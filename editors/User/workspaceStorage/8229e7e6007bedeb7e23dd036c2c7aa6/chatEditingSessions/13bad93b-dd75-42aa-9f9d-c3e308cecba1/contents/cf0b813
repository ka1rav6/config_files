<script lang="ts">
  import type { Task } from "../services/api";
  import TaskCard from "./TaskCard.svelte";

  export let title: string;
  export let icon: string | undefined = undefined;
  export let color: string | undefined = undefined;
  export let items: Task[];
  export let panelIndex: number;
  export let focusedPanel: number;
  export let focusedTaskIndex: number;
  export let onTaskClick: (task: Task) => void = () => {};

  $: isFocused = panelIndex === focusedPanel;
</script>

<section class="panel" class:focused={isFocused} style={color ? `--panel-accent: ${color}` : ""}>
  <header>
    {#if icon}<span class="icon">{icon}</span>{/if}
    <h2>{title}</h2>
    <span class="count">{items.length}</span>
  </header>
  <div class="items">
    {#if items.length === 0}
      <p class="empty">nothing here</p>
    {/if}
    {#each items as task, i (task.id)}
      <button class="task-button" on:click={() => onTaskClick(task)}><TaskCard {task} focused={isFocused && i === focusedTaskIndex} /></button>
    {/each}
  </div>
</section>

<style>
  .panel {
    background: color-mix(in srgb, var(--panel-bg) calc(var(--opacity) * 100%), transparent);
    border: var(--border-width) solid var(--border);
    border-radius: var(--radius);
    padding: 12px;
    display: flex;
    flex-direction: column;
    min-height: 0;
    overflow: hidden;
    transition: border-color 120ms ease;
  }
  .panel.focused {
    border-color: var(--panel-accent, var(--accent));
  }
  header {
    display: flex;
    align-items: center;
    gap: 6px;
    margin-bottom: 6px;
    flex-shrink: 0;
  }
  .icon {
    font-family: var(--font-icon);
    color: var(--panel-accent, var(--accent));
  }
  h2 {
    font-family: var(--font-heading);
    font-size: var(--font-size-heading);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    margin: 0;
    flex: 1;
  }
  .count {
    font-family: var(--font-mono);
    color: var(--muted);
    font-size: 0.85em;
  }
  .items {
    display: flex;
    flex-direction: column;
    gap: var(--task-gap);
    overflow-y: auto;
  }
  .empty {
    color: var(--muted);
    font-size: 0.9em;
    padding: 6px 10px;
  }
  .task-button { display: contents; color: inherit; font: inherit; text-align: left; }
</style>
