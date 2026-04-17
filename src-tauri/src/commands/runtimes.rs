use crate::error::CanopyError;
use serde::Serialize;

/// A detected AI runtime binary on PATH.
#[derive(Debug, Serialize)]
pub struct DetectedRuntime {
    pub slug: String,
    pub path: String,
    pub version: Option<String>,
}

/// Scan PATH for known AI runtime binaries.
/// Week 1: implement per-adapter detection logic.
#[tauri::command]
pub async fn runtime_detect() -> Result<Vec<DetectedRuntime>, CanopyError> {
    // Stub — returns empty list until Week 1 adapter implementations land.
    Ok(vec![])
}
