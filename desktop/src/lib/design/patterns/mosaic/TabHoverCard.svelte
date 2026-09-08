<script lang="ts">
/**
 * TabHoverCard — hover detail card for a tab in the Mosaic strip.
 *
 * Renders a structured summary of a Pane's metadata when the user hovers a
 * tab AND `mosaicPrefs.show_details_on_hover` is true. The host (MosaicTile)
 * is responsible for the open/closed lifecycle and for skipping render when
 * the pref is off — this component is a *pure presenter*.
 *
 * Positioning is delegated to a Floating-UI-free strategy: the card is
 * absolutely positioned by the host via the `style` prop. We do NOT
 * reimplement portal / collision logic — for the simple "below the tab"
 * placement that's sufficient.
 *
 * Missing fields fallback gracefully: every row shows a `—` if absent so
 * the layout doesn't reflow during an async fetch.
 *
 * CSS prefix: thc-
 * LOC target: ≤ 180.
 */
import type { Pane } from '$lib/stores/mosaic-layout.svelte.js';

interface Props {
  pane: Pane;
  /** Inline style for absolute positioning (top/left from the host). */
  style?: string;
}

let { pane, style = '' }: Props = $props();

// ── Derived rows ─────────────────────────────────────────────────────────────
// Each row reads pane.config (free-form) defensively. We type-check at the
// boundary; everything inside is safe-coerced to display-strings.

function asString(v: unknown): string | null {
  return typeof v === 'string' && v.length > 0 ? v : null;
}

function asNumber(v: unknown): number | null {
  return typeof v === 'number' && Number.isFinite(v) ? v : null;
}

const cfg = $derived((pane.config ?? {}) as Record<string, unknown>);

const command = $derived(asString(cfg.command) ?? asString(cfg.cmd) ?? pane.title);
const cwd = $derived(asString(cfg.cwd) ?? asString(cfg.working_directory) ?? null);
const branch = $derived(asString(cfg.branch));
const agent = $derived(asString(cfg.agent) ?? asString(cfg.agent_slug) ?? null);
const runtime = $derived(asString(cfg.runtime) ?? asString(cfg.runtimeType) ?? null);
const model = $derived(asString(cfg.model));
const startedAt = $derived(
  asString(cfg.started_at) ?? asString(cfg.startedAt) ?? asString(cfg.created_at) ?? null
);
const cost = $derived(
  asNumber(cfg.cost_usd) ?? asNumber(cfg.cost) ?? asNumber(cfg.total_cost) ?? null
);

// ── Formatters ───────────────────────────────────────────────────────────────

function relativeTime(iso: string | null): string {
  if (!iso) return '—';
  const t = Date.parse(iso);
  if (Number.isNaN(t)) return iso;
  const seconds = Math.max(0, Math.round((Date.now() - t) / 1000));
  if (seconds < 60) return `${seconds}s ago`;
  if (seconds < 3600) return `${Math.round(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.round(seconds / 3600)}h ago`;
  return `${Math.round(seconds / 86400)}d ago`;
}

function formatCost(c: number | null): string {
  if (c === null) return '—';
  if (c < 0.01) return `<$0.01`;
  return `$${c.toFixed(2)}`;
}
</script>

<div
  class="thc-card"
  role="tooltip"
  aria-label="Tab details for {pane.title}"
  data-testid="tab-hover-card"
  {style}
>
  <div class="thc-title" title={command}>{command}</div>

  <dl class="thc-grid">
    <dt>Working dir</dt>
    <dd title={cwd ?? ''}>{cwd ?? '—'}</dd>

    <dt>Branch</dt>
    <dd>{branch ?? '—'}</dd>

    <dt>Agent</dt>
    <dd>{agent ?? '—'}</dd>

    <dt>Runtime</dt>
    <dd>{runtime ?? '—'}</dd>

    <dt>Model</dt>
    <dd>{model ?? '—'}</dd>

    <dt>Started</dt>
    <dd>{relativeTime(startedAt)}</dd>

    <dt>Cost</dt>
    <dd>{formatCost(cost)}</dd>
  </dl>
</div>

<style>
  .thc-card {
    position: absolute;
    z-index: 50;
    min-width: 260px;
    max-width: 360px;
    padding: 10px 12px;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius-md, 8px);
    box-shadow:
      0 4px 16px rgba(0, 0, 0, 0.12),
      0 1px 3px rgba(0, 0, 0, 0.08);
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--fg);
    pointer-events: none;
  }

  .thc-title {
    font-weight: 600;
    font-family: var(--font-mono, monospace);
    font-size: 12px;
    color: var(--fg);
    margin-bottom: 6px;
    padding-bottom: 6px;
    border-bottom: 1px solid var(--border);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .thc-grid {
    display: grid;
    grid-template-columns: max-content 1fr;
    column-gap: 12px;
    row-gap: 4px;
    margin: 0;
  }

  .thc-grid dt {
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--fg-subtle);
    align-self: center;
  }

  .thc-grid dd {
    margin: 0;
    color: var(--fg-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-family: var(--font-mono, monospace);
    font-size: 11px;
  }
</style>
