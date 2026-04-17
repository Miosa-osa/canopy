<script lang="ts">
/**
 * QuotaGauge — circular progress ring showing provider quota consumption.
 *
 * Props:
 *   usedPercent  — 0–100 fill level
 *   label        — short text below the ring (e.g. "Claude API")
 *   valueLabel   — detailed label shown in tooltip (e.g. "$12.40 / $50.00")
 *   resetsAt     — ISO-8601 timestamp; rendered as tooltip reset date
 *   size         — ring diameter in px (default 40)
 */

interface Props {
  usedPercent: number;
  label?: string;
  valueLabel?: string;
  resetsAt?: string;
  size?: number;
}

let { usedPercent, label, valueLabel, resetsAt, size = 40 }: Props = $props();

const STROKE = 3;
const radius = $derived((size - STROKE * 2) / 2);
const circumference = $derived(2 * Math.PI * radius);
const offset = $derived(
  circumference - (Math.min(100, Math.max(0, usedPercent)) / 100) * circumference
);

const colorClass = $derived(
  usedPercent >= 90 ? 'qg-critical' : usedPercent >= 70 ? 'qg-warn' : 'qg-ok'
);

function formatReset(iso: string): string {
  try {
    return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
  } catch {
    return iso;
  }
}
</script>

<div
  class="qg-root"
  title={[valueLabel, resetsAt ? `Resets ${formatReset(resetsAt)}` : ''].filter(Boolean).join(' · ')}
  aria-label={`${label ?? 'Quota'}: ${Math.round(usedPercent)}% used`}
  role="img"
>
  <svg
    width={size}
    height={size}
    viewBox={`0 0 ${size} ${size}`}
    aria-hidden="true"
  >
    <!-- Track ring -->
    <circle
      class="qg-track"
      cx={size / 2}
      cy={size / 2}
      r={radius}
      stroke-width={STROKE}
      fill="none"
    />
    <!-- Progress ring -->
    <circle
      class="qg-progress {colorClass}"
      cx={size / 2}
      cy={size / 2}
      r={radius}
      stroke-width={STROKE}
      fill="none"
      stroke-linecap="round"
      stroke-dasharray={circumference}
      stroke-dashoffset={offset}
      transform={`rotate(-90 ${size / 2} ${size / 2})`}
    />
    <!-- Center percentage text -->
    <text
      class="qg-pct"
      x={size / 2}
      y={size / 2}
      text-anchor="middle"
      dominant-baseline="central"
    >
      {Math.round(usedPercent)}
    </text>
  </svg>

  {#if label}
    <span class="qg-label">{label}</span>
  {/if}
</div>

<style>
  .qg-root {
    display: inline-flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    cursor: default;
  }

  .qg-track {
    stroke: var(--border);
  }

  .qg-progress {
    transition: stroke-dashoffset 0.4s cubic-bezier(0.4, 0, 0.2, 1);
  }

  .qg-ok {
    stroke: var(--signal-running);
  }
  .qg-warn {
    stroke: var(--signal-warn);
  }
  .qg-critical {
    stroke: var(--signal-error);
  }

  .qg-pct {
    font-family: var(--font-mono);
    font-size: 9px;
    font-weight: 500;
    fill: var(--fg-muted);
  }

  .qg-label {
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
    white-space: nowrap;
    max-width: 64px;
    overflow: hidden;
    text-overflow: ellipsis;
    text-align: center;
  }
</style>
