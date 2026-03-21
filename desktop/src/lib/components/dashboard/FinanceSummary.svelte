<script lang="ts">
  import BudgetBar from '$lib/components/shared/BudgetBar.svelte';
  import { dashboardStore } from '$lib/stores/dashboard.svelte';

  interface Props {
    class?: string;
  }

  let { class: className = '' }: Props = $props();

  function centsToDisplay(cents: number): string {
    return '$' + (cents / 100).toFixed(2);
  }

  const finance = $derived(dashboardStore.financeSummary);

  const todayDollars    = $derived(finance ? centsToDisplay(finance.today_cents) : '—');
  const weekDollars     = $derived(finance ? centsToDisplay(finance.week_cents) : '—');
  const monthDollars    = $derived(finance ? centsToDisplay(finance.month_cents) : '—');
  const cacheSavingsPct = $derived(finance ? finance.cache_savings_pct : null);

  // BudgetBar uses fmt(n) = n.toFixed(2), so pass dollar values (cents / 100)
  const todaySpentDollars = $derived(finance ? finance.today_cents / 100 : 0);
  const dailyLimitDollars = $derived(finance ? finance.daily_limit_cents / 100 : 0);
</script>

<article class="fs-card {className}" aria-label="Finance summary">
  <header class="fs-header">
    <span class="fs-title">Finance</span>
  </header>

  {#if dashboardStore.isLoading && !finance}
    <div class="fs-skeleton-group" aria-hidden="true">
      <div class="fs-skeleton fs-skeleton--amount"></div>
      <div class="fs-skeleton fs-skeleton--bar"></div>
    </div>
  {:else if !finance}
    <div class="fs-empty">No finance data available</div>
  {:else}
    <div class="fs-columns" role="group" aria-label="Spending breakdown">
      <div class="fs-col" aria-label="Today's spend: {todayDollars}">
        <span class="fs-amount">{todayDollars}</span>
        <span class="fs-period">Today</span>
      </div>

      <div class="fs-divider" aria-hidden="true"></div>

      <div class="fs-col" aria-label="This week's spend: {weekDollars}">
        <span class="fs-amount">{weekDollars}</span>
        <span class="fs-period">This Week</span>
      </div>

      <div class="fs-divider" aria-hidden="true"></div>

      <div class="fs-col" aria-label="This month's spend: {monthDollars}">
        <span class="fs-amount">{monthDollars}</span>
        <span class="fs-period">This Month</span>
      </div>
    </div>

    <div class="fs-budget-row">
      <BudgetBar
        spent={todaySpentDollars}
        limit={dailyLimitDollars}
        currency="$"
        warningPct={80}
        label="Daily limit"
      />
    </div>

    {#if cacheSavingsPct !== null}
      <div class="fs-savings" aria-label="Cache savings: {cacheSavingsPct} percent">
        <svg
          width="13"
          height="13"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          aria-hidden="true"
        >
          <polyline points="20 6 9 17 4 12" />
        </svg>
        <span>Cache savings: <strong>{cacheSavingsPct}%</strong></span>
      </div>
    {/if}
  {/if}
</article>

<style>
  .fs-card {
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-lg);
    padding: var(--space-4);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  .fs-header {
    display: flex;
    align-items: center;
  }

  .fs-title {
    font-family: var(--font-sans);
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
  }

  .fs-columns {
    display: flex;
    flex-direction: row;
    align-items: center;
    gap: 0;
  }

  .fs-col {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-1);
    padding: 0 var(--space-3);
  }

  .fs-col:first-child {
    padding-left: 0;
  }

  .fs-col:last-child {
    padding-right: 0;
  }

  .fs-amount {
    font-family: var(--font-sans);
    font-size: 18px;
    font-weight: 700;
    color: var(--text-primary);
    line-height: 1;
    letter-spacing: -0.5px;
  }

  .fs-period {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    color: var(--text-tertiary);
    text-transform: uppercase;
    letter-spacing: 0.4px;
  }

  .fs-divider {
    width: 1px;
    height: 36px;
    background: var(--border-default);
    flex-shrink: 0;
  }

  .fs-budget-row {
    width: 100%;
  }

  .fs-savings {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--accent-success);
  }

  .fs-savings strong {
    font-weight: 600;
  }

  .fs-empty {
    padding: var(--space-4) 0;
    text-align: center;
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--text-tertiary);
  }

  .fs-skeleton-group {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .fs-skeleton {
    border-radius: var(--radius-sm);
    background: linear-gradient(
      90deg,
      var(--bg-surface) 0%,
      var(--bg-elevated) 50%,
      var(--bg-surface) 100%
    );
    background-size: 200% 100%;
    animation: fs-shimmer 1.6s ease-in-out infinite;
    border: 1px solid var(--border-default);
  }

  .fs-skeleton--amount { height: 48px; }
  .fs-skeleton--bar    { height: 28px; }

  @keyframes fs-shimmer {
    0%   { background-position: 200% 0; }
    100% { background-position: -200% 0; }
  }

  @media (prefers-reduced-motion: reduce) {
    .fs-skeleton { animation: none; }
  }
</style>
