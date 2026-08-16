<script lang="ts">
  /**
   * ActivityWidget — last 10 agent activity events from /notifications.
   * CSS prefix: aw- (ActivityWidget)
   */
  import { createQuery } from '@tanstack/svelte-query';
  import { writable } from 'svelte/store';
  import { untrack } from 'svelte';
  import { notificationsQuery } from '$lib/api/queries/notifications.js';
  import type { Notification } from '$lib/domain/notifications/types.js';
  import type { CreateQueryOptions } from '@tanstack/svelte-query';

  const optsStore = writable(
    untrack(() => notificationsQuery({ limit: 10 }) as CreateQueryOptions<Notification[]>),
  );
  const query = createQuery<Notification[]>(optsStore);

  const events = $derived(($query.data ?? []) as Notification[]);

  function relativeTime(iso: string): string {
    const diff = Date.now() - new Date(iso).getTime();
    const sec = Math.floor(diff / 1000);
    if (sec < 60) return `${sec}s ago`;
    const min = Math.floor(sec / 60);
    if (min < 60) return `${min}m ago`;
    const hr = Math.floor(min / 60);
    if (hr < 24) return `${hr}h ago`;
    return `${Math.floor(hr / 24)}d ago`;
  }
</script>

<div class="aw-widget">
  {#if $query.isLoading}
    <p class="aw-empty">Loading…</p>
  {:else if $query.isError}
    <p class="aw-error">Failed to load activity</p>
  {:else if events.length === 0}
    <p class="aw-empty">No recent activity</p>
  {:else}
    <ul class="aw-list" aria-label="Recent agent activity">
      {#each events as event (event.id)}
        <li class="aw-item">
          <div class="aw-dot" aria-hidden="true"></div>
          <div class="aw-content">
            <span class="aw-title">{event.title}</span>
            {#if event.agentSlug}
              <span class="aw-agent">{event.agentSlug}</span>
            {/if}
          </div>
          <span class="aw-time">{relativeTime(event.insertedAt)}</span>
        </li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .aw-widget {
    padding: var(--space-3);
    display: flex;
    flex-direction: column;
  }

  .aw-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .aw-item {
    display: flex;
    align-items: flex-start;
    gap: var(--space-2);
    padding: 5px var(--space-1);
    border-radius: var(--radius-sm);
    transition: background var(--dur-instant) ease;
  }

  .aw-item:hover {
    background: color-mix(in oklch, var(--fg) 5%, transparent);
  }

  .aw-dot {
    width: 6px;
    height: 6px;
    border-radius: 9999px;
    background: var(--cnp-accent, color-mix(in oklch, var(--fg) 40%, transparent));
    flex-shrink: 0;
    margin-top: 5px;
  }

  .aw-content {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 1px;
    min-width: 0;
  }

  .aw-title {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg);
    font-weight: 500;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .aw-agent {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .aw-time {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    white-space: nowrap;
    flex-shrink: 0;
  }

  .aw-empty,
  .aw-error {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
  }

  .aw-empty { color: var(--fg-subtle); }
  .aw-error { color: var(--signal-error, oklch(0.65 0.20 25)); }
</style>
