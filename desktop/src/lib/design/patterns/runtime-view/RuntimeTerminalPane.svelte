<script lang="ts">
/**
 * RuntimeTerminalPane — the terminal pane content:
 * unauthenticated overlay, spawning overlay, error overlay, or live terminal.
 * CSS prefix: rtv- (shared with runtimes/[type]/+page).
 */
import { goto } from '$app/navigation';
import TerminalSession from '$lib/design/patterns/TerminalSession.svelte';

interface Props {
  runtimeType: string;
  runtimeName: string;
  isAuthenticated: boolean;
  isSpawning: boolean;
  isLoading: boolean;
  sessionId: string | null;
  spawnError: string | null;
  onRetry: () => void;
}

let {
  runtimeType,
  runtimeName,
  isAuthenticated,
  isSpawning,
  isLoading,
  sessionId,
  spawnError,
  onRetry,
}: Props = $props();
</script>

{#if !isAuthenticated && runtimeName}
  <div class="rtv-overlay" role="status" aria-live="polite">
    <div class="rtv-overlay-card">
      <p class="rtv-overlay-msg">Sign in to {runtimeName} to open a terminal.</p>
      <button
        class="rtv-overlay-btn"
        onclick={() => goto(`/settings/runtimes/${runtimeType}`)}
        aria-label="Go to runtime settings to authenticate"
      >
        Sign in
      </button>
    </div>
  </div>

{:else if isSpawning || (!sessionId && !spawnError && isLoading)}
  <div class="rtv-overlay" role="status" aria-live="polite">
    <div class="rtv-connecting-row">
      <span class="rtv-connecting-dot" aria-hidden="true"></span>
      <span class="rtv-connecting-text">
        {isSpawning ? 'Starting session…' : 'Loading runtime…'}
      </span>
    </div>
  </div>

{:else if spawnError}
  <div class="rtv-overlay" role="alert">
    <div class="rtv-overlay-card">
      <p class="rtv-overlay-msg rtv-overlay-msg--error">{spawnError}</p>
      <button
        class="rtv-overlay-btn"
        onclick={onRetry}
        aria-label="Retry session spawn"
      >
        Retry
      </button>
    </div>
  </div>

{:else if sessionId}
  {#key sessionId}
    <TerminalSession {sessionId} isRunning={true} />
  {/key}
{/if}

<style>
  /* Overlays (unauthenticated, spawning, error) */
  .rtv-overlay {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--bg);
    z-index: 2;
  }

  .rtv-overlay-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-4);
    padding: var(--space-6) var(--space-8);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    background: var(--bg-elevated);
  }

  .rtv-overlay-msg {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    text-align: center;
    line-height: 1.5;
  }

  .rtv-overlay-msg--error {
    color: oklch(60% 0.2 25);
  }

  .rtv-overlay-btn {
    padding: 7px 20px;
    border-radius: 9999px;
    border: none;
    background: var(--cnp-accent);
    color: oklch(100% 0 0);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    cursor: pointer;
    transition: background 0.1s ease;
  }

  .rtv-overlay-btn:hover {
    background: color-mix(in oklch, var(--cnp-accent) 85%, oklch(0% 0 0) 15%);
  }

  .rtv-overlay-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 3px;
  }

  /* Connecting state */
  .rtv-connecting-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  .rtv-connecting-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--fg-subtle);
    animation: rtv-blink 1s ease-in-out infinite;
  }

  .rtv-connecting-text {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  @keyframes rtv-blink {
    0%, 100% { opacity: 0.3; }
    50%       { opacity: 1; }
  }

  /* Transcript fallback */
  .rtv-transcript-placeholder {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: var(--space-8);
  }

  .rtv-transcript-text {
    margin: 0;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    font-style: italic;
  }
</style>
