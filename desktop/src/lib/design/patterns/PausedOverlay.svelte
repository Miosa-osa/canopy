<script lang="ts">
  /**
   * PausedOverlay — semi-transparent overlay shown over a terminal when the
   * session is paused. Exposes a "Resume" action button.
   * CSS prefix: po- (PausedOverlay)
   */

  interface Props {
    onResume: () => void;
    isPending?: boolean;
  }

  let { onResume, isPending = false }: Props = $props();
</script>

<div class="po-overlay" role="status" aria-label="Session paused">
  <div class="po-content">
    <span class="po-dot" aria-hidden="true"></span>
    <span class="po-label">Paused — resume to continue streaming</span>
    <button
      class="po-resume-btn"
      onclick={onResume}
      disabled={isPending}
      aria-busy={isPending}
    >
      {isPending ? 'Resuming…' : 'Resume'}
    </button>
  </div>
</div>

<style>
  .po-overlay {
    position: absolute;
    inset: 0;
    z-index: 10;
    background: color-mix(in oklch, var(--bg) 70%, transparent);
    backdrop-filter: blur(2px);
    -webkit-backdrop-filter: blur(2px);
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: inherit;
  }

  .po-content {
    display: flex;
    align-items: center;
    gap: var(--space-3, 0.75rem);
    padding: var(--space-3, 0.75rem) var(--space-4, 1rem);
    border-radius: var(--radius-lg, 8px);
    border: 1px solid var(--border);
    background: var(--bg-elevated, rgba(20, 20, 20, 0.92));
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3);
  }

  .po-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: var(--priority, oklch(0.78 0.15 70));
    flex-shrink: 0;
    animation: po-pulse 2s ease-in-out infinite;
  }

  @keyframes po-pulse {
    0%, 100% { opacity: 0.4; }
    50%       { opacity: 1; }
  }

  .po-label {
    font-family: var(--font-mono);
    font-size: var(--text-xs, 0.75rem);
    color: var(--fg-muted);
    white-space: nowrap;
  }

  .po-resume-btn {
    padding: 3px 10px;
    border-radius: var(--radius-sm, 4px);
    border: 1px solid var(--border);
    background: color-mix(in oklch, var(--priority, oklch(0.78 0.15 70)) 12%, transparent);
    color: var(--priority, oklch(0.78 0.15 70));
    font-family: var(--font-mono);
    font-size: var(--text-xs, 0.75rem);
    font-weight: 600;
    cursor: pointer;
    flex-shrink: 0;
    transition: background var(--dur-instant, 80ms) ease, border-color var(--dur-instant, 80ms) ease;
  }

  .po-resume-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--priority, oklch(0.78 0.15 70)) 22%, transparent);
    border-color: color-mix(in oklch, var(--priority, oklch(0.78 0.15 70)) 50%, transparent);
  }

  .po-resume-btn:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .po-resume-btn:focus-visible {
    outline: 2px solid var(--priority, oklch(0.78 0.15 70));
    outline-offset: 2px;
  }
</style>
