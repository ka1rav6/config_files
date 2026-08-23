<script lang="ts">
  import type { Task, Category } from "../services/api";
  import Panel from "./Panel.svelte";

  export let tasks: Task[];
  export let categories: Category[];
  export let focusedPanel: number;
  export let focusedTaskIndex: number;
  export let columns = 2;
  export let onTaskClick: (task: Task) => void = () => {};

  // Section 9's dashboard: one panel per category, plus a synthetic
  // "Critical" panel driven by a filter instead of a category_id — same
  // shape as the `critical` panel in the doc's example config (section 44).
  $: panels = [
    ...categories.map((c) => ({
      id: c.id,
      title: c.name,
      icon: c.icon ?? undefined,
      color: c.color ?? undefined,
      items: tasks.filter((t) => t.category_id === c.id && t.status !== "archived"),
    })),
    {
      id: "critical",
      title: "Critical",
      icon: "󰀦",
      color: "var(--crit-critical)",
      items: tasks.filter((t) => t.criticality === "critical" && t.status === "pending"),
    },
  ];

  export function panelCount() {
    return panels.length;
  }
  export function itemCountFor(panelIdx: number) {
    return panels[panelIdx]?.items.length ?? 0;
  }
  export function categoryIdFor(panelIdx: number) {
    return panels[panelIdx]?.id;
  }
  export function focusedTask(): Task | undefined {
    return panels[focusedPanel]?.items[focusedTaskIndex];
  }
</script>

<div class="grid" style="--cols: {columns}">
  {#each panels as panel, i (panel.id)}
    <Panel
      title={panel.title}
      icon={panel.icon}
      color={panel.color}
      items={panel.items}
      panelIndex={i}
      {focusedPanel}
      {focusedTaskIndex}
      {onTaskClick}
    />
  {/each}
</div>

<style>
  .grid {
    flex: 1;
    display: grid;
    grid-template-columns: repeat(var(--cols), 1fr);
    grid-auto-rows: 1fr;
    gap: 12px;
    padding: 12px;
    min-height: 0;
  }
</style>
