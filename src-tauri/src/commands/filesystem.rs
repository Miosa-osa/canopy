use crate::error::CanopyError;
use serde::Serialize;

/// A directory entry returned from list_dir.
#[derive(Debug, Serialize)]
pub struct DirEntry {
    pub name: String,
    pub path: String,
    pub is_dir: bool,
}

/// List the contents of a directory.
/// Week 1: implement full recursive listing with filtering.
#[tauri::command]
pub async fn list_dir(path: String) -> Result<Vec<DirEntry>, CanopyError> {
    let read = std::fs::read_dir(&path)
        .map_err(|e| CanopyError::Filesystem(format!("Cannot read {path}: {e}")))?;

    let mut entries = Vec::new();
    for entry in read.flatten() {
        let meta = entry
            .metadata()
            .map_err(|e| CanopyError::Filesystem(e.to_string()))?;
        entries.push(DirEntry {
            name: entry.file_name().to_string_lossy().into_owned(),
            path: entry.path().to_string_lossy().into_owned(),
            is_dir: meta.is_dir(),
        });
    }

    Ok(entries)
}

/// Read a file's contents as a UTF-8 string.
/// Week 1: add size limit + binary detection.
#[tauri::command]
pub async fn read_file(path: String) -> Result<String, CanopyError> {
    std::fs::read_to_string(&path)
        .map_err(|e| CanopyError::Filesystem(format!("Cannot read {path}: {e}")))
}
