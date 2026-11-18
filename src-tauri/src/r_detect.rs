//! Locate an R installation (>= 4.4) and report how to install one if missing.

use serde::Serialize;
use std::path::{Path, PathBuf};
use std::process::Command;

pub const MIN_R: (u32, u32) = (4, 4);

#[derive(Debug, Clone, Serialize, PartialEq)]
pub struct RInstall {
    pub rscript: PathBuf,
    pub version: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct RStatus {
    pub found: Option<RInstall>,
    /// Installations found but older than MIN_R.
    pub too_old: Vec<RInstall>,
    pub ok: bool,
    pub install_hint: InstallHint,
}

#[derive(Debug, Clone, Serialize)]
pub struct InstallHint {
    pub url: String,
    pub command: Option<String>,
    pub text: String,
    /// Button text for the download link, naming the right build for this computer.
    pub download_label: String,
    /// Plain steps shown on the start screen.
    pub steps: Vec<String>,
}

/// Parse "Rscript (R) version 4.4.1 (2024-06-14)" or "R scripting front-end version 4.4.1".
pub fn parse_version(out: &str) -> Option<(u32, u32, u32)> {
    let idx = out.find("version ")?;
    let rest = &out[idx + 8..];
    let ver: String = rest.chars().take_while(|c| c.is_ascii_digit() || *c == '.').collect();
    let mut it = ver.split('.').map(|p| p.parse::<u32>().ok());
    Some((it.next()??, it.next()??, it.next().flatten().unwrap_or(0)))
}

pub fn version_ok(v: (u32, u32, u32)) -> bool {
    (v.0, v.1) >= MIN_R
}

fn probe(rscript: &Path) -> Option<(RInstall, bool)> {
    if !rscript.is_file() {
        return None;
    }
    let mut cmd = Command::new(rscript);
    cmd.arg("--version");
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        cmd.creation_flags(CREATE_NO_WINDOW);
    }
    let out = cmd.output().ok()?;
    // Rscript prints its version to stderr on older R and stdout on newer R.
    let text = format!(
        "{}{}",
        String::from_utf8_lossy(&out.stdout),
        String::from_utf8_lossy(&out.stderr)
    );
    let v = parse_version(&text)?;
    Some((
        RInstall { rscript: rscript.to_path_buf(), version: format!("{}.{}.{}", v.0, v.1, v.2) },
        version_ok(v),
    ))
}

/// Windows process flag: start a console program (Rscript) without opening a console window.
#[cfg(windows)]
pub const CREATE_NO_WINDOW: u32 = 0x0800_0000;

fn rscript_name() -> &'static str {
    if cfg!(windows) {
        "Rscript.exe"
    } else {
        "Rscript"
    }
}

/// Candidate Rscript paths in priority order.
pub fn candidates() -> Vec<PathBuf> {
    let mut c = Vec::new();
    for var in ["STATNEXT_RSCRIPT"] {
        if let Ok(p) = std::env::var(var) {
            c.push(PathBuf::from(p));
        }
    }
    if let Ok(home) = std::env::var("R_HOME") {
        c.push(Path::new(&home).join("bin").join(rscript_name()));
    }
    if let Ok(p) = which::which(rscript_name()) {
        c.push(p);
    }
    #[cfg(target_os = "macos")]
    {
        c.push("/Library/Frameworks/R.framework/Resources/bin/Rscript".into());
        c.push("/opt/homebrew/bin/Rscript".into());
        c.push("/usr/local/bin/Rscript".into());
    }
    #[cfg(target_os = "linux")]
    {
        c.push("/usr/bin/Rscript".into());
        c.push("/usr/local/bin/Rscript".into());
        if let Ok(rd) = std::fs::read_dir("/opt/R") {
            for e in rd.flatten() {
                c.push(e.path().join("bin/Rscript"));
            }
        }
    }
    #[cfg(windows)]
    {
        c.extend(windows_registry_paths());
        for base in [r"C:\Program Files\R", r"C:\Program Files (x86)\R"] {
            if let Ok(rd) = std::fs::read_dir(base) {
                let mut dirs: Vec<_> = rd.flatten().map(|e| e.path()).collect();
                dirs.sort();
                dirs.reverse(); // newest first
                for d in dirs {
                    c.push(d.join("bin").join("Rscript.exe"));
                }
            }
        }
    }
    c.dedup();
    c
}

#[cfg(windows)]
fn windows_registry_paths() -> Vec<PathBuf> {
    use winreg::enums::{HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE};
    use winreg::RegKey;
    let mut out = Vec::new();
    for hive in [HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER] {
        if let Ok(k) = RegKey::predef(hive).open_subkey(r"SOFTWARE\R-core\R") {
            if let Ok(p) = k.get_value::<String, _>("InstallPath") {
                out.push(Path::new(&p).join("bin").join("Rscript.exe"));
            }
        }
    }
    out
}

pub fn install_hint() -> InstallHint {
    let back = "Come back to this window: StatNext finds R by itself and finishes the setup.".to_string();
    if cfg!(target_os = "macos") {
        let (chip, file) = if cfg!(target_arch = "aarch64") {
            ("Apple silicon (M1 or later)", "R-4.x.x-arm64.pkg")
        } else {
            ("Intel", "R-4.x.x-x86_64.pkg")
        };
        InstallHint {
            url: "https://cloud.r-project.org/bin/macosx/".into(),
            command: Some("brew install --cask r".into()),
            text: format!("StatNext uses R, the free statistics engine. This Mac has an {chip} processor."),
            download_label: format!("Download R for {chip}"),
            steps: vec![
                format!("Click the button below. On the CRAN page, under \"Latest release\", download {file}."),
                "Open the downloaded file and click through the installer (Continue, Agree, Install).".into(),
                back,
            ],
        }
    } else if cfg!(windows) {
        InstallHint {
            // Always redirects to the installer of the current R release.
            url: "https://cloud.r-project.org/bin/windows/base/release.html".into(),
            command: Some("winget install RProject.R".into()),
            text: "StatNext uses R, the free statistics engine.".into(),
            download_label: "Download R for Windows".into(),
            steps: vec![
                "Click the button below; the R installer downloads straight away.".into(),
                "Run the downloaded R-4.x.x-win.exe and keep the default options.".into(),
                back,
            ],
        }
    } else {
        InstallHint {
            url: "https://cloud.r-project.org/bin/linux/".into(),
            command: None,
            text: "StatNext uses R, the free statistics engine. Your distribution's own package may be older than 4.4.".into(),
            download_label: "Open CRAN's Linux instructions".into(),
            steps: vec![
                "Click the button below and follow the steps for your distribution (Ubuntu, Debian, Fedora…).".into(),
                "Install R 4.4 or later from CRAN's repository.".into(),
                back,
            ],
        }
    }
}

/// Open a CRAN page in the default browser. Only CRAN links are accepted.
pub fn open_cran(url: &str) -> std::io::Result<()> {
    let ok = [
        "https://cloud.r-project.org/", "https://cran.r-project.org/",
        // AI provider key pages linked from Settings
        "https://console.anthropic.com/", "https://platform.openai.com/", "https://aistudio.google.com/",
    ]
    .iter().any(|p| url.starts_with(p))
        && !url.chars().any(|c| c.is_whitespace() || c == '"' || c == '\'' || c == '&' || c == '|');
    if !ok {
        return Err(std::io::Error::new(std::io::ErrorKind::InvalidInput, "Only CRAN links can be opened"));
    }
    #[cfg(target_os = "macos")]
    let mut cmd = std::process::Command::new("open");
    #[cfg(windows)]
    let mut cmd = {
        let mut c = std::process::Command::new("rundll32");
        c.arg("url.dll,FileProtocolHandler");
        c
    };
    #[cfg(all(unix, not(target_os = "macos")))]
    let mut cmd = std::process::Command::new("xdg-open");
    cmd.arg(url).spawn().map(|_| ())
}

pub fn detect() -> RStatus {
    let mut too_old = Vec::new();
    let mut found = None;
    for cand in candidates() {
        if let Some((inst, ok)) = probe(&cand) {
            if ok {
                found = Some(inst);
                break;
            }
            if !too_old.contains(&inst) {
                too_old.push(inst);
            }
        }
    }
    RStatus { ok: found.is_some(), found, too_old, install_hint: install_hint() }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_opens_cran_links() {
        assert!(open_cran("https://example.com/").is_err());
        assert!(open_cran("https://cloud.r-project.org/ && rm").is_err());
        assert!(open_cran("file:///etc/passwd").is_err());
        let h = install_hint();
        assert!(h.url.starts_with("https://cloud.r-project.org/"));
        assert_eq!(h.steps.len(), 3);
    }

    #[test]
    fn parses_rscript_versions() {
        assert_eq!(parse_version("Rscript (R) version 4.4.1 (2024-06-14)"), Some((4, 4, 1)));
        assert_eq!(parse_version("R scripting front-end version 4.3.3 (2024-02-29)"), Some((4, 3, 3)));
        assert_eq!(parse_version("garbage"), None);
    }

    #[test]
    fn enforces_minimum_version() {
        assert!(version_ok((4, 4, 0)));
        assert!(version_ok((5, 0, 0)));
        assert!(!version_ok((4, 3, 3)));
    }
}
