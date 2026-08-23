<script lang="ts">
  import { createEventDispatcher, onMount } from "svelte";
  import type { Category, Criticality, Task } from "../services/api";

  export let task: Task | null = null;
  export let categories: Category[] = [];
  export let showCategory = true;
  const dispatch = createEventDispatcher<{ submit: Record<string, unknown>; cancel: void }>();
  let title = task?.title ?? "";
  let description = task?.description ?? "";
  let criticality: Criticality = task?.criticality ?? "normal";
  let due_at = task?.due_at?.slice(0, 16) ?? "";
  let estimated_minutes = task?.estimated_minutes?.toString() ?? "";
  let category_id = task?.category_id ?? "";
  let input: HTMLInputElement;

  onMount(() => input?.focus());
  function submit() {
    if (!title.trim()) return;
    dispatch("submit", {
      title: title.trim(), description: description || null, criticality,
      due_at: due_at ? new Date(due_at).toISOString() : null,
      estimated_minutes: estimated_minutes ? Number(estimated_minutes) : null,
      category_id: category_id || null,
    });
  }
</script>

<div class="backdrop" role="presentation" tabindex="-1" on:keydown|stopPropagation={(event) => event.key === "Escape" && dispatch("cancel")} on:click|self={() => dispatch("cancel")}>
  <form class="box" on:submit|preventDefault={submit}>
    <h2>{task ? "Edit task" : "New task"}</h2>
    <input bind:this={input} bind:value={title} placeholder="Task title" aria-label="Task title" />
    <textarea bind:value={description} placeholder="Description" aria-label="Description" rows="3"></textarea>
    <div class="row">
      <select bind:value={criticality} aria-label="Criticality">
        <option value="low">Low</option><option value="normal">Normal</option>
        <option value="high">High</option><option value="critical">Critical</option>
      </select>
      <input type="datetime-local" bind:value={due_at} aria-label="Due date" />
    </div>
    {#if showCategory}
    <div class="row">
      <input type="number" min="1" bind:value={estimated_minutes} placeholder="Minutes" aria-label="Estimated minutes" />
      <select bind:value={category_id} aria-label="Category">
        <option value="">Uncategorized</option>
        {#each categories as category}<option value={category.id}>{category.name}</option>{/each}
      </select>
    </div>
    {:else}
      <input type="number" min="1" bind:value={estimated_minutes} placeholder="Minutes" aria-label="Estimated minutes" />
    {/if}
    <div class="actions"><button type="button" on:click={() => dispatch("cancel")}>Cancel</button><button class="primary" type="submit">{task ? "Save" : "Add"}</button></div>
  </form>
</div>

<style>
  .backdrop { position: fixed; inset: 0; display: grid; place-items: center; background: rgba(0,0,0,.58); z-index: 5; }
  .box { width: min(520px, 92vw); display: grid; gap: 12px; padding: 22px; background: var(--panel-bg); border: 1px solid var(--border); border-radius: var(--radius); }
  h2 { margin: 0 0 4px; font-family: var(--font-heading); }
  input, textarea, select, button { font: inherit; color: var(--foreground); background: var(--background); border: 1px solid var(--border); border-radius: calc(var(--radius) / 2); padding: 9px 10px; }
  textarea { resize: vertical; }
  .row { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
  .actions { display: flex; justify-content: flex-end; gap: 8px; margin-top: 4px; }
  button { cursor: pointer; } .primary { background: var(--accent); color: var(--background); border-color: var(--accent); }
</style>
