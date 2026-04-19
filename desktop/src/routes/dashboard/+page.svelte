<script lang="ts">
/**
 * /dashboard — Command Center.
 *
 * Three widgets inline (NO separate widget components):
 *   Row 1: Active Agents (full width)
 *   Row 2: Spend This Month (left) + Recent Sessions (right)
 *
 * Query: dashboardSummaryQuery — staleTime 30s, refetchOnWindowFocus: true.
 * Manual refresh button forces invalidation.
 * CSS prefix: cc- (Command Center)
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

// Hired agents — used to look up full Agent objects for AgentLiveCard
const hiredAgentsOptsStore = writable(
  untrack(() => hiredAgentsQuery() as CreateQueryOptions<Agent[]>)
);
const hiredQ = createQuery<Agent[]>(hiredAgentsOptsStore);

/** Map from agent slug → full Agent for cards. */
const agentBySlug = $derived(
  ($hiredQ.data ?? []).reduce<Record<string, Agent>>((acc, a) => {
    acc[a.slug] = a;
    return acc;
  }, {})
);

const summary = $derived($query.data ?? null);

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Format an ISO timestamp into a relative "Xm ago" / "Xs ago" string. */
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

/** Format a session's duration between insertedAt and completedAt. */
function sessionDuration(s: RecentSession): string {
  if (!s.completedAt) return 'running';
  const ms = new Date(s.completedAt).getTime() - new Date(s.insertedAt).getTime();
  if (ms < 0) return '—';
  const secs = Math.floor(ms / 1000);
  if (secs < 60) return `${secs}s`;
  return `${Math.floor(secs / 60)}m ${secs % 60}s`;
}

/** Format a USD decimal string to "$X.XX". */
function formatUsd(raw: string): string {
  const n = parseFloat(raw);
  return isNaN(n) ? '$—' : `$${n.toFixed(2)}`;
}

/** Compute bar width % relative to the max bar in the list (capped 4–100%). */
function barWidths(agents: SpendByAgent[]): number[] {
  if (agents.length === 0) return [];
  const vals = agents.map((a) => Math.max(0, parseFloat(a.costUsd) || 0));
  const max = Math.max(...vals, 0.001);
  return vals.map((v) => Math.max(4, Math.round((v / max) * 100)));
}

/** Map a session status string to a StatusDot color. */
function dotColor(status: string): 'green' | 'amber' | 'red' | 'grey' {
  switch (status) {
    case 'running': return 'green';
    case 'error': return 'red';
    case 'paused':
    case 'pending': return 'amber';
    default: return 'grey';
  }
}

/** Reactive "Updated Xm ago" label — refreshed on query data change. */
const updatedLabel = $derived(
  $query.dataUpdatedAt > 0 ? `Updated ${relativeTime(new Date($query.dataUpdatedAt).toISOString())}` : ''
);

function handleRefresh(): void {
  void queryClient.invalidateQueries({ queryKey: ['dashboard', 'summary'] });
}
</script>

<div class="cc-page">
  <!-- Header -->
  <header class="cc-header">
    <h1 class="cc-title">Command Center</h1>
    <div class="cc-header-actions">
      {#if updatedLabel}
        <span class="cc-updated">{updatedLabel}</span>
      {/if}
      <button
        class="btn-compact btn-compact-ghost cc-refresh"
        onclick={handleRefresh}
        aria-label="Refresh dashboard"
        title="Refresh"
        disabled={$query.isFetching}
      >
        <RefreshCw
          size={12}
          aria-hidden="true"
          class={$query.isFetching ? 'cc-spin' : ''}
        />
        <span class="cc-refresh-label">Refresh</span>
      </button>
    </div>
  </header>

  <!-- Grid -->
  <div class="cc-grid">
    <!-- ── Row 1: Active Agents (full width) ── -->
    <section class="glass-card cc-widget cc-widget-full" aria-label="Active agents">
      <div class="cc-widget-head">
        <span class="cc-widget-title">Active Agents</span>
        {#if summary}
          <span class="cc-badge">{summary.activeAgents.length}</span>
        {/if}
      </div>

      {#if $query.isLoading}
        <div class="cc-skeleton-wrap">
          <SkeletonList count={3} height="2.5rem" gap="0.5rem" />
        </div>
      {:else if $query.isError}
        <p class="cc-error-msg">Failed to load — {($query.error as Error).message}</p>
      {:else if !summary || summary.activeAgents.length === 0}
        <p class="cc-empty-msg">No agents are currently running.</p>
      {:else}
        {@const visible = summary.activeAgents.slice(0, 8)}
        {@const overflow = summary.activeAgents.length - visible.length}
        <div class="cc-live-grid">
          {#each visible as activeAgent (activeAgent.currentSessionId)}
            {@const fullAgent = agentBySlug[activeAgent.agentSlug ?? '']}
            {#if fullAgent}
              <AgentLiveCard agent={fullAgent} compact />
            {:else}
              <!-- Fallback row while hiredAgentsQuery resolves -->
              <button
                class="cc-agent-row"
                onclick={() => goto(`/sessions/${activeAgent.currentSessionId}`)}
                aria-label="Open session for {activeAgent.agentSlug ?? 'unknown agent'}"
              >
                <StatusDot color="green" pulse={true} />
                <span class="cc-agent-slug">{activeAgent.agentSlug ?? '—'}</span>
                <span class="cc-agent-meta">{relativeTime(activeAgent.startedAt)}</span>
                <span class="cc-chevron" aria-hidden="true">›</span>
              </button>
            {/if}
          {/each}
        </div>
        {#if overflow > 0}
          <a class="cc-overflow-link" href="/agents?hired=true">+ {overflow} more</a>
        {/if}
      {/if}
    </section>

    <!-- ── Row 2 left: Spend This Month ── -->
    <section class="glass-card cc-widget cc-widget-half" aria-label="Spend this month">
      <div class="cc-widget-head">
        <span class="cc-widget-title">Spend This Month</span>
      </div>

      {#if $query.isLoading}
        <div class="cc-skeleton-wrap">
          <SkeletonList count={4} height="1.75rem" gap="0.5rem" />
        </div>
      {:else if $query.isError}
        <p class="cc-error-msg">Failed to load</p>
      {:else if !summary}
        <p class="cc-empty-msg">No spend data.</p>
      {:else}
        <!-- Big total -->
        <div class="cc-spend-total" aria-label="Total spend {formatUsd(summary.spendThisMonth.totalUsd)}">
          {formatUsd(summary.spendThisMonth.totalUsd)}
        </div>

        <!-- Per-agent bars -->
        {#if summary.spendThisMonth.byAgent.length > 0}
          <div class="cc-bars" aria-label="Spend by agent">
            {#each summary.spendThisMonth.byAgent as row, i (row.agentSlug)}
              <div class="cc-bar-row">
                <span class="cc-bar-label">{row.agentSlug}</span>
                <div class="cc-bar-track" role="progressbar" aria-valuenow={parseFloat(row.costUsd)} aria-label={row.agentSlug}>
                  <div
                    class="cc-bar-fill"
                    style="width: {barWidths(summary.spendThisMonth.byAgent)[i]}%;"
                  ></div>
                </div>
                <span class="cc-bar-value">{formatUsd(row.costUsd)}</span>
              </div>
            {/each}
          </div>
        {:else}
          <p class="cc-empty-msg cc-empty-msg-sm">No per-agent data yet.</p>
        {/if}

        <!-- Runtime split -->
        {#if summary.spendThisMonth.byRuntime.length > 0}
          <div class="cc-runtime-split" aria-label="Spend by runtime">
            <span class="cc-runtime-label-head">By runtime</span>
            <div class="cc-runtime-pills">
              {#each summary.spendThisMonth.byRuntime as rt (rt.runtimeType)}
                <span class="cc-runtime-pill">
                  <span class="cc-runtime-name">{rt.runtimeType}</span>
                  <span class="cc-runtime-cost">{formatUsd(rt.costUsd)}</span>
                </span>
              {/each}
            </div>
          </div>
        {/if}
      {/if}
    </section>

    <!-- ── Row 2 right: Recent Sessions ── -->
    <section class="glass-card cc-widget cc-widget-half" aria-label="Recent sessions">
      <div class="cc-widget-head">
        <span class="cc-widget-title">Recent Sessions</span>
      </div>

      {#if $query.isLoading}
        <div class="cc-skeleton-wrap">
          <SkeletonList count={5} height="2.25rem" gap="0.375rem" />
        </div>
      {:else if $query.isError}
        <p class="cc-error-msg">Failed to load</p>
      {:else if !summary || summary.recentSessions.length === 0}
        <p class="cc-empty-msg">No sessions yet.</p>
      {:else}
        <div class="cc-session-table-wrap">
          <table class="cc-session-table">
            <thead>
              <tr>
                <th class="cc-th cc-th-dot"></th>
                <th class="cc-th">Agent</th>
                <th class="cc-th">Runtime</th>
                <th class="cc-th">Duration</th>
                <th class="cc-th">When</th>
              </tr>
            </thead>
            <tbody>
              {#each summary.recentSessions as s (s.id)}
                <!-- svelte-ignore a11y_interactive_supports_focus -->
                <tr
                  class="cc-session-row"
                  role="button"
                  tabindex="0"
                  onclick={() => goto(`/sessions/${s.id}`)}
                  onkeydown={(e) => e.key === 'Enter' && goto(`/sessions/${s.id}`)}
                  aria-label="Open session {s.id}"
                >
                  <td class="cc-td cc-td-dot">
                    <StatusDot color={dotColor(s.status)} pulse={s.status === 'running'} />
                  </td>
                  <td class="cc-td cc-td-agent">{s.agentSlug ?? '—'}</td>
                  <td class="cc-td cc-mono">{s.runtimeType}</td>
                  <td class="cc-td cc-mono">{sessionDuration(s)}</td>
                  <td class="cc-td cc-mono">{relativeTime(s.insertedAt)}</td>
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
  .cc-page {
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
  .cc-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: var(--space-3);
    flex-shrink: 0;
  }

  .cc-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: var(--tracking-2xl);
    line-height: var(--lh-2xl);
  }

  .cc-header-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .cc-updated {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  .cc-refresh {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
  }

  .cc-refresh-label {
    font-size: var(--text-xs);
  }

  /* Spin animation for fetching state applied via :global to the Lucide icon svg */
  :global(.cc-spin) {
    animation: cc-rotate 1s linear infinite;
  }

  @keyframes cc-rotate {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  /* ── Grid ── */
  .cc-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    grid-template-rows: auto auto;
    gap: var(--space-4);
    flex: 1;
    min-height: 0;
  }

  /* ── Widget shells ── */
  .cc-widget {
    padding: var(--space-4);
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    min-height: 0;
    overflow: hidden;
  }

  /* Full-width: spans both columns */
  .cc-widget-full {
    grid-column: 1 / -1;
  }

  /* Half-width: one column each */
  .cc-widget-half {
    grid-column: span 1;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  /* ── Widget header ── */
  .cc-widget-head {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
  }

  .cc-widget-title {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.07em;
  }

  .cc-badge {
    font-family: var(--font-mono);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 12%, transparent 88%);
    border-radius: 9999px;
    padding: 1px 6px;
    line-height: 1.5;
  }

  /* ── Skeleton / error / empty ── */
  .cc-skeleton-wrap {
    flex: 1;
  }

  .cc-error-msg {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--signal-error);
    margin: 0;
  }

  .cc-empty-msg {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    margin: 0;
  }

  .cc-empty-msg-sm {
    font-size: var(--text-xs);
  }

  /* ── Active Agents widget ── */

  /* 2-column grid for AgentLiveCard compact cards; collapses to 1 on narrow */
  .cc-live-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: var(--space-2);
  }

  .cc-overflow-link {
    display: inline-block;
    margin-top: var(--space-1);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    text-decoration: none;
  }

  .cc-overflow-link:hover {
    color: var(--fg-muted);
    text-decoration: underline;
  }

  /* Fallback row (while hiredAgentsQuery is resolving) */
  .cc-agent-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-2);
    border-radius: var(--radius-md);
    cursor: pointer;
    width: 100%;
    background: transparent;
    border: none;
    text-align: left;
    font-family: inherit;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .cc-agent-row:hover {
    background: color-mix(in oklch, var(--fg) 5%, transparent 95%);
  }

  .cc-agent-row:focus-visible {
    outline: 2px solid color-mix(in oklch, var(--fg) 40%, transparent 60%);
    outline-offset: 2px;
  }

  .cc-agent-slug {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    flex: 1;
  }

  .cc-agent-meta {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  .cc-chevron {
    color: var(--fg-subtle);
    font-size: 14px;
    line-height: 1;
    flex-shrink: 0;
  }

  /* ── Spend widget ── */
  .cc-spend-total {
    font-family: var(--font-mono);
    font-size: var(--text-3xl, 2rem);
    font-weight: 700;
    color: var(--fg);
    letter-spacing: -0.03em;
    line-height: 1;
    flex-shrink: 0;
  }

  .cc-bars {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    flex-shrink: 0;
  }

  .cc-bar-row {
    display: grid;
    grid-template-columns: 8rem 1fr 4rem;
    align-items: center;
    gap: var(--space-2);
  }

  .cc-bar-label {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .cc-bar-track {
    height: 6px;
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    border-radius: 9999px;
    overflow: hidden;
  }

  .cc-bar-fill {
    height: 100%;
    background: linear-gradient(
      90deg,
      color-mix(in oklch, var(--fg) 50%, transparent 50%),
      color-mix(in oklch, var(--fg) 30%, transparent 70%)
    );
    border-radius: 9999px;
    transition: width var(--dur-normal) var(--ease-io);
  }

  .cc-bar-value {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    text-align: right;
    white-space: nowrap;
  }

  /* ── Runtime split ── */
  .cc-runtime-split {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
    padding-top: var(--space-2);
    border-top: 1px solid var(--border);
    flex-shrink: 0;
  }

  .cc-runtime-label-head {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.07em;
  }

  .cc-runtime-pills {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-1);
  }

  .cc-runtime-pill {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: 2px 8px;
  }

  .cc-runtime-name {
    color: var(--fg);
    font-weight: 500;
  }

  .cc-runtime-cost {
    color: var(--fg-muted);
  }

  /* ── Recent Sessions widget ── */
  .cc-session-table-wrap {
    overflow-x: auto;
    flex: 1;
  }

  .cc-session-table {
    width: 100%;
    border-collapse: collapse;
  }

  .cc-th {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-muted);
    padding: var(--space-1) var(--space-2);
    text-align: left;
    border-bottom: 1px solid var(--border);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    white-space: nowrap;
  }

  .cc-th-dot {
    width: 24px;
    padding-right: 0;
  }

  .cc-session-row {
    cursor: pointer;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .cc-session-row:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  .cc-session-row:focus-visible {
    outline: 2px solid color-mix(in oklch, var(--fg) 40%, transparent 60%);
    outline-offset: -2px;
  }

  .cc-td {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    padding: var(--space-2) var(--space-2);
    border-bottom: 1px solid color-mix(in oklch, var(--border) 50%, transparent 50%);
    white-space: nowrap;
  }

  .cc-td-dot {
    padding-right: 0;
    width: 24px;
  }

  .cc-td-agent {
    font-weight: 500;
    max-width: 10rem;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .cc-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  /* ── Responsive: collapse to single column on narrow viewports ── */
  @media (max-width: 680px) {
    .cc-grid {
      grid-template-columns: 1fr;
    }

    .cc-widget-half {
      grid-column: 1 / -1;
    }

    .cc-bar-row {
      grid-template-columns: 6rem 1fr 3.5rem;
    }

    .cc-live-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
