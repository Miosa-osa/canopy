<script lang="ts">
/**
 * SubscriptionDetectPanel — shows CLI subscription detection status.
 * If a subscription file or env var was found, surfaces a success state.
 * If not, gives the user instructions to run `<cli> auth login`.
 *
 * This panel never tries to launch the CLI browser flow from within Canopy —
 * it detects what the CLI already did and reports it.
 *
 * CSS prefix: sdp-
 */

interface Props {
  /** Name of the CLI, e.g. "Claude Code" */
  runtimeName: string;
  /** Whether detection found a subscription credential */
  detected: boolean | null;
  /** File path checked, e.g. ~/.claude/credentials.json */
  checkPath?: string | null;
  /** Is a re-check in progress? */
  checking?: boolean;
  onRecheck: () => void;
}

let { runtimeName, detected, checkPath = null, checking = false, onRecheck }: Props = $props();
</script>

<div class="sdp-panel">
  <div class="sdp-header">
    <span class="sdp-label">Subscription</span>
    {#if detected === true}
      <span class="sdp-badge sdp-badge--ok">Detected</span>
    {:else if detected === false}
      <span class="sdp-badge sdp-badge--muted">Not found</span>
    {:else}
      <span class="sdp-badge sdp-badge--muted">Checking…</span>
    {/if}
  </div>

  {#if detected === true}
    <p class="sdp-body">
      {runtimeName} subscription detected
      {#if checkPath}<span class="sdp-mono">({checkPath})</span>{/if}.
      No action needed — sessions will launch with your existing credentials.
    </p>
  {:else if detected === false}
    <p class="sdp-body">
      No {runtimeName} subscription found. Run the login command in your terminal
      to authenticate with your account:
    </p>
    <div class="sdp-cmd-row">
      <code class="sdp-cmd">claude auth login</code>
      <button
        class="sdp-copy-btn"
        onclick={() => void navigator.clipboard.writeText('claude auth login')}
        aria-label="Copy login command to clipboard"
      >Copy</button>
    </div>
    <p class="sdp-hint">
      Your browser will open. Complete the sign-in there, then return here and
      click "Check again".
    </p>
  {/if}

  <button
    class="sdp-recheck-btn"
    disabled={checking}
    onclick={onRecheck}
    aria-label="Re-run subscription detection"
  >{checking ? 'Checking…' : 'Check again'}</button>
</div>

<style>
  .sdp-panel {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .sdp-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .sdp-label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    flex: 1;
  }

  .sdp-badge {
    display: inline-flex;
    align-items: center;
    height: 18px;
    padding: 0 var(--space-2);
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }

  .sdp-badge--ok {
    background: color-mix(in oklch, oklch(70% 0.15 145) 14%, transparent 86%);
    color: oklch(50% 0.15 145);
  }

  .sdp-badge--muted {
    background: color-mix(in oklch, var(--fg) 7%, transparent 93%);
    color: var(--fg-subtle);
  }

  .sdp-body {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    line-height: 1.5;
  }

  .sdp-mono {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-subtle);
  }

  .sdp-cmd-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
  }

  .sdp-cmd {
    flex: 1;
    font-family: var(--font-mono);
    font-size: 12px;
    color: var(--fg);
    user-select: all;
  }

  .sdp-copy-btn {
    flex-shrink: 0;
    padding: 2px var(--space-2);
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-subtle);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    cursor: pointer;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .sdp-copy-btn:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .sdp-copy-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  .sdp-hint {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    line-height: 1.5;
  }

  .sdp-recheck-btn {
    align-self: flex-start;
    padding: var(--space-1) var(--space-3);
    border-radius: 9999px;
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    cursor: pointer;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out),
      border-color var(--dur-instant) var(--ease-out);
  }

  .sdp-recheck-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .sdp-recheck-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .sdp-recheck-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }
</style>
