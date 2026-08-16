<script lang="ts">
/**
 * ActivityFilterBar — event-type chip multi-select + workspace dropdown + clear.
 * CSS prefix: afb- (ActivityFilterBar)
 * LOC target: ≤ 120.
 */

import { X } from 'lucide-svelte';
import type { ActivityEventType } from '$lib/domain/activity/types.js';

interface Props {
  selectedTypes: ActivityEventType[];
  workspaceSlug: string;
  availableWorkspaces: string[];
  onTypesChange: (types: ActivityEventType[]) => void;
  onWorkspaceChange: (slug: string) => void;
  onClear: () => void;
}

const {
  selectedTypes,
  workspaceSlug,
  availableWorkspaces,
  onTypesChange,
  onWorkspaceChange,
  onClear,
}: Props = $props();

// ── Event type chip config ────────────────────────────────────────────────────

const TYPE_CHIPS: { value: ActivityEventType; label: string }[] = [
  { value: 'session_started', label: 'Session started' },
  { value: 'session_ended', label: 'Session ended' },
  { value: 'task_dispatched', label: 'Task dispatched' },
  { value: 'task_completed', label: 'Task completed' },
  { value: 'task_failed', label: 'Task failed' },
  { value: 'issue_opened', label: 'Issue opened' },
  { value: 'issue_closed', label: 'Issue closed' },
  { value: 'agent_registered', label: 'Agent registered' },
];

const hasFilters = $derived(selectedTypes.length > 0 || workspaceSlug !== '');

function toggleType(type: ActivityEventType): void {
  if (selectedTypes.includes(type)) {
    onTypesChange(selectedTypes.filter((t) => t !== type));
  } else {
    onTypesChange([...selectedTypes, type]);
  }
}
</script>

<div class="afb-bar" role="group" aria-label="Activity filters">
  <!-- Workspace dropdown -->
  {#if availableWorkspaces.length > 1}
    <select
      class="afb-select"
      value={workspaceSlug}
      onchange={(e) => onWorkspaceChange((e.currentTarget as HTMLSelectElement).value)}
      aria-label="Filter by workspace"
    >
      <option value="">All workspaces</option>
      {#each availableWorkspaces as ws (ws)}
        <option value={ws}>{ws}</option>
      {/each}
    </select>
  {/if}

  <!-- Event type chips -->
  <div class="afb-chips" role="group" aria-label="Filter by event type">
    {#each TYPE_CHIPS as chip (chip.value)}
      {@const active = selectedTypes.includes(chip.value)}
      <button
        class="afb-chip"
        class:afb-chip--active={active}
        onclick={() => toggleType(chip.value)}
        aria-pressed={active}
        aria-label="Filter: {chip.label}"
      >
        {chip.label}
      </button>
    {/each}
  </div>

  <!-- Clear -->
  {#if hasFilters}
    <button
      class="afb-clear"
      onclick={onClear}
      aria-label="Clear all filters"
      title="Clear filters"
    >
      <X size={12} aria-hidden="true" />
      Clear
    </button>
  {/if}
</div>

<style>
  .afb-bar {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-wrap: wrap;
    padding: var(--space-2) var(--space-4);
    border-bottom: 1px solid var(--border);
    background: var(--bg-inset);
    flex-shrink: 0;
  }

  .afb-select {
    font-size: 11px;
    font-family: var(--font-sans);
    color: var(--fg);
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 3px 6px;
    outline: none;
    cursor: pointer;
    height: 24px;
  }

  .afb-select:focus-visible {
    border-color: var(--cnp-accent);
  }

  .afb-chips {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    flex-wrap: wrap;
  }

  .afb-chip {
    font-size: 11px;
    font-family: var(--font-sans);
    font-weight: 500;
    padding: 2px 8px;
    height: 22px;
    border-radius: 9999px;
    border: 1px solid var(--border);
    background: var(--bg);
    color: var(--fg-subtle);
    cursor: pointer;
    white-space: nowrap;
    transition:
      border-color var(--dur-instant) var(--ease-out),
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .afb-chip:hover {
    border-color: var(--cnp-accent);
    color: var(--fg);
  }

  .afb-chip--active {
    border-color: var(--cnp-accent);
    background: color-mix(in oklch, var(--cnp-accent) 12%, transparent);
    color: var(--cnp-accent);
  }

  .afb-chip:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .afb-clear {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 11px;
    font-family: var(--font-sans);
    font-weight: 500;
    padding: 2px 8px;
    height: 22px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-subtle);
    cursor: pointer;
    margin-left: var(--space-2);
    transition:
      border-color var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .afb-clear:hover {
    border-color: var(--cnp-accent);
    color: var(--fg);
  }

  .afb-clear:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  @media (prefers-reduced-motion: reduce) {
    .afb-chip, .afb-clear { transition: none; }
  }
</style>
