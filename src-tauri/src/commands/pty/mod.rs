//! PTY lifecycle commands backed by `portable-pty`.
//!
//! Public surface:
//!   * [`pty_spawn`] / [`pty_write`] / [`pty_kill`]  — Tauri commands
//!   * [`PtySessions`] / [`PtyHandle`]               — state + return types
//!
//! Submodules:
//!   * `session` — registry + per-session struct
//!   * `spawn`   — `portable-pty` bring-up
//!   * `reader`  — background thread pumping output to the webview

mod reader;
mod session;
mod spawn;

use crate::app_state::AppState;
use crate::error::CanopyError;
use serde::Serialize;
use std::io::Write;
use tauri::{AppHandle, State};

pub use session::PtySessions;

/// Returned to the frontend when a PTY spawns successfully.
#[derive(Debug, Serialize)]
pub struct PtyHandle {
    pub session_id: String,
}

/// Spawn a command inside a new PTY and begin streaming its output to the
/// frontend via the `pty:output` event. Returns the assigned session id.
#[tauri::command]
pub async fn pty_spawn(
    command: String,
    args: Vec<String>,
    cwd: String,
    env: Vec<(String, String)>,
    app: AppHandle,
    state: State<'_, AppState>,
) -> Result<PtyHandle, CanopyError> {
    let session_id = session::generate_session_id();
    let sessions = state.ptys.clone();

    let (pty_session, output_reader) = spawn::spawn_pty(&command, &args, &cwd, &env)?;

    sessions
        .lock()
        .map_err(|e| CanopyError::Pty(format!("state lock poisoned: {e}")))?
        .insert(session_id.clone(), pty_session);

    reader::start_reader_thread(app, session_id.clone(), output_reader, sessions);

    Ok(PtyHandle { session_id })
}

/// Write UTF-8 data to a live PTY session's stdin.
#[tauri::command]
pub fn pty_write(
    session_id: String,
    data: String,
    state: State<'_, AppState>,
) -> Result<(), CanopyError> {
    let mut sessions = state
        .ptys
        .lock()
        .map_err(|e| CanopyError::Pty(format!("state lock poisoned: {e}")))?;

    let wrote = sessions.with_mut(&session_id, |session| {
        session
            .writer
            .write_all(data.as_bytes())
            .and_then(|()| session.writer.flush())
    });

    match wrote {
        Some(Ok(())) => Ok(()),
        Some(Err(e)) => Err(CanopyError::Pty(format!("write failed: {e}"))),
        None => Err(CanopyError::Pty(format!("unknown session: {session_id}"))),
    }
}

/// Kill a live PTY session and remove it from the registry. Idempotent: if
/// the session is already gone we return `Ok(())`.
#[tauri::command]
pub fn pty_kill(session_id: String, state: State<'_, AppState>) -> Result<(), CanopyError> {
    let mut sessions = state
        .ptys
        .lock()
        .map_err(|e| CanopyError::Pty(format!("state lock poisoned: {e}")))?;

    match sessions.remove(&session_id) {
        Some(mut session) => session
            .child
            .kill()
            .map_err(|e| CanopyError::Pty(format!("kill failed: {e}"))),
        None => Ok(()),
    }
}
