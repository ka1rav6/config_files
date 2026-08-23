<script lang="ts">
  import { onMount } from "svelte";
  import { get } from "svelte/store";
  import "./lib/styles/theme.css";
  import { api } from "./lib/services/api";
  import { tasks, categories, loading, refresh, addTask, toggleStatus, removeTask, removeCategory, updateTask, undoMessage, undo } from "./lib/stores/tasks";
  import { mode, focusedPanel, focusedTaskIndex, helpVisible, renameTarget } from "./lib/stores/keyboard";
  import { columns, loadColumns, changeColumns } from "./lib/stores/layout";
  import Dashboard from "./lib/components/Dashboard.svelte";
  import PromptModal from "./lib/components/PromptModal.svelte";
  import HelpOverlay from "./lib/components/HelpOverlay.svelte";
  import TaskModal from "./lib/components/TaskModal.svelte";

  let dashboard: Dashboard;
  let editingTask: import("./lib/services/api").Task | null = null;
  let search = "";
  let statusFilter = "pending";
  let criticalityFilter = "all";
  let sortMode = "created";
  let workspaceId: number | null = null;
  let searchInput: HTMLInputElement;

  onMount(() => {
    refresh();
    loadColumns();
    api.activeWorkspace().then((id) => (workspaceId = id));
    api.getPreferences().then((preferences) => {
      const theme = (preferences.theme ?? {}) as Record<string, string | null>;
      for (const [key, value] of Object.entries(theme)) {
        if (value) document.documentElement.style.setProperty(`--${key.replaceAll("_", "-")}`, value);
      }
    });
  });

  $: pendingCount = $tasks.filter((t) => t.status === "pending").length;
  $: visibleTasks = $tasks
    .filter((t) => !search.trim() || `${t.title} ${t.description ?? ""}`.toLowerCase().includes(search.toLowerCase()))
    .filter((t) => statusFilter === "all" || t.status === statusFilter)
    .filter((t) => criticalityFilter === "all" || t.criticality === criticalityFilter)
    .filter((t) => workspaceId === null || t.workspace_id === null || t.workspace_id === workspaceId)
    .sort((a, b) => sortMode === "due" ? (a.due_at ?? "9999").localeCompare(b.due_at ?? "9999") : sortMode === "criticality" ? b.criticality.localeCompare(a.criticality) : b.created_at.localeCompare(a.created_at));

  function categoryLabel(): string {
    const id = dashboard?.categoryIdFor($focusedPanel);
    if (!id || id === "critical") return "General";
    return $categories.find((c) => c.id === id)?.name ?? "General";
  }

  function slugify(name: string): string {
    return (
      name
        .toLowerCase()
        .trim()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/(^-|-$)/g, "") || `cat-${Date.now()}`
    );
  }

  async function moveFocusedCategory(direction: 1 | -1) {
    const id = dashboard?.categoryIdFor($focusedPanel);
    if (!id || id === "critical") return;
    await api.reorderCategory(id, direction);
    await refresh();
    const idx = get(categories).findIndex((c) => c.id === id);
    if (idx >= 0) focusedPanel.set(idx);
  }

  // Shift+D: delete the focused category. Its tasks are kept but become
  // uncategorized (FK ON DELETE SET NULL). The Critical panel is synthetic
  // and can't be deleted. Note: a category still defined in config.lua will
  // be re-created by the Lua upsert on next launch.
  async function deleteFocusedCategory() {
    const id = dashboard?.categoryIdFor($focusedPanel);
    if (!id || id === "critical") return;
    await removeCategory(id);
    focusedTaskIndex.set(0);
    // panels = categories + critical; clamp focus into the new range
    const lastValid = get(categories).length;
    if ($focusedPanel > lastValid) focusedPanel.set(lastValid);
  }

  function onKeydown(e: KeyboardEvent) {
    if ($mode !== "normal") return;

    // Shift+H: full shortcut list, works regardless of anything else.
    if (e.key === "H") {
      helpVisible.set(true);
      return;
    }

    const panelCount = dashboard?.panelCount() ?? 0;

    switch (e.key) {
      case "j":
      case "ArrowDown": {
        const count = dashboard?.itemCountFor($focusedPanel) ?? 0;
        if (count > 0) focusedTaskIndex.update((i) => Math.min(i + 1, count - 1));
        e.preventDefault();
        break;
      }
      case "k":
      case "ArrowUp":
        focusedTaskIndex.update((i) => Math.max(i - 1, 0));
        e.preventDefault();
        break;
      case "Tab":
        e.preventDefault();
        if (panelCount === 0) break;
        if (e.shiftKey) {
          focusedPanel.update((p) => (p - 1 + panelCount) % panelCount);
        } else {
          focusedPanel.update((p) => (p + 1) % panelCount);
        }
        focusedTaskIndex.set(0);
        break;
      case "ArrowRight":
      case "l":
        e.preventDefault();
        if (e.ctrlKey) {
          moveFocusedCategory(1);
        } else if (panelCount > 0) {
          focusedPanel.update((p) => (p + 1) % panelCount);
          focusedTaskIndex.set(0);
        }
        break;
      case "ArrowLeft":
      case "h":
        e.preventDefault();
        if (e.ctrlKey) {
          moveFocusedCategory(-1);
        } else if (panelCount > 0) {
          focusedPanel.update((p) => (p - 1 + panelCount) % panelCount);
          focusedTaskIndex.set(0);
        }
        break;
      case " ":
      case "c": {
        const t = dashboard?.focusedTask();
        if (t) toggleStatus(t.id);
        e.preventDefault();
        break;
      }
      case "d": {
        const t = dashboard?.focusedTask();
        if (t) removeTask(t.id);
        break;
      }
      case "e": {
        const t = dashboard?.focusedTask();
        if (t) editingTask = t;
        break;
      }
      case "u":
        undo();
        break;
      case "a":
        e.preventDefault();
        mode.set("addingTask");
        break;
      case "/":
        e.preventDefault();
        searchInput?.focus();
        break;
      case "A":
        mode.set("addingCategory");
        break;
      case "r": {
        const id = dashboard?.categoryIdFor($focusedPanel);
        if (id && id !== "critical") {
          renameTarget.set(id);
          mode.set("renamingCategory");
        }
        break;
      }
      case "D":
        deleteFocusedCategory();
        break;
      case "-":
        changeColumns(-1);
        break;
      case "=":
      case "+":
        changeColumns(1);
        break;
      case "Escape":
        helpVisible.set(false);
        break;
      default:
        if (e.key >= "1" && e.key <= "9") {
          const idx = Number(e.key) - 1;
          if (idx < panelCount) {
            focusedPanel.set(idx);
            focusedTaskIndex.set(0);
          }
        }
    }
  }

  async function onAddTaskSubmit(e: CustomEvent<Record<string, unknown>>) {
    const detail = e.detail as unknown as string | { title: string; [key: string]: unknown };
    if (typeof detail === "string") {
      await addTask(detail, null, workspaceId);
    } else {
      await api.createTask({ ...detail, workspace_id: workspaceId, category_id: null } as { title: string; category_id: string | null; workspace_id: number | null });
      await refresh();
    }
    mode.set("normal");
  }

  async function onAddCategorySubmit(e: CustomEvent<string>) {
    await api.createCategory({ id: slugify(e.detail), name: e.detail });
    await refresh();
    mode.set("normal");
  }

  async function onRenameCategorySubmit(e: CustomEvent<string>) {
    const id = get(renameTarget);
    if (id) {
      await api.renameCategory(id, e.detail);
      await refresh();
    }
    mode.set("normal");
  }

  async function onEditTaskSubmit(e: CustomEvent<Record<string, unknown>>) {
    if (editingTask) await updateTask(editingTask.id, e.detail);
    editingTask = null;
  }
</script>

<svelte:window on:keydown={onKeydown} />

<main>
  <header class="titlebar">
    <h1>HyprTodo</h1>
    <input class="search" bind:this={searchInput} bind:value={search} placeholder="Find a task" aria-label="Find a task" />
    <select bind:value={statusFilter} aria-label="Status filter"><option value="all">All</option><option value="pending">Pending</option><option value="completed">Done</option></select>
    <select bind:value={criticalityFilter} aria-label="Criticality filter"><option value="all">Any priority</option><option value="critical">Critical</option><option value="high">High</option><option value="normal">Normal</option><option value="low">Low</option></select>
    <select bind:value={sortMode} aria-label="Sort tasks"><option value="created">Newest</option><option value="due">Due date</option><option value="criticality">Priority</option></select>
    <span class="summary">{pendingCount} tasks</span>
  </header>

  {#if $loading}
    <p class="status">loading…</p>
  {:else}
    <Dashboard
      bind:this={dashboard}
      tasks={visibleTasks}
      categories={$categories}
      focusedPanel={$focusedPanel}
      focusedTaskIndex={$focusedTaskIndex}
      columns={$columns}
      onTaskClick={(task) => (editingTask = task)}
    />
  {/if}
</main>

{#if $mode === "addingTask"}
  <TaskModal categories={$categories} showCategory={false} on:submit={onAddTaskSubmit} on:cancel={() => mode.set("normal")} />
{:else if $mode === "addingCategory"}
  <PromptModal
    label="New category name"
    placeholder="e.g. Research"
    on:submit={onAddCategorySubmit}
    on:cancel={() => mode.set("normal")}
  />
{:else if $mode === "renamingCategory"}
  <PromptModal
    label="Rename category"
    initial={$categories.find((c) => c.id === $renameTarget)?.name ?? ""}
    on:submit={onRenameCategorySubmit}
    on:cancel={() => mode.set("normal")}
  />
{/if}

{#if editingTask}
  <TaskModal task={editingTask} categories={$categories} on:submit={onEditTaskSubmit} on:cancel={() => (editingTask = null)} />
{/if}
{#if $undoMessage}<button class="undo" on:click={undo}>{$undoMessage} · Undo (u)</button>{/if}

{#if $helpVisible}
  <HelpOverlay on:close={() => helpVisible.set(false)} />
{/if}

<style>
  main {
    display: flex;
    flex-direction: column;
    height: 100vh;
  }
  .titlebar {
    display: flex;
    align-items: center;
    padding: 10px 16px;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }
  h1 {
    font-family: var(--font-heading);
    font-size: 1em;
    margin: 0;
    flex: 1;
    letter-spacing: 0.02em;
  }
  .summary {
    color: var(--muted);
    font-family: var(--font-mono);
    font-size: 0.85em;
    margin-left: 2px;
  }
  .search, select, button { color: var(--foreground); background: var(--control-bg); border: 1px solid var(--control-border); border-radius: calc(var(--radius) / 2); padding: 6px 8px; margin-left: 8px; }
  select:hover, button:hover { background: var(--control-hover); }
  .search:focus, select:focus, button:focus-visible { outline: 2px solid var(--accent); outline-offset: 1px; }
  .search { min-width: 150px; flex: 0 1 220px; }
  .undo { position: fixed; right: 18px; bottom: 18px; z-index: 4; color: var(--foreground); background: var(--control-bg); border: 1px solid var(--accent); border-radius: var(--radius); padding: 10px 14px; }
  .status {
    padding: 24px;
    color: var(--muted);
  }
</style>
