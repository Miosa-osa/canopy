//! Binary detection on `$PATH` for known AI runtime CLIs.
//!
//! For each runtime in `KNOWN_RUNTIMES` we:
//!   1. Search `$PATH` via `which`
//!   2. If found, shell `<bin> --version` (bounded 3s) and parse output
//!   3. Return a `DetectedRuntime` record for every slug — installed or not
//!
//! The frontend uses this to render the runtime dashboard: missing binaries
//! get an "Install" CTA; present ones get a version badge.

use crate::error::CanopyError;
use serde::Serialize;
use std::time::Duration;
use tokio::process::Command;
use tokio::time::timeout;

/// Runtimes we know how to detect. Slug is stable + used for Keychain
/// namespacing (`canopy.runtime.<slug>`). Binary is what lives on `$PATH`.
const KNOWN_RUNTIMES: &[(&str, &str)] = &[
    ("claude-local", "claude"),
    ("codex", "codex"),
    ("gemini", "gemini"),
    ("cursor-agent", "cursor-agent"),
    ("opencode", "opencode"),
    ("aider", "aider"),
    ("windsurf", "windsurf"),
    ("pi", "pi"),
    ("hermes", "hermes"),
];

const VERSION_TIMEOUT: Duration = Duration::from_secs(3);

/// A single runtime lookup result. `installed: false` implies `path` and
/// `version` are `None`.
#[derive(Debug, Serialize)]
pub struct DetectedRuntime {
    pub slug: String,
    pub binary: String,
    pub installed: bool,
    pub path: Option<String>,
    pub version: Option<String>,
}

/// Scan `$PATH` for every runtime in `KNOWN_RUNTIMES` and return their state.
#[tauri::command]
pub async fn runtime_detect() -> Result<Vec<DetectedRuntime>, CanopyError> {
    let mut results = Vec::with_capacity(KNOWN_RUNTIMES.len());

    for (slug, binary) in KNOWN_RUNTIMES {
        results.push(detect_one(slug, binary).await);
    }

    Ok(results)
}

/// Detect one runtime. Never returns an error — missing binaries are a
/// normal state, not a failure.
async fn detect_one(slug: &str, binary: &str) -> DetectedRuntime {
    let Ok(path) = which::which(binary) else {
        return DetectedRuntime {
            slug: slug.to_string(),
            binary: binary.to_string(),
            installed: false,
            path: None,
            version: None,
        };
    };

    let version = probe_version(binary).await;

    DetectedRuntime {
        slug: slug.to_string(),
        binary: binary.to_string(),
        installed: true,
        path: Some(path.to_string_lossy().into_owned()),
        version,
    }
}

/// Run `<binary> --version` with a hard 3s timeout. Swallow all failures —
/// absence of a version string is not a detection failure.
async fn probe_version(binary: &str) -> Option<String> {
    let mut cmd = Command::new(binary);
    cmd.arg("--version");
    cmd.kill_on_drop(true);

    let output = timeout(VERSION_TIMEOUT, cmd.output()).await.ok()?.ok()?;

    parse_version(&output.stdout, &output.stderr)
}

/// Parse version string from combined stdout+stderr. Returns the first
/// non-empty line, trimmed. Handles tools that print to stderr (e.g. `aider`).
fn parse_version(stdout: &[u8], stderr: &[u8]) -> Option<String> {
    let primary = String::from_utf8_lossy(stdout);
    if let Some(v) = first_nonempty_line(&primary) {
        return Some(v);
    }
    let secondary = String::from_utf8_lossy(stderr);
    first_nonempty_line(&secondary)
}

fn first_nonempty_line(s: &str) -> Option<String> {
    s.lines()
        .map(str::trim)
        .find(|line| !line.is_empty())
        .map(|line| line.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_version_from_stdout_single_line() {
        let version = parse_version(b"claude 1.2.3\n", b"");
        assert_eq!(version.as_deref(), Some("claude 1.2.3"));
    }

    #[test]
    fn parses_version_from_stderr_when_stdout_empty() {
        let version = parse_version(b"", b"aider 0.55.0\n");
        assert_eq!(version.as_deref(), Some("aider 0.55.0"));
    }

    #[test]
    fn returns_none_when_both_streams_empty() {
        assert_eq!(parse_version(b"", b""), None);
        assert_eq!(parse_version(b"\n\n", b"   \n"), None);
    }

    #[test]
    fn trims_whitespace_and_uses_first_nonempty_line() {
        let version = parse_version(b"\n   \nversion 2.0.0\nignored\n", b"");
        assert_eq!(version.as_deref(), Some("version 2.0.0"));
    }

    #[test]
    fn known_runtimes_slugs_are_unique() {
        let mut slugs: Vec<&str> = KNOWN_RUNTIMES.iter().map(|(slug, _)| *slug).collect();
        slugs.sort_unstable();
        let before = slugs.len();
        slugs.dedup();
        assert_eq!(before, slugs.len(), "duplicate runtime slug");
    }
}
