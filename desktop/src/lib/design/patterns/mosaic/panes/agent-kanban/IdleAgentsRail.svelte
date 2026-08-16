<script lang="ts">
  /**
   * IdleAgentsRail — right-side rail showing hired agents with auto-pickup
   * enabled. Each row is a drop target — dropping a task card on a row
   * triggers a manual claim for that agent.
   *
   * CSS prefix: idle-
   *
   * The rail is data-driven by the `idleAgentsQuery` factory; the parent
   * pane owns the click→claim mutation so this component stays a pure
   * presentational + drop-target wrapper.
   */

  import type { IdleAgent } from '$lib/domain/agent-kanban/types.js';

  interface Props {
    agents: IdleAgent[];
    /** Currently-dragged task short_id, or null when nothing is being dragged. */
    draggingTaskId?: string | null;
    onClaim: (agentSlug: string, taskShortId: string) => void;
  }

  let { agents, draggingTaskId = null, onClaim }: Props = $props();

  let highlightSlug = $state<string | null>(null);

  function handleDragOver(e: DragEvent, slug: string): void {
    if (!draggingTaskId) return;
    e.preventDefault();
    highlightSlug = slug;
  }

  function handleDragLeave(slug: string): void {
    if (highlightSlug === slug) highlightSlug = null;
  }

  function handleDrop(e: DragEvent, slug: string): void {
    e.preventDefault();
    highlightSlug = null;
    const taskId = e.dataTransfer?.getData('application/x-canopy-task-id');
    const id = taskId || draggingTaskId;
    if (id) onClaim(slug, id);
  }
</script>

<aside class="idle" aria-label="Idle agents">
  <header class="idle__header">
    <h2 class="idle__heading">Idle agents</h2>
    <span class="idle__count">{agents.length}</span>
  </header>

  {#if agents.length === 0}
    <p class="idle__empty">No agents have auto-pickup enabled.</p>
  {:else}
    <ul class="idle__list" role="list">
      {#each agents as a (a.slug)}
        <li
          class="idle__row"
          class:idle__row--highlight={highlightSlug === a.slug}
          ondragover={(e) => handleDragOver(e, a.slug)}
          ondragleave={() => handleDragLeave(a.slug)}
          ondrop={(e) => handleDrop(e, a.slug)}
        >
          <div class="idle__row-head">
            <span class="idle__name">{a.name}</span>
            <span class="idle__sessions" aria-label="Active sessions">
              {a.activeSessionCount}
            </span>
          </div>
          <p class="idle__category">{a.category}</p>

          {#if a.capabilities.length > 0}
            <ul class="idle__caps" aria-label="Capabilities">
              {#each a.capabilities.slice(0, 4) as cap (cap)}
                <li class="idle__cap">{cap}</li>
              {/each}
              {#if a.capabilities.length > 4}
                <li class="idle__cap idle__cap--more">+{a.capabilities.length - 4}</li>
              {/if}
            </ul>
          {/if}
        </li>
      {/each}
    </ul>
  {/if}
</aside>

<style>
  .idle {
    width: 240px;
    min-width: 240px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 12px;
    border-left: 1px solid var(--border);
    font-family: var(--font-sans);
    overflow-y: auto;
  }

  .idle__header {
    display: flex;
    align-items: baseline;
    gap: 8px;
  }

  .idle__heading {
    margin: 0;
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .idle__count {
    font-size: 11px;
    color: var(--fg-subtle);
  }

  .idle__empty {
    margin: 0;
    font-size: 12px;
    color: var(--fg-subtle);
    line-height: 1.4;
  }

  .idle__list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .idle__row {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 8px 10px;
    border-radius: var(--radius-md);
    border: 1px dashed transparent;
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    transition: border-color 0.1s ease, background 0.1s ease;
  }

  .idle__row--highlight {
    border-color: var(--cnp-accent, oklch(0.72 0.18 145));
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 12%, transparent);
  }

  .idle__row-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .idle__name {
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
  }

  .idle__sessions {
    font-size: 10px;
    color: var(--fg-subtle);
    padding: 1px 5px;
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    font-family: var(--font-mono);
  }

  .idle__category {
    margin: 0;
    font-size: 11px;
    color: var(--fg-subtle);
  }

  .idle__caps {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .idle__cap {
    padding: 1px 5px;
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg-muted);
    font-size: 10px;
  }

  .idle__cap--more {
    font-style: italic;
  }
</style>
