import { writable, get } from "svelte/store";
import { api, type Task, type Category, type Status } from "../services/api";

export const tasks = writable<Task[]>([]);
export const categories = writable<Category[]>([]);
export const loading = writable(true);
export const undoMessage = writable<string | null>(null);
let undoAction: (() => Promise<void>) | null = null;

export async function undo() {
  const action = undoAction;
  undoAction = null;
  undoMessage.set(null);
  if (action) await action();
}

export async function refresh() {
  loading.set(true);
  try {
    const [t, c] = await Promise.all([api.listTasks({}), api.listCategories()]);
    tasks.set(t);
    categories.set(c);
  } finally {
    loading.set(false);
  }
}

export async function addTask(title: string, categoryId: string | null) {
  const task = await api.createTask({ title, category_id: categoryId });
  tasks.update((all) => [...all, task]);
  return task;
}

export async function toggleStatus(id: string) {
  const current = get(tasks).find((t) => t.id === id);
  if (!current) return;
  const next: Status = current.status === "completed" ? "pending" : "completed";
  const updated = await api.setTaskStatus(id, next);
  if (updated) {
    tasks.update((all) => all.map((t) => (t.id === id ? updated : t)));
    undoAction = async () => {
      const restored = await api.setTaskStatus(id, current.status);
      if (restored) tasks.update((all) => all.map((t) => (t.id === id ? restored : t)));
    };
    undoMessage.set(next === "completed" ? "Task completed" : "Task reopened");
  }
}

export async function removeTask(id: string) {
  const removed = get(tasks).find((t) => t.id === id);
  if (!removed) return;
  await api.deleteTask(id);
  tasks.update((all) => all.filter((t) => t.id !== id));
  undoAction = async () => {
    const restored = await api.createTask(removed);
    tasks.update((all) => [...all, restored]);
  };
  undoMessage.set("Task deleted");
}

export async function updateTask(id: string, patch: Partial<Task>) {
  const previous = get(tasks).find((t) => t.id === id);
  const updated = await api.updateTask(id, patch);
  if (updated) {
    tasks.update((all) => all.map((t) => (t.id === id ? updated : t)));
    if (previous) {
      undoAction = async () => {
        const restored = await api.updateTask(id, previous);
        if (restored) tasks.update((all) => all.map((t) => (t.id === id ? restored : t)));
      };
      undoMessage.set("Task updated");
    }
  }
  return updated;
}
