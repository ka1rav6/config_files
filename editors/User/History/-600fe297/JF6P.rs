use crate::db::Pool;
use anyhow::{Context, Result};
use rusqlite::{params, OptionalExtension, Row};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum Status {
    Pending,
    Completed,
    Archived,
}

impl Status {
    fn as_str(&self) -> &'static str {
        match self {
            Status::Pending => "pending",
            Status::Completed => "completed",
            Status::Archived => "archived",
        }
    }
    fn from_str(s: &str) -> Self {
        match s {
            "completed" => Status::Completed,
            "archived" => Status::Archived,
            _ => Status::Pending,
        }
    }
}

// Criticality is a semantic value, not a color (design doc section 7):
// the frontend/theme decides presentation.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "lowercase")]
pub enum Criticality {
    Low,
    Normal,
    High,
    Critical,
}

impl Criticality {
    fn as_str(&self) -> &'static str {
        match self {
            Criticality::Low => "low",
            Criticality::Normal => "normal",
            Criticality::High => "high",
            Criticality::Critical => "critical",
        }
    }
    fn from_str(s: &str) -> Self {
        match s {
            "low" => Criticality::Low,
            "high" => Criticality::High,
            "critical" => Criticality::Critical,
            _ => Criticality::Normal,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    pub id: String,
    pub title: String,
    pub description: Option<String>,
    pub category_id: Option<String>,
    pub status: Status,
    pub criticality: Criticality,
    pub created_at: String,
    pub updated_at: String,
    pub due_at: Option<String>,
    pub completed_at: Option<String>,
    pub estimated_minutes: Option<i64>,
    pub workspace_id: Option<i64>,
    pub sort_order: i64,
    pub parent_id: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct NewTask {
    pub title: String,
    pub description: Option<String>,
    pub category_id: Option<String>,
    pub criticality: Option<Criticality>,
    pub due_at: Option<String>,
    pub estimated_minutes: Option<i64>,
    pub parent_id: Option<String>,
    pub workspace_id: Option<i64>,
}

#[derive(Debug, Default, Deserialize)]
pub struct TaskFilter {
    pub category_id: Option<String>,
    pub status: Option<Status>,
    pub criticality: Option<Criticality>,
}

fn row_to_task(row: &Row) -> rusqlite::Result<Task> {
    Ok(Task {
        id: row.get("id")?,
        title: row.get("title")?,
        description: row.get("description")?,
        category_id: row.get("category_id")?,
        status: Status::from_str(&row.get::<_, String>("status")?),
        criticality: Criticality::from_str(&row.get::<_, String>("criticality")?),
        created_at: row.get("created_at")?,
        updated_at: row.get("updated_at")?,
        due_at: row.get("due_at")?,
        completed_at: row.get("completed_at")?,
        estimated_minutes: row.get("estimated_minutes")?,
        workspace_id: row.get("workspace_id")?,
        sort_order: row.get("sort_order")?,
        parent_id: row.get("parent_id")?,
    })
}

const SELECT_COLS: &str = "id, title, description, category_id, status, criticality, \
     created_at, updated_at, due_at, completed_at, estimated_minutes, \
     workspace_id, sort_order, parent_id";

pub fn create(pool: &Pool, new: NewTask) -> Result<Task> {
    let conn = pool.get()?;
    let id = Uuid::new_v4().to_string();
    let criticality = new.criticality.unwrap_or(Criticality::Normal);
    conn.execute(
        "INSERT INTO tasks (id, title, description, category_id, criticality, due_at, \
         estimated_minutes, parent_id, workspace_id) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
        params![
            id,
            new.title,
            new.description,
            new.category_id,
            criticality.as_str(),
            new.due_at,
            new.estimated_minutes,
            new.parent_id,
            new.workspace_id,
        ],
    )
    .context("inserting task")?;
    get(pool, &id)?.context("task disappeared immediately after insert")
}

pub fn get(pool: &Pool, id: &str) -> Result<Option<Task>> {
    let conn = pool.get()?;
    let task = conn
        .query_row(
            &format!("SELECT {SELECT_COLS} FROM tasks WHERE id = ?1"),
            params![id],
            row_to_task,
        )
        .optional()
        .context("querying task by id")?;
    Ok(task)
}

pub fn list(pool: &Pool, filter: &TaskFilter) -> Result<Vec<Task>> {
    let conn = pool.get()?;
    let mut sql = format!("SELECT {SELECT_COLS} FROM tasks WHERE 1=1");
    let mut binds: Vec<Box<dyn rusqlite::ToSql>> = Vec::new();

    if let Some(cat) = &filter.category_id {
        sql.push_str(" AND category_id = ?");
        binds.push(Box::new(cat.clone()));
    }
    if let Some(status) = &filter.status {
        sql.push_str(" AND status = ?");
        binds.push(Box::new(status.as_str().to_string()));
    }
    if let Some(crit) = &filter.criticality {
        sql.push_str(" AND criticality = ?");
        binds.push(Box::new(crit.as_str().to_string()));
    }
    sql.push_str(" ORDER BY sort_order ASC, created_at ASC");

    let mut stmt = conn.prepare(&sql).context("preparing task list query")?;
    let params_refs: Vec<&dyn rusqlite::ToSql> = binds.iter().map(|b| b.as_ref()).collect();
    let rows = stmt
        .query_map(params_refs.as_slice(), row_to_task)
        .context("executing task list query")?;

    let mut out = Vec::new();
    for r in rows {
        out.push(r?);
    }
    Ok(out)
}

#[derive(Debug, Default, Deserialize)]
pub struct TaskUpdate {
    pub title: Option<String>,
    pub description: Option<String>,
    pub category_id: Option<String>,
    pub criticality: Option<Criticality>,
    pub due_at: Option<String>,
    pub estimated_minutes: Option<i64>,
    pub sort_order: Option<i64>,
}

pub fn update(pool: &Pool, id: &str, patch: TaskUpdate) -> Result<Option<Task>> {
    let conn = pool.get()?;
    conn.execute(
        "UPDATE tasks SET
            title              = COALESCE(?2, title),
            description        = COALESCE(?3, description),
            category_id        = COALESCE(?4, category_id),
            criticality        = COALESCE(?5, criticality),
            due_at             = COALESCE(?6, due_at),
            estimated_minutes  = COALESCE(?7, estimated_minutes),
            sort_order         = COALESCE(?8, sort_order),
            updated_at         = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
         WHERE id = ?1",
        params![
            id,
            patch.title,
            patch.description,
            patch.category_id,
            patch.criticality.map(|c| c.as_str().to_string()),
            patch.due_at,
            patch.estimated_minutes,
            patch.sort_order,
        ],
    )
    .context("updating task")?;
    drop(conn);
    get(pool, id)
}

/// Toggles between pending and completed. This is the `Space` / `c` action
/// from the keyboard system (design doc section 19) and drives the
/// completed_at timestamp used for "done" filtering.
pub fn set_status(pool: &Pool, id: &str, status: Status) -> Result<Option<Task>> {
    let conn = pool.get()?;
    let completed_at = matches!(status, Status::Completed).then(|| chrono_now());
    conn.execute(
        "UPDATE tasks SET status = ?2, completed_at = ?3,
            updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
         WHERE id = ?1",
        params![id, status.as_str(), completed_at],
    )
    .context("updating task status")?;
    drop(conn);
    get(pool, id)
}

pub fn delete(pool: &Pool, id: &str) -> Result<()> {
    let conn = pool.get()?;
    conn.execute("DELETE FROM tasks WHERE id = ?1", params![id])
        .context("deleting task")?;
    Ok(())
}

/// Summary counts used by the Waybar module (design doc section 15) and the
/// dashboard header. Kept as a single cheap query rather than three round
/// trips, per the "minimize database queries" principle (section 2.2).
#[derive(Debug, Serialize)]
pub struct TaskCounts {
    pub pending: i64,
    pub critical_pending: i64,
    pub overdue: i64,
}

pub fn counts(pool: &Pool) -> Result<TaskCounts> {
    let conn = pool.get()?;
    let mut stmt = conn.prepare(
        "SELECT
            SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END),
            SUM(CASE WHEN status = 'pending' AND criticality = 'critical' THEN 1 ELSE 0 END),
            SUM(CASE WHEN status = 'pending' AND due_at IS NOT NULL
                     AND due_at < strftime('%Y-%m-%dT%H:%M:%fZ', 'now') THEN 1 ELSE 0 END)
         FROM tasks",
    )?;
    let (pending, critical_pending, overdue): (Option<i64>, Option<i64>, Option<i64>) =
        stmt.query_row([], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))?;
    Ok(TaskCounts {
        pending: pending.unwrap_or(0),
        critical_pending: critical_pending.unwrap_or(0),
        overdue: overdue.unwrap_or(0),
    })
}

/// Matches SQLite's `strftime('%Y-%m-%dT%H:%M:%fZ', 'now')` format exactly
/// (millisecond precision, trailing `Z`) so `completed_at` sorts and
/// compares correctly against `created_at`/`updated_at`/`due_at`, all of
/// which are stamped by SQLite itself rather than by this Rust code.
fn chrono_now() -> String {
    chrono::Utc::now().format("%Y-%m-%dT%H:%M:%S%.3fZ").to_string()
}
