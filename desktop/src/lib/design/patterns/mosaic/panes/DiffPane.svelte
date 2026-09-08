<script lang="ts">
/**
 * DiffPane — Mosaic pane for inspecting a git diff.
 *
 * Two modes:
 *   1. Session mode (sessionId) → live worktree diff with hunk-level
 *      Keep / Discard / Stage and Commit. Backed by the Phase-5
 *      ChangesPanel (FileList + DiffViewer + CommitModal) wrapped here
 *      with hunk actions via FileDiff.
 *   2. Ref mode (fromRef + toRef) → arbitrary diff between two refs.
 *      Read-only — no commit, no discard.
 *
 * Reuses (no duplication):
 *   - ChangesFileList (via ./diff/FileList wrapper)
 *   - DiffViewer       (via ./diff/FileDiff wrapper)
 *   - CommitModal      (via ./diff/CommitComposer wrapper)
 *   - parse-diff       (for ref-mode parsing)
 *   - worktreeStatusQuery / worktreeDiffQuery (via queries/diff.ts)
 *
 * CSS prefix: dp-
 * LOC target: ≤ 260.
 */
import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { useWorktreeDiff, useWorktreeStatus } from '$lib/api/queries/diff.js';
import type { WorktreeStatus } from '$lib/api/queries/sessions.js';
import type { DiffFile, DiffPaneOptions, DiffViewMode } from '$lib/domain/diff/types.js';
import { isTruncated, parseDiff } from '$lib/utils/parse-diff.js';
import CommitComposer from './diff/CommitComposer.svelte';
import FileDiff from './diff/FileDiff.svelte';
import FileList from './diff/FileList.svelte';

interface Props {
  /** When set, the pane shows the live worktree diff for this session. */
  sessionId?: string;
  /** Optional ref-mode diff (read-only). Reserved for future use. */
  fromRef?: string;
  toRef?: string;
  workspaceSlug: string;
}

let { sessionId, fromRef, toRef, workspaceSlug: _ws }: Props = $props();

const inSessionMode = $derived(Boolean(sessionId));
const inRefMode = $derived(!sessionId && Boolean(fromRef && toRef));

// ── Pane-level toggles ───────────────────────────────────────────────────────

const VIEW_KEY = 'canopy.diff.view_mode';
const WS_KEY = 'canopy.diff.ignore_whitespace';

let opts = $state<DiffPaneOptions>({
  viewMode:
    typeof localStorage !== 'undefined'
      ? ((localStorage.getItem(VIEW_KEY) as DiffViewMode) ?? 'inline')
      : 'inline',
  ignoreWhitespace:
    typeof localStorage !== 'undefined' ? localStorage.getItem(WS_KEY) === '1' : false,
});

function setViewMode(m: DiffViewMode): void {
  opts.viewMode = m;
  if (typeof localStorage !== 'undefined') localStorage.setItem(VIEW_KEY, m);
}

function toggleWhitespace(): void {
  opts.ignoreWhitespace = !opts.ignoreWhitespace;
  if (typeof localStorage !== 'undefined') {
    localStorage.setItem(WS_KEY, opts.ignoreWhitespace ? '1' : '0');
  }
}

// ── Session-mode queries ─────────────────────────────────────────────────────

const statusOptsStore = writable(
  untrack(
    () =>
      (sessionId
        ? useWorktreeStatus(sessionId)
        : {
            queryKey: ['sessions', 'none', 'worktree'],
            queryFn: () => null,
            enabled: false,
          }) as CreateQueryOptions<WorktreeStatus | null>
  )
);
$effect(() => {
  statusOptsStore.set(
    (sessionId
      ? useWorktreeStatus(sessionId)
      : {
          queryKey: ['sessions', 'none', 'worktree'],
          queryFn: () => null,
          enabled: false,
        }) as CreateQueryOptions<WorktreeStatus | null>
  );
});
const statusQuery = createQuery<WorktreeStatus | null>(statusOptsStore);

const hasWorktree = $derived(Boolean($statusQuery.data?.path));
const changesCount = $derived($statusQuery.data?.changesCount ?? 0);

const diffOptsStore = writable(
  untrack(
    () =>
      (sessionId
        ? useWorktreeDiff(sessionId, false)
        : {
            queryKey: ['sessions', 'none', 'worktree', 'diff'],
            queryFn: () => ({ raw: '', truncated: false }),
            enabled: false,
          }) as CreateQueryOptions<{ raw: string; truncated: boolean }>
  )
);
$effect(() => {
  diffOptsStore.set(
    (sessionId
      ? useWorktreeDiff(sessionId, hasWorktree && changesCount > 0)
      : {
          queryKey: ['sessions', 'none', 'worktree', 'diff'],
          queryFn: () => ({ raw: '', truncated: false }),
          enabled: false,
        }) as CreateQueryOptions<{ raw: string; truncated: boolean }>
  );
});
const diffQuery = createQuery<{ raw: string; truncated: boolean }>(diffOptsStore);

// ── Parsed files ─────────────────────────────────────────────────────────────

const files = $derived<DiffFile[]>($diffQuery.data?.raw ? parseDiff($diffQuery.data.raw) : []);

const showTruncationBanner = $derived(
  Boolean($diffQuery.data?.truncated) ||
    Boolean($diffQuery.data?.raw && isTruncated($diffQuery.data.raw))
);

// ── UI state ─────────────────────────────────────────────────────────────────

let selectedFile = $state<DiffFile | null>(null);
let commitOpen = $state(false);

$effect(() => {
  const first = files[0] ?? null;
  if (first && !selectedFile) selectedFile = first;
  if (selectedFile && !files.find((f) => f.path === selectedFile?.path)) {
    selectedFile = files[0] ?? null;
  }
});

function handleCommitSuccess(): void {
  selectedFile = null;
  commitOpen = false;
}
</script>

<div class="dp-root">
  <!-- Toolbar: view-mode + whitespace -->
  <div class="dp-toolbar">
    <div class="dp-toolbar__group" role="group" aria-label="View mode">
      {#each (["inline", "side-by-side"] as const) as mode (mode)}
        <button
          class="dp-toggle"
          class:dp-toggle--active={opts.viewMode === mode}
          onclick={() => setViewMode(mode)}
          aria-pressed={opts.viewMode === mode}
        >
          {mode === "inline" ? "Inline" : "Side by side"}
        </button>
      {/each}
    </div>

    <button
      class="dp-toggle"
      class:dp-toggle--active={opts.ignoreWhitespace}
      onclick={toggleWhitespace}
      aria-pressed={opts.ignoreWhitespace}
      title="Ignore whitespace changes"
    >
      Whitespace
    </button>
  </div>

  {#if inSessionMode}
    {#if $statusQuery.isLoading}
      <div class="dp-state">Loading worktree…</div>
    {:else if $statusQuery.isError}
      <div class="dp-state dp-state--error">Failed to load worktree status.</div>
    {:else if !hasWorktree}
      <div class="dp-state">
        <p class="dp-state-title">No worktree</p>
        <p class="dp-state-body">
          This session has no worktree. Sessions in git-repo workspaces
          auto-create worktrees.
        </p>
      </div>
    {:else if changesCount === 0}
      <div class="dp-state">
        <p class="dp-state-title">No changes yet</p>
        <p class="dp-state-body">Edits in this terminal will appear here.</p>
      </div>
    {:else}
      {#if showTruncationBanner}
        <div class="dp-truncation-banner" role="alert">
          Diff truncated — open file in editor to view full changes.
        </div>
      {/if}

      <div class="dp-split">
        <div class="dp-list-pane">
          <FileList
            {files}
            activeFile={selectedFile}
            onSelect={(f) => {
              selectedFile = f;
            }}
            onCommit={() => {
              commitOpen = true;
            }}
          />
        </div>

        <div class="dp-viewer-pane">
          {#if $diffQuery.isLoading}
            <div class="dp-state">Loading diff…</div>
          {:else if selectedFile}
            <FileDiff file={selectedFile} {sessionId} />
          {:else}
            <div class="dp-state">Select a file to view changes.</div>
          {/if}
        </div>
      </div>
    {/if}
  {:else if inRefMode}
    <div class="dp-state">
      <p class="dp-state-title">Ref diff</p>
      <p class="dp-state-body">
        Diff between <code>{fromRef}</code> and <code>{toRef}</code>.
        Backend ref-diff endpoint not yet wired — coming soon.
      </p>
    </div>
  {:else}
    <div class="dp-state">
      <p class="dp-state-title">Diff pane</p>
      <p class="dp-state-body">
        Open this pane against a session worktree, or pass fromRef/toRef
        for a static ref diff.
      </p>
    </div>
  {/if}
</div>

{#if sessionId}
  <CommitComposer
    open={commitOpen}
    {files}
    {sessionId}
    onClose={() => {
      commitOpen = false;
    }}
    onSuccess={handleCommitSuccess}
  />
{/if}

<style>
  .dp-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
    font-family: var(--font-sans);
  }

  .dp-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-2);
    padding: var(--space-1) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    background: color-mix(in oklch, var(--fg) 3%, transparent);
  }

  .dp-toolbar__group {
    display: flex;
    gap: 2px;
  }

  .dp-toggle {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 500;
    color: var(--fg-subtle);
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 2px 8px;
    cursor: pointer;
    transition:
      color 0.1s ease,
      background 0.1s ease;
  }
  .dp-toggle--active {
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    border-color: var(--fg-subtle);
  }
  .dp-toggle:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  .dp-state {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--space-2);
    padding: var(--space-6);
    text-align: center;
    color: var(--fg-subtle);
    font-size: var(--text-xs);
  }

  .dp-state--error {
    color: var(--destructive, oklch(0.65 0.22 25));
  }

  .dp-state-title {
    margin: 0;
    font-weight: 600;
    font-size: var(--text-sm);
    color: var(--fg-muted);
  }

  .dp-state-body {
    margin: 0;
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    max-width: 260px;
    line-height: 1.5;
  }

  .dp-truncation-banner {
    padding: var(--space-2) var(--space-3);
    background: color-mix(in oklch, oklch(0.78 0.15 70) 12%, transparent);
    border-bottom: 1px solid color-mix(in oklch, oklch(0.78 0.15 70) 30%, transparent);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: oklch(0.78 0.15 70);
    flex-shrink: 0;
  }

  .dp-split {
    flex: 1;
    display: flex;
    min-height: 0;
    overflow: hidden;
  }

  .dp-list-pane {
    width: 220px;
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    border-right: 1px solid var(--border);
    overflow: hidden;
  }

  .dp-viewer-pane {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }
</style>
