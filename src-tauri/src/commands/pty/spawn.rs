//! Bring-up for a new PTY via `portable-pty`.

use super::session::PtySession;
use crate::error::CanopyError;
use portable_pty::{native_pty_system, CommandBuilder, PtySize};
use std::io::Read;

const DEFAULT_PTY_ROWS: u16 = 30;
const DEFAULT_PTY_COLS: u16 = 120;

/// Spawn a PTY with the requested command. Returns the populated `PtySession`
/// alongside a cloned reader handle for the output pump thread.
pub(super) fn spawn_pty(
    command: &str,
    args: &[String],
    cwd: &str,
    env: &[(String, String)],
) -> Result<(PtySession, Box<dyn Read + Send>), CanopyError> {
    let pty_system = native_pty_system();
    let pair = pty_system
        .openpty(PtySize {
            rows: DEFAULT_PTY_ROWS,
            cols: DEFAULT_PTY_COLS,
            pixel_width: 0,
            pixel_height: 0,
        })
        .map_err(|e| CanopyError::Pty(format!("openpty: {e}")))?;

    let mut cmd = CommandBuilder::new(command);
    for arg in args {
        cmd.arg(arg);
    }
    if !cwd.is_empty() {
        cmd.cwd(cwd);
    }
    for (k, v) in env {
        cmd.env(k, v);
    }

    let child = pair
        .slave
        .spawn_command(cmd)
        .map_err(|e| CanopyError::Pty(format!("spawn: {e}")))?;

    // Dropping the slave lets EOF propagate to our reader when the child exits.
    drop(pair.slave);

    let reader = pair
        .master
        .try_clone_reader()
        .map_err(|e| CanopyError::Pty(format!("clone_reader: {e}")))?;
    let writer = pair
        .master
        .take_writer()
        .map_err(|e| CanopyError::Pty(format!("take_writer: {e}")))?;

    Ok((
        PtySession {
            master: pair.master,
            writer,
            child,
        },
        reader,
    ))
}
