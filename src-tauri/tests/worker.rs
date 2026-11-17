//! Integration tests against a real R worker. Run when STATNEXT_TEST_R=1 and
//! statnextr is installed in the default R library (CI installs it first).

use serde_json::{json, Value};
use statnext_lib::r_bridge::RBridge;
use statnext_lib::r_detect;
use statnext_lib::r_worker::WorkerConfig;
use statnext_lib::rpc::codes;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::Duration;

fn enabled() -> bool {
    std::env::var("STATNEXT_TEST_R").as_deref() == Ok("1")
}

fn config() -> WorkerConfig {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("..");
    let rscript = std::env::var("STATNEXT_RSCRIPT").map(PathBuf::from).unwrap_or_else(|_| {
        r_detect::candidates().into_iter().find(|p| p.is_file()).expect("Rscript")
    });
    WorkerConfig {
        rscript,
        modules: vec![root.join("analyses")],
        datasets: Some(root.join("datasets")),
        work_dir: tempfile::tempdir().unwrap().keep(),
        r_lib: None,
    }
}

async fn bridge() -> (RBridge, Arc<Mutex<Vec<Value>>>) {
    let seen = Arc::new(Mutex::new(Vec::new()));
    let s2 = seen.clone();
    let b = RBridge::new(Arc::new(move |n| s2.lock().unwrap().push(n)));
    b.configure(config()).await;
    (b, seen)
}

#[tokio::test(flavor = "multi_thread")]
async fn runs_an_analysis_end_to_end() {
    if !enabled() {
        return;
    }
    let (b, _) = bridge().await;
    let hello = b.call("system.hello", json!({})).await.unwrap();
    assert_eq!(hello["protocol"], 1);
    b.call("data.example", json!({"name": "mtcars"})).await.unwrap();
    let res = b
        .call("analysis.run", json!({"module": "ttest_ind", "options": {"dv": ["mpg"], "group": ["am"], "plot": "none"}}))
        .await
        .unwrap();
    let row = &res["tables"][1]["rows"][0];
    assert!((row["stat"].as_f64().unwrap() + 3.7671).abs() < 1e-4);
    assert!(res["code"].as_str().unwrap().contains("t.test(mpg ~ am"));
    let err = b.call("analysis.run", json!({"module": "ttest_ind", "options": {"dv": ["mpg"]}})).await.unwrap_err();
    assert_eq!(err.code, codes::INVALID_OPTIONS);
    b.shutdown().await;
}

#[cfg(unix)]
#[tokio::test(flavor = "multi_thread")]
async fn cancel_interrupts_and_worker_survives() {
    if !enabled() {
        return;
    }
    let (b, _) = bridge().await;
    b.call("data.example", json!({"name": "mtcars"})).await.unwrap();
    let b = Arc::new(b);
    let b2 = b.clone();
    let job = tokio::spawn(async move { b2.call("code.run", json!({"code": "Sys.sleep(30)"})).await });
    tokio::time::sleep(Duration::from_millis(1500)).await;
    assert!(b.cancel().await);
    let out = tokio::time::timeout(Duration::from_secs(10), job).await.unwrap().unwrap();
    assert_eq!(out.unwrap_err().code, codes::CANCELLED);
    // Same worker, data still loaded.
    let info = b.call("data.info", json!({})).await.unwrap();
    assert_eq!(info["nrow"], 32);
    b.shutdown().await;
}

#[tokio::test(flavor = "multi_thread")]
async fn restarted_worker_replays_data() {
    if !enabled() {
        return;
    }
    let (b, _) = bridge().await;
    b.call("data.example", json!({"name": "mtcars"})).await.unwrap();
    b.call("data.patch", json!({"ops": [{"op": "set_cell", "row": 0, "column": "mpg", "value": "99"}]}))
        .await
        .unwrap();
    // Simulate a crash.
    let _ = b.call("code.run", json!({"code": "quit(save = 'no', status = 1)"})).await;
    let sl = b.call("data.slice", json!({"offset": 0, "limit": 1})).await.unwrap();
    assert_eq!(sl["columns"]["mpg"][0], 99.0);
    b.shutdown().await;
}
