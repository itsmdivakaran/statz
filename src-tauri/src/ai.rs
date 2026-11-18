//! Optional AI assistant. Off unless the user turns it on and adds a key.
//!
//! API keys live in the OS keychain (macOS Keychain, Windows Credential Manager,
//! Secret Service on Linux) and never reach the webview: the frontend builds the
//! provider request body, and this module adds the key header and sends it.

use crate::rpc::{codes, RpcError};
use serde_json::Value;
use std::time::Duration;

const SERVICE: &str = "StatNext AI";
pub const PROVIDERS: &[&str] = &["anthropic", "openai", "gemini", "compatible", "ollama"];

fn check_provider(p: &str) -> Result<(), RpcError> {
    if PROVIDERS.contains(&p) {
        Ok(())
    } else {
        Err(RpcError::new(codes::INVALID_OPTIONS, format!("Unknown AI provider: {p}")))
    }
}

fn entry(provider: &str) -> Result<keyring::Entry, RpcError> {
    check_provider(provider)?;
    keyring::Entry::new(SERVICE, provider).map_err(|e| RpcError::new(codes::R_ERROR, e.to_string()))
}

fn get_key(provider: &str) -> Result<Option<String>, RpcError> {
    match entry(provider)?.get_password() {
        Ok(k) => Ok(Some(k)),
        Err(keyring::Error::NoEntry) => Ok(None),
        Err(e) => Err(RpcError::new(codes::R_ERROR, format!("Could not read the key from the keychain: {e}"))),
    }
}

/// Only https, or plain http to this computer (Ollama and other local servers).
pub fn url_allowed(url: &str) -> bool {
    let Some(rest) = url.strip_prefix("https://").or_else(|| url.strip_prefix("http://")) else {
        return false;
    };
    if url.starts_with("https://") {
        return !rest.is_empty();
    }
    let host = rest.split(['/', ':']).next().unwrap_or("");
    matches!(host, "localhost" | "127.0.0.1") || rest.starts_with("[::1]")
}

#[tauri::command]
pub fn ai_key_set(provider: String, key: String) -> Result<(), RpcError> {
    let key = key.trim();
    if key.is_empty() {
        return Err(RpcError::new(codes::INVALID_OPTIONS, "The API key is empty."));
    }
    entry(&provider)?
        .set_password(key)
        .map_err(|e| RpcError::new(codes::R_ERROR, format!("Could not save the key to the keychain: {e}")))
}

#[tauri::command]
pub fn ai_key_status(provider: String) -> Result<bool, RpcError> {
    Ok(get_key(&provider)?.is_some())
}

#[tauri::command]
pub fn ai_key_delete(provider: String) -> Result<(), RpcError> {
    match entry(&provider)?.delete_credential() {
        Ok(()) | Err(keyring::Error::NoEntry) => Ok(()),
        Err(e) => Err(RpcError::new(codes::R_ERROR, e.to_string())),
    }
}

/// POST `body` to `url` with the provider's auth header and return the JSON reply.
#[tauri::command]
pub async fn ai_post(provider: String, url: String, body: Value) -> Result<Value, RpcError> {
    check_provider(&provider)?;
    if !url_allowed(&url) {
        return Err(RpcError::new(codes::INVALID_OPTIONS, "AI endpoints must use https (or http://localhost)."));
    }
    let key = get_key(&provider)?;
    if key.is_none() && !matches!(provider.as_str(), "ollama" | "compatible") {
        return Err(RpcError::new(codes::INVALID_OPTIONS, "Add an API key in Settings › AI assistant first."));
    }
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(180))
        .build()
        .map_err(|e| RpcError::new(codes::R_ERROR, e.to_string()))?;
    let mut req = client.post(&url).json(&body);
    if let Some(k) = key {
        req = match provider.as_str() {
            "anthropic" => req.header("x-api-key", k).header("anthropic-version", "2023-06-01"),
            "gemini" => req.header("x-goog-api-key", k),
            _ => req.bearer_auth(k),
        };
    }
    let res = req.send().await.map_err(|e| RpcError::new(codes::R_ERROR, format!("Could not reach the AI service: {e}")))?;
    let status = res.status();
    let text = res.text().await.unwrap_or_default();
    let json: Value = serde_json::from_str(&text).unwrap_or(Value::String(text));
    if !status.is_success() {
        return Err(RpcError {
            code: codes::R_ERROR,
            message: format!("The AI service returned {status}"),
            data: Some(serde_json::json!({ "status": status.as_u16(), "body": json })),
        });
    }
    Ok(json)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_https_or_localhost() {
        assert!(url_allowed("https://api.anthropic.com/v1/messages"));
        assert!(url_allowed("http://localhost:11434/v1/chat/completions"));
        assert!(url_allowed("http://127.0.0.1:8080/v1"));
        assert!(!url_allowed("http://example.com/v1"));
        assert!(!url_allowed("http://localhost.evil.com/v1"));
        assert!(!url_allowed("file:///etc/passwd"));
        assert!(!url_allowed("https://"));
    }

    #[test]
    fn unknown_provider_is_rejected() {
        assert!(check_provider("anthropic").is_ok());
        assert!(check_provider("other").is_err());
    }
}
