<script lang="ts">
/**
 * /agent-control — Agent Control Center.
 * Tabs: Agents (5-lane lifecycle board) | Tasks (agent kanban board).
 * CSS prefix: agc-
 * LOC target: ≤ 340.
 */
import {
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { ChevronDown, ChevronRight, RefreshCw, X } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { agentKanbanBoardQuery } from '$lib/api/queries/agent-kanban.js';
import { listAgents } from '$lib/api/queries/agents.js';
import { listRoutines } from '$lib/api/queries/routines.js';
import { listRuntimes } from '$lib/api/queries/runtimes.js';
import {
  listSessions,
  pauseSession,
  resumeSession,
  stopSession,
} from '$lib/api/queries/sessions.js';
import ControlLane from '$lib/design/patterns/agent-control/ControlLane.svelte';
import type { AgentLane } from '$lib/design/patterns/agent-control/types.js';
import { LANE_CONFIGS } from '$lib/design/patterns/agent-control/types.js';
import AgentKanbanPane from '$lib/design/patterns/mosaic/panes/AgentKanbanPane.svelte';
import type { AgentKanbanBoard } from '$lib/domain/agent-kanban/types.js';
import type { Agent } from '$lib/domain/agents/types.js';
import type { Routine } from '$lib/domain/routines/types.js';
import type { Runtime } from '$lib/domain/runtimes/types.js';
import type { Session } from '$lib/domain/sessions/types.js';
import { ui } from '$lib/stores/ui.svelte.js';

const LS_VIEW_KEY = 'canopy.agent_control.view';
const LS_TAB_KEY = 'canopy.agent_control.tab';
const LS_SETTINGS_KEY = 'canopy.agent_control.settings';

// ── Tab state ──────────────────────────────────────────────────────────────────

type TabId = 'agents' | 'tasks';

function loadTab(): TabId {
  try {
    return (localStorage.getItem(LS_TAB_KEY) as TabId | null) ?? 'agents';
  } catch {
    return 'agents';
  }
}
function saveTab(t: TabId): void {
  try {
    localStorage.setItem(LS_TAB_KEY, t);
  } catch {
    /* quota */
  }
}

let activeTab = $state<TabId>(loadTab());
$effect(() => {
  saveTab(activeTab);
});

// ── Settings state ─────────────────────────────────────────────────────────────

interface AgentControlSettings {
  autoPickup: boolean;
  defaultAgentSlug: string;
  maxConcurrentClaims: number;
}

const DEFAULT_SETTINGS: AgentControlSettings = {
  autoPickup: false,
  defaultAgentSlug: '',
  maxConcurrentClaims: 1,
};

function loadSettings(): AgentControlSettings {
  try {
    const raw = localStorage.getItem(LS_SETTINGS_KEY);
    if (!raw) return { ...DEFAULT_SETTINGS };
    return { ...DEFAULT_SETTINGS, ...(JSON.parse(raw) as Partial<AgentControlSettings>) };
  } catch {
    return { ...DEFAULT_SETTINGS };
  }
}
function saveSettings(s: AgentControlSettings): void {
  try {
    localStorage.setItem(LS_SETTINGS_KEY, JSON.stringify(s));
  } catch {
    /* quota */
  }
}

let settings = $state<AgentControlSettings>(loadSettings());
$effect(() => {
  saveSettings(settings);
});

let settingsOpen = $state(false);

const queryClient = useQueryClient();

// ── Queries ───────────────────────────────────────────────────────────────────

const agentsOptsStore = writable(
  untrack(
    () =>
      ({
        queryKey: ['agents', {}] as const,
        queryFn: () => listAgents(),
        staleTime: 10_000,
        refetchInterval: 10_000,
      }) as CreateQueryOptions<Agent[]>
  )
);
const agentsQuery = createQuery<Agent[]>(agentsOptsStore);

const sessionsOptsStore = writable(
  untrack(
    () =>
      ({
        queryKey: ['sessions', {}] as const,
        queryFn: () => listSessions(),
        staleTime: 5_000,
        refetchInterval: 10_000,
      }) as CreateQueryOptions<Session[]>
  )
);
const sessionsQuery = createQuery<Session[]>(sessionsOptsStore);

const routinesOptsStore = writable(
  untrack(
    () =>
      ({
        queryKey: ['routines', {}] as const,
        queryFn: () => listRoutines(),
        staleTime: 15_000,
      }) as CreateQueryOptions<Routine[]>
  )
);
const routinesQuery = createQuery<Routine[]>(routinesOptsStore);

const runtimesOptsStore = writable(
  untrack(
    () =>
      ({
        queryKey: ['runtimes'] as const,
        queryFn: listRuntimes,
        staleTime: 30_000,
      }) as CreateQueryOptions<Runtime[]>
  )
);
const runtimesQuery = createQuery<Runtime[]>(runtimesOptsStore);

const kanbanBoardOptsStore = writable(
  untrack(() => agentKanbanBoardQuery({ workspaceSlug: 'default' }))
);
const kanbanBoardQuery = createQuery<AgentKanbanBoard>(kanbanBoardOptsStore);

// ── Data derivations ──────────────────────────────────────────────────────────

const allAgents = $derived(($agentsQuery.data ?? []) as Agent[]);
const allSessions = $derived(($sessionsQuery.data ?? []) as Session[]);
const allRoutines = $derived(($routinesQuery.data ?? []) as Routine[]);
const allRuntimes = $derived(($runtimesQuery.data ?? []) as Runtime[]);

/** Agents with an authenticated (installed) runtime available. */
const authenticatedRuntimeTypes = $derived(
  new Set(allRuntimes.filter((r: Runtime) => r.status === 'installed').map((r: Runtime) => r.type))
);

/** Map: agentSlug → most recent active session (running or paused). */
function buildPrimarySessions(sessions: Session[]): Map<string, Session> {
  const map = new Map<string, Session>();
  const sorted = [...sessions].sort(
    (a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime()
  );
  for (const s of sorted) {
    if (!s.agentSlug) continue;
    if (s.status !== 'running' && s.status !== 'paused') continue;
    if (!map.has(s.agentSlug)) map.set(s.agentSlug, s);
  }
  return map;
}

const primarySessions = $derived(buildPrimarySessions(allSessions));

/** Set of agentSlugs that are targets of enabled routines. */
const scheduledSlugs = $derived<Set<string>>(
  new Set(
    allRoutines
      .filter((r: Routine) => r.enabled && r.targetAgentSlug)
      .map((r: Routine) => r.targetAgentSlug as string)
  )
);

/**
 * Primary-lane bucketing rule (highest-priority wins):
 *   running > paused > scheduled > idle > offline
 *
 * running   — agent has ≥1 session with status = "running"
 * paused    — agent has ≥1 session with status = "paused" (no running session)
 * scheduled — agent is target of ≥1 enabled Routine (no active session)
 * idle      — installed runtime + auth, no active session, no routine
 * offline   — no authenticated runtime OR not installed
 */
function computeLane(agent: Agent): AgentLane {
  const session = primarySessions.get(agent.slug);
  if (session?.status === 'running') return 'running';
  if (session?.status === 'paused') return 'paused';
  if (scheduledSlugs.has(agent.slug)) return 'scheduled';
  const rt = agent.defaultRuntime;
  if (rt && authenticatedRuntimeTypes.has(rt)) return 'idle';
  return 'offline';
}

function buildLaneMap(agents: Agent[]): Map<AgentLane, Agent[]> {
  const map = new Map<AgentLane, Agent[]>([
    ['running', []],
    ['paused', []],
    ['scheduled', []],
    ['idle', []],
    ['offline', []],
  ]);
  for (const agent of agents) {
    const lane = computeLane(agent);
    map.get(lane)!.push(agent);
  }
  return map;
}

const laneMap = $derived(buildLaneMap(allAgents));

// ── View / search state ───────────────────────────────────────────────────────

let searchQuery = $state('');
let selectedSlugs = $state<Set<string>>(new Set());

function loadView(): string {
  try {
    return localStorage.getItem(LS_VIEW_KEY) ?? 'all';
  } catch {
    return 'all';
  }
}
function saveView(v: string): void {
  try {
    localStorage.setItem(LS_VIEW_KEY, v);
  } catch {
    /* quota */
  }
}

let currentView = $state(loadView());

$effect(() => {
  saveView(currentView);
});

function filterLaneMap(map: Map<AgentLane, Agent[]>, q: string): Map<AgentLane, Agent[]> {
  if (!q.trim()) return map;
  const lower = q.toLowerCase();
  const result = new Map<AgentLane, Agent[]>();
  for (const [lane, agents] of map) {
    result.set(
      lane,
      agents.filter(
        (a) => a.name.toLowerCase().includes(lower) || a.slug.toLowerCase().includes(lower)
      )
    );
  }
  return result;
}

const filteredLaneMap = $derived(filterLaneMap(laneMap, searchQuery));

// ── Mutations ─────────────────────────────────────────────────────────────────

const pauseMut = createMutation({
  mutationFn: (sessionId: string) => pauseSession(sessionId),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['sessions'] });
  },
});

const resumeMut = createMutation({
  mutationFn: (sessionId: string) => resumeSession(sessionId),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['sessions'] });
  },
});

const stopMut = createMutation({
  mutationFn: (sessionId: string) => stopSession(sessionId),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['sessions'] });
  },
});

// ── Drag-to-lane handler ─────────────────────────────────────────────────────

function handleDrop(agent: Agent, targetLane: AgentLane): void {
  if (targetLane === 'offline') return; // no-op per spec

  const session = primarySessions.get(agent.slug);

  if (targetLane === 'running') {
    if (!session) {
      // No active session — open NewSessionModal (without pre-fill since modal
      // doesn't accept agentSlug/runtimeType props per read of NewSessionModal.svelte).
      ui.openNewSessionModal();
    }
    // If session exists and is paused, resume it.
    else if (session.status === 'paused') {
      $resumeMut.mutate(session.id);
    }
    return;
  }

  if (targetLane === 'paused' && session?.status === 'running') {
    $pauseMut.mutate(session.id);
    return;
  }

  if (targetLane === 'idle' && session) {
    if (confirm(`Stop all sessions for ${agent.name}?`)) {
      $stopMut.mutate(session.id);
    }
    return;
  }

  if (targetLane === 'scheduled') {
    // Open routines — the existing routines UI handles creation.
    // No native prefill available; navigate user there.
    window.location.href = '/routines';
  }
}

// ── Multi-select ─────────────────────────────────────────────────────────────

function handleSelect(slug: string, checked: boolean): void {
  const next = new Set(selectedSlugs);
  if (checked) next.add(slug);
  else next.delete(slug);
  selectedSlugs = next;
}

function clearSelection(): void {
  selectedSlugs = new Set();
}

async function bulkPause(): Promise<void> {
  const ids = [...selectedSlugs]
    .map((slug) => primarySessions.get(slug)?.id)
    .filter((id): id is string => id !== undefined);
  await Promise.allSettled(ids.map((id) => pauseSession(id)));
  queryClient.invalidateQueries({ queryKey: ['sessions'] });
}

async function bulkResume(): Promise<void> {
  const ids = [...selectedSlugs]
    .map((slug) => primarySessions.get(slug)?.id)
    .filter((id): id is string => id !== undefined);
  await Promise.allSettled(ids.map((id) => resumeSession(id)));
  queryClient.invalidateQueries({ queryKey: ['sessions'] });
}

async function bulkStop(): Promise<void> {
  if (!confirm(`Stop sessions for ${selectedSlugs.size} agent(s)?`)) return;
  const ids = [...selectedSlugs]
    .map((slug) => primarySessions.get(slug)?.id)
    .filter((id): id is string => id !== undefined);
  await Promise.allSettled(ids.map((id) => stopSession(id)));
  queryClient.invalidateQueries({ queryKey: ['sessions'] });
  clearSelection();
}

const selectionCount = $derived(selectedSlugs.size);

// ── Stats bar ─────────────────────────────────────────────────────────────────

const statHired = $derived(allAgents.length);
const statRunning = $derived(allSessions.filter((s) => s.status === 'running').length);
const statClaimed = $derived(
  (($kanbanBoardQuery.data as AgentKanbanBoard | undefined)?.claimed ?? []).length
);
const statBacklog = $derived(
  (($kanbanBoardQuery.data as AgentKanbanBoard | undefined)?.backlog ?? []).length
);

const VIEW_OPTIONS = [
  { value: 'all', label: 'All' },
  { value: 'workspace', label: 'By workspace' },
  { value: 'project', label: 'By project' },
];
</script>

<div class="agc-page">
  <!-- Header -->
  <header class="agc-header">
    <div class="agc-header-left">
      <h1 class="agc-title">Agent Control Center</h1>
      <!-- Page tabs: Agents | Tasks -->
      <div class="agc-page-tabs" role="tablist" aria-label="Agent Control tabs">
        <button
          class="agc-page-tab"
          class:agc-page-tab--active={activeTab === 'agents'}
          role="tab"
          aria-selected={activeTab === 'agents'}
          onclick={() => { activeTab = 'agents'; }}
        >Agents</button>
        <button
          class="agc-page-tab"
          class:agc-page-tab--active={activeTab === 'tasks'}
          role="tab"
          aria-selected={activeTab === 'tasks'}
          onclick={() => { activeTab = 'tasks'; }}
        >Tasks</button>
      </div>
      {#if activeTab === 'agents'}
        <div class="agc-view-tabs" role="tablist" aria-label="View options">
          {#each VIEW_OPTIONS as opt (opt.value)}
            <button
              class="agc-view-tab"
              class:agc-view-tab--active={currentView === opt.value}
              role="tab"
              aria-selected={currentView === opt.value}
              onclick={() => { currentView = opt.value; }}
            >
              {opt.label}
            </button>
          {/each}
        </div>
      {/if}
    </div>
    <div class="agc-header-right">
      {#if activeTab === 'agents'}
        <input
          class="agc-search"
          type="search"
          placeholder="Search agents…"
          bind:value={searchQuery}
          aria-label="Search agents"
        />
      {/if}
      <button
        class="agc-icon-btn"
        onclick={() => {
          queryClient.invalidateQueries({ queryKey: ['agents'] });
          queryClient.invalidateQueries({ queryKey: ['sessions'] });
          queryClient.invalidateQueries({ queryKey: ['agent-kanban'] });
        }}
        aria-label="Refresh"
        title="Refresh"
      >
        <RefreshCw size={13} aria-hidden="true" />
      </button>
    </div>
  </header>

  <!-- Stats bar -->
  <div class="agc-stats" aria-label="Agent stats">
    <span class="agc-stat"><strong>{statHired}</strong> agents hired</span>
    <span class="agc-stat-sep" aria-hidden="true">·</span>
    <span class="agc-stat"><strong>{statRunning}</strong> running</span>
    <span class="agc-stat-sep" aria-hidden="true">·</span>
    <span class="agc-stat"><strong>{statClaimed}</strong> tasks claimed</span>
    <span class="agc-stat-sep" aria-hidden="true">·</span>
    <span class="agc-stat"><strong>{statBacklog}</strong> in backlog</span>
  </div>

  <!-- Tab panels -->
  {#if activeTab === 'agents'}
    <!-- Loading / error states -->
    {#if $agentsQuery.isLoading || $sessionsQuery.isLoading}
      <div class="agc-loading" role="status" aria-live="polite">Loading agents…</div>
    {:else if $agentsQuery.isError}
      <div class="agc-error" role="alert">
        Failed to load agents: {($agentsQuery.error as Error).message}
      </div>
    {:else}
      <!-- Lane board -->
      <div class="agc-board" role="region" aria-label="Agent lanes">
        {#each LANE_CONFIGS as cfg (cfg.id)}
          <ControlLane
            lane={cfg.id}
            label={cfg.label}
            color={cfg.color}
            agents={filteredLaneMap.get(cfg.id) ?? []}
            {scheduledSlugs}
            {primarySessions}
            {selectedSlugs}
            onSelect={handleSelect}
            onPause={(id) => $pauseMut.mutate(id)}
            onResume={(id) => $resumeMut.mutate(id)}
            onDrop={handleDrop}
          />
        {/each}
      </div>

      <!-- Settings section (collapsible, bottom of Agents tab) -->
      <div class="agc-settings">
        <button
          class="agc-settings-toggle"
          onclick={() => { settingsOpen = !settingsOpen; }}
          aria-expanded={settingsOpen}
          aria-controls="agc-settings-body"
        >
          {#if settingsOpen}
            <ChevronDown size={12} aria-hidden="true" />
          {:else}
            <ChevronRight size={12} aria-hidden="true" />
          {/if}
          Settings
        </button>
        {#if settingsOpen}
          <div class="agc-settings-body" id="agc-settings-body">
            <label class="agc-setting-row">
              <span class="agc-setting-label">Auto-pickup</span>
              <input
                type="checkbox"
                bind:checked={settings.autoPickup}
                aria-label="Global auto-pickup on/off"
              />
            </label>
            <label class="agc-setting-row">
              <span class="agc-setting-label">Default agent for new tasks</span>
              <select
                class="agc-setting-select"
                bind:value={settings.defaultAgentSlug}
                aria-label="Default agent for new tasks"
              >
                <option value="">— none —</option>
                {#each allAgents as agent (agent.slug)}
                  <option value={agent.slug}>{agent.name}</option>
                {/each}
              </select>
            </label>
            <label class="agc-setting-row">
              <span class="agc-setting-label">Max concurrent claims per agent</span>
              <input
                class="agc-setting-number"
                type="number"
                min="1"
                max="5"
                bind:value={settings.maxConcurrentClaims}
                aria-label="Max concurrent claims per agent"
              />
            </label>
          </div>
        {/if}
      </div>
    {/if}
  {:else}
    <!-- Tasks tab: Agent Kanban board -->
    <div class="agc-tasks-panel">
      <AgentKanbanPane workspaceSlug="default" />
    </div>
  {/if}

  <!-- Bulk action bar (bottom of viewport, appears when ≥1 selected) -->
  {#if selectionCount > 0}
    <div class="agc-bulk-bar" role="toolbar" aria-label="Bulk actions">
      <span class="agc-bulk-count">{selectionCount} selected</span>
      <button class="agc-bulk-btn" onclick={bulkPause} aria-label="Pause all selected">
        Pause all
      </button>
      <button class="agc-bulk-btn" onclick={bulkResume} aria-label="Resume all selected">
        Resume all
      </button>
      <button
        class="agc-bulk-btn agc-bulk-btn--danger"
        onclick={bulkStop}
        aria-label="Stop all selected"
      >
        Stop all
      </button>
      <button
        class="agc-bulk-close"
        onclick={clearSelection}
        aria-label="Clear selection"
      >
        <X size={13} aria-hidden="true" />
        Close
      </button>
    </div>
  {/if}
</div>

<style>
  .agc-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
    padding: var(--space-6);
    gap: var(--space-5);
    position: relative;
  }

  .agc-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-4);
    flex-wrap: wrap;
    flex-shrink: 0;
  }

  .agc-header-left {
    display: flex;
    align-items: center;
    gap: var(--space-4);
    flex-wrap: wrap;
  }

  .agc-header-right {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .agc-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: var(--tracking-2xl);
    line-height: var(--lh-2xl);
    white-space: nowrap;
  }

  .agc-view-tabs {
    display: flex;
    align-items: center;
    gap: 1px;
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    border-radius: var(--radius-md);
    padding: 2px;
  }

  .agc-view-tab {
    padding: 4px 10px;
    border: none;
    background: transparent;
    border-radius: var(--radius-sm);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    cursor: pointer;
    transition: background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
    white-space: nowrap;
  }

  .agc-view-tab:hover { color: var(--fg); }

  .agc-view-tab--active {
    background: var(--bg-elevated);
    color: var(--fg);
  }

  .agc-search {
    padding: 5px 10px;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    width: 200px;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .agc-search::placeholder { color: var(--fg-subtle); font-style: italic; }

  .agc-search:focus-visible {
    outline: none;
    border-color: var(--cnp-accent, var(--fg-muted));
  }

  .agc-icon-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    border-radius: var(--radius-md);
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-muted);
    cursor: pointer;
    transition: background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .agc-icon-btn:hover { background: color-mix(in oklch, var(--fg) 8%, transparent); color: var(--fg); }

  .agc-icon-btn:focus-visible {
    outline: 2px solid var(--cnp-accent, currentColor);
    outline-offset: 2px;
  }

  /* Page-level tab strip (Agents | Tasks) */
  .agc-page-tabs {
    display: flex;
    gap: 1px;
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    border-radius: var(--radius-md);
    padding: 2px;
  }

  .agc-page-tab {
    padding: 4px 12px;
    border: none;
    background: transparent;
    border-radius: var(--radius-sm);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-muted);
    cursor: pointer;
    transition: background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
    white-space: nowrap;
  }

  .agc-page-tab:hover { color: var(--fg); }

  .agc-page-tab--active {
    background: var(--bg-elevated);
    color: var(--fg);
  }

  .agc-page-tab:focus-visible {
    outline: 2px solid var(--cnp-accent, currentColor);
    outline-offset: 2px;
  }

  /* Stats bar */
  .agc-stats {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    flex-shrink: 0;
    flex-wrap: wrap;
  }

  .agc-stat {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  .agc-stat strong {
    color: var(--fg);
    font-weight: 600;
  }

  .agc-stat-sep {
    color: var(--fg-subtle);
    user-select: none;
  }

  /* Tasks tab panel */
  .agc-tasks-panel {
    flex: 1;
    min-height: 0;
    display: flex;
    overflow: hidden;
  }

  /* Settings collapsible */
  .agc-settings {
    flex-shrink: 0;
    border-top: 1px solid var(--border);
    padding-top: var(--space-3);
  }

  .agc-settings-toggle {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    border: none;
    background: transparent;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-muted);
    cursor: pointer;
    padding: 0;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    transition: color var(--dur-instant) var(--ease-out);
  }

  .agc-settings-toggle:hover { color: var(--fg); }

  .agc-settings-toggle:focus-visible {
    outline: 2px solid var(--cnp-accent, currentColor);
    outline-offset: 2px;
  }

  .agc-settings-body {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-3) 0;
  }

  .agc-setting-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-4);
  }

  .agc-setting-label {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
  }

  .agc-setting-select {
    padding: 4px 8px;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    min-width: 160px;
  }

  .agc-setting-number {
    padding: 4px 8px;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    width: 60px;
    text-align: center;
  }

  .agc-setting-select:focus-visible,
  .agc-setting-number:focus-visible {
    outline: none;
    border-color: var(--cnp-accent, var(--fg-muted));
  }

  .agc-loading,
  .agc-error {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    padding: var(--space-8) var(--space-4);
    text-align: center;
  }

  .agc-error { color: var(--destructive, oklch(0.65 0.22 25)); }

  /* Board: horizontal lanes, scrollable */
  .agc-board {
    display: flex;
    gap: var(--space-4);
    flex: 1;
    overflow-x: auto;
    overflow-y: hidden;
    align-items: flex-start;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
    padding-bottom: var(--space-2);
  }

  .agc-board > :global(.acl-lane) {
    min-width: 220px;
    max-width: 300px;
    height: 100%;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  /* Bulk action bar */
  .agc-bulk-bar {
    position: fixed;
    bottom: var(--space-5);
    left: 50%;
    transform: translateX(-50%);
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-4);
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    box-shadow: 0 8px 24px color-mix(in oklch, black 30%, transparent);
    z-index: 40;
    white-space: nowrap;
  }

  .agc-bulk-count {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    padding-right: var(--space-2);
    border-right: 1px solid var(--border);
  }

  .agc-bulk-btn {
    padding: 5px 12px;
    border-radius: var(--radius-md);
    border: 1px solid var(--border);
    background: transparent;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    cursor: pointer;
    transition: background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .agc-bulk-btn:hover { background: color-mix(in oklch, var(--fg) 8%, transparent); color: var(--fg); }

  .agc-bulk-btn--danger:hover {
    background: color-mix(in oklch, var(--destructive, oklch(0.65 0.22 25)) 12%, transparent);
    color: var(--destructive, oklch(0.65 0.22 25));
    border-color: color-mix(in oklch, var(--destructive, oklch(0.65 0.22 25)) 30%, var(--border));
  }

  .agc-bulk-close {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    padding: 5px 10px;
    border-radius: var(--radius-md);
    border: none;
    background: transparent;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    cursor: pointer;
    margin-left: var(--space-1);
    transition: color var(--dur-instant) var(--ease-out);
  }

  .agc-bulk-close:hover { color: var(--fg); }

  .agc-bulk-close:focus-visible,
  .agc-bulk-btn:focus-visible {
    outline: 2px solid var(--cnp-accent, currentColor);
    outline-offset: 2px;
  }
</style>
