//! .statnext project files: a zip holding the UI state, the R session state
//! (datasets, code log, analyses as RDS) and a manifest.

use serde_json::Value;
use std::fs::File;
use std::io::{Read, Write};
use std::path::Path;
use zip::write::SimpleFileOptions;

pub const FORMAT_VERSION: u32 = 1;

pub fn write(path: &Path, ui_state: &Value, data_rds: &Path) -> Result<(), String> {
    let tmp = path.with_extension("statnext.tmp");
    {
        let file = File::create(&tmp).map_err(|e| e.to_string())?;
        let mut zip = zip::ZipWriter::new(file);
        let opts = SimpleFileOptions::default().compression_method(zip::CompressionMethod::Deflated);
        let manifest = serde_json::json!({
            "app": "StatNext",
            "format": FORMAT_VERSION,
            "app_version": env!("CARGO_PKG_VERSION"),
        });
        let mut put = |name: &str, bytes: &[u8]| -> Result<(), String> {
            zip.start_file(name, opts).map_err(|e| e.to_string())?;
            zip.write_all(bytes).map_err(|e| e.to_string())
        };
        put("manifest.json", manifest.to_string().as_bytes())?;
        put("ui.json", serde_json::to_vec_pretty(ui_state).map_err(|e| e.to_string())?.as_slice())?;
        put("data.rds", &std::fs::read(data_rds).map_err(|e| e.to_string())?)?;
        zip.finish().map_err(|e| e.to_string())?;
    }
    // Write-then-rename so a crash never leaves a half-written project.
    std::fs::rename(&tmp, path).map_err(|e| e.to_string())
}

/// Returns the UI state and extracts data.rds to `data_out`.
pub fn read(path: &Path, data_out: &Path) -> Result<Value, String> {
    let file = File::open(path).map_err(|e| e.to_string())?;
    let mut zip = zip::ZipArchive::new(file).map_err(|_| "Not a StatNext project file.".to_string())?;
    let manifest: Value = {
        let mut s = String::new();
        zip.by_name("manifest.json")
            .map_err(|_| "Not a StatNext project file.".to_string())?
            .read_to_string(&mut s)
            .map_err(|e| e.to_string())?;
        serde_json::from_str(&s).map_err(|e| e.to_string())?
    };
    if manifest["format"].as_u64().unwrap_or(0) > FORMAT_VERSION as u64 {
        return Err("This project was saved by a newer StatNext.".into());
    }
    let ui: Value = {
        let mut s = String::new();
        zip.by_name("ui.json").map_err(|e| e.to_string())?.read_to_string(&mut s).map_err(|e| e.to_string())?;
        serde_json::from_str(&s).map_err(|e| e.to_string())?
    };
    let mut rds = Vec::new();
    zip.by_name("data.rds").map_err(|e| e.to_string())?.read_to_end(&mut rds).map_err(|e| e.to_string())?;
    std::fs::write(data_out, rds).map_err(|e| e.to_string())?;
    Ok(ui)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trips() {
        let dir = tempfile::tempdir().unwrap();
        let rds = dir.path().join("in.rds");
        std::fs::write(&rds, b"RDS-BYTES").unwrap();
        let proj = dir.path().join("a.statnext");
        let ui = serde_json::json!({"analyses": [{"module": "ttest_ind"}]});
        write(&proj, &ui, &rds).unwrap();
        let out = dir.path().join("out.rds");
        assert_eq!(read(&proj, &out).unwrap(), ui);
        assert_eq!(std::fs::read(out).unwrap(), b"RDS-BYTES");
    }

    #[test]
    fn rejects_other_files() {
        let dir = tempfile::tempdir().unwrap();
        let f = dir.path().join("x.statnext");
        std::fs::write(&f, b"nope").unwrap();
        assert!(read(&f, &dir.path().join("o")).is_err());
    }
}
