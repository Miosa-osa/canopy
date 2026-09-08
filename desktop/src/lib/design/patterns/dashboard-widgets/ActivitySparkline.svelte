<script lang="ts">
/**
 * ActivitySparkline — 7-day mini bar chart of a numeric metric.
 * Pure SVG, no charting library.
 * CSS prefix: asp-
 *
 * Props:
 *   label   — display label above chart (e.g. "Sessions")
 *   values  — array of 7 numbers (oldest → newest)
 *   color   — optional CSS color for bars (defaults to --cnp-accent)
 */

interface Props {
  label: string;
  values: number[];
  color?: string;
}

let { label, values = [], color }: Props = $props();

const BAR_COUNT = 7;
const BAR_W = 6;
const BAR_GAP = 3;
const SVG_H = 32;
const SVG_W = BAR_COUNT * BAR_W + (BAR_COUNT - 1) * BAR_GAP;

// Pad/trim to 7 values
const bars = $derived(
  values.length >= BAR_COUNT
    ? values.slice(-BAR_COUNT)
    : [...Array<number>(BAR_COUNT - values.length).fill(0), ...values]
);

const maxVal = $derived(Math.max(...bars, 1));

function barHeight(v: number): number {
  return Math.max(2, Math.round((v / maxVal) * SVG_H));
}

function barY(v: number): number {
  return SVG_H - barHeight(v);
}

const today = $derived(bars[bars.length - 1] ?? 0);
const yesterday = $derived(bars[bars.length - 2] ?? 0);
const delta = $derived(
  yesterday === 0 ? null : Math.round(((today - yesterday) / yesterday) * 100)
);
</script>

<div class="asp-widget">
  <div class="asp-header">
    <span class="asp-label">{label}</span>
    {#if delta !== null}
      <span
        class="asp-delta"
        class:asp-delta--up={delta >= 0}
        class:asp-delta--down={delta < 0}
        aria-label="{delta >= 0 ? '+' : ''}{delta}% vs yesterday"
      >
        {delta >= 0 ? '+' : ''}{delta}%
      </span>
    {/if}
  </div>

  <div class="asp-value" aria-label="Today: {today}">
    {today}
  </div>

  <svg
    class="asp-chart"
    width={SVG_W}
    height={SVG_H}
    viewBox="0 0 {SVG_W} {SVG_H}"
    aria-label="{label} — 7 day trend"
    role="img"
  >
    {#each bars as v, i (i)}
      {@const x = i * (BAR_W + BAR_GAP)}
      {@const h = barHeight(v)}
      {@const y = barY(v)}
      <rect
        x={x}
        y={y}
        width={BAR_W}
        height={h}
        rx="1"
        fill={i === BAR_COUNT - 1
          ? (color ?? 'var(--cnp-accent)')
          : 'color-mix(in oklch, var(--fg) 16%, transparent)'}
        aria-label="Day {i + 1}: {v}"
      />
    {/each}
  </svg>
</div>

<style>
  .asp-widget {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
    padding: var(--space-3);
  }

  .asp-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-2);
  }

  .asp-label {
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

  .asp-delta {
    font-family: var(--font-mono);
    font-size: 10px;
    white-space: nowrap;
    flex-shrink: 0;
  }

  .asp-delta--up {
    color: oklch(0.65 0.15 145);
  }

  .asp-delta--down {
    color: var(--signal-error, oklch(0.65 0.20 25));
  }

  .asp-value {
    font-family: var(--font-mono);
    font-size: 20px;
    font-weight: 700;
    color: var(--fg);
    letter-spacing: -0.02em;
    line-height: 1;
  }

  .asp-chart {
    display: block;
    overflow: visible;
  }
</style>
