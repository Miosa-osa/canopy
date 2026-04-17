mod app_state;
mod commands;
mod error;

use app_state::AppState;
use commands::{filesystem, pty, runtimes, vault};

/// Application entry point called from main.rs.
/// Registers all plugins, shared state, and Tauri command handlers.
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_store::Builder::new().build())
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_shell::init())
        .manage(AppState::new())
        .invoke_handler(tauri::generate_handler![
            // PTY commands
            pty::pty_spawn,
            pty::pty_write,
            pty::pty_kill,
            // Runtime detection
            runtimes::runtime_detect,
            // Vault (OS keychain)
            vault::vault_get,
            vault::vault_put,
            vault::vault_delete,
            // Filesystem
            filesystem::list_dir,
            filesystem::read_file,
        ])
        .setup(|_app| Ok(()))
        .run(tauri::generate_context!())
        .expect("error while running Canopy application");
}
