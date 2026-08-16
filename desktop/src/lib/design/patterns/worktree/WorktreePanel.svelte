<script lang="ts">
/**
 * WorktreePanel — full worktree UI for the session sidebar "Worktree" tab.
 * Shows branch info, changed files, ahead/behind, and commit/push/merge/cleanup actions.
 * CSS prefix: wtp-
 * LOC target: ≤ 260.
 */
import {
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import {
  cleanupWorktreeDelete,
  commitWorktree,
  mergeWorktree,
  pushWorktree,
  type WorktreeStatus,
  worktreeDiffQuery,
  worktreeStatusQuery,
} from '$lib/api/queries/worktree.js';
import DiffViewer from '$lib/design/patterns/diff/DiffViewer.svelte';
import OpenInEditorButton from '$lib/design/primitives/OpenInEditorButton.svelte';
import { toasts } from '$lib/stores/toasts.svelte.js';
import type { DiffFile } from '$lib/utils/parse-diff.js';
import { parseDiff } from '$lib/utils/parse-diff.js';

interface Props {
  sessionId: string;
}

let { sessionId }: Props = $props();

const queryClient = useQueryClient();

// ── Status query ─────────────────────────────────────────────────────────────

const statusOptsStore = writable(
  untrack(() => worktreeStatusQuery(sessionId) as CreateQueryOptions<WorktreeStatus>)
);
$effect(() => {
  statusOptsStore.set(worktreeStatusQuery(sessionId) as CreateQueryOptions<WorktreeStatus>);
});
const statusQuery = createQuery<WorktreeStatus>(statusOptsStore);

const status = $derived($statusQuery.data ?? null);
const hasWorktree = $derived(Boolean(status?.exists));
const changesCount = $derived(status?.changesCount ?? 0);
const ahead = $derived(status?.ahead ?? 0);
const behind = $derived(status?.behind ?? 0);

// ── Diff query (enabled only when worktree exists + has changes) ──────────────

const diffOptsStore = writable(
  untrack(
    () =>
      worktreeDiffQuery(sessionId, false) as CreateQueryOptions<{
        diff: string;
        truncated: boolean;
      }>
  )
);
$effect(() => {
  diffOptsStore.set(
    worktreeDiffQuery(sessionId, hasWorktree && changesCount > 0) as CreateQueryOptions<{
      diff: string;
      truncated: boolean;
    }>
  );
});
const diffQuery = createQuery<{ diff: string; truncated: boolean }>(diffOptsStore);

const files = $derived<DiffFile[]>($diffQuery.data?.diff ? parseDiff($diffQuery.data.diff) : []);

// ── UI state ─────────────────────────────────────────────────────────────────

let selectedFile = $state<DiffFile | null>(null);
let commitOpen = $state(false);
let commitMessage = $state('');
let conflictFiles = $state<string[]>([]);

$effect(() => {
  const first = files[0] ?? null;
  if (first && !selectedFile) selectedFile = first;
  if (selectedFile && !files.find((f) => f.path === selectedFile?.path)) {
    selectedFile = files[0] ?? null;
  }
});

function invalidate(): void {
  queryClient.invalidateQueries({ queryKey: ['sessions', sessionId, 'worktree'] });
  queryClient.invalidateQueries({ queryKey: ['sessions', sessionId] });
}

// ── Mutations ─────────────────────────────────────────────────────────────────

const commitMut = createMutation({
  mutationFn: () => commitWorktree(sessionId, { message: commitMessage.trim() }),
  onSuccess: (res) => {
    if (res.ok) {
      toasts.success(`Committed${res.sha ? ` ${res.sha.slice(0, 7)}` : ''}`);
      commitMessage = '';
      commitOpen = false;
      selectedFile = null;
      invalidate();
    } else {
      toasts.error(res.error ?? 'Commit failed');
    }
  },
  onError: (err: Error) => {
    toasts.error(err.message ?? 'Commit failed');
  },
});

const pushMut = createMutation({
  mutationFn: () => pushWorktree(sessionId),
  onSuccess: (res) => {
    if (res.ok) {
      toasts.success(`Pushed${res.ref ? ` ${res.ref}` : ''}`);
      invalidate();
    } else {
      toasts.error(res.error ?? 'Push failed');
    }
  },
  onError: (err: Error) => {
    toasts.error(err.message ?? 'Push failed');
  },
});

const mergeMut = createMutation({
  mutationFn: () => mergeWorktree(sessionId),
  onSuccess: (res) => {
    if (res.ok) {
      conflictFiles = [];
      toasts.success(`Merged into ${res.baseBranch ?? 'base'}`);
      invalidate();
    } else if (res.conflictFiles?.length) {
      conflictFiles = res.conflictFiles;
      toasts.error(`Merge conflict in ${res.conflictFiles.length} file(s)`);
    } else {
      toasts.error(res.error ?? 'Merge failed');
    }
  },
  onError: (err: Error) => {
    toasts.error(err.message ?? 'Merge failed');
  },
});

const cleanupMut = createMutation({
  mutationFn: () => cleanupWorktreeDelete(sessionId),
  onSuccess: (res) => {
    if (res.ok) {
      toasts.success('Worktree removed');
      invalidate();
    }
  },
  onError: (err: Error) => {
    toasts.error(err.message ?? 'Cleanup failed');
  },
});

const anyPending = $derived(
  $commitMut.isPending || $pushMut.isPending || $mergeMut.isPending || $cleanupMut.isPending
);

function handleCommitKeydown(e: KeyboardEvent): void {
  if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
    e.preventDefault();
    void $commitMut.mutateAsync();
  }
  if (e.key === 'Escape') {
    commitOpen = false;
    commitMessage = '';
  }
}
</script>

<div class="wtp-root">
  {#if $statusQuery.isLoading}
    <div class="wtp-state">Loading worktree…</div>
  {:else if $statusQuery.isError}
    <div class="wtp-state wtp-state--error">Failed to load worktree status.</div>
  {:else if !hasWorktree}
    <div class="wtp-state">
      <p class="wtp-state-title">No worktree</p>
      <p class="wtp-state-body">Sessions in git-repo workspaces auto-create a worktree branch.</p>
    </div>
  {:else}
    <!-- ── Branch info header ─────────────────────────────────────────────── -->
    <div class="wtp-header">
      <div class="wtp-branch-row">
        <span class="wtp-label">Branch</span>
        <span class="wtp-chip wtp-mono">{status?.branch ?? '—'}</span>
        <button
          class="wtp-copy-btn"
          onclick={() => status?.branch && navigator.clipboard.writeText(status.branch)}
          aria-label="Copy branch name"
          title="Copy branch name"
        >⎘</button>
      </div>
      <div class="wtp-meta-row">
        <span class="wtp-meta-item wtp-mono">from <span class="wtp-base">{status?.baseBranch ?? '—'}</span></span>
        {#if ahead > 0 || behind > 0}
          <span class="wtp-meta-sep" aria-hidden="true">·</span>
          {#if ahead > 0}<span class="wtp-ahead wtp-mono">↑{ahead}</span>{/if}
          {#if behind > 0}<span class="wtp-behind wtp-mono">↓{behind}</span>{/if}
        {/if}
      </div>
      {#if status?.path}
        <div class="wtp-path-row">
          <span class="wtp-path wtp-mono">{status.path}</span>
          <button
            class="wtp-copy-btn"
            onclick={() => status?.path && navigator.clipboard.writeText(status.path)}
            aria-label="Copy worktree path"
            title="Copy worktree path"
          >⎘</button>
          <OpenInEditorButton path={status.path} />
        </div>
      {/if}
    </div>

    <!-- ── Status summary ─────────────────────────────────────────────────── -->
    <div class="wtp-summary">
      <span class="wtp-summary-text">
        {changesCount === 0 ? 'No changes' : `${changesCount} changed file${changesCount === 1 ? '' : 's'}`}
        {ahead > 0 ? `, ${ahead} ahead of ${status?.baseBranch ?? 'base'}` : ''}
      </span>
    </div>

    <!-- ── File list + diff split ─────────────────────────────────────────── -->
    {#if changesCount > 0 && files.length > 0}
      <div class="wtp-split">
        <div class="wtp-file-list">
          {#each files as file (file.path)}
            {@const isActive = selectedFile?.path === file.path}
            <button
              class="wtp-file-row"
              class:wtp-file-row--active={isActive}
              onclick={() => { selectedFile = file; }}
              title={file.path}
              aria-pressed={isActive}
            >
              <span class="wtp-file-status wtp-file-status--{file.status}" aria-hidden="true">
                {file.status === 'added' ? 'A' : file.status === 'deleted' ? 'D' : file.status === 'renamed' ? 'R' : 'M'}
              </span>
              <span class="wtp-file-path">{file.path}</span>
              {#if !file.binary}
                <span class="wtp-counts">
                  {#if file.additions > 0}<span class="wtp-add">+{file.additions}</span>{/if}
                  {#if file.deletions > 0}<span class="wtp-del">−{file.deletions}</span>{/if}
                </span>
              {/if}
            </button>
          {/each}
        </div>
        <div class="wtp-diff-pane">
          {#if $diffQuery.isLoading}
            <div class="wtp-state">Loading diff…</div>
          {:else if selectedFile}
            <DiffViewer file={selectedFile} />
          {:else}
            <div class="wtp-state">Select a file.</div>
          {/if}
        </div>
      </div>
    {/if}

    <!-- ── Conflict file list ──────────────────────────────────────────────── -->
    {#if conflictFiles.length > 0}
      <div class="wtp-conflict-banner" role="alert">
        Merge conflict — resolve in editor, then commit:
        {#each conflictFiles as f (f)}
          <span class="wtp-conflict-file wtp-mono">{f}</span>
        {/each}
      </div>
    {/if}

    <!-- ── Actions ────────────────────────────────────────────────────────── -->
    <div class="wtp-actions">
      <button
        class="wtp-btn wtp-btn--primary"
        onclick={() => { commitOpen = !commitOpen; }}
        disabled={changesCount === 0 || anyPending}
        aria-label="Open commit panel"
      >Commit…</button>
      <button
        class="wtp-btn"
        onclick={() => void $pushMut.mutateAsync()}
        disabled={ahead === 0 || anyPending}
        aria-label="Push to remote"
      >{$pushMut.isPending ? 'Pushing…' : 'Push'}</button>
      <button
        class="wtp-btn"
        onclick={() => { conflictFiles = []; void $mergeMut.mutateAsync(); }}
        disabled={anyPending}
        aria-label="Merge session branch into base"
      >{$mergeMut.isPending ? 'Merging…' : `Merge → ${status?.baseBranch ?? 'base'}`}</button>
      <button
        class="wtp-btn wtp-btn--danger"
        onclick={() => void $cleanupMut.mutateAsync()}
        disabled={anyPending}
        aria-label="Remove worktree from disk"
      >{$cleanupMut.isPending ? 'Removing…' : 'Cleanup'}</button>
    </div>

    <!-- ── Inline commit form ─────────────────────────────────────────────── -->
    {#if commitOpen}
      <div class="wtp-commit-form" role="form" aria-label="Commit changes">
        <textarea
          class="wtp-commit-input"
          rows={3}
          bind:value={commitMessage}
          placeholder="feat: describe the change  (Cmd+Enter to commit)"
          aria-label="Commit message"
          disabled={$commitMut.isPending}
          onkeydown={handleCommitKeydown}
        ></textarea>
        <div class="wtp-commit-footer">
          <button class="wtp-btn" onclick={() => { commitOpen = false; commitMessage = ''; }}>Cancel</button>
          <button
            class="wtp-btn wtp-btn--primary"
            onclick={() => void $commitMut.mutateAsync()}
            disabled={!commitMessage.trim() || $commitMut.isPending}
          >{$commitMut.isPending ? 'Committing…' : 'Commit all'}</button>
        </div>
      </div>
    {/if}
  {/if}
</div>

<style>
  .wtp-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
    font-family: var(--font-sans);
  }

  .wtp-mono { font-family: var(--font-mono); }

  .wtp-state {
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
  .wtp-state--error { color: var(--destructive, oklch(0.65 0.22 25)); }
  .wtp-state-title { margin: 0; font-weight: 600; font-size: var(--text-sm); color: var(--fg-muted); }
  .wtp-state-body { margin: 0; font-size: var(--text-xs); color: var(--fg-subtle); max-width: 220px; line-height: 1.5; }

  /* Header */
  .wtp-header {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
    padding: var(--space-3) var(--space-4);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .wtp-branch-row, .wtp-meta-row, .wtp-path-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    min-width: 0;
    flex-wrap: wrap;
  }

  .wtp-label {
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    flex-shrink: 0;
  }

  .wtp-chip {
    font-size: var(--text-xs);
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 1px 6px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 160px;
  }

  .wtp-meta-item { font-size: var(--text-xs); color: var(--fg-subtle); }
  .wtp-meta-sep { color: var(--fg-subtle); }
  .wtp-base { color: var(--fg-muted); }
  .wtp-ahead { font-size: var(--text-xs); color: oklch(0.72 0.18 145); }
  .wtp-behind { font-size: var(--text-xs); color: oklch(0.78 0.15 70); }

  .wtp-path {
    font-size: 10px;
    color: var(--fg-subtle);
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .wtp-copy-btn {
    flex-shrink: 0;
    padding: 0 4px;
    background: none;
    border: none;
    cursor: pointer;
    color: var(--fg-subtle);
    font-size: var(--text-xs);
    line-height: 1;
    border-radius: 3px;
    transition: color 0.12s ease;
  }
  .wtp-copy-btn:hover { color: var(--fg); }

  /* Summary */
  .wtp-summary {
    padding: var(--space-2) var(--space-4);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }
  .wtp-summary-text { font-size: var(--text-xs); color: var(--fg-subtle); }

  /* File list + diff split */
  .wtp-split {
    flex: 1;
    display: flex;
    min-height: 0;
    overflow: hidden;
  }

  .wtp-file-list {
    width: 180px;
    flex-shrink: 0;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
    border-right: 1px solid var(--border);
    display: flex;
    flex-direction: column;
  }

  .wtp-file-row {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    width: 100%;
    padding: var(--space-1) var(--space-2);
    background: transparent;
    border: none;
    border-left: 2px solid transparent;
    cursor: pointer;
    text-align: left;
    min-width: 0;
    transition: background 0.1s ease, border-color 0.1s ease;
  }
  .wtp-file-row:hover:not(.wtp-file-row--active) {
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }
  .wtp-file-row--active {
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.78 0.18 145)) 8%, transparent);
    border-left-color: var(--cnp-accent, oklch(0.78 0.18 145));
  }

  .wtp-file-status {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    font-weight: 700;
    flex-shrink: 0;
    width: 12px;
    text-align: center;
  }
  .wtp-file-status--added { color: var(--success, oklch(0.72 0.18 145)); }
  .wtp-file-status--deleted { color: var(--destructive, oklch(0.65 0.22 25)); }
  .wtp-file-status--modified, .wtp-file-status--renamed { color: var(--cnp-accent, oklch(0.78 0.18 145)); }

  .wtp-file-path {
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

  .wtp-counts { display: flex; gap: 3px; flex-shrink: 0; }
  .wtp-add { font-family: var(--font-mono); font-size: 10px; color: var(--success, oklch(0.72 0.18 145)); }
  .wtp-del { font-family: var(--font-mono); font-size: 10px; color: var(--destructive, oklch(0.65 0.22 25)); }

  .wtp-diff-pane {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  /* Conflict banner */
  .wtp-conflict-banner {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: var(--space-2) var(--space-4);
    background: color-mix(in oklch, var(--destructive, oklch(0.65 0.22 25)) 10%, transparent);
    border-top: 1px solid color-mix(in oklch, var(--destructive, oklch(0.65 0.22 25)) 30%, transparent);
    font-size: var(--text-xs);
    color: var(--destructive, oklch(0.65 0.22 25));
    flex-shrink: 0;
  }
  .wtp-conflict-file { font-size: 10px; color: var(--fg-muted); }

  /* Actions */
  .wtp-actions {
    display: flex;
    gap: var(--space-2);
    flex-wrap: wrap;
    padding: var(--space-3) var(--space-4);
    border-top: 1px solid var(--border);
    flex-shrink: 0;
  }

  .wtp-btn {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 3px 10px;
    cursor: pointer;
    white-space: nowrap;
    transition: background 0.1s ease, color 0.1s ease, border-color 0.1s ease;
  }
  .wtp-btn:hover:not(:disabled) { color: var(--fg); border-color: var(--fg-subtle); }
  .wtp-btn:disabled { opacity: 0.35; cursor: not-allowed; }
  .wtp-btn--primary { color: var(--bg); background: var(--fg); border-color: transparent; }
  .wtp-btn--primary:hover:not(:disabled) { opacity: 0.85; color: var(--bg); }
  .wtp-btn--danger { color: var(--destructive, oklch(0.65 0.22 25)); border-color: color-mix(in oklch, var(--destructive, oklch(0.65 0.22 25)) 35%, transparent); }
  .wtp-btn--danger:hover:not(:disabled) { background: color-mix(in oklch, var(--destructive, oklch(0.65 0.22 25)) 10%, transparent); color: var(--destructive, oklch(0.65 0.22 25)); }
  .wtp-btn:focus-visible { outline: 2px solid var(--cnp-accent); outline-offset: 2px; }

  /* Commit form */
  .wtp-commit-form {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-3) var(--space-4);
    border-top: 1px solid var(--border);
    flex-shrink: 0;
    background: color-mix(in oklch, var(--bg-inset) 50%, transparent);
  }

  .wtp-commit-input {
    width: 100%;
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    resize: none;
    outline: none;
    box-sizing: border-box;
    transition: border-color 0.1s ease;
  }
  .wtp-commit-input:focus { border-color: var(--cnp-accent, oklch(0.78 0.18 145)); }
  .wtp-commit-input:disabled { opacity: 0.5; }
  .wtp-commit-input::placeholder { color: var(--fg-subtle); }

  .wtp-commit-footer {
    display: flex;
    justify-content: flex-end;
    gap: var(--space-2);
  }
</style>
