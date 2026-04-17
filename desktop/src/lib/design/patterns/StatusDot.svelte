<script lang="ts">
/**
 * StatusDot — small colored dot with optional label.
 * Used to indicate running / idle / warn / error states.
 * LOC target: ≤ 40.
 */

interface Props {
  color?: 'green' | 'grey' | 'amber' | 'red';
  label?: string;
  pulse?: boolean;
  class?: string;
}

let { color = 'grey', label, pulse = false, class: className = '' }: Props = $props();

const colorVar: Record<string, string> = {
  green: 'var(--signal-running)',
  grey: 'var(--fg-subtle)',
  amber: 'var(--signal-warn)',
  red: 'var(--signal-error)',
};
</script>

<span class="cnp-status-dot {className}" class:pulse={pulse && color === 'green'} aria-label={label ?? color}>
  <span class="dot" style="background: {colorVar[color]};"></span>
  {#if label}
    <span class="label">{label}</span>
  {/if}
</span>

<style>
  .cnp-status-dot {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
  }

  .dot {
    width: 7px;
    height: 7px;
    border-radius: 9999px;
    flex-shrink: 0;
  }

  .cnp-status-dot.pulse .dot {
    animation: sd-pulse 2s cubic-bezier(0.65, 0, 0.35, 1) infinite;
  }

  .label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    white-space: nowrap;
  }

  @keyframes sd-pulse {
    0%, 100% { opacity: 1; box-shadow: 0 0 0 0 rgba(120, 200, 80, 0.2); }
    50% { opacity: 0.85; box-shadow: 0 0 0 4px rgba(120, 200, 80, 0); }
  }
</style>
