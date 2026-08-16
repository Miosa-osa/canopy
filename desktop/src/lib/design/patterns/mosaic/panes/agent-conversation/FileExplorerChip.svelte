<script lang="ts" module>
  /**
   * Pure helpers — kept module-scoped so tests don't need a Svelte runtime.
   */
  import type { DirEntry } from '$lib/domain/workspaces/types.js';

  /** Filter a directory listing by case-insensitive substring match. */
  export function filterEntries(
    entries: readonly DirEntry[],
    query: string,
  ): DirEntry[] {
    const q = query.trim().toLowerCase();
    if (!q) return [...entries];
    return entries.filter((e) => e.name.toLowerCase().includes(q));
  }
</script>

<script lang="ts">
  /**
   * FileExplorerChip — chip + popover with an inline file picker.
   *
   * REUSE — wraps the same `FileTreeNode` (build/sections variant) used
   * by ProjectExplorerSection. We deliberately do NOT extract a shared
   * <FileTree> primitive because the existing `FileTree.svelte` (full
   * recursive tree) and `build/sections/FileTreeNode.svelte` (lazy
   * per-folder) already cover the two real shapes — extracting a third
   * abstraction would be premature.
   *
   * Behavior:
   *   - Click chip → popover opens.
   *   - Type in search → filters TOP-LEVEL entries; tree-expand still works.
   *   - Click a file → emits onPickFile(workspaceRelativePath).
   *   - Esc / outside-click → close.
   *
   * CSS prefix: fec-
   */
  import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
  import { FolderTree, Search } from 'lucide-svelte';
  import { onMount, tick, untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import { directoryListingQuery } from '$lib/api/queries/file-tree.js';
  import type { DirEntry } from '$lib/domain/workspaces/types.js';
  import FileTreeNode from '$lib/design/patterns/build/sections/FileTreeNode.svelte';

  interface Props {
    workspaceSlug: string;
    /** Workspace-relative root for the picker — defaults to "" (workspace root). */
    rootPath?: string;
    /** Fires when a file is selected. Path is workspace-relative. */
    onPickFile: (path: string) => void;
  }

  let { workspaceSlug, rootPath = '', onPickFile }: Props = $props();

  let open = $state(false);
  let query = $state('');
  let triggerEl = $state<HTMLButtonElement | null>(null);
  let popoverEl = $state<HTMLDivElement | null>(null);
  let inputEl = $state<HTMLInputElement | null>(null);

  // ── Top-level listing ─────────────────────────────────────────────────────
  const optsStore = writable(
    untrack(
      () => directoryListingQuery(workspaceSlug, rootPath) as CreateQueryOptions<DirEntry[]>,
    ),
  );
  $effect(() => {
    optsStore.set(
      directoryListingQuery(workspaceSlug, rootPath) as CreateQueryOptions<DirEntry[]>,
    );
  });
  const listQ = createQuery<DirEntry[]>(optsStore);

  const visibleEntries = $derived<DirEntry[]>(filterEntries($listQ.data ?? [], query));

  // ── Open / close lifecycle ────────────────────────────────────────────────
  function toggle(): void {
    open = !open;
    if (open) void tick().then(() => inputEl?.focus());
  }

  function close(): void {
    open = false;
    query = '';
  }

  $effect(() => {
    if (!open) return;

    const onDocPointer = (ev: PointerEvent): void => {
      const target = ev.target as Node | null;
      if (!target) return;
      if (popoverEl && popoverEl.contains(target)) return;
      if (triggerEl && triggerEl.contains(target)) return;
      close();
    };
    const onKey = (e: KeyboardEvent): void => {
      if (e.key === 'Escape') {
        e.preventDefault();
        close();
      }
    };
    document.addEventListener('pointerdown', onDocPointer, true);
    document.addEventListener('keydown', onKey, true);
    return () => {
      document.removeEventListener('pointerdown', onDocPointer, true);
      document.removeEventListener('keydown', onKey, true);
    };
  });

  function handleOpenFile(entry: DirEntry): void {
    if (entry.isDir) return;
    onPickFile(entry.path);
    close();
  }
</script>

<div class="fec-host">
  <button
    type="button"
    class="fec-chip"
    class:fec-chip--on={open}
    onclick={toggle}
    bind:this={triggerEl}
    aria-haspopup="dialog"
    aria-expanded={open}
    aria-label="Open file explorer"
    title="Browse files"
  >
    <FolderTree size={11} aria-hidden="true" />
    <span class="fec-chip__label">Files</span>
  </button>

  {#if open}
    <div
      class="fec-pop"
      role="dialog"
      aria-label="File explorer"
      bind:this={popoverEl}
    >
      <div class="fec-pop__head">
        <Search size={11} aria-hidden="true" />
        <input
          type="search"
          class="fec-pop__input"
          placeholder="Search files…"
          bind:value={query}
          bind:this={inputEl}
          aria-label="Filter files"
        />
      </div>

      <div class="fec-pop__body" role="tree" aria-label="Workspace files">
        {#if $listQ.isLoading}
          <div class="fec-pop__status">Loading…</div>
        {:else if $listQ.isError}
          <div class="fec-pop__status fec-pop__status--err">
            Could not load files
          </div>
        {:else if visibleEntries.length === 0}
          <div class="fec-pop__status">No matches</div>
        {:else}
          <ul class="fec-pop__tree" role="group">
            {#each visibleEntries as entry (entry.path)}
              <FileTreeNode
                {workspaceSlug}
                {entry}
                depth={0}
                onOpenFile={handleOpenFile}
              />
            {/each}
          </ul>
        {/if}
      </div>
    </div>
  {/if}
</div>

<style>
  .fec-host {
    position: relative;
    display: inline-flex;
  }

  .fec-chip {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 3px 8px;
    height: 22px;
    border: 1px solid var(--border, rgba(255, 255, 255, 0.10));
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    border-radius: 999px;
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: 11px;
    cursor: pointer;
    transition: background 80ms ease-out, color 80ms ease-out, border-color 80ms ease-out;
  }
  .fec-chip:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg);
    border-color: color-mix(in oklch, var(--fg) 18%, transparent);
  }
  .fec-chip--on {
    color: var(--fg);
    border-color: color-mix(in oklch, var(--fg) 24%, transparent);
    background: color-mix(in oklch, var(--fg) 12%, transparent);
  }

  .fec-chip__label { white-space: nowrap; }

  .fec-pop {
    position: absolute;
    bottom: calc(100% + 6px);
    left: 0;
    width: 320px;
    max-height: 380px;
    display: flex;
    flex-direction: column;
    border: 1px solid var(--border, rgba(255, 255, 255, 0.12));
    border-radius: 8px;
    background: var(--bg-elev, var(--bg));
    box-shadow: 0 10px 32px rgba(0, 0, 0, 0.45);
    overflow: hidden;
    z-index: 50;
  }

  .fec-pop__head {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 10px;
    border-bottom: 1px solid var(--border, rgba(255, 255, 255, 0.08));
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    color: var(--fg-subtle);
  }

  .fec-pop__input {
    flex: 1;
    border: none;
    outline: none;
    background: transparent;
    color: var(--fg);
    font-family: var(--font-sans);
    font-size: 12px;
  }
  .fec-pop__input::placeholder { color: var(--fg-subtle); }

  .fec-pop__body {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    padding: 4px 0;
  }

  .fec-pop__tree {
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .fec-pop__status {
    padding: 12px;
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
    text-align: center;
  }

  .fec-pop__status--err { color: var(--signal-error, oklch(0.62 0.22 25)); }
</style>
