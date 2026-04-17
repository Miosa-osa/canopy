//! Background thread that drains a PTY and fans output out to the webview.

use super::session::PtySessions;
use serde::Serialize;
use std::io::Read;
use std::sync::{Arc, Mutex};
use std::thread;
use tauri::{AppHandle, Emitter};

const READ_BUFFER_SIZE: usize = 4096;

#[derive(Debug, Serialize, Clone)]
struct PtyOutputEvent {
    session_id: String,
    data: String,
}

#[derive(Debug, Serialize, Clone)]
struct PtyExitEvent {
    session_id: String,
}

/// Spawn a blocking thread that drains the PTY reader and forwards chunks to
/// the webview as `pty:output` events. Emits `pty:exit` + removes the session
/// from the registry on EOF.
pub(super) fn start_reader_thread(
    app: AppHandle,
    session_id: String,
    mut reader: Box<dyn Read + Send>,
    sessions: Arc<Mutex<PtySessions>>,
) {
    thread::spawn(move || {
        let mut buf = [0u8; READ_BUFFER_SIZE];
        loop {
            match reader.read(&mut buf) {
                Ok(0) => break,
                Ok(n) => {
                    let data = String::from_utf8_lossy(&buf[..n]).into_owned();
                    let _ = app.emit(
                        "pty:output",
                        PtyOutputEvent {
                            session_id: session_id.clone(),
                            data,
                        },
                    );
                }
                Err(_) => break,
            }
        }

        if let Ok(mut sessions) = sessions.lock() {
            sessions.remove(&session_id);
        }
        let _ = app.emit(
            "pty:exit",
            PtyExitEvent {
                session_id: session_id.clone(),
            },
        );
    });
}
