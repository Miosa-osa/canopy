<script lang="ts">
/**
 * Activity feed — polled every 10s, grouped by relative day.
 * Route: /activity
 * CSS prefix: act- (Activity page)
 * LOC target: ≤ 280.
 */

import { createQuery } from '@tanstack/svelte-query';
import { writable } from 'svelte/store';
import { untrack, onDestroy } from 'svelte';
import { Activity } from 'lucide-svelte';
import { activityQuery } from '$lib/api/queries/activity.js';
import { subscribeLiveRuns } from '$lib/api/queries/live-runs.js';
import ActivityRow from '$lib/design/patterns/activity/ActivityRow.svelte';
import ActivityFilterBar from '$lib/design/patterns/activity/ActivityFilterBar.svelte';
import type { ActivityEvent, ActivityEventType } from '$lib/domain/activity/types.js';
import ViewPicker from '$lib/design/primitives/ViewPicker.svelte';
import type { ViewState } from '$lib/design/primitives/ViewPicker.svelte';

// ── Live-run WebSocket subscription ───────────────────────────────────────────
// Prepend run lifecycle events to the activity list in real time.
// Polled REST data remains the source of truth; WS adds zero-latency prepend.

const { events: liveEvents, disconnect: disconnectLiveRuns } = subscribeLiveRuns({
  workspace: 'default',
});

// Convert a live run event into a synthetic ActivityEvent for display.
function liveEventToActivity(ev: import('$lib/api/queries/live-runs.js').LiveRunEvent): ActivityEvent | null {
  const p = ev.payload as unknown as Record<string, unknown>;
  const runId = (p.runId ?? p.run_id ?? '') as string;
  const shortId = (p.shortId ?? p.short_id ?? runId) as string;
  const wsSlug = (p.workspaceSlug ?? p.workspace_slug ?? '') as string;

  const kindMap: Record<string, string> = {
    run_started: 'run.started',
    run_status: 'run.status',
    run_log: 'run.log',
    run_tool_call: 'run.tool_call',
    run_tool_result: 'run.tool_result',
    run_finished: 'run.finished',
    run_event: 'run.event',
  };

  return {
    id: `live-${ev.kind}-${runId}-${ev.receivedAt}`,
    type: (kindMap[ev.kind] ?? ev.kind) as ActivityEventType,
    at: ev.receivedAt,
    workspace_slug: wsSlug,
    actor: null,
    entity_type: 'run',
    entity_id: runId,
    entity_label: shortId,
    meta: p,
  } as unknown as ActivityEvent;
}

// Prepend new live events to the polled list reactively.
let liveActivityEvents = $state<ActivityEvent[]>([]);

$effect(() => {
  const evs = $liveEvents;
  if (evs.length === 0) return;
  const converted = evs
    .map(liveEventToActivity)
    .filter((e): e is ActivityEvent => e !== null);
  // Only prepend the newest batch (avoid re-inserting already-seen events).
  liveActivityEvents = converted;
});

onDestroy(disconnectLiveRuns);

// ── Filter state ──────────────────────────────────────────────────────────────

let selectedTypes = $state<ActivityEventType[]>([]);
let workspaceSlug = $state('');

// ── Query ─────────────────────────────────────────────────────────────────────

const queryOpts = writable(
  untrack(() =>
    activityQuery({ limit: 50 }),
  ),
);

const activityQ = createQuery<ActivityEvent[]>(queryOpts);

// Rebuild query opts when filters change.
$effect(() => {
  queryOpts.set(
    activityQuery({
      limit: 50,
      workspace_slug: workspaceSlug || undefined,
      type: selectedTypes.length > 0 ? selectedTypes : undefined,
    }),
  );
});

// ── Derived data ──────────────────────────────────────────────────────────────

// Merge live events at the head; deduplicate by id to avoid doubles after poll refresh.
const allEvents = $derived((): ActivityEvent[] => {
  const polled = ($activityQ.data ?? []) as ActivityEvent[];
  const polledIds = new Set(polled.map((e) => e.id));
  const fresh = liveActivityEvents.filter((e) => !polledIds.has(e.id));
  return [...fresh, ...polled];
});
const isLoading = $derived($activityQ.isLoading);
const isError = $derived($activityQ.isError);

const availableWorkspaces = $derived(
  [...new Set(allEvents().map((e) => e.workspace_slug).filter(Boolean))].sort(),
);

// ── Day grouping ──────────────────────────────────────────────────────────────

interface DayGroup {
  label: string;
  events: ActivityEvent[];
}

function dayLabel(iso: string): string {
  const d = new Date(iso);
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const yesterday = new Date(today.getTime() - 86_400_000);
  const weekAgo = new Date(today.getTime() - 7 * 86_400_000);
  const eventDay = new Date(d.getFullYear(), d.getMonth(), d.getDate());

  if (eventDay.getTime() === today.getTime()) return 'Today';
  if (eventDay.getTime() === yesterday.getTime()) return 'Yesterday';
  if (eventDay >= weekAgo) return 'This week';
  return d.toLocaleDateString(undefined, { year: 'numeric', month: 'long', day: 'numeric' });
}

const dayGroups = $derived((): DayGroup[] => {
  const map = new Map<string, ActivityEvent[]>();
  // Events arrive newest-first from the API — preserve that order.
  for (const ev of allEvents()) {
    const label = dayLabel(ev.at);
    const bucket = map.get(label) ?? [];
    bucket.push(ev);
    map.set(label, bucket);
  }
  return [...map.entries()].map(([label, events]) => ({ label, events }));
});

// ── Handlers ──────────────────────────────────────────────────────────────────

function handleClear(): void {
  selectedTypes = [];
  workspaceSlug = '';
}

let view = $state<ViewState>({ layout: 'list', density: 'comfortable', sort: 'recent' });
</script>

<div class="act-root">
  <!-- Header -->
  <header class="act-header" aria-label="Activity feed controls">
    <div class="act-header-left">
      <h1 class="act-title">Activity</h1>
      {#if !isLoading}
        <span class="act-count" aria-live="polite">
          {allEvents().length} {allEvents().length === 1 ? 'event' : 'events'}
        </span>
      {/if}
    </div>
    <ViewPicker routeSlug="activity" bind:view />
  </header>

  <!-- Filter bar -->
  <ActivityFilterBar
    {selectedTypes}
    {workspaceSlug}
    {availableWorkspaces}
    onTypesChange={(t) => { selectedTypes = t; }}
    onWorkspaceChange={(w) => { workspaceSlug = w; }}
    onClear={handleClear}
  />

  <!-- Content -->
  <div class="act-scroll" role="feed" aria-label="Activity events" aria-busy={isLoading}>
    {#if isLoading}
      <!-- Skeleton -->
      <div class="act-skeletons" aria-hidden="true">
        {#each Array(6) as _, i (i)}
          <div class="act-skeleton"></div>
        {/each}
      </div>

    {:else if isError}
      <div class="act-state" role="alert">
        <p class="act-state-heading">Failed to load activity</p>
        <p class="act-state-sub">Check your connection and try again.</p>
      </div>

    {:else if allEvents().length === 0}
      <div class="act-state" role="status">
        <div class="act-state-icon" aria-hidden="true">
          <Activity size={28} />
        </div>
        <p class="act-state-heading">No activity yet</p>
        <p class="act-state-sub">Spin up an agent to see events here.</p>
      </div>

    {:else}
      {#each dayGroups() as group (group.label)}
        <div class="act-day-group">
          <div class="act-day-label" role="heading" aria-level={2}>{group.label}</div>
          <div class="act-day-rows" role="list">
            {#each group.events as event (event.id)}
              <ActivityRow {event} />
            {/each}
          </div>
        </div>
      {/each}
    {/if}
  </div>
</div>

<style>
  .act-root {
    flex: 1;
    display: flex;
    flex-direction: column;
    min-height: 0;
    overflow: hidden;
  }

  /* Header */
  .act-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-6) var(--space-6) var(--space-3);
    flex-shrink: 0;
  }

  .act-header-left {
    display: flex;
    align-items: baseline;
    gap: var(--space-3);
  }

  .act-title {
    font-size: 13px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    margin: 0;
  }

  .act-count {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-subtle);
  }

  /* Scroll container */
  .act-scroll {
    flex: 1;
    overflow-y: auto;
    min-height: 0;
  }

  /* Day group */
  .act-day-group {
    display: flex;
    flex-direction: column;
  }

  .act-day-label {
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    opacity: 0.7;
    padding: var(--space-3) var(--space-4) var(--space-1);
    position: sticky;
    top: 0;
    background: var(--bg);
    z-index: 1;
    border-bottom: 1px solid var(--border);
  }

  .act-day-rows {
    display: flex;
    flex-direction: column;
  }

  /* Skeleton */
  .act-skeletons {
    display: flex;
    flex-direction: column;
    gap: 1px;
    padding: var(--space-4);
  }

  .act-skeleton {
    height: 56px;
    background: var(--bg-inset);
    border-radius: var(--radius-md);
    animation: act-pulse 1.5s ease-in-out infinite;
  }

  @keyframes act-pulse { 0%, 100% { opacity: 0.4; } 50% { opacity: 0.8; } }

  /* Empty / error state */
  .act-state {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--space-3);
    padding: var(--space-12);
    text-align: center;
    min-height: 300px;
  }

  .act-state-icon {
    color: var(--fg-subtle);
    opacity: 0.5;
  }

  .act-state-heading {
    font-size: 15px;
    font-weight: 600;
    color: var(--fg);
    margin: 0;
  }

  .act-state-sub {
    font-size: 13px;
    color: var(--fg-subtle);
    margin: 0;
  }

  @media (prefers-reduced-motion: reduce) {
    .act-skeleton { animation: none; }
  }
</style>
