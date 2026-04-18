<script lang="ts">
/**
 * Workspace detail — /workspaces/:slug (docs/02-frontend-design.md §6.9).
 * Three-pane layout: file tree (300px) | file viewer (flex) | metadata PushPanel.
 * Top bar: breadcrumb + status + pill actions.
 */

import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
import { AlertCircle, FileText } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import { page } from '$app/state';
import { workspaceDetailQuery, workspaceTreeQuery } from '$lib/api/queries/workspaces.js';
import { Breadcrumb, BreadcrumbItem } from '$lib/design/foundation/breadcrumb/index.js';
import { toast } from '$lib/design/foundation/toast/toast.js';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import FileTree from '$lib/design/patterns/FileTree.svelte';
import FileViewer from '$lib/design/patterns/FileViewer.svelte';
import PushPanel from '$lib/design/patterns/PushPanel.svelte';
import StatusDot from '$lib/design/patterns/StatusDot.svelte';
import type { WorkspaceDetail, FileTreeNode } from '$lib/domain/workspaces/types.js';

// slug is always defined on this route — SvelteKit guarantees it
const slug = $derived(page.params.slug ?? '');

// ── Workspace detail query ────────────────────────────────────────────────────
const detailOptsStore = writable(
  untrack(() => workspaceDetailQuery(slug) as CreateQueryOptions<WorkspaceDetail>)
);
$effect(() => {
  detailOptsStore.set(workspaceDetailQuery(slug) as CreateQueryOptions<WorkspaceDetail>);
});
const detailQ = createQuery<WorkspaceDetail>(detailOptsStore);

// ── Tree query (for metadata: file count + total size) ────────────────────────
const treeOptsStore = writable(
  untrack(() => workspaceTreeQuery(slug) as CreateQueryOptions<FileTreeNode>)
);
$effect(() => {
  treeOptsStore.set(workspaceTreeQuery(slug) as CreateQueryOptions<FileTreeNode>);
});
const treeQ = createQuery<FileTreeNode>(treeOptsStore);

// ── Local state ───────────────────────────────────────────────────────────────
let selectedPath = $state<string | undefined>(undefined);
let infoPanelOpen = $state(true);

// ── Derived helpers ───────────────────────────────────────────────────────────
const workspace = $derived(($detailQ.data ?? null) as WorkspaceDetail | null);

/** Emoji derived from template slug — maps to a conceptual icon. */
const templateEmoji = $derived.by(() => {
  const t = workspace?.template ?? '';
  const map: Record<string, string> = {
    'sales-engine': '📈',
    'dev-shop': '⚙️',
    'content-factory': '✍️',
    blank: '🗂️',
  };
  return map[t] ?? '📁';
});

/** Recursively count files in tree (dirs not counted). */
function countFiles(node: FileTreeNode): number {
  if (!node.isDir) return 1;
  return node.children.reduce((acc, child) => acc + countFiles(child), 0);
}

/** Sum total size in bytes across all file nodes. */
function totalSize(node: FileTreeNode): number {
  if (!node.isDir) return node.size;
  return node.children.reduce((acc, child) => acc + totalSize(child), 0);
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

function formatDate(iso: string | null): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

const fileCount = $derived($treeQ.data ? countFiles($treeQ.data) : null);
const treeSize = $derived($treeQ.data ? totalSize($treeQ.data) : null);
</script>

<div class="ws-detail">
  {#if $detailQ.isLoading}
    <!-- Top-bar skeleton -->
    <header class="ws-detail__topbar">
      <div class="ws-sk ws-sk--breadcrumb"></div>
      <div class="ws-sk ws-sk--actions"></div>
    </header>
    <!-- Body skeleton -->
    <div class="ws-detail__body">
      <div class="ws-detail__tree ws-sk ws-sk--tree"></div>
      <div class="ws-detail__center"></div>
    </div>
  {:else if $detailQ.isError || !workspace}
    <div class="ws-detail__full-error">
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
    <header class="ws-detail__topbar">
      <div class="ws-detail__topbar-left">
        <Breadcrumb>
          <BreadcrumbItem href="/workspaces">Workspaces</BreadcrumbItem>
          <BreadcrumbItem>{workspace.name}</BreadcrumbItem>
        </Breadcrumb>

        <StatusDot
          color="grey"
          label={workspace.template ?? 'custom'}
        />

        <span class="ws-template-emoji" aria-label="Template: {workspace.template ?? 'custom'}">
          {templateEmoji}
        </span>
      </div>

      <div class="ws-detail__topbar-actions">
        <button
          class="btn-pill btn-pill-primary btn-pill-sm"
          onclick={() => goto(`/sessions?workspace=${slug}`)}
          aria-label="New session in {workspace.name}"
        >
          New session here ▸
        </button>

        <button
          class="btn-pill btn-pill-secondary btn-pill-sm"
          onclick={() => toast.info('Coming soon — Week 4')}
          aria-label="Open workspace in terminal"
        >
          Open in Terminal
        </button>

        <button
          class="btn-compact btn-compact-ghost btn-compact-sm"
          onclick={() => { infoPanelOpen = !infoPanelOpen; }}
          aria-label={infoPanelOpen ? 'Hide info panel' : 'Show info panel'}
          aria-pressed={infoPanelOpen}
        >
          {infoPanelOpen ? '→' : '←'} Info
        </button>
      </div>
    </header>

    <!-- ── Body: tree | viewer | metadata panel ── -->
    <div class="ws-detail__body">
      <!-- Left: 300px file tree -->
      <aside class="ws-detail__tree" aria-label="File tree">
        <FileTree
          workspaceSlug={slug}
          onSelect={(path) => { selectedPath = path; }}
          {selectedPath}
        />
      </aside>

      <!-- Center: file viewer or empty state -->
      <main class="ws-detail__center">
        {#if selectedPath}
          <FileViewer workspaceSlug={slug} path={selectedPath} />
        {:else}
          <EmptyState
            icon={FileText as never}
            title="Select a file to view"
            body="Choose a file from the tree on the left."
          />
        {/if}
      </main>

      <!-- Right: PushPanel — workspace metadata -->
      <PushPanel open={infoPanelOpen} title="Workspace info" onClose={() => { infoPanelOpen = false; }}>
        <dl class="ws-meta">
          <div class="ws-meta__row">
            <dt>Root path</dt>
            <dd class="ws-meta__mono" title={workspace.rootPath}>{workspace.rootPath}</dd>
          </div>

          <div class="ws-meta__row">
            <dt>Template</dt>
            <dd>{workspace.template ?? '—'}</dd>
          </div>

          <div class="ws-meta__row">
            <dt>Created</dt>
            <dd>{formatDate(workspace.insertedAt)}</dd>
          </div>

          <div class="ws-meta__row">
            <dt>Updated</dt>
            <dd>{formatDate(workspace.updatedAt)}</dd>
          </div>

          {#if fileCount !== null}
            <div class="ws-meta__row">
              <dt>Files</dt>
              <dd>{fileCount.toLocaleString()}</dd>
            </div>
          {/if}

          {#if treeSize !== null}
            <div class="ws-meta__row">
              <dt>Total size</dt>
              <dd>{formatBytes(treeSize)}</dd>
            </div>
          {/if}

          {#if workspace.description}
            <div class="ws-meta__row ws-meta__row--stack">
              <dt>Description</dt>
              <dd class="ws-meta__desc">{workspace.description}</dd>
            </div>
          {/if}
        </dl>
      </PushPanel>
    </div>
  {/if}
</div>

<style>
  .ws-detail {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  /* ── Top bar ── */
  .ws-detail__topbar {
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

  .ws-detail__topbar-left {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    min-width: 0;
  }

  .ws-detail__topbar-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
  }

  .ws-template-emoji {
    font-size: var(--text-base);
    line-height: 1;
    user-select: none;
  }

  /* ── Body: three panes ── */
  .ws-detail__body {
    display: flex;
    flex: 1;
    overflow: hidden;
    gap: 0;
  }

  .ws-detail__tree {
    width: 300px;
    flex-shrink: 0;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .ws-detail__center {
    flex: 1;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    min-width: 0;
    background: var(--bg);
  }

  /* Full-page error state */
  .ws-detail__full-error {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  /* ── Workspace metadata (in PushPanel) ── */
  .ws-meta {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    margin: 0;
    padding: 0;
  }

  .ws-meta__row {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: var(--space-3);
  }

  .ws-meta__row--stack {
    flex-direction: column;
    gap: var(--space-1);
  }

  .ws-meta dt {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    flex-shrink: 0;
  }

  .ws-meta dd {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
    text-align: right;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 200px;
  }

  .ws-meta__mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    max-width: 180px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    direction: rtl;
    text-align: left;
  }

  .ws-meta__desc {
    text-align: left;
    white-space: normal;
    max-width: none;
    line-height: 1.5;
  }

  /* ── Loading skeletons ── */
  .ws-sk {
    background: var(--border);
    border-radius: var(--radius-sm);
    animation: ws-pulse 1.5s var(--ease-io) infinite;
  }

  .ws-sk--breadcrumb { height: 18px; width: 220px; }
  .ws-sk--actions { height: 28px; width: 280px; border-radius: 9999px; }
  .ws-sk--tree { animation: ws-pulse 1.5s var(--ease-io) infinite; }

  @keyframes ws-pulse {
    0%, 100% { opacity: 0.3; }
    50% { opacity: 0.6; }
  }
</style>
