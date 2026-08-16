<script lang="ts">
  /**
   * FileTreeNode — recursive lazy-loading tree node for the Build rail's
   * Project Explorer section. CSS prefix: brl-tree-.
   *
   * Differs from the global $lib/design/patterns/FileTreeNode.svelte in that:
   *   1. It fetches children lazily on expand via directoryListingQuery
   *      (not from a pre-fetched recursive tree).
   *   2. It renders inside a 280px panel — sizing/typography tuned tighter.
   *
   * LOC target: ≤ 160.
   */
  import {
    type CreateQueryOptions,
    createQuery,
  } from "@tanstack/svelte-query";
  import { ChevronRight, File, Folder } from "lucide-svelte";
  import { untrack } from "svelte";
  import { writable } from "svelte/store";
  import { directoryListingQuery } from "$lib/api/queries/file-tree.js";
  import { fileIcon } from "$lib/api/queries/files.js";
  import type { DirEntry } from "$lib/domain/workspaces/types.js";
  import FileTreeNodeSelf from "./FileTreeNode.svelte";

  interface Props {
    /** Workspace slug this tree is rooted in. */
    workspaceSlug: string;
    /** Entry describing this node. */
    entry: DirEntry;
    /** Depth from the rail root (0 = top-level inside rail). */
    depth: number;
    /** Called when a file (not a directory) is double-clicked. */
    onOpenFile: (entry: DirEntry) => void;
    /** Optional drag start handler — emits a drag payload for Mosaic drops. */
    onDragStart?: (entry: DirEntry, ev: DragEvent) => void;
  }

  let { workspaceSlug, entry, depth, onOpenFile, onDragStart }: Props =
    $props();

  let isExpanded = $state(false);

  // Lazy directory query — only enabled when this node is a dir AND expanded.
  function buildOpts(): CreateQueryOptions<DirEntry[]> {
    return {
      ...directoryListingQuery(workspaceSlug, entry.path),
      enabled: Boolean(workspaceSlug) && entry.isDir && isExpanded,
    } as CreateQueryOptions<DirEntry[]>;
  }

  const optsStore = writable(untrack(() => buildOpts()));
  $effect(() => {
    // Re-run when slug, path, or expansion state changes.
    optsStore.set(buildOpts());
  });
  const dirQ = createQuery<DirEntry[]>(optsStore);

  const indent = $derived(depth * 10);

  function handleClick(): void {
    if (entry.isDir) {
      isExpanded = !isExpanded;
    }
  }

  function handleDoubleClick(): void {
    if (!entry.isDir) {
      onOpenFile(entry);
    }
  }

  function handleDragStart(ev: DragEvent): void {
    if (onDragStart) onDragStart(entry, ev);
  }

  // Extract extension for icon mapping (used only for files).
  const extension = $derived(
    entry.isDir
      ? null
      : (entry.name.split(".").pop()?.toLowerCase() ?? null),
  );
</script>

<li class="brl-tree-node" role="none">
  <button
    type="button"
    class="brl-tree-row"
    class:brl-tree-row--dir={entry.isDir}
    style="padding-left: calc(var(--space-2) + {indent}px);"
    onclick={handleClick}
    ondblclick={handleDoubleClick}
    ondragstart={handleDragStart}
    draggable={!entry.isDir}
    aria-expanded={entry.isDir ? isExpanded : undefined}
    title={entry.path}
  >
    {#if entry.isDir}
      <span class="brl-tree-chev" class:brl-tree-chev--open={isExpanded} aria-hidden="true">
        <ChevronRight size={12} />
      </span>
      <span class="brl-tree-icon" aria-hidden="true">
        <Folder size={13} />
      </span>
    {:else}
      <span class="brl-tree-chev brl-tree-chev--placeholder" aria-hidden="true"></span>
      <span class="brl-tree-icon" aria-hidden="true">
        {#if extension}
          <span class="brl-tree-emoji">{fileIcon(extension)}</span>
        {:else}
          <File size={13} />
        {/if}
      </span>
    {/if}
    <span class="brl-tree-name">{entry.name}</span>
  </button>

  {#if entry.isDir && isExpanded}
    {#if $dirQ.isLoading}
      <div class="brl-tree-loading" style="padding-left: calc(var(--space-4) + {indent}px);">
        Loading…
      </div>
    {:else if $dirQ.isError}
      <div class="brl-tree-error" style="padding-left: calc(var(--space-4) + {indent}px);">
        Failed to load
      </div>
    {:else if $dirQ.data && $dirQ.data.length > 0}
      <ul class="brl-tree-children" role="group">
        {#each $dirQ.data as child (child.path)}
          <FileTreeNodeSelf
            {workspaceSlug}
            entry={child}
            depth={depth + 1}
            {onOpenFile}
            {onDragStart}
          />
        {/each}
      </ul>
    {:else if $dirQ.data}
      <div class="brl-tree-empty" style="padding-left: calc(var(--space-4) + {indent}px);">
        Empty
      </div>
    {/if}
  {/if}
</li>

<style>
  .brl-tree-node {
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .brl-tree-row {
    display: flex;
    align-items: center;
    gap: var(--space-1, 4px);
    width: 100%;
    min-height: 24px;
    padding-right: var(--space-2);
    border: none;
    background: transparent;
    border-radius: var(--radius-sm, 4px);
    cursor: pointer;
    font-family: var(--font-mono);
    font-size: 11.5px;
    color: var(--fg-muted);
    text-align: left;
    white-space: nowrap;
    overflow: hidden;
    transition: background 80ms ease-out;
  }

  .brl-tree-row:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .brl-tree-chev {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 12px;
    height: 12px;
    flex-shrink: 0;
    color: var(--fg-subtle);
    transition: transform 100ms ease-out;
  }

  .brl-tree-chev--open {
    transform: rotate(90deg);
  }

  .brl-tree-chev--placeholder {
    width: 12px;
  }

  .brl-tree-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 14px;
    flex-shrink: 0;
    color: var(--fg-subtle);
  }

  .brl-tree-emoji {
    font-size: 12px;
    line-height: 1;
  }

  .brl-tree-name {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .brl-tree-children {
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .brl-tree-loading,
  .brl-tree-error,
  .brl-tree-empty {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
    padding-top: 2px;
    padding-bottom: 2px;
  }

  .brl-tree-error {
    color: var(--signal-error, #eb4335);
  }
</style>
