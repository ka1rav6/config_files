// Prevents an extra console window on Windows in release builds; harmless
// (and irrelevant) on the Linux/Wayland target but kept for parity with the
// standard Tauri template.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use hyprtodo::commands;
use hyprtodo::config;
use hyprtodo::db;
use hyprtodo::state::AppState;
use hyprtodo::tasks::{self, Criticality, Status, TaskFilter};
use std::collections::HashSet;
use std::time::Duration;

fn main() {
    tracing_subscriber::fmt::init();

    let pool = db::init_pool().expect("failed to initialize database");
    if let Err(e) = config::load_and_apply(&pool) {
        tracing::warn!(error = ?e, "lua config failed to load, using existing categories");
    }

    let reminder_pool = pool.clone();
    std::thread::spawn(move || {
        let mut notified = HashSet::new();
        loop {
            if let Ok(items) = tasks::list(&reminder_pool, &TaskFilter { status: Some(Status::Pending), ..Default::default() }) {
                let now = chrono::Utc::now().to_rfc3339();
                for task in items {
                    if task.due_at.as_deref().is_some_and(|due| due <= now.as_str()) && notified.insert(task.id.clone()) {
                        let urgency = if task.criticality == Criticality::Critical { "critical" } else { "normal" };
                        let _ = std::process::Command::new("notify-send")
                            .args(["HyprTodo reminder", &task.title, "-u", urgency])
                            .status();
                    }
                }
            }
            std::thread::sleep(Duration::from_secs(60));
        }
    });

    tauri::Builder::default()
        .manage(AppState { pool })
        .invoke_handler(tauri::generate_handler![
            commands::list_tasks,
            commands::create_task,
            commands::update_task,
            commands::set_task_status,
            commands::delete_task,
            commands::task_counts,
            commands::list_categories,
            commands::create_category,
            commands::delete_category,
            commands::rename_category,
            commands::reorder_category,
            commands::get_columns,
            commands::set_columns,
            commands::get_preferences,
            commands::active_workspace,
        ])
        .run(tauri::generate_context!())
        .expect("error while running hyprtodo");
}
