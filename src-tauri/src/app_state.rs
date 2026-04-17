//! Shared desktop-wide state carried via `tauri::State`.
//!
//! Owns the PTY session registry. A single `AppState` is constructed in
//! `lib.rs` and handed to the builder with `.manage(...)`.

use crate::commands::pty::PtySessions;
use std::sync::{Arc, Mutex};

/// Top-level mutable state for the desktop process.
pub struct AppState {
    pub ptys: Arc<Mutex<PtySessions>>,
}

impl AppState {
    pub fn new() -> Self {
        Self {
            ptys: Arc::new(Mutex::new(PtySessions::default())),
        }
    }
}

impl Default for AppState {
    fn default() -> Self {
        Self::new()
    }
}
