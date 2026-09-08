<script lang="ts">
/**
 * /dashboard — Moveable widget grid.
 *
 * 6 draggable widgets, persistent order + size via localStorage.
 * Uses svelte-dnd-action (already installed). No heavy gridstack library.
 * CSS prefix: dg- (DashboardGrid)
 *
 * Layout key: canopy.dashboard.layout
 * Shape: {id: string, size: 'compact'|'normal'|'wide'}[]
 */

import type { CreateQueryOptions } from '@tanstack/svelte-query';
import { createQuery, useQueryClient } from '@tanstack/svelte-query';
import { RefreshCw, RotateCcw } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import type { DndEvent } from 'svelte-dnd-action';
import { dndzone } from 'svelte-dnd-action';
import { dashboardSummaryQuery } from '$lib/api/queries/dashboard.js';
import ActivitySparkline from '$lib/design/patterns/dashboard-widgets/ActivitySparkline.svelte';
import ActivityWidget from '$lib/design/patterns/dashboard-widgets/ActivityWidget.svelte';
import BudgetAlertWidget from '$lib/design/patterns/dashboard-widgets/BudgetAlertWidget.svelte';
import RuntimesWidget from '$lib/design/patterns/dashboard-widgets/RuntimesWidget.svelte';
import ScheduleWidget from '$lib/design/patterns/dashboard-widgets/ScheduleWidget.svelte';
import SessionsWidget from '$lib/design/patterns/dashboard-widgets/SessionsWidget.svelte';
import SpendWidget from '$lib/design/patterns/dashboard-widgets/SpendWidget.svelte';
import StatTile from '$lib/design/patterns/dashboard-widgets/StatTile.svelte';
import TasksWidget from '$lib/design/patterns/dashboard-widgets/TasksWidget.svelte';
import WidgetShell from '$lib/design/patterns/dashboard-widgets/WidgetShell.svelte';
import type { DashboardSummary } from '$lib/domain/dashboard/types.js';

const queryClient = useQueryClient();

// ── Dashboard summary (for SpendWidget) ──────────────────────────────────────

const summaryOptsStore = writable(
  untrack(() => dashboardSummaryQuery() as CreateQueryOptions<DashboardSummary>)
);
const summaryQuery = createQuery<DashboardSummary>(summaryOptsStore);
const summary = $derived($summaryQuery.data ?? null);

// ── Layout persistence ────────────────────────────────────────────────────────

type WidgetSize = 'compact' | 'normal' | 'wide';

interface WidgetItem {
  id: string;
  size: WidgetSize;
}

const LAYOUT_KEY = 'canopy.dashboard.layout';

const WIDGET_LABELS: Record<string, string> = {
  sessions: 'Active Sessions',
  tasks: 'Tasks by Status',
  activity: 'Recent Activity',
  spend: 'Spend This Month',
  runtimes: 'Runtimes Status',
  schedule: 'Upcoming Schedule',
  activity_sparkline: 'Activity Trend',
  budget_alerts: 'Budget Alerts',
  stat_tiles: 'Stats',
};

const DEFAULT_LAYOUT: WidgetItem[] = [
  { id: 'sessions', size: 'normal' },
  { id: 'tasks', size: 'normal' },
  { id: 'activity', size: 'normal' },
  { id: 'spend', size: 'normal' },
  { id: 'runtimes', size: 'normal' },
  { id: 'schedule', size: 'normal' },
  { id: 'activity_sparkline', size: 'compact' },
  { id: 'budget_alerts', size: 'normal' },
  { id: 'stat_tiles', size: 'normal' },
];

function loadLayout(): WidgetItem[] {
  if (typeof localStorage === 'undefined') return DEFAULT_LAYOUT;
  try {
    const raw = localStorage.getItem(LAYOUT_KEY);
    if (!raw) return DEFAULT_LAYOUT;
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return DEFAULT_LAYOUT;
    // Validate and fill in any missing ids from default
    const valid = (parsed as WidgetItem[]).filter(
      (item) => typeof item.id === 'string' && typeof item.size === 'string'
    );
    const ids = new Set(valid.map((i) => i.id));
    const missing = DEFAULT_LAYOUT.filter((d) => !ids.has(d.id));
    return [...valid, ...missing];
  } catch {
    return DEFAULT_LAYOUT;
  }
}

function saveLayout(items: WidgetItem[]): void {
  if (typeof localStorage === 'undefined') return;
  localStorage.setItem(LAYOUT_KEY, JSON.stringify(items));
}

let items = $state<WidgetItem[]>(loadLayout());

// ── DnD ───────────────────────────────────────────────────────────────────────

const FLIP_MS = 200;

function handleConsider(e: CustomEvent<DndEvent<WidgetItem>>): void {
  items = e.detail.items;
}

function handleFinalize(e: CustomEvent<DndEvent<WidgetItem>>): void {
  items = e.detail.items;
  saveLayout(items);
}

// ── Size changes ──────────────────────────────────────────────────────────────

function handleSizeChange(id: string, size: WidgetSize): void {
  items = items.map((item) => (item.id === id ? { ...item, size } : item));
  saveLayout(items);
}

// ── Actions ───────────────────────────────────────────────────────────────────

function resetLayout(): void {
  items = [...DEFAULT_LAYOUT];
  if (typeof localStorage !== 'undefined') {
    localStorage.removeItem(LAYOUT_KEY);
  }
}

function handleRefresh(): void {
  void queryClient.invalidateQueries({ queryKey: ['dashboard', 'summary'] });
}

const updatedLabel = $derived(
  $summaryQuery.dataUpdatedAt > 0
    ? `Updated ${relativeTime(new Date($summaryQuery.dataUpdatedAt).toISOString())}`
    : ''
);

function relativeTime(iso: string | null | undefined): string {
  if (!iso) return '—';
  const diff = Date.now() - new Date(iso).getTime();
  if (diff < 0) return 'just now';
  const sec = Math.floor(diff / 1000);
  if (sec < 60) return `${sec}s ago`;
  const min = Math.floor(sec / 60);
  if (min < 60) return `${min}m ago`;
  const hr = Math.floor(min / 60);
  return `${hr}h ago`;
}
</script>

<div class="dg-page">
  <!-- Header -->
  <header class="dg-header">
    <h1 class="dg-title">Dashboard</h1>
    <div class="dg-actions">
      {#if updatedLabel}
        <span class="dg-updated">{updatedLabel}</span>
      {/if}
      <button
        class="btn-compact btn-compact-ghost dg-action-btn"
        onclick={resetLayout}
        aria-label="Reset dashboard layout"
        title="Reset layout"
      >
        <RotateCcw size={12} aria-hidden="true" />
        <span>Reset layout</span>
      </button>
      <button
        class="btn-compact btn-compact-ghost dg-action-btn"
        onclick={handleRefresh}
        aria-label="Refresh dashboard"
        title="Refresh"
        disabled={$summaryQuery.isFetching}
      >
        <RefreshCw
          size={12}
          aria-hidden="true"
          class={$summaryQuery.isFetching ? 'dg-spin' : ''}
        />
        <span>Refresh</span>
      </button>
    </div>
  </header>

  <!-- Moveable grid -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="dg-grid"
    use:dndzone={{ items, flipDurationMs: FLIP_MS, type: 'dashboard-widget' }}
    onconsider={handleConsider}
    onfinalize={handleFinalize}
    role="region"
    aria-label="Dashboard widget grid — drag to reorder"
  >
    {#each items as item (item.id)}
      <div
        class="dg-cell dg-cell--{item.size}"
        aria-label={WIDGET_LABELS[item.id] ?? item.id}
      >
        <WidgetShell
          id={item.id}
          label={WIDGET_LABELS[item.id] ?? item.id}
          size={item.size}
          onSizeChange={handleSizeChange}
        >
          {#if item.id === 'sessions'}
            <SessionsWidget />
          {:else if item.id === 'tasks'}
            <TasksWidget />
          {:else if item.id === 'activity'}
            <ActivityWidget />
          {:else if item.id === 'spend'}
            <SpendWidget
              summary={summary}
              loading={$summaryQuery.isLoading}
              error={$summaryQuery.isError}
            />
          {:else if item.id === 'runtimes'}
            <RuntimesWidget />
          {:else if item.id === 'schedule'}
            <ScheduleWidget />
          {:else if item.id === 'activity_sparkline'}
            <ActivitySparkline
              label="Sessions (7d)"
              values={summary?.peakHours30d?.slice(-7) ?? []}
            />
          {:else if item.id === 'budget_alerts'}
            <BudgetAlertWidget />
          {:else if item.id === 'stat_tiles'}
            <div class="dg-stat-grid">
              <StatTile
                label="Active Agents"
                value={summary?.activeAgents?.length ?? '—'}
                delta={null}
              />
              <StatTile
                label="Total Sessions"
                value={summary?.totalSessions?.count ?? '—'}
                delta={null}
              />
            </div>
          {/if}
        </WidgetShell>
      </div>
    {/each}
  </div>
</div>

<style>
  /* ── Page shell ── */
  .dg-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-6);
    overflow-y: auto;
    height: 100%;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  /* ── Header ── */
  .dg-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: var(--space-3);
    flex-shrink: 0;
  }

  .dg-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: var(--tracking-2xl);
    line-height: var(--lh-2xl);
  }

  .dg-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .dg-updated {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  .dg-action-btn {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    font-size: var(--text-xs);
  }

  :global(.dg-spin) {
    animation: dg-rotate 1s linear infinite;
  }

  @keyframes dg-rotate {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  /* ── Widget grid ── */
  .dg-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--space-3);
    align-items: start;
  }

  /* ── Cell size variants — wide spans 2 columns ── */
  .dg-cell {
    min-height: 180px;
  }

  .dg-cell--compact {
    min-height: 100px;
  }

  .dg-cell--wide {
    grid-column: span 2;
  }

  /* ── Stat tiles grid (inside widget body) ── */
  .dg-stat-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: var(--space-2);
    padding: var(--space-2);
  }

  /* ── Drag ghost ── */
  :global(.dg-grid > [aria-grabbed="true"]) {
    opacity: 0.55;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.2);
  }

  /* ── Responsive ── */
  @media (max-width: 900px) {
    .dg-grid {
      grid-template-columns: repeat(2, 1fr);
    }

    .dg-cell--wide {
      grid-column: span 2;
    }
  }

  @media (max-width: 600px) {
    .dg-grid {
      grid-template-columns: 1fr;
    }

    .dg-cell--wide {
      grid-column: span 1;
    }
  }
</style>
