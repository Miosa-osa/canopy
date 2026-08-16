<script lang="ts">
/**
 * TerminalHarness — orchestration chrome wrapping TerminalSession.
 *
 * Renders a monochrome toolbar above the xterm pane with session controls
 * and slash-command shortcuts. Does NOT open its own WebSocket — input is
 * routed through TerminalSession.sendInput (one WS per session, period).
 *
 * Toolbar: Pause/Resume · Stop · Restart · Fork · Screenshot · Observe · Slash cmds
 *
 * CSS prefix: th- (TerminalHarness)
 * LOC target: ≤ 280.
 */

import { onMount } from 'svelte';
import { goto } from '$app/navigation';
import {
  cancelSession,
  createSession,
  pauseSession,
  resumeSession,
  stopSession,
} from '$lib/api/queries/sessions.js';
import TerminalSession from '$lib/design/patterns/TerminalSession.svelte';
import { harnessStore } from '$lib/stores/terminal-harness.svelte.js';
import { toasts } from '$lib/stores/toasts.svelte.js';
import type { Session } from '$lib/domain/sessions/types.js';

interface Props {
  sessionId: string;
  session: Session | null;
  isRunning?: boolean;
  isPaused?: boolean;
  /** Propagate pause/resume back to parent for PausedOverlay. */
  onPause?: () => void;
  onResume?: () => void;
  /**
   * Called once the WebSocket channel joins and the terminal is ready to
   * receive input. The parent receives a stable reference to the PTY write
   * function so it can inject prompts from outside the harness.
   */
  onSendReady?: (sendFn: (data: string) => void) => void;
}

let {
  sessionId,
  session,
  isRunning = false,
  isPaused = false,
  onPause,
  onResume,
  onSendReady,
}: Props = $props();

// ── Local state ───────────────────────────────────────────────────────────────

let busy = $state<
  'pause' | 'resume' | 'stop' | 'restart' | 'fork' | 'screenshot' | null
>(null);
let observerOpen = $state(false);
let observerApiKey = $state('');
let observerProvider = $state<'anthropic' | 'openai'>('anthropic');
let forkModalOpen = $state(false);
let forkPrompt = $state('');

// ── Input injection via TerminalSession callback ──────────────────────────────
// TerminalSession calls onReady with its sendInput fn. No second WS needed.

let _sendToTerminal: ((data: string) => void) | null = null;

function handleReady(fn: (data: string) => void): void {
  _sendToTerminal = fn;
  onSendReady?.(fn);
}

function sendInput(data: string): void {
  _sendToTerminal?.(data);
}

// ── Mount: start transcript capture only ─────────────────────────────────────

onMount(() => {
  const stopCapture = harnessStore.startCapture(sessionId);

  return () => {
    stopCapture();
    _sendToTerminal = null;
  };
});

// ── Toolbar actions ───────────────────────────────────────────────────────────

async function handlePause(): Promise<void> {
  busy = 'pause';
  try {
    await pauseSession(sessionId);
    onPause?.();
    toasts.success('Paused — terminal stays alive');
  } catch (err) {
    toasts.error(err instanceof Error ? err.message : 'Pause failed');
  } finally {
    busy = null;
  }
}

async function handleResume(): Promise<void> {
  busy = 'resume';
  try {
    await resumeSession(sessionId);
    onResume?.();
    toasts.success('Resumed');
  } catch (err) {
    toasts.error(err instanceof Error ? err.message : 'Resume failed');
  } finally {
    busy = null;
  }
}

function handleStop(e: MouseEvent): void {
  if (e.shiftKey) {
    // Hard kill.
    busy = 'stop';
    stopSession(sessionId)
      .then(() => toasts.info('Session hard-stopped'))
      .catch((err: unknown) => toasts.error(err instanceof Error ? err.message : 'Stop failed'))
      .finally(() => { busy = null; });
  } else {
    // Soft: send Ctrl+C via channel.
    sendInput('\u0003');
    toasts.info('Sent Ctrl+C — Shift+Stop for hard kill');
  }
}

async function handleRestart(): Promise<void> {
  if (!session) return;
  busy = 'restart';
  try {
    await stopSession(sessionId);
    const newSession = await createSession({
      runtimeType: session.runtimeType,
      cwd: session.cwd ?? '~',
      modelId: session.modelId ?? undefined,
      workspaceSlug: session.workspaceSlug ?? undefined,
      prompt: session.prompt ?? undefined,
    });
    toasts.success('Restarted');
    void goto(`/sessions/${newSession.id}`);
  } catch (err) {
    toasts.error(err instanceof Error ? err.message : 'Restart failed');
    busy = null;
  }
}

async function handleFork(): Promise<void> {
  if (!session) return;
  busy = 'fork';
  forkModalOpen = false;
  try {
    const newSession = await createSession({
      runtimeType: session.runtimeType,
      cwd: session.cwd ?? '~',
      modelId: session.modelId ?? undefined,
      workspaceSlug: session.workspaceSlug ?? undefined,
      prompt: forkPrompt.trim() || session.prompt || undefined,
      parentSessionId: session.id,
    });
    forkPrompt = '';
    toasts.success('Forked session');
    void goto(`/sessions/${newSession.id}`);
  } catch (err) {
    toasts.error(err instanceof Error ? err.message : 'Fork failed');
  } finally {
    busy = null;
  }
}

async function handleScreenshot(): Promise<void> {
  busy = 'screenshot';
  // Fallback: extract transcript text + copy to clipboard.
  const text = harnessStore.transcriptText;
  try {
    await navigator.clipboard.writeText(text);
    toasts.success('Terminal text copied to clipboard');
  } catch {
    toasts.warning('Clipboard unavailable — transcript buffered in memory');
  } finally {
    busy = null;
  }
}

function handleObserve(): void {
  observerOpen = !observerOpen;
  harnessStore.observerStatus = 'idle';
}

async function runObserver(): Promise<void> {
  if (!observerApiKey.trim()) return;
  await harnessStore.runObserver(observerApiKey, observerProvider);
}

function sendSlash(cmd: string): void {
  sendInput(`${cmd}\r`);
}
</script>

<!-- ── Root ──────────────────────────────────────────────────────────────────── -->
<div class="th-root">

  <!-- ── Toolbar ────────────────────────────────────────────────────────────── -->
  <div class="th-toolbar" role="toolbar" aria-label="Terminal harness controls">
    <!-- Pause / Resume -->
    {#if isRunning}
      <button
        class="th-btn"
        class:th-btn--busy={busy === 'pause'}
        onclick={handlePause}
        disabled={busy !== null}
        aria-label="Pause session"
        title="Pause (keeps terminal alive)"
      >
        <span aria-hidden="true">⏸</span>
      </button>
    {:else if isPaused}
      <button
        class="th-btn th-btn--active"
        class:th-btn--busy={busy === 'resume'}
        onclick={handleResume}
        disabled={busy !== null}
        aria-label="Resume session"
        title="Resume"
      >
        <span aria-hidden="true">▶</span>
      </button>
    {/if}

    <!-- Stop (soft: Ctrl+C | Shift+click: hard kill) -->
    <button
      class="th-btn th-btn--danger"
      class:th-btn--busy={busy === 'stop'}
      onclick={handleStop}
      disabled={busy !== null}
      aria-label="Stop session (Shift+click for hard kill)"
      title="Stop — sends Ctrl+C. Shift+click = hard kill"
    >
      <span aria-hidden="true">⏹</span>
    </button>

    <!-- Restart -->
    <button
      class="th-btn"
      class:th-btn--busy={busy === 'restart'}
      onclick={handleRestart}
      disabled={busy !== null || !session}
      aria-label="Restart session"
      title="Restart — stops + spawns sibling session"
    >
      <span aria-hidden="true">↻</span>
    </button>

    <div class="th-divider" aria-hidden="true"></div>

    <!-- Fork -->
    <button
      class="th-btn"
      class:th-btn--active={forkModalOpen}
      class:th-btn--busy={busy === 'fork'}
      onclick={() => { forkModalOpen = !forkModalOpen; }}
      disabled={busy !== null || !session}
      aria-label="Fork session"
      title="Fork — new session from same worktree base branch"
    >
      <span aria-hidden="true">⎇</span>
    </button>

    <!-- Screenshot (text fallback — html2canvas not installed) -->
    <button
      class="th-btn"
      class:th-btn--busy={busy === 'screenshot'}
      onclick={handleScreenshot}
      disabled={busy !== null}
      aria-label="Copy terminal text to clipboard"
      title="Copy transcript text to clipboard"
    >
      <span aria-hidden="true">📋</span>
    </button>

    <!-- Observe -->
    <button
      class="th-btn"
      class:th-btn--active={observerOpen}
      onclick={handleObserve}
      aria-label="Open observer pane"
      title="Observer — sends transcript to AI for review"
    >
      <span aria-hidden="true">🔍</span>
    </button>

    <div class="th-divider" aria-hidden="true"></div>

    <!-- Slash commands -->
    <span class="th-label" aria-hidden="true">≣</span>
    {#each (['/clear', '/compact', '/resume', '/status'] as const) as cmd (cmd)}
      <button
        class="th-slash-btn"
        onclick={() => sendSlash(cmd)}
        aria-label="Send {cmd} to terminal"
        title="Send {cmd}"
      >
        {cmd}
      </button>
    {/each}
  </div>

  <!-- ── Fork modal ─────────────────────────────────────────────────────────── -->
  {#if forkModalOpen}
    <div class="th-popover" role="dialog" aria-label="Fork session">
      <p class="th-popover-label">Fork prompt (optional)</p>
      <textarea
        class="th-popover-input"
        rows="3"
        placeholder="Leave blank to copy current prompt"
        bind:value={forkPrompt}
        aria-label="Fork prompt"
      ></textarea>
      <div class="th-popover-actions">
        <button class="th-popover-cancel" onclick={() => { forkModalOpen = false; forkPrompt = ''; }}>
          Cancel
        </button>
        <button
          class="th-popover-confirm"
          onclick={handleFork}
          disabled={busy === 'fork'}
        >
          {busy === 'fork' ? 'Forking…' : 'Fork'}
        </button>
      </div>
    </div>
  {/if}

  <!-- ── Observer pane ─────────────────────────────────────────────────────── -->
  {#if observerOpen}
    <div class="th-observer" role="complementary" aria-label="Session observer">
      <div class="th-observer-header">
        <span class="th-observer-title">Observer</span>
        <button class="th-observer-close" onclick={() => { observerOpen = false; }} aria-label="Close observer">✕</button>
      </div>

      <div class="th-observer-body">
        {#if harnessStore.observerStatus === 'idle' || harnessStore.observerStatus === 'error'}
          <div class="th-observer-config">
            <select
              class="th-obs-select"
              bind:value={observerProvider}
              aria-label="Observer provider"
            >
              <option value="anthropic">Anthropic (claude-haiku)</option>
              <option value="openai">OpenAI (gpt-4o-mini)</option>
            </select>
            <input
              class="th-obs-input"
              type="password"
              placeholder="API key"
              bind:value={observerApiKey}
              aria-label="Observer API key"
            />
            {#if harnessStore.observerError}
              <p class="th-obs-error">{harnessStore.observerError}</p>
            {:else}
              <p class="th-obs-hint">Key is never sent to Canopy backend — direct API call only.</p>
            {/if}
            <button
              class="th-obs-run"
              onclick={runObserver}
              disabled={!observerApiKey.trim()}
            >
              Analyze session
            </button>
          </div>
        {:else if harnessStore.observerStatus === 'loading'}
          <p class="th-obs-loading">Analyzing…</p>
        {:else if harnessStore.observerStatus === 'done'}
          <div class="th-obs-results">
            {#each harnessStore.observerMessages as msg (msg.content)}
              <p class="th-obs-bubble">{msg.content}</p>
            {/each}
            <button class="th-obs-again" onclick={() => { harnessStore.observerStatus = 'idle'; }}>
              Run again
            </button>
          </div>
        {/if}
      </div>
    </div>
  {/if}

  <!-- ── Terminal ────────────────────────────────────────────────────────────── -->
  <div class="th-terminal-wrap">
    <TerminalSession {sessionId} {isRunning} onReady={handleReady} />
  </div>
</div>

<style>
  .th-root {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-height: 0;
    overflow: hidden;
    position: relative;
  }

  /* ── Toolbar ── */
  .th-toolbar {
    display: flex;
    align-items: center;
    gap: 2px;
    padding: 4px 8px;
    border-bottom: 1px solid var(--border);
    background: color-mix(in oklch, var(--bg-inset) 80%, transparent);
    flex-shrink: 0;
    flex-wrap: wrap;
  }

  .th-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 26px;
    border-radius: var(--radius-sm);
    border: 1px solid transparent;
    background: transparent;
    color: var(--fg-muted);
    font-size: 13px;
    cursor: pointer;
    transition:
      background 0.1s ease,
      color 0.1s ease,
      border-color 0.1s ease;
  }

  .th-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg);
  }

  .th-btn--active {
    background: color-mix(in oklch, var(--cnp-accent) 12%, transparent);
    color: var(--cnp-accent);
    border-color: color-mix(in oklch, var(--cnp-accent) 30%, transparent);
  }

  .th-btn--danger:hover:not(:disabled) {
    color: var(--signal-error, oklch(0.65 0.2 25));
    border-color: color-mix(in oklch, var(--signal-error, oklch(0.65 0.2 25)) 30%, transparent);
    background: color-mix(in oklch, var(--signal-error, oklch(0.65 0.2 25)) 8%, transparent);
  }

  .th-btn--busy {
    opacity: 0.5;
    cursor: wait;
  }

  .th-btn:disabled {
    opacity: 0.35;
    cursor: not-allowed;
  }

  .th-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .th-divider {
    width: 1px;
    height: 16px;
    background: var(--border);
    margin: 0 4px;
    flex-shrink: 0;
  }

  .th-label {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-subtle);
    padding: 0 4px;
    user-select: none;
  }

  .th-slash-btn {
    font-family: var(--font-mono);
    font-size: 10px;
    padding: 2px 6px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-subtle);
    cursor: pointer;
    transition: color 0.1s ease, border-color 0.1s ease;
    white-space: nowrap;
  }

  .th-slash-btn:hover {
    color: var(--cnp-accent);
    border-color: var(--cnp-accent);
  }

  .th-slash-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  /* ── Fork popover ── */
  .th-popover {
    position: absolute;
    top: 38px;
    left: 80px;
    z-index: 50;
    background: var(--bg-overlay, var(--bg-inset));
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    padding: var(--space-3);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    width: 280px;
    box-shadow: 0 4px 24px color-mix(in oklch, black 40%, transparent);
  }

  .th-popover-label {
    font-size: 11px;
    font-weight: 500;
    color: var(--fg-muted);
    margin: 0;
    font-family: var(--font-sans);
  }

  .th-popover-input {
    width: 100%;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: var(--space-2);
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg);
    resize: none;
    outline: none;
  }

  .th-popover-input:focus {
    border-color: var(--cnp-accent);
  }

  .th-popover-actions {
    display: flex;
    justify-content: flex-end;
    gap: var(--space-2);
  }

  .th-popover-cancel,
  .th-popover-confirm {
    font-size: 11px;
    font-family: var(--font-sans);
    font-weight: 500;
    padding: 3px 10px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-muted);
    cursor: pointer;
    transition: color 0.1s ease, border-color 0.1s ease;
  }

  .th-popover-confirm {
    border-color: var(--cnp-accent);
    color: var(--cnp-accent);
  }

  .th-popover-confirm:hover:not(:disabled) {
    background: color-mix(in oklch, var(--cnp-accent) 12%, transparent);
  }

  .th-popover-cancel:hover {
    color: var(--fg);
  }

  /* ── Observer pane ── */
  .th-observer {
    border-bottom: 1px solid var(--border);
    background: color-mix(in oklch, var(--bg-inset) 60%, transparent);
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    max-height: 260px;
  }

  .th-observer-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 6px 10px;
    border-bottom: 1px solid var(--border);
  }

  .th-observer-title {
    font-family: var(--font-mono);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--fg-subtle);
  }

  .th-observer-close {
    background: transparent;
    border: none;
    color: var(--fg-subtle);
    cursor: pointer;
    font-size: 11px;
    padding: 0 4px;
    line-height: 1;
  }

  .th-observer-close:hover { color: var(--fg); }

  .th-observer-body {
    padding: var(--space-3);
    overflow-y: auto;
    flex: 1;
    scrollbar-width: thin;
  }

  .th-observer-config {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .th-obs-select,
  .th-obs-input {
    font-size: 11px;
    font-family: var(--font-mono);
    padding: 4px 8px;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--bg-inset);
    color: var(--fg);
    outline: none;
    width: 100%;
  }

  .th-obs-select:focus,
  .th-obs-input:focus { border-color: var(--cnp-accent); }

  .th-obs-hint {
    font-size: 10px;
    color: var(--fg-subtle);
    margin: 0;
    font-family: var(--font-sans);
  }

  .th-obs-error {
    font-size: 10px;
    color: var(--signal-error, oklch(0.65 0.2 25));
    margin: 0;
  }

  .th-obs-run,
  .th-obs-again {
    font-size: 11px;
    font-family: var(--font-sans);
    font-weight: 600;
    padding: 4px 12px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--cnp-accent);
    background: color-mix(in oklch, var(--cnp-accent) 10%, transparent);
    color: var(--cnp-accent);
    cursor: pointer;
    align-self: flex-start;
    transition: background 0.1s ease;
  }

  .th-obs-run:hover:not(:disabled),
  .th-obs-again:hover {
    background: color-mix(in oklch, var(--cnp-accent) 18%, transparent);
  }

  .th-obs-run:disabled { opacity: 0.4; cursor: not-allowed; }

  .th-obs-loading {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-subtle);
    margin: 0;
  }

  .th-obs-results {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .th-obs-bubble {
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--fg);
    line-height: 1.6;
    margin: 0;
    padding: var(--space-2) var(--space-3);
    background: color-mix(in oklch, var(--fg) 5%, transparent);
    border-radius: var(--radius-md);
    border-left: 2px solid var(--cnp-accent);
    white-space: pre-wrap;
  }

  /* ── Terminal wrap ── */
  .th-terminal-wrap {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  @media (prefers-reduced-motion: reduce) {
    .th-btn,
    .th-slash-btn,
    .th-obs-run,
    .th-obs-again { transition: none; }
  }
</style>
