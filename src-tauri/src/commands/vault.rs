use crate::error::CanopyError;
use keyring::Entry;

const KEYRING_SERVICE: &str = "ai.canopy.desktop";

/// Retrieve a secret from the OS keychain.
#[tauri::command]
pub async fn vault_get(key: String) -> Result<String, CanopyError> {
    let entry = Entry::new(KEYRING_SERVICE, &key)?;
    entry.get_password().map_err(CanopyError::from)
}

/// Store a secret in the OS keychain.
#[tauri::command]
pub async fn vault_put(key: String, value: String) -> Result<(), CanopyError> {
    let entry = Entry::new(KEYRING_SERVICE, &key)?;
    entry.set_password(&value).map_err(CanopyError::from)
}

/// Delete a secret from the OS keychain.
#[tauri::command]
pub async fn vault_delete(key: String) -> Result<(), CanopyError> {
    let entry = Entry::new(KEYRING_SERVICE, &key)?;
    entry.delete_credential().map_err(CanopyError::from)
}
