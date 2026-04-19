<script lang="ts">
/**
 * AgentLiveCard — live timeline card for one agent.
 *
 * compact (40px, single-line summary) | full (120px, tool args + last 3 entries)
 *
 * Lifecycle:
 *   1. Query `sessionsQuery({ agent_slug, status: 'running' })` for a running session.
 *   2. When a running session exists, subscribe via `subscribeToSession`.
 *   3. Maintain a rolling buffer of the last 10 TranscriptEntry items.
 *   4. On session done or component destroy → unsubscribe.
 *
 * CSS prefix: alc- (AgentLiveCard)
 * LOC target: ≤ 250.
 */

import { onDestroy } from 'svelte';
import { goto } from '$app/navigation';
import { createQuery } from '@tanstack/svelte-query';
import { writable } from 'svelte/store';
import { untrack } from 'svelte';
import { formatDistanceToNow } from 'date-fns';
import type { CreateQueryOptions } from '@tanstack/svelte-query';
import type { Agent } from '$lib/domain/agents/types.js';
import type { Session, TranscriptEntry } from '$lib/domain/sessions/types.js';
import { sessionsQuery } from '$lib/api/queries/sessions.js';
import { subscribeToSession } from '$lib/api/realtime.js';
import StatusDot from './StatusDot.svelte';
import ActorAvatar from './ActorAvatar.svelte';

// ── Props ─────────────────────────────────────────────────────────────────────

interface Props {
  agent: Agent;
  compact?: boolean;
  full?: boolean;
}

let { agent, compact = false, full = false }: Props = $props();

// ── Running-session query ─────────────────────────────────────────────────────

const qOptsStore = writable(
  untrack(() =>
    sessionsQuery({ agentSlug: agent.slug, status: 'running', limit: 1 }) as CreateQueryOptions<Session[]>
  )
);

$effect(() => {
  qOptsStore.set(
    sessionsQuery({ agentSlug: agent.slug, status: 'running', limit: 1 }) as CreateQueryOptions<Session[]>
  );
});

const runningQ = createQuery<Session[]>(qOptsStore);

// ── SSE subscription ──────────────────────────────────────────────────────────

let buffer = $state<TranscriptEntry[]>([]);
let sessionStatus = $state<'running' | 'completed' | null>(null);
let completedAt = $state<number | null>(null);
let unsub: (() => void) | null = null;

/** Running session (first result), or null. */
const runningSession = $derived(
  $runningQ.data && $runningQ.data.length > 0 ? $runningQ.data[0] : null
);

/** Last session from any completed run (for "Last run" label when idle). */
const lastSession = $derived($runningQ.data?.[0] ?? null);

$effect(() => {
  const session = runningSession;

  if (!session) {
    // No running session — clean up any lingering SSE connection.
    if (unsub) {
      unsub();
      unsub = null;
    }
    // Keep buffer for completed fade-out; clear after 5s if we just finished.
    return;
  }

  // Already subscribed to this session — no-op.
  if (unsub) return;

  sessionStatus = 'running';
  buffer = [];

  const cleanup = subscribeToSession(
    session.id,
    (entry: TranscriptEntry) => {
      buffer = [...buffer.slice(-9), entry]; // rolling 10-entry window
    },
    () => {
      // status change — we drive from SSE done instead
    },
    () => {
      sessionStatus = 'completed';
      completedAt = Date.now();
      unsub = null;
      // Fade back to idle after 5 s
      setTimeout(() => {
        sessionStatus = null;
        completedAt = null;
        buffer = [];
      }, 5000);
    }
  );

  unsub = cleanup;
});

onDestroy(() => {
  unsub?.();
  unsub = null;
});

// ── Derived visual state ──────────────────────────────────────────────────────

type VisualState = 'idle' | 'thinking' | 'tool_call' | 'assistant' | 'error' | 'completed';

const lastEntry = $derived(buffer.length > 0 ? buffer[buffer.length - 1] : null);

const visualState = $derived.by<VisualState>(() => {
  if (sessionStatus === 'completed') return 'completed';
  if (!runningSession || !lastEntry) return 'idle';
  switch (lastEntry.kind) {
    case 'thinking': return 'thinking';
    case 'tool_call': return 'tool_call';
    case 'assistant': return 'assistant';
    case 'system':
    case 'stderr': return 'error';
    default: return 'assistant';
  }
});

const dotColor = $derived.by<'green' | 'amber' | 'red' | 'grey'>(() => {
  switch (visualState) {
    case 'thinking':
    case 'tool_call':
    case 'assistant':
    case 'completed': return 'green';
    case 'error': return 'red';
    default: return 'grey';
  }
});

const statusLabel = $derived.by<string>(() => {
  switch (visualState) {
    case 'idle': {
      if (!lastSession) return 'Never run';
      const ago = lastSession.startedAt
        ? formatDistanceToNow(new Date(lastSession.startedAt), { addSuffix: true })
        : null;
      return ago ? `Last run: ${ago}` : 'Never run';
    }
    case 'thinking': return 'Thinking\u2026';
    case 'tool_call':
      return lastEntry && lastEntry.kind === 'tool_call' ? `Using: ${lastEntry.toolName}` : 'Using tool\u2026';
    case 'assistant': return 'Responding\u2026';
    case 'error': return lastEntry && lastEntry.kind === 'system' ? `Error: ${lastEntry.text}` : 'Error';
    case 'completed': {
      if (completedAt && runningSession?.startedAt) {
        const durSec = Math.round((completedAt - new Date(runningSession.startedAt).getTime()) / 1000);
        return `Completed ${durSec}s`;
      }
      return 'Completed';
    }
  }
});

const previewText = $derived.by<string | null>(() => {
  if (!lastEntry) return null;
  switch (lastEntry.kind) {
    case 'thinking': return lastEntry.text;
    case 'assistant': return lastEntry.text;
    case 'tool_call': return JSON.stringify(lastEntry.args).slice(0, 80);
    case 'system': return lastEntry.text;
    case 'stderr': return lastEntry.text;
    default: return null;
  }
});

// ── Interaction ───────────────────────────────────────────────────────────────

function handleClick(): void {
  if (runningSession) {
    goto(`/sessions/${runningSession.id}`);
  } else {
    goto(`/agents/${agent.slug}`);
  }
}

// Last 3 entries for full-mode list (newest-last)
const lastThree = $derived(buffer.slice(-3));
</script>

<!-- Compact: 40px single-line -->
{#if compact}
  <button
    class="alc-compact"
    onclick={handleClick}
    aria-label="{agent.name} — {statusLabel}"
  >
    <StatusDot color={dotColor} pulse={visualState === 'thinking' || visualState === 'tool_call'} />
    <span class="alc-compact__name">{agent.emoji} {agent.name}</span>
    <span class="alc-compact__status">{statusLabel}</span>
  </button>

<!-- Full (or default): 120px with detail -->
{:else}
  <button
    class="alc-card"
    class:alc-card--running={!!runningSession}
    onclick={handleClick}
    aria-label="{agent.name} — {statusLabel}"
  >
    <div class="alc-card__header">
      <ActorAvatar
        actor={{ type: 'agent', id: agent.slug, name: agent.name, emoji: agent.emoji }}
        size="sm"
      />
      <span class="alc-card__name">{agent.name}</span>
      <StatusDot
        color={dotColor}
        pulse={visualState === 'thinking' || visualState === 'tool_call' || visualState === 'assistant'}
        label={statusLabel}
      />
    </div>

    {#if visualState !== 'idle' && previewText}
      <p class="alc-card__preview" class:alc-card__preview--error={visualState === 'error'}>
        {previewText}
      </p>
    {/if}

    {#if full && lastThree.length > 0}
      <ul class="alc-card__entries" aria-label="Recent activity">
        {#each lastThree as entry (entry.id)}
          <li class="alc-card__entry alc-card__entry--{entry.kind}">
            {#if entry.kind === 'tool_call'}
              <span class="alc-entry-kind">tool</span>
              <span class="alc-entry-text">{entry.toolName}</span>
            {:else if entry.kind === 'thinking'}
              <span class="alc-entry-kind">think</span>
              <span class="alc-entry-text">{entry.text.slice(0, 60)}{entry.text.length > 60 ? '\u2026' : ''}</span>
            {:else if entry.kind === 'assistant'}
              <span class="alc-entry-kind">msg</span>
              <span class="alc-entry-text">{entry.text.slice(0, 60)}{entry.text.length > 60 ? '\u2026' : ''}</span>
            {:else if entry.kind === 'system' || entry.kind === 'stderr'}
              <span class="alc-entry-kind alc-entry-kind--err">err</span>
              <span class="alc-entry-text">{entry.text.slice(0, 60)}{entry.text.length > 60 ? '\u2026' : ''}</span>
            {/if}
          </li>
        {/each}
      </ul>
    {/if}
  </button>
{/if}

<style>
  /* ── Compact variant (40px tall single row) ── */
  .alc-compact {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: 0 var(--space-3);
    height: 40px;
    width: 100%;
    border-radius: var(--radius-md);
    border: 1px solid var(--border);
    background: transparent;
    cursor: pointer;
    text-align: left;
    font-family: inherit;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .alc-compact:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  .alc-compact:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .alc-compact__name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    flex: 1;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .alc-compact__status {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    white-space: nowrap;
    flex-shrink: 0;
  }

  /* ── Full/default card (120px) ── */
  .alc-card {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-3);
    min-height: 80px;
    max-height: 120px;
    width: 100%;
    border-radius: var(--radius-md);
    border: 1px solid var(--border);
    background: transparent;
    cursor: pointer;
    text-align: left;
    font-family: inherit;
    overflow: hidden;
    transition: background var(--dur-instant) var(--ease-out), border-color var(--dur-instant) var(--ease-out);
  }

  .alc-card--running {
    border-color: color-mix(in oklch, var(--signal-running) 30%, var(--border) 70%);
    background: color-mix(in oklch, var(--signal-running) 4%, transparent 96%);
  }

  .alc-card:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  .alc-card--running:hover {
    background: color-mix(in oklch, var(--signal-running) 6%, transparent 94%);
  }

  .alc-card:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .alc-card__header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .alc-card__name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    flex: 1;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  /* Preview line: 2-line clamp (thinking/assistant), 1-line clamp (tool) */
  .alc-card__preview {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    margin: 0;
    overflow: hidden;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
    line-height: 1.45;
  }

  .alc-card__preview--error {
    color: var(--signal-error);
  }

  /* Mini entry list (full mode only) */
  .alc-card__entries {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
    overflow: hidden;
  }

  .alc-card__entry {
    display: flex;
    align-items: baseline;
    gap: var(--space-1);
  }

  .alc-entry-kind {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    border-radius: var(--radius-sm);
    padding: 0 4px;
    flex-shrink: 0;
    line-height: 1.5;
  }

  .alc-entry-kind--err {
    color: var(--signal-error);
    background: color-mix(in oklch, var(--signal-error) 12%, transparent 88%);
  }

  .alc-entry-text {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex: 1;
  }

  /* Tool call entry: 1-line clamp for args preview */
  .alc-card__entry--tool_call .alc-entry-text {
    font-family: var(--font-mono);
    font-size: 10px;
    color: color-mix(in oklch, var(--signal-running) 70%, var(--fg-muted) 30%);
  }
</style>
