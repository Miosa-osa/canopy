<script lang="ts">
  /**
   * BudgetAlertWidget — shows budgets that are >80% spent.
   * CSS prefix: baw-
   *
   * Fetches /budgets on mount. Renders a red/amber card for any that exceed threshold.
   * Clicking a card navigates to /settings (budget detail is not yet a separate route).
   */
  import { createQuery } from '@tanstack/svelte-query';
  import { AlertTriangle } from 'lucide-svelte';
  import { goto } from '$app/navigation';
  import { apiGet } from '$lib/api/client.js';

  interface Budget {
    id: string;
    name: string;
    limitUsd: string;
    spentUsd?: string;
    enabled: boolean;
    scopeType?: string;
  }

  const ALERT_THRESHOLD = 0.8;

  const budgetsQ = createQuery<Budget[]>({
    queryKey: ['budgets'],
    queryFn: () =>
      apiGet<{ data: Budget[] }>('/budgets').then((r) => r.data ?? []),
    staleTime: 60_000,
  });

  const alertBudgets = $derived(
    ($budgetsQ.data ?? []).filter((b) => {
      if (!b.enabled) return false;
      const limit = parseFloat(b.limitUsd);
      const spent = parseFloat(b.spentUsd ?? '0');
      return limit > 0 && spent / limit >= ALERT_THRESHOLD;
    })
  );

  function pct(b: Budget): number {
    const limit = parseFloat(b.limitUsd);
    const spent = parseFloat(b.spentUsd ?? '0');
    return limit > 0 ? Math.min(100, Math.round((spent / limit) * 100)) : 0;
  }

  function severity(p: number): 'critical' | 'warn' {
    return p >= 95 ? 'critical' : 'warn';
  }
</script>

<div class="baw-widget">
  {#if $budgetsQ.isLoading}
    <p class="baw-empty">Loading budgets…</p>
  {:else if alertBudgets.length === 0}
    <p class="baw-ok">All budgets within limits</p>
  {:else}
    <ul class="baw-list" role="list" aria-label="Budget alerts">
      {#each alertBudgets as b (b.id)}
        {@const p = pct(b)}
        {@const sev = severity(p)}
        <li class="baw-item" role="listitem">
          <button
            class="baw-card baw-card--{sev}"
            onclick={() => goto('/settings')}
            aria-label="{b.name} — {p}% spent"
          >
            <div class="baw-card-header">
              <AlertTriangle size={12} aria-hidden="true" class="baw-icon baw-icon--{sev}" />
              <span class="baw-name">{b.name}</span>
              <span class="baw-pct">{p}%</span>
            </div>
            <div class="baw-track" role="progressbar" aria-valuenow={p} aria-valuemax={100}>
              <div class="baw-fill baw-fill--{sev}" style="width: {p}%;"></div>
            </div>
            <div class="baw-meta">
              <span>${b.spentUsd ?? '0'} of ${b.limitUsd}</span>
              {#if b.scopeType}
                <span class="baw-scope">{b.scopeType}</span>
              {/if}
            </div>
          </button>
        </li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .baw-widget {
    padding: var(--space-2);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .baw-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .baw-card {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
    width: 100%;
    padding: var(--space-2) var(--space-3);
    border-radius: var(--radius-md);
    border: 1px solid;
    background: transparent;
    cursor: pointer;
    text-align: left;
    transition: background var(--dur-fast) ease;
  }

  .baw-card--warn {
    border-color: oklch(0.75 0.18 75 / 0.5);
    background: oklch(0.75 0.18 75 / 0.07);
  }

  .baw-card--critical {
    border-color: oklch(0.65 0.20 25 / 0.5);
    background: oklch(0.65 0.20 25 / 0.08);
  }

  .baw-card--warn:hover {
    background: oklch(0.75 0.18 75 / 0.12);
  }

  .baw-card--critical:hover {
    background: oklch(0.65 0.20 25 / 0.14);
  }

  .baw-card:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .baw-card-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  :global(.baw-icon) {
    flex-shrink: 0;
  }

  :global(.baw-icon--warn) {
    color: oklch(0.75 0.18 75);
  }

  :global(.baw-icon--critical) {
    color: oklch(0.65 0.20 25);
  }

  .baw-name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .baw-pct {
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg-muted);
    flex-shrink: 0;
  }

  .baw-track {
    height: 3px;
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    border-radius: 9999px;
    overflow: hidden;
  }

  .baw-fill {
    height: 100%;
    border-radius: 9999px;
    transition: width var(--dur-normal) ease;
  }

  .baw-fill--warn {
    background: oklch(0.75 0.18 75);
  }

  .baw-fill--critical {
    background: oklch(0.65 0.20 25);
  }

  .baw-meta {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-2);
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .baw-scope {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    padding: 1px 4px;
    border-radius: var(--radius-sm);
    font-size: 9px;
  }

  .baw-empty,
  .baw-ok {
    margin: 0;
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
  }

  .baw-empty {
    color: var(--fg-subtle);
  }

  .baw-ok {
    color: oklch(0.65 0.15 145);
  }
</style>
