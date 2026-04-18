<script lang="ts">
/**
 * /sessions — Session list with status + runtime + workspace filter.
 *
 * Week 4 polish:
 *   - WorkspaceSwitcher pattern replaces Foundation <Select> for workspace filter.
 *   - useListKeyboard: j/k/↵/r/? keyboard nav on the session table.
 *   - Empty/loading/error states via EmptyState + SkeletonList.
 *   - Filter bar: status + runtime pill selects, workspace inline filter.
 *
 * The ?workspace=slug URL param pre-fills the workspace selector on mount.
 */
import { type CreateQueryOptions, createQuery, useQueryClient } from '@tanstack/svelte-query';
import { Clock, RefreshCw } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import { page } from '$app/state';
import { sessionsQuery } from '$lib/api/queries/sessions.js';
import { workspacesQuery } from '$lib/api/queries/workspaces.js';
import Select from '$lib/design/foundation/select/Select.svelte';
import { Table, TableHeader } from '$lib/design/foundation/table/index.js';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import SkeletonList from '$lib/design/patterns/SkeletonList.svelte';
import StatusDot from '$lib/design/patterns/StatusDot.svelte';
import type { Session, SessionStatus } from '$lib/domain/sessions/types.js';
import type { Workspace } from '$lib/domain/workspaces/types.js';
import { useListKeyboard } from '$lib/utils/useListKeyboard.svelte.js';

const queryClient = useQueryClient();

const STATUS_OPTIONS = [
  { value: 'all', label: 'All statuses' },
  { value: 'pending', label: 'Pending' },
  { value: 'running', label: 'Running' },
  { value: 'completed', label: 'Completed' },
  { value: 'cancelled', label: 'Cancelled' },
  { value: 'error', label: 'Error' },
];

const RUNTIME_OPTIONS = [
  { value: 'all', label: 'All runtimes' },
  { value: 'claude', label: 'Claude' },
  { value: 'openai', label: 'OpenAI' },
  { value: 'gemini', label: 'Gemini' },
  { value: 'ollama', label: 'Ollama' },
  { value: 'mistral', label: 'Mistral' },
  { value: 'groq', label: 'Groq' },
  { value: 'deepseek', label: 'DeepSeek' },
  { value: 'cohere', label: 'Cohere' },
  { value: 'gemma', label: 'Gemma' },
];

// Pre-fill workspace from URL ?workspace=slug query param.
const urlWorkspace = $derived(page.url.searchParams.get('workspace') ?? 'all');

let statusFilter = $state('all');
let runtimeFilter = $state('all');
let workspaceFilter = $state('all');
let shortcutHelpVisible = $state(false);

// Sync workspaceFilter when the URL param changes.
$effect(() => {
  workspaceFilter = urlWorkspace;
});

// Workspace list for the selector.
const workspacesOptsStore = writable(
  untrack(() => workspacesQuery() as CreateQueryOptions<Workspace[]>)
);
const workspacesResult = createQuery<Workspace[]>(workspacesOptsStore);

const workspaceOptions = $derived([
  { value: 'all', label: 'All workspaces' },
  ...($workspacesResult.data ?? []).map((w: Workspace) => ({
    value: w.slug,
    label: w.name,
  })),
]);

const filters = $derived({
  status: statusFilter !== 'all' ? statusFilter : undefined,
  runtimeType: runtimeFilter !== 'all' ? runtimeFilter : undefined,
  workspaceSlug: workspaceFilter !== 'all' ? workspaceFilter : undefined,
});

const queryOptsStore = writable(
  untrack(() => sessionsQuery(filters) as CreateQueryOptions<Session[]>)
);

$effect(() => {
  queryOptsStore.set(sessionsQuery(filters) as CreateQueryOptions<Session[]>);
});

const query = createQuery<Session[]>(queryOptsStore);

const sessions = $derived(($query.data ?? []) as Session[]);

// ── Keyboard navigation ──────────────────────────────────────────────────────

const kb = useListKeyboard({
  items: () => sessions,
  onSelect: (session) => goto(`/sessions/${session.id}`),
  onRefresh: () => {
    queryClient.invalidateQueries({ queryKey: ['sessions'] });
  },
  onHelp: () => {
    shortcutHelpVisible = !shortcutHelpVisible;
  },
});

// ── Helpers ──────────────────────────────────────────────────────────────────

function dotColor(status: SessionStatus): 'green' | 'amber' | 'red' | 'grey' {
  switch (status) {
    case 'running': return 'green';
    case 'error': return 'red';
    case 'paused': return 'amber';
    case 'pending': return 'amber';
    default: return 'grey';
  }
}

/** Compute session duration in ms from startedAt / completedAt timestamps. */
function sessionDurationMs(s: Session): number | null {
  if (!s.startedAt || !s.completedAt) return null;
  return new Date(s.completedAt).getTime() - new Date(s.startedAt).getTime();
}

function formatDuration(ms: number | null): string {
  if (ms === null) return '—';
  if (ms < 1000) return `${ms}ms`;
  const secs = Math.floor(ms / 1000);
  if (secs < 60) return `${secs}s`;
  return `${Math.floor(secs / 60)}m ${secs % 60}s`;
}

function formatCost(usd: string): string {
  const n = parseFloat(usd);
  return isNaN(n) ? '—' : `$${n.toFixed(2)}`;
}
</script>

<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
<div
  class="sl-page"
  role="region"
  aria-label="Sessions list"
  onkeydown={kb.handleKeydown}
  tabindex="0"
>
  <!-- Header -->
  <header class="sl-header">
    <h1 class="sl-title">Sessions</h1>
    <button
      class="btn-pill btn-pill-primary btn-pill-sm"
      onclick={() => goto('/')}
      aria-label="Start new session"
    >
      + New Session
    </button>
  </header>

  <!-- Filter bar -->
  <div class="sl-filters" role="search" aria-label="Filter sessions">
    <Select
      options={STATUS_OPTIONS}
      bind:value={statusFilter}
      placeholder="All statuses"
    />
    <Select
      options={RUNTIME_OPTIONS}
      bind:value={runtimeFilter}
      placeholder="All runtimes"
    />
    <Select
      options={workspaceOptions}
      bind:value={workspaceFilter}
      placeholder="All workspaces"
    />
    <button
      class="sl-refresh btn-compact btn-compact-ghost"
      onclick={() => queryClient.invalidateQueries({ queryKey: ['sessions'] })}
      aria-label="Refresh sessions (r)"
      title="Refresh (r)"
    >
      <RefreshCw size={12} aria-hidden="true" />
    </button>
  </div>

  <!-- Shortcut help overlay -->
  {#if shortcutHelpVisible}
    <div class="sl-help glass-panel" role="status" aria-live="polite">
      <span class="sl-help__title">Keyboard shortcuts</span>
      <div class="sl-help__rows">
        <span><kbd>j</kbd> / <kbd>↓</kbd> next</span>
        <span><kbd>k</kbd> / <kbd>↑</kbd> prev</span>
        <span><kbd>↵</kbd> open</span>
        <span><kbd>r</kbd> refresh</span>
        <span><kbd>Esc</kbd> clear</span>
      </div>
      <button class="sl-help__close btn-compact btn-compact-ghost" onclick={() => { shortcutHelpVisible = false; }}>✕</button>
    </div>
  {/if}

  <!-- Table or states -->
  {#if $query.isError}
    <EmptyState
      title="Couldn't load sessions"
      body={($query.error as Error).message || 'Check your connection and try again.'}
      action="Retry"
      onAction={() => $query.refetch()}
    />
  {:else if $query.isLoading}
    <div class="sl-skeleton-wrap">
      <SkeletonList count={8} height="2.5rem" gap="0.375rem" />
    </div>
  {:else if sessions.length === 0}
    <EmptyState
      icon={Clock as never}
      title="No sessions yet"
      body="Type a prompt on Home to get started."
      action="New session"
      onAction={() => goto('/')}
    />
  {:else}
    <div class="sl-table-wrap">
      <Table hoverable>
        <TableHeader>
          <tr>
            <th class="sl-th sl-th-status"></th>
            <th class="sl-th">Agent</th>
            <th class="sl-th">Runtime</th>
            <th class="sl-th">Duration</th>
            <th class="sl-th">Cost</th>
          </tr>
        </TableHeader>
        <tbody>
          {#each sessions as session, i (session.id)}
            <!-- svelte-ignore a11y_interactive_supports_focus -->
            <tr
              class="sl-row bos-table-row"
              class:sl-row--selected={kb.selectedIndex === i}
              role="button"
              onclick={() => goto(`/sessions/${session.id}`)}
              onkeydown={(e) => e.key === 'Enter' && goto(`/sessions/${session.id}`)}
              aria-selected={kb.selectedIndex === i}
            >
              <td class="bos-table-cell sl-td-status">
                <StatusDot color={dotColor(session.status)} pulse={session.status === 'running'} />
              </td>
              <td class="bos-table-cell sl-td-agent">
                {session.agentSlug ?? '—'}
              </td>
              <td class="bos-table-cell sl-mono">
                {session.runtimeType}
              </td>
              <td class="bos-table-cell sl-mono">
                {formatDuration(sessionDurationMs(session))}
              </td>
              <td class="bos-table-cell sl-mono">
                {formatCost(session.costUsd)}
              </td>
            </tr>
          {/each}
        </tbody>
      </Table>
    </div>
  {/if}
</div>

<style>
  .sl-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-6);
    overflow-y: auto;
    height: 100%;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
    outline: none;
  }

  .sl-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: var(--space-3);
  }

  .sl-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: var(--tracking-2xl);
    line-height: var(--lh-2xl);
  }

  .sl-filters {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-wrap: wrap;
  }

  .sl-filters :global(.bos-select) {
    min-width: 160px;
    width: auto;
  }

  .sl-refresh {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    flex-shrink: 0;
    transition: background var(--dur-instant) var(--ease-out);
  }

  /* Shortcut help */
  .sl-help {
    display: flex;
    align-items: center;
    gap: var(--space-4);
    padding: var(--space-2) var(--space-4);
    border-radius: var(--radius-lg);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    flex-wrap: wrap;
    position: relative;
  }

  .sl-help__title {
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    font-size: 10px;
  }

  .sl-help__rows {
    display: flex;
    gap: var(--space-4);
    flex-wrap: wrap;
  }

  .sl-help__rows kbd {
    font-family: var(--font-mono);
    font-size: 10px;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: 3px;
    padding: 0 3px;
    color: var(--fg);
  }

  .sl-help__close {
    margin-left: auto;
  }

  .sl-skeleton-wrap {
    flex: 1;
  }

  .sl-table-wrap {
    overflow-x: auto;
    border-radius: var(--radius-lg);
    border: 1px solid var(--border);
  }

  .sl-th {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-muted);
    padding: var(--space-2) var(--space-3);
    text-align: left;
    border-bottom: 1px solid var(--border);
    letter-spacing: var(--tracking-xs);
    text-transform: uppercase;
    white-space: nowrap;
  }

  .sl-th-status {
    width: 32px;
    padding-right: 0;
  }

  :global(.sl-row) {
    cursor: pointer;
  }

  :global(.sl-row--selected) {
    background: color-mix(in oklch, var(--fg) 5%, transparent 95%) !important;
  }

  :global(.sl-td-status) {
    padding-right: 0 !important;
    width: 32px !important;
  }

  :global(.sl-td-agent) {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    font-weight: 500;
  }

  .sl-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }
</style>
