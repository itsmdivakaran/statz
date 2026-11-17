//! JSON-RPC 2.0 types shared with the R backend (r-backend/R/server.R).

use serde::{Deserialize, Serialize};
use serde_json::Value;

/// Error codes; keep in sync with SN_ERR in r-backend/R/util.R.
pub mod codes {
    pub const PARSE_ERROR: i64 = -32700;
    pub const METHOD_NOT_FOUND: i64 = -32601;
    pub const R_ERROR: i64 = -32001;
    pub const MISSING_PACKAGE: i64 = -32002;
    pub const INVALID_OPTIONS: i64 = -32003;
    pub const CANCELLED: i64 = -32004;
    pub const WORKER_DIED: i64 = -32005;
    pub const NOT_STARTED: i64 = -32006;
}

/// Prefix R puts on notification lines written to stderr.
pub const NOTIFY_PREFIX: &str = "\x1eSN ";

#[derive(Debug, Serialize)]
pub struct Request<'a> {
    pub jsonrpc: &'static str,
    pub id: u64,
    pub method: &'a str,
    pub params: &'a Value,
}

#[derive(Debug, Deserialize)]
pub struct Response {
    pub id: Option<Value>,
    #[serde(default)]
    pub result: Option<Value>,
    #[serde(default)]
    pub error: Option<RpcError>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RpcError {
    pub code: i64,
    pub message: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub data: Option<Value>,
}

impl RpcError {
    pub fn new(code: i64, message: impl Into<String>) -> Self {
        Self { code, message: message.into(), data: None }
    }
}

impl std::fmt::Display for RpcError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{} ({})", self.message, self.code)
    }
}

impl std::error::Error for RpcError {}

/// Parse one stdout line from R. Returns the numeric id and the outcome.
pub fn parse_response(line: &str) -> Option<(u64, Result<Value, RpcError>)> {
    let resp: Response = serde_json::from_str(line).ok()?;
    let id = resp.id?.as_u64()?;
    let outcome = match (resp.result, resp.error) {
        (_, Some(err)) => Err(err),
        (Some(v), None) => Ok(v),
        (None, None) => Ok(Value::Null),
    };
    Some((id, outcome))
}

/// Parse a stderr line; returns the notification JSON if the line carries one.
pub fn parse_notification(line: &str) -> Option<Value> {
    line.strip_prefix(NOTIFY_PREFIX).and_then(|rest| serde_json::from_str(rest).ok())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parses_result_and_error() {
        let (id, r) = parse_response(r#"{"jsonrpc":"2.0","id":7,"result":{"ok":true}}"#).unwrap();
        assert_eq!(id, 7);
        assert_eq!(r.unwrap(), json!({"ok": true}));
        let (_, e) = parse_response(
            r#"{"jsonrpc":"2.0","id":8,"error":{"code":-32003,"message":"Add a variable","data":{"role":"dv"}}}"#,
        )
        .unwrap();
        let e = e.unwrap_err();
        assert_eq!(e.code, codes::INVALID_OPTIONS);
        assert_eq!(e.data.unwrap()["role"], "dv");
    }

    #[test]
    fn ignores_non_protocol_lines() {
        assert!(parse_response("[1] 1 2 3").is_none());
        assert!(parse_notification("Warning message:").is_none());
        let n = parse_notification("\x1eSN {\"method\":\"$/progress\",\"params\":{\"pct\":50}}").unwrap();
        assert_eq!(n["params"]["pct"], 50);
    }
}
