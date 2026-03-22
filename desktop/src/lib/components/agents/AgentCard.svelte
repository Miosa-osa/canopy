<!-- src/lib/components/agents/AgentCard.svelte -->
<script lang="ts">
  import { goto } from '$app/navigation';
  import StatusDot from '$lib/components/shared/StatusDot.svelte';
  import TimeAgo from '$lib/components/shared/TimeAgo.svelte';
  import { agentsStore } from '$lib/stores/agents.svelte';
  import type { CanopyAgent, AgentStatus, AgentLifecycleAction } from '$api/types';

  interface Props {
    agent: CanopyAgent;
  }

  let { agent }: Props = $props();

  function statusToDot(s: AgentStatus): 'online' | 'idle' | 'busy' | 'error' | 'offline' | 'sleeping' {
    switch (s) {
      case 'running':    return 'busy';
      case 'active':     return 'busy';
      case 'working':    return 'busy';
      case 'idle':       return 'idle';
      case 'sleeping':   return 'sleeping';
      case 'paused':     return 'offline';
      case 'error':      return 'error';
      case 'terminated': return 'offline';
      default:           return 'offline';
    }
  }

  function statusLabel(s: AgentStatus): string {
    switch (s) {
      case 'running':    return 'Running';
      case 'active':     return 'Active';
      case 'working':    return 'Working';
      case 'idle':       return 'Idle';
      case 'sleeping':   return 'Sleeping';
      case 'paused':     return 'Paused';
      case 'error':      return 'Error';
      case 'terminated': return 'Terminated';
      default:           return s;
    }
  }

  function formatCost(cents: number): string {
    if (cents === 0) return '$0.00';
    if (cents < 100) return `$0.${cents.toString().padStart(2, '0')}`;
    return `$${(cents / 100).toFixed(2)}`;
  }

  function formatTokens(usage: CanopyAgent['token_usage_today']): string {
    const total = usage.input + usage.output;
    if (total === 0) return '0';
    if (total >= 1_000_000) return `${(total / 1_000_000).toFixed(1)}M`;
    if (total >= 1000) return `${(total / 1000).toFixed(0)}K`;
    return String(total);
  }

  async function handleAction(e: MouseEvent, action: AgentLifecycleAction) {
    e.stopPropagation();
    await agentsStore.performAction(agent.id, action);
  }

  function navigateToDetail() {
    void goto(`/app/agents/${agent.id}`);
  }
</script>

<div
  class="ac-card"
  onclick={navigateToDetail}
  role="button"
  aria-label="View agent {agent.display_name}"
  tabindex="0"
  onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); navigateToDetail(); } }}
>
  <div class="ac-top">
    <span class="ac-emoji" aria-hidden="true">{agent.avatar_emoji}</span>
    <div class="ac-identity">
      <span class="ac-name">{agent.display_name}</span>
      <span class="ac-role">{agent.role}</span>
    </div>
  </div>

  <div class="ac-status-row">
    <StatusDot
      status={statusToDot(agent.status)}
      pulse={agent.status === 'running'}
    />
    <span class="ac-status-text">{statusLabel(agent.status)}</span>
    {#if agent.last_active_at}
      <TimeAgo date={agent.last_active_at} short />
    {/if}
  </div>

  <div class="ac-stats">
    <div class="ac-stat" title="Tokens used today">
      <span class="ac-stat-label">Tokens</span>
      <span class="ac-stat-value">{formatTokens(agent.token_usage_today)}</span>
    </div>
    <div class="ac-stat ac-stat--right" title="Cost today">
      <span class="ac-stat-label">Cost</span>
      <span class="ac-stat-value">{formatCost(agent.cost_today_cents)}</span>
    </div>
  </div>

  {#if agent.current_task}
    <p class="ac-task" title={agent.current_task}>
      {agent.current_task}
    </p>
  {:else}
    <p class="ac-task ac-task--empty">No active task</p>
  {/if}

  <div class="ac-actions" role="toolbar" aria-label="Agent actions">
    {#if agent.status === 'sleeping' || agent.status === 'paused' || agent.status === 'terminated'}
      <button
        class="ac-btn ac-btn--primary"
        onclick={(e) => handleAction(e, 'wake')}
        aria-label="Wake {agent.display_name}"
      >
        Wake
      </button>
    {:else if agent.status === 'running'}
      <button
        class="ac-btn"
        onclick={(e) => handleAction(e, 'sleep')}
        aria-label="Sleep {agent.display_name}"
      >
        Sleep
      </button>
      <button
        class="ac-btn"
        onclick={(e) => handleAction(e, 'pause')}
        aria-label="Pause {agent.display_name}"
      >
        Pause
      </button>
    {:else if agent.status === 'idle'}
      <button
        class="ac-btn ac-btn--primary"
        onclick={(e) => handleAction(e, 'focus')}
        aria-label="Focus {agent.display_name}"
      >
        Focus
      </button>
      <button
        class="ac-btn"
        onclick={(e) => handleAction(e, 'sleep')}
        aria-label="Sleep {agent.display_name}"
      >
        Sleep
      </button>
    {:else if agent.status === 'error'}
      <button
        class="ac-btn ac-btn--primary"
        onclick={(e) => handleAction(e, 'wake')}
        aria-label="Restart {agent.display_name}"
      >
        Restart
      </button>
    {/if}
  </div>
</div>

<style>
  .ac-card {
    width: 200px;
    min-height: 220px;
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-lg);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    padding: 14px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    cursor: pointer;
    transition:
      border-color 150ms ease,
      transform 150ms ease,
      box-shadow 150ms ease;
    outline: none;
  }

  .ac-card:hover {
    border-color: var(--border-hover);
    transform: translateY(-2px);
    box-shadow: 0 6px 24px rgba(0, 0, 0, 0.25);
  }

  .ac-card:focus-visible {
    border-color: var(--accent-primary);
    box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.3);
  }

  /* Top section */
  .ac-top {
    display: flex;
    align-items: flex-start;
    gap: 10px;
  }

  .ac-emoji {
    font-size: 32px;
    line-height: 1;
    flex-shrink: 0;
  }

  .ac-identity {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }

  .ac-name {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ac-role {
    font-size: 12px;
    color: var(--text-tertiary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  /* Status row */
  .ac-status-row {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .ac-status-text {
    font-size: 12px;
    color: var(--text-secondary);
    flex: 1;
  }

  /* Stats */
  .ac-stats {
    display: flex;
    gap: 8px;
    padding: 8px 0;
    border-top: 1px solid var(--border-default);
    border-bottom: 1px solid var(--border-default);
  }

  .ac-stat {
    display: flex;
    flex-direction: column;
    gap: 2px;
    flex: 1;
  }

  .ac-stat--right {
    align-items: flex-end;
  }

  .ac-stat-label {
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 0.4px;
    color: var(--text-tertiary);
    font-weight: 500;
  }

  .ac-stat-value {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-primary);
    font-variant-numeric: tabular-nums;
  }

  /* Current task */
  .ac-task {
    font-size: 12px;
    color: var(--text-secondary);
    font-style: italic;
    line-height: 1.4;
    overflow: hidden;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    margin: 0;
  }

  .ac-task--empty {
    color: var(--text-muted);
  }

  /* Actions */
  .ac-actions {
    display: flex;
    gap: 6px;
    margin-top: auto;
  }

  .ac-btn {
    flex: 1;
    height: 26px;
    border-radius: var(--radius-xs);
    border: 1px solid var(--border-default);
    background: transparent;
    color: var(--text-secondary);
    font-size: 11px;
    font-weight: 500;
    font-family: var(--font-sans);
    cursor: pointer;
    transition: all 120ms ease;
    padding: 0 8px;
  }

  .ac-btn:hover {
    background: var(--bg-elevated);
    border-color: var(--border-hover);
    color: var(--text-primary);
  }

  .ac-btn--primary {
    background: rgba(59, 130, 246, 0.15);
    border-color: rgba(59, 130, 246, 0.35);
    color: #93c5fd;
  }

  .ac-btn--primary:hover {
    background: rgba(59, 130, 246, 0.25);
    border-color: rgba(59, 130, 246, 0.5);
    color: #bfdbfe;
  }
</style>
