<script lang="ts">
  /**
   * KanbanColumn — single column in the Agent Kanban pane.
   * CSS prefix: akcol-
   *
   * Drag-drop is wired by the parent pane via `dndzone`. This component
   * owns layout + the optional auto-pickup toggle in the column header.
   * It does NOT depend on a specific column key — it's just a typed
   * presentational wrapper around the DnD-zone div.
   */

  import { SHADOW_PLACEHOLDER_ITEM_ID, dndzone } from 'svelte-dnd-action';
  import type { DndEvent } from 'svelte-dnd-action';
  import type { Task } from '$lib/domain/tasks/types.js';
  import type { AgentKanbanColumn } from '$lib/domain/agent-kanban/types.js';
  import AgentKanbanCard from './AgentKanbanCard.svelte';

  interface Props {
    column: AgentKanbanColumn;
    label: string;
    items: Task[];
    /** Optional auto-pickup toggle — only meaningful for `backlog`. */
    showAutoPickupToggle?: boolean;
    autoPickupOn?: boolean;
    onAutoPickupToggle?: () => void;
    onConsider: (e: CustomEvent<DndEvent<Task>>) => void;
    onFinalize: (e: CustomEvent<DndEvent<Task>>) => void;
  }

  let {
    column,
    label,
    items,
    showAutoPickupToggle = false,
    autoPickupOn = false,
    onAutoPickupToggle,
    onConsider,
    onFinalize,
  }: Props = $props();

  const visibleCount = $derived(
    items.filter((t) => t.id !== SHADOW_PLACEHOLDER_ITEM_ID).length,
  );

  const FLIP_MS = 180;
</script>

<section class="akcol" aria-label={`${label} column`}>
  <header class="akcol__header">
    <h2 class="akcol__label">{label}</h2>
    <span class="akcol__count" aria-label={`${visibleCount} tasks`}>{visibleCount}</span>

    {#if showAutoPickupToggle}
      <button
        type="button"
        class="akcol__toggle"
        class:akcol__toggle--on={autoPickupOn}
        onclick={onAutoPickupToggle}
        aria-pressed={autoPickupOn}
        aria-label="Toggle auto pickup"
        title="Auto pickup — idle agents grab matching tasks"
      >
        Auto-pickup
      </button>
    {/if}
  </header>

  <div
    class="akcol__zone"
    use:dndzone={{ items, flipDurationMs: FLIP_MS, dropTargetStyle: {} }}
    onconsider={onConsider}
    onfinalize={onFinalize}
    data-column={column}
  >
    {#each items as task (task.id)}
      <AgentKanbanCard {task} />
    {/each}
  </div>
</section>

<style>
  .akcol {
    display: flex;
    flex-direction: column;
    width: 280px;
    min-width: 280px;
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    padding: 10px;
    gap: 8px;
    font-family: var(--font-sans);
  }

  .akcol__header {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0 4px;
  }

  .akcol__label {
    margin: 0;
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .akcol__count {
    font-size: 11px;
    color: var(--fg-subtle);
    padding: 1px 6px;
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
  }

  .akcol__toggle {
    margin-left: auto;
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-muted);
    font-size: 10px;
    font-family: var(--font-sans);
    padding: 3px 8px;
    border-radius: var(--radius-sm);
    cursor: pointer;
    transition: background 0.1s ease, border-color 0.1s ease, color 0.1s ease;
  }

  .akcol__toggle:hover {
    color: var(--fg);
    border-color: color-mix(in oklch, var(--fg) 30%, transparent);
  }

  .akcol__toggle--on {
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 18%, transparent);
    border-color: var(--cnp-accent, oklch(0.72 0.18 145));
    color: var(--fg);
  }

  .akcol__zone {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 6px;
    min-height: 60px;
    overflow-y: auto;
    padding: 2px;
  }
</style>
