<script lang="ts">
  /**
   * FileTreeNode — recursive lazy-loading tree node primitive.
   * CSS prefix: ft- (FileTree).
   *
   * Foundation primitive — used by FileTree.svelte. Renders a single tree row
   * (folder or file) and, when a folder is expanded, fetches its children via
   * `directoryListingQuery` and recurses.
   *
   * This is the SHARED implementation. Both /files and the Build rail's
   * ProjectExplorerSection use this — see foundation/file-tree/index.ts.
   *
   * LOC target: ≤ 200.
   */
  import {
    type CreateQueryOptions,
    createQuery,
  } from "@tanstack/svelte-query";
  import { ChevronRight, File as FileIcon, Folder } from "lucide-svelte";
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
    /** Depth from the tree root (0 = top-level). */
    depth: number;
    /** Currently selected path (or null). Used to highlight one row. */
    selectedPath: string | null;
    /** Set of paths whose children are expanded. */
    expandedPaths: Set<string>;
    /** Hide entries whose name starts with "." (default: true at root). */
    hideHidden: boolean;
    /** File-click handler — receives the entry. */
    onFileSelect: (entry: DirEntry) => void;
    /** Folder-toggle handler — receives the path + the next-expanded boolean. */
    onFolderToggle: (path: string, willBeExpanded: boolean) => void;
    /** Optional drag-start handler — emits a drag payload for drop targets. */
    onDragStart?: (entry: DirEntry, ev: DragEvent) => void;
  }

  let {
    workspaceSlug,
    entry,
    depth,
    selectedPath,
    expandedPaths,
    hideHidden,
    onFileSelect,
    onFolderToggle,
    onDragStart,
  }: Props = $props();

  const isExpanded = $derived(expandedPaths.has(entry.path));
  const isSelected = $derived(selectedPath === entry.path);

  // Lazy directory query — only enabled when this node is a dir AND expanded.
  function buildOpts(): CreateQueryOptions<DirEntry[]> {
    return {
      ...directoryListingQuery(workspaceSlug, entry.path),
      enabled: Boolean(workspaceSlug) && entry.isDir && isExpanded,
    } as CreateQueryOptions<DirEntry[]>;
  }

  const optsStore = writable(untrack(() => buildOpts()));
  $effect(() => {
    optsStore.set(buildOpts());
  });
  const dirQ = createQuery<DirEntry[]>(optsStore);

  const indent = $derived(depth * 12);

  function handleClick(): void {
    if (entry.isDir) {
      onFolderToggle(entry.path, !isExpanded);
    } else {
      onFileSelect(entry);
    }
  }

  function handleKeydown(ev: KeyboardEvent): void {
    if (ev.key === "Enter" || ev.key === " ") {
      ev.preventDefault();
      handleClick();
    }
  }

  function handleDragStart(ev: DragEvent): void {
    if (onDragStart) onDragStart(entry, ev);
  }

  // Filter children by hidden-toggle.
  const visibleChildren = $derived(
    ($dirQ.data ?? []).filter(
      (child) => !hideHidden || !child.name.startsWith("."),
    ),
  );

  const extension = $derived(
    entry.isDir
      ? null
      : (entry.name.split(".").pop()?.toLowerCase() ?? null),
  );
</script>

<li class="ft-node" role="none">
  <button
    type="button"
    class="ft-row"
    class:ft-row--dir={entry.isDir}
    class:ft-row--selected={isSelected}
    style="padding-left: calc(var(--space-2) + {indent}px);"
    onclick={handleClick}
    onkeydown={handleKeydown}
    ondragstart={handleDragStart}
    draggable={!entry.isDir}
    aria-expanded={entry.isDir ? isExpanded : undefined}
    aria-selected={isSelected}
    title={entry.path}
  >
    {#if entry.isDir}
      <span class="ft-chev" class:ft-chev--open={isExpanded} aria-hidden="true">
        <ChevronRight size={12} />
      </span>
      <span class="ft-icon" aria-hidden="true">
        <Folder size={13} />
      </span>
    {:else}
      <span class="ft-chev ft-chev--placeholder" aria-hidden="true"></span>
      <span class="ft-icon" aria-hidden="true">
        {#if extension}
          <span class="ft-emoji">{fileIcon(extension)}</span>
        {:else}
          <FileIcon size={13} />
        {/if}
      </span>
    {/if}
    <span class="ft-name">{entry.name}</span>
  </button>

  {#if entry.isDir && isExpanded}
    {#if $dirQ.isLoading}
      <div class="ft-leaf-msg" style="padding-left: calc(var(--space-6) + {indent}px);">
        Loading…
      </div>
    {:else if $dirQ.isError}
      <div
        class="ft-leaf-msg ft-leaf-msg--error"
        style="padding-left: calc(var(--space-6) + {indent}px);"
        role="alert"
      >
        {(($dirQ.error as Error)?.message ?? "Failed to load") || "Failed to load"}
      </div>
    {:else if visibleChildren.length > 0}
      <ul class="ft-children" role="group">
        {#each visibleChildren as child (child.path)}
          <FileTreeNodeSelf
            {workspaceSlug}
            entry={child}
            depth={depth + 1}
            {selectedPath}
            {expandedPaths}
            {hideHidden}
            {onFileSelect}
            {onFolderToggle}
            {onDragStart}
          />
        {/each}
      </ul>
    {:else}
      <div
        class="ft-leaf-msg"
        style="padding-left: calc(var(--space-6) + {indent}px);"
      >
        Empty
      </div>
    {/if}
  {/if}
</li>

<style>
  .ft-node {
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .ft-row {
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
    font-size: 12px;
    color: var(--fg-muted);
    text-align: left;
    white-space: nowrap;
    overflow: hidden;
    transition: background 80ms ease-out, color 80ms ease-out;
  }

  .ft-row:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .ft-row--selected {
    background: color-mix(in oklch, var(--cnp-accent, #6e8df1) 14%, transparent 86%);
    color: var(--fg);
  }

  .ft-row--selected:hover {
    background: color-mix(in oklch, var(--cnp-accent, #6e8df1) 20%, transparent 80%);
  }

  .ft-row:focus-visible {
    outline: 2px solid var(--cnp-accent, #6e8df1);
    outline-offset: -2px;
  }

  .ft-chev {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 12px;
    height: 12px;
    flex-shrink: 0;
    color: var(--fg-subtle);
    transition: transform 100ms ease-out;
  }

  .ft-chev--open {
    transform: rotate(90deg);
  }

  .ft-chev--placeholder {
    width: 12px;
  }

  .ft-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 14px;
    flex-shrink: 0;
    color: var(--fg-subtle);
  }

  .ft-emoji {
    font-size: 12px;
    line-height: 1;
  }

  .ft-name {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ft-children {
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .ft-leaf-msg {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
    padding-top: 2px;
    padding-bottom: 2px;
  }

  .ft-leaf-msg--error {
    color: var(--signal-error, #eb4335);
  }
</style>
