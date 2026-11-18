//! StatNext desktop shell: finds R, sets up the private R library, supervises the
//! R worker and exposes it to the frontend as Tauri commands.

pub mod ai;
pub mod project;
pub mod r_bridge;
pub mod r_detect;
pub mod r_worker;
pub mod rpc;
pub mod setup;

use r_bridge::RBridge;
use r_worker::WorkerConfig;
use rpc::{codes, RpcError};
use serde_json::Value;
use std::path::PathBuf;
use std::sync::Arc;
use tauri::{AppHandle, Emitter, Manager, State};

struct AppState {
    bridge: Arc<RBridge>,
}

/// Bundled resource folder, or the repo checkout in debug builds.
fn resource(app: &AppHandle, name: &str) -> PathBuf {
    if let Ok(root) = std::env::var("STATNEXT_ROOT") {
        return PathBuf::from(root).join(name);
    }
    if cfg!(debug_assertions) {
        let dev = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("..").join(name);
        if dev.exists() {
            return dev;
        }
    }
    app.path().resource_dir().map(|d| d.join(name)).unwrap_or_else(|_| PathBuf::from(name))
}

fn err(e: impl ToString) -> RpcError {
    RpcError::new(codes::R_ERROR, e.to_string())
}

#[tauri::command]
fn r_status() -> r_detect::RStatus {
    r_detect::detect()
}

/// Ensure packages are installed, start the worker and return its hello.
#[tauri::command]
async fn backend_start(app: AppHandle, state: State<'_, AppState>) -> Result<Value, RpcError> {
    let status = r_detect::detect();
    let Some(r) = status.found else {
        return Err(RpcError {
            code: codes::NOT_STARTED,
            message: "R 4.4 or later was not found.".into(),
            data: Some(serde_json::to_value(&status).unwrap_or_default()),
        });
    };
    let minor = r.version.rsplitn(2, '.').last().unwrap_or(&r.version).to_string();
    let data_dir = app.path().app_local_data_dir().map_err(err)?;
    let lib = data_dir.join("r-lib").join(&minor);
    let backend = resource(&app, "r-backend");
    if !setup::is_installed(&lib, &backend) {
        let app2 = app.clone();
        setup::run_bootstrap(&r.rscript, &lib, &backend, move |pct, message| {
            let _ = app2.emit("setup://progress", serde_json::json!({"pct": pct, "message": message}));
        })
        .await
        .map_err(|m| RpcError::new(codes::MISSING_PACKAGE, m))?;
    }
    let cfg = WorkerConfig {
        rscript: r.rscript.clone(),
        modules: vec![resource(&app, "analyses")],
        datasets: Some(resource(&app, "datasets")),
        plugins: Some(data_dir.join("plugins")),
        work_dir: data_dir.join("sessions").join(std::process::id().to_string()),
        r_lib: Some(lib),
    };
    state.bridge.configure(cfg).await;
    let mut hello = state.bridge.call("system.hello", Value::Object(Default::default())).await?;
    hello["rscript"] = Value::from(r.rscript.display().to_string());
    Ok(hello)
}

#[tauri::command]
fn open_cran(url: String) -> Result<(), RpcError> {
    r_detect::open_cran(&url).map_err(err)
}

#[tauri::command]
async fn rpc(method: String, params: Value, state: State<'_, AppState>) -> Result<Value, RpcError> {
    if !r_bridge::ALLOWED.contains(&method.as_str()) {
        return Err(RpcError::new(codes::METHOD_NOT_FOUND, format!("Method not allowed: {method}")));
    }
    state.bridge.call(&method, params).await
}

#[tauri::command]
async fn rpc_cancel(state: State<'_, AppState>) -> Result<bool, RpcError> {
    Ok(state.bridge.cancel().await)
}

#[tauri::command]
async fn project_save(
    path: String,
    ui_state: Value,
    app: AppHandle,
    state: State<'_, AppState>,
) -> Result<(), RpcError> {
    let tmp = app.path().app_local_data_dir().map_err(err)?.join("project-save.rds");
    state.bridge.call("data.save", serde_json::json!({"path": tmp})).await?;
    project::write(&PathBuf::from(path), &ui_state, &tmp).map_err(err)
}

#[tauri::command]
async fn project_load(path: String, app: AppHandle, state: State<'_, AppState>) -> Result<Value, RpcError> {
    let dir = app.path().app_local_data_dir().map_err(err)?;
    std::fs::create_dir_all(&dir).map_err(err)?;
    let rds = dir.join(format!("project-load-{}.rds", std::process::id()));
    let ui = project::read(&PathBuf::from(path), &rds).map_err(err)?;
    let datasets = state.bridge.call("data.load", serde_json::json!({"path": rds})).await?;
    Ok(serde_json::json!({"ui": ui, "datasets": datasets}))
}

pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .setup(|app| {
            let handle = app.handle().clone();
            let notify: r_worker::Notify = Arc::new(move |n: Value| {
                let _ = handle.emit("r://notification", n);
            });
            app.manage(AppState { bridge: Arc::new(RBridge::new(notify)) });
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            r_status,
            backend_start,
            rpc,
            rpc_cancel,
            project_save,
            project_load,
            open_cran,
            ai::ai_key_set,
            ai::ai_key_status,
            ai::ai_key_delete,
            ai::ai_post
        ])
        .build(tauri::generate_context!())
        .expect("error while building StatNext")
        .run(|app, event| {
            if let tauri::RunEvent::Exit = event {
                let bridge = app.state::<AppState>().bridge.clone();
                tauri::async_runtime::block_on(bridge.shutdown());
            }
        });
}
