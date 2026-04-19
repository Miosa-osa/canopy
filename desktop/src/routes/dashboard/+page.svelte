<script lang="ts">
/**
 * /dashboard — System Observability.
 *
 * Linear.app-style dense layout. No card-in-card nesting. No decorative emojis.
 * All data from a single GET /api/v1/dashboard/summary (30s stale).
 *
 * Row 1: 4 stat cards (Total Messages, Total Sessions, Success Rate, Total Tokens)
 * Row 2: Active Agents (full width — from Wave 1)
 * Row 3: Sandbox Usage Today | Peak Hours 30d | Traffic Sources
 * Row 4: Token Usage This Month | Storage Overview
 * Row 5: Top Agents by Usage | Top Tools 30d
 * Row 6: Spend This Month | Recent Sessions
 *
 * CSS prefix: obs- (observability)
 */
import { createQuery, useQueryClient } from '@tanstack/svelte-query';
import { RefreshCw } from 'lucide-svelte';
import { writable } from 'svelte/store';
import { untrack } from 'svelte';
import { goto } from '$app/navigation';
import { dashboardSummaryQuery } from '$lib/api/queries/dashboard.js';
import { hiredAgentsQuery } from '$lib/api/queries/agents.js';
import SkeletonList from '$lib/design/patterns/SkeletonList.svelte';
import StatusDot from '$lib/design/patterns/StatusDot.svelte';
import AgentLiveCard from '$lib/design/patterns/AgentLiveCard.svelte';
import type { DashboardSummary, RecentSession, SpendByAgent } from '$lib/domain/dashboard/types.js';
import type { Agent } from '$lib/domain/agents/types.js';
import type { CreateQueryOptions } from '@tanstack/svelte-query';

const queryClient = useQueryClient();

const queryOptsStore = writable(
  untrack(() => dashboardSummaryQuery() as CreateQueryOptions<DashboardSummary>)
);
const query = createQuery<DashboardSummary>(queryOptsStore);

const hiredAgentsOptsStore = writable(
  untrack(() => hiredAgentsQuery() as CreateQueryOptions<Agent[]>)
);
const hiredQ = createQuery<Agent[]>(hiredAgentsOptsStore);

const agentBySlug = $derived(
  ($hiredQ.data ?? []).reduce<Record<string, Agent>>((acc, a) => {
    acc[a.slug] = a;
    return acc;
  }, {})
);

const summary = $derived($query.data ?? null);

// ── Helpers ───────────────────────────────────────────────────────────────────

function relativeTime(iso: string | null | undefined): string {
  if (!iso) return '—';
  const diffMs = Date.now() - new Date(iso).getTime();
  if (diffMs < 0) return 'just now';
  const diffSec = Math.floor(diffMs / 1000);
  if (diffSec < 60) return `${diffSec}s ago`;
  const diffMin = Math.floor(diffSec / 60);
  if (diffMin < 60) return `${diffMin}m ago`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `${diffHr}h ago`;
  return `${Math.floor(diffHr / 24)}d ago`;
}

function sessionDuration(s: RecentSession): string {
  if (!s.completedAt) return 'running';
  const ms = new Date(s.completedAt).getTime() - new Date(s.insertedAt).getTime();
  if (ms < 0) return '—';
  const secs = Math.floor(ms / 1000);
  if (secs < 60) return `${secs}s`;
  return `${Math.floor(secs / 60)}m ${secs % 60}s`;
}

function formatUsd(raw: string | number): string {
  const n = typeof raw === 'number' ? raw : parseFloat(raw);
  return isNaN(n) ? '$—' : `$${n.toFixed(2)}`;
}

function formatNumber(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
  return String(n);
}

function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  if (bytes >= 1_073_741_824) return `${(bytes / 1_073_741_824).toFixed(1)} GB`;
  if (bytes >= 1_048_576) return `${(bytes / 1_048_576).toFixed(1)} MB`;
  if (bytes >= 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${bytes} B`;
}

function barWidths(agents: SpendByAgent[]): number[] {
  if (agents.length === 0) return [];
  const vals = agents.map((a) => Math.max(0, parseFloat(a.costUsd) || 0));
  const max = Math.max(...vals, 0.001);
  return vals.map((v) => Math.max(4, Math.round((v / max) * 100)));
}

function dotColor(status: string): 'green' | 'amber' | 'red' | 'grey' {
  switch (status) {
    case 'running': return 'green';
    case 'error': return 'red';
    case 'paused':
    case 'pending': return 'amber';
    default: return 'grey';
  }
}

const updatedLabel = $derived(
  $query.dataUpdatedAt > 0
    ? `Updated ${relativeTime(new Date($query.dataUpdatedAt).toISOString())}`
    : ''
);

function handleRefresh(): void {
  void queryClient.invalidateQueries({ queryKey: ['dashboard', 'summary'] });
}

// Peak hours bar chart — normalised heights (4–100%)
const peakHourBars = $derived(() => {
  const hours = summary?.peakHours30d ?? Array(24).fill(0);
  const max = Math.max(...hours, 1);
  return hours.map((v) => Math.max(4, Math.round((v / max) * 100)));
});

// Token usage bars — relative widths for input vs output
const tokenBars = $derived(() => {
  const t = summary?.tokenUsageByPeriod;
  if (!t || t.total === 0) return { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };
  const norm = (n: number) => Math.max(2, Math.round((n / t.total) * 100));
  return {
    input: norm(t.inputTokens),
    output: norm(t.outputTokens),
    cacheRead: norm(t.cacheRead),
    cacheWrite: norm(t.cacheWrite),
  };
});
</script>

<div class="obs-page">
  <!-- ── Header ─────────────────────────────────────────────────────────────── -->
  <header class="obs-header">
    <h1 class="obs-title">System Observability</h1>
    <div class="obs-header-actions">
      {#if updatedLabel}
        <span class="obs-updated">{updatedLabel}</span>
      {/if}
      <button
        class="btn-compact btn-compact-ghost obs-refresh"
        onclick={handleRefresh}
        aria-label="Refresh dashboard"
        title="Refresh"
        disabled={$query.isFetching}
      >
        <RefreshCw
          size={12}
          aria-hidden="true"
          class={$query.isFetching ? 'obs-spin' : ''}
        />
        <span class="obs-refresh-label">Refresh</span>
      </button>
    </div>
  </header>

  <div class="obs-grid">

    <!-- ── Row 1: 4 stat cards ───────────────────────────────────────────────── -->

    <!-- Total Messages -->
    <section class="obs-widget obs-stat-card obs-span-3" aria-label="Total messages">
      <span class="obs-stat-label">Total Messages</span>
      {#if $query.isLoading}
        <span class="obs-stat-num obs-stat-num-loading">—</span>
      {:else}
        <span class="obs-stat-num">{formatNumber(summary?.totalMessages.count ?? 0)}</span>
      {/if}
    </section>

    <!-- Total Sessions -->
    <section class="obs-widget obs-stat-card obs-span-3" aria-label="Total sessions">
      <span class="obs-stat-label">Total Sessions</span>
      {#if $query.isLoading}
        <span class="obs-stat-num obs-stat-num-loading">—</span>
      {:else}
        <span class="obs-stat-num">{formatNumber(summary?.totalSessions.count ?? 0)}</span>
      {/if}
    </section>

    <!-- Success Rate -->
    <section class="obs-widget obs-stat-card obs-span-3" aria-label="Success rate">
      <span class="obs-stat-label">Success Rate (30d)</span>
      {#if $query.isLoading}
        <span class="obs-stat-num obs-stat-num-loading">—</span>
      {:else}
        <span class="obs-stat-num">{summary?.successRate.rate ?? 0}<span class="obs-stat-unit">%</span></span>
        <span class="obs-stat-sub">{summary?.successRate.completed ?? 0} ok / {summary?.successRate.failed ?? 0} failed</span>
      {/if}
    </section>

    <!-- Total Tokens -->
    <section class="obs-widget obs-stat-card obs-span-3" aria-label="Total tokens">
      <span class="obs-stat-label">Total Tokens</span>
      {#if $query.isLoading}
        <span class="obs-stat-num obs-stat-num-loading">—</span>
      {:else}
        <span class="obs-stat-num">{formatNumber(summary?.totalTokens.total ?? 0)}</span>
        <span class="obs-stat-sub">input · output · cache</span>
      {/if}
    </section>

    <!-- ── Row 2: Active Agents (full width — Wave 1) ───────────────────────── -->
    <section class="obs-widget obs-span-12" aria-label="Active agents">
      <div class="obs-widget-head">
        <span class="obs-section-label">Active Agents</span>
        {#if summary}
          <span class="obs-badge">{summary.activeAgents.length}</span>
        {/if}
      </div>

      {#if $query.isLoading}
        <div class="obs-skeleton-wrap">
          <SkeletonList count={3} height="2.5rem" gap="0.5rem" />
        </div>
      {:else if $query.isError}
        <p class="obs-error-msg">Failed to load — {($query.error as Error).message}</p>
      {:else if !summary || summary.activeAgents.length === 0}
        <p class="obs-empty-msg">No agents currently running.</p>
      {:else}
        {@const visible = summary.activeAgents.slice(0, 8)}
        {@const overflow = summary.activeAgents.length - visible.length}
        <div class="obs-live-grid">
          {#each visible as activeAgent (activeAgent.currentSessionId)}
            {@const fullAgent = agentBySlug[activeAgent.agentSlug ?? '']}
            {#if fullAgent}
              <AgentLiveCard agent={fullAgent} compact />
            {:else}
              <button
                class="obs-agent-row"
                onclick={() => goto(`/sessions/${activeAgent.currentSessionId}`)}
                aria-label="Open session for {activeAgent.agentSlug ?? 'unknown agent'}"
              >
                <StatusDot color="green" pulse={true} />
                <span class="obs-agent-slug">{activeAgent.agentSlug ?? '—'}</span>
                <span class="obs-agent-meta">{relativeTime(activeAgent.startedAt)}</span>
                <span class="obs-chevron" aria-hidden="true">›</span>
              </button>
            {/if}
          {/each}
        </div>
        {#if overflow > 0}
          <a class="obs-overflow-link" href="/agents?hired=true">+ {overflow} more</a>
        {/if}
      {/if}
    </section>

    <!-- ── Row 3: Sandbox Usage | Peak Hours | Traffic Sources ──────────────── -->

    <!-- Sandbox Usage Today -->
    <section class="obs-widget obs-span-4" aria-label="Sandbox usage today">
      <span class="obs-section-label">Sandbox Usage Today</span>
      {#if $query.isLoading}
        <div class="obs-skeleton-wrap"><SkeletonList count={3} height="1.5rem" gap="0.5rem" /></div>
      {:else if !summary}
        <p class="obs-empty-msg">No data.</p>
      {:else}
        {@const sb = summary.sandboxUsageToday}
        <div class="obs-kv-table">
          <div class="obs-kv-row">
            <span class="obs-kv-key">Started</span>
            <span class="obs-kv-val">{sb.started}</span>
          </div>
          <div class="obs-kv-row">
            <span class="obs-kv-key">Stopped</span>
            <span class="obs-kv-val">{sb.stopped}</span>
          </div>
          <div class="obs-kv-row">
            <span class="obs-kv-key">Running now</span>
            <span class="obs-kv-val">{sb.runningNow}</span>
          </div>
          <div class="obs-kv-row">
            <span class="obs-kv-key">Avg lifetime</span>
            <span class="obs-kv-val">{sb.avgLifetimeMin}m</span>
          </div>
        </div>
      {/if}
    </section>

    <!-- Peak Hours 30d — sparkline bar chart -->
    <section class="obs-widget obs-span-5" aria-label="Peak hours last 30 days">
      <span class="obs-section-label">Peak Hours (30d, UTC)</span>
      {#if $query.isLoading}
        <div class="obs-skeleton-wrap"><SkeletonList count={1} height="4rem" gap="0" /></div>
      {:else if !summary}
        <p class="obs-empty-msg">No data.</p>
      {:else}
        <div class="obs-hour-chart" role="img" aria-label="Sessions per UTC hour over last 30 days">
          {#each peakHourBars() as height, i}
            <div
              class="obs-hour-bar"
              style="height: {height}%;"
              title="Hour {i}:00 UTC — {summary.peakHours30d[i]} sessions"
            ></div>
          {/each}
        </div>
        <div class="obs-hour-labels">
          <span>0h</span>
          <span>6h</span>
          <span>12h</span>
          <span>18h</span>
          <span>23h</span>
        </div>
      {/if}
    </section>

    <!-- Traffic Sources — placeholder until feature lands -->
    <section class="obs-widget obs-span-3" aria-label="Traffic sources">
      <span class="obs-section-label">Traffic Sources</span>
      <p class="obs-empty-msg">No data available.</p>
    </section>

    <!-- ── Row 4: Token Usage | Storage Overview ─────────────────────────────── -->

    <!-- Token Usage This Month -->
    <section class="obs-widget obs-span-6" aria-label="Token usage this month">
      <span class="obs-section-label">Token Usage (30d)</span>
      {#if $query.isLoading}
        <div class="obs-skeleton-wrap"><SkeletonList count={4} height="1.25rem" gap="0.5rem" /></div>
      {:else if !summary}
        <p class="obs-empty-msg">No data.</p>
      {:else}
        {@const t = summary.tokenUsageByPeriod}
        {@const bars = tokenBars()}
        <div class="obs-token-bars">
          <div class="obs-token-row">
            <span class="obs-token-label">Input</span>
            <div class="obs-token-track">
              <div class="obs-token-fill obs-token-fill-input" style="width: {bars.input}%;"></div>
            </div>
            <span class="obs-token-val">{formatNumber(t.inputTokens)}</span>
          </div>
          <div class="obs-token-row">
            <span class="obs-token-label">Output</span>
            <div class="obs-token-track">
              <div class="obs-token-fill obs-token-fill-output" style="width: {bars.output}%;"></div>
            </div>
            <span class="obs-token-val">{formatNumber(t.outputTokens)}</span>
          </div>
          <div class="obs-token-row">
            <span class="obs-token-label">Cache read</span>
            <div class="obs-token-track">
              <div class="obs-token-fill obs-token-fill-cache" style="width: {bars.cacheRead}%;"></div>
            </div>
            <span class="obs-token-val">{formatNumber(t.cacheRead)}</span>
          </div>
          <div class="obs-token-row">
            <span class="obs-token-label">Cache write</span>
            <div class="obs-token-track">
              <div class="obs-token-fill obs-token-fill-cache" style="width: {bars.cacheWrite}%;"></div>
            </div>
            <span class="obs-token-val">{formatNumber(t.cacheWrite)}</span>
          </div>
        </div>
        <div class="obs-token-total">
          Total <span class="obs-token-total-val">{formatNumber(t.total)}</span>
        </div>
      {/if}
    </section>

    <!-- Storage Overview -->
    <section class="obs-widget obs-span-6" aria-label="Storage overview">
      <span class="obs-section-label">Storage Overview</span>
      {#if $query.isLoading}
        <div class="obs-skeleton-wrap"><SkeletonList count={4} height="1.25rem" gap="0.5rem" /></div>
      {:else if !summary}
        <p class="obs-empty-msg">No data.</p>
      {:else}
        {@const s = summary.storageOverview}
        <div class="obs-kv-table">
          <div class="obs-kv-row">
            <span class="obs-kv-key">Workspaces</span>
            <span class="obs-kv-val">{s.workspaces}</span>
          </div>
          <div class="obs-kv-row">
            <span class="obs-kv-key">Files indexed</span>
            <span class="obs-kv-val">{formatNumber(s.files)}</span>
          </div>
          <div class="obs-kv-row">
            <span class="obs-kv-key">Total size</span>
            <span class="obs-kv-val">{formatBytes(s.fileBytes)}</span>
          </div>
          <div class="obs-kv-row">
            <span class="obs-kv-key">Knowledge bases</span>
            <span class="obs-kv-val obs-kv-muted">{s.knowledgeBases === 0 ? '—' : s.knowledgeBases}</span>
          </div>
          <div class="obs-kv-row">
            <span class="obs-kv-key">KB chunks</span>
            <span class="obs-kv-val obs-kv-muted">{s.kbChunks === 0 ? '—' : formatNumber(s.kbChunks)}</span>
          </div>
        </div>
      {/if}
    </section>

    <!-- ── Row 5: Top Agents | Top Tools ─────────────────────────────────────── -->

    <!-- Top Agents by Usage -->
    <section class="obs-widget obs-span-6" aria-label="Top agents by usage">
      <span class="obs-section-label">Top Agents (30d)</span>
      {#if $query.isLoading}
        <div class="obs-skeleton-wrap"><SkeletonList count={5} height="2rem" gap="0.25rem" /></div>
      {:else if !summary || summary.topAgentsByUsage.length === 0}
        <p class="obs-empty-msg">No agent sessions in the last 30 days.</p>
      {:else}
        <table class="obs-table">
          <thead>
            <tr>
              <th class="obs-th">Agent</th>
              <th class="obs-th obs-th-r">Sessions</th>
              <th class="obs-th obs-th-r">Cost</th>
              <th class="obs-th obs-th-r">Avg duration</th>
            </tr>
          </thead>
          <tbody>
            {#each summary.topAgentsByUsage as row (row.agentSlug)}
              <tr class="obs-tr">
                <td class="obs-td obs-td-slug">{row.agentSlug}</td>
                <td class="obs-td obs-td-r obs-mono">{row.sessionCount}</td>
                <td class="obs-td obs-td-r obs-mono">{formatUsd(row.totalCostUsd)}</td>
                <td class="obs-td obs-td-r obs-mono">
                  {row.avgDurationS != null ? `${row.avgDurationS}s` : '—'}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </section>

    <!-- Top Tools 30d -->
    <section class="obs-widget obs-span-6" aria-label="Top tools last 30 days">
      <span class="obs-section-label">Top Tools (30d)</span>
      {#if $query.isLoading}
        <div class="obs-skeleton-wrap"><SkeletonList count={5} height="2rem" gap="0.25rem" /></div>
      {:else if !summary || summary.topTools30d.length === 0}
        <p class="obs-empty-msg">No tool calls in the last 30 days.</p>
      {:else}
        <table class="obs-table">
          <thead>
            <tr>
              <th class="obs-th">Tool</th>
              <th class="obs-th obs-th-r">Calls</th>
            </tr>
          </thead>
          <tbody>
            {#each summary.topTools30d as row, i (i)}
              <tr class="obs-tr">
                <td class="obs-td obs-td-slug">{row.toolName ?? '(unknown)'}</td>
                <td class="obs-td obs-td-r obs-mono">{row.callCount}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </section>

    <!-- ── Row 6: Spend This Month | Recent Sessions ──────────────────────────── -->

    <!-- Spend This Month -->
    <section class="obs-widget obs-span-6" aria-label="Spend this month">
      <div class="obs-widget-head">
        <span class="obs-section-label">Spend This Month</span>
      </div>
      {#if $query.isLoading}
        <div class="obs-skeleton-wrap"><SkeletonList count={4} height="1.75rem" gap="0.5rem" /></div>
      {:else if $query.isError}
        <p class="obs-error-msg">Failed to load</p>
      {:else if !summary}
        <p class="obs-empty-msg">No spend data.</p>
      {:else}
        <div class="obs-spend-total" aria-label="Total spend {formatUsd(summary.spendThisMonth.totalUsd)}">
          {formatUsd(summary.spendThisMonth.totalUsd)}
        </div>
        {#if summary.spendThisMonth.byAgent.length > 0}
          <div class="obs-bars" aria-label="Spend by agent">
            {#each summary.spendThisMonth.byAgent as row, i (row.agentSlug)}
              <div class="obs-bar-row">
                <span class="obs-bar-label">{row.agentSlug}</span>
                <div class="obs-bar-track" role="progressbar" aria-valuenow={parseFloat(row.costUsd)} aria-label={row.agentSlug}>
                  <div class="obs-bar-fill" style="width: {barWidths(summary.spendThisMonth.byAgent)[i]}%;"></div>
                </div>
                <span class="obs-bar-value">{formatUsd(row.costUsd)}</span>
              </div>
            {/each}
          </div>
        {:else}
          <p class="obs-empty-msg">No per-agent data yet.</p>
        {/if}
        {#if summary.spendThisMonth.byRuntime.length > 0}
          <div class="obs-runtime-split">
            <span class="obs-runtime-head">By runtime</span>
            <div class="obs-runtime-pills">
              {#each summary.spendThisMonth.byRuntime as rt (rt.runtimeType)}
                <span class="obs-runtime-pill">
                  <span class="obs-runtime-name">{rt.runtimeType}</span>
                  <span class="obs-runtime-cost">{formatUsd(rt.costUsd)}</span>
                </span>
              {/each}
            </div>
          </div>
        {/if}
      {/if}
    </section>

    <!-- Recent Sessions -->
    <section class="obs-widget obs-span-6" aria-label="Recent sessions">
      <span class="obs-section-label">Recent Sessions</span>
      {#if $query.isLoading}
        <div class="obs-skeleton-wrap"><SkeletonList count={5} height="2.25rem" gap="0.375rem" /></div>
      {:else if $query.isError}
        <p class="obs-error-msg">Failed to load</p>
      {:else if !summary || summary.recentSessions.length === 0}
        <p class="obs-empty-msg">No sessions yet.</p>
      {:else}
        <div class="obs-table-wrap">
          <table class="obs-table">
            <thead>
              <tr>
                <th class="obs-th obs-th-dot"></th>
                <th class="obs-th">Agent</th>
                <th class="obs-th">Runtime</th>
                <th class="obs-th">Duration</th>
                <th class="obs-th">When</th>
              </tr>
            </thead>
            <tbody>
              {#each summary.recentSessions as s (s.id)}
                <!-- svelte-ignore a11y_interactive_supports_focus -->
                <tr
                  class="obs-tr obs-tr-clickable"
                  role="button"
                  tabindex="0"
                  onclick={() => goto(`/sessions/${s.id}`)}
                  onkeydown={(e) => e.key === 'Enter' && goto(`/sessions/${s.id}`)}
                  aria-label="Open session {s.id}"
                >
                  <td class="obs-td obs-td-dot">
                    <StatusDot color={dotColor(s.status)} pulse={s.status === 'running'} />
                  </td>
                  <td class="obs-td obs-td-slug">{s.agentSlug ?? '—'}</td>
                  <td class="obs-td obs-mono">{s.runtimeType}</td>
                  <td class="obs-td obs-mono">{sessionDuration(s)}</td>
                  <td class="obs-td obs-mono">{relativeTime(s.insertedAt)}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      {/if}
    </section>

  </div>
</div>

<style>
  /* ── Page shell ── */
  .obs-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-6);
    overflow-y: auto;
    height: 100%;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  /* ── Header ── */
  .obs-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: var(--space-3);
    flex-shrink: 0;
  }

  .obs-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: var(--tracking-2xl);
    line-height: var(--lh-2xl);
  }

  .obs-header-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .obs-updated {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  .obs-refresh {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
  }

  .obs-refresh-label {
    font-size: var(--text-xs);
  }

  :global(.obs-spin) {
    animation: obs-rotate 1s linear infinite;
  }

  @keyframes obs-rotate {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  /* ── 12-column grid ── */
  .obs-grid {
    display: grid;
    grid-template-columns: repeat(12, 1fr);
    gap: var(--space-3);
  }

  .obs-span-3  { grid-column: span 3; }
  .obs-span-4  { grid-column: span 4; }
  .obs-span-5  { grid-column: span 5; }
  .obs-span-6  { grid-column: span 6; }
  .obs-span-12 { grid-column: span 12; }

  /* ── Widget shell — Linear.app card style ── */
  .obs-widget {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-4);
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    min-height: 0;
  }

  /* ── Section label (shared heading style) ── */
  .obs-section-label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    flex-shrink: 0;
  }

  /* ── Widget head (label + badge) ── */
  .obs-widget-head {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
  }

  .obs-badge {
    font-family: var(--font-mono);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 12%, transparent 88%);
    border-radius: 9999px;
    padding: 1px 6px;
    line-height: 1.5;
  }

  /* ── Stat cards (Row 1) ── */
  .obs-stat-card {
    gap: var(--space-1);
  }

  .obs-stat-num {
    font-family: var(--font-mono);
    font-size: 32px;
    font-weight: 700;
    font-feature-settings: "tnum";
    color: var(--fg);
    line-height: 1;
    letter-spacing: -0.02em;
  }

  .obs-stat-num-loading {
    color: var(--fg-subtle);
  }

  .obs-stat-unit {
    font-size: 18px;
    font-weight: 500;
    margin-left: 2px;
  }

  .obs-stat-sub {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
    letter-spacing: 0.02em;
  }

  /* ── Skeleton / error / empty ── */
  .obs-skeleton-wrap {
    flex: 1;
  }

  .obs-error-msg {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--signal-error);
    margin: 0;
  }

  .obs-empty-msg {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    margin: 0;
  }

  /* ── Active Agents widget (Row 2) ── */
  .obs-live-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: var(--space-2);
  }

  .obs-overflow-link {
    display: inline-block;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    text-decoration: none;
  }

  .obs-overflow-link:hover {
    color: var(--fg-muted);
    text-decoration: underline;
  }

  .obs-agent-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2);
    border-radius: var(--radius-sm);
    cursor: pointer;
    width: 100%;
    background: transparent;
    border: none;
    text-align: left;
    font-family: inherit;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .obs-agent-row:hover {
    background: color-mix(in oklch, var(--fg) 5%, transparent 95%);
  }

  .obs-agent-row:focus-visible {
    outline: 2px solid color-mix(in oklch, var(--fg) 40%, transparent 60%);
    outline-offset: 2px;
  }

  .obs-agent-slug {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    flex: 1;
  }

  .obs-agent-meta {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  .obs-chevron {
    color: var(--fg-subtle);
    font-size: 14px;
    line-height: 1;
    flex-shrink: 0;
  }

  /* ── KV table (Sandbox, Storage) ── */
  .obs-kv-table {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .obs-kv-row {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: var(--space-2);
  }

  .obs-kv-key {
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--fg-subtle);
  }

  .obs-kv-val {
    font-family: var(--font-mono);
    font-size: 12px;
    font-feature-settings: "tnum";
    color: var(--fg);
    font-weight: 500;
  }

  .obs-kv-muted {
    color: var(--fg-subtle);
  }

  /* ── Peak hours bar chart ── */
  .obs-hour-chart {
    display: flex;
    align-items: flex-end;
    gap: 2px;
    height: 56px;
    flex-shrink: 0;
  }

  .obs-hour-bar {
    flex: 1;
    background: var(--cnp-accent, color-mix(in oklch, var(--fg) 60%, transparent 40%));
    border-radius: 2px 2px 0 0;
    min-height: 3px;
    opacity: 0.75;
    transition: opacity var(--dur-instant);
  }

  .obs-hour-bar:hover {
    opacity: 1;
  }

  .obs-hour-labels {
    display: flex;
    justify-content: space-between;
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    padding-top: 2px;
  }

  /* ── Token usage bars ── */
  .obs-token-bars {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .obs-token-row {
    display: grid;
    grid-template-columns: 6rem 1fr 3.5rem;
    align-items: center;
    gap: var(--space-2);
  }

  .obs-token-label {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
    white-space: nowrap;
  }

  .obs-token-track {
    height: 5px;
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    border-radius: 9999px;
    overflow: hidden;
  }

  .obs-token-fill {
    height: 100%;
    border-radius: 9999px;
    transition: width var(--dur-normal) var(--ease-io);
  }

  .obs-token-fill-input {
    background: var(--cnp-accent, color-mix(in oklch, var(--fg) 60%, transparent 40%));
  }

  .obs-token-fill-output {
    background: color-mix(in oklch, var(--fg) 40%, transparent 60%);
  }

  .obs-token-fill-cache {
    background: color-mix(in oklch, var(--fg) 20%, transparent 80%);
  }

  .obs-token-val {
    font-family: var(--font-mono);
    font-size: 11px;
    font-feature-settings: "tnum";
    color: var(--fg-muted);
    text-align: right;
  }

  .obs-token-total {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
    padding-top: var(--space-1);
    border-top: 1px solid var(--border);
  }

  .obs-token-total-val {
    font-family: var(--font-mono);
    font-weight: 600;
    color: var(--fg);
  }

  /* ── Shared table styles ── */
  .obs-table-wrap {
    overflow-x: auto;
    flex: 1;
  }

  .obs-table {
    width: 100%;
    border-collapse: collapse;
  }

  .obs-th {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    color: var(--fg-subtle);
    padding: var(--space-1) var(--space-2);
    text-align: left;
    border-bottom: 1px solid var(--border);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    white-space: nowrap;
  }

  .obs-th-r { text-align: right; }

  .obs-th-dot {
    width: 20px;
    padding-right: 0;
  }

  .obs-tr {
    transition: background var(--dur-instant) var(--ease-out);
  }

  .obs-tr-clickable {
    cursor: pointer;
  }

  .obs-tr-clickable:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  .obs-tr-clickable:focus-visible {
    outline: 2px solid color-mix(in oklch, var(--fg) 40%, transparent 60%);
    outline-offset: -2px;
  }

  .obs-td {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    padding: var(--space-2);
    border-bottom: 1px solid color-mix(in oklch, var(--border) 50%, transparent 50%);
    white-space: nowrap;
  }

  .obs-td-dot {
    padding-right: 0;
    width: 20px;
  }

  .obs-td-slug {
    font-weight: 500;
    max-width: 12rem;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .obs-td-r {
    text-align: right;
  }

  .obs-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    font-feature-settings: "tnum";
  }

  /* ── Spend widget ── */
  .obs-spend-total {
    font-family: var(--font-mono);
    font-size: 28px;
    font-weight: 700;
    font-feature-settings: "tnum";
    color: var(--fg);
    letter-spacing: -0.02em;
    line-height: 1;
    flex-shrink: 0;
  }

  .obs-bars {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    flex-shrink: 0;
  }

  .obs-bar-row {
    display: grid;
    grid-template-columns: 8rem 1fr 4rem;
    align-items: center;
    gap: var(--space-2);
  }

  .obs-bar-label {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .obs-bar-track {
    height: 5px;
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    border-radius: 9999px;
    overflow: hidden;
  }

  .obs-bar-fill {
    height: 100%;
    background: var(--cnp-accent, color-mix(in oklch, var(--fg) 50%, transparent 50%));
    border-radius: 9999px;
    transition: width var(--dur-normal) var(--ease-io);
  }

  .obs-bar-value {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    font-feature-settings: "tnum";
    color: var(--fg-muted);
    text-align: right;
    white-space: nowrap;
  }

  /* ── Runtime split ── */
  .obs-runtime-split {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
    padding-top: var(--space-2);
    border-top: 1px solid var(--border);
    flex-shrink: 0;
  }

  .obs-runtime-head {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.07em;
  }

  .obs-runtime-pills {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-1);
  }

  .obs-runtime-pill {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 2px 8px;
  }

  .obs-runtime-name {
    color: var(--fg);
    font-weight: 500;
  }

  .obs-runtime-cost {
    color: var(--fg-muted);
  }

  /* ── Responsive ── */
  @media (max-width: 900px) {
    .obs-span-3,
    .obs-span-4,
    .obs-span-5,
    .obs-span-6 {
      grid-column: span 6;
    }
  }

  @media (max-width: 640px) {
    .obs-span-3,
    .obs-span-4,
    .obs-span-5,
    .obs-span-6,
    .obs-span-12 {
      grid-column: span 12;
    }

    .obs-bar-row {
      grid-template-columns: 6rem 1fr 3rem;
    }

    .obs-live-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
