<!-- src/lib/components/costs/CostDashboard.svelte -->
<script lang="ts">
  import { costsStore } from '$lib/stores/costs.svelte';
  import AnomalyAlert from './AnomalyAlert.svelte';
  import CostSummaryCards from './CostSummaryCards.svelte';
  import CostChart from './CostChart.svelte';
  import AgentCostBreakdown from './AgentCostBreakdown.svelte';
  import ModelDistribution from './ModelDistribution.svelte';
  import CacheSavings from './CacheSavings.svelte';
  import BudgetPolicyTable from './BudgetPolicyTable.svelte';
  import BudgetIncidentLog from './BudgetIncidentLog.svelte';
</script>

<div class="cd-root">
  <!-- Loading shimmer -->
  {#if costsStore.isLoading}
    <div class="cd-loading" aria-live="polite" aria-label="Loading cost data">
      {#each { length: 6 } as _, i (i)}
        <div class="cd-skeleton"></div>
      {/each}
    </div>

  {:else if costsStore.error}
    <div class="cd-error" role="alert">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
        <circle cx="12" cy="12" r="10" /><line x1="15" y1="9" x2="9" y2="15" /><line x1="9" y1="9" x2="15" y2="15" />
      </svg>
      <span>Failed to load cost data: {costsStore.error}</span>
      <button class="cd-retry-btn" onclick={() => void costsStore.fetchAll()}>Retry</button>
    </div>

  {:else}
    <!-- Anomaly alert (conditional) -->
    {#if costsStore.hasAnomaly}
      <AnomalyAlert />
    {/if}

    <!-- Row 1: Summary cards -->
    <CostSummaryCards />

    <!-- Row 2: Chart + Model distribution -->
    <div class="cd-row cd-row--chart">
      <div class="cd-col-wide">
        <CostChart />
      </div>
      <div class="cd-col-narrow">
        <ModelDistribution />
      </div>
    </div>

    <!-- Row 3: Agent breakdown + Cache savings -->
    <div class="cd-row cd-row--breakdown">
      <div class="cd-col-wide">
        <AgentCostBreakdown />
      </div>
      <div class="cd-col-narrow">
        <CacheSavings />
      </div>
    </div>

    <!-- Row 4: Budget policy table -->
    <BudgetPolicyTable />

    <!-- Row 5: Incident log -->
    <BudgetIncidentLog />
  {/if}
</div>

<style>
  .cd-root {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    width: 100%;
  }

  .cd-loading {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--space-4);
  }

  .cd-skeleton {
    height: 100px;
    border-radius: var(--radius-lg);
    background: linear-gradient(
      90deg,
      var(--bg-surface) 0%,
      var(--bg-elevated) 50%,
      var(--bg-surface) 100%
    );
    background-size: 200% 100%;
    animation: cd-shimmer 1.6s ease-in-out infinite;
    border: 1px solid var(--border-default);
  }

  @keyframes cd-shimmer {
    0%   { background-position: 200% 0; }
    100% { background-position: -200% 0; }
  }

  @media (prefers-reduced-motion: reduce) {
    .cd-skeleton { animation: none; }
  }

  .cd-error {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-3) var(--space-4);
    background: rgba(239, 68, 68, 0.08);
    border: 1px solid rgba(239, 68, 68, 0.25);
    border-radius: var(--radius-md);
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--text-secondary);
  }

  .cd-retry-btn {
    margin-left: auto;
    background: none;
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    color: var(--text-secondary);
    font-family: var(--font-sans);
    font-size: 12px;
    padding: 2px var(--space-3);
    cursor: pointer;
    transition: border-color 120ms ease, color 120ms ease;
  }

  .cd-retry-btn:hover {
    border-color: var(--border-hover);
    color: var(--text-primary);
  }

  .cd-row {
    display: grid;
    gap: var(--space-4);
  }

  .cd-row--chart,
  .cd-row--breakdown {
    grid-template-columns: 1fr 320px;
  }

  .cd-col-wide {
    min-width: 0;
  }

  .cd-col-narrow {
    min-width: 0;
  }

  @media (max-width: 900px) {
    .cd-row--chart,
    .cd-row--breakdown {
      grid-template-columns: 1fr;
    }
  }
</style>
