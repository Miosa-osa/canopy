<script lang="ts">
/**
 * WorkspaceOverviewTab — Overview tab for workspace detail page.
 * Shows stat tiles + detail list.
 * CSS prefix: wot-
 */
import type { FileTreeNode, WorkspaceDetail } from '$lib/domain/workspaces/types.js';
import WorkspaceStatsTiles from './WorkspaceStatsTiles.svelte';

interface Props {
  workspace: WorkspaceDetail;
  treeData: FileTreeNode | null;
  sessionCount: number;
  onCopyPath: (path: string) => void;
}

let { workspace, treeData, sessionCount, onCopyPath }: Props = $props();

function countFiles(node: FileTreeNode): number {
  if (!node.isDir) return 1;
  return node.children.reduce((acc, child) => acc + countFiles(child), 0);
}

function totalSize(node: FileTreeNode): number {
  if (!node.isDir) return node.size;
  return node.children.reduce((acc, child) => acc + totalSize(child), 0);
}

const fileCount = $derived(treeData ? countFiles(treeData) : null);
const treeSize = $derived(treeData ? totalSize(treeData) : null);
</script>

<div class="wot-panel">
  <section class="wot-section">
    <h2 class="wot-title">Stats</h2>
    <WorkspaceStatsTiles
      sessions={sessionCount}
      files={fileCount}
      sizeBytes={treeSize}
      createdAt={workspace.insertedAt}
    />
  </section>

  <section class="wot-section">
    <h2 class="wot-title">Details</h2>
    <dl class="wot-dl">
      <div class="wot-row">
        <dt>Name</dt>
        <dd>{workspace.name}</dd>
      </div>
      <div class="wot-row">
        <dt>Slug</dt>
        <dd class="wot-mono">{workspace.slug}</dd>
      </div>
      <div class="wot-row">
        <dt>Root path</dt>
        <dd>
          <button
            class="wot-copy-btn"
            onclick={() => onCopyPath(workspace.rootPath ?? '')}
            aria-label="Copy root path"
          >{workspace.rootPath}</button>
        </dd>
      </div>
      {#if workspace.template}
        <div class="wot-row">
          <dt>Template</dt>
          <dd class="wot-mono">{workspace.template}</dd>
        </div>
      {/if}
      {#if workspace.description}
        <div class="wot-row wot-row--stack">
          <dt>Description</dt>
          <dd class="wot-desc">{workspace.description}</dd>
        </div>
      {/if}
    </dl>
  </section>
</div>

<style>
  .wot-panel {
    display: flex;
    flex-direction: column;
    gap: var(--space-6);
  }

  .wot-section {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .wot-title {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    margin: 0;
  }

  .wot-dl {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    margin: 0;
    padding: var(--space-4);
    background: var(--bg-subtle);
    border: 1px solid var(--border);
    border-radius: var(--radius);
  }

  .wot-row {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: var(--space-4);
  }

  .wot-row--stack {
    flex-direction: column;
    gap: var(--space-1);
  }

  .wot-dl dt {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    flex-shrink: 0;
  }

  .wot-dl dd {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
    text-align: right;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 320px;
  }

  .wot-desc {
    text-align: left !important;
    white-space: normal !important;
    max-width: none !important;
    line-height: 1.5;
  }

  .wot-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
  }

  .wot-copy-btn {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    background: transparent;
    border: none;
    padding: 0;
    cursor: pointer;
    text-align: right;
    transition: color 0.12s ease;
  }

  .wot-copy-btn:hover { color: var(--cnp-accent); }
</style>
