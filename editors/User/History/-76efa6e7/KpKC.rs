use crate::categories::{self, Category, NewCategory};
use crate::db;
use crate::state::AppState;
use crate::tasks::{self, NewTask, Status, Task, TaskCounts, TaskFilter, TaskUpdate};
use tauri::State;

// Every command returns Result<T, String> because Tauri serializes the Err
// variant to the frontend as a plain string; internal errors already carry
// full anyhow context via tracing, so we log-then-flatten here.

fn flatten<T>(r: anyhow::Result<T>) -> Result<T, String> {
    r.map_err(|e| {
        tracing::error!(error = ?e, "command failed");
        e.to_string()
    })
}

#[tauri::command]
pub fn list_tasks(state: State<AppState>, filter: TaskFilter) -> Result<Vec<Task>, String> {
    flatten(tasks::list(&state.pool, &filter))
}

#[tauri::command]
pub fn create_task(state: State<AppState>, task: NewTask) -> Result<Task, String> {
    flatten(tasks::create(&state.pool, task))
}

#[tauri::command]
pub fn update_task(
    state: State<AppState>,
    id: String,
    patch: TaskUpdate,
) -> Result<Option<Task>, String> {
    flatten(tasks::update(&state.pool, &id, patch))
}

#[tauri::command]
pub fn set_task_status(
    state: State<AppState>,
    id: String,
    status: Status,
) -> Result<Option<Task>, String> {
    flatten(tasks::set_status(&state.pool, &id, status))
}

#[tauri::command]
pub fn delete_task(state: State<AppState>, id: String) -> Result<(), String> {
    flatten(tasks::delete(&state.pool, &id))
}

#[tauri::command]
pub fn task_counts(state: State<AppState>) -> Result<TaskCounts, String> {
    flatten(tasks::counts(&state.pool))
}

#[tauri::command]
pub fn list_categories(state: State<AppState>) -> Result<Vec<Category>, String> {
    flatten(categories::list(&state.pool))
}

#[tauri::command]
pub fn create_category(state: State<AppState>, category: NewCategory) -> Result<Category, String> {
    flatten(categories::create(&state.pool, category))
}

#[tauri::command]
pub fn delete_category(state: State<AppState>, id: String) -> Result<(), String> {
    flatten(categories::delete(&state.pool, &id))
}

#[tauri::command]
pub fn rename_category(state: State<AppState>, id: String, name: String) -> Result<(), String> {
    flatten(categories::rename(&state.pool, &id, &name))
}

/// direction: -1 moves the category one slot left/up, +1 moves it right/down.
#[tauri::command]
pub fn reorder_category(state: State<AppState>, id: String, direction: i32) -> Result<(), String> {
    flatten(categories::reorder(&state.pool, &id, direction))
}

#[tauri::command]
pub fn get_columns(state: State<AppState>) -> Result<u32, String> {
    flatten(
        db::get_meta(&state.pool, "columns")
            .map(|v| v.and_then(|s| s.parse().ok()).unwrap_or(2)),
    )
}

#[tauri::command]
pub fn set_columns(state: State<AppState>, n: u32) -> Result<(), String> {
    flatten(db::set_meta(&state.pool, "columns", &n.clamp(1, 6).to_string()))
}

#[tauri::command]
pub fn get_preferences(state: State<AppState>) -> Result<serde_json::Value, String> {
    flatten(db::get_meta(&state.pool, "preferences").map(|value| {
        value.and_then(|raw| serde_json::from_str(&raw).ok()).unwrap_or_else(|| serde_json::json!({}))
    }))
}

#[tauri::command]
pub fn active_workspace() -> Result<Option<i64>, String> {
    let output = std::process::Command::new("hyprctl")
        .args(["-j", "activeworkspace"])
        .output()
        .map_err(|e| e.to_string())?;
    if !output.status.success() {
        return Ok(None);
    }
    Ok(serde_json::from_slice::<serde_json::Value>(&output.stdout)
        .ok()
        .and_then(|value| value.get("id").and_then(|id| id.as_i64())))
}
