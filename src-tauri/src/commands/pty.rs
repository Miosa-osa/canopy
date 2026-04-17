use crate::error::CanopyError;

/// Spawn a PTY session for an agent runtime process.
/// Week 1: implement with portable-pty.
#[tauri::command]
pub async fn pty_spawn(
    _runtime: String,
    _cwd: String,
    _env: Vec<(String, String)>,
) -> Result<String, CanopyError> {
    Err(CanopyError::NotImplemented("pty_spawn — Week 1".into()))
}

/// Write bytes to a running PTY session.
#[tauri::command]
pub async fn pty_write(_session_id: String, _data: String) -> Result<(), CanopyError> {
    Err(CanopyError::NotImplemented("pty_write — Week 1".into()))
}

/// Kill a running PTY session.
#[tauri::command]
pub async fn pty_kill(_session_id: String) -> Result<(), CanopyError> {
    Err(CanopyError::NotImplemented("pty_kill — Week 1".into()))
}
