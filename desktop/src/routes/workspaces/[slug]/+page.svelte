<script lang="ts">
/**
 * Workspace detail — /workspaces/:slug
 * Tabs: Overview | Setup | Sessions | Files | Danger
 * CSS prefix: wd-
 */

import {
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { AlertCircle, FolderOpen } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import { page } from '$app/state';
import { sessionsQuery } from '$lib/api/queries/sessions.js';
import {
  deleteWorkspaceMutation,
  startInitJob,
  workspaceDetailQuery,
  workspaceInitJobQuery,
  workspaceTreeQuery,
} from '$lib/api/queries/workspaces.js';
import { Breadcrumb, BreadcrumbItem } from '$lib/design/foundation/breadcrumb/index.js';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import FileTree from '$lib/design/patterns/FileTree.svelte';
import FileViewer from '$lib/design/patterns/FileViewer.svelte';
import StatusDot from '$lib/design/patterns/StatusDot.svelte';
import InitProgressCard from '$lib/design/patterns/workspaces/InitProgressCard.svelte';
import PinnedPanel from '$lib/design/patterns/workspaces/PinnedPanel.svelte';
import SetupScriptCard from '$lib/design/patterns/workspaces/SetupScriptCard.svelte';
import WorkspaceDangerTab from '$lib/design/patterns/workspaces/WorkspaceDangerTab.svelte';
import WorkspaceEngineTab from '$lib/design/patterns/workspaces/WorkspaceEngineTab.svelte';
import WorkspaceOverviewTab from '$lib/design/patterns/workspaces/WorkspaceOverviewTab.svelte';
import WorkspaceSessionsTab from '$lib/design/patterns/workspaces/WorkspaceSessionsTab.svelte';
import type { Session } from '$lib/domain/sessions/types.js';
import type { FileTreeNode, InitJob, WorkspaceDetail } from '$lib/domain/workspaces/types.js';
import { toasts } from '$lib/stores/toasts.svelte.js';

const slug = $derived(page.params.slug ?? '');

// ── Tab state ─────────────────────────────────────────────────────────────────
type Tab = 'overview' | 'setup' | 'engine' | 'sessions' | 'files' | 'danger';
let activeTab = $state<Tab>('overview');

// ── Workspace detail query ────────────────────────────────────────────────────
const detailOptsStore = writable(
  untrack(() => workspaceDetailQuery(slug) as CreateQueryOptions<WorkspaceDetail>)
);
$effect(() => {
  detailOptsStore.set(workspaceDetailQuery(slug) as CreateQueryOptions<WorkspaceDetail>);
});
const detailQ = createQuery<WorkspaceDetail>(detailOptsStore);

// ── Tree query ────────────────────────────────────────────────────────────────
const treeOptsStore = writable(
  untrack(() => workspaceTreeQuery(slug) as CreateQueryOptions<FileTreeNode>)
);
$effect(() => {
  treeOptsStore.set(workspaceTreeQuery(slug) as CreateQueryOptions<FileTreeNode>);
});
const treeQ = createQuery<FileTreeNode>(treeOptsStore);

// ── Sessions query ────────────────────────────────────────────────────────────
const sessionsOptsStore = writable(untrack(() => sessionsQuery({ workspaceSlug: slug })));
$effect(() => {
  sessionsOptsStore.set(sessionsQuery({ workspaceSlug: slug }));
});
const sessionsQ = createQuery<Session[]>(sessionsOptsStore);

// ── Delete mutation ────────────────────────────────────────────────────────────
const queryClient = useQueryClient();
const deleteMut = createMutation(deleteWorkspaceMutation());

// ── Derived ───────────────────────────────────────────────────────────────────
const workspace = $derived(($detailQ.data ?? null) as WorkspaceDetail | null);
const sessions = $derived(($sessionsQ.data ?? []) as unknown as Record<string, unknown>[]);

// ── Init job tracking ─────────────────────────────────────────────────────────
// startInitJob (called by TemplatePicker) stores the job_id in sessionStorage.
// This page reads it, creates a polling query, and clears on terminal state.

let activeJobId = $state<string | null>(null);
const initJobKey = $derived(`canopy.ws.${slug}.init_job_id`);

$effect(() => {
  if (typeof window !== 'undefined') {
    const stored = sessionStorage.getItem(initJobKey);
    if (stored) activeJobId = stored;
  }
});

const initJobOptsStore = writable(
  untrack(() => workspaceInitJobQuery(slug, activeJobId ?? '') as CreateQueryOptions<InitJob>)
);

$effect(() => {
  if (activeJobId) {
    initJobOptsStore.set(workspaceInitJobQuery(slug, activeJobId) as CreateQueryOptions<InitJob>);
  }
});

const initJobQ = createQuery<InitJob>(initJobOptsStore);

const activeInitJob = $derived(activeJobId ? (($initJobQ.data ?? null) as InitJob | null) : null);
const showInitCard = $derived(
  activeInitJob !== null &&
    (activeInitJob.status === 'running' ||
      activeInitJob.status === 'pending' ||
      activeInitJob.status === 'failed')
);

function clearInitJob(): void {
  if (typeof window !== 'undefined') sessionStorage.removeItem(initJobKey);
  activeJobId = null;
  queryClient.invalidateQueries({ queryKey: ['workspaces', slug] });
}

async function handleRetryInit(): Promise<void> {
  try {
    const resp = await startInitJob(slug);
    if (typeof window !== 'undefined') sessionStorage.setItem(initJobKey, resp.jobId);
    activeJobId = resp.jobId;
  } catch {
    toasts.error('Failed to start init');
  }
}

// ── Local state ───────────────────────────────────────────────────────────────
let selectedPath = $state<string | undefined>(undefined);

// ── Actions ───────────────────────────────────────────────────────────────────
function handleDeleteConfirm(): void {
  $deleteMut.mutate(slug, {
    onSuccess: () => {
      toasts.success('Workspace deleted');
      goto('/workspaces');
    },
    onError: () => {
      toasts.error('Failed to delete workspace');
    },
  });
}

function handleRenamed(): void {
  queryClient.invalidateQueries({ queryKey: ['workspaces'] });
}

function handleDeleted(): void {
  goto('/workspaces');
}

function copyToClipboard(path: string): void {
  navigator.clipboard
    .writeText(path)
    .then(() => {
      toasts.info('Copied to clipboard');
    })
    .catch(() => {
      toasts.error('Copy failed');
    });
}
</script>

<div class="wd-page">
  {#if $detailQ.isLoading}
    <header class="wd-topbar">
      <div class="wd-sk wd-sk--breadcrumb"></div>
    </header>
  {:else if $detailQ.isError || !workspace}
    <div class="wd-full-error">
      <EmptyState
        icon={AlertCircle as never}
        title="Workspace not found"
        body="This workspace doesn't exist or couldn't be loaded."
        action="Back to workspaces"
        onAction={() => goto('/workspaces')}
      />
    </div>
  {:else}
    <!-- ── Top bar ── -->
    <header class="wd-topbar">
      <div class="wd-topbar-left">
        <Breadcrumb>
          <BreadcrumbItem href="/workspaces">Workspaces</BreadcrumbItem>
          <BreadcrumbItem>{workspace.name}</BreadcrumbItem>
        </Breadcrumb>
        <StatusDot color="grey" label={workspace.template ?? 'custom'} />
        <button
          class="wd-path-badge"
          onclick={() => copyToClipboard(workspace.rootPath ?? '')}
          title="Click to copy path"
          aria-label="Copy root path"
        >{workspace.rootPath}</button>
      </div>
      <div class="wd-topbar-actions">
        <button
          class="btn-pill btn-pill-primary btn-pill-sm"
          onclick={() => goto(`/sessions?workspace=${slug}`)}
          aria-label="New session in {workspace.name}"
        >New session</button>
      </div>
    </header>

    <!-- ── Tab bar ── -->
    <div class="wd-tabs" role="tablist" aria-label="Workspace sections">
      {#each ([['overview','Overview'],['setup','Setup'],['engine','Engine'],['sessions','Sessions'],['files','Files'],['danger','Danger']] as const) as [id, label] (id)}
        <button
          class="wd-tab"
          class:wd-tab--active={activeTab === id}
          role="tab"
          aria-selected={activeTab === id}
          aria-controls="wd-panel-{id}"
          onclick={() => { activeTab = id; }}
        >{label}</button>
      {/each}
    </div>

    <!-- ── Init progress card ── -->
    {#if showInitCard && activeInitJob}
      <div class="wd-init-banner">
        <InitProgressCard
          {slug}
          jobId={activeInitJob.id}
          initialJob={activeInitJob}
          onDone={() => { toasts.success('Workspace initialized'); clearInitJob(); }}
          onCancelled={() => { toasts.info('Init cancelled'); clearInitJob(); }}
          onError={(err) => {
            if (err) toasts.error(err);
          }}
        />
      </div>
    {/if}

    <!-- ── Main content with optional pinned sidebar ── -->
    <div class="wd-layout">
      <div class="wd-pinned-sidebar" aria-label="Pinned items sidebar">
        <PinnedPanel workspaceSlug={slug} />
      </div>

    <!-- ── Tab content ── -->
    <div class="wd-body">
      {#if activeTab === 'overview'}
        <div id="wd-panel-overview" class="wd-panel" role="tabpanel">
          <WorkspaceOverviewTab
            {workspace}
            treeData={$treeQ.data ?? null}
            sessionCount={sessions.length}
            onCopyPath={copyToClipboard}
          />
        </div>

      {:else if activeTab === 'setup'}
        <div id="wd-panel-setup" class="wd-panel" role="tabpanel">
          <SetupScriptCard workspaceSlug={slug} />
        </div>

      {:else if activeTab === 'engine'}
        <div id="wd-panel-engine" class="wd-panel" role="tabpanel">
          <WorkspaceEngineTab workspaceSlug={slug} />
        </div>

      {:else if activeTab === 'sessions'}
        <div id="wd-panel-sessions" class="wd-panel" role="tabpanel">
          <WorkspaceSessionsTab
            workspaceSlug={slug}
            {sessions}
            isLoading={$sessionsQ.isLoading}
          />
        </div>

      {:else if activeTab === 'files'}
        <div id="wd-panel-files" class="wd-panel wd-panel--files" role="tabpanel">
          <aside class="wd-file-tree" aria-label="File tree">
            <FileTree
              workspaceSlug={slug}
              onSelect={(path) => { selectedPath = path; }}
              {selectedPath}
            />
          </aside>
          <main class="wd-file-viewer">
            {#if selectedPath}
              <FileViewer workspaceSlug={slug} path={selectedPath} />
            {:else}
              <EmptyState
                icon={FolderOpen as never}
                title="Select a file"
                body="Choose a file from the tree on the left."
              />
            {/if}
          </main>
        </div>

      {:else if activeTab === 'danger'}
        <div id="wd-panel-danger" class="wd-panel" role="tabpanel">
          <WorkspaceDangerTab
            {workspace}
            onDeleted={handleDeleted}
            onRenamed={handleRenamed}
            isDeleting={$deleteMut.isPending}
            onDeleteRequest={handleDeleteConfirm}
          />
        </div>
      {/if}
    </div>
    </div><!-- end wd-layout -->
  {/if}
</div>

<style>
  .wd-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  .wd-topbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-3) var(--space-5);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    gap: var(--space-4);
    flex-wrap: wrap;
    min-height: 52px;
  }

  .wd-topbar-left {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    min-width: 0;
  }

  .wd-topbar-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
  }

  .wd-path-badge {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    background: transparent;
    border: none;
    padding: 2px var(--space-1);
    cursor: pointer;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 280px;
    border-radius: var(--radius-sm);
    transition: background 0.12s ease, color 0.12s ease;
  }

  .wd-path-badge:hover {
    background: var(--bg-subtle);
    color: var(--fg-muted);
  }

  .wd-tabs {
    display: flex;
    align-items: center;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    padding: 0 var(--space-5);
    overflow-x: auto;
    scrollbar-width: none;
  }

  .wd-tabs::-webkit-scrollbar { display: none; }

  .wd-tab {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg-subtle);
    background: transparent;
    border: none;
    border-bottom: 2px solid transparent;
    padding: var(--space-3);
    cursor: pointer;
    transition: color 0.15s ease, border-color 0.15s ease;
    white-space: nowrap;
    flex-shrink: 0;
    margin-bottom: -1px;
  }

  .wd-tab:hover { color: var(--fg-muted); }

  .wd-tab--active {
    color: var(--fg);
    border-bottom-color: var(--cnp-accent);
  }

  .wd-layout {
    flex: 1;
    overflow: hidden;
    display: flex;
    flex-direction: row;
    gap: 0;
  }

  .wd-pinned-sidebar {
    width: 200px;
    flex-shrink: 0;
    border-right: 1px solid var(--border);
    overflow-y: auto;
    padding: var(--space-3);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .wd-body {
    flex: 1;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .wd-panel {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-5) var(--space-6);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .wd-panel--files {
    display: flex;
    flex-direction: row;
    padding: 0;
    overflow: hidden;
  }

  .wd-file-tree {
    width: 280px;
    flex-shrink: 0;
    overflow: hidden;
    border-right: 1px solid var(--border);
  }

  .wd-file-viewer {
    flex: 1;
    overflow-y: auto;
    min-width: 0;
    background: var(--bg);
  }

  .wd-full-error {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .wd-sk {
    background: var(--border);
    border-radius: var(--radius-sm);
    animation: wd-pulse 1.5s ease-in-out infinite;
  }

  .wd-init-banner {
    padding: var(--space-3) var(--space-5) 0;
    flex-shrink: 0;
  }

  .wd-sk--breadcrumb { height: 18px; width: 200px; }

  @keyframes wd-pulse {
    0%, 100% { opacity: 0.3; }
    50% { opacity: 0.65; }
  }
</style>
