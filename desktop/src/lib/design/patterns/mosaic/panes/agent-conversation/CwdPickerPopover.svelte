<script lang="ts" module>
  /**
   * Pure helpers — pulled out so tests don't need a Svelte runtime.
   */
  import type { DirEntry } from '$lib/domain/workspaces/types.js';

  /**
   * Resolve the parent path of a workspace-relative path. The workspace
   * root is "" — its parent is also "" (we don't escape the workspace).
   */
  export function parentDir(path: string): string {
    const trimmed = path.replace(/\/+$/, '');
    if (!trimmed) return '';
    const idx = trimmed.lastIndexOf('/');
    return idx === -1 ? '' : trimmed.slice(0, idx);
  }

  /**
   * Filter a flat directory listing to directories whose name contains
   * the query (case-insensitive). Empty query = all dirs.
   */
  export function filterDirs(
    entries: readonly DirEntry[],
    query: string,
  ): DirEntry[] {
    const dirs = entries.filter((e) => e.isDir);
    const q = query.trim().toLowerCase();
    if (!q) return dirs;
    return dirs.filter((d) => d.name.toLowerCase().includes(q));
  }
</script>

<script lang="ts">
  /**
   * CwdPickerPopover — "Search directories…" popover anchored to the
   * cwd chip. Lists `.. (Parent Directory)` + child folders of the
   * current cwd, with a top-of-popover filter.
   *
   * REUSE — talks to `directoryListingQuery` (which wraps the existing
   * listDir API). No new fetcher.
   *
   * Closes on Esc, outside click, or selection.
   *
   * CSS prefix: cwd-pop-
   */
  import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
  import { ArrowUp, Folder, Search } from 'lucide-svelte';
  import { onMount, tick, untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import { directoryListingQuery } from '$lib/api/queries/file-tree.js';
  import type { DirEntry } from '$lib/domain/workspaces/types.js';
  import { activeWorkspace } from '$lib/stores/active-workspace.svelte.js';

  interface Props {
    workspaceSlug: string;
    /** Workspace-relative current directory (""=root). */
    cwd: string;
    /** Fires when the user picks a destination. The string is the new
     *  workspace-relative cwd. */
    onPick: (newCwd: string) => void;
    /** Outside click / Esc → close. */
    onClose: () => void;
  }

  let { workspaceSlug, cwd, onPick, onClose }: Props = $props();

  let query = $state('');
  let popoverEl = $state<HTMLDivElement | null>(null);
  let inputEl = $state<HTMLInputElement | null>(null);

  // ── Directory listing (lazy, single query for current cwd) ─────────────────
  // The API expects a path relative to the workspace root. Strip the root
  // prefix if cwd is an absolute path matching the workspace root.
  function relativeCwd(absCwd: string): string {
    const root = activeWorkspace?.rootPath;
    if (!root || !absCwd) return '';
    if (absCwd === root) return '';
    if (absCwd.startsWith(root + '/')) return absCwd.slice(root.length + 1);
    if (absCwd.startsWith('/')) return '';
    return absCwd;
  }

  const optsStore = writable(
    untrack(() =>
      directoryListingQuery(workspaceSlug, relativeCwd(cwd)) as CreateQueryOptions<DirEntry[]>,
    ),
  );
  $effect(() => {
    optsStore.set(
      directoryListingQuery(workspaceSlug, relativeCwd(cwd)) as CreateQueryOptions<DirEntry[]>,
    );
  });
  const listQ = createQuery<DirEntry[]>(optsStore);

  const dirs = $derived<DirEntry[]>(filterDirs($listQ.data ?? [], query));
  const showParent = $derived<boolean>(cwd !== '');
  const parentPath = $derived<string>(parentDir(cwd));

  // ── Focus + outside click + Esc ────────────────────────────────────────────
  onMount(() => {
    void tick().then(() => inputEl?.focus());

    const onDocPointer = (ev: PointerEvent): void => {
      const target = ev.target as Node | null;
      if (!target || !popoverEl) return;
      if (!popoverEl.contains(target)) onClose();
    };
    const onKey = (e: KeyboardEvent): void => {
      if (e.key === 'Escape') {
        e.preventDefault();
        onClose();
      }
    };
    // Capture phase so we beat anything the chip itself binds.
    document.addEventListener('pointerdown', onDocPointer, true);
    document.addEventListener('keydown', onKey, true);
    return () => {
      document.removeEventListener('pointerdown', onDocPointer, true);
      document.removeEventListener('keydown', onKey, true);
    };
  });

  function handlePick(path: string): void {
    onPick(path);
    onClose();
  }
</script>

<div
  class="cwd-pop"
  role="dialog"
  aria-label="Pick working directory"
  bind:this={popoverEl}
>
  <div class="cwd-pop__head">
    <Search size={11} aria-hidden="true" />
    <input
      type="search"
      class="cwd-pop__input"
      placeholder="Search directories…"
      bind:value={query}
      bind:this={inputEl}
      aria-label="Filter directories"
    />
  </div>

  <div class="cwd-pop__cwd" title={cwd || '/'}>
    <span class="cwd-pop__cwd-label">cwd</span>
    <span class="cwd-pop__cwd-path">{cwd || '/'}</span>
  </div>

  <ul class="cwd-pop__list" role="listbox">
    {#if showParent}
      <li role="none">
        <button
          type="button"
          class="cwd-pop__row cwd-pop__row--parent"
          role="option"
          aria-selected="false"
          onclick={() => handlePick(parentPath)}
        >
          <ArrowUp size={11} aria-hidden="true" />
          <span class="cwd-pop__row-name">.. (Parent Directory)</span>
        </button>
      </li>
    {/if}

    {#if $listQ.isLoading}
      <li role="none" class="cwd-pop__status">Loading…</li>
    {:else if $listQ.isError}
      <li role="none" class="cwd-pop__status cwd-pop__status--err">
        Could not list directory
      </li>
    {:else if dirs.length === 0}
      <li role="none" class="cwd-pop__status">No directories</li>
    {:else}
      {#each dirs as d (d.path)}
        <li role="none">
          <button
            type="button"
            class="cwd-pop__row"
            role="option"
            aria-selected="false"
            onclick={() => handlePick(d.path)}
            title={d.path}
          >
            <Folder size={11} aria-hidden="true" />
            <span class="cwd-pop__row-name">{d.name}</span>
          </button>
        </li>
      {/each}
    {/if}
  </ul>
</div>

<style>
  .cwd-pop {
    display: flex;
    flex-direction: column;
    width: 320px;
    max-height: 360px;
    border: 1px solid var(--border, rgba(255, 255, 255, 0.12));
    border-radius: 8px;
    background: var(--bg-elev, var(--bg));
    box-shadow: 0 10px 32px rgba(0, 0, 0, 0.45);
    overflow: hidden;
    color: var(--fg);
  }

  .cwd-pop__head {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 10px;
    border-bottom: 1px solid var(--border, rgba(255, 255, 255, 0.08));
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    color: var(--fg-subtle);
  }

  .cwd-pop__input {
    flex: 1;
    border: none;
    outline: none;
    background: transparent;
    color: var(--fg);
    font-family: var(--font-sans);
    font-size: 12px;
  }
  .cwd-pop__input::placeholder { color: var(--fg-subtle); }

  .cwd-pop__cwd {
    display: flex;
    gap: 6px;
    padding: 4px 12px;
    font-family: var(--font-mono);
    font-size: 10.5px;
    color: var(--fg-subtle);
    border-bottom: 1px solid var(--border, rgba(255, 255, 255, 0.06));
  }

  .cwd-pop__cwd-label {
    text-transform: uppercase;
    letter-spacing: 0.04em;
    font-weight: 500;
  }
  .cwd-pop__cwd-path {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .cwd-pop__list {
    list-style: none;
    margin: 0;
    padding: 4px 0;
    overflow-y: auto;
    flex: 1;
    min-height: 0;
  }

  .cwd-pop__row {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    padding: 5px 12px;
    border: none;
    background: transparent;
    color: var(--fg-muted);
    font-family: var(--font-mono);
    font-size: 11.5px;
    cursor: pointer;
    text-align: left;
    transition: background 80ms ease-out, color 80ms ease-out;
  }

  .cwd-pop__row:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg);
  }

  .cwd-pop__row--parent {
    color: var(--fg-subtle);
    font-style: italic;
  }

  .cwd-pop__row-name {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex: 1;
  }

  .cwd-pop__status {
    padding: 8px 12px;
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
  }

  .cwd-pop__status--err { color: var(--signal-error, oklch(0.62 0.22 25)); }
</style>
