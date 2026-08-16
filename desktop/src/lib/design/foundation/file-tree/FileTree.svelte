<script lang="ts">
  /**
   * FileTree — shared workspace file-tree primitive.
   * CSS prefix: ft-root- (FileTree root).
   *
   * Foundation primitive used by:
   *   • /files (project explorer page)
   *   • Build rail's ProjectExplorerSection
   *   • Anywhere else that needs to render a workspace's filesystem as a tree
   *
   * Contract:
   *   • Reads top-level entries via `directoryListingQuery(slug, "")`.
   *   • Lazy-loads children when a folder is expanded.
   *   • Owns the `expanded` Set + `selected` path state internally; emits
   *     callbacks so consumers can persist or react.
   *   • Hides dotfiles by default (toggleable via `hideHidden` prop).
   *
   * Props:
   *   workspaceSlug   — workspace whose root_path is rendered
   *   onFileSelect    — called with the DirEntry when a file row is clicked
   *   onFolderToggle  — optional; called with (path, expanded) on chevron toggle
   *   initialExpanded — optional; seed expanded folder paths (e.g. from
   *                     useWorkspaceState)
   *   initialSelected — optional; seed the highlighted file path
   *   hideHidden      — defaults to true; controls whether `.foo` rows render
   *   onDragStart     — optional; called with (entry, ev) when a file is
   *                     dragged. Consumers serialize the payload they need.
   *
   * LOC target: ≤ 200.
   */
  import {
    type CreateQueryOptions,
    createQuery,
  } from "@tanstack/svelte-query";
  import { FolderOpen } from "lucide-svelte";
  import { untrack } from "svelte";
  import { writable } from "svelte/store";
  import { directoryListingQuery } from "$lib/api/queries/file-tree.js";
  import type { DirEntry } from "$lib/domain/workspaces/types.js";
  import FileTreeNode from "./FileTreeNode.svelte";

  interface Props {
    workspaceSlug: string;
    onFileSelect: (entry: DirEntry) => void;
    onFolderToggle?: (path: string, expanded: boolean) => void;
    initialExpanded?: string[];
    initialSelected?: string | null;
    hideHidden?: boolean;
    onDragStart?: (entry: DirEntry, ev: DragEvent) => void;
  }

  let {
    workspaceSlug,
    onFileSelect,
    onFolderToggle,
    initialExpanded,
    initialSelected = null,
    hideHidden = true,
    onDragStart,
  }: Props = $props();

  // ── Internal state ─────────────────────────────────────────────────────────
  // Use a Set wrapped in $state — Svelte 5 tracks Set mutations when reassigned.
  let expandedPaths = $state<Set<string>>(new Set(initialExpanded ?? []));
  let selectedPath = $state<string | null>(initialSelected);

  // Track the slug we initialized for so a workspace switch resets state.
  let lastSlug = $state<string | null>(null);
  $effect(() => {
    if (workspaceSlug && workspaceSlug !== lastSlug) {
      lastSlug = workspaceSlug;
      expandedPaths = new Set(initialExpanded ?? []);
      selectedPath = initialSelected;
    }
  });

  function toggleFolder(path: string, willBeExpanded: boolean): void {
    const next = new Set(expandedPaths);
    if (willBeExpanded) next.add(path);
    else next.delete(path);
    expandedPaths = next;
    onFolderToggle?.(path, willBeExpanded);
  }

  function selectFile(entry: DirEntry): void {
    selectedPath = entry.path;
    onFileSelect(entry);
  }

  // ── Top-level directory listing ────────────────────────────────────────────
  const optsStore = writable(
    untrack(
      () =>
        directoryListingQuery(workspaceSlug, "") as CreateQueryOptions<DirEntry[]>,
    ),
  );
  $effect(() => {
    optsStore.set(
      directoryListingQuery(workspaceSlug, "") as CreateQueryOptions<DirEntry[]>,
    );
  });
  const rootQ = createQuery<DirEntry[]>(optsStore);

  const visibleRoot = $derived(
    ($rootQ.data ?? []).filter(
      (e) => !hideHidden || !e.name.startsWith("."),
    ),
  );

  // Truncated-list warning for very large root directories. The tree itself
  // doesn't virtualize yet — we surface a hint so users know to use search.
  const LARGE_DIR_THRESHOLD = 500;
  const isLargeRoot = $derived(($rootQ.data?.length ?? 0) > LARGE_DIR_THRESHOLD);

  // ── Public-ish actions for parent components ───────────────────────────────
  /** Re-fetch the root listing and refresh expanded children. */
  export function refresh(): void {
    void $rootQ.refetch();
  }

  /** Clear selection (e.g. when navigation moves away). */
  export function clearSelection(): void {
    selectedPath = null;
  }
</script>

<div class="ft-root" role="tree" aria-label="Workspace files">
  {#if $rootQ.isLoading}
    <div class="ft-root__skeleton" aria-label="Loading files">
      {#each { length: 6 } as _, i (i)}
        <div class="ft-root__sk" style="width: {55 + (i % 3) * 15}%;"></div>
      {/each}
    </div>
  {:else if $rootQ.isError}
    <div class="ft-root__error" role="alert">
      <FolderOpen size={20} aria-hidden="true" />
      <span>{(($rootQ.error as Error)?.message ?? "Could not load files") || "Could not load files"}</span>
      <button class="ft-root__retry" type="button" onclick={refresh}>Retry</button>
    </div>
  {:else if visibleRoot.length === 0}
    <div class="ft-root__empty" role="status">
      <FolderOpen size={20} aria-hidden="true" />
      <span>{hideHidden && ($rootQ.data?.length ?? 0) > 0 ? "Only hidden files in this workspace" : "Empty workspace"}</span>
    </div>
  {:else}
    {#if isLargeRoot}
      <div class="ft-root__hint">
        Large directory ({$rootQ.data?.length ?? 0} entries). Use search to find files faster.
      </div>
    {/if}
    <ul class="ft-root__tree" role="group">
      {#each visibleRoot as entry (entry.path)}
        <FileTreeNode
          {workspaceSlug}
          {entry}
          depth={0}
          {selectedPath}
          {expandedPaths}
          {hideHidden}
          onFileSelect={selectFile}
          onFolderToggle={toggleFolder}
          {onDragStart}
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
    min-height: 0;
    overflow-y: auto;
    padding: var(--space-1, 4px) 0;
  }

  .ft-root__tree {
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .ft-root__skeleton {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-3);
  }

  .ft-root__sk {
    height: 12px;
    background: var(--border, rgba(0, 0, 0, 0.08));
    border-radius: var(--radius-sm, 4px);
    animation: ft-root-pulse 1.5s ease-in-out infinite;
  }

  @keyframes ft-root-pulse {
    0%, 100% { opacity: 0.3; }
    50% { opacity: 0.6; }
  }

  .ft-root__error,
  .ft-root__empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-6);
    text-align: center;
    color: var(--fg-subtle);
    font-family: var(--font-sans);
    font-size: 12px;
  }

  .ft-root__error {
    color: var(--signal-error, #eb4335);
  }

  .ft-root__retry {
    background: transparent;
    border: 1px solid currentColor;
    color: inherit;
    padding: 4px 12px;
    border-radius: var(--radius-sm, 4px);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: 11px;
  }

  .ft-root__retry:hover {
    background: color-mix(in oklch, currentColor 10%, transparent 90%);
  }

  .ft-root__hint {
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
    border-bottom: 1px dashed var(--border);
    background: color-mix(in oklch, var(--fg) 3%, transparent 97%);
  }
</style>
