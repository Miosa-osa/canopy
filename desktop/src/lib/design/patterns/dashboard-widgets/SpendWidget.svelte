<script lang="ts">
  /**
   * SpendWidget — spend this month: total + per-agent bars.
   * CSS prefix: spw- (SpendWidget)
   * Data from dashboardSummaryQuery (already loaded by parent page).
   */
  import type { DashboardSummary } from '$lib/domain/dashboard/types.js';

  interface Props {
    summary: DashboardSummary | null;
    loading: boolean;
    error: boolean;
  }

  let { summary, loading, error }: Props = $props();

  function formatUsd(raw: string | number): string {
    const n = typeof raw === 'number' ? raw : parseFloat(raw);
    return isNaN(n) ? '$—' : `$${n.toFixed(2)}`;
  }

  function barWidths(agents: { agentSlug: string; costUsd: string }[]): number[] {
    if (agents.length === 0) return [];
    const vals = agents.map((a) => Math.max(0, parseFloat(a.costUsd) || 0));
    const max = Math.max(...vals, 0.001);
    return vals.map((v) => Math.max(4, Math.round((v / max) * 100)));
  }
</script>

<div class="spw-widget">
  {#if loading}
    <p class="spw-empty">Loading…</p>
  {:else if error || !summary}
    <p class="spw-error">Failed to load spend data</p>
  {:else}
    <div class="spw-total" aria-label="Total spend {formatUsd(summary.spendThisMonth.totalUsd)}">
      {formatUsd(summary.spendThisMonth.totalUsd)}
      <span class="spw-period">this month</span>
    </div>

    {#if summary.spendThisMonth.byAgent.length > 0}
      {@const widths = barWidths(summary.spendThisMonth.byAgent)}
      <div class="spw-bars" aria-label="Spend by agent">
        {#each summary.spendThisMonth.byAgent as row, i (row.agentSlug)}
          <div class="spw-bar-row">
            <span class="spw-bar-label" title={row.agentSlug}>{row.agentSlug}</span>
            <div
              class="spw-bar-track"
              role="progressbar"
              aria-valuenow={parseFloat(row.costUsd)}
              aria-label={row.agentSlug}
            >
              <div class="spw-bar-fill" style="width: {widths[i]}%;"></div>
            </div>
            <span class="spw-bar-val">{formatUsd(row.costUsd)}</span>
          </div>
        {/each}
      </div>
    {:else}
      <p class="spw-empty">No agent spend yet</p>
    {/if}
  {/if}
</div>

<style>
  .spw-widget {
    padding: var(--space-3);
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .spw-total {
    font-family: var(--font-mono);
    font-size: 24px;
    font-weight: 700;
    color: var(--fg);
    letter-spacing: -0.02em;
    line-height: 1;
    display: flex;
    align-items: baseline;
    gap: var(--space-2);
  }

  .spw-period {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 400;
    color: var(--fg-subtle);
    letter-spacing: 0.02em;
  }

  .spw-bars {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .spw-bar-row {
    display: grid;
    grid-template-columns: 7rem 1fr 3.5rem;
    align-items: center;
    gap: var(--space-2);
  }

  .spw-bar-label {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .spw-bar-track {
    height: 4px;
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    border-radius: 9999px;
    overflow: hidden;
  }

  .spw-bar-fill {
    height: 100%;
    background: var(--cnp-accent, color-mix(in oklch, var(--fg) 50%, transparent));
    border-radius: 9999px;
    transition: width var(--dur-normal) ease;
  }

  .spw-bar-val {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-muted);
    text-align: right;
    white-space: nowrap;
  }

  .spw-empty,
  .spw-error {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
  }

  .spw-empty { color: var(--fg-subtle); }
  .spw-error { color: var(--signal-error, oklch(0.65 0.20 25)); }
</style>
