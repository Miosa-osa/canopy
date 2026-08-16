<script lang="ts">
/**
 * /sessions — Session list grouped by workspace.
 *
 * Additions:
 *   - ViewPicker (layout / density / sort) right of filter bar
 *   - "Show ended" toggle (off by default) hides completed/cancelled/failed rows
 *   - "Clean up" dropdown — bulk-delete ended/failed/old sessions
 *   - Confirm modal before destructive bulk deletes
 *
 * CSS prefix: sl-
 * LOC target: ≤ 380
 */
import { type CreateQueryOptions, createQuery, useQueryClient } from '@tanstack/svelte-query';
import { Clock, Plus, RefreshCw, ChevronDown, Trash2 } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { page } from '$app/state';
import { sessionsQuery } from '$lib/api/queries/sessions.js';
import { bulkDeleteSessions } from '$lib/api/queries/sessions.js';
import { workspacesQuery } from '$lib/api/queries/workspaces.js';
import { goto } from '$app/navigation';
import Select from '$lib/design/foundation/select/Select.svelte';
import { Table, TableHeader } from '$lib/design/foundation/table/index.js';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import SkeletonList from '$lib/design/patterns/SkeletonList.svelte';
import StatusDot from '$lib/design/patterns/StatusDot.svelte';
import ViewPicker from '$lib/design/primitives/ViewPicker.svelte';
import type { ViewState } from '$lib/design/primitives/ViewPicker.svelte';
import type { Session, SessionStatus } from '$lib/domain/sessions/types.js';
import type { Workspace } from '$lib/domain/workspaces/types.js';
import { ui } from '$lib/stores/ui.svelte.js';
import { useListKeyboard } from '$lib/utils/useListKeyboard.svelte.js';

const queryClient = useQueryClient();

// ── View picker ───────────────────────────────────────────────────────────────

let view = $state<ViewState>({ layout: 'list', density: 'comfortable', sort: 'recent' });

// ── Filters ───────────────────────────────────────────────────────────────────

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
];

const urlWorkspace = $derived(page.url.searchParams.get('workspace') ?? 'all');

let statusFilter = $state('all');
let runtimeFilter = $state('all');
let workspaceFilter = $state('all');
let shortcutHelpVisible = $state(false);
let showEnded = $state(false);
let collapsedGroups = $state<Set<string>>(new Set());

// Clean-up state
let cleanupMenuOpen = $state(false);
let confirmOpen = $state(false);
let confirmLabel = $state('');
let pendingCleanup = $state<(() => Promise<void>) | null>(null);
let isDeleting = $state(false);
let deleteResult = $state<string | null>(null);

$effect(() => {
  workspaceFilter = urlWorkspace;
});

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
const allSessions = $derived(($query.data ?? []) as Session[]);

// Hide ended sessions unless toggle is on
// Cast to string set to handle backend statuses not yet reflected in the TS union
const TERMINAL_STATUSES = new Set<string>(['completed', 'cancelled', 'failed', 'ended']);

const sessions = $derived(
  showEnded
    ? allSessions
    : allSessions.filter((s) => !TERMINAL_STATUSES.has(s.status as string))
);

const hiddenCount = $derived(allSessions.length - sessions.length);

// ── Sorting ───────────────────────────────────────────────────────────────────

function sortSessions(list: Session[], sort: string): Session[] {
  const copy = [...list];
  switch (sort) {
    case 'oldest':
      return copy.sort((a, b) => new Date(a.insertedAt).getTime() - new Date(b.insertedAt).getTime());
    case 'name_asc':
      return copy.sort((a, b) => (a.prompt ?? '').localeCompare(b.prompt ?? ''));
    case 'name_desc':
      return copy.sort((a, b) => (b.prompt ?? '').localeCompare(a.prompt ?? ''));
    case 'status':
      return copy.sort((a, b) => a.status.localeCompare(b.status));
    default: // recent
      return copy.sort((a, b) => new Date(b.insertedAt).getTime() - new Date(a.insertedAt).getTime());
  }
}

// ── Group sessions by workspace slug ──────────────────────────────────────────

interface SessionGroup {
  label: string;
  key: string;
  sessions: Session[];
}

const sessionGroups = $derived<SessionGroup[]>(
  buildGroups(sortSessions(sessions, view.sort))
);

function buildGroups(list: Session[]): SessionGroup[] {
  const map = new Map<string, Session[]>();
  for (const s of list) {
    const key = s.workspaceSlug ?? '(no workspace)';
    const arr = map.get(key) ?? [];
    arr.push(s);
    map.set(key, arr);
  }
  return Array.from(map.entries()).map(([key, items]) => ({
    key,
    label: key,
    sessions: items,
  }));
}

function toggleGroup(key: string): void {
  const next = new Set(collapsedGroups);
  if (next.has(key)) next.delete(key);
  else next.add(key);
  collapsedGroups = next;
}

// ── Density helpers ───────────────────────────────────────────────────────────

const rowPad = $derived(
  view.density === 'compact' ? 'var(--space-1) var(--space-2)'
  : view.density === 'roomy' ? 'var(--space-4) var(--space-3)'
  : 'var(--space-2) var(--space-3)'
);

// ── Cleanup actions ───────────────────────────────────────────────────────────

function askCleanup(label: string, fn: () => Promise<void>): void {
  confirmLabel = label;
  pendingCleanup = fn;
  confirmOpen = true;
  cleanupMenuOpen = false;
}

async function runCleanup(): Promise<void> {
  if (!pendingCleanup) return;
  isDeleting = true;
  deleteResult = null;
  try {
    await pendingCleanup();
    queryClient.invalidateQueries({ queryKey: ['sessions'] });
    deleteResult = 'Done.';
  } catch (e) {
    deleteResult = `Error: ${(e as Error).message}`;
  } finally {
    isDeleting = false;
    confirmOpen = false;
    pendingCleanup = null;
  }
}

function cancelCleanup(): void {
  confirmOpen = false;
  pendingCleanup = null;
}

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;

// Precompute counts for confirmation labels
const endedCount = $derived(allSessions.filter((s) => TERMINAL_STATUSES.has(s.status as string)).length);
const failedCount = $derived(allSessions.filter((s) => (s.status as string) === 'failed').length);
const oldHourCount = $derived(
  allSessions.filter((s) =>
    TERMINAL_STATUSES.has(s.status as string) && Date.now() - new Date(s.insertedAt).getTime() > HOUR_MS
  ).length
);
const oldDayCount = $derived(
  allSessions.filter((s) =>
    TERMINAL_STATUSES.has(s.status as string) && Date.now() - new Date(s.insertedAt).getTime() > DAY_MS
  ).length
);

// ── Keyboard navigation ───────────────────────────────────────────────────────

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

// ── Helpers ───────────────────────────────────────────────────────────────────

function dotColor(status: SessionStatus): 'green' | 'amber' | 'red' | 'grey' {
  switch (status) {
    case 'running': return 'green';
    case 'error': return 'red';
    case 'paused': return 'amber';
    case 'pending': return 'amber';
    default: return 'grey';
  }
}

function relativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60_000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.floor(hrs / 24)}d ago`;
}

function promptPreview(s: Session): string {
  if (!s.prompt) return '—';
  return s.prompt.length > 60 ? `${s.prompt.slice(0, 60)}…` : s.prompt;
}

function flatIndex(groupIdx: number, rowIdx: number): number {
  let n = 0;
  for (let g = 0; g < groupIdx; g++) {
    n += sessionGroups[g].sessions.length;
  }
  return n + rowIdx;
}
</script>

<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
<div
  class="sl-page"
  role="region"
  aria-label="Sessions list"
  onkeydown={kb.handleKeydown}
>
  <!-- Header -->
  <header class="sl-header">
    <h1 class="sl-title">Sessions</h1>
    <button
      class="btn-pill btn-pill-primary btn-pill-sm"
      onclick={() => ui.openNewSessionModal()}
      aria-label="New session (Cmd+N)"
    >
      <Plus size={12} aria-hidden="true" />
      New Session
    </button>
  </header>

  <!-- Filter bar + controls -->
  <div class="sl-toolbar">
    <div class="sl-filters" role="search" aria-label="Filter sessions">
      <Select options={STATUS_OPTIONS} bind:value={statusFilter} placeholder="All statuses" />
      <Select options={RUNTIME_OPTIONS} bind:value={runtimeFilter} placeholder="All runtimes" />
      <Select options={workspaceOptions} bind:value={workspaceFilter} placeholder="All workspaces" />
      <button
        class="sl-refresh btn-compact btn-compact-ghost"
        onclick={() => queryClient.invalidateQueries({ queryKey: ['sessions'] })}
        aria-label="Refresh sessions (r)"
        title="Refresh (r)"
      >
        <RefreshCw size={12} aria-hidden="true" />
      </button>
    </div>

    <div class="sl-controls">
      <!-- Show ended toggle -->
      <button
        class="sl-toggle"
        class:sl-toggle--on={showEnded}
        onclick={() => { showEnded = !showEnded; }}
        aria-pressed={showEnded}
        title={showEnded ? 'Hide ended sessions' : 'Show ended sessions'}
      >
        {showEnded ? 'Hide ended' : 'Show ended'}
        {#if hiddenCount > 0 && !showEnded}
          <span class="sl-badge">{hiddenCount}</span>
        {/if}
      </button>

      <!-- Clean-up dropdown -->
      <div class="sl-cleanup-wrap">
        <button
          class="sl-cleanup-btn"
          onclick={() => { cleanupMenuOpen = !cleanupMenuOpen; }}
          aria-haspopup="menu"
          aria-expanded={cleanupMenuOpen}
        >
          <Trash2 size={11} aria-hidden="true" />
          Clean up
          <ChevronDown size={10} aria-hidden="true" />
        </button>

        {#if cleanupMenuOpen}
          <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
          <div
            class="sl-cleanup-backdrop"
            onclick={() => { cleanupMenuOpen = false; }}
          ></div>
          <menu class="sl-cleanup-menu" role="menu">
            <li role="presentation">
              <button
                class="sl-menu-item"
                role="menuitem"
                onclick={() => askCleanup(
                  `Delete all ended sessions (${endedCount})?`,
                  () => bulkDeleteSessions().then(() => undefined)
                )}
                disabled={endedCount === 0}
              >
                Clear all ended
                {#if endedCount > 0}<span class="sl-menu-count">{endedCount}</span>{/if}
              </button>
            </li>
            <li role="presentation">
              <button
                class="sl-menu-item"
                role="menuitem"
                onclick={() => askCleanup(
                  `Delete all failed sessions (${failedCount})?`,
                  () => bulkDeleteSessions({ status: 'failed' }).then(() => undefined)
                )}
                disabled={failedCount === 0}
              >
                Clear all failed
                {#if failedCount > 0}<span class="sl-menu-count">{failedCount}</span>{/if}
              </button>
            </li>
            <li class="sl-menu-sep" role="separator"></li>
            <li role="presentation">
              <button
                class="sl-menu-item"
                role="menuitem"
                onclick={() => askCleanup(
                  `Delete ended sessions older than 1 hour (${oldHourCount})?`,
                  () => bulkDeleteSessions({ before: new Date(Date.now() - HOUR_MS).toISOString() }).then(() => undefined)
                )}
                disabled={oldHourCount === 0}
              >
                Clear all &gt; 1 hour old
                {#if oldHourCount > 0}<span class="sl-menu-count">{oldHourCount}</span>{/if}
              </button>
            </li>
            <li role="presentation">
              <button
                class="sl-menu-item"
                role="menuitem"
                onclick={() => askCleanup(
                  `Delete ended sessions older than 1 day (${oldDayCount})?`,
                  () => bulkDeleteSessions({ before: new Date(Date.now() - DAY_MS).toISOString() }).then(() => undefined)
                )}
                disabled={oldDayCount === 0}
              >
                Clear all &gt; 1 day old
                {#if oldDayCount > 0}<span class="sl-menu-count">{oldDayCount}</span>{/if}
              </button>
            </li>
          </menu>
        {/if}
      </div>

      <!-- View picker -->
      <ViewPicker routeSlug="sessions" bind:view />
    </div>
  </div>

  <!-- Delete result toast -->
  {#if deleteResult}
    <div class="sl-result" role="status" aria-live="polite">{deleteResult}</div>
  {/if}

  <!-- Confirm modal -->
  {#if confirmOpen}
    <div class="sl-overlay" role="dialog" aria-modal="true" aria-label="Confirm cleanup">
      <div class="sl-dialog">
        <p class="sl-dialog-body">{confirmLabel}</p>
        <div class="sl-dialog-actions">
          <button class="sl-dialog-cancel" onclick={cancelCleanup} disabled={isDeleting}>
            Cancel
          </button>
          <button class="sl-dialog-confirm" onclick={runCleanup} disabled={isDeleting}>
            {isDeleting ? 'Deleting…' : 'Delete'}
          </button>
        </div>
      </div>
    </div>
  {/if}

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
        <span><kbd>⌘N</kbd> new session</span>
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
  {:else if allSessions.length === 0}
    <EmptyState
      icon={Clock as never}
      title="No sessions yet"
      body="Spawn your first terminal."
      action="New session"
      onAction={() => ui.openNewSessionModal()}
    />
  {:else if sessions.length === 0}
    <div class="sl-all-hidden">
      All sessions are ended.
      <button class="sl-inline-link" onclick={() => { showEnded = true; }}>Show them</button>
    </div>
  {:else}
    <div class="sl-groups">
      {#each sessionGroups as group (group.key)}
        {@const isCollapsed = collapsedGroups.has(group.key)}
        <div class="sl-group">
          <!-- Group header -->
          <button
            class="sl-group-header"
            onclick={() => toggleGroup(group.key)}
            aria-expanded={!isCollapsed}
            aria-controls="slg-{group.key}"
          >
            <span class="sl-group-chevron" class:collapsed={isCollapsed} aria-hidden="true">▸</span>
            <span class="sl-group-name">{group.label}</span>
            <span class="sl-group-count">{group.sessions.length}</span>
          </button>

          {#if !isCollapsed}
            <div id="slg-{group.key}" class="sl-table-wrap">
              <Table hoverable>
                <TableHeader>
                  <tr>
                    <th class="sl-th sl-th-status"></th>
                    <th class="sl-th">Runtime</th>
                    <th class="sl-th">Prompt</th>
                    <th class="sl-th">When</th>
                    <th class="sl-th">Cost</th>
                  </tr>
                </TableHeader>
                <tbody>
                  {#each group.sessions as session, i (session.id)}
                    {@const fi = flatIndex(sessionGroups.indexOf(group), i)}
                    <!-- svelte-ignore a11y_interactive_supports_focus -->
                    <tr
                      class="sl-row bos-table-row"
                      class:sl-row--selected={kb.selectedIndex === fi}
                      style="--sl-row-pad: {rowPad}"
                      role="button"
                      onclick={() => goto(`/sessions/${session.id}`)}
                      onkeydown={(e) => e.key === 'Enter' && goto(`/sessions/${session.id}`)}
                      aria-pressed={kb.selectedIndex === fi}
                    >
                      <td class="bos-table-cell sl-td-status">
                        <StatusDot color={dotColor(session.status)} pulse={session.status === 'running'} />
                      </td>
                      <td class="bos-table-cell sl-mono">{session.runtimeType}</td>
                      <td class="bos-table-cell sl-td-prompt">{promptPreview(session)}</td>
                      <td class="bos-table-cell sl-mono">{relativeTime(session.insertedAt)}</td>
                      <td class="bos-table-cell sl-mono">{parseFloat(session.costUsd) > 0 ? `$${parseFloat(session.costUsd).toFixed(2)}` : '—'}</td>
                    </tr>
                  {/each}
                </tbody>
              </Table>
            </div>
          {/if}
        </div>
      {/each}
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

  /* ── Toolbar: filters left, controls right ── */
  .sl-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
    flex-wrap: wrap;
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
  }

  .sl-controls {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
    flex-wrap: wrap;
  }

  /* ── Show-ended toggle ── */
  .sl-toggle {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    padding: 3px 8px;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: transparent;
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    color: var(--fg-muted);
    cursor: pointer;
    white-space: nowrap;
    transition: border-color var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .sl-toggle:hover {
    color: var(--fg);
    border-color: var(--fg-muted);
  }

  .sl-toggle--on {
    border-color: var(--cnp-accent);
    color: var(--cnp-accent);
  }

  .sl-toggle:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .sl-badge {
    font-family: var(--font-mono);
    font-size: 10px;
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    border-radius: 999px;
    padding: 0 4px;
    color: var(--fg-subtle);
  }

  /* ── Cleanup dropdown ── */
  .sl-cleanup-wrap {
    position: relative;
  }

  .sl-cleanup-btn {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    padding: 3px 8px;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: transparent;
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    color: var(--fg-muted);
    cursor: pointer;
    white-space: nowrap;
    transition: border-color var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .sl-cleanup-btn:hover {
    color: var(--fg);
    border-color: var(--fg-muted);
  }

  .sl-cleanup-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .sl-cleanup-backdrop {
    position: fixed;
    inset: 0;
    z-index: 49;
  }

  .sl-cleanup-menu {
    position: absolute;
    top: calc(100% + 4px);
    right: 0;
    z-index: 50;
    min-width: 200px;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-1) 0;
    list-style: none;
    margin: 0;
    box-shadow: 0 4px 16px color-mix(in oklch, var(--fg) 12%, transparent);
  }

  .sl-menu-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    padding: var(--space-2) var(--space-3);
    background: transparent;
    border: none;
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--fg);
    cursor: pointer;
    text-align: left;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .sl-menu-item:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 6%, transparent);
  }

  .sl-menu-item:disabled {
    color: var(--fg-subtle);
    cursor: default;
  }

  .sl-menu-item:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: -2px;
  }

  .sl-menu-count {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    border-radius: 999px;
    padding: 0 5px;
    margin-left: var(--space-2);
  }

  .sl-menu-sep {
    height: 1px;
    background: var(--border);
    margin: var(--space-1) 0;
  }

  /* ── Confirm overlay ── */
  .sl-overlay {
    position: fixed;
    inset: 0;
    z-index: 60;
    display: flex;
    align-items: center;
    justify-content: center;
    background: color-mix(in oklch, var(--fg) 35%, transparent);
  }

  .sl-dialog {
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    padding: var(--space-6);
    max-width: 340px;
    width: calc(100% - var(--space-8));
  }

  .sl-dialog-body {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    margin: 0 0 var(--space-5);
    line-height: 1.5;
  }

  .sl-dialog-actions {
    display: flex;
    justify-content: flex-end;
    gap: var(--space-2);
  }

  .sl-dialog-cancel,
  .sl-dialog-confirm {
    padding: var(--space-2) var(--space-4);
    border-radius: var(--radius-md);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    cursor: pointer;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .sl-dialog-cancel {
    background: transparent;
    border: 1px solid var(--border);
    color: var(--fg-muted);
  }

  .sl-dialog-cancel:hover:not(:disabled) {
    color: var(--fg);
  }

  .sl-dialog-confirm {
    background: color-mix(in oklch, var(--fg) 90%, transparent);
    border: 1px solid transparent;
    color: var(--bg);
  }

  .sl-dialog-confirm:hover:not(:disabled) {
    background: var(--fg);
  }

  .sl-dialog-cancel:disabled,
  .sl-dialog-confirm:disabled {
    opacity: 0.5;
    cursor: default;
  }

  /* ── Result toast ── */
  .sl-result {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    padding: var(--space-1) var(--space-2);
    background: color-mix(in oklch, var(--fg) 5%, transparent);
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    align-self: flex-start;
  }

  /* ── All hidden ── */
  .sl-all-hidden {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    padding: var(--space-8) 0;
    text-align: center;
  }

  .sl-inline-link {
    background: transparent;
    border: none;
    color: var(--cnp-accent);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    cursor: pointer;
    padding: 0 var(--space-1);
    text-decoration: underline;
  }

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

  .sl-help__close { margin-left: auto; }

  .sl-skeleton-wrap { flex: 1; }

  /* ── Groups ── */
  .sl-groups {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .sl-group {
    display: flex;
    flex-direction: column;
  }

  .sl-group-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-1) var(--space-2);
    background: transparent;
    border: none;
    cursor: pointer;
    text-align: left;
    border-radius: var(--radius-md);
    transition: background var(--dur-instant) var(--ease-out);
  }

  .sl-group-header:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  .sl-group-chevron {
    font-size: 10px;
    color: var(--fg-subtle);
    transition: transform 0.15s var(--ease-out);
    display: inline-block;
    flex-shrink: 0;
    transform: rotate(90deg);
  }

  .sl-group-chevron.collapsed {
    transform: rotate(0deg);
  }

  .sl-group-name {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-muted);
    letter-spacing: 0.04em;
    flex: 1;
  }

  .sl-group-count {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    padding: 1px 6px;
    border-radius: 999px;
    flex-shrink: 0;
  }

  .sl-table-wrap {
    overflow-x: auto;
    border-radius: var(--radius-lg);
    border: 1px solid var(--border);
    margin-top: var(--space-1);
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

  :global(.sl-row) { cursor: pointer; }

  :global(.sl-row td) {
    padding-top: var(--sl-row-pad, var(--space-2) var(--space-3)) !important;
    padding-bottom: var(--sl-row-pad, var(--space-2) var(--space-3)) !important;
  }

  :global(.sl-row--selected) {
    background: color-mix(in oklch, var(--fg) 5%, transparent 95%) !important;
  }

  :global(.sl-td-status) {
    padding-right: 0 !important;
    width: 32px !important;
  }

  .sl-td-prompt {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    max-width: 360px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .sl-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }
</style>
