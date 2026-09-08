<script lang="ts">
/**
 * ChangesFileList — dense file list for the diff panel.
 * CSS prefix: cfl-
 * LOC target: ≤ 140.
 */
import type { DiffFile } from '$lib/utils/parse-diff.js';
import { fileStatusIcon } from '$lib/utils/parse-diff.js';

interface Props {
  files: DiffFile[];
  activeFile: DiffFile | null;
  onSelect: (file: DiffFile) => void;
  onCommit: () => void;
}

let { files, activeFile, onSelect, onCommit }: Props = $props();

type Filter = 'all' | 'added' | 'modified' | 'deleted';
let filter = $state<Filter>('all');

const filtered = $derived(filter === 'all' ? files : files.filter((f) => f.status === filter));

const totalAdditions = $derived(files.reduce((n, f) => n + f.additions, 0));
const totalDeletions = $derived(files.reduce((n, f) => n + f.deletions, 0));

function statusColor(status: DiffFile['status']): string {
  switch (status) {
    case 'added':
      return 'var(--success, oklch(0.72 0.18 145))';
    case 'deleted':
      return 'var(--destructive, oklch(0.65 0.22 25))';
    case 'renamed':
      return 'var(--fg-muted)';
    default:
      return 'var(--cnp-accent, oklch(0.78 0.18 145))';
  }
}
</script>

<!-- Header -->
<div class="cfl-header">
  <span class="cfl-title">
    Changes
    {#if files.length > 0}
      <span class="cfl-badge">{files.length}</span>
    {/if}
  </span>
  {#if files.length > 0}
    <button class="cfl-commit-btn" onclick={onCommit} aria-label="Commit all changes">
      Commit all
    </button>
  {/if}
</div>

<!-- Summary bar -->
{#if files.length > 0}
  <div class="cfl-summary">
    <span class="cfl-additions">+{totalAdditions}</span>
    <span class="cfl-deletions">−{totalDeletions}</span>
  </div>

  <!-- Filter -->
  <div class="cfl-filters" role="group" aria-label="Filter changed files">
    {#each (['all', 'added', 'modified', 'deleted'] as const) as f (f)}
      <button
        class="cfl-filter-btn"
        class:cfl-filter-btn--active={filter === f}
        onclick={() => { filter = f; }}
        aria-pressed={filter === f}
      >
        {f.charAt(0).toUpperCase() + f.slice(1)}
      </button>
    {/each}
  </div>
{/if}

<!-- File list -->
<div class="cfl-list" role="listbox" aria-label="Changed files">
  {#if filtered.length === 0}
    <div class="cfl-empty">
      {files.length === 0
        ? 'No changes in this worktree yet.'
        : 'No files match this filter.'}
    </div>
  {:else}
    {#each filtered as file (file.path)}
      {@const isActive = activeFile?.path === file.path}
      <button
        class="cfl-row"
        class:cfl-row--active={isActive}
        role="option"
        aria-selected={isActive}
        onclick={() => onSelect(file)}
        title={file.path}
      >
        <span class="cfl-status-icon" style:color={statusColor(file.status)} aria-hidden="true">
          {fileStatusIcon(file.status)}
        </span>
        <span class="cfl-path">{file.path}</span>
        {#if !file.binary}
          <span class="cfl-counts">
            {#if file.additions > 0}
              <span class="cfl-add">+{file.additions}</span>
            {/if}
            {#if file.deletions > 0}
              <span class="cfl-del">−{file.deletions}</span>
            {/if}
          </span>
        {:else}
          <span class="cfl-binary">binary</span>
        {/if}
      </button>
    {/each}
  {/if}
</div>

<style>
  .cfl-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-2) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .cfl-title {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    display: flex;
    align-items: center;
    gap: var(--space-1);
  }

  .cfl-badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 18px;
    height: 18px;
    padding: 0 5px;
    border-radius: 9999px;
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-muted);
  }

  .cfl-commit-btn {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--cnp-accent, oklch(0.78 0.18 145));
    background: transparent;
    border: 1px solid color-mix(in oklch, var(--cnp-accent, oklch(0.78 0.18 145)) 40%, transparent);
    border-radius: var(--radius-sm);
    padding: 2px 8px;
    cursor: pointer;
    transition: background 0.1s ease, color 0.1s ease;
  }
  .cfl-commit-btn:hover {
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.78 0.18 145)) 10%, transparent);
    color: var(--fg);
  }
  .cfl-commit-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .cfl-summary {
    display: flex;
    gap: var(--space-2);
    padding: var(--space-1) var(--space-3);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .cfl-additions { color: var(--success, oklch(0.72 0.18 145)); }
  .cfl-deletions { color: var(--destructive, oklch(0.65 0.22 25)); }

  .cfl-filters {
    display: flex;
    gap: 0;
    padding: var(--space-1) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    overflow-x: auto;
    scrollbar-width: none;
  }

  .cfl-filter-btn {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 500;
    color: var(--fg-subtle);
    background: transparent;
    border: none;
    padding: 2px 6px;
    cursor: pointer;
    border-radius: var(--radius-sm);
    transition: color 0.1s ease, background 0.1s ease;
    white-space: nowrap;
  }
  .cfl-filter-btn:hover:not(.cfl-filter-btn--active) {
    color: var(--fg-muted);
  }
  .cfl-filter-btn--active {
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
  }

  .cfl-list {
    flex: 1;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .cfl-empty {
    padding: var(--space-6) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    text-align: center;
    font-style: italic;
  }

  .cfl-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    width: 100%;
    padding: var(--space-1) var(--space-3);
    background: transparent;
    border: none;
    border-left: 2px solid transparent;
    cursor: pointer;
    text-align: left;
    transition: background 0.1s ease, border-color 0.1s ease;
    min-width: 0;
  }
  .cfl-row:hover:not(.cfl-row--active) {
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }
  .cfl-row--active {
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.78 0.18 145)) 8%, transparent);
    border-left-color: var(--cnp-accent, oklch(0.78 0.18 145));
  }

  .cfl-status-icon {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    font-weight: 700;
    flex-shrink: 0;
    width: 12px;
    text-align: center;
  }

  .cfl-path {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg);
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    direction: rtl;
    text-align: left;
  }

  .cfl-counts {
    display: flex;
    gap: 4px;
    flex-shrink: 0;
  }

  .cfl-add {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--success, oklch(0.72 0.18 145));
  }

  .cfl-del {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--destructive, oklch(0.65 0.22 25));
  }

  .cfl-binary {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    font-style: italic;
    flex-shrink: 0;
  }
</style>
