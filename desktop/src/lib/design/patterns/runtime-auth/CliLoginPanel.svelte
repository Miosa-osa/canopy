<script lang="ts">
/**
 * CliLoginPanel — instructs the user to run the CLI auth command.
 *
 * Canopy never spawns the interactive browser auth flow — the CLI owns that.
 * This panel gives the command to copy, explains what happens, and lets the
 * user trigger a re-detection after they've signed in.
 *
 * CSS prefix: clp-
 */

interface Props {
  /** CLI login command, e.g. "claude auth login" */
  loginCommand: string;
  /** Whether `detect_command` succeeded */
  loggedIn: boolean | null;
  /** Is re-detection running? */
  checking?: boolean;
  onRecheck: () => void;
}

let { loginCommand, loggedIn, checking = false, onRecheck }: Props = $props();

let copied = $state(false);

function copyCommand() {
  void navigator.clipboard.writeText(loginCommand).then(() => {
    copied = true;
    setTimeout(() => { copied = false; }, 2000);
  });
}
</script>

<div class="clp-panel">
  <div class="clp-header">
    <span class="clp-label">CLI login</span>
    {#if loggedIn === true}
      <span class="clp-badge clp-badge--ok">Signed in</span>
    {:else if loggedIn === false}
      <span class="clp-badge clp-badge--muted">Not signed in</span>
    {:else}
      <span class="clp-badge clp-badge--muted">Unknown</span>
    {/if}
  </div>

  {#if loggedIn === true}
    <p class="clp-body">
      CLI is authenticated. Sessions will launch using the CLI's stored credentials.
    </p>
  {:else}
    <p class="clp-body">
      Run this command in your terminal to sign in. Your browser will open to
      complete authentication — Canopy does not handle that step.
    </p>
    <div class="clp-cmd-row">
      <code class="clp-cmd">{loginCommand}</code>
      <button
        class="clp-copy-btn"
        onclick={copyCommand}
        aria-label="Copy login command to clipboard"
      >{copied ? 'Copied' : 'Copy'}</button>
    </div>
    <p class="clp-hint">
      After signing in your terminal, click "Check again" to confirm.
    </p>
  {/if}

  <button
    class="clp-recheck-btn"
    disabled={checking}
    onclick={onRecheck}
    aria-label="Re-run CLI login detection"
  >{checking ? 'Checking…' : 'Check again'}</button>
</div>

<style>
  .clp-panel {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .clp-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .clp-label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    flex: 1;
  }

  .clp-badge {
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

  .clp-badge--ok {
    background: color-mix(in oklch, oklch(70% 0.15 145) 14%, transparent 86%);
    color: oklch(50% 0.15 145);
  }

  .clp-badge--muted {
    background: color-mix(in oklch, var(--fg) 7%, transparent 93%);
    color: var(--fg-subtle);
  }

  .clp-body {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    line-height: 1.5;
  }

  .clp-cmd-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
  }

  .clp-cmd {
    flex: 1;
    font-family: var(--font-mono);
    font-size: 12px;
    color: var(--fg);
    user-select: all;
  }

  .clp-copy-btn {
    flex-shrink: 0;
    min-width: 48px;
    padding: 2px var(--space-2);
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-subtle);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    cursor: pointer;
    text-align: center;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .clp-copy-btn:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .clp-copy-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  .clp-hint {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    line-height: 1.5;
  }

  .clp-recheck-btn {
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

  .clp-recheck-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .clp-recheck-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .clp-recheck-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }
</style>
