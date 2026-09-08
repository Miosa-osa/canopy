<script lang="ts">
/**
 * LifecyclePanel — shows hook events linked to a Canopy session.
 * CSS prefix: lcp-
 * Rendered in session detail sidebar "Lifecycle" tab.
 * LOC target: ≤ 120.
 */

import { createQuery } from '@tanstack/svelte-query';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { apiGet } from '$lib/api/client.js';

interface HookEvent {
  id: string;
  agent: string;
  event: string;
  session_id: string | null;
  run_id: string | null;
  payload: Record<string, unknown>;
  inserted_at: string;
}

interface Props {
  sessionId: string;
}

let { sessionId }: Props = $props();

const queryOptsStore = writable(
  untrack(() => ({
    queryKey: ['sessions', sessionId, 'lifecycle'],
    queryFn: () =>
      apiGet<{ data: HookEvent[] }>(`/sessions/${sessionId}/lifecycle`).then((r) => r.data ?? []),
    refetchInterval: 8_000,
    enabled: !!sessionId,
  }))
);

$effect(() => {
  queryOptsStore.set({
    queryKey: ['sessions', sessionId, 'lifecycle'],
    queryFn: () =>
      apiGet<{ data: HookEvent[] }>(`/sessions/${sessionId}/lifecycle`).then((r) => r.data ?? []),
    refetchInterval: 8_000,
    enabled: !!sessionId,
  });
});

const lifecycleQuery = createQuery<HookEvent[]>(queryOptsStore);

function relTime(isoStr: string): string {
  const ms = Date.now() - new Date(isoStr).getTime();
  if (ms < 60_000) return `${Math.floor(ms / 1000)}s ago`;
  if (ms < 3_600_000) return `${Math.floor(ms / 60_000)}m ago`;
  return `${Math.floor(ms / 3_600_000)}h ago`;
}
</script>

<div class="lcp-root" aria-label="Lifecycle events">
  {#if $lifecycleQuery.isLoading}
    <p class="lcp-hint">Loading…</p>
  {:else if !$lifecycleQuery.data?.length}
    <p class="lcp-hint">No lifecycle events yet. Events appear when the agent sends hook notifications.</p>
  {:else}
    <ul class="lcp-list" role="list">
      {#each ($lifecycleQuery.data ?? []) as ev (ev.id)}
        <li class="lcp-row">
          <div class="lcp-dot" aria-hidden="true"></div>
          <div class="lcp-body">
            <div class="lcp-top">
              <span class="lcp-event">{ev.event}</span>
              <span class="lcp-agent">{ev.agent}</span>
              <time class="lcp-time" datetime={ev.inserted_at}>{relTime(ev.inserted_at)}</time>
            </div>
            {#if ev.payload?.tool_name}
              <span class="lcp-tool">tool: {String(ev.payload.tool_name)}</span>
            {/if}
          </div>
        </li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .lcp-root {
    padding: var(--space-3);
  }

  .lcp-hint {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    padding: var(--space-4) var(--space-2);
    text-align: center;
    line-height: 1.5;
    margin: 0;
  }

  .lcp-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 0;
    position: relative;
  }

  .lcp-row {
    display: flex;
    align-items: flex-start;
    gap: var(--space-2);
    padding: var(--space-2) 0;
    position: relative;
  }

  .lcp-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--cnp-accent);
    flex-shrink: 0;
    margin-top: 5px;
  }

  .lcp-body {
    display: flex;
    flex-direction: column;
    gap: 2px;
    flex: 1;
    min-width: 0;
  }

  .lcp-top {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-wrap: wrap;
  }

  .lcp-event {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg);
  }

  .lcp-agent {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    padding: 1px 5px;
    border-radius: var(--radius-sm);
  }

  .lcp-time {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    margin-left: auto;
  }

  .lcp-tool {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-muted);
  }
</style>
