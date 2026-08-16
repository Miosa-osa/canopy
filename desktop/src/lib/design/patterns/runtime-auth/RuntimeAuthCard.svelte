<script lang="ts">
/**
 * RuntimeAuthCard — one table row per runtime.
 * Shows: name, kind pill, status pill, version, auth status pill, actions.
 *
 * No blue. Auth status pill uses --success green or var(--fg-subtle) muted.
 * "Configure" pill is monochrome (no accent unless hovered).
 * Sign in button is gone — replaced by the auth status pill + Configure link.
 *
 * CSS prefix: rac-
 */
import type { Runtime } from '$lib/domain/runtimes/types.js';

interface Props {
  runtime: Runtime;
  authStatus: 'subscription' | 'cli_login' | 'api_key' | 'none' | 'error';
  onTest: () => void;
}

let { runtime, authStatus, onTest }: Props = $props();

const isInstalled = $derived(runtime.status === 'installed');

const kindLabel = $derived(
  runtime.kind === 'cli'
    ? 'CLI'
    : runtime.kind === 'api'
      ? 'API'
      : runtime.kind === 'local_model'
        ? 'Local'
        : runtime.kind ?? '—',
);

const authLabel = $derived<string>(
  authStatus === 'subscription'
    ? 'Signed in'
    : authStatus === 'cli_login'
      ? 'Signed in'
      : authStatus === 'api_key'
        ? 'API key'
        : authStatus === 'error'
          ? 'Error'
          : 'Not authenticated',
);

const isAuthenticated = $derived(
  authStatus === 'subscription' || authStatus === 'cli_login' || authStatus === 'api_key',
);

const statusLabel = $derived<string>(
  runtime.status === 'installed'
    ? 'Installed'
    : runtime.status === 'not_installed'
      ? 'Not installed'
      : runtime.status === 'misconfigured'
        ? 'Misconfigured'
        : runtime.status === 'error'
          ? 'Error'
          : runtime.status,
);
</script>

<tr class="rac-row">
  <!-- Name -->
  <td class="rac-cell rac-cell--name">
    <a href="/settings/runtimes/{runtime.type}" class="rac-name-link">{runtime.name}</a>
  </td>

  <!-- Kind — uses actual runtime.kind, not capability inference -->
  <td class="rac-cell">
    <span class="rac-badge">{kindLabel}</span>
  </td>

  <!-- Installed status -->
  <td class="rac-cell">
    <span
      class="rac-badge"
      class:rac-badge--ok={isInstalled}
      class:rac-badge--muted={!isInstalled}
    >{statusLabel}</span>
  </td>

  <!-- Version -->
  <td class="rac-cell rac-cell--mono">
    {runtime.version ?? '—'}
  </td>

  <!-- Auth status — pill only, no button -->
  <td class="rac-cell">
    <span
      class="rac-badge"
      class:rac-badge--ok={isAuthenticated}
      class:rac-badge--warn={authStatus === 'error'}
      class:rac-badge--muted={authStatus === 'none'}
    >{authLabel}</span>
  </td>

  <!-- Actions — Configure (always) + Test (if authenticated) -->
  <td class="rac-cell rac-cell--actions">
    {#if isAuthenticated}
      <button class="rac-action-btn" onclick={onTest} aria-label="Test {runtime.name} connection">
        Test
      </button>
    {/if}
    <a
      href="/settings/runtimes/{runtime.type}"
      class="rac-action-btn"
      aria-label="Configure {runtime.name} authentication"
    >Configure</a>
  </td>
</tr>

<style>
  .rac-row {
    border-bottom: 1px solid var(--border);
    transition: background var(--dur-instant) var(--ease-out);
  }

  .rac-row:last-child {
    border-bottom: none;
  }

  .rac-row:hover {
    background: color-mix(in oklch, var(--fg) 3%, transparent 97%);
  }

  .rac-cell {
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    vertical-align: middle;
    white-space: nowrap;
  }

  .rac-cell--name {
    font-weight: 500;
    color: var(--fg);
  }

  .rac-cell--mono {
    font-family: var(--font-mono);
    font-size: 11px;
  }

  .rac-cell--actions {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    justify-content: flex-end;
  }

  /* ── Name link ── */

  .rac-name-link {
    color: var(--fg);
    text-decoration: none;
    font-weight: 500;
  }

  .rac-name-link:hover {
    color: var(--cnp-accent);
  }

  .rac-name-link:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
    border-radius: 2px;
  }

  /* ── Badges ── */

  .rac-badge {
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
    background: color-mix(in oklch, var(--fg) 7%, transparent 93%);
    color: var(--fg-subtle);
  }

  .rac-badge--ok {
    background: color-mix(in oklch, oklch(70% 0.15 145) 14%, transparent 86%);
    color: oklch(50% 0.15 145);
  }

  .rac-badge--warn {
    background: color-mix(in oklch, oklch(65% 0.2 25) 12%, transparent 88%);
    color: oklch(50% 0.2 25);
  }

  .rac-badge--muted {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg-subtle);
  }

  /* ── Action buttons ── */

  .rac-action-btn {
    display: inline-flex;
    align-items: center;
    height: 26px;
    padding: 0 var(--space-2);
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    cursor: pointer;
    text-decoration: none;
    white-space: nowrap;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out),
      border-color var(--dur-instant) var(--ease-out);
  }

  .rac-action-btn:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .rac-action-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }
</style>
