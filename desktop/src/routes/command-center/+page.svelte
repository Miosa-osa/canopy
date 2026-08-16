<script lang="ts">
/**
 * Command Center — live grid of all running sessions, with optional grouping.
 * Route: /command-center
 *
 * Data: TanStack Query polling every 5s via sessionsQuery({ status: 'running' }).
 * Grid: 3-wide desktop, 2-wide tablet, 1-wide mobile.
 * Tile cap: 12 visible per group, "+N more" tile above that.
 * Group-by: none | project | workspace | agent | runtime (persisted to localStorage).
 * Empty state: "No agents running" + New session CTA.
 *
 * CSS prefix: cc- (CommandCenter)
 * LOC target: ≤ 500.
 */

import { createQuery } from '@tanstack/svelte-query';
import { writable } from 'svelte/store';
import { untrack, onDestroy } from 'svelte';
import { Terminal, Plus, ChevronDown, ChevronRight, PauseCircle, XCircle } from 'lucide-svelte';
import { goto } from '$app/navigation';
import { ui } from '$lib/stores/ui.svelte.js';
import { sessionsQuery, bulkDeleteSessions } from '$lib/api/queries/sessions.js';
import { subscribeLiveRuns } from '$lib/api/queries/live-runs.js';
import type { LiveRunEvent } from '$lib/api/queries/live-runs.js';
import CommandTile from '$lib/design/patterns/command-center/CommandTile.svelte';
import { GroupingState } from '$lib/design/patterns/command-center/useGrouping.svelte.js';
import type { GroupBy } from '$lib/design/patterns/command-center/useGrouping.svelte.js';
import type { Session } from '$lib/domain/sessions/types.js';
import ViewPicker from '$lib/design/primitives/ViewPicker.svelte';
import type { ViewState } from '$lib/design/primitives/ViewPicker.svelte';

// ── Constants ─────────────────────────────────────────────────────────────────

const TILE_CAP = 12;
const REFETCH_MS = 5_000;
const PULSE_MS = 1_200; // duration of the tile pulse animation

// ── Query — running sessions, 5s refetch ──────────────────────────────────────

// No status filter — fetch running + pending so newly created sessions appear
// immediately within the 5s polling window. Filter client-side via filterStatus.
const queryOpts = writable(
  untrack(() => ({
    ...sessionsQuery({}),
    refetchInterval: REFETCH_MS,
  })),
);

const sessionsQ = createQuery<Session[]>(queryOpts);

// ── Filters ───────────────────────────────────────────────────────────────────

let filterRuntime = $state('');
let filterWorkspace = $state('');
// Default to active statuses so command center shows live + queued sessions.
let filterStatus = $state<'active' | 'running' | 'pending' | 'paused' | 'error' | ''>('active');

// Pause-all: client-side toggle — streams pause visually, WS stays alive.
let pauseAll = $state(false);
const pausedIds = $state(new Set<string>());

function handlePauseAll(): void {
  pauseAll = !pauseAll;
}

function handleTilePause(id: string): void {
  if (pausedIds.has(id)) {
    pausedIds.delete(id);
  } else {
    pausedIds.add(id);
  }
}

// ── Grouping state ────────────────────────────────────────────────────────────

const grouping = new GroupingState();

const GROUP_BY_OPTIONS: { value: GroupBy; label: string }[] = [
  { value: 'none', label: 'No grouping' },
  { value: 'project', label: 'By project' },
  { value: 'workspace', label: 'By workspace' },
  { value: 'agent', label: 'By agent' },
  { value: 'runtime', label: 'By runtime' },
];

// ── Derived display data ──────────────────────────────────────────────────────

const allSessions = $derived(($sessionsQ.data ?? []) as Session[]);

const filteredSessions = $derived(
  allSessions.filter((s) => {
    if (filterRuntime && !s.runtimeType.toLowerCase().includes(filterRuntime.toLowerCase())) return false;
    if (filterWorkspace && s.workspaceSlug !== filterWorkspace) return false;
    if (filterStatus === 'active') {
      if (s.status !== 'running' && s.status !== 'pending' && s.status !== 'paused') return false;
    } else if (filterStatus) {
      if (s.status !== filterStatus) return false;
    }
    return true;
  }),
);

const sessionGroups = $derived(grouping.groups(filteredSessions));

const uniqueRuntimes = $derived(
  [...new Set(allSessions.map((s) => s.runtimeType))].sort(),
);
const uniqueWorkspaces = $derived(
  [...new Set(allSessions.map((s) => s.workspaceSlug).filter(Boolean) as string[])].sort(),
);

const totalCount = $derived(allSessions.length);
const isLoading = $derived($sessionsQ.isLoading);
const showGroupHeaders = $derived(grouping.groupBy !== 'none');

// ── Live-run WebSocket subscription ───────────────────────────────────────────
// On run_started: briefly pulse the tile whose session is visible.
// On run_finished: update the status pill immediately (no poll wait).

const { events: liveRunEvents, disconnect: disconnectLiveRuns } = subscribeLiveRuns({
  workspace: 'default',
});

// session_id → set of active pulse timers (cleared automatically after PULSE_MS)
const pulsingSessionIds = $state(new Set<string>());

// session_id → live status override (cleared when poll catches up)
const liveStatusOverrides = $state(new Map<string, Session['status']>());

$effect(() => {
  const evs = $liveRunEvents;
  if (evs.length === 0) return;

  // Only process the most recent event to avoid re-processing history on re-render.
  const latest: LiveRunEvent = evs[0];
  const p = latest.payload as unknown as Record<string, unknown>;
  const sessionId = (p.sessionId ?? p.session_id ?? '') as string;

  if (latest.kind === 'run_started' && sessionId) {
    // Pulse the tile for this session
    pulsingSessionIds.add(sessionId);
    setTimeout(() => {
      pulsingSessionIds.delete(sessionId);
    }, PULSE_MS);
  }

  if (latest.kind === 'run_finished' && sessionId) {
    // Eagerly update the status pill to reflect terminal run state.
    // The poll will overwrite this within REFETCH_MS.
    const runStatus = (p.status ?? '') as string;
    if (runStatus === 'succeeded') {
      liveStatusOverrides.set(sessionId, 'completed' as Session['status']);
    } else if (runStatus === 'failed') {
      liveStatusOverrides.set(sessionId, 'error' as Session['status']);
    }
  }
});

onDestroy(disconnectLiveRuns);

// ── ViewPicker + cleanup ──────────────────────────────────────────────────────

let view = $state<ViewState>({ layout: 'grid', density: 'comfortable', sort: 'recent' });

let showEnded = $state(false);
const TERMINAL_STATUSES = new Set(['completed', 'cancelled', 'failed', 'ended']);

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;

let cleanupMenuOpen = $state(false);
let confirmOpen = $state(false);
let confirmLabel = $state('');
let pendingCleanup = $state<(() => Promise<void>) | null>(null);
let isDeleting = $state(false);

const endedCount = $derived(allSessions.filter((s) => TERMINAL_STATUSES.has(s.status)).length);
const oldDayCount = $derived(
  allSessions.filter((s) =>
    TERMINAL_STATUSES.has(s.status) && Date.now() - new Date(s.insertedAt).getTime() > DAY_MS
  ).length
);

function askCleanup(label: string, fn: () => Promise<void>): void {
  confirmLabel = label;
  pendingCleanup = fn;
  confirmOpen = true;
  cleanupMenuOpen = false;
}

async function runCleanup(): Promise<void> {
  if (!pendingCleanup) return;
  isDeleting = true;
  try {
    await pendingCleanup();
  } finally {
    isDeleting = false;
    confirmOpen = false;
    pendingCleanup = null;
  }
}
</script>

<div class="cc-root">
  <!-- ── Top bar ──────────────────────────────────────────────────────────── -->
  <header class="cc-topbar" aria-label="Command center controls">
    <div class="cc-topbar-left">
      <h1 class="cc-title">Command Center</h1>
      {#if !isLoading}
        <span class="cc-count" aria-live="polite">
          {totalCount} {totalCount === 1 ? 'session' : 'sessions'}
        </span>
      {/if}
    </div>

    <div class="cc-topbar-right">
      <!-- Group-by picker -->
      <select
        class="cc-filter cc-filter--group"
        value={grouping.groupBy}
        onchange={(e) => grouping.setGroupBy((e.currentTarget as HTMLSelectElement).value as GroupBy)}
        aria-label="Group sessions by"
      >
        {#each GROUP_BY_OPTIONS as opt (opt.value)}
          <option value={opt.value}>{opt.label}</option>
        {/each}
      </select>

      <!-- Runtime filter -->
      {#if uniqueRuntimes.length > 1}
        <select
          class="cc-filter"
          bind:value={filterRuntime}
          aria-label="Filter by runtime"
        >
          <option value="">All runtimes</option>
          {#each uniqueRuntimes as rt (rt)}
            <option value={rt}>{rt}</option>
          {/each}
        </select>
      {/if}

      <!-- Workspace filter -->
      {#if uniqueWorkspaces.length > 1}
        <select
          class="cc-filter"
          bind:value={filterWorkspace}
          aria-label="Filter by workspace"
        >
          <option value="">All workspaces</option>
          {#each uniqueWorkspaces as ws (ws)}
            <option value={ws}>{ws}</option>
          {/each}
        </select>
      {/if}

      <!-- Status filter -->
      <select
        class="cc-filter"
        bind:value={filterStatus}
        aria-label="Filter by status"
      >
        <option value="active">Active (running + queued)</option>
        <option value="">All statuses</option>
        <option value="running">Running</option>
        <option value="pending">Queued</option>
        <option value="paused">Paused</option>
        <option value="error">Error</option>
      </select>

      <!-- Pause-all -->
      <button
        class="cc-btn"
        class:cc-btn--active={pauseAll}
        onclick={handlePauseAll}
        aria-label={pauseAll ? 'Resume all streams' : 'Pause all streams'}
        title={pauseAll ? 'Resume all' : 'Pause all'}
      >
        {pauseAll ? 'Resume all' : 'Pause all'}
      </button>

      <!-- Show ended toggle -->
      <button
        class="cc-btn"
        class:cc-btn--active={showEnded}
        onclick={() => { showEnded = !showEnded; filterStatus = showEnded ? '' : 'active'; }}
        aria-pressed={showEnded}
        title={showEnded ? 'Hide ended sessions' : 'Show ended sessions'}
      >
        {showEnded ? 'Hide ended' : 'Show ended'}
        {#if endedCount > 0 && !showEnded}
          <span class="cc-ended-badge">{endedCount}</span>
        {/if}
      </button>

      <!-- Cleanup -->
      <div class="cc-cleanup-wrap" style="position:relative">
        <button
          class="cc-btn"
          onclick={() => { cleanupMenuOpen = !cleanupMenuOpen; }}
          aria-haspopup="menu"
          aria-expanded={cleanupMenuOpen}
        >
          Clean up
        </button>
        {#if cleanupMenuOpen}
          <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
          <div
            style="position:fixed;inset:0;z-index:49"
            onclick={() => { cleanupMenuOpen = false; }}
          ></div>
          <menu class="cc-cleanup-menu" role="menu">
            <li role="presentation">
              <button class="cc-menu-item" role="menuitem"
                onclick={() => askCleanup(`Delete all ended sessions (${endedCount})?`, () => bulkDeleteSessions().then(() => undefined))}
                disabled={endedCount === 0}
              >
                Clear all ended {#if endedCount > 0}<span class="cc-menu-count">{endedCount}</span>{/if}
              </button>
            </li>
            <li role="presentation">
              <button class="cc-menu-item" role="menuitem"
                onclick={() => askCleanup(`Delete ended sessions older than 1 day (${oldDayCount})?`, () => bulkDeleteSessions({ before: new Date(Date.now() - DAY_MS).toISOString() }).then(() => undefined))}
                disabled={oldDayCount === 0}
              >
                Clear &gt; 1 day old {#if oldDayCount > 0}<span class="cc-menu-count">{oldDayCount}</span>{/if}
              </button>
            </li>
          </menu>
        {/if}
      </div>

      <!-- ViewPicker -->
      <ViewPicker routeSlug="command-center" bind:view />
    </div>
  </header>

  <!-- Confirm modal -->
  {#if confirmOpen}
    <div style="position:fixed;inset:0;z-index:60;display:flex;align-items:center;justify-content:center;background:color-mix(in oklch,var(--fg) 35%,transparent)" role="dialog" aria-modal="true">
      <div style="background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-lg);padding:var(--space-6);max-width:320px;width:90%">
        <p style="font-family:var(--font-sans);font-size:var(--text-sm);color:var(--fg);margin:0 0 var(--space-5)">{confirmLabel}</p>
        <div style="display:flex;justify-content:flex-end;gap:var(--space-2)">
          <button class="cc-btn" onclick={() => { confirmOpen = false; pendingCleanup = null; }} disabled={isDeleting}>Cancel</button>
          <button class="cc-btn cc-btn--active" onclick={runCleanup} disabled={isDeleting}>{isDeleting ? 'Deleting…' : 'Delete'}</button>
        </div>
      </div>
    </div>
  {/if}

  <!-- ── Content ─────────────────────────────────────────────────────────── -->
  {#if isLoading}
    <div class="cc-grid" aria-busy="true" aria-label="Loading sessions">
      {#each Array(3) as _, i (i)}
        <div class="cc-skeleton" aria-hidden="true"></div>
      {/each}
    </div>

  {:else if filteredSessions.length === 0}
    <div class="cc-empty" role="status">
      <div class="cc-empty-icon" aria-hidden="true">
        <Terminal size={28} />
      </div>
      <p class="cc-empty-heading">No agents running</p>
      <p class="cc-empty-sub">Start a session to see it here.</p>
      <button
        class="cc-new-btn"
        onclick={() => ui.openNewSessionModal()}
        aria-label="Start new session"
      >
        <Plus size={14} aria-hidden="true" />
        New session
      </button>
    </div>

  {:else if showGroupHeaders}
    <!-- Grouped layout -->
    <div class="cc-groups">
      {#each sessionGroups as group (group.key)}
        {@const collapsed = grouping.isCollapsed(group.key)}
        {@const visible = group.sessions.slice(0, TILE_CAP)}
        {@const overflow = Math.max(0, group.sessions.length - TILE_CAP)}

        <section class="cc-group" aria-label="Group: {group.label}">
          <!-- Group header -->
          <div class="cc-group-header">
            <button
              class="cc-group-toggle"
              onclick={() => grouping.toggleCollapsed(group.key)}
              aria-expanded={!collapsed}
              aria-controls="cc-group-body-{group.key}"
            >
              {#if collapsed}
                <ChevronRight size={12} aria-hidden="true" />
              {:else}
                <ChevronDown size={12} aria-hidden="true" />
              {/if}
              <span class="cc-group-label">{group.label}</span>
              <span class="cc-group-badge">{group.sessions.length}</span>
            </button>

            <!-- Per-group actions -->
            <div class="cc-group-actions">
              <button
                class="cc-group-action"
                onclick={handlePauseAll}
                aria-label="Pause all in {group.label}"
                title="Pause all"
              >
                <PauseCircle size={12} aria-hidden="true" />
              </button>
              <button
                class="cc-group-action cc-group-action--danger"
                onclick={() => goto('/sessions')}
                aria-label="Stop all in {group.label}"
                title="Stop all (goes to Sessions)"
              >
                <XCircle size={12} aria-hidden="true" />
              </button>
            </div>
          </div>

          <!-- Group body -->
          {#if !collapsed}
            <div
              class="cc-grid"
              id="cc-group-body-{group.key}"
              aria-label="Sessions in {group.label}"
            >
              {#each visible as session (session.id)}
                <div class:cc-tile-pulse={pulsingSessionIds.has(session.id)}>
                  <CommandTile {session} onPause={handleTilePause} />
                </div>
              {/each}

              {#if overflow > 0}
                <button
                  class="cc-overflow-tile"
                  onclick={() => goto('/sessions')}
                  aria-label="View {overflow} more sessions"
                >
                  <span class="cc-overflow-count">+{overflow}</span>
                  <span class="cc-overflow-label">more sessions</span>
                </button>
              {/if}
            </div>
          {/if}
        </section>
      {/each}
    </div>

  {:else}
    <!-- Flat layout (no grouping) -->
    {@const visible = filteredSessions.slice(0, TILE_CAP)}
    {@const overflow = Math.max(0, filteredSessions.length - TILE_CAP)}
    <div class="cc-grid" aria-label="Active sessions">
      {#each visible as session (session.id)}
        <CommandTile {session} onPause={handleTilePause} />
      {/each}

      {#if overflow > 0}
        <button
          class="cc-overflow-tile"
          onclick={() => goto('/sessions')}
          aria-label="View {overflow} more sessions"
        >
          <span class="cc-overflow-count">+{overflow}</span>
          <span class="cc-overflow-label">more sessions</span>
        </button>
      {/if}
    </div>
  {/if}
</div>

<style>
  .cc-root {
    flex: 1;
    display: flex;
    flex-direction: column;
    padding: var(--space-6) var(--space-6) var(--space-4);
    gap: var(--space-4);
    overflow-y: auto;
    min-height: 0;
    background: var(--bg-inset, var(--bg));
  }

  /* ── Top bar ──────────────────────────────────────────────────────────────── */
  .cc-topbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-4);
    flex-shrink: 0;
    flex-wrap: wrap;
  }

  .cc-topbar-left {
    display: flex;
    align-items: baseline;
    gap: var(--space-3);
  }

  .cc-title {
    font-size: 13px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    margin: 0;
  }

  .cc-count {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-subtle);
  }

  .cc-topbar-right {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-wrap: wrap;
  }

  .cc-filter {
    font-size: 11px;
    font-family: var(--font-sans);
    color: var(--fg);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 3px 6px;
    outline: none;
    cursor: pointer;
  }

  .cc-filter--group {
    border-color: var(--cnp-accent);
    color: var(--cnp-accent);
  }

  .cc-filter:focus-visible {
    border-color: var(--cnp-accent);
  }

  .cc-btn {
    font-size: 11px;
    font-weight: 600;
    font-family: var(--font-sans);
    padding: 3px 10px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: var(--bg-inset);
    color: var(--fg-subtle);
    cursor: pointer;
    transition: border-color var(--dur-fast) var(--ease-out), color var(--dur-fast) var(--ease-out);
  }

  .cc-btn:hover {
    border-color: var(--cnp-accent);
    color: var(--fg);
  }

  .cc-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .cc-btn--active {
    border-color: var(--cnp-accent);
    color: var(--cnp-accent);
    background: color-mix(in oklch, var(--cnp-accent) 8%, transparent);
  }

  /* ── Groups ───────────────────────────────────────────────────────────────── */
  .cc-groups {
    display: flex;
    flex-direction: column;
    gap: var(--space-6);
  }

  .cc-group {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .cc-group-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-2);
  }

  .cc-group-toggle {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    background: transparent;
    border: none;
    cursor: pointer;
    padding: var(--space-1) 0;
    color: var(--fg-subtle);
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
  }

  .cc-group-toggle:hover {
    color: var(--fg);
  }

  .cc-group-toggle:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
    border-radius: var(--radius-sm);
  }

  .cc-group-label {
    flex: 1;
  }

  .cc-group-badge {
    font-family: var(--font-mono);
    font-size: 10px;
    padding: 1px 6px;
    border-radius: 9999px;
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    color: var(--fg-subtle);
  }

  .cc-group-actions {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    opacity: 0;
    transition: opacity var(--dur-instant) var(--ease-out);
  }

  .cc-group:hover .cc-group-actions {
    opacity: 1;
  }

  .cc-group-action {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 20px;
    height: 20px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-subtle);
    cursor: pointer;
    transition:
      border-color var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .cc-group-action:hover {
    border-color: var(--cnp-accent);
    color: var(--fg);
  }

  .cc-group-action--danger:hover {
    border-color: var(--signal-error);
    color: var(--signal-error);
  }

  .cc-group-action:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  /* ── Grid ─────────────────────────────────────────────────────────────────── */
  .cc-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--space-3);
    align-content: start;
  }

  @media (max-width: 900px) {
    .cc-grid { grid-template-columns: repeat(2, 1fr); }
  }

  @media (max-width: 560px) {
    .cc-grid { grid-template-columns: 1fr; }
  }

  /* ── Skeleton ─────────────────────────────────────────────────────────────── */
  .cc-skeleton {
    height: 220px;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    animation: cc-pulse 1.5s ease-in-out infinite;
  }

  @keyframes cc-pulse { 0%, 100% { opacity: 0.4; } 50% { opacity: 0.8; } }

  /* Tile pulse — triggered by live run_started event */
  :global(.cc-tile-pulse) {
    animation: cc-tile-highlight 1.2s ease-out forwards;
  }

  @keyframes cc-tile-highlight {
    0%   { box-shadow: 0 0 0 2px var(--cnp-accent); }
    60%  { box-shadow: 0 0 0 4px color-mix(in oklch, var(--cnp-accent) 40%, transparent); }
    100% { box-shadow: none; }
  }

  /* ── Empty state ─────────────────────────────────────────────────────────── */
  .cc-empty {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--space-3);
    padding: var(--space-12);
    text-align: center;
  }

  .cc-empty-icon {
    color: var(--fg-subtle);
    opacity: 0.5;
  }

  .cc-empty-heading {
    font-size: 15px;
    font-weight: 600;
    color: var(--fg);
    margin: 0;
  }

  .cc-empty-sub {
    font-size: 13px;
    color: var(--fg-subtle);
    margin: 0;
  }

  .cc-new-btn {
    display: inline-flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-4);
    font-size: 13px;
    font-weight: 600;
    font-family: var(--font-sans);
    border-radius: var(--radius-md);
    border: 1px solid var(--cnp-accent);
    background: color-mix(in oklch, var(--cnp-accent) 10%, transparent);
    color: var(--cnp-accent);
    cursor: pointer;
    transition: background var(--dur-fast) var(--ease-out);
    margin-top: var(--space-2);
  }

  .cc-new-btn:hover {
    background: color-mix(in oklch, var(--cnp-accent) 18%, transparent);
  }

  .cc-new-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  /* ── Overflow tile ────────────────────────────────────────────────────────── */
  .cc-overflow-tile {
    height: 220px;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--space-2);
    background: var(--bg-inset);
    border: 1px dashed var(--border);
    border-radius: var(--radius-lg);
    cursor: pointer;
    font-family: var(--font-sans);
    transition: border-color var(--dur-fast) var(--ease-out);
  }

  .cc-overflow-tile:hover {
    border-color: var(--cnp-accent);
  }

  .cc-overflow-tile:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .cc-overflow-count {
    font-family: var(--font-mono);
    font-size: 28px;
    color: var(--fg);
    font-variant-numeric: tabular-nums;
  }

  .cc-overflow-label {
    font-size: 11px;
    color: var(--fg-subtle);
    letter-spacing: 0.04em;
  }

  .cc-ended-badge {
    font-family: var(--font-mono);
    font-size: 10px;
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    border-radius: 999px;
    padding: 0 4px;
    margin-left: 2px;
  }

  .cc-cleanup-menu {
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

  .cc-menu-item {
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
  }

  .cc-menu-item:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 6%, transparent);
  }

  .cc-menu-item:disabled { color: var(--fg-subtle); cursor: default; }

  .cc-menu-count {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    border-radius: 999px;
    padding: 0 5px;
  }

  @media (prefers-reduced-motion: reduce) {
    .cc-skeleton { animation: none; }
    .cc-btn, .cc-new-btn, .cc-overflow-tile { transition: none; }
    .cc-group-actions { transition: none; }
    .cc-group-action { transition: none; }
  }
</style>
