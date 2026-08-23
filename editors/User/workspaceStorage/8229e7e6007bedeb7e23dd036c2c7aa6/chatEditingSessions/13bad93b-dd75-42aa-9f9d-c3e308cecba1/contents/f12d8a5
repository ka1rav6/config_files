import { invoke } from "@tauri-apps/api/core";

export type Status = "pending" | "completed" | "archived";
export type Criticality = "low" | "normal" | "high" | "critical";

export interface Task {
  id: string;
  title: string;
  description: string | null;
  category_id: string | null;
  status: Status;
  criticality: Criticality;
  created_at: string;
  updated_at: string;
  due_at: string | null;
  completed_at: string | null;
  estimated_minutes: number | null;
  workspace_id: number | null;
  sort_order: number;
  parent_id: string | null;
}

export interface Category {
  id: string;
  name: string;
  icon: string | null;
  color: string | null;
  sort_order: number;
}

export interface TaskFilter {
  category_id?: string | null;
  status?: Status | null;
  criticality?: Criticality | null;
}

export interface TaskCounts {
  pending: number;
  critical_pending: number;
  overdue: number;
}

// Every function here is a thin, 1:1 mirror of a #[tauri::command] in
// src-tauri/src/commands/mod.rs. Keeping it flat (no client-side caching or
// derived state) means the SQLite database stays the single source of
// truth, per design doc section 47.

export const api = {
  listTasks: (filter: TaskFilter = {}) => invoke<Task[]>("list_tasks", { filter }),

  createTask: (task: {
    title: string;
    description?: string | null;
    category_id?: string | null;
    criticality?: Criticality | null;
    due_at?: string | null;
    estimated_minutes?: number | null;
    parent_id?: string | null;
  }) => invoke<Task>("create_task", { task }),

  updateTask: (id: string, patch: Partial<Task>) =>
    invoke<Task | null>("update_task", { id, patch }),

  setTaskStatus: (id: string, status: Status) =>
    invoke<Task | null>("set_task_status", { id, status }),

  deleteTask: (id: string) => invoke<void>("delete_task", { id }),

  taskCounts: () => invoke<TaskCounts>("task_counts"),

  listCategories: () => invoke<Category[]>("list_categories"),

  createCategory: (category: { id: string; name: string; icon?: string; color?: string }) =>
    invoke<Category>("create_category", { category }),

  deleteCategory: (id: string) => invoke<void>("delete_category", { id }),

  renameCategory: (id: string, name: string) => invoke<void>("rename_category", { id, name }),

  reorderCategory: (id: string, direction: number) =>
    invoke<void>("reorder_category", { id, direction }),

  getColumns: () => invoke<number>("get_columns"),

  setColumns: (n: number) => invoke<void>("set_columns", { n }),
  getPreferences: () => invoke<Record<string, unknown>>("get_preferences"),
  activeWorkspace: () => invoke<number | null>("active_workspace"),
};
