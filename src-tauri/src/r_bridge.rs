//! Supervises the R worker: lazy start, restart after a crash or a Windows cancel,
//! and replay of data-changing calls so the new worker has the same datasets.

use crate::r_worker::{Notify, Worker, WorkerConfig};
use crate::rpc::{codes, RpcError};
use serde_json::Value;
use std::sync::Arc;
use tokio::sync::{Mutex, RwLock};

/// Methods whose effects must be replayed into a fresh worker.
const REPLAYED: &[&str] = &["data.import", "data.example", "data.patch", "data.load"];

/// Methods the frontend may call through the generic `rpc` command.
pub const ALLOWED: &[&str] = &[
    "system.hello",
    "pkg.install",
    "data.import",
    "data.example",
    "data.examples",
    "data.info",
    "data.slice",
    "data.patch",
    "data.save",
    "data.load",
    "analysis.list",
    "analysis.help",
    "analysis.run",
    "analysis.remove",
    "code.run",
    "session.script",
    "plot.export",
];

pub struct RBridge {
    cfg: RwLock<Option<WorkerConfig>>,
    worker: RwLock<Option<Arc<Worker>>>,
    replay: Mutex<Vec<(String, Value)>>,
    notify: Notify,
}

impl RBridge {
    pub fn new(notify: Notify) -> Self {
        Self { cfg: RwLock::new(None), worker: RwLock::new(None), replay: Mutex::default(), notify }
    }

    pub async fn configure(&self, cfg: WorkerConfig) {
        *self.cfg.write().await = Some(cfg);
        if let Some(w) = self.worker.write().await.take() {
            w.kill().await;
        }
    }

    async fn ensure_worker(&self) -> Result<Arc<Worker>, RpcError> {
        if let Some(w) = self.worker.read().await.as_ref() {
            if w.is_alive() {
                return Ok(w.clone());
            }
        }
        let mut slot = self.worker.write().await;
        if let Some(w) = slot.as_ref() {
            if w.is_alive() {
                return Ok(w.clone());
            }
        }
        let cfg = self.cfg.read().await.clone().ok_or_else(|| {
            RpcError::new(codes::NOT_STARTED, "R is not configured yet.")
        })?;
        let w = Arc::new(
            Worker::spawn(&cfg, self.notify.clone())
                .await
                .map_err(|e| RpcError::new(codes::WORKER_DIED, format!("Cannot start R: {e}")))?,
        );
        // Bring a restarted worker back to the same data state.
        for (method, params) in self.replay.lock().await.iter() {
            w.call(method, params).await?;
        }
        *slot = Some(w.clone());
        Ok(w)
    }

    pub async fn call(&self, method: &str, params: Value) -> Result<Value, RpcError> {
        let w = self.ensure_worker().await?;
        let out = w.call(method, &params).await;
        if out.is_ok() && REPLAYED.contains(&method) {
            let mut log = self.replay.lock().await;
            if method == "data.load" {
                log.clear();
            } else if method != "data.patch" {
                // A new import replaces everything previously recorded for that dataset.
                let ds = params.get("dataset").cloned().unwrap_or(Value::from("data"));
                log.retain(|(_, p)| p.get("dataset").cloned().unwrap_or(Value::from("data")) != ds);
            }
            log.push((method.to_string(), params));
        }
        out
    }

    /// Cancel the running job. Unix: SIGINT keeps the worker. Windows: kill it; the next
    /// call starts a new worker and replays the data log.
    pub async fn cancel(&self) -> bool {
        let Some(w) = self.worker.read().await.clone() else { return false };
        if w.interrupt() {
            return true;
        }
        w.kill().await;
        true
    }

    pub async fn shutdown(&self) {
        if let Some(w) = self.worker.write().await.take() {
            w.kill().await;
        }
    }
}
