//! PTY session state. One `PtySession` per live child; all sessions live in
//! `PtySessions`, which is wrapped in the shared `AppState`.

use portable_pty::{Child, MasterPty};
use std::collections::HashMap;
use std::io::Write;
use std::time::{SystemTime, UNIX_EPOCH};

/// One live PTY session.
pub struct PtySession {
    pub(super) master: Box<dyn MasterPty + Send>,
    pub(super) writer: Box<dyn Write + Send>,
    pub(super) child: Box<dyn Child + Send + Sync>,
}

impl std::fmt::Debug for PtySession {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("PtySession")
            .field("pid", &self.child.process_id())
            .field("master_size", &self.master.get_size().ok())
            .finish()
    }
}

/// Registry of active PTY sessions.
#[derive(Default)]
pub struct PtySessions {
    sessions: HashMap<String, PtySession>,
}

impl PtySessions {
    pub(super) fn insert(&mut self, id: String, session: PtySession) {
        self.sessions.insert(id, session);
    }

    pub(super) fn remove(&mut self, id: &str) -> Option<PtySession> {
        self.sessions.remove(id)
    }

    pub(super) fn with_mut<R>(
        &mut self,
        id: &str,
        f: impl FnOnce(&mut PtySession) -> R,
    ) -> Option<R> {
        self.sessions.get_mut(id).map(f)
    }
}

/// Generate a process-unique session id. A `(pid, nanos)` combo is collision
/// free under realistic load without pulling in a `uuid` crate.
pub(super) fn generate_session_id() -> String {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    format!("pty-{}-{:x}", std::process::id(), nanos)
}
