<script lang="ts">
/**
 * /runtimes/[type] — Runtime Terminal View.
 *
 * Layout: collapsible header | fill terminal | collapsible right sidebar.
 *
 * Mount behavior:
 *   1. GET /sessions?runtime=<type>&status=running → attach to most recent if found.
 *   2. If none → GET /workspaces → POST /sessions with first workspace.
 *   3. If runtime not authenticated → show overlay, block session spawn.
 *
 * Keyboard shortcuts:
 *   Cmd/Ctrl+K         → focus terminal
 *   Cmd/Ctrl+Shift+N   → open new-session modal
 *   Esc                → blur terminal
 *
 * CSS prefix: rtv-
 */

import { type CreateQueryOptions, createQuery, useQueryClient } from '@tanstack/svelte-query';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { page } from '$app/state';
import { apiDelete, apiPost } from '$lib/api/client.js';
import { runtimeDetailQuery } from '$lib/api/queries/runtimes.js';
import { listSessions } from '$lib/api/queries/sessions.js';
import { listWorkspaces } from '$lib/api/queries/workspaces.js';
import ChangesPanel from '$lib/design/patterns/diff/ChangesPanel.svelte';
import NewSessionModal from '$lib/design/patterns/NewSessionModal.svelte';
import RuntimeInfoPanel from '$lib/design/patterns/runtime-view/RuntimeInfoPanel.svelte';
import RuntimeSessionList from '$lib/design/patterns/runtime-view/RuntimeSessionList.svelte';
import RuntimeTerminalHeader from '$lib/design/patterns/runtime-view/RuntimeTerminalHeader.svelte';
import RuntimeTerminalPane from '$lib/design/patterns/runtime-view/RuntimeTerminalPane.svelte';
import ResizablePanel from '$lib/design/primitives/ResizablePanel.svelte';
import type { RuntimeDetail } from '$lib/domain/runtimes/types.js';
import type { CreateSessionBody, Session } from '$lib/domain/sessions/types.js';
import { activeWorkspace } from '$lib/stores/active-workspace.svelte.js';

const queryClient = useQueryClient();
const runtimeType = $derived(page.params.type ?? '');

// ── Runtime detail query ──────────────────────────────────────────────────────

const detailOptsStore = writable(
  untrack(() => runtimeDetailQuery(runtimeType) as CreateQueryOptions<RuntimeDetail>)
);
$effect(() => {
  detailOptsStore.set(runtimeDetailQuery(runtimeType) as CreateQueryOptions<RuntimeDetail>);
});
const detailQuery = createQuery<RuntimeDetail>(detailOptsStore);

// ── Sessions for this runtime (sidebar list) ──────────────────────────────────

const sessionsOptsStore = writable(
  untrack(
    () =>
      ({
        queryKey: ['sessions', { runtimeType }] as const,
        queryFn: () => listSessions({ runtimeType }),
        staleTime: 10_000,
        enabled: Boolean(runtimeType),
      }) as CreateQueryOptions<Session[]>
  )
);
$effect(() => {
  sessionsOptsStore.set({
    queryKey: ['sessions', { runtimeType }] as const,
    queryFn: () => listSessions({ runtimeType }),
    staleTime: 10_000,
    enabled: Boolean(runtimeType),
  } as CreateQueryOptions<Session[]>);
});
const sessionsQuery = createQuery<Session[]>(sessionsOptsStore);

// ── UI state ──────────────────────────────────────────────────────────────────

let sessionId = $state<string | null>(null);
let spawnError = $state<string | null>(null);
let isSpawning = $state(false);
let isDetaching = $state(false);
let showNewSession = $state(false);
let sidebarTab = $state<'sessions' | 'info' | 'logs' | 'changes'>('sessions');

// Sidebar collapse — persisted in localStorage
const SIDEBAR_KEY = 'canopy.runtime_detail.sidebar_collapsed';
let sidebarCollapsed = $state(
  typeof localStorage !== 'undefined' ? localStorage.getItem(SIDEBAR_KEY) === 'true' : false
);
function toggleSidebar(): void {
  sidebarCollapsed = !sidebarCollapsed;
  if (typeof localStorage !== 'undefined') {
    localStorage.setItem(SIDEBAR_KEY, String(sidebarCollapsed));
  }
}

// Header collapse
let headerCollapsed = $state(false);

// ── Derived auth check ────────────────────────────────────────────────────────

const isAuthenticated = $derived(
  $detailQuery.data?.status === 'installed' || $detailQuery.data?.status === 'misconfigured'
);

// ── Session auto-attach / spawn ───────────────────────────────────────────────

async function autoAttachOrSpawn(runtime: RuntimeDetail): Promise<void> {
  if (!isAuthenticated) return;

  isSpawning = true;
  spawnError = null;

  try {
    const running = await listSessions({ runtimeType: runtime.type, status: 'running' });
    if (running.length > 0) {
      const sorted = [...running].sort(
        (a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime()
      );
      sessionId = sorted[0].id;
      return;
    }

    // Prefer the active workspace; fall back to the first workspace from
    // the API only when no active workspace is set yet (cold boot before
    // the WorkspaceSwitcher has hydrated).
    let workspaceSlug = activeWorkspace.slug ?? undefined;
    let cwd = activeWorkspace.rootPath ?? '~';
    if (!workspaceSlug) {
      const workspaces = await listWorkspaces();
      workspaceSlug = workspaces[0]?.slug ?? undefined;
      cwd = workspaces[0]?.rootPath ?? '~';
    }

    const body: CreateSessionBody = {
      runtimeType: runtime.type,
      cwd,
      workspaceSlug,
      prompt: undefined,
    };
    const created = (await apiPost<Session>('/sessions', body)) as unknown as {
      id?: string;
      sessionId?: string;
    };
    sessionId = created.sessionId ?? created.id ?? null;

    await queryClient.invalidateQueries({ queryKey: ['sessions'] });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    spawnError = msg;
  } finally {
    isSpawning = false;
  }
}

let autoAttachTriggered = $state(false);
$effect(() => {
  const runtime = $detailQuery.data;
  if (runtime && !autoAttachTriggered) {
    autoAttachTriggered = true;
    void autoAttachOrSpawn(runtime);
  }
});

// ── Session switcher ──────────────────────────────────────────────────────────

function switchSession(id: string): void {
  sessionId = id;
}

// ── Detach / end session ──────────────────────────────────────────────────────

async function handleDetach(): Promise<void> {
  if (!sessionId) return;
  isDetaching = true;
  try {
    await apiDelete(`/sessions/${sessionId}`);
    sessionId = null;
    await queryClient.invalidateQueries({ queryKey: ['sessions'] });
  } catch {
    sessionId = null;
  } finally {
    isDetaching = false;
  }
}

// ── Keyboard shortcuts ────────────────────────────────────────────────────────

let terminalContainerEl = $state<HTMLDivElement | undefined>();

function handleKeydown(e: KeyboardEvent): void {
  const mod = e.metaKey || e.ctrlKey;

  if (mod && e.key === 'k' && !e.shiftKey) {
    e.preventDefault();
    terminalContainerEl?.focus();
    return;
  }

  if (mod && e.shiftKey && e.key === 'N') {
    e.preventDefault();
    showNewSession = true;
    return;
  }

  if (e.key === 'Escape' && document.activeElement === terminalContainerEl) {
    e.preventDefault();
    terminalContainerEl?.blur();
  }
}

const runtimeSessions = $derived(($sessionsQuery.data ?? []) as Session[]);
</script>

<svelte:window onkeydown={handleKeydown} />

<div class="rtv-root">
  <!-- Header -->
  {#if $detailQuery.data}
    <RuntimeTerminalHeader
      runtime={$detailQuery.data}
      collapsed={headerCollapsed}
      onToggleCollapse={() => { headerCollapsed = !headerCollapsed; }}
      onDetach={handleDetach}
      {isDetaching}
    />
  {:else if $detailQuery.isLoading}
    <div class="rtv-header-skeleton" aria-hidden="true"></div>
  {/if}

  <!-- Main area -->
  <div class="rtv-body">
    {#if sidebarCollapsed}
      <!-- Collapsed: just the terminal pane + toggle -->
      <div class="rtv-terminal-pane" bind:this={terminalContainerEl} tabindex="-1">
        <RuntimeTerminalPane
          {runtimeType}
          runtimeName={$detailQuery.data?.name ?? ''}
          {isAuthenticated}
          {isSpawning}
          isLoading={$detailQuery.isLoading}
          {sessionId}
          {spawnError}
          onRetry={() => {
            autoAttachTriggered = false;
            spawnError = null;
            if ($detailQuery.data) void autoAttachOrSpawn($detailQuery.data);
          }}
        />
      </div>
      <button
        class="rtv-sidebar-toggle"
        onclick={toggleSidebar}
        aria-label="Expand sidebar"
        title="Expand sidebar"
      >
        <span class="rtv-toggle-icon" aria-hidden="true">‹</span>
      </button>
    {:else}
      <!-- Expanded: ResizablePanel with collapse button in sidebar header -->
      <ResizablePanel persistKey="runtime.detail.sidebar" defaultSize={280} minSize={200} maxSize={520}>
        {#snippet left()}
          <div class="rtv-terminal-pane" bind:this={terminalContainerEl} tabindex="-1">
            <RuntimeTerminalPane
              {runtimeType}
              runtimeName={$detailQuery.data?.name ?? ''}
              {isAuthenticated}
              {isSpawning}
              isLoading={$detailQuery.isLoading}
              {sessionId}
              {spawnError}
              onRetry={() => {
                autoAttachTriggered = false;
                spawnError = null;
                if ($detailQuery.data) void autoAttachOrSpawn($detailQuery.data);
              }}
            />
          </div>
        {/snippet}

        {#snippet right()}
          <aside class="rtv-sidebar" aria-label="Runtime sidebar">
            <!-- Tab bar + collapse button -->
            <div class="rtv-sidebar-tabs" role="tablist" aria-label="Sidebar tabs">
              {#each (['sessions', 'info', 'logs', 'changes'] as const) as tab (tab)}
                <button
                  class="rtv-tab"
                  class:rtv-tab--active={sidebarTab === tab}
                  role="tab"
                  aria-selected={sidebarTab === tab}
                  onclick={() => { sidebarTab = tab; }}
                  aria-label="{tab} tab"
                >
                  {tab.charAt(0).toUpperCase() + tab.slice(1)}
                </button>
              {/each}
              <button
                class="rtv-sidebar-collapse"
                onclick={toggleSidebar}
                aria-label="Collapse sidebar"
                title="Collapse sidebar"
              >›</button>
            </div>

            <!-- Tab content -->
            <div class="rtv-sidebar-content" role="tabpanel">
              {#if sidebarTab === 'sessions'}
                <RuntimeSessionList
                  sessions={runtimeSessions}
                  activeSessionId={sessionId ?? ''}
                  isLoading={$sessionsQuery.isLoading}
                  onSelect={switchSession}
                  onNewSession={() => { showNewSession = true; }}
                />
              {:else if sidebarTab === 'info'}
                {#if $detailQuery.data}
                  <RuntimeInfoPanel runtime={$detailQuery.data} />
                {:else}
                  <div class="rtv-sidebar-loading">Loading…</div>
                {/if}
              {:else if sidebarTab === 'changes'}
                {#if sessionId}
                  <ChangesPanel {sessionId} />
                {:else}
                  <div class="rtv-sidebar-loading">No active session.</div>
                {/if}
              {:else}
                <div class="rtv-sidebar-deferred">Log buffer — coming soon.</div>
              {/if}
            </div>
          </aside>
        {/snippet}
      </ResizablePanel>
    {/if}
  </div>
</div>

<!-- New Session Modal -->
<NewSessionModal open={showNewSession} onClose={() => { showNewSession = false; }} />

<style>
  .rtv-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
    background: var(--bg);
  }

  /* Header skeleton */
  .rtv-header-skeleton {
    height: 52px;
    flex-shrink: 0;
    border-bottom: 1px solid var(--border);
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    animation: rtv-pulse 1.4s ease-in-out infinite;
  }

  @keyframes rtv-pulse {
    0%, 100% { opacity: 0.4; }
    50%       { opacity: 0.8; }
  }

  /* Body: terminal + sidebar */
  .rtv-body {
    display: flex;
    flex: 1;
    min-height: 0;
    position: relative;
  }

  .rtv-terminal-pane {
    flex: 1;
    min-width: 0;
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    position: relative;
    outline: none;
  }

  /* Collapse toggle — shown only when sidebar is fully collapsed */
  .rtv-sidebar-toggle {
    position: absolute;
    right: 0;
    top: 50%;
    transform: translateY(-50%);
    z-index: 3;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 16px;
    height: 36px;
    border-radius: 6px 0 0 6px;
    border: 1px solid var(--border);
    border-right: none;
    background: var(--bg-elevated);
    color: var(--fg-subtle);
    cursor: pointer;
    transition: color 0.1s ease, background 0.1s ease;
    padding: 0;
  }

  .rtv-sidebar-toggle:hover {
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
  }

  .rtv-sidebar-toggle:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  .rtv-toggle-icon {
    font-size: 14px;
    line-height: 1;
    user-select: none;
  }

  /* Right sidebar — width now controlled by ResizablePanel */
  .rtv-sidebar {
    width: 100%;
    height: 100%;
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    border-left: 1px solid var(--border);
    background: var(--bg-elevated);
    overflow: hidden;
  }

  /* Collapse button inside sidebar tab bar */
  .rtv-sidebar-collapse {
    margin-left: auto;
    padding: 0 var(--space-2);
    background: transparent;
    border: none;
    color: var(--fg-subtle);
    cursor: pointer;
    font-size: 14px;
    line-height: 1;
    transition: color 0.1s ease;
  }

  .rtv-sidebar-collapse:hover { color: var(--fg); }

  .rtv-sidebar-collapse:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: -2px;
  }

  .rtv-sidebar-tabs {
    display: flex;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .rtv-tab {
    flex: 1;
    padding: var(--space-2) 0;
    border: none;
    background: transparent;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-subtle);
    cursor: pointer;
    border-bottom: 2px solid transparent;
    transition: color 0.1s ease, border-color 0.1s ease;
  }

  .rtv-tab:hover:not(.rtv-tab--active) {
    color: var(--fg-muted);
  }

  .rtv-tab--active {
    color: var(--fg);
    border-bottom-color: var(--cnp-accent);
  }

  .rtv-tab:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: -2px;
  }

  .rtv-sidebar-content {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .rtv-sidebar-loading,
  .rtv-sidebar-deferred {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    font-style: italic;
    padding: var(--space-6);
    text-align: center;
  }
</style>
