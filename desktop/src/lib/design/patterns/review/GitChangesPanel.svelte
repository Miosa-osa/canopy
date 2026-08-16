<script lang="ts">
  /**
   * GitChangesPanel — workspace-level git status panel.
   * Shows staged/unstaged files with inline diff expansion, stage/unstage,
   * commit message input, and push. Backed by session worktree endpoints.
   * CSS prefix: gcp-
   * LOC target: ≤ 300.
   */
  import {
    type CreateQueryOptions,
    createQuery,
    useQueryClient,
  } from '@tanstack/svelte-query';
  import { writable } from 'svelte/store';
  import { untrack } from 'svelte';
  import {
    GitBranch,
    Plus,
    Minus,
    RefreshCw,
    GitCommitHorizontal,
    Upload,
    ChevronDown,
    ChevronRight,
    FileText,
  } from 'lucide-svelte';
  import {
    worktreeStatusQuery,
    worktreeDiffQuery,
    sessionsQuery,
    type WorktreeStatus,
  } from '$lib/api/queries/sessions.js';
  import { apiPost } from '$lib/api/client.js';
  import { parseDiff, type DiffFile } from '$lib/utils/parse-diff.js';
  import { toasts } from '$lib/stores/toasts.svelte.js';
  import type { Session } from '$lib/domain/sessions/types.js';

  // ── Find first session with a worktree ────────────────────────────────────────

  const allSessionsQuery = createQuery(
    sessionsQuery({ limit: 20 }) as CreateQueryOptions<Session[]>,
  );

  const sessionId = $derived(
    ($allSessionsQuery.data ?? []).find(
      (s) => Boolean((s as Session & { worktreePath?: string }).worktreePath),
    )?.id ?? '',
  );

  // ── Worktree status + diff ────────────────────────────────────────────────────

  const queryClient = useQueryClient();

  const statusOptsStore = writable(
    untrack(() => worktreeStatusQuery(sessionId) as CreateQueryOptions<WorktreeStatus>),
  );
  $effect(() => {
    statusOptsStore.set(worktreeStatusQuery(sessionId) as CreateQueryOptions<WorktreeStatus>);
  });
  const statusQuery = createQuery<WorktreeStatus>(statusOptsStore);

  const hasWorktree = $derived(Boolean($statusQuery.data?.path));
  const branch = $derived($statusQuery.data?.branch ?? 'unknown');
  const changesCount = $derived($statusQuery.data?.changesCount ?? 0);

  const diffOptsStore = writable(
    untrack(() => worktreeDiffQuery(sessionId, false) as CreateQueryOptions<{ raw: string; truncated: boolean }>),
  );
  $effect(() => {
    diffOptsStore.set(
      worktreeDiffQuery(sessionId, hasWorktree && changesCount > 0) as CreateQueryOptions<{ raw: string; truncated: boolean }>,
    );
  });
  const diffQuery = createQuery<{ raw: string; truncated: boolean }>(diffOptsStore);
  const files = $derived<DiffFile[]>($diffQuery.data?.raw ? parseDiff($diffQuery.data.raw) : []);

  // ── Staged state (client-side) ────────────────────────────────────────────────

  let stagedPaths = $state<Set<string>>(new Set());
  $effect(() => { stagedPaths = new Set(files.map((f) => f.path)); });

  const stagedFiles = $derived(files.filter((f) => stagedPaths.has(f.path)));
  const unstagedFiles = $derived(files.filter((f) => !stagedPaths.has(f.path)));

  function stageFile(path: string): void { stagedPaths = new Set([...stagedPaths, path]); }
  function unstageFile(path: string): void { const n = new Set(stagedPaths); n.delete(path); stagedPaths = n; }
  function stageAll(): void { stagedPaths = new Set(files.map((f) => f.path)); }
  function unstageAll(): void { stagedPaths = new Set(); }

  // ── Expanded diffs ────────────────────────────────────────────────────────────

  let expandedPaths = $state<Set<string>>(new Set());
  function toggleExpand(path: string): void {
    const n = new Set(expandedPaths);
    if (n.has(path)) n.delete(path); else n.add(path);
    expandedPaths = n;
  }

  // ── Commit + push ─────────────────────────────────────────────────────────────

  let commitMsg = $state('');
  let isCommitting = $state(false);
  let isPushing = $state(false);

  async function handleCommit(): Promise<void> {
    if (!commitMsg.trim() || !sessionId) return;
    isCommitting = true;
    try {
      await apiPost(`/sessions/${sessionId}/worktree/commit`, {
        message: commitMsg.trim(),
        files: stagedPaths.size > 0 ? [...stagedPaths] : undefined,
      });
      toasts.success('Committed successfully');
      commitMsg = '';
      stagedPaths = new Set();
      void queryClient.invalidateQueries({ queryKey: ['sessions', sessionId, 'worktree'] });
    } catch (err) {
      toasts.error(`Commit failed: ${err instanceof Error ? err.message : 'unknown error'}`);
    } finally { isCommitting = false; }
  }

  async function handlePush(): Promise<void> {
    if (!sessionId) return;
    isPushing = true;
    try {
      await apiPost(`/sessions/${sessionId}/worktree/push`, { remote: 'origin' });
      toasts.success('Pushed to origin');
    } catch (err) {
      toasts.error(`Push failed: ${err instanceof Error ? err.message : 'unknown error'}`);
    } finally { isPushing = false; }
  }

  function refresh(): void {
    void queryClient.invalidateQueries({ queryKey: ['sessions', sessionId, 'worktree'] });
  }

  $effect(() => {
    if (!sessionId) return;
    const timer = setInterval(refresh, 10_000);
    return () => clearInterval(timer);
  });

  // ── Helpers ───────────────────────────────────────────────────────────────────

  function statusLabel(s: DiffFile['status']): string {
    return s === 'added' ? 'A' : s === 'deleted' ? 'D' : s === 'renamed' ? 'R' : 'M';
  }
  function statusColor(s: DiffFile['status']): string {
    return s === 'added' ? 'var(--success, oklch(0.72 0.18 145))'
      : s === 'deleted' ? 'var(--destructive, oklch(0.65 0.22 25))'
      : s === 'renamed' ? 'oklch(0.72 0.18 250)'
      : 'oklch(0.72 0.18 70)';
  }
</script>

{#snippet fileRow(file: DiffFile, staged: boolean)}
  {@const expanded = expandedPaths.has(file.path)}
  <div class="gcp-file-row" class:gcp-file-row--expanded={expanded}>
    <button
      class="gcp-file-toggle"
      onclick={() => toggleExpand(file.path)}
      aria-expanded={expanded}
      aria-label="{expanded ? 'Collapse' : 'Expand'} {file.path}"
    >
      {#if expanded}<ChevronDown size={12} aria-hidden="true" />{:else}<ChevronRight size={12} aria-hidden="true" />{/if}
    </button>
    <FileText size={13} aria-hidden="true" class="gcp-file-icon" />
    <span class="gcp-file-path" title={file.path}>{file.path}</span>
    {#if !staged}
      <span class="gcp-status-badge" style:color={statusColor(file.status)} title={file.status}>{statusLabel(file.status)}</span>
    {/if}
    <span class="gcp-diff-stat">
      <span class="gcp-add">+{file.additions}</span>
      <span class="gcp-del">-{file.deletions}</span>
    </span>
    {#if staged}
      <button class="gcp-action-btn gcp-action-btn--unstage" onclick={() => unstageFile(file.path)} aria-label="Unstage {file.path}" title="Unstage">
        <Minus size={11} aria-hidden="true" />
      </button>
    {:else}
      <button class="gcp-action-btn gcp-action-btn--stage" onclick={() => stageFile(file.path)} aria-label="Stage {file.path}" title="Stage">
        <Plus size={11} aria-hidden="true" />
      </button>
    {/if}
  </div>
  {#if expanded}
    <div class="gcp-inline-diff" role="region" aria-label="Diff for {file.path}">
      {#if file.binary}
        <p class="gcp-binary-note">Binary file</p>
      {:else}
        {#each file.hunks as hunk (hunk.header)}
          <div class="gcp-hunk-header">{hunk.header}</div>
          {#each hunk.lines as dl (dl)}
            {#if dl.type !== 'hunk_header'}
              <div class="gcp-diff-line" class:gcp-diff-line--add={dl.type === 'add'} class:gcp-diff-line--del={dl.type === 'del'}
              ><span class="gcp-diff-sign">{dl.type === 'add' ? '+' : dl.type === 'del' ? '−' : ' '}</span>{dl.content}</div>
            {/if}
          {/each}
        {/each}
      {/if}
    </div>
  {/if}
{/snippet}

<div class="gcp-root">
  <header class="gcp-header">
    <GitBranch size={14} aria-hidden="true" class="gcp-header-icon" />
    <h2 class="gcp-title">Changes</h2>
    {#if hasWorktree}
      <span class="gcp-branch-badge">{branch}</span>
    {/if}
    <span class="gcp-spacer"></span>
    <button class="gcp-icon-btn" onclick={refresh} aria-label="Refresh" disabled={$statusQuery.isFetching}>
      <RefreshCw size={13} aria-hidden="true" />
    </button>
  </header>

  {#if $allSessionsQuery.isLoading || $statusQuery.isLoading}
    <div class="gcp-state"><p class="gcp-state-title">Loading…</p></div>
  {:else if !sessionId || !hasWorktree}
    <div class="gcp-state">
      <GitBranch size={24} aria-hidden="true" class="gcp-empty-icon" />
      <p class="gcp-state-title">No active worktree</p>
      <p class="gcp-state-body">Start a terminal in a git repo to track changes here.</p>
    </div>
  {:else if changesCount === 0}
    <div class="gcp-state">
      <GitCommitHorizontal size={24} aria-hidden="true" class="gcp-empty-icon" />
      <p class="gcp-state-title">Working tree clean</p>
      <p class="gcp-state-body">No modifications in this session's worktree.</p>
    </div>
  {:else}
    <div class="gcp-scroll">
      <section class="gcp-section">
        <div class="gcp-section-header">
          <span class="gcp-section-label">Staged</span>
          <span class="gcp-section-count">{stagedFiles.length}</span>
          <button class="gcp-text-btn" onclick={unstageAll} disabled={stagedFiles.length === 0}>Unstage all</button>
        </div>
        {#if stagedFiles.length === 0}
          <p class="gcp-section-empty">No staged files</p>
        {:else}
          {#each stagedFiles as file (file.path)}{@render fileRow(file, true)}{/each}
        {/if}
      </section>

      <section class="gcp-section">
        <div class="gcp-section-header">
          <span class="gcp-section-label">Unstaged</span>
          <span class="gcp-section-count">{unstagedFiles.length}</span>
          <button class="gcp-text-btn" onclick={stageAll} disabled={unstagedFiles.length === 0}>Stage all</button>
        </div>
        {#if unstagedFiles.length === 0}
          <p class="gcp-section-empty">No unstaged files</p>
        {:else}
          {#each unstagedFiles as file (file.path)}{@render fileRow(file, false)}{/each}
        {/if}
      </section>
    </div>

    <div class="gcp-actions">
      <textarea class="gcp-commit-input" placeholder="Commit message…" rows={2} bind:value={commitMsg} aria-label="Commit message"></textarea>
      <div class="gcp-actions-row">
        <button class="gcp-btn gcp-btn--primary" onclick={handleCommit} disabled={!commitMsg.trim() || isCommitting || stagedFiles.length === 0} aria-label="Commit staged changes">
          <GitCommitHorizontal size={13} aria-hidden="true" />
          {isCommitting ? 'Committing…' : 'Commit'}
        </button>
        <button class="gcp-btn gcp-btn--ghost" onclick={handlePush} disabled={isPushing} aria-label="Push to remote">
          <Upload size={13} aria-hidden="true" />
          {isPushing ? 'Pushing…' : 'Push'}
        </button>
      </div>
    </div>
  {/if}
</div>

<style>
  .gcp-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
    font-family: var(--font-sans);
    background: var(--bg);
  }

  .gcp-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-4) var(--space-5) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }
  :global(.gcp-header-icon) { color: var(--fg-muted); }
  .gcp-title { margin: 0; font-size: var(--text-sm); font-weight: 600; color: var(--fg); letter-spacing: -0.01em; }
  .gcp-branch-badge {
    padding: 1px 6px; border-radius: 9999px; border: 1px solid var(--border);
    font-family: var(--font-mono); font-size: 10px; color: var(--fg-muted); background: var(--bg-inset);
    max-width: 120px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  }
  .gcp-spacer { flex: 1; }
  .gcp-icon-btn {
    display: flex; align-items: center; justify-content: center;
    width: 24px; height: 24px; border-radius: var(--radius-sm); border: none;
    background: transparent; cursor: pointer; color: var(--fg-muted);
    transition: color 0.1s ease, background 0.1s ease;
  }
  .gcp-icon-btn:hover { color: var(--fg); background: var(--bg-inset); }
  .gcp-icon-btn:disabled { opacity: 0.4; cursor: not-allowed; }
  .gcp-icon-btn:focus-visible { outline: 2px solid var(--cnp-accent, oklch(0.65 0.18 250)); outline-offset: 1px; }

  .gcp-state {
    flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center;
    gap: var(--space-2); padding: var(--space-6); text-align: center;
  }
  :global(.gcp-empty-icon) { color: var(--fg-subtle); margin-bottom: var(--space-1); }
  .gcp-state-title { margin: 0; font-size: var(--text-sm); font-weight: 600; color: var(--fg-muted); }
  .gcp-state-body { margin: 0; font-size: var(--text-xs); color: var(--fg-subtle); max-width: 220px; line-height: 1.5; }

  .gcp-scroll { flex: 1; overflow-y: auto; overflow-x: hidden; scrollbar-width: thin; scrollbar-color: var(--border) transparent; }

  .gcp-section { padding: var(--space-2) 0; border-bottom: 1px solid var(--border); }
  .gcp-section-header { display: flex; align-items: center; gap: var(--space-2); padding: var(--space-1) var(--space-5); margin-bottom: var(--space-1); }
  .gcp-section-label { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.06em; color: var(--fg-subtle); }
  .gcp-section-count {
    font-family: var(--font-mono); font-size: 10px; color: var(--fg-subtle);
    background: var(--bg-inset); border: 1px solid var(--border); padding: 0 4px; border-radius: var(--radius-sm);
  }
  .gcp-text-btn {
    margin-left: auto; font-family: var(--font-sans); font-size: 10px; font-weight: 500;
    color: var(--fg-muted); background: transparent; border: none; cursor: pointer;
    padding: 2px 6px; border-radius: var(--radius-sm); transition: color 0.1s ease, background 0.1s ease;
  }
  .gcp-text-btn:hover:not(:disabled) { color: var(--fg); background: var(--bg-inset); }
  .gcp-text-btn:disabled { opacity: 0.35; cursor: not-allowed; }
  .gcp-section-empty { margin: 0; padding: var(--space-2) var(--space-5); font-size: var(--text-xs); color: var(--fg-subtle); font-style: italic; }

  .gcp-file-row {
    display: flex; align-items: center; gap: var(--space-2);
    padding: 3px var(--space-5) 3px var(--space-3); transition: background 0.1s ease;
  }
  .gcp-file-row:hover { background: var(--bg-inset); }
  .gcp-file-row--expanded { background: color-mix(in oklch, var(--fg) 3%, transparent); }

  .gcp-file-toggle {
    display: flex; align-items: center; justify-content: center;
    width: 16px; height: 16px; border: none; background: transparent;
    cursor: pointer; color: var(--fg-subtle); flex-shrink: 0; border-radius: 2px; transition: color 0.1s ease;
  }
  .gcp-file-toggle:hover { color: var(--fg); }
  .gcp-file-toggle:focus-visible { outline: 2px solid var(--cnp-accent, oklch(0.65 0.18 250)); }
  :global(.gcp-file-icon) { color: var(--fg-subtle); flex-shrink: 0; }
  .gcp-file-path {
    flex: 1; min-width: 0; font-family: var(--font-mono); font-size: var(--text-xs);
    color: var(--fg); white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  }
  .gcp-status-badge { font-family: var(--font-mono); font-size: 10px; font-weight: 700; flex-shrink: 0; width: 14px; text-align: center; }
  .gcp-diff-stat { display: flex; gap: 4px; font-family: var(--font-mono); font-size: 10px; flex-shrink: 0; }
  .gcp-add { color: var(--success, oklch(0.72 0.18 145)); }
  .gcp-del { color: var(--destructive, oklch(0.65 0.22 25)); }

  .gcp-action-btn {
    display: flex; align-items: center; justify-content: center;
    width: 20px; height: 20px; border-radius: var(--radius-sm); border: 1px solid var(--border);
    background: transparent; cursor: pointer; flex-shrink: 0;
    transition: color 0.1s ease, background 0.1s ease, border-color 0.1s ease;
  }
  .gcp-action-btn--stage { color: var(--success, oklch(0.72 0.18 145)); }
  .gcp-action-btn--stage:hover { background: color-mix(in oklch, var(--success, oklch(0.72 0.18 145)) 15%, transparent); border-color: var(--success, oklch(0.72 0.18 145)); }
  .gcp-action-btn--unstage { color: oklch(0.72 0.18 70); }
  .gcp-action-btn--unstage:hover { background: color-mix(in oklch, oklch(0.72 0.18 70) 15%, transparent); border-color: oklch(0.72 0.18 70); }
  .gcp-action-btn:focus-visible { outline: 2px solid var(--cnp-accent, oklch(0.65 0.18 250)); outline-offset: 1px; }

  .gcp-inline-diff {
    border-top: 1px solid var(--border);
    border-bottom: 1px solid color-mix(in oklch, var(--border) 40%, transparent);
    overflow-x: auto; background: color-mix(in oklch, var(--bg) 60%, var(--bg-inset) 40%);
    scrollbar-width: thin; scrollbar-color: var(--border) transparent;
  }
  .gcp-hunk-header {
    padding: 2px var(--space-3); font-family: var(--font-mono); font-size: 10px;
    color: var(--fg-subtle); background: color-mix(in oklch, var(--fg) 5%, transparent);
    border-top: 1px solid var(--border); white-space: pre;
  }
  .gcp-diff-line { display: flex; font-family: var(--font-mono); font-size: var(--text-xs); line-height: 1.5; white-space: pre; color: var(--fg); padding: 0 var(--space-3); }
  .gcp-diff-line--add { background: color-mix(in oklch, var(--success, oklch(0.72 0.18 145)) 12%, transparent); }
  .gcp-diff-line--del { background: color-mix(in oklch, var(--destructive, oklch(0.65 0.22 25)) 12%, transparent); }
  .gcp-diff-sign { width: 16px; flex-shrink: 0; user-select: none; color: var(--fg-subtle); }
  .gcp-diff-line--add .gcp-diff-sign { color: var(--success, oklch(0.72 0.18 145)); }
  .gcp-diff-line--del .gcp-diff-sign { color: var(--destructive, oklch(0.65 0.22 25)); }
  .gcp-binary-note { margin: 0; padding: var(--space-3); font-size: var(--text-xs); color: var(--fg-subtle); font-style: italic; }

  .gcp-actions {
    flex-shrink: 0; padding: var(--space-3) var(--space-5); border-top: 1px solid var(--border);
    display: flex; flex-direction: column; gap: var(--space-2); background: var(--bg);
  }
  .gcp-commit-input {
    width: 100%; resize: none; font-family: var(--font-sans); font-size: var(--text-xs);
    color: var(--fg); background: var(--bg-inset); border: 1px solid var(--border);
    border-radius: var(--radius-md); padding: var(--space-2) var(--space-3);
    outline: none; transition: border-color 0.1s ease; line-height: 1.5; box-sizing: border-box;
  }
  .gcp-commit-input::placeholder { color: var(--fg-subtle); }
  .gcp-commit-input:focus { border-color: var(--fg-muted); }
  .gcp-actions-row { display: flex; gap: var(--space-2); }
  .gcp-btn {
    display: flex; align-items: center; gap: var(--space-1); padding: 5px 10px;
    border-radius: var(--radius-md); border: 1px solid var(--border);
    font-family: var(--font-sans); font-size: var(--text-xs); font-weight: 500;
    cursor: pointer; transition: background 0.1s ease, color 0.1s ease, border-color 0.1s ease, opacity 0.1s ease;
    white-space: nowrap;
  }
  .gcp-btn:disabled { opacity: 0.4; cursor: not-allowed; }
  .gcp-btn:focus-visible { outline: 2px solid var(--cnp-accent, oklch(0.65 0.18 250)); outline-offset: 1px; }
  .gcp-btn--primary { background: var(--fg); color: var(--bg); border-color: var(--fg); flex: 1; justify-content: center; }
  .gcp-btn--primary:hover:not(:disabled) { background: color-mix(in oklch, var(--fg) 85%, transparent); }
  .gcp-btn--ghost { background: transparent; color: var(--fg-muted); }
  .gcp-btn--ghost:hover:not(:disabled) { background: var(--bg-inset); color: var(--fg); }
</style>
