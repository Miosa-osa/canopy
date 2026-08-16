<script lang="ts">
  /**
   * SessionsWidget — active sessions count + mini list.
   * CSS prefix: sw- (SessionsWidget)
   * Reads GET /api/v1/sessions (filter: status=running)
   */
  import { createQuery } from '@tanstack/svelte-query';
  import { writable } from 'svelte/store';
  import { untrack } from 'svelte';
  import { goto } from '$app/navigation';
  import { sessionsQuery } from '$lib/api/queries/sessions.js';
  import StatusDot from '$lib/design/patterns/StatusDot.svelte';
  import type { Session } from '$lib/domain/sessions/types.js';
  import type { CreateQueryOptions } from '@tanstack/svelte-query';

  const optsStore = writable(
    untrack(() => sessionsQuery({ status: 'running', limit: 10 }) as CreateQueryOptions<Session[]>),
  );
  const query = createQuery<Session[]>(optsStore);

  const sessions = $derived(($query.data ?? []) as Session[]);

  function relativeTime(iso: string): string {
    const diff = Date.now() - new Date(iso).getTime();
    const sec = Math.floor(diff / 1000);
    if (sec < 60) return `${sec}s`;
    const min = Math.floor(sec / 60);
    if (min < 60) return `${min}m`;
    return `${Math.floor(min / 60)}h`;
  }
</script>

<div class="sw-widget">
  {#if $query.isLoading}
    <p class="sw-empty">Loading…</p>
  {:else if $query.isError}
    <p class="sw-error">Failed to load sessions</p>
  {:else}
    <div class="sw-count" aria-label="{sessions.length} active sessions">
      {sessions.length}
      <span class="sw-count-label">active</span>
    </div>
    {#if sessions.length === 0}
      <p class="sw-empty">No sessions running</p>
    {:else}
      <ul class="sw-list" aria-label="Active sessions">
        {#each sessions.slice(0, 6) as session (session.id)}
          <li>
            <button
              class="sw-row"
              onclick={() => goto(`/sessions/${session.id}`)}
              aria-label="Open session for {session.agentSlug ?? 'unknown'}"
            >
              <StatusDot color="green" pulse={true} />
              <span class="sw-agent">{session.agentSlug ?? '—'}</span>
              <span class="sw-time">{relativeTime(session.insertedAt)}</span>
            </button>
          </li>
        {/each}
      </ul>
    {/if}
  {/if}
</div>

<style>
  .sw-widget {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-3);
  }

  .sw-count {
    font-family: var(--font-mono);
    font-size: 28px;
    font-weight: 700;
    color: var(--fg);
    line-height: 1;
    letter-spacing: -0.02em;
    display: flex;
    align-items: baseline;
    gap: var(--space-2);
  }

  .sw-count-label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    color: var(--fg-subtle);
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }

  .sw-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .sw-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    width: 100%;
    padding: 4px var(--space-1);
    background: transparent;
    border: none;
    cursor: pointer;
    border-radius: var(--radius-sm);
    transition: background var(--dur-instant) ease;
    font-family: inherit;
  }

  .sw-row:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent);
  }

  .sw-row:focus-visible {
    outline: 2px solid var(--fg-muted);
    outline-offset: 1px;
  }

  .sw-agent {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg);
    font-weight: 500;
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    text-align: left;
  }

  .sw-time {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    white-space: nowrap;
    flex-shrink: 0;
  }

  .sw-empty {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
  }

  .sw-error {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--signal-error, oklch(0.65 0.20 25));
  }
</style>
