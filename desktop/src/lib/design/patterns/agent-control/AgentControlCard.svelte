<script lang="ts">
/**
 * AgentControlCard — single agent card for the Agent Control Center lanes.
 * Shows state pills, quick actions on hover, multi-select checkbox.
 * CSS prefix: acc-
 * LOC target: ≤ 180.
 */

import { Bot, MoreHorizontal, Pause, Play, Terminal } from 'lucide-svelte';
import { goto } from '$app/navigation';
import StatusDot from '$lib/design/patterns/StatusDot.svelte';
import type { Agent } from '$lib/domain/agents/types.js';
import type { Session } from '$lib/domain/sessions/types.js';
import type { AgentLane } from './types.js';

interface Props {
  agent: Agent;
  lane: AgentLane;
  primarySession: Session | null;
  isScheduled: boolean;
  selected: boolean;
  onSelect: (slug: string, checked: boolean) => void;
  onPause: (sessionId: string) => void;
  onResume: (sessionId: string) => void;
}

let { agent, lane, primarySession, isScheduled, selected, onSelect, onPause, onResume }: Props =
  $props();

const dotColor = $derived<'green' | 'amber' | 'red' | 'grey'>(
  lane === 'running'
    ? 'green'
    : lane === 'paused' || lane === 'scheduled'
      ? 'amber'
      : lane === 'offline'
        ? 'red'
        : 'grey'
);

function handleTerminal(e: MouseEvent): void {
  e.stopPropagation();
  if (primarySession) {
    void goto(`/sessions/${primarySession.id}`);
  } else if (agent.defaultRuntime) {
    void goto(`/runtimes/${agent.defaultRuntime}`);
  } else {
    void goto('/runtimes');
  }
}

function handleTogglePause(e: MouseEvent): void {
  e.stopPropagation();
  if (!primarySession) return;
  if (primarySession.status === 'running') {
    onPause(primarySession.id);
  } else if (primarySession.status === 'paused') {
    onResume(primarySession.id);
  }
}

function handleCheckbox(e: MouseEvent): void {
  e.stopPropagation();
  onSelect(agent.slug, !selected);
}

function relativeTime(iso: string | null): string {
  if (!iso) return '—';
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60_000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.floor(hrs / 24)}d ago`;
}

const lastActive = $derived(relativeTime(primarySession?.updatedAt ?? agent.updatedAt));

const canTogglePause = $derived(
  primarySession !== null &&
    (primarySession.status === 'running' || primarySession.status === 'paused')
);
</script>

<div
  class="acc-card"
  class:acc-card--selected={selected}
  role="article"
  aria-label="Agent {agent.name}"
>
  <!-- Multi-select checkbox (top-left hover) -->
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div
    class="acc-checkbox"
    role="checkbox"
    aria-checked={selected}
    aria-label="Select {agent.name}"
    tabindex="-1"
    onclick={handleCheckbox}
  >
    <input
      type="checkbox"
      checked={selected}
      aria-label="Select {agent.name}"
      tabindex="-1"
      readonly
    />
  </div>

  <!-- Card body -->
  <div class="acc-body">
    <!-- Avatar + name row -->
    <div class="acc-identity">
      <div class="acc-avatar" aria-hidden="true">
        <Bot size={14} />
      </div>
      <div class="acc-names">
        <span class="acc-name">{agent.name}</span>
        <span class="acc-slug">{agent.slug}</span>
      </div>
      <div class="acc-dots">
        <StatusDot color={dotColor} pulse={lane === 'running'} />
        {#if isScheduled && lane !== 'scheduled'}
          <span class="acc-pill acc-pill--scheduled" aria-label="Scheduled">S</span>
        {/if}
        {#if lane === 'running'}
          <span class="acc-pill acc-pill--running" aria-label="Running">R</span>
        {:else if lane === 'paused'}
          <span class="acc-pill acc-pill--paused" aria-label="Paused">P</span>
        {:else if lane === 'scheduled'}
          <span class="acc-pill acc-pill--scheduled" aria-label="Scheduled">S</span>
        {:else if lane === 'offline'}
          <span class="acc-pill acc-pill--offline" aria-label="Offline">X</span>
        {/if}
      </div>
    </div>

    <!-- Runtime + last active -->
    <div class="acc-meta">
      {#if agent.defaultRuntime}
        <span class="acc-runtime">{agent.defaultRuntime}</span>
      {/if}
      <span class="acc-time">{lastActive}</span>
    </div>
  </div>

  <!-- Hover actions -->
  <div class="acc-actions" role="group" aria-label="Agent actions">
    <button
      class="acc-action-btn"
      onclick={handleTerminal}
      aria-label="Open terminal"
      title="Open terminal"
    >
      <Terminal size={12} aria-hidden="true" />
    </button>

    {#if canTogglePause}
      <button
        class="acc-action-btn"
        onclick={handleTogglePause}
        aria-label={primarySession?.status === 'running' ? 'Pause agent' : 'Resume agent'}
        title={primarySession?.status === 'running' ? 'Pause' : 'Resume'}
      >
        {#if primarySession?.status === 'running'}
          <Pause size={12} aria-hidden="true" />
        {:else}
          <Play size={12} aria-hidden="true" />
        {/if}
      </button>
    {/if}

    <button
      class="acc-action-btn"
      aria-label="More options"
      title="More options"
      onclick={(e) => e.stopPropagation()}
    >
      <MoreHorizontal size={12} aria-hidden="true" />
    </button>
  </div>
</div>

<style>
  .acc-card {
    position: relative;
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-3);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    background: var(--bg-elevated);
    cursor: grab;
    transition: background var(--dur-instant) var(--ease-out),
      border-color var(--dur-instant) var(--ease-out);
    user-select: none;
  }

  .acc-card:hover {
    background: color-mix(in oklch, var(--fg) 4%, var(--bg-elevated));
    border-color: color-mix(in oklch, var(--fg) 20%, transparent);
  }

  .acc-card--selected {
    border-color: var(--cnp-accent, var(--fg-muted));
    background: color-mix(in oklch, var(--cnp-accent, var(--fg)) 5%, var(--bg-elevated));
  }

  .acc-checkbox {
    position: absolute;
    top: var(--space-2);
    left: var(--space-2);
    opacity: 0;
    transition: opacity var(--dur-instant) var(--ease-out);
    z-index: 2;
  }

  .acc-card:hover .acc-checkbox,
  .acc-card--selected .acc-checkbox {
    opacity: 1;
  }

  .acc-checkbox input {
    width: 14px;
    height: 14px;
    cursor: pointer;
    accent-color: var(--cnp-accent, var(--fg));
  }

  .acc-body { display: flex; flex-direction: column; gap: var(--space-1); }

  .acc-identity {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding-left: var(--space-5);
  }

  .acc-card:hover .acc-identity { padding-left: var(--space-5); }

  .acc-avatar {
    width: 28px;
    height: 28px;
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 14px;
    flex-shrink: 0;
    font-family: var(--font-sans);
  }

  .acc-names { display: flex; flex-direction: column; gap: 1px; flex: 1; min-width: 0; }

  .acc-name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    line-height: 1.25;
  }

  .acc-slug {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .acc-dots { display: flex; align-items: center; gap: var(--space-1); flex-shrink: 0; }

  .acc-pill {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 16px;
    height: 16px;
    border-radius: 999px;
    font-family: var(--font-sans);
    font-size: 9px;
    font-weight: 700;
    letter-spacing: 0.02em;
  }

  .acc-pill--running {
    background: color-mix(in oklch, var(--success, oklch(0.72 0.17 155)) 18%, transparent);
    color: var(--success, oklch(0.72 0.17 155));
  }

  .acc-pill--paused,
  .acc-pill--scheduled {
    background: color-mix(in oklch, var(--priority, oklch(0.75 0.15 80)) 18%, transparent);
    color: var(--priority, oklch(0.75 0.15 80));
  }

  .acc-pill--offline {
    background: color-mix(in oklch, var(--destructive, oklch(0.65 0.22 25)) 18%, transparent);
    color: var(--destructive, oklch(0.65 0.22 25));
  }

  .acc-meta {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding-left: var(--space-5);
  }

  .acc-runtime {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-muted);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    padding: 1px 5px;
    border-radius: var(--radius-sm);
  }

  .acc-time {
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
    margin-left: auto;
  }

  .acc-actions {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    opacity: 0;
    transition: opacity var(--dur-instant) var(--ease-out);
    padding-left: var(--space-5);
  }

  .acc-card:hover .acc-actions { opacity: 1; }

  .acc-action-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-muted);
    cursor: pointer;
    transition: background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .acc-action-btn:hover {
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    color: var(--fg);
  }

  .acc-action-btn:focus-visible {
    outline: 2px solid var(--cnp-accent, currentColor);
    outline-offset: 2px;
  }
</style>
