<script lang="ts">
/**
 * StatTile — value + delta % + tiny 7-bar sparkline.
 * Canonical stat primitive.
 * CSS prefix: st-
 *
 * Props:
 *   label    — metric label
 *   value    — current value (number or formatted string)
 *   delta    — % change vs previous period (positive = up)
 *   trend    — array of 7 numbers for the mini sparkline
 *   onDrill  — optional click handler for drill-down
 */

interface Props {
  label: string;
  value: string | number;
  delta?: number | null;
  trend?: number[];
  onDrill?: () => void;
}

let { label, value, delta = null, trend = [], onDrill }: Props = $props();

// Sparkline geometry
const BAR_COUNT = 7;
const BAR_W = 4;
const BAR_GAP = 2;
const SVG_H = 20;
const SVG_W = BAR_COUNT * BAR_W + (BAR_COUNT - 1) * BAR_GAP;

const bars = $derived(
  trend.length >= BAR_COUNT
    ? trend.slice(-BAR_COUNT)
    : [...Array<number>(BAR_COUNT - trend.length).fill(0), ...trend]
);

const maxVal = $derived(Math.max(...bars, 1));

function bh(v: number): number {
  return Math.max(2, Math.round((v / maxVal) * SVG_H));
}

const deltaLabel = $derived(delta === null ? '' : `${delta >= 0 ? '+' : ''}${delta}%`);

const hasTrend = $derived(bars.some((b) => b > 0));
</script>

<!-- Single root element avoids Svelte structural {#if} block issues -->
<button
  class="st-tile"
  class:st-tile--clickable={!!onDrill}
  onclick={onDrill ?? undefined}
  disabled={!onDrill}
  aria-label="{label}: {value}{deltaLabel ? `, ${deltaLabel}` : ''}"
>
  <div class="st-top">
    <span class="st-label">{label}</span>
    {#if delta !== null}
      <span
        class="st-delta"
        class:st-delta--up={delta >= 0}
        class:st-delta--down={delta < 0}
        aria-label={deltaLabel}
      >
        {deltaLabel}
      </span>
    {/if}
  </div>

  <div class="st-value">{value}</div>

  {#if hasTrend}
    <svg
      class="st-sparkline"
      width={SVG_W}
      height={SVG_H}
      viewBox="0 0 {SVG_W} {SVG_H}"
      aria-hidden="true"
    >
      {#each bars as v, i (i)}
        {@const x = i * (BAR_W + BAR_GAP)}
        {@const h = bh(v)}
        <rect
          x={x}
          y={SVG_H - h}
          width={BAR_W}
          height={h}
          rx="1"
          fill={i === BAR_COUNT - 1
            ? 'var(--cnp-accent)'
            : 'color-mix(in oklch, var(--fg) 14%, transparent)'}
        />
      {/each}
    </svg>
  {/if}
</button>

<style>
  .st-tile {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
    padding: var(--space-3);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    transition: background var(--dur-fast) ease, box-shadow var(--dur-fast) ease;
    text-align: left;
    width: 100%;
    font-family: inherit;
    cursor: default;
  }

  .st-tile:disabled {
    opacity: 1;
  }

  .st-tile--clickable {
    cursor: pointer;
  }

  .st-tile--clickable:hover {
    background: color-mix(in oklch, var(--bg-inset) 80%, var(--fg) 5%);
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  }

  .st-tile--clickable:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .st-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-2);
  }

  .st-label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--fg-subtle);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .st-delta {
    font-family: var(--font-mono);
    font-size: 10px;
    font-weight: 600;
    flex-shrink: 0;
  }

  .st-delta--up {
    color: oklch(0.65 0.15 145);
  }

  .st-delta--down {
    color: var(--signal-error, oklch(0.65 0.20 25));
  }

  .st-value {
    font-family: var(--font-mono);
    font-size: 22px;
    font-weight: 700;
    color: var(--fg);
    letter-spacing: -0.02em;
    line-height: 1;
  }

  .st-sparkline {
    display: block;
    overflow: visible;
    margin-top: var(--space-1);
  }
</style>
