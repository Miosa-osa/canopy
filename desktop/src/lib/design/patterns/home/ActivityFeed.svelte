<script lang="ts">
import { createQuery } from '@tanstack/svelte-query';
import { ArrowRight } from 'lucide-svelte';
import { goto } from '$app/navigation';
import { sessionsQuery } from '$lib/api/queries/sessions.js';
import type { Session } from '$lib/domain/sessions/types.js';
import { mosaicLayout } from '$lib/stores/mosaic-layout.svelte.js';

const feed = createQuery({
  ...sessionsQuery({ limit: 10 }),
  refetchInterval: 10_000,
});

const sessions = $derived(($feed.data as Session[] | undefined) ?? []);

function relativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const s = Math.floor(diff / 1000);
  if (s < 60) return `${s}s ago`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
}

function sessionTitle(s: Session): string {
  if (s.prompt) return s.prompt.slice(0, 60);
  return `Session ${s.id.slice(0, 8)}`;
}

function openSession(s: Session): void {
  mosaicLayout.openPane({
    id: s.id,
    kind: s.kind === 'agent_conversation' ? 'agent_conversation' : 'session',
    ref: s.id,
    title: sessionTitle(s).slice(0, 40),
    config: { sessionId: s.id },
  });
  void goto('/build');
}
</script>

<div class="af-root">
  <div class="af-header">
    <h2 class="af-heading">Recent sessions</h2>
    {#if sessions.length > 0}
      <button class="af-view-all" onclick={() => goto('/sessions')} aria-label="View all sessions">
        View all <ArrowRight size={11} aria-hidden="true" />
      </button>
    {/if}
  </div>

  {#if $feed.isLoading}
    {#each Array(3) as _, i (i)}
      <div class="af-skeleton" aria-hidden="true"></div>
    {/each}
  {:else if sessions.length === 0}
    <p class="af-empty">No recent sessions. Start one above.</p>
  {:else}
    <ul class="af-list" aria-label="Recent sessions">
      {#each sessions as session (session.id)}
        <li>
          <button
            class="af-row"
            onclick={() => openSession(session)}
            aria-label="Open session: {sessionTitle(session)}"
          >
            <span
              class="af-dot"
              class:af-dot--running={session.status === 'running'}
              class:af-dot--done={session.status === 'completed'}
              class:af-dot--error={session.status === 'error'}
              aria-hidden="true"
            ></span>

            <span class="af-title">{sessionTitle(session)}</span>
            <span class="af-runtime">{session.runtimeType}</span>
            <span class="af-time">{relativeTime(session.insertedAt)}</span>
          </button>
        </li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .af-root {
    display: flex;
    flex-direction: column;
    gap: 4px;
    width: 100%;
  }

  .af-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 4px;
  }

  .af-heading {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    margin: 0;
  }

  .af-view-all {
    display: inline-flex;
    align-items: center;
    gap: 3px;
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
    background: none;
    border: none;
    cursor: pointer;
    padding: 0;
    transition: color 100ms;
  }

  .af-view-all:hover { color: var(--fg); }

  .af-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .af-row {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 7px 8px;
    background: transparent;
    border: 1px solid transparent;
    border-radius: var(--radius-sm, 6px);
    cursor: pointer;
    text-align: left;
    font-family: var(--font-sans);
    transition: background 80ms, border-color 80ms;
  }

  .af-row:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    border-color: var(--border);
  }

  .af-row:focus-visible {
    outline: 2px solid var(--cnp-accent, #6366f1);
    outline-offset: 2px;
  }

  .af-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    flex-shrink: 0;
    background: var(--fg-subtle);
  }

  .af-dot--running {
    background: #22c55e;
    animation: af-pulse 1.5s ease-in-out infinite;
  }

  .af-dot--done { background: var(--fg-subtle); }
  .af-dot--error { background: #ef4444; }

  @keyframes af-pulse {
    0%, 100% { opacity: 1; }
    50%      { opacity: 0.35; }
  }

  .af-title {
    flex: 1;
    font-size: 12px;
    color: var(--fg);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .af-runtime {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-muted);
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    border-radius: 3px;
    padding: 1px 5px;
    flex-shrink: 0;
    white-space: nowrap;
  }

  .af-time {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    flex-shrink: 0;
    font-variant-numeric: tabular-nums;
    min-width: 36px;
    text-align: right;
  }

  .af-skeleton {
    height: 34px;
    background: color-mix(in oklch, var(--fg) 3%, transparent);
    border-radius: var(--radius-sm, 6px);
    animation: af-shimmer 1.5s ease-in-out infinite;
  }

  @keyframes af-shimmer { 0%, 100% { opacity: 0.3; } 50% { opacity: 0.6; } }

  .af-empty {
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--fg-subtle);
    margin: 0;
    text-align: center;
    padding: 20px 0;
  }

  @media (prefers-reduced-motion: reduce) {
    .af-dot--running { animation: none; }
    .af-skeleton { animation: none; opacity: 0.4; }
  }
</style>
