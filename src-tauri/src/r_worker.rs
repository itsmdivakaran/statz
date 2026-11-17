//! One R process speaking newline-delimited JSON-RPC over stdin/stdout.

use crate::rpc::{self, codes, Request, RpcError};
use crate::setup::r_path;
use serde_json::Value;
use std::collections::HashMap;
use std::path::PathBuf;
use std::process::Stdio;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::process::{Child, ChildStdin, Command};
use tokio::sync::{oneshot, Mutex};

pub type Notify = Arc<dyn Fn(Value) + Send + Sync>;
type Pending = Arc<std::sync::Mutex<HashMap<u64, oneshot::Sender<Result<Value, RpcError>>>>>;

#[derive(Debug, Clone)]
pub struct WorkerConfig {
    pub rscript: PathBuf,
    /// Directories holding analysis modules (built-in first, then plugins).
    pub modules: Vec<PathBuf>,
    pub datasets: Option<PathBuf>,
    /// The user's plugin folder (installed plugins are loaded from here).
    pub plugins: Option<PathBuf>,
    pub work_dir: PathBuf,
    /// Private R library (prepended to .libPaths() via R_LIBS_USER).
    pub r_lib: Option<PathBuf>,
}

impl WorkerConfig {
    pub fn args(&self) -> Vec<String> {
        let sep = if cfg!(windows) { ";" } else { ":" };
        let modules: Vec<String> = self.modules.iter().map(|p| r_path(p)).collect();
        let mut a = vec![
            "--vanilla".into(),
            "-e".into(),
            "statnextr::sn_main()".into(),
            "--args".into(),
            format!("--modules={}", modules.join(sep)),
            format!("--workdir={}", r_path(&self.work_dir)),
        ];
        if let Some(d) = &self.datasets {
            a.push(format!("--datasets={}", r_path(d)));
        }
        if let Some(d) = &self.plugins {
            a.push(format!("--plugins={}", r_path(d)));
        }
        a
    }
}

pub struct Worker {
    stdin: Mutex<ChildStdin>,
    child: Mutex<Child>,
    pending: Pending,
    next_id: AtomicU64,
    alive: Arc<AtomicBool>,
    pid: Option<u32>,
}

impl Worker {
    pub async fn spawn(cfg: &WorkerConfig, notify: Notify) -> std::io::Result<Self> {
        std::fs::create_dir_all(&cfg.work_dir)?;
        let mut cmd = Command::new(&cfg.rscript);
        cmd.args(cfg.args())
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .kill_on_drop(true);
        // Force UTF-8 so APA symbols (minus, eta, chi) survive the pipe.
        if !cfg!(windows) {
            cmd.env("LC_ALL", if cfg!(target_os = "macos") { "en_US.UTF-8" } else { "C.UTF-8" });
        }
        if let Some(lib) = &cfg.r_lib {
            std::fs::create_dir_all(lib)?;
            cmd.env("R_LIBS_USER", r_path(lib));
        }
        #[cfg(windows)]
        cmd.creation_flags(crate::r_detect::CREATE_NO_WINDOW);
        let mut child = cmd.spawn()?;
        let pid = child.id();
        let stdin = child.stdin.take().expect("piped stdin");
        let stdout = child.stdout.take().expect("piped stdout");
        let stderr = child.stderr.take().expect("piped stderr");
        let pending: Pending = Arc::default();
        let alive = Arc::new(AtomicBool::new(true));

        // stdout: protocol responses.
        {
            let pending = pending.clone();
            let alive = alive.clone();
            tokio::spawn(async move {
                let mut lines = BufReader::new(stdout).lines();
                while let Ok(Some(line)) = lines.next_line().await {
                    match rpc::parse_response(&line) {
                        Some((id, outcome)) => {
                            if let Some(tx) = pending.lock().unwrap().remove(&id) {
                                let _ = tx.send(outcome);
                            }
                        }
                        None => log::warn!("R stdout (non-protocol): {line}"),
                    }
                }
                alive.store(false, Ordering::SeqCst);
                for (_, tx) in pending.lock().unwrap().drain() {
                    let _ = tx.send(Err(RpcError::new(codes::WORKER_DIED, "The R process stopped.")));
                }
            });
        }
        // stderr: notifications and logs.
        tokio::spawn(async move {
            let mut lines = BufReader::new(stderr).lines();
            while let Ok(Some(line)) = lines.next_line().await {
                match rpc::parse_notification(&line) {
                    Some(n) => notify(n),
                    None => log::info!("R: {line}"),
                }
            }
        });

        Ok(Self {
            stdin: Mutex::new(stdin),
            child: Mutex::new(child),
            pending,
            next_id: AtomicU64::new(1),
            alive,
            pid,
        })
    }

    pub fn is_alive(&self) -> bool {
        self.alive.load(Ordering::SeqCst)
    }

    /// Send a request and wait for its response. R handles requests in order.
    pub async fn call(&self, method: &str, params: &Value) -> Result<Value, RpcError> {
        if !self.is_alive() {
            return Err(RpcError::new(codes::WORKER_DIED, "The R process stopped."));
        }
        let id = self.next_id.fetch_add(1, Ordering::SeqCst);
        let (tx, rx) = oneshot::channel();
        self.pending.lock().unwrap().insert(id, tx);
        let mut line = serde_json::to_string(&Request { jsonrpc: "2.0", id, method, params })
            .map_err(|e| RpcError::new(codes::PARSE_ERROR, e.to_string()))?;
        line.push('\n');
        {
            let mut stdin = self.stdin.lock().await;
            if let Err(e) = async {
                stdin.write_all(line.as_bytes()).await?;
                stdin.flush().await
            }
            .await
            {
                self.pending.lock().unwrap().remove(&id);
                return Err(RpcError::new(codes::WORKER_DIED, format!("Cannot write to R: {e}")));
            }
        }
        rx.await
            .unwrap_or_else(|_| Err(RpcError::new(codes::WORKER_DIED, "The R process stopped.")))
    }

    /// Interrupt the running request (SIGINT). R turns it into a -32004 error and keeps
    /// its state. Returns false where interrupts are unsupported (Windows).
    pub fn interrupt(&self) -> bool {
        #[cfg(unix)]
        if let Some(pid) = self.pid {
            // SAFETY: plain kill(2) on our own child process.
            return unsafe { libc::kill(pid as libc::pid_t, libc::SIGINT) } == 0;
        }
        false
    }

    pub async fn kill(&self) {
        let _ = self.child.lock().await.kill().await;
        self.alive.store(false, Ordering::SeqCst);
    }
}
