<script lang="ts">
/**
 * FileTree — recursive workspace file tree with keyboard navigation.
 * Fetches via workspaceTreeQuery. Delegates node rendering to FileTreeNode.
 * LOC target: ≤ 250. CSS prefix: ft-.
 *
 * Keyboard:
 *   ↑/↓   move focus through visible nodes
 *   →     expand focused dir
 *   ←     collapse focused dir
 *   Enter  select focused file (noop on dirs)
 */

import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
import { FolderOpen } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { workspaceTreeQuery } from '$lib/api/queries/workspaces.js';
import type { FileTreeNode } from '$lib/domain/workspaces/types.js';
import FileTreeNodeComponent from './FileTreeNode.svelte';

interface Props {
  workspaceSlug: string;
  onSelect: (path: string) => void;
  selectedPath?: string | undefined;
}

let { workspaceSlug, onSelect, selectedPath = undefined }: Props = $props();

// ── TanStack Query (canonical writable + untrack + $effect bridge) ────────────
const optsStore = writable(
  untrack(() => workspaceTreeQuery(workspaceSlug) as CreateQueryOptions<FileTreeNode>)
);
$effect(() => {
  optsStore.set(workspaceTreeQuery(workspaceSlug) as CreateQueryOptions<FileTreeNode>);
});
const treeQ = createQuery<FileTreeNode>(optsStore);

// ── Local state ───────────────────────────────────────────────────────────────
let expandedPaths = $state(new Set<string>());
let focusedPath = $state<string | undefined>(undefined);

function toggleDir(path: string): void {
  const next = new Set(expandedPaths);
  if (next.has(path)) {
    next.delete(path);
  } else {
    next.add(path);
  }
  expandedPaths = next;
}

// ── Visible-node flat list for keyboard navigation ────────────────────────────
function collectVisible(node: FileTreeNode): FileTreeNode[] {
  const result: FileTreeNode[] = [node];
  if (node.isDir && expandedPaths.has(node.path)) {
    for (const child of node.children) {
      result.push(...collectVisible(child));
    }
  }
  return result;
}

// Derived flat array of all visible nodes (excludes root container itself)
const visibleNodes = $derived(
  $treeQ.data
    ? $treeQ.data.children.flatMap((child) => collectVisible(child))
    : []
);

// ── Keyboard handler ──────────────────────────────────────────────────────────
function handleKeyDown(e: KeyboardEvent): void {
  const nodes = visibleNodes;
  if (nodes.length === 0) return;

  const currentIdx = focusedPath != null ? nodes.findIndex((n) => n.path === focusedPath) : -1;

  if (e.key === 'ArrowDown') {
    e.preventDefault();
    const nextIdx = currentIdx < nodes.length - 1 ? currentIdx + 1 : 0;
    focusedPath = nodes[nextIdx]?.path;
  } else if (e.key === 'ArrowUp') {
    e.preventDefault();
    const prevIdx = currentIdx > 0 ? currentIdx - 1 : nodes.length - 1;
    focusedPath = nodes[prevIdx]?.path;
  } else if (e.key === 'ArrowRight') {
    e.preventDefault();
    if (focusedPath != null) {
      const node = nodes.find((n) => n.path === focusedPath);
      if (node?.isDir && !expandedPaths.has(node.path)) {
        toggleDir(node.path);
      }
    }
  } else if (e.key === 'ArrowLeft') {
    e.preventDefault();
    if (focusedPath != null) {
      const node = nodes.find((n) => n.path === focusedPath);
      if (node?.isDir && expandedPaths.has(node.path)) {
        toggleDir(node.path);
      }
    }
  } else if (e.key === 'Enter') {
    e.preventDefault();
    if (focusedPath != null) {
      const node = nodes.find((n) => n.path === focusedPath);
      if (node && !node.isDir) {
        onSelect(node.path);
      }
    }
  }
}

// ── Root helpers ──────────────────────────────────────────────────────────────
const rootNode = $derived($treeQ.data ?? null);
</script>

<div
  class="ft-root"
  role="tree"
  aria-label="Workspace files"
  tabindex="0"
  onkeydown={handleKeyDown}
>
  {#if $treeQ.isLoading}
    <!-- Loading skeleton -->
    <div class="ft-skeleton" aria-label="Loading file tree" aria-live="polite">
      {#each { length: 6 } as _, i (i)}
        <div class="ft-sk" style="width: {60 + (i % 3) * 15}%; margin-left: {(i % 2) * 12}px;"></div>
      {/each}
    </div>
  {:else if $treeQ.isError || !rootNode}
    <div class="ft-error" role="alert">
      <!-- svelte-ignore svelte_component_deprecated -->
      <svelte:component this={FolderOpen as unknown as typeof import('svelte').SvelteComponent} size={24} aria-hidden="true" />
      <span>Could not load files</span>
    </div>
  {:else if rootNode.children.length === 0}
    <div class="ft-empty" role="status">
      <!-- svelte-ignore svelte_component_deprecated -->
      <svelte:component this={FolderOpen as unknown as typeof import('svelte').SvelteComponent} size={24} aria-hidden="true" />
      <span>Empty workspace</span>
    </div>
  {:else}
    <ul class="ft-list" role="group">
      {#each rootNode.children as child (child.path)}
        <FileTreeNodeComponent
          node={child}
          depth={0}
          {selectedPath}
          {focusedPath}
          onSelect={(path) => {
            focusedPath = path;
            onSelect(path);
          }}
          onToggle={toggleDir}
          {expandedPaths}
        />
      {/each}
    </ul>
  {/if}
</div>

<style>
  .ft-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow-y: auto;
    outline: none;
    background: var(--bg-inset);
    border-right: 1px solid var(--border);
  }

  .ft-root:focus-visible {
    outline: none;
    box-shadow: inset 2px 0 0 var(--accent);
  }

  .ft-list {
    list-style: none;
    margin: 0;
    padding: var(--space-2) 0;
  }

  /* Loading skeleton */
  .ft-skeleton {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-3);
  }

  .ft-sk {
    height: 14px;
    background: var(--border);
    border-radius: var(--radius-sm);
    animation: ft-pulse 1.5s var(--ease-io) infinite;
  }

  @keyframes ft-pulse {
    0%, 100% { opacity: 0.3; }
    50% { opacity: 0.6; }
  }

  /* Error + empty */
  .ft-error,
  .ft-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--space-2);
    height: 100%;
    color: var(--fg-subtle);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    padding: var(--space-6);
    text-align: center;
  }

  .ft-error {
    color: var(--signal-error);
  }
</style>
