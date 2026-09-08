<script lang="ts">
/**
 * /analytics — Analytics super-module dashboard.
 * Powered by Iris (the Analytics Agent) via /api/v1/analytics/*.
 *
 * Sections:
 *   1. Stat tiles — sessions, tasks, tokens, spend (from dashboard summary)
 *   2. Cost trend — 30-day cost time-series (analytics/costs)
 *   3. Insights feed — recent anomalies / findings (analytics/insights)
 *   4. Alerts panel — active alert configurations (analytics/alerts)
 *
 * CSS prefix: an-
 */
import {
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import {
  Activity,
  AlertTriangle,
  BarChart2,
  Bell,
  Coins,
  Cpu,
  Sparkles,
  TrendingDown,
  TrendingUp,
} from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import {
  acknowledgeInsight,
  alertsQuery,
  costQuery,
  insightsQuery,
} from '$lib/api/queries/analytics.js';
import { dashboardSummaryQuery } from '$lib/api/queries/dashboard.js';
import SkeletonList from '$lib/design/patterns/SkeletonList.svelte';
import type { Alert, CostBuckets, Insight } from '$lib/domain/analytics/types.js';
import type { DashboardSummary } from '$lib/domain/dashboard/types.js';

const qc = useQueryClient();

// ── Queries ────────────────────────────────────────────────────────────────

const summaryStore = writable(
  untrack(() => dashboardSummaryQuery() as CreateQueryOptions<DashboardSummary>)
);
const summaryQ = createQuery<DashboardSummary>(summaryStore);

const costsStore = writable(
  untrack(
    () =>
      costQuery({
        granularity: 'day',
        from: thirtyDaysAgo(),
      }) as CreateQueryOptions<CostBuckets>
  )
);
const costsQ = createQuery<CostBuckets>(costsStore);

const insightsStore = writable(
  untrack(() => insightsQuery({ limit: 8 }) as CreateQueryOptions<Insight[]>)
);
const insightsQ = createQuery<Insight[]>(insightsStore);

const alertsStore = writable(untrack(() => alertsQuery() as CreateQueryOptions<Alert[]>));
const alertsQ = createQuery<Alert[]>(alertsStore);

// ── Acknowledge mutation ───────────────────────────────────────────────────

const ackMut = createMutation({
  mutationFn: ({
    slug,
    feedback,
  }: {
    slug: string;
    feedback?: 'true_positive' | 'false_positive';
  }) => acknowledgeInsight(slug, 'user', feedback),
  onSuccess: () => {
    qc.invalidateQueries({ queryKey: ['analytics', 'insights'] });
  },
});

function handleAck(slug: string, feedback?: 'true_positive' | 'false_positive') {
  $ackMut.mutate({ slug, feedback });
}

// ── Stat tiles (from dashboard summary) ────────────────────────────────────

const summary = $derived($summaryQ.data ?? null);
const sessionCount = $derived(summary?.totalSessions?.count ?? 0);
const tasksCompleted = $derived(summary?.successRate?.completed ?? 0);
const tokensUsed = $derived(summary?.totalTokens?.total ?? 0);
const spendUsd = $derived(
  summary ? parseFloat(summary.spendThisMonth.totalUsd || '0').toFixed(2) : '0.00'
);

// ── Cost trend ─────────────────────────────────────────────────────────────

const costData = $derived($costsQ.data?.rows ?? []);
const costMax = $derived(Math.max(...costData.map((b) => b.costCents), 1));
const costTotal = $derived(costData.reduce((sum, b) => sum + (b.costCents || 0), 0));
const previousHalfTotal = $derived(
  costData.slice(0, Math.floor(costData.length / 2)).reduce((sum, b) => sum + (b.costCents || 0), 0)
);
const recentHalfTotal = $derived(
  costData.slice(Math.floor(costData.length / 2)).reduce((sum, b) => sum + (b.costCents || 0), 0)
);
const costDeltaPct = $derived(
  previousHalfTotal === 0
    ? 0
    : Math.round(((recentHalfTotal - previousHalfTotal) / previousHalfTotal) * 100)
);

const COST_W = 600;
const COST_H = 120;
const COST_BAR_GAP = 2;

const costBars = $derived(
  costData.map((b, i) => {
    const bw = COST_W / Math.max(costData.length, 1) - COST_BAR_GAP;
    const bh = Math.round((b.costCents / costMax) * (COST_H - 4));
    return {
      x: i * (COST_W / Math.max(costData.length, 1)) + COST_BAR_GAP / 2,
      y: COST_H - bh,
      w: bw,
      h: bh,
      bucket: b.bucket,
      cost: b.costCents,
    };
  })
);

// ── Insights feed ──────────────────────────────────────────────────────────

const insights = $derived($insightsQ.data ?? []);
const unacknowledgedCount = $derived(insights.filter((i) => !i.acknowledgedAt).length);

// ── Alerts ─────────────────────────────────────────────────────────────────

const alerts = $derived($alertsQ.data ?? []);
const activeAlerts = $derived(alerts.filter((a) => a.enabled));

// ── Helpers ────────────────────────────────────────────────────────────────

function fmtNum(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
  return String(n);
}

function fmtCents(c: number): string {
  return `$${(c / 100).toFixed(2)}`;
}

function fmtBucket(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
  });
}

function fmtRelative(iso: string): string {
  const ms = Date.now() - new Date(iso).getTime();
  const s = Math.floor(ms / 1000);
  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
}

function thirtyDaysAgo(): string {
  const d = new Date();
  d.setDate(d.getDate() - 30);
  return d.toISOString();
}

function severityClass(severity: string): string {
  return `an-sev-${severity}`;
}

const isLoading = $derived($summaryQ.isLoading || $costsQ.isLoading || $insightsQ.isLoading);
</script>

<div class="an-page">
  <header class="an-header">
    <div class="an-header-left">
      <h1 class="an-title">Analytics</h1>
      <span class="an-subtitle">
        Powered by Iris · Last 30 days
        {#if unacknowledgedCount > 0}
          · <span class="an-badge">{unacknowledgedCount} unacknowledged</span>
        {/if}
      </span>
    </div>
    <a href="/settings/analytics" class="an-settings-link">
      <Bell size={14} aria-hidden="true" />
      Manage alerts
    </a>
  </header>

  {#if isLoading}
    <div class="an-loading">
      <SkeletonList count={4} height="5rem" gap="0.75rem" />
    </div>
  {:else}
    <!-- Stat tiles -->
    <div class="an-tiles" role="list">
      <div class="an-tile" role="listitem">
        <div class="an-tile__icon"><Activity size={16} aria-hidden="true" /></div>
        <div class="an-tile__body">
          <span class="an-tile__label">Sessions</span>
          <span class="an-tile__value">{fmtNum(sessionCount)}</span>
        </div>
      </div>

      <div class="an-tile" role="listitem">
        <div class="an-tile__icon"><BarChart2 size={16} aria-hidden="true" /></div>
        <div class="an-tile__body">
          <span class="an-tile__label">Tasks completed</span>
          <span class="an-tile__value">{fmtNum(tasksCompleted)}</span>
        </div>
      </div>

      <div class="an-tile" role="listitem">
        <div class="an-tile__icon"><Cpu size={16} aria-hidden="true" /></div>
        <div class="an-tile__body">
          <span class="an-tile__label">Tokens</span>
          <span class="an-tile__value">{fmtNum(tokensUsed)}</span>
        </div>
      </div>

      <div class="an-tile" role="listitem">
        <div class="an-tile__icon"><Coins size={16} aria-hidden="true" /></div>
        <div class="an-tile__body">
          <span class="an-tile__label">Spend (month)</span>
          <span class="an-tile__value">${spendUsd}</span>
        </div>
      </div>
    </div>

    <!-- Cost trend -->
    <section class="an-chart-card" aria-labelledby="an-cost-label">
      <header class="an-chart-header">
        <h2 class="an-chart-title" id="an-cost-label">Cost trend (30d)</h2>
        <div class="an-chart-meta">
          <span class="an-chart-total">{fmtCents(costTotal)} total</span>
          {#if costDeltaPct !== 0}
            <span class="an-chart-delta" class:up={costDeltaPct > 0} class:down={costDeltaPct < 0}>
              {#if costDeltaPct > 0}
                <TrendingUp size={12} aria-hidden="true" />
              {:else}
                <TrendingDown size={12} aria-hidden="true" />
              {/if}
              {Math.abs(costDeltaPct)}% vs prior 15d
            </span>
          {/if}
        </div>
      </header>
      {#if costData.length === 0}
        <p class="an-chart-empty">No cost telemetry yet. Costs accrue as agents run.</p>
      {:else}
        <div class="an-chart-wrap" aria-hidden="true">
          <svg
            viewBox="0 0 {COST_W} {COST_H}"
            width="100%"
            height={COST_H}
            role="img"
            aria-label="Bar chart of cost per day over the last 30 days"
          >
            {#each costBars as bar, i (i)}
              <rect
                x={bar.x}
                y={bar.y}
                width={bar.w}
                height={bar.h}
                class="an-cost-bar"
              >
                <title>{fmtBucket(bar.bucket)}: {fmtCents(bar.cost)}</title>
              </rect>
            {/each}
          </svg>
        </div>
      {/if}
    </section>

    <!-- Insights feed -->
    <section class="an-section" aria-labelledby="an-insights-label">
      <header class="an-section-header">
        <h2 class="an-section-title" id="an-insights-label">
          <Sparkles size={14} aria-hidden="true" />
          Recent insights
        </h2>
        <span class="an-section-meta">{insights.length} surfaced</span>
      </header>
      {#if insights.length === 0}
        <p class="an-empty">
          No insights yet. Iris surfaces anomalies, trends, and forecasts as agents run.
        </p>
      {:else}
        <ul class="an-insight-list">
          {#each insights as ins (ins.id)}
            <li class="an-insight {severityClass(ins.severity)}">
              <div class="an-insight-row">
                <span class="an-insight-sev">{ins.severity}</span>
                <span class="an-insight-kind">{ins.kind}</span>
                <span class="an-insight-time">{fmtRelative(ins.detectedAt)}</span>
              </div>
              <div class="an-insight-title">{ins.title}</div>
              {#if ins.metric}
                <div class="an-insight-metric">{ins.metric}</div>
              {/if}
              {#if !ins.acknowledgedAt}
                <div class="an-insight-actions">
                  <button
                    type="button"
                    class="an-insight-ack"
                    aria-label={`Mark insight ${ins.title} as a true positive`}
                    onclick={() => handleAck(ins.slug, "true_positive")}
                    disabled={$ackMut.isPending}
                  >
                    ✓ true
                  </button>
                  <button
                    type="button"
                    class="an-insight-ack"
                    aria-label={`Mark insight ${ins.title} as a false positive`}
                    onclick={() => handleAck(ins.slug, "false_positive")}
                    disabled={$ackMut.isPending}
                  >
                    ✗ false
                  </button>
                </div>
              {/if}
            </li>
          {/each}
        </ul>
      {/if}
    </section>

    <!-- Alerts panel -->
    <section class="an-section" aria-labelledby="an-alerts-label">
      <header class="an-section-header">
        <h2 class="an-section-title" id="an-alerts-label">
          <AlertTriangle size={14} aria-hidden="true" />
          Active alerts
        </h2>
        <span class="an-section-meta">{activeAlerts.length} of {alerts.length} enabled</span>
      </header>
      {#if alerts.length === 0}
        <p class="an-empty">
          No alerts configured. <a href="/settings/analytics">Create one</a> to be paged
          when a metric crosses your threshold or anomaly band.
        </p>
      {:else}
        <ul class="an-alert-list">
          {#each alerts as al (al.id)}
            <li class="an-alert" class:disabled={!al.enabled}>
              <div class="an-alert-name">{al.name}</div>
              <div class="an-alert-meta">
                <span>{al.metric}</span>
                <span>·</span>
                <span>{al.type}</span>
                <span>·</span>
                <span>{al.severity}</span>
                {#if al.fireCount > 0}
                  <span>·</span>
                  <span>fired {al.fireCount}×</span>
                {/if}
              </div>
            </li>
          {/each}
        </ul>
      {/if}
    </section>
  {/if}
</div>

<style>
  .an-page {
    padding: 1.5rem 2rem 4rem;
    max-width: 1200px;
    margin: 0 auto;
    color: var(--cnp-fg);
  }

  .an-header {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    margin-bottom: 1.5rem;
    gap: 1rem;
  }

  .an-header-left {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .an-title {
    font-family: var(--cnp-font-serif, Georgia, serif);
    font-size: 2rem;
    font-weight: 500;
    letter-spacing: -0.025em;
    margin: 0;
  }

  .an-subtitle {
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
  }

  .an-badge {
    color: var(--cnp-accent);
    font-weight: 500;
  }

  .an-settings-link {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.4rem 0.75rem;
    border: 1px solid var(--cnp-border);
    border-radius: 6px;
    color: var(--cnp-fg-muted);
    text-decoration: none;
    font-size: 0.8rem;
    transition: color 0.15s, border-color 0.15s;
  }

  .an-settings-link:hover {
    color: var(--cnp-fg);
    border-color: var(--cnp-fg-muted);
  }

  .an-loading {
    margin-top: 1rem;
  }

  .an-tiles {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
    gap: 0.75rem;
    margin-bottom: 1.5rem;
  }

  .an-tile {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 1rem 1.25rem;
    background: var(--cnp-bg-elev);
    border: 1px solid var(--cnp-border);
    border-radius: 8px;
  }

  .an-tile__icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    color: var(--cnp-accent);
    background: color-mix(in oklch, var(--cnp-accent) 12%, transparent);
    border-radius: 6px;
  }

  .an-tile__body {
    display: flex;
    flex-direction: column;
    gap: 0.1rem;
    min-width: 0;
  }

  .an-tile__label {
    font-size: 0.75rem;
    color: var(--cnp-fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .an-tile__value {
    font-size: 1.5rem;
    font-weight: 500;
    font-feature-settings: "tnum";
  }

  .an-chart-card {
    background: var(--cnp-bg-elev);
    border: 1px solid var(--cnp-border);
    border-radius: 8px;
    padding: 1.25rem;
    margin-bottom: 1.5rem;
  }

  .an-chart-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
    margin-bottom: 0.75rem;
  }

  .an-chart-title {
    font-size: 0.95rem;
    font-weight: 500;
    margin: 0;
  }

  .an-chart-meta {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    font-size: 0.8rem;
    color: var(--cnp-fg-muted);
  }

  .an-chart-total {
    font-feature-settings: "tnum";
  }

  .an-chart-delta {
    display: inline-flex;
    align-items: center;
    gap: 0.2rem;
  }

  .an-chart-delta.up {
    color: var(--cnp-warn, #d97706);
  }

  .an-chart-delta.down {
    color: var(--cnp-accent);
  }

  .an-chart-empty {
    padding: 1.5rem 0;
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
    text-align: center;
  }

  .an-cost-bar {
    fill: var(--cnp-accent);
    opacity: 0.85;
  }

  .an-cost-bar:hover {
    opacity: 1;
  }

  .an-section {
    background: var(--cnp-bg-elev);
    border: 1px solid var(--cnp-border);
    border-radius: 8px;
    padding: 1.25rem;
    margin-bottom: 1.5rem;
  }

  .an-section-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 0.75rem;
  }

  .an-section-title {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.95rem;
    font-weight: 500;
    margin: 0;
  }

  .an-section-meta {
    font-size: 0.8rem;
    color: var(--cnp-fg-muted);
  }

  .an-empty {
    padding: 1rem 0;
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
  }

  .an-empty a {
    color: var(--cnp-accent);
  }

  .an-insight-list,
  .an-alert-list {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .an-insight {
    padding: 0.75rem 1rem;
    border: 1px solid var(--cnp-border);
    border-left-width: 3px;
    border-radius: 4px;
    background: var(--cnp-bg);
    position: relative;
  }

  .an-sev-info {
    border-left-color: var(--cnp-fg-muted);
  }

  .an-sev-medium {
    border-left-color: #d97706;
  }

  .an-sev-high {
    border-left-color: #dc2626;
  }

  .an-sev-critical {
    border-left-color: #dc2626;
    background: color-mix(in oklch, #dc2626 6%, var(--cnp-bg));
  }

  .an-insight-row {
    display: flex;
    gap: 0.5rem;
    font-size: 0.7rem;
    color: var(--cnp-fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
    margin-bottom: 0.25rem;
  }

  .an-insight-title {
    font-size: 0.9rem;
    font-weight: 500;
  }

  .an-insight-metric {
    font-size: 0.8rem;
    color: var(--cnp-fg-muted);
    margin-top: 0.2rem;
    font-family: var(--cnp-font-mono, monospace);
  }

  .an-insight-actions {
    position: absolute;
    top: 0.5rem;
    right: 0.5rem;
    display: flex;
    gap: 0.25rem;
  }

  .an-insight-ack {
    background: transparent;
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    color: var(--cnp-fg-muted);
    padding: 0.2rem 0.5rem;
    font-size: 0.7rem;
    cursor: pointer;
    transition: color 0.15s, border-color 0.15s;
    font-family: inherit;
  }

  .an-insight-ack:hover:not(:disabled) {
    color: var(--cnp-fg);
    border-color: var(--cnp-fg-muted);
  }

  .an-insight-ack:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .an-alert {
    padding: 0.65rem 1rem;
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    background: var(--cnp-bg);
  }

  .an-alert.disabled {
    opacity: 0.5;
  }

  .an-alert-name {
    font-size: 0.9rem;
    font-weight: 500;
  }

  .an-alert-meta {
    display: flex;
    gap: 0.4rem;
    font-size: 0.75rem;
    color: var(--cnp-fg-muted);
    margin-top: 0.2rem;
  }
</style>
