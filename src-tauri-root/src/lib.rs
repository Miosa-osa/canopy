mod filesystem;


#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_store::Builder::new().build())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_os::init())
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            filesystem::scan_canopy_dir,
            filesystem::list_canopy_agents,
            filesystem::list_canopy_projects,
            filesystem::list_canopy_schedules,
            filesystem::watch_canopy_dir,
            filesystem::scaffold_canopy_dir,
            filesystem::detect_adapters,
            filesystem::install_adapter,
            filesystem::setup_osa,
            filesystem::scan_nodes_dir,
            filesystem::read_markdown_file,
            filesystem::scan_rhythm_dir,
            filesystem::list_signal_files,
            filesystem::read_topology_yaml,
            filesystem::run_engine_command,
        ])
        .setup(|_app| {
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
