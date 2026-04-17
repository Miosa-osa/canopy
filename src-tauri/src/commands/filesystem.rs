//! Safe filesystem commands for the desktop shell.
//!
//! Week 1 guard: reject any path containing a `..` segment (defense in depth
//! against directory traversal from the frontend). A proper workspace-root
//! whitelist lands in Week 2 once `workspace:root` is wired through state.

use crate::error::CanopyError;
use serde::Serialize;
use std::path::Path;
use std::time::UNIX_EPOCH;

const MAX_READ_BYTES: u64 = 10 * 1024 * 1024;

/// A filesystem entry returned from `list_dir`.
#[derive(Debug, Serialize)]
pub struct FsEntry {
    pub name: String,
    pub is_dir: bool,
    pub size_bytes: u64,
    pub modified_unix: Option<i64>,
}

/// List a directory. Non-recursive. Returns entries in OS-native order.
#[tauri::command]
pub async fn list_dir(path: String) -> Result<Vec<FsEntry>, CanopyError> {
    guard_path(&path)?;

    let read = std::fs::read_dir(&path)
        .map_err(|e| CanopyError::Filesystem(format!("Cannot read {path}: {e}")))?;

    let mut entries = Vec::new();
    for entry in read.flatten() {
        let meta = entry
            .metadata()
            .map_err(|e| CanopyError::Filesystem(e.to_string()))?;
        entries.push(FsEntry {
            name: entry.file_name().to_string_lossy().into_owned(),
            is_dir: meta.is_dir(),
            size_bytes: meta.len(),
            modified_unix: meta
                .modified()
                .ok()
                .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
                .map(|d| d.as_secs() as i64),
        });
    }

    Ok(entries)
}

/// Read a file as UTF-8. Caps at 10MB; rejects non-UTF-8 bytes.
#[tauri::command]
pub async fn read_file(path: String) -> Result<String, CanopyError> {
    guard_path(&path)?;

    let meta = std::fs::metadata(&path)
        .map_err(|e| CanopyError::Filesystem(format!("Cannot stat {path}: {e}")))?;
    if meta.len() > MAX_READ_BYTES {
        return Err(CanopyError::Filesystem(format!(
            "File too large: {} bytes (max {MAX_READ_BYTES})",
            meta.len()
        )));
    }

    let bytes = std::fs::read(&path)
        .map_err(|e| CanopyError::Filesystem(format!("Cannot read {path}: {e}")))?;
    String::from_utf8(bytes)
        .map_err(|_| CanopyError::Filesystem(format!("File is not valid UTF-8: {path}")))
}

/// Reject paths with any `..` segment. Returns `Err` without touching disk.
fn guard_path(path: &str) -> Result<(), CanopyError> {
    if path.is_empty() {
        return Err(CanopyError::Filesystem("Empty path".into()));
    }
    let p = Path::new(path);
    for component in p.components() {
        if matches!(component, std::path::Component::ParentDir) {
            return Err(CanopyError::Filesystem(format!(
                "Path traversal rejected: {path}"
            )));
        }
    }
    // Also guard against a sneaky `..` embedded in a segment name string
    // (Path::components normalizes these out, but defence in depth).
    if path.split(&['/', '\\'][..]).any(|seg| seg == "..") {
        return Err(CanopyError::Filesystem(format!(
            "Path traversal rejected: {path}"
        )));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_empty_path() {
        assert!(guard_path("").is_err());
    }

    #[test]
    fn rejects_parent_dir_segments() {
        for bad in [
            "../etc/passwd",
            "/var/log/../../etc/passwd",
            "foo/../bar",
            "..",
            "./..",
            "a/b/../../c",
        ] {
            assert!(guard_path(bad).is_err(), "should reject: {bad}");
        }
    }

    #[test]
    fn accepts_absolute_and_relative_clean_paths() {
        for ok in [
            "/Users/alice/project",
            "./src/lib.rs",
            "src/lib.rs",
            "/",
            "a/b/c",
            "file.txt",
            "..file",       // '..' only as literal prefix, not a segment
            "foo..bar/baz", // embedded double-dot but not a segment
        ] {
            assert!(guard_path(ok).is_ok(), "should accept: {ok}");
        }
    }

    #[tokio::test]
    async fn read_file_rejects_traversal() {
        let err = read_file("../secret".into()).await.unwrap_err();
        assert!(matches!(err, CanopyError::Filesystem(_)));
    }

    #[tokio::test]
    async fn list_dir_rejects_traversal() {
        let err = list_dir("foo/../bar".into()).await.unwrap_err();
        assert!(matches!(err, CanopyError::Filesystem(_)));
    }

    #[tokio::test]
    async fn read_file_rejects_oversize() {
        use std::io::Write;
        let tmp = tempfile::NamedTempFile::new().expect("tempfile");
        // Write > MAX_READ_BYTES by seeking — sparse file, cheap on disk.
        let f = tmp.as_file();
        f.set_len(MAX_READ_BYTES + 1).expect("set_len");
        // Touch a byte to satisfy metadata len on all fs backends.
        (&mut &*f).write_all(&[0]).ok();
        let err = read_file(tmp.path().to_string_lossy().into_owned())
            .await
            .unwrap_err();
        assert!(matches!(err, CanopyError::Filesystem(_)));
    }
}
