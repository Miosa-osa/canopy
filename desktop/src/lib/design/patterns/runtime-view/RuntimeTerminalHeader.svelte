<script lang="ts">
/**
 * RuntimeTerminalHeader — collapsible header bar for the runtime terminal view.
 *
 * Shows runtime name, version, binary path, auth status pill, and detach button.
 * Collapse toggle is exposed via callback so parent can persist state.
 *
 * CSS prefix: rth-
 */
import { goto } from '$app/navigation';
import type { RuntimeDetail } from '$lib/domain/runtimes/types.js';

interface Props {
  runtime: RuntimeDetail;
  collapsed: boolean;
  onToggleCollapse: () => void;
  onDetach: () => void;
  isDetaching?: boolean;
}

let {
  runtime,
  collapsed,
  onToggleCollapse,
  onDetach,
  isDetaching = false,
}: Props = $props();

const isAuthenticated = $derived(
  runtime.status === 'installed' || runtime.status === 'misconfigured'
);

const authLabel = $derived(
  runtime.status === 'installed'
    ? 'Authenticated'
    : runtime.status === 'misconfigured'
      ? 'Misconfigured'
      : 'Not signed in'
);

const authVariant = $derived<'ok' | 'warn' | 'off'>(
  runtime.status === 'installed'
    ? 'ok'
    : runtime.status === 'misconfigured'
      ? 'warn'
      : 'off'
);
</script>

<header class="rth-root" class:rth-root--collapsed={collapsed} aria-label="Runtime header">
  <!-- Left: identity -->
  <div class="rth-identity">
    <button
      class="rth-collapse-btn"
      onclick={onToggleCollapse}
      aria-label={collapsed ? 'Expand header' : 'Collapse header'}
      title={collapsed ? 'Expand' : 'Collapse'}
    >
      <span class="rth-chevron" class:rth-chevron--up={!collapsed} aria-hidden="true">›</span>
    </button>

    <div class="rth-name-row">
      <span class="rth-name">{runtime.name}</span>
      {#if runtime.version}
        <span class="rth-version">{runtime.version}</span>
      {/if}
      {#if runtime.binaryPath && !collapsed}
        <span class="rth-binary">{runtime.binaryPath}</span>
      {/if}
    </div>

    <span class="rth-auth-pill" data-variant={authVariant} aria-label="Auth status: {authLabel}">
      {authLabel}
    </span>
  </div>

  <!-- Right: actions -->
  <div class="rth-actions">
    {#if !isAuthenticated}
      <button
        class="rth-btn rth-btn--accent"
        onclick={() => goto(`/settings/runtimes/${runtime.type}`)}
        aria-label="Go to runtime settings to sign in"
      >
        Sign in
      </button>
    {/if}

    <button
      class="rth-btn"
      onclick={onDetach}
      disabled={isDetaching}
      aria-label="Detach and end session"
    >
      {isDetaching ? 'Ending…' : 'End session'}
    </button>
  </div>
</header>

<style>
  .rth-root {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
    padding: 0 var(--space-4);
    height: 52px;
    flex-shrink: 0;
    border-bottom: 1px solid var(--border);
    background: var(--bg-elevated);
    transition: height 0.15s var(--ease-out);
    overflow: hidden;
  }

  .rth-root--collapsed {
    height: 40px;
  }

  .rth-identity {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    min-width: 0;
    flex: 1;
  }

  .rth-collapse-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    border-radius: var(--radius-sm);
    border: none;
    background: transparent;
    color: var(--fg-subtle);
    cursor: pointer;
    flex-shrink: 0;
    transition: color 0.1s ease, background 0.1s ease;
    padding: 0;
  }

  .rth-collapse-btn:hover {
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
  }

  .rth-collapse-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  .rth-chevron {
    font-size: 16px;
    line-height: 1;
    display: inline-block;
    transform: rotate(90deg);
    transition: transform 0.15s var(--ease-out);
    user-select: none;
  }

  .rth-chevron--up {
    transform: rotate(-90deg);
  }

  .rth-name-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    min-width: 0;
    overflow: hidden;
  }

  .rth-name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    white-space: nowrap;
  }

  .rth-version {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    white-space: nowrap;
  }

  .rth-binary {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 260px;
  }

  .rth-auth-pill {
    display: inline-flex;
    align-items: center;
    height: 18px;
    padding: 0 7px;
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    flex-shrink: 0;
    background: color-mix(in oklch, var(--fg) 7%, transparent 93%);
    color: var(--fg-subtle);
    border: 1px solid var(--border);
  }

  .rth-auth-pill[data-variant='ok'] {
    background: color-mix(in oklch, oklch(70% 0.15 145) 14%, transparent 86%);
    color: oklch(50% 0.15 145);
    border-color: color-mix(in oklch, oklch(70% 0.15 145) 25%, transparent 75%);
  }

  .rth-auth-pill[data-variant='warn'] {
    background: color-mix(in oklch, oklch(75% 0.18 80) 14%, transparent 86%);
    color: oklch(50% 0.18 80);
    border-color: color-mix(in oklch, oklch(75% 0.18 80) 25%, transparent 75%);
  }

  .rth-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
  }

  .rth-btn {
    display: inline-flex;
    align-items: center;
    padding: 4px 12px;
    border-radius: 9999px;
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    cursor: pointer;
    white-space: nowrap;
    transition: background 0.1s ease, color 0.1s ease, border-color 0.1s ease;
  }

  .rth-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .rth-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .rth-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .rth-btn--accent {
    background: var(--cnp-accent);
    border-color: var(--cnp-accent);
    color: oklch(100% 0 0);
  }

  .rth-btn--accent:hover:not(:disabled) {
    background: color-mix(in oklch, var(--cnp-accent) 85%, oklch(0% 0 0) 15%);
    border-color: color-mix(in oklch, var(--cnp-accent) 85%, oklch(0% 0 0) 15%);
    color: oklch(100% 0 0);
  }
</style>
