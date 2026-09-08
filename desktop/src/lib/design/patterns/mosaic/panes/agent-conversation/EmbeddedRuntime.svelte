<script lang="ts">
/**
 * EmbeddedRuntime — wraps an existing runtime session inside an
 * AgentConversationPane. Renders the runtime's live terminal output
 * and exposes a header strip with status + "End runtime" affordance.
 *
 * REUSE — does NOT reimplement xterm. Renders <TerminalSession>
 * (the same primitive RuntimeTerminalPane uses) under the hood.
 *
 * The pane owns the lifecycle config; this component is purely
 * presentational + emits events upward.
 *
 * CSS prefix: emr-
 */
import { type CreateQueryOptions, createMutation, createQuery } from '@tanstack/svelte-query';
import { Square } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { cancelSessionMutation, sessionDetailQuery } from '$lib/api/queries/sessions.js';
import TerminalSession from '$lib/design/patterns/TerminalSession.svelte';
import type { SessionDetail } from '$lib/domain/sessions/types.js';

interface Props {
  /** Runtime type label (e.g. "claude-local"). */
  runtimeType: string;
  /** The session id this runtime is bound to. */
  sessionId: string;
  /** Bubble up the sendInput function so the composer can pipe keystrokes. */
  onSendInputReady?: (sendInput: (data: string) => void) => void;
  /** Fires when the user clicks "End runtime". Parent unsets
   *  pane.config.embeddedRuntime. */
  onEnd?: () => void;
}

let { runtimeType, sessionId, onSendInputReady, onEnd }: Props = $props();

// ── Status query (reuses sessionDetailQuery — no new fetcher) ──────────────
const optsStore = writable(
  untrack(() => sessionDetailQuery(sessionId) as CreateQueryOptions<SessionDetail>)
);
$effect(() => {
  optsStore.set(sessionDetailQuery(sessionId) as CreateQueryOptions<SessionDetail>);
});
const detailQ = createQuery<SessionDetail>(optsStore);

const status = $derived<string>($detailQ.data?.session.status ?? 'starting');

// Map raw status → semantic dot class.
const statusTone = $derived<'running' | 'paused' | 'completed' | 'failed' | 'starting'>(
  status === 'running' || status === 'active'
    ? 'running'
    : status === 'paused'
      ? 'paused'
      : status === 'failed' || status === 'cancelled'
        ? 'failed'
        : status === 'completed' || status === 'ended'
          ? 'completed'
          : 'starting'
);

// ── End runtime mutation (reuses cancelSessionMutation) ────────────────────
const cancel = createMutation(cancelSessionMutation());

function handleEnd(): void {
  if (!sessionId) return;
  $cancel.mutate(sessionId, {
    onSettled: () => onEnd?.(),
  });
}

// ── Pretty label per runtime type ──────────────────────────────────────────
const runtimeLabel = $derived<string>(
  runtimeType === 'claude-local'
    ? 'Claude Code'
    : runtimeType === 'codex-local'
      ? 'Codex'
      : runtimeType === 'gemini-local'
        ? 'Gemini'
        : runtimeType
);
</script>

<div class="emr-root" data-runtime={runtimeType}>
  <header class="emr-head" role="banner" aria-label="Embedded runtime">
    <span class="emr-dot emr-dot--{statusTone}" aria-hidden="true"></span>
    <span class="emr-label">{runtimeLabel}</span>
    <span class="emr-status" aria-live="polite">{status}</span>
    <span class="emr-spacer"></span>
    <button
      type="button"
      class="emr-end"
      onclick={handleEnd}
      aria-label="End runtime"
      title="End runtime"
      disabled={$cancel.isPending}
    >
      <Square size={11} aria-hidden="true" />
      <span>End runtime</span>
    </button>
  </header>

  <div class="emr-body">
    {#key sessionId}
      <TerminalSession
        {sessionId}
        isRunning={true}
        onReady={(send) => onSendInputReady?.(send)}
      />
    {/key}
  </div>
</div>

<style>
  .emr-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 0;
    background: var(--bg);
  }

  .emr-head {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 12px;
    border-bottom: 1px solid var(--border, rgba(255, 255, 255, 0.08));
    background: var(--bg-elev, var(--bg));
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-muted);
  }

  .emr-spacer {
    flex: 1;
  }

  .emr-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: var(--fg-subtle);
    flex-shrink: 0;
  }

  .emr-dot--running {
    background: oklch(0.72 0.18 145);
    box-shadow: 0 0 6px color-mix(in oklch, oklch(0.72 0.18 145) 60%, transparent);
  }
  .emr-dot--paused   { background: oklch(0.78 0.14 85); }
  .emr-dot--failed   { background: oklch(0.62 0.22 25); }
  .emr-dot--completed { background: var(--fg-muted); }
  .emr-dot--starting {
    background: var(--fg-subtle);
    animation: emr-blink 1s ease-in-out infinite;
  }

  @keyframes emr-blink {
    0%, 100% { opacity: 0.35; }
    50%       { opacity: 1; }
  }

  .emr-label {
    font-weight: 500;
    color: var(--fg);
  }

  .emr-status {
    font-family: var(--font-mono);
    font-size: 10.5px;
    color: var(--fg-subtle);
    text-transform: lowercase;
  }

  .emr-end {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 2px 8px;
    height: 22px;
    border: 1px solid var(--border, rgba(255, 255, 255, 0.10));
    background: transparent;
    border-radius: 999px;
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: 11px;
    cursor: pointer;
    transition: background 80ms ease-out, color 80ms ease-out, border-color 80ms ease-out;
  }

  .emr-end:hover:not([disabled]) {
    background: color-mix(in oklch, oklch(0.62 0.22 25) 14%, transparent);
    color: oklch(0.72 0.20 25);
    border-color: color-mix(in oklch, oklch(0.62 0.22 25) 40%, transparent);
  }

  .emr-end[disabled] {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .emr-body {
    flex: 1;
    min-height: 0;
    position: relative;
    overflow: hidden;
  }
</style>
