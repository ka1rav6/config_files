<script lang="ts">
  import { createEventDispatcher } from "svelte";
  const dispatch = createEventDispatcher<{ close: void }>();

  // Mirrors the actual keymap in App.svelte — keep these in sync.
  const bindings: [string, string][] = [
    ["j / k", "move focus down / up"],
    ["h/l or ← / →", "move focus between panels"],
    ["Ctrl+h / Ctrl+l", "move panel left / right (reorder)"],
    ["Tab / Shift+Tab", "next / previous panel"],
    ["1-9", "jump to panel"],
    ["Space / c", "complete task"],
    ["a", "add task"],
    ["A", "add category"],
    ["r", "rename focused category"],
    ["D", "delete focused category (its tasks are kept, uncategorized)"],
    ["d", "delete task"],
    ["e / click", "edit task details"],
    ["u", "undo the last task action"],
    ["search / filters", "find and sort tasks"],
    ["- / =", "fewer / more columns"],
    ["Shift+H", "show this help"],
    ["Esc", "close"],
  ];
</script>

<div class="backdrop" on:click={() => dispatch("close")}>
  <div class="box" on:click={(e) => e.stopPropagation()}>
    <h2>Keybindings</h2>
    <dl>
      {#each bindings as [key, action]}
        <dt>{key}</dt>
        <dd>{action}</dd>
      {/each}
    </dl>
    <p class="hint">Press Esc to close</p>
  </div>
</div>

<style>
  .backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .box {
    background: var(--panel-bg);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 20px 24px;
    width: min(420px, 90vw);
  }
  h2 {
    font-family: var(--font-heading);
    margin-top: 0;
  }
  dl {
    display: grid;
    grid-template-columns: auto 1fr;
    column-gap: 16px;
    row-gap: 6px;
    margin: 0;
  }
  dt {
    font-family: var(--font-mono);
    color: var(--accent);
    white-space: nowrap;
  }
  dd {
    margin: 0;
    color: var(--foreground);
  }
  .hint {
    color: var(--muted);
    font-size: 0.85em;
    margin-bottom: 0;
    margin-top: 14px;
  }
</style>
