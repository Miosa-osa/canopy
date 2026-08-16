<script lang="ts">
  /**
   * ScheduleWidget — next 5 scheduled items from /schedule.
   * Expects 404 gracefully — fallback to "No items scheduled".
   * CSS prefix: schw- (ScheduleWidget)
   */
  import { createQuery } from '@tanstack/svelte-query';
  import { writable } from 'svelte/store';
  import { untrack } from 'svelte';
  import { apiGet } from '$lib/api/client.js';
  import type { CreateQueryOptions } from '@tanstack/svelte-query';

  interface ScheduleItem {
    id: string;
    title: string;
    scheduledAt: string;
    kind?: string;
  }

  async function fetchSchedule(): Promise<ScheduleItem[]> {
    try {
      return await apiGet<ScheduleItem[]>('/schedule');
    } catch {
      // 404 or any error → treat as empty
      return [];
    }
  }

  const optsStore = writable(
    untrack(
      () =>
        ({
          queryKey: ['schedule', 'upcoming'] as const,
          queryFn: fetchSchedule,
          staleTime: 60_000,
          retry: false,
        }) as CreateQueryOptions<ScheduleItem[]>,
    ),
  );
  const query = createQuery<ScheduleItem[]>(optsStore);

  const items = $derived(($query.data ?? []).slice(0, 5));

  function formatDate(iso: string): string {
    const d = new Date(iso);
    return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
  }
</script>

<div class="schw-widget">
  {#if $query.isLoading}
    <p class="schw-empty">Loading…</p>
  {:else if items.length === 0}
    <p class="schw-empty">No items scheduled</p>
  {:else}
    <ul class="schw-list" aria-label="Upcoming schedule">
      {#each items as item (item.id)}
        <li class="schw-item">
          <div class="schw-content">
            <span class="schw-title">{item.title}</span>
            {#if item.kind}
              <span class="schw-kind">{item.kind}</span>
            {/if}
          </div>
          <span class="schw-date">{formatDate(item.scheduledAt)}</span>
        </li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .schw-widget {
    padding: var(--space-3);
    display: flex;
    flex-direction: column;
  }

  .schw-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .schw-item {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: var(--space-2);
    padding: 5px var(--space-1);
    border-radius: var(--radius-sm);
  }

  .schw-content {
    display: flex;
    flex-direction: column;
    gap: 1px;
    flex: 1;
    min-width: 0;
  }

  .schw-title {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg);
    font-weight: 500;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .schw-kind {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .schw-date {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-muted);
    white-space: nowrap;
    flex-shrink: 0;
  }

  .schw-empty {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
  }
</style>
