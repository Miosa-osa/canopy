<script lang="ts">
  /**
   * AgentSessionsList — recent sessions this agent ran.
   * Uses agentSessionsQuery which filters by agent_slug.
   * CSS prefix: asl- (AgentSessionsList)
   */
  import { goto } from '$app/navigation';
  import type { Session } from '$lib/domain/sessions/types.js';

  interface Props {
    sessions: Session[];
    isLoading: boolean;
    agentSlug: string;
  }

  let { sessions, isLoading, agentSlug }: Props = $props();

  function statusColor(status: string): string {
    switch (status) {
      case 'running': return 'green';
      case 'completed': return 'grey';
      case 'failed': return 'red';
      case 'cancelled': return 'amber';
      default: return 'grey';
    }
  }

  function formatDate(iso: string): string {
    return new Date(iso).toLocaleString(undefined, {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  }
</script>

<div class="asl-root">
  <div class="asl-header">
    <h3 class="asl-title">Recent sessions</h3>
    <button
      class="btn-pill btn-pill-secondary btn-pill-sm"
      onclick={() => goto(`/sessions?agent=${agentSlug}`)}
      aria-label="View all sessions for this agent"
    >
      View all
    </button>
  </div>

  {#if isLoading}
    <p class="asl-hint">Loading sessions…</p>
  {:else if sessions.length === 0}
    <p class="asl-hint">No sessions yet. Run this agent to start a session.</p>
  {:else}
    <div class="asl-list" role="list">
      {#each sessions as s (s.id)}
        <div class="asl-row" role="listitem">
          <button
            class="asl-row-btn"
            onclick={() => goto(`/sessions/${s.id}`)}
            aria-label="Open session {s.id}"
          >
            <span
              class="asl-status-dot"
              style="background: {statusColor(s.status) === 'green'
                ? 'oklch(0.7 0.17 145)'
                : statusColor(s.status) === 'red'
                  ? 'oklch(0.55 0.22 25)'
                  : statusColor(s.status) === 'amber'
                    ? 'oklch(0.75 0.12 85)'
                    : 'var(--fg-subtle)'};"
              aria-label="Status: {s.status}"
            ></span>
            <div class="asl-info">
              <span class="asl-id">{s.id.slice(0, 8)}</span>
              <span class="asl-status">{s.status}</span>
            </div>
            <span class="asl-date">{formatDate(s.insertedAt)}</span>
          </button>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .asl-root {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-6);
  }

  .asl-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .asl-title {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
  }

  .asl-hint {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  .asl-list {
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .asl-row {
    border-radius: var(--radius-sm);
  }

  .asl-row-btn {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-2) var(--space-2);
    border-radius: var(--radius-sm);
    border: none;
    background: transparent;
    width: 100%;
    cursor: pointer;
    text-align: left;
    transition: background 0.1s;
  }

  .asl-row-btn:hover {
    background: color-mix(in oklch, var(--fg) 5%, transparent);
  }

  .asl-status-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .asl-info {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex: 1;
    min-width: 0;
  }

  .asl-id {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg);
  }

  .asl-status {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    text-transform: capitalize;
  }

  .asl-date {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    flex-shrink: 0;
  }
</style>
