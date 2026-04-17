use serde::Serialize;
use thiserror::Error;

/// Canonical error type for all Tauri commands.
/// Serializable so Tauri can send it to the frontend as a string.
///
/// Variants are scaffolded ahead of their first use-site in Week 1+.
/// `dead_code` is allowed because unused variants do not carry runtime cost
/// and splitting the enum per milestone would create churn on every lift.
#[allow(dead_code)]
#[derive(Debug, Error, Serialize)]
pub enum CanopyError {
    #[error("PTY error: {0}")]
    Pty(String),

    #[error("Runtime detection failed: {0}")]
    RuntimeDetect(String),

    #[error("Vault error: {0}")]
    Vault(String),

    #[error("Filesystem error: {0}")]
    Filesystem(String),

    #[error("Not implemented: {0}")]
    NotImplemented(String),

    #[error("IO error: {0}")]
    Io(String),
}

impl From<std::io::Error> for CanopyError {
    fn from(e: std::io::Error) -> Self {
        Self::Io(e.to_string())
    }
}

impl From<keyring::Error> for CanopyError {
    fn from(e: keyring::Error) -> Self {
        Self::Vault(e.to_string())
    }
}
