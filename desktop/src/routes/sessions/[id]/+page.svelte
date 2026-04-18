<script lang="ts">
/**
 * /sessions/[id] — Session Detail (hero live view).
 *
 * Layout: three zones
 *   1. Header bar — back, avatar, title, status badge, cancel CTA
 *   2. Body       — TranscriptView (left) + Context panel (right 340px)
 *   3. Footer     — LiveTerminal (collapsible)
 *
 * On mount:
 *   - Fetch session + messages via TanStack Query
 *   - Subscribe to SSE via subscribeToSession()
 *   - Append live TranscriptEntries to reactive messages list
 *   - Return unsubscribe() from onMount
 *
 * TanStack QueryClientProvider assumed from root layout (+layout.svelte).
 */
// TODO: QueryClient setup assumed from layout

import { type CreateQueryOptions, createMutation, createQuery } from '@tanstack/svelte-query';
import { onMount, untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import { page } from '$app/state';
import {
  cancelSession,
  sessionDetailQuery,
  sessionMessagesQuery,
} from '$lib/api/queries/sessions.js';
import { subscribeToSession } from '$lib/api/realtime.js';
import Alert from '$lib/design/foundation/alert/Alert.svelte';
import Skeleton from '$lib/design/foundation/skeleton/Skeleton.svelte';
import ActorAvatar from '$lib/design/patterns/ActorAvatar.svelte';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import LiveTerminal from '$lib/design/patterns/LiveTerminal.svelte';
import StatusDot from '$lib/design/patterns/StatusDot.svelte';
import TranscriptView from '$lib/design/patterns/TranscriptView.svelte';
import type { SessionDetail, SessionStatus, TranscriptEntry } from '$lib/domain/sessions/types.js';

const sessionId = $derived(page.params.id ?? '');

const detailOptsStore = writable(
  untrack(() => sessionDetailQuery(sessionId) as CreateQueryOptions<SessionDetail>)
);
const messagesOptsStore = writable(
  untrack(() => sessionMessagesQuery(sessionId) as CreateQueryOptions<TranscriptEntry[]>)
);

$effect(() => {
  detailOptsStore.set(sessionDetailQuery(sessionId) as CreateQueryOptions<SessionDetail>);
  messagesOptsStore.set(sessionMessagesQuery(sessionId) as CreateQueryOptions<TranscriptEntry[]>);
});

const detailQuery = createQuery<SessionDetail>(detailOptsStore);
const messagesQuery = createQuery<TranscriptEntry[]>(messagesOptsStore);

const cancelMut = createMutation<void, Error, string>({
  mutationFn: (id: string) => cancelSession(id),
});

// Live transcript entries — seeded from initial query, appended via SSE.
let messages = $state<TranscriptEntry[]>([]);
let liveStatus = $state<SessionStatus | null>(null);
let terminalOpen = $state(false);
let cancelError = $state<string | null>(null);

// Seed messages once initial query resolves.
$effect(() => {
  const data = $messagesQuery.data;
  if (data && messages.length === 0) {
    messages = [...data];
  }
});

const session = $derived($detailQuery.data ?? null);
const effectiveStatus = $derived<SessionStatus>(liveStatus ?? session?.status ?? 'pending');
const isRunning = $derived(effectiveStatus === 'running');

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

function formatDuration(ms: number | null): string {
  if (ms === null) return '…';
  if (ms < 1000) return `${ms}ms`;
  const secs = Math.floor(ms / 1000);
  if (secs < 60) return `${secs}s`;
  return `${Math.floor(secs / 60)}m ${secs % 60}s`;
}

async function handleCancel() {
  cancelError = null;
  try {
    await $cancelMut.mutateAsync(sessionId);
    liveStatus = 'cancelled';
  } catch (err) {
    cancelError = err instanceof Error ? err.message : 'Cancel failed';
  }
}

onMount(() => {
  const unsubscribe = subscribeToSession(
    sessionId,
    (entry) => {
      messages = [...messages, entry];
    },
    (status) => {
      liveStatus = status;
    },
    () => {
      // done — SSE stream closed by server
    }
  );

  return unsubscribe;
});
</script>

<div class="sd-page">
  <!-- ── Header bar ──────────────────────────────────────────────────── -->
  <header class="sd-header">
    <div class="sd-header-left">
      <button
        class="btn-compact btn-compact-ghost sd-back"
        onclick={() => goto('/sessions')}
        aria-label="Back to sessions"
      >
        ← Back
      </button>

      {#if session}
        <ActorAvatar
          actor={{
            type: 'agent',
            id: session.agentSlug ?? sessionId,
            name: session.agentSlug ?? 'Direct prompt',
          }}
          size="md"
        />
        <div class="sd-meta">
          <span class="sd-agent-name">{session.agentSlug ?? 'Direct prompt'}</span>
          <span class="sd-runtime">· {session.runtimeType}</span>
          <StatusDot
            color={statusDotColor(effectiveStatus)}
            pulse={isRunning}
            label={effectiveStatus}
          />
        </div>
      {:else if $detailQuery.isLoading}
        <div class="sd-meta-skeleton">
          <Skeleton class="sd-sk-avatar" />
          <Skeleton class="sd-sk-title" />
        </div>
      {/if}
    </div>

    <div class="sd-header-right">
      {#if session}
        <div class="sd-session-info">
          <span class="sd-mono">#{sessionId.slice(0, 8)}</span>
          <span class="sd-separator" aria-hidden="true">·</span>
          <span class="sd-mono">{formatDuration(session.durationMs)}</span>
          <span class="sd-separator" aria-hidden="true">·</span>
          <span class="sd-mono">${session.costUsd.toFixed(4)}</span>
        </div>
      {/if}

      {#if isRunning}
        <button
          class="btn-pill btn-pill-danger btn-pill-sm"
          onclick={handleCancel}
          disabled={$cancelMut.isPending}
          aria-label="Cancel session"
        >
          {#if $cancelMut.isPending}
            <span class="btn-pill-spinner" aria-hidden="true"></span>
            Cancelling…
          {:else}
            Cancel
          {/if}
        </button>
      {/if}
    </div>
  </header>

  <!-- Cancel error -->
  {#if cancelError}
    <Alert variant="error" dismissible ondismiss={() => (cancelError = null)}>
      {cancelError}
    </Alert>
  {/if}

  <!-- ── Body ────────────────────────────────────────────────────────── -->
  <div class="sd-body">
    <!-- Transcript panel -->
    <div class="sd-transcript glass-panel" role="region" aria-label="Session transcript">
      {#if $detailQuery.isError}
        <EmptyState title="Session not found" body="This session may have been deleted." />
      {:else}
        <TranscriptView {messages} isStreaming={isRunning} />
      {/if}
    </div>

    <!-- Context panel -->
    <aside class="sd-context glass-panel" aria-label="Session context">
      <h2 class="sd-context-title">Context</h2>

      {#if session}
        <!-- Prompt -->
        <details class="sd-ctx-item">
          <summary class="sd-ctx-summary">Prompt</summary>
          <p class="sd-ctx-body sd-mono">{session.prompt}</p>
        </details>

        <!-- Workspace -->
        <div class="sd-ctx-item">
          <span class="sd-ctx-label">Workspace</span>
          {#if session.workspaceSlug}
            <a
              class="sd-workspace-chip"
              href="/workspaces/{session.workspaceSlug}"
              aria-label="Open workspace {session.workspaceSlug}"
            >
              {session.workspaceSlug}
            </a>
          {:else}
            <span class="sd-ctx-value">—</span>
          {/if}
        </div>

        <!-- Sandbox URL -->
        {#if session.sandboxUrl}
          <div class="sd-ctx-item">
            <span class="sd-ctx-label">Sandbox</span>
            <a
              class="sd-ctx-link sd-mono"
              href={session.sandboxUrl}
              target="_blank"
              rel="noreferrer"
            >
              {session.sandboxUrl}
            </a>
          </div>
        {/if}

        <!-- Governance -->
        <div class="sd-ctx-item">
          <span class="sd-ctx-label">Governance</span>
          <span class="sd-ctx-value">{session.governanceMode}</span>
        </div>
      {:else if $detailQuery.isLoading}
        {#each Array.from({ length: 4 }, (_, i) => i) as i (i)}
          <Skeleton class="sd-sk-ctx" />
        {/each}
      {/if}
    </aside>
  </div>

  <!-- ── Live Terminal (collapsible) ────────────────────────────────── -->
  <div class="sd-terminal-section">
    <button
      class="sd-terminal-toggle btn-compact btn-compact-ghost"
      onclick={() => (terminalOpen = !terminalOpen)}
      aria-expanded={terminalOpen}
      aria-controls="sd-terminal-panel"
    >
      <span class="sd-terminal-toggle-arrow" class:open={terminalOpen} aria-hidden="true">▸</span>
      Live Terminal
    </button>

    {#if terminalOpen}
      <div id="sd-terminal-panel" class="sd-terminal-panel">
        <LiveTerminal stream={null} {isRunning} />
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
    gap: 0;
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
  }

  .sd-back {
    font-size: var(--text-sm);
    flex-shrink: 0;
  }

  .sd-meta {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    min-width: 0;
  }

  .sd-meta-skeleton {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  :global(.sd-sk-avatar) {
    width: 36px !important;
    height: 36px !important;
    border-radius: 50% !important;
    flex-shrink: 0 !important;
  }

  :global(.sd-sk-title) {
    height: 13px !important;
    width: 120px !important;
    border-radius: 4px !important;
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

  .sd-runtime {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    white-space: nowrap;
  }

  .sd-header-right {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    flex-shrink: 0;
  }

  .sd-session-info {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .sd-separator {
    color: var(--fg-subtle);
    user-select: none;
  }

  .sd-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  /* ── Body ── */
  .sd-body {
    flex: 1;
    display: flex;
    gap: var(--space-2);
    padding: var(--space-2);
    overflow: hidden;
    min-height: 0;
  }

  .sd-transcript {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    border-radius: var(--radius-lg);
  }

  .sd-context {
    width: 340px;
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-4);
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
    border-radius: var(--radius-lg);
  }

  .sd-context-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg-muted);
    letter-spacing: var(--tracking-xs);
    text-transform: uppercase;
  }

  .sd-ctx-item {
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding-bottom: var(--space-3);
    border-bottom: 1px solid var(--border);
  }

  .sd-ctx-item:last-child {
    border-bottom: none;
    padding-bottom: 0;
  }

  .sd-ctx-summary {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    cursor: pointer;
    user-select: none;
    list-style: none;
    display: flex;
    align-items: center;
    gap: var(--space-1);
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

  .sd-ctx-link {
    font-size: var(--text-xs);
    color: var(--fg-muted);
    word-break: break-all;
    text-decoration: underline;
    text-underline-offset: 2px;
  }

  .sd-ctx-link:hover {
    color: var(--fg);
  }

  /* Workspace chip — compact pill linking to /workspaces/:slug */
  .sd-workspace-chip {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    align-self: flex-start;
    padding: 2px 8px;
    border-radius: var(--radius-full, 9999px);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    border: 1px solid var(--border);
    text-decoration: none;
    transition: background 0.12s ease, color 0.12s ease;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 100%;
  }

  .sd-workspace-chip:hover {
    background: color-mix(in oklch, var(--fg) 12%, transparent 88%);
    color: var(--fg);
  }

  .sd-workspace-chip:focus-visible {
    outline: 2px solid var(--accent, currentColor);
    outline-offset: 2px;
  }

  :global(.sd-sk-ctx) {
    height: 24px !important;
    width: 100% !important;
    border-radius: 4px !important;
  }

  /* ── Terminal section ── */
  .sd-terminal-section {
    flex-shrink: 0;
    border-top: 1px solid var(--border);
    display: flex;
    flex-direction: column;
  }

  .sd-terminal-toggle {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    padding: var(--space-2) var(--space-4);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    width: 100%;
    text-align: left;
    border-radius: 0;
  }

  .sd-terminal-toggle-arrow {
    font-size: 10px;
    transition: transform 0.15s var(--ease-out);
    display: inline-block;
    flex-shrink: 0;
  }

  .sd-terminal-toggle-arrow.open {
    transform: rotate(90deg);
  }

  .sd-terminal-panel {
    height: 200px;
    padding: 0 var(--space-2) var(--space-2);
  }
</style>
