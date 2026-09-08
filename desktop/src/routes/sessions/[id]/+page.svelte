<script lang="ts">
/**
 * /sessions/[id] — Session detail. Each session = one terminal instance.
 *
 * Primary view: xterm.js wired to Phoenix Channel "terminal:session:<id>" via WS.
 * Fallback: TranscriptView if channel is unavailable (backend not yet ready).
 *
 * Input bar: Cmd/Ctrl+Enter → fork session (POST /api/v1/sessions with parentSessionId).
 * Fork: copies runtime + workspace + cwd, allows new prompt.
 *
 * Side panel: workspace name, runtime+model, token/cost counter, session meta.
 *
 * LOC ≤ 300.
 */

import {
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { Copy, GitFork, X } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import { page } from '$app/state';
import { listRunsForSession, type Run, transcriptQuery } from '$lib/api/queries/runs.js';
import {
  cancelSession,
  cleanupWorktree,
  createSession,
  pauseSession,
  resumeSession,
  sendSessionMessage,
  sessionDetailQuery,
} from '$lib/api/queries/sessions.js';
import Alert from '$lib/design/foundation/alert/Alert.svelte';
import Skeleton from '$lib/design/foundation/skeleton/Skeleton.svelte';
import ActorAvatar from '$lib/design/patterns/ActorAvatar.svelte';
import ChangesPanel from '$lib/design/patterns/diff/ChangesPanel.svelte';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import RichInputToggle from '$lib/design/patterns/mosaic/panes/agent-conversation/RichInputToggle.svelte';
import PausedOverlay from '$lib/design/patterns/PausedOverlay.svelte';
import TypedTranscript from '$lib/design/patterns/runs/TypedTranscript.svelte';
import StatusDot from '$lib/design/patterns/StatusDot.svelte';
import LifecyclePanel from '$lib/design/patterns/sessions/LifecyclePanel.svelte';
import PortsList from '$lib/design/patterns/sessions/PortsList.svelte';
import TerminalHarness from '$lib/design/patterns/terminal-harness/TerminalHarness.svelte';
import WorktreePanel from '$lib/design/patterns/worktree/WorktreePanel.svelte';
import OpenInEditorButton from '$lib/design/primitives/OpenInEditorButton.svelte';
import ResizablePanel from '$lib/design/primitives/ResizablePanel.svelte';
import type {
  CreateSessionBody,
  Session,
  SessionDetail,
  SessionStatus,
} from '$lib/domain/sessions/types.js';
import { toasts } from '$lib/stores/toasts.svelte.js';

const queryClient = useQueryClient();
const sessionId = $derived(page.params.id ?? '');

const detailOptsStore = writable(
  untrack(() => sessionDetailQuery(sessionId) as CreateQueryOptions<SessionDetail>)
);

$effect(() => {
  detailOptsStore.set(sessionDetailQuery(sessionId) as CreateQueryOptions<SessionDetail>);
});

const detailQuery = createQuery<SessionDetail>(detailOptsStore);

const cancelMut = createMutation<void, Error, string>({
  mutationFn: (id: string) => cancelSession(id),
});

const pauseMut = createMutation<Session, Error, string>({
  mutationFn: (id: string) => pauseSession(id),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['sessions', sessionId] });
    queryClient.invalidateQueries({ queryKey: ['sessions'] });
  },
});

const resumeMut = createMutation<Session, Error, string>({
  mutationFn: (id: string) => resumeSession(id),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['sessions', sessionId] });
    queryClient.invalidateQueries({ queryKey: ['sessions'] });
  },
});

const cleanupWorktreeMut = createMutation<{ ok: boolean }, Error, string>({
  mutationFn: (id: string) => cleanupWorktree(id),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['sessions', sessionId] });
    toasts.success('Worktree removed');
  },
  onError: (err) => {
    toasts.error(err.message ?? 'Cleanup failed');
  },
});

const forkMut = createMutation<Session, Error, CreateSessionBody>({
  mutationFn: (body) => createSession(body),
  onSuccess: (newSession) => {
    queryClient.invalidateQueries({ queryKey: ['sessions'] });
    void goto(`/sessions/${newSession.id}`);
  },
});

// ── State ─────────────────────────────────────────────────────────────────────

let cancelError = $state<string | null>(null);
let pauseResumeError = $state<string | null>(null);
let promptInput = $state('');
let sidebarTab = $state<'context' | 'changes' | 'runs' | 'worktree' | 'ports' | 'lifecycle'>(
  'context'
);

// ── Rich Input ─────────────────────────────────────────────────────────────────
// PTY write function — populated when TerminalHarness reports ready.
let ptySend = $state<((data: string) => void) | null>(null);

// localStorage key is session-scoped so each session remembers its own toggle.
const richInputStorageKey = $derived(`rich-input:${sessionId}`);
let richInputOn = $state(false);

$effect(() => {
  // Read persisted state once sessionId is known (runs on mount + sessionId change).
  const stored =
    typeof localStorage !== 'undefined' ? localStorage.getItem(richInputStorageKey) : null;
  richInputOn = stored === 'true';
});

function toggleRichInput(): void {
  richInputOn = !richInputOn;
  if (typeof localStorage !== 'undefined') {
    localStorage.setItem(richInputStorageKey, String(richInputOn));
  }
}

let richInputTextarea = $state<HTMLTextAreaElement | undefined>();

// Auto-grow textarea height as content grows.
function autoGrow(node: HTMLTextAreaElement): void {
  node.style.height = 'auto';
  node.style.height = `${Math.min(node.scrollHeight, 200)}px`;
}

async function handleSendPrompt(): Promise<void> {
  const content = promptInput.trim();
  if (!content || !ptySend) return;

  // Write to PTY stdin.
  ptySend(`${content}\n`);

  // Fire-and-forget audit log — swallow errors if backend not yet wired.
  void sendSessionMessage(sessionId, content).catch(() => {
    /* not yet wired */
  });

  promptInput = '';
  // Reset textarea height after clearing.
  if (richInputTextarea) {
    richInputTextarea.style.height = 'auto';
  }
}

function handleRichKeydown(e: KeyboardEvent): void {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    void handleSendPrompt();
  } else if (e.key === 'Escape') {
    richInputOn = false;
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem(richInputStorageKey, 'false');
    }
  }
}

// Runs for this session — loaded lazily when "runs" tab is selected
const runsOptsStore = writable(untrack(() => listRunsForSession(sessionId)));
$effect(() => {
  runsOptsStore.set(listRunsForSession(sessionId));
});
const runsQuery = createQuery<Run[]>(runsOptsStore);

// Transcript expansion — one run expanded at a time
let expandedRunId = $state<string | null>(null);
const transcriptOptsStore = writable(untrack(() => transcriptQuery(expandedRunId ?? '')));
$effect(() => {
  transcriptOptsStore.set(transcriptQuery(expandedRunId ?? ''));
});
const runTranscriptQuery = createQuery(transcriptOptsStore);

const sessionDetail = $derived($detailQuery.data ?? null);
const session = $derived(sessionDetail?.session ?? null);
const effectiveStatus = $derived<SessionStatus>(session?.status ?? 'pending');
const isRunning = $derived(effectiveStatus === 'running');
const isPaused = $derived(effectiveStatus === 'paused');

// ── Actions ───────────────────────────────────────────────────────────────────

async function handleCancel(): Promise<void> {
  cancelError = null;
  try {
    await $cancelMut.mutateAsync(sessionId);
    queryClient.invalidateQueries({ queryKey: ['sessions', sessionId] });
    queryClient.invalidateQueries({ queryKey: ['sessions'] });
  } catch (err) {
    cancelError = err instanceof Error ? err.message : 'Cancel failed';
  }
}

async function handlePause(): Promise<void> {
  pauseResumeError = null;
  try {
    await $pauseMut.mutateAsync(sessionId);
    toasts.success('Paused — terminal stays alive');
  } catch (err) {
    pauseResumeError = err instanceof Error ? err.message : 'Pause failed';
    toasts.error(pauseResumeError ?? 'Pause failed');
  }
}

async function handleResume(): Promise<void> {
  pauseResumeError = null;
  try {
    await $resumeMut.mutateAsync(sessionId);
    toasts.success('Resumed');
  } catch (err) {
    pauseResumeError = err instanceof Error ? err.message : 'Resume failed';
    toasts.error(pauseResumeError ?? 'Resume failed');
  }
}

function handleFork(): void {
  if (!session) return;
  $forkMut.mutate({
    runtimeType: session.runtimeType,
    cwd: session.cwd ?? '~',
    modelId: session.modelId ?? undefined,
    workspaceSlug: session.workspaceSlug ?? undefined,
    prompt: promptInput.trim() || session.prompt || undefined,
    parentSessionId: session.id,
  });
}

function copyId(): void {
  void navigator.clipboard.writeText(sessionId);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function statusDotColor(s: SessionStatus): 'green' | 'amber' | 'red' | 'grey' {
  switch (s) {
    case 'running':
      return 'green';
    case 'error':
      return 'red';
    case 'paused':
      return 'amber';
    case 'pending':
      return 'amber';
    default:
      return 'grey';
  }
}

function formatDuration(): string {
  if (!session?.startedAt || !session?.completedAt) return '…';
  const ms = new Date(session.completedAt).getTime() - new Date(session.startedAt).getTime();
  if (ms < 1000) return `${ms}ms`;
  const secs = Math.floor(ms / 1000);
  return secs < 60 ? `${secs}s` : `${Math.floor(secs / 60)}m ${secs % 60}s`;
}

function formatCost(): string {
  if (!session) return '—';
  const n = parseFloat(session.costUsd);
  return isNaN(n) ? '—' : `$${n.toFixed(4)}`;
}
</script>

<div class="sd-page">
  <!-- ── Header ─────────────────────────────────────────────────────────── -->
  <header class="sd-header">
    <div class="sd-header-left">
      <button class="btn-compact btn-compact-ghost sd-back" onclick={() => goto('/sessions')} aria-label="Back to sessions">
        ← Back
      </button>

      {#if session}
        <ActorAvatar
          actor={{ type: 'agent', id: session.agentSlug ?? sessionId, name: session.agentSlug ?? 'Direct prompt' }}
          size="md"
        />
        <div class="sd-meta">
          <span class="sd-agent-name">{session.agentSlug ?? 'Direct prompt'}</span>
          <span class="sd-sep sd-mono">·</span>
          <span class="sd-runtime sd-mono">{session.runtimeType}{session.modelId ? `/${session.modelId}` : ''}</span>
          {#if session.workspaceSlug}
            <span class="sd-sep sd-mono">·</span>
            <span class="sd-workspace sd-mono">{session.workspaceSlug}</span>
          {/if}
          <StatusDot color={statusDotColor(effectiveStatus)} pulse={isRunning} label={effectiveStatus} />
        </div>
      {:else if $detailQuery.isLoading}
        <div class="sd-meta">
          <Skeleton class="sd-sk-avatar" />
          <Skeleton class="sd-sk-title" />
        </div>
      {/if}
    </div>

    <div class="sd-header-right">
      {#if session}
        <button class="sd-id-btn sd-mono" onclick={copyId} title="Copy session ID">
          <Copy size={10} aria-hidden="true" />
          #{sessionId.slice(0, 8)}
        </button>
        <span class="sd-sep sd-mono" aria-hidden="true">·</span>
        <span class="sd-mono">{formatDuration()}</span>
        <span class="sd-sep sd-mono" aria-hidden="true">·</span>
        <span class="sd-mono">{formatCost()}</span>
      {/if}

      <button
        class="btn-compact btn-compact-ghost sd-fork-btn"
        onclick={handleFork}
        disabled={$forkMut.isPending || !session}
        aria-label="Fork session"
        title="Fork session — spawn new terminal from same config"
      >
        <GitFork size={12} aria-hidden="true" />
        {$forkMut.isPending ? 'Forking…' : 'Fork'}
      </button>

      {#if isRunning}
        <button
          class="btn-compact btn-compact-ghost sd-pause-btn"
          onclick={handlePause}
          disabled={$pauseMut.isPending}
          aria-label="Pause session"
          title="Pause — terminal stays alive"
        >
          {$pauseMut.isPending ? 'Pausing…' : 'Pause'}
        </button>
        <button
          class="btn-pill btn-pill-danger btn-pill-sm"
          onclick={handleCancel}
          disabled={$cancelMut.isPending}
          aria-label="End session"
        >
          {$cancelMut.isPending ? 'Ending…' : 'End'}
          <X size={11} aria-hidden="true" />
        </button>
      {:else if isPaused}
        <button
          class="btn-compact btn-compact-ghost sd-resume-btn"
          onclick={handleResume}
          disabled={$resumeMut.isPending}
          aria-label="Resume session"
        >
          {$resumeMut.isPending ? 'Resuming…' : 'Resume'}
        </button>
      {/if}
    </div>
  </header>

  {#if cancelError}
    <Alert variant="error" dismissible ondismiss={() => (cancelError = null)}>
      {cancelError}
    </Alert>
  {/if}

  <!-- ── Body ───────────────────────────────────────────────────────────── -->
  <div class="sd-body">
    <ResizablePanel persistKey="session.detail.sidebar" defaultSize={280} minSize={200} maxSize={600}>
      {#snippet left()}
        <!-- Terminal pane — xterm.js over Phoenix Channel with TranscriptView fallback -->
        {#if $detailQuery.isError}
          <div class="sd-transcript-wrap">
            <EmptyState title="Session not found" body="This session may have been deleted." />
          </div>
        {:else if $detailQuery.isLoading}
          <div class="sd-transcript-wrap sd-loading">
            <Skeleton class="sd-sk-fill" />
          </div>
        {:else}
          <div class="sd-transcript-wrap sd-transcript-wrap--relative">
            <TerminalHarness
              {sessionId}
              {session}
              {isRunning}
              {isPaused}
              onPause={handlePause}
              onResume={handleResume}
              onSendReady={(fn) => { ptySend = fn; }}
            />
            {#if isPaused}
              <PausedOverlay onResume={handleResume} isPending={$resumeMut.isPending} />
            {/if}
          </div>
        {/if}
      {/snippet}

      {#snippet right()}
        <!-- Side panel with tabs: Context | Changes -->
        <aside class="sd-context glass-panel" aria-label="Session context">
          <!-- Tab bar -->
          <div class="sd-tabs" role="tablist" aria-label="Session panel tabs">
            {#each ([
              { id: 'context',   label: 'Context'  },
              { id: 'changes',   label: 'Changes'  },
              { id: 'worktree',  label: 'Tree'     },
              { id: 'runs',      label: 'Runs'     },
              { id: 'ports',     label: 'Ports'    },
              { id: 'lifecycle', label: 'Life'     },
            ] as const) as tab (tab.id)}
              <button
                class="sd-tab"
                class:sd-tab--active={sidebarTab === tab.id}
                role="tab"
                aria-selected={sidebarTab === tab.id}
                onclick={() => { sidebarTab = tab.id; }}
              >
                {tab.label}
              </button>
            {/each}
          </div>

          {#if sidebarTab === 'changes'}
            <div class="sd-changes-pane">
              <ChangesPanel {sessionId} />
            </div>
          {:else if sidebarTab === 'worktree'}
            <div class="sd-changes-pane">
              <WorktreePanel {sessionId} />
            </div>
          {:else if sidebarTab === 'runs'}
            <!-- Runs tab: read-only list of runs for this session -->
            <div class="sd-runs-pane" aria-label="Session runs">
              {#if $runsQuery.isLoading}
                {#each Array.from({ length: 3 }, (_, i) => i) as i (i)}
                  <div class="sd-run-row sd-run-row--loading" aria-hidden="true">
                    <div class="sd-run-sk sd-run-sk--id"></div>
                    <div class="sd-run-sk sd-run-sk--status"></div>
                  </div>
                {/each}
              {:else if !$runsQuery.data?.length}
                <p class="sd-runs-empty">No runs yet for this session.</p>
              {:else}
                {#each ($runsQuery.data ?? []) as run (run.id)}
                  {@const isExpanded = expandedRunId === run.id}
                  <div class="sd-run-row" aria-label="Run {run.shortId}" aria-expanded={isExpanded}>
                    <!-- svelte-ignore a11y_click_events_have_key_events -->
                    <!-- svelte-ignore a11y_no_static_element_interactions -->
                    <div
                      class="sd-run-summary"
                      onclick={() => { expandedRunId = isExpanded ? null : run.id; }}
                      role="button"
                      tabindex="0"
                      onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') expandedRunId = isExpanded ? null : run.id; }}
                    >
                      <div class="sd-run-left">
                        <span class="sd-run-expand" aria-hidden="true">{isExpanded ? '▾' : '▸'}</span>
                        <span class="sd-run-id sd-mono">{run.shortId}</span>
                        {#if run.agentSlug}
                          <span class="sd-run-agent">{run.agentSlug}</span>
                        {/if}
                      </div>
                      <div class="sd-run-right">
                        <span class="sd-run-status sd-run-status--{run.status}">{run.status}</span>
                        {#if run.usageJson?.costUsd}
                          <span class="sd-run-cost sd-mono">${parseFloat(run.usageJson.costUsd).toFixed(4)}</span>
                        {/if}
                        <a
                          class="sd-run-log-link"
                          href="/api/v1/runs/{run.id}/log"
                          target="_blank"
                          rel="noopener"
                          aria-label="Open NDJSON log for {run.shortId}"
                          title="View raw NDJSON log"
                          onclick={(e) => e.stopPropagation()}
                        >log ↗</a>
                      </div>
                    </div>
                    {#if isExpanded}
                      <div class="sd-run-transcript">
                        <TypedTranscript
                          blocks={$runTranscriptQuery.data?.blocks ?? []}
                          isLoading={$runTranscriptQuery.isLoading}
                          error={$runTranscriptQuery.isError ? 'Could not load transcript' : null}
                        />
                      </div>
                    {/if}
                  </div>
                {/each}
              {/if}
            </div>
          {:else if sidebarTab === 'ports'}
            <PortsList {sessionId} />
          {:else if sidebarTab === 'lifecycle'}
            <LifecyclePanel {sessionId} />
          {:else}
          <!-- Context tab content -->
          <div class="sd-ctx-scroll">
          {#if session}
            <details class="sd-ctx-item">
              <summary class="sd-ctx-summary">Prompt</summary>
              {#if session.prompt}
                <p class="sd-ctx-body sd-ctx-mono">{session.prompt}</p>
              {:else}
                <p class="sd-ctx-body sd-ctx-empty">No initial prompt</p>
              {/if}
            </details>

            <div class="sd-ctx-item">
              <span class="sd-ctx-label">Directory</span>
              <span class="sd-ctx-value sd-ctx-mono">{session.cwd}</span>
            </div>

            {#if session.branch}
              <div class="sd-ctx-item">
                <span class="sd-ctx-label">Branch</span>
                <div class="sd-ctx-copy-row">
                  <span class="sd-ctx-value sd-ctx-mono">{session.branch}</span>
                  <button
                    class="sd-copy-btn"
                    onclick={() => navigator.clipboard.writeText(session!.branch!)}
                    aria-label="Copy branch name"
                    title="Copy branch name"
                  >⎘</button>
                </div>
              </div>
            {/if}

            {#if session.worktreePath}
              <div class="sd-ctx-item">
                <span class="sd-ctx-label">Worktree</span>
                <div class="sd-ctx-copy-row">
                  <span class="sd-ctx-value sd-ctx-mono sd-ctx-truncate">{session.worktreePath}</span>
                  <button
                    class="sd-copy-btn"
                    onclick={() => navigator.clipboard.writeText(session!.worktreePath!)}
                    aria-label="Copy worktree path"
                    title="Copy worktree path"
                  >⎘</button>
                </div>
              </div>
              <div class="sd-ctx-item">
                <OpenInEditorButton path={session.worktreePath} />
              </div>
            {:else if session.cwd}
              <div class="sd-ctx-item">
                <OpenInEditorButton path={session.cwd} />
              </div>
            {/if}

            <div class="sd-ctx-item">
              <span class="sd-ctx-label">Workspace</span>
              {#if session.workspaceSlug}
                <a class="sd-ws-chip" href="/workspaces/{session.workspaceSlug}">{session.workspaceSlug}</a>
              {:else}
                <span class="sd-ctx-value">—</span>
              {/if}
            </div>

            {#if session.modelId}
              <div class="sd-ctx-item">
                <span class="sd-ctx-label">Model</span>
                <span class="sd-ctx-value sd-ctx-mono">{session.modelId}</span>
              </div>
            {/if}

            <div class="sd-ctx-item">
              <span class="sd-ctx-label">Tokens</span>
              <span class="sd-ctx-value sd-ctx-mono">
                in {session.inputTokens.toLocaleString()} / out {session.outputTokens.toLocaleString()}
              </span>
            </div>

            <div class="sd-ctx-item">
              <span class="sd-ctx-label">Cost</span>
              <span class="sd-ctx-value sd-ctx-mono">{formatCost()}</span>
            </div>
            {#if session.worktreePath}
              <div class="sd-ctx-danger-zone">
                <button
                  class="btn-compact btn-compact-ghost sd-cleanup-btn"
                  onclick={() => $cleanupWorktreeMut.mutate(sessionId)}
                  disabled={$cleanupWorktreeMut.isPending}
                  aria-label="Remove worktree"
                  title="Remove git worktree from disk — review changes first"
                >
                  {$cleanupWorktreeMut.isPending ? 'Removing…' : 'Cleanup worktree'}
                </button>
              </div>
            {/if}
          {:else if $detailQuery.isLoading}
            {#each Array.from({ length: 4 }, (_, i) => i) as i (i)}
              <Skeleton class="sd-sk-ctx" />
            {/each}
          {/if}
          </div>
          {/if}
        </aside>
      {/snippet}
    </ResizablePanel>
  </div>

  <!-- ── Input bar — inject or hint ──────────────────────────────────────── -->
  <div
    class="sd-rich-bar"
    class:sd-rich-bar--expanded={richInputOn}
    aria-label={richInputOn ? 'Rich prompt input' : 'Terminal input hint'}
  >
    {#if richInputOn}
      <!-- Expanded: full composer -->
      <div class="sd-rich-composer">
        <textarea
          class="sd-rich-textarea"
          rows="1"
          placeholder="Type a prompt — Enter to send, Shift+Enter for newline, Esc to collapse"
          bind:value={promptInput}
          bind:this={richInputTextarea}
          oninput={(e) => autoGrow(e.currentTarget)}
          onkeydown={handleRichKeydown}
          aria-label="Rich prompt input"
          disabled={!ptySend}
          autofocus
        ></textarea>
        <div class="sd-rich-footer">
          <div class="sd-rich-footer-left">
            {#if session?.runtimeType}
              <span class="sd-rich-chip sd-mono">{session.runtimeType}{session.modelId ? `/${session.modelId}` : ''}</span>
            {/if}
            <RichInputToggle on={richInputOn} onToggle={toggleRichInput} enabled={!!ptySend} />
          </div>
          <button
            class="sd-rich-send-btn"
            onclick={handleSendPrompt}
            disabled={!ptySend || !promptInput.trim()}
            aria-label="Send prompt to terminal"
            title="Send (Enter)"
          >
            Send ↵
          </button>
        </div>
      </div>
    {:else}
      <!-- Collapsed: hint row -->
      <div class="sd-rich-hint">
        <span class="sd-caret" aria-hidden="true">❯</span>
        <span class="sd-rich-hint-text sd-mono">Type in terminal</span>
        <span class="sd-rich-sep" aria-hidden="true">·</span>
        <RichInputToggle on={false} onToggle={toggleRichInput} enabled={!!ptySend} />
      </div>
    {/if}
  </div>
</div>

<style>
  .sd-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  /* ── Header ── */
  .sd-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-3) var(--space-4);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    flex-wrap: wrap;
    gap: var(--space-2);
  }

  .sd-header-left {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    min-width: 0;
    flex-wrap: wrap;
  }

  .sd-back { font-size: var(--text-sm); flex-shrink: 0; }

  .sd-meta {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-wrap: wrap;
    min-width: 0;
  }

  .sd-agent-name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 200px;
  }

  .sd-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  .sd-sep { color: var(--fg-subtle); user-select: none; }
  .sd-runtime, .sd-workspace { white-space: nowrap; }

  .sd-header-right {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
    flex-wrap: wrap;
  }

  .sd-id-btn {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    background: transparent;
    border: none;
    cursor: pointer;
    color: var(--fg-muted);
    padding: 2px 4px;
    border-radius: var(--radius-sm);
    transition: color 0.12s ease;
  }
  .sd-id-btn:hover { color: var(--fg); }

  .sd-fork-btn {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    font-size: var(--text-xs);
  }

  :global(.sd-sk-avatar) {
    width: 32px !important;
    height: 32px !important;
    border-radius: 50% !important;
    flex-shrink: 0 !important;
  }

  :global(.sd-sk-title) {
    height: 13px !important;
    width: 120px !important;
    border-radius: 4px !important;
  }

  /* ── Body ── */
  .sd-body {
    flex: 1;
    display: flex;
    padding: var(--space-2);
    overflow: hidden;
    min-height: 0;
  }

  .sd-transcript-wrap {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    min-height: 0;
  }

  .sd-transcript-wrap--relative {
    position: relative;
  }

  .sd-loading {
    border-radius: var(--radius-lg);
    border: 1px solid var(--border);
  }

  .sd-pause-btn {
    font-size: var(--text-xs);
    color: var(--priority, oklch(0.78 0.15 70));
  }

  .sd-pause-btn:hover:not(:disabled) {
    color: var(--fg);
  }

  .sd-resume-btn {
    font-size: var(--text-xs);
    color: var(--priority, oklch(0.78 0.15 70));
    border: 1px solid color-mix(in oklch, var(--priority, oklch(0.78 0.15 70)) 40%, transparent);
    border-radius: var(--radius-sm);
    padding: 2px 8px;
  }

  .sd-resume-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--priority, oklch(0.78 0.15 70)) 10%, transparent);
  }

  :global(.sd-sk-fill) {
    width: 100% !important;
    height: 100% !important;
    border-radius: var(--radius-lg) !important;
  }

  /* Side panel — width controlled by ResizablePanel */
  .sd-context {
    width: 100%;
    height: 100%;
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    gap: 0;
    padding: 0;
    overflow: hidden;
    border-radius: var(--radius-lg);
  }

  /* Tab bar */
  .sd-tabs {
    display: flex;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .sd-tab {
    flex: 1;
    padding: var(--space-2) 0;
    border: none;
    background: transparent;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-subtle);
    cursor: pointer;
    border-bottom: 2px solid transparent;
    transition: color 0.1s ease, border-color 0.1s ease;
  }
  .sd-tab:hover:not(.sd-tab--active) { color: var(--fg-muted); }
  .sd-tab--active {
    color: var(--fg);
    border-bottom-color: var(--cnp-accent);
  }
  .sd-tab:focus-visible { outline: 2px solid var(--cnp-accent); outline-offset: -2px; }

  /* Changes pane — fills the panel, no padding (ChangesPanel owns its own) */
  .sd-changes-pane {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .sd-ctx-scroll {
    flex: 1;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
    padding: var(--space-4);
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .sd-ctx-item {
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding-bottom: var(--space-3);
    border-bottom: 1px solid var(--border);
  }

  .sd-ctx-item:last-child { border-bottom: none; padding-bottom: 0; }

  .sd-ctx-summary {
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    cursor: pointer;
    list-style: none;
  }

  .sd-ctx-body {
    margin: var(--space-1) 0 0;
    font-size: var(--text-xs);
    line-height: 1.6;
    color: var(--fg-muted);
    word-break: break-word;
  }

  .sd-ctx-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: var(--tracking-xs);
  }

  .sd-ctx-value {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
  }

  .sd-ctx-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    word-break: break-all;
  }

  .sd-ws-chip {
    display: inline-flex;
    align-self: flex-start;
    padding: 2px 8px;
    border-radius: 9999px;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    border: 1px solid var(--border);
    text-decoration: none;
    transition: background 0.12s ease, color 0.12s ease;
  }

  .sd-ws-chip:hover {
    background: color-mix(in oklch, var(--fg) 12%, transparent 88%);
    color: var(--fg);
  }

  :global(.sd-sk-ctx) {
    height: 24px !important;
    width: 100% !important;
    border-radius: 4px !important;
  }

  .sd-ctx-copy-row {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    min-width: 0;
  }

  .sd-ctx-truncate {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
    flex: 1;
  }

  .sd-copy-btn {
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

  .sd-copy-btn:hover { color: var(--fg); }

  .sd-ctx-danger-zone {
    padding-top: var(--space-2);
    margin-top: var(--space-1);
    border-top: 1px solid var(--border);
  }

  .sd-cleanup-btn {
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    width: 100%;
    justify-content: flex-start;
  }

  .sd-cleanup-btn:hover {
    color: var(--color-error, hsl(0 70% 60%));
  }

  /* ── Rich Input bar (sd-rich- prefix) ── */
  .sd-rich-bar {
    border-top: 1px solid var(--border);
    flex-shrink: 0;
    background: color-mix(in oklch, var(--bg-inset) 60%, transparent 40%);
    transition: padding 0.12s ease;
  }

  /* Collapsed: single hint row */
  .sd-rich-hint {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-4);
  }

  .sd-rich-hint-text {
    color: var(--fg-subtle);
    font-size: var(--text-xs);
  }

  .sd-rich-sep {
    color: var(--fg-subtle);
    user-select: none;
    font-size: var(--text-xs);
  }

  /* Expanded: full composer */
  .sd-rich-composer {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-3) var(--space-4);
  }

  .sd-rich-textarea {
    width: 100%;
    background: transparent;
    border: none;
    outline: none;
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    color: var(--fg);
    resize: none;
    line-height: 1.5;
    min-height: 28px;
    max-height: 200px;
    overflow-y: auto;
    scrollbar-width: thin;
  }

  .sd-rich-textarea::placeholder { color: var(--fg-subtle); }
  .sd-rich-textarea:disabled { opacity: 0.5; }

  .sd-rich-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-2);
  }

  .sd-rich-footer-left {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .sd-rich-chip {
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    padding: 2px 8px;
    border-radius: 9999px;
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    border: 1px solid var(--border);
    white-space: nowrap;
  }

  .sd-rich-send-btn {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    padding: 4px 12px;
    border: 1px solid var(--cnp-accent, oklch(0.72 0.18 145));
    border-radius: var(--radius-md);
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 10%, transparent);
    color: var(--cnp-accent, oklch(0.72 0.18 145));
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    cursor: pointer;
    flex-shrink: 0;
    transition: background 0.12s ease;
  }

  .sd-rich-send-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 18%, transparent);
  }

  .sd-rich-send-btn:disabled { opacity: 0.35; cursor: not-allowed; }

  .sd-rich-send-btn:focus-visible {
    outline: 2px solid var(--cnp-accent, oklch(0.72 0.18 145));
    outline-offset: 2px;
  }

  /* Shared caret glyph (used in hint row) */
  .sd-caret {
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    color: var(--cnp-accent, oklch(0.72 0.18 145));
    flex-shrink: 0;
    user-select: none;
    line-height: 1.5;
  }

  .sd-ctx-empty {
    margin: var(--space-1) 0 0;
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    font-style: italic;
  }

  /* ── Runs tab ── */
  .sd-runs-pane {
    flex: 1;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
    display: flex;
    flex-direction: column;
    gap: 1px;
    padding: var(--space-2) 0;
  }

  .sd-runs-empty {
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    padding: var(--space-4);
    text-align: center;
  }

  .sd-run-row {
    display: flex;
    flex-direction: column;
    border-bottom: 1px solid var(--border);
  }

  .sd-run-summary {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-4);
    min-height: 32px;
    cursor: pointer;
    user-select: none;
  }

  .sd-run-summary:hover { background: color-mix(in oklch, var(--fg) 4%, transparent); }

  .sd-run-expand {
    font-size: 10px;
    color: var(--fg-subtle);
    width: 10px;
    flex-shrink: 0;
  }

  .sd-run-transcript {
    border-top: 1px solid var(--border);
    background: var(--bg-inset);
    padding: 0 var(--space-2);
    max-height: 320px;
    overflow-y: auto;
  }

  .sd-run-row--loading {
    gap: var(--space-2);
    animation: sd-pulse 1.4s ease-in-out infinite;
  }

  .sd-run-sk {
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
  }

  .sd-run-sk--id { width: 72px; height: 12px; }
  .sd-run-sk--status { width: 48px; height: 10px; }

  @keyframes sd-pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.4; }
  }

  .sd-run-left {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    min-width: 0;
  }

  .sd-run-right {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
  }

  .sd-run-id {
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  .sd-run-agent {
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 80px;
  }

  .sd-run-status {
    font-size: 10px;
    font-weight: 600;
    padding: 1px 5px;
    border-radius: var(--radius-sm);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .sd-run-status--queued { background: color-mix(in oklch, var(--fg) 10%, transparent); color: var(--fg-muted); }
  .sd-run-status--running { background: oklch(0.85 0.12 145 / 0.18); color: oklch(0.55 0.14 145); }
  .sd-run-status--paused { background: oklch(0.85 0.12 60 / 0.18); color: oklch(0.55 0.14 60); }
  .sd-run-status--succeeded { background: oklch(0.85 0.1 145 / 0.12); color: oklch(0.5 0.12 145); }
  .sd-run-status--failed { background: oklch(0.85 0.12 25 / 0.18); color: oklch(0.55 0.14 25); }
  .sd-run-status--cancelled { background: color-mix(in oklch, var(--fg) 8%, transparent); color: var(--fg-subtle); }

  .sd-run-cost {
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .sd-run-log-link {
    font-size: 10px;
    color: var(--fg-subtle);
    text-decoration: none;
    opacity: 0.7;
    transition: opacity 0.1s;
  }

  .sd-run-log-link:hover { opacity: 1; color: var(--cnp-accent); }
</style>
