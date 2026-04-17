//! Credential vault commands — thin wrappers over the OS keychain via `keyring`.
//!
//! Caller is expected to pass a namespaced `service` (e.g. `"canopy.runtime.claude-local"`)
//! and an `account` (e.g. `"api_key"`). The `keyring` crate provides per-OS backends:
//! macOS Keychain, Windows Credential Manager, Linux Secret Service.

use crate::error::CanopyError;
use keyring::{Entry, Error as KeyringError};

/// Store a secret in the OS keychain. Overwrites any existing value.
#[tauri::command]
pub async fn vault_put(
    service: String,
    account: String,
    secret: String,
) -> Result<(), CanopyError> {
    tokio::task::spawn_blocking(move || -> Result<(), CanopyError> {
        let entry = Entry::new(&service, &account)?;
        entry.set_password(&secret)?;
        Ok(())
    })
    .await
    .map_err(|e| CanopyError::Vault(format!("join error: {e}")))?
}

/// Retrieve a secret from the OS keychain.
///
/// Returns `Ok(None)` if no entry exists (maps `keyring::Error::NoEntry`).
/// Any other keychain failure is surfaced as `CanopyError::Vault(String)` with
/// the backend message — we do not leak raw `keyring::Error` types.
#[tauri::command]
pub async fn vault_get(service: String, account: String) -> Result<Option<String>, CanopyError> {
    tokio::task::spawn_blocking(move || -> Result<Option<String>, CanopyError> {
        let entry = Entry::new(&service, &account)?;
        match entry.get_password() {
            Ok(secret) => Ok(Some(secret)),
            Err(KeyringError::NoEntry) => Ok(None),
            Err(e) => Err(CanopyError::Vault(e.to_string())),
        }
    })
    .await
    .map_err(|e| CanopyError::Vault(format!("join error: {e}")))?
}

/// Delete a secret from the OS keychain. Idempotent — no error if missing.
#[tauri::command]
pub async fn vault_delete(service: String, account: String) -> Result<(), CanopyError> {
    tokio::task::spawn_blocking(move || -> Result<(), CanopyError> {
        let entry = Entry::new(&service, &account)?;
        match entry.delete_credential() {
            Ok(()) => Ok(()),
            Err(KeyringError::NoEntry) => Ok(()),
            Err(e) => Err(CanopyError::Vault(e.to_string())),
        }
    })
    .await
    .map_err(|e| CanopyError::Vault(format!("join error: {e}")))?
}
