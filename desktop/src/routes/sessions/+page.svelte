<script lang="ts">
/**
 * /sessions — Session list with status + runtime + workspace filter.
 *
 * Filter bar drives sessionsQuery() parameters reactively.
 * The ?workspace=slug URL param pre-fills the workspace selector on mount.
 * Foundation Table with status dot, agent name, runtime, workspace, duration, cost.
 *
 * TanStack QueryClientProvider assumed from root layout (+layout.svelte).
 */
// TODO: QueryClient setup assumed from layout
import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import { page } from '$app/state';
import { sessionsQuery } from '$lib/api/queries/sessions.js';
import { workspacesQuery } from '$lib/api/queries/workspaces.js';
import Alert from '$lib/design/foundation/alert/Alert.svelte';
import Select from '$lib/design/foundation/select/Select.svelte';
import Skeleton from '$lib/design/foundation/skeleton/Skeleton.svelte';
import { Table, TableHeader } from '$lib/design/foundation/table/index.js';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import StatusDot from '$lib/design/patterns/StatusDot.svelte';
import type { Session, SessionStatus } from '$lib/domain/sessions/types.js';
import type { Workspace } from '$lib/domain/workspaces/types.js';

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

// Sync workspaceFilter when the URL param changes (e.g., navigated from another page).
$effect(() => {
  workspaceFilter = urlWorkspace;
});

// Workspace list for the selector — loaded once, stale for 30s.
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

function dotColor(status: SessionStatus): 'green' | 'amber' | 'red' | 'grey' {
  switch (status) {
    case 'running':
      return 'green';
    case 'error':
      return 'red';
    case 'paused':
      return 'amber';
    case 'pending':
      return 'amber';
    default:
      return 'grey';
  }
}

function formatDuration(ms: number | null): string {
  if (ms === null) return '—';
  if (ms < 1000) return `${ms}ms`;
  const secs = Math.floor(ms / 1000);
  if (secs < 60) return `${secs}s`;
  return `${Math.floor(secs / 60)}m ${secs % 60}s`;
}

function formatCost(usd: number): string {
  return `$${usd.toFixed(2)}`;
}
</script>

<div class="sl-page">
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
  </div>

  <!-- Table or states -->
  {#if $query.isError}
    <Alert variant="error" title="Failed to load sessions">
      {($query.error as Error).message}
      <button
        class="btn-pill btn-pill-sm btn-pill-primary"
        onclick={() => $query.refetch()}
        style="margin-top: 8px;"
      >
        Retry
      </button>
    </Alert>
  {:else if $query.isLoading}
    <div class="sl-skeleton">
      {#each Array.from({ length: 8 }, (_, i) => i) as i (i)}
        <Skeleton class="sl-sk-row" />
      {/each}
    </div>
  {:else if $query.data && $query.data.length > 0}
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
          {#each $query.data as session (session.id)}
            <!-- svelte-ignore a11y_interactive_supports_focus -->
            <tr
              class="sl-row bos-table-row"
              role="button"
              onclick={() => goto(`/sessions/${session.id}`)}
              onkeydown={(e) => e.key === 'Enter' && goto(`/sessions/${session.id}`)}
            >
              <td class="bos-table-cell sl-td-status">
                <StatusDot color={dotColor(session.status)} pulse={session.status === 'running'} />
              </td>
              <td class="bos-table-cell sl-td-agent">
                {session.agentSlug || session.agentName || '—'}
              </td>
              <td class="bos-table-cell sl-mono">
                {session.runtimeName ?? session.runtimeType}
              </td>
              <td class="bos-table-cell sl-mono">
                {formatDuration(session.durationMs)}
              </td>
              <td class="bos-table-cell sl-mono">
                {formatCost(session.costUsd)}
              </td>
            </tr>
          {/each}
        </tbody>
      </Table>
    </div>
  {:else}
    <EmptyState
      title="No sessions yet."
      body="Type a prompt on Home to get started."
    />
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

  .sl-skeleton {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  :global(.sl-sk-row) {
    height: 40px !important;
    width: 100% !important;
    border-radius: var(--radius-md) !important;
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

  :global(.sl-td-runtime),
  :global(.sl-td-duration),
  :global(.sl-td-cost) {
    font-family: var(--font-mono) !important;
    font-size: var(--text-xs) !important;
    color: var(--fg-muted) !important;
  }

  .sl-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }
</style>
