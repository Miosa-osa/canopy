<script lang="ts">
/**
 * ToastContainer — fixed bottom-right overlay that renders the global toast stack.
 * Shows up to 3 toasts simultaneously. Slide-in-right enter animation.
 * CSS prefix: tc- (ToastContainer)
 * LOC target: ≤ 100.
 *
 * Mount once in +layout.svelte:
 *   <ToastContainer />
 */
import { type Toast, toasts } from '$lib/stores/toasts.svelte.js';

const ICON: Record<string, string> = {
  info: 'ℹ',
  success: '✓',
  warning: '⚠',
  error: '✕',
};

const visible = $derived(toasts.items.slice(-3));

function dismiss(id: string): void {
  toasts.dismiss(id);
}

function kindLabel(kind: Toast['kind']): string {
  return kind.charAt(0).toUpperCase() + kind.slice(1);
}
</script>

<div class="tc-region" aria-live="polite" aria-label="Notifications" role="status">
  {#each visible as toast (toast.id)}
    <div
      class="tc-toast tc-toast--{toast.kind}"
      role="alert"
      aria-atomic="true"
    >
      <span class="tc-icon" aria-label={kindLabel(toast.kind)}>{ICON[toast.kind]}</span>
      <span class="tc-message">{toast.message}</span>
      <button
        class="tc-dismiss"
        onclick={() => dismiss(toast.id)}
        aria-label="Dismiss notification"
      >
        ✕
      </button>
    </div>
  {/each}
</div>

<style>
  .tc-region {
    position: fixed;
    bottom: var(--space-6, 1.5rem);
    right: var(--space-6, 1.5rem);
    z-index: 9000;
    display: flex;
    flex-direction: column;
    gap: var(--space-2, 0.5rem);
    width: 320px;
    pointer-events: none;
  }

  .tc-toast {
    display: flex;
    align-items: center;
    gap: var(--space-3, 0.75rem);
    padding: var(--space-3, 0.75rem) var(--space-4, 1rem);
    border-radius: 8px;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    color: var(--fg);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    line-height: 1.5;
    pointer-events: all;
    animation: slide-in-right var(--dur-fast) var(--ease-out) both;
    box-shadow: 0 4px 12px oklch(0 0 0 / 0.4);
  }

  .tc-toast--success {
    border-color: var(--signal-running);
  }

  .tc-toast--warning {
    border-color: var(--signal-warn);
  }

  .tc-toast--error {
    border-color: var(--signal-error);
  }

  .tc-icon {
    flex-shrink: 0;
    font-size: var(--text-base);
    color: var(--fg-muted);
  }

  .tc-toast--success .tc-icon {
    color: var(--signal-running);
  }

  .tc-toast--warning .tc-icon {
    color: var(--signal-warn);
  }

  .tc-toast--error .tc-icon {
    color: var(--signal-error);
  }

  .tc-message {
    flex: 1;
    color: var(--fg);
  }

  .tc-dismiss {
    flex-shrink: 0;
    background: none;
    border: none;
    cursor: pointer;
    color: var(--fg-subtle);
    font-size: var(--text-xs);
    padding: 2px 4px;
    border-radius: 4px;
    line-height: 1;
    transition: color var(--dur-instant) var(--ease-out);
  }

  .tc-dismiss:hover {
    color: var(--fg);
  }

  .tc-dismiss:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 2px;
  }
</style>
