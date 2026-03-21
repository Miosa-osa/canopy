<!-- src/routes/app/costs/+page.svelte -->
<script lang="ts">
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import CostDashboard from '$lib/components/costs/CostDashboard.svelte';
  import { costsStore } from '$lib/stores/costs.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';
  import type { DateRange } from '$lib/stores/costs.svelte';

  // Re-fetch all cost data whenever the active workspace changes (covers onMount + workspace switches)
  $effect(() => {
    void workspaceStore.activeWorkspaceId;
    void costsStore.fetchAll();
  });

  const DATE_RANGE_OPTIONS: { value: DateRange; label: string }[] = [
    { value: '7d', label: '7 days' },
    { value: '30d', label: '30 days' },
    { value: '90d', label: '90 days' },
  ];
</script>

<PageShell title="Costs" subtitle="Observability">
  {#snippet actions()}
    <div class="cpage-range" role="group" aria-label="Date range">
      {#each DATE_RANGE_OPTIONS as opt (opt.value)}
        <button
          class="cpage-range-btn"
          class:cpage-range-btn--active={costsStore.dateRange === opt.value}
          onclick={() => costsStore.setDateRange(opt.value)}
          aria-pressed={costsStore.dateRange === opt.value}
        >
          {opt.label}
        </button>
      {/each}
    </div>
  {/snippet}

  <CostDashboard />
</PageShell>

<style>
  .cpage-range {
    display: flex;
    align-items: center;
    gap: 2px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    padding: 2px;
  }

  .cpage-range-btn {
    background: none;
    border: none;
    border-radius: 6px;
    color: var(--text-tertiary);
    font-family: var(--font-sans);
    font-size: 12px;
    font-weight: 500;
    padding: 3px 10px;
    cursor: pointer;
    transition: background 120ms ease, color 120ms ease;
    white-space: nowrap;
  }

  .cpage-range-btn:hover {
    color: var(--text-secondary);
    background: rgba(255, 255, 255, 0.05);
  }

  .cpage-range-btn--active {
    background: var(--bg-surface);
    color: var(--text-primary);
    border: 1px solid var(--border-default);
  }
</style>
