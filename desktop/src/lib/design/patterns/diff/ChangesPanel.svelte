<script lang="ts">
  /**
   * ChangesPanel — composes ChangesFileList + DiffViewer for a session worktree.
   * CSS prefix: chp-
   * LOC target: ≤ 180.
   */
  import { type CreateQueryOptions, createQuery, useQueryClient } from '@tanstack/svelte-query';
  import { untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import { worktreeDiffQuery, worktreeStatusQuery } from '$lib/api/queries/sessions.js';
  import { isTruncated, parseDiff } from '$lib/utils/parse-diff.js';
  import type { DiffFile } from '$lib/utils/parse-diff.js';
  import type { WorktreeStatus } from '$lib/api/queries/sessions.js';
  import { toasts } from '$lib/stores/toasts.svelte.js';
  import ChangesFileList from './ChangesFileList.svelte';
  import CommitModal from './CommitModal.svelte';
  import DiffViewer from './DiffViewer.svelte';

  interface Props {
    sessionId: string;
  }

  let { sessionId }: Props = $props();

  const queryClient = useQueryClient();

  // ── Worktree status ───────────────────────────────────────────────────────────

  const statusOptsStore = writable(
    untrack(() => worktreeStatusQuery(sessionId) as CreateQueryOptions<WorktreeStatus>),
  );
  $effect(() => {
    statusOptsStore.set(worktreeStatusQuery(sessionId) as CreateQueryOptions<WorktreeStatus>);
  });
  const statusQuery = createQuery<WorktreeStatus>(statusOptsStore);

  const hasWorktree = $derived(Boolean($statusQuery.data?.path));
  const changesCount = $derived($statusQuery.data?.changesCount ?? 0);

  // ── Diff fetch ────────────────────────────────────────────────────────────────

  const diffOptsStore = writable(
    untrack(
      () =>
        worktreeDiffQuery(sessionId, false) as CreateQueryOptions<{
          raw: string;
          truncated: boolean;
        }>,
    ),
  );
  $effect(() => {
    diffOptsStore.set(
      worktreeDiffQuery(sessionId, hasWorktree && changesCount > 0) as CreateQueryOptions<{
        raw: string;
        truncated: boolean;
      }>,
    );
  });
  const diffQuery = createQuery<{ raw: string; truncated: boolean }>(diffOptsStore);

  // ── Parsed files ──────────────────────────────────────────────────────────────

  const files = $derived<DiffFile[]>(
    $diffQuery.data?.raw ? parseDiff($diffQuery.data.raw) : [],
  );

  const showTruncationBanner = $derived(
    Boolean($diffQuery.data?.truncated) ||
      Boolean($diffQuery.data?.raw && isTruncated($diffQuery.data.raw)),
  );

  // ── UI state ──────────────────────────────────────────────────────────────────

  let selectedFile = $state<DiffFile | null>(null);
  let commitOpen = $state(false);

  // Auto-select first file when list loads
  $effect(() => {
    const first = files[0] ?? null;
    if (first && !selectedFile) selectedFile = first;
    // If selected file is no longer in list, clear it
    if (selectedFile && !files.find((f) => f.path === selectedFile?.path)) {
      selectedFile = files[0] ?? null;
    }
  });

  function handleCommitSuccess(): void {
    toasts.success('Committed successfully');
    queryClient.invalidateQueries({ queryKey: ['sessions', sessionId, 'worktree'] });
    queryClient.invalidateQueries({ queryKey: ['sessions', sessionId, 'worktree', 'diff'] });
    selectedFile = null;
  }
</script>

<div class="chp-root">
  {#if $statusQuery.isLoading}
    <div class="chp-state">Loading worktree…</div>
  {:else if $statusQuery.isError}
    <div class="chp-state chp-state--error">Failed to load worktree status.</div>
  {:else if !hasWorktree}
    <div class="chp-state">
      <p class="chp-state-title">No worktree</p>
      <p class="chp-state-body">
        This session has no worktree. Sessions in git-repo workspaces auto-create worktrees.
      </p>
    </div>
  {:else if changesCount === 0}
    <div class="chp-state">
      <p class="chp-state-title">No changes yet</p>
      <p class="chp-state-body">Edits in this terminal will appear here.</p>
    </div>
  {:else}
    <!-- Truncation banner -->
    {#if showTruncationBanner}
      <div class="chp-truncation-banner" role="alert">
        Diff truncated — open file in editor to view full changes.
      </div>
    {/if}

    <!-- Split layout: file list (left) + diff viewer (right) -->
    <div class="chp-split">
      <div class="chp-file-list-pane">
        <ChangesFileList
          {files}
          activeFile={selectedFile}
          onSelect={(f) => { selectedFile = f; }}
          onCommit={() => { commitOpen = true; }}
        />
      </div>

      <div class="chp-viewer-pane">
        {#if $diffQuery.isLoading}
          <div class="chp-state">Loading diff…</div>
        {:else if selectedFile}
          <DiffViewer file={selectedFile} />
        {:else}
          <div class="chp-state">Select a file to view changes.</div>
        {/if}
      </div>
    </div>
  {/if}
</div>

<CommitModal
  open={commitOpen}
  {files}
  {sessionId}
  onClose={() => { commitOpen = false; }}
  onSuccess={handleCommitSuccess}
/>

<style>
  .chp-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
    font-family: var(--font-sans);
  }

  .chp-state {
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

  .chp-state--error { color: var(--destructive, oklch(0.65 0.22 25)); }

  .chp-state-title {
    margin: 0;
    font-weight: 600;
    font-size: var(--text-sm);
    color: var(--fg-muted);
  }

  .chp-state-body {
    margin: 0;
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    max-width: 220px;
    line-height: 1.5;
  }

  .chp-truncation-banner {
    padding: var(--space-2) var(--space-3);
    background: color-mix(in oklch, oklch(0.78 0.15 70) 12%, transparent);
    border-bottom: 1px solid color-mix(in oklch, oklch(0.78 0.15 70) 30%, transparent);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: oklch(0.78 0.15 70);
    flex-shrink: 0;
  }

  .chp-split {
    flex: 1;
    display: flex;
    min-height: 0;
    overflow: hidden;
  }

  .chp-file-list-pane {
    width: 220px;
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    border-right: 1px solid var(--border);
    overflow: hidden;
  }

  .chp-viewer-pane {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }
</style>
