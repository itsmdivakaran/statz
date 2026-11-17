//! First-run setup of the private R library: dependencies from a date-pinned Posit
//! Package Manager snapshot (binaries on macOS/Windows), then statnextr from the
//! bundled source. The snapshot date is the version lock for every user.

use std::path::Path;
use std::process::Stdio;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;

/// Package versions are pinned by this snapshot date. Bump deliberately.
pub const CRAN_SNAPSHOT: &str = "https://packagemanager.posit.co/cran/2026-11-01";

pub const R_PACKAGES: &[&str] = &[
    "jsonlite", "glue", "effectsize", "car", "rsvg", "readxl", "haven", "S7", "ggnext",
];

/// R script run once by Rscript. Prints "PROGRESS <pct> <message>" lines.
pub fn bootstrap_script(lib: &Path, backend_src: &Path) -> String {
    let lib = lib.display().to_string().replace('\\', "/");
    let src = backend_src.display().to_string().replace('\\', "/");
    let pkgs = R_PACKAGES.iter().map(|p| format!("\"{p}\"")).collect::<Vec<_>>().join(", ");
    format!(
        r#"
lib <- "{lib}"
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(lib, .libPaths()))
options(repos = c(CRAN = "{repo}"), timeout = 600)
pkgs <- c({pkgs})
todo <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
for (i in seq_along(todo)) {{
  cat(sprintf("PROGRESS %d Installing %s\n", round(90 * (i - 1) / length(todo)), todo[i]))
  install.packages(todo[i], lib = lib, quiet = TRUE)
}}
cat("PROGRESS 92 Installing statnextr\n")
install.packages("{src}", lib = lib, repos = NULL, type = "source", quiet = TRUE)
missing <- c(pkgs, "statnextr")[!vapply(c(pkgs, "statnextr"), requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {{ cat("FAILED", missing, "\n"); quit(status = 1) }}
cat("PROGRESS 100 Ready\n")
"#,
        repo = CRAN_SNAPSHOT
    )
}

/// Parse "PROGRESS 42 Installing car" into (42, "Installing car").
pub fn parse_progress(line: &str) -> Option<(u32, String)> {
    let rest = line.strip_prefix("PROGRESS ")?;
    let (pct, msg) = rest.split_once(' ').unwrap_or((rest, ""));
    Some((pct.parse().ok()?, msg.to_string()))
}

/// True when statnextr is already installed in `lib` at the bundled version.
pub fn is_installed(lib: &Path, backend_src: &Path) -> bool {
    let read_version = |p: &Path| {
        std::fs::read_to_string(p).ok().and_then(|s| {
            s.lines().find_map(|l| l.strip_prefix("Version:").map(|v| v.trim().to_string()))
        })
    };
    match (
        read_version(&lib.join("statnextr").join("DESCRIPTION")),
        read_version(&backend_src.join("DESCRIPTION")),
    ) {
        (Some(a), Some(b)) => a == b,
        _ => false,
    }
}

pub async fn run_bootstrap(
    rscript: &Path,
    lib: &Path,
    backend_src: &Path,
    mut on_progress: impl FnMut(u32, String),
) -> Result<(), String> {
    let script = bootstrap_script(lib, backend_src);
    let mut child = Command::new(rscript)
        .args(["--vanilla", "-e", &script])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("Cannot start R: {e}"))?;
    let stdout = child.stdout.take().expect("piped");
    let stderr = child.stderr.take().expect("piped");
    let err_task = tokio::spawn(async move {
        let mut buf = Vec::new();
        let mut lines = BufReader::new(stderr).lines();
        while let Ok(Some(l)) = lines.next_line().await {
            buf.push(l);
        }
        buf
    });
    let mut lines = BufReader::new(stdout).lines();
    let mut failed = None;
    while let Ok(Some(line)) = lines.next_line().await {
        if let Some((pct, msg)) = parse_progress(&line) {
            on_progress(pct, msg);
        } else if let Some(rest) = line.strip_prefix("FAILED") {
            failed = Some(rest.trim().to_string());
        }
    }
    let status = child.wait().await.map_err(|e| e.to_string())?;
    let stderr = err_task.await.unwrap_or_default();
    if status.success() {
        Ok(())
    } else {
        let tail: Vec<_> = stderr.iter().rev().take(15).rev().cloned().collect();
        Err(format!(
            "Package setup failed{}.\n{}",
            failed.map(|f| format!(" ({f})")).unwrap_or_default(),
            tail.join("\n")
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_progress_lines() {
        assert_eq!(parse_progress("PROGRESS 42 Installing car"), Some((42, "Installing car".into())));
        assert_eq!(parse_progress("PROGRESS 100"), Some((100, "".into())));
        assert_eq!(parse_progress("trying URL"), None);
    }

    #[test]
    fn script_pins_snapshot_and_escapes_paths() {
        let s = bootstrap_script(Path::new(r"C:\Users\a\lib"), Path::new("/app/r-backend"));
        assert!(s.contains(CRAN_SNAPSHOT));
        assert!(s.contains("C:/Users/a/lib"));
    }
}
