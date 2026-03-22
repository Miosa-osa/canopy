<!-- src/lib/components/office/OfficeDetailPanel.svelte -->
<!-- Slide-out panel shown when an agent is selected in the office -->
<script lang="ts">
  import { fly } from 'svelte/transition';
  import type { CanopyAgent, AgentStatus, AgentLifecycleAction } from '$api/types';
  import { agentsStore } from '$lib/stores/agents.svelte';

  interface Props {
    agent: CanopyAgent | null;
    onclose: () => void;
  }

  let { agent, onclose }: Props = $props();

  const STATUS_COLORS: Record<AgentStatus, string> = {
    running:    'rgba(34, 197, 94, 0.7)',
    active:     'rgba(34, 197, 94, 0.7)',
    working:    'rgba(34, 197, 94, 0.7)',
    idle:       '#6366f1',
    sleeping:   '#64748b',
    paused:     '#f59e0b',
    error:      '#ef4444',
    terminated: '#ef4444',
  };

  const STATUS_LABELS: Record<AgentStatus, string> = {
    running:    'Running',
    active:     'Active',
    working:    'Working',
    idle:       'Idle',
    sleeping:   'Sleeping',
    paused:     'Paused',
    error:      'Error',
    terminated: 'Terminated',
  };

  function djb2(str: string): number {
    let hash = 5381;
    for (let i = 0; i < str.length; i++) {
      hash = ((hash << 5) - hash + str.charCodeAt(i)) >>> 0;
    }
    return hash;
  }

  const AVATAR_COLORS = [
    '#6366f1', '#8b5cf6', '#ec4899', '#f43f5e',
    '#f97316', '#eab308', '#22c55e', '#14b8a6',
    '#06b6d4', '#3b82f6', '#a855f7', '#d946ef',
  ];

  const avatarColor = $derived(
    agent ? AVATAR_COLORS[djb2(agent.id) % AVATAR_COLORS.length] : '#6366f1'
  );
  const statusColor = $derived(
    agent ? (STATUS_COLORS[agent.status] ?? '#64748b') : '#64748b'
  );

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

  // Available lifecycle actions based on status
  const availableActions = $derived.by((): AgentLifecycleAction[] => {
    if (!agent) return [];
    switch (agent.status) {
      case 'running': return ['sleep', 'pause'];
      case 'idle':    return ['focus', 'sleep'];
      case 'sleeping':
      case 'paused':
      case 'terminated': return ['wake'];
      case 'error':   return ['wake'];
      default:        return [];
    }
  });

  const actionLabels: Record<AgentLifecycleAction, string> = {
    wake:      'Wake',
    sleep:     'Sleep',
    focus:     'Focus',
    pause:     'Pause',
    resume:    'Resume',
    terminate: 'Terminate',
  };

  let performing = $state<AgentLifecycleAction | null>(null);

  async function performAction(action: AgentLifecycleAction) {
    if (!agent || performing) return;
    performing = action;
    await agentsStore.performAction(agent.id, action);
    performing = null;
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') onclose();
  }
</script>

<!-- Backdrop -->
{#if agent}
  <div
    class="odp-backdrop"
    role="presentation"
    onclick={onclose}
    onkeydown={handleKeydown}
    aria-hidden="true"
  ></div>

  <!-- Panel -->
  <aside
    class="odp-panel"
    aria-label="Agent details: {agent.display_name}"
    transition:fly={{ x: 320, duration: 260, opacity: 1 }}
  >
    <!-- Header -->
    <div class="odp-header">
      <div class="odp-avatar" style="background: {avatarColor};">
        {#if agent.avatar_emoji}
          <span class="odp-emoji">{agent.avatar_emoji}</span>
        {:else}
          <span class="odp-initial">
            {(agent.display_name?.[0] ?? agent.name?.[0] ?? '?').toUpperCase()}
          </span>
        {/if}
        <!-- Status ring -->
        <span class="odp-status-ring" style="border-color: {statusColor};"
          class:odp-status-ring--pulse={agent.status === 'running'}></span>
      </div>

      <div class="odp-identity">
        <h2 class="odp-name">{agent.display_name}</h2>
        <span class="odp-role">{agent.role}</span>
      </div>

      <button
        class="odp-close"
        onclick={onclose}
        aria-label="Close agent panel"
        title="Close"
      >
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true">
          <path d="M3 3L13 13M13 3L3 13" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
        </svg>
      </button>
    </div>

    <!-- Status badge -->
    <div class="odp-section">
      <span
        class="odp-status-badge"
        style="--sc: {statusColor};"
      >
        <span class="odp-status-dot" style="background: {statusColor};"></span>
        {STATUS_LABELS[agent.status]}
      </span>
    </div>

    <!-- Current task -->
    {#if agent.current_task}
      <div class="odp-section">
        <div class="odp-section-label">Current Task</div>
        <p class="odp-task">{agent.current_task}</p>
      </div>
    {:else}
      <div class="odp-section">
        <div class="odp-section-label">Current Task</div>
        <p class="odp-task odp-task--empty">No active task</p>
      </div>
    {/if}

    <!-- Quick stats -->
    <div class="odp-section">
      <div class="odp-section-label">Today</div>
      <div class="odp-stats">
        <div class="odp-stat">
          <span class="odp-stat-label">Tokens</span>
          <span class="odp-stat-value">{formatTokens(agent.token_usage_today)}</span>
        </div>
        <div class="odp-stat-divider"></div>
        <div class="odp-stat">
          <span class="odp-stat-label">Cost</span>
          <span class="odp-stat-value">{formatCost(agent.cost_today_cents)}</span>
        </div>
        <div class="odp-stat-divider"></div>
        <div class="odp-stat">
          <span class="odp-stat-label">Model</span>
          <span class="odp-stat-value odp-stat-value--model">{agent.model.split('/').pop() ?? agent.model}</span>
        </div>
      </div>
    </div>

    <!-- Quick actions -->
    {#if availableActions.length > 0}
      <div class="odp-section">
        <div class="odp-section-label">Actions</div>
        <div class="odp-actions">
          {#each availableActions as action}
            <button
              class="odp-action-btn"
              class:odp-action-btn--primary={action === 'wake' || action === 'focus'}
              class:odp-action-btn--danger={action === 'terminate'}
              disabled={!!performing}
              onclick={() => performAction(action)}
              aria-label="{actionLabels[action]} agent"
            >
              {#if performing === action}
                <span class="odp-btn-spinner" aria-hidden="true"></span>
              {/if}
              {actionLabels[action]}
            </button>
          {/each}

          <!-- Terminate always available unless already terminated -->
          {#if agent.status !== 'terminated'}
            <button
              class="odp-action-btn odp-action-btn--danger"
              disabled={!!performing}
              onclick={() => performAction('terminate')}
              aria-label="Terminate agent"
            >
              Terminate
            </button>
          {/if}
        </div>
      </div>
    {/if}

    <!-- Recent activity placeholder -->
    <div class="odp-section odp-section--flex1">
      <div class="odp-section-label">Recent Activity</div>
      <div class="odp-activity-placeholder" role="status">
        <span class="odp-activity-icon" aria-hidden="true">◈</span>
        <span class="odp-activity-text">Activity stream coming soon</span>
      </div>
    </div>

    <!-- Footer info -->
    <div class="odp-footer">
      <span class="odp-footer-item">Adapter: {agent.adapter}</span>
      <span class="odp-footer-dot" aria-hidden="true">·</span>
      <span class="odp-footer-item">{agent.skills.length} skill{agent.skills.length !== 1 ? 's' : ''}</span>
    </div>
  </aside>
{/if}

<style>
  .odp-backdrop {
    position: fixed;
    inset: 0;
    background: transparent;
    z-index: 49;
  }

  .odp-panel {
    position: fixed;
    top: 0;
    right: 0;
    bottom: 0;
    width: 320px;
    background: #13121f;
    border-left: 1px solid #2a2848;
    z-index: 50;
    display: flex;
    flex-direction: column;
    overflow-y: auto;
    overflow-x: hidden;
    box-shadow: -8px 0 32px rgba(0, 0, 0, 0.4);
  }

  .odp-panel::-webkit-scrollbar { width: 4px; }
  .odp-panel::-webkit-scrollbar-track { background: transparent; }
  .odp-panel::-webkit-scrollbar-thumb { background: #2a2848; border-radius: 2px; }

  /* Header */
  .odp-header {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 20px 16px 16px;
    border-bottom: 1px solid #1e1e38;
    flex-shrink: 0;
  }

  .odp-avatar {
    width: 44px;
    height: 44px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    position: relative;
  }

  .odp-emoji {
    font-size: 22px;
    line-height: 1;
  }

  .odp-initial {
    font-size: 18px;
    font-weight: 700;
    color: white;
    font-family: system-ui, sans-serif;
  }

  .odp-status-ring {
    position: absolute;
    inset: -3px;
    border-radius: 14px;
    border: 2px solid;
    opacity: 0.7;
  }

  .odp-status-ring--pulse {
    animation: odp-ring-pulse 2s ease-out infinite;
  }

  @keyframes odp-ring-pulse {
    0%, 100% { opacity: 0.7; transform: scale(1); }
    50%       { opacity: 0.3; transform: scale(1.05); }
  }

  .odp-identity {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 3px;
  }

  .odp-name {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .odp-role {
    font-size: 12px;
    color: var(--text-tertiary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .odp-close {
    width: 28px;
    height: 28px;
    border-radius: 6px;
    border: 1px solid #2a2848;
    background: transparent;
    color: var(--text-tertiary);
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 120ms ease;
    flex-shrink: 0;
  }

  .odp-close:hover {
    background: #1e1e38;
    border-color: #3a3860;
    color: var(--text-secondary);
  }

  /* Sections */
  .odp-section {
    padding: 14px 16px;
    border-bottom: 1px solid #1a1a32;
  }

  .odp-section--flex1 {
    flex: 1;
  }

  .odp-section-label {
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.8px;
    text-transform: uppercase;
    color: #4a4870;
    margin-bottom: 8px;
  }

  /* Status badge */
  .odp-status-badge {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 4px 10px;
    border-radius: 100px;
    font-size: 12px;
    font-weight: 500;
    background: color-mix(in srgb, var(--sc) 12%, transparent);
    border: 1px solid color-mix(in srgb, var(--sc) 25%, transparent);
    color: var(--sc);
  }

  .odp-status-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  /* Task */
  .odp-task {
    font-size: 13px;
    color: var(--text-secondary);
    line-height: 1.5;
    margin: 0;
    font-style: italic;
  }

  .odp-task--empty {
    color: #4a4870;
  }

  /* Stats */
  .odp-stats {
    display: flex;
    align-items: stretch;
    gap: 0;
    background: #0f0f1e;
    border: 1px solid #1e1e38;
    border-radius: 8px;
    overflow: hidden;
  }

  .odp-stat {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 3px;
    padding: 10px 12px;
  }

  .odp-stat-divider {
    width: 1px;
    background: #1e1e38;
    flex-shrink: 0;
  }

  .odp-stat-label {
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 0.4px;
    color: #4a4870;
    font-weight: 500;
  }

  .odp-stat-value {
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
    font-variant-numeric: tabular-nums;
  }

  .odp-stat-value--model {
    font-size: 11px;
  }

  /* Actions */
  .odp-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }

  .odp-action-btn {
    flex: 1;
    min-width: 70px;
    height: 30px;
    border-radius: 6px;
    border: 1px solid #2a2848;
    background: transparent;
    color: var(--text-secondary);
    font-size: 12px;
    font-weight: 500;
    font-family: var(--font-sans, system-ui);
    cursor: pointer;
    transition: all 120ms ease;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 5px;
  }

  .odp-action-btn:hover:not(:disabled) {
    background: #1e1e38;
    border-color: #3a3860;
    color: var(--text-primary);
  }

  .odp-action-btn--primary {
    background: rgba(59, 130, 246, 0.12);
    border-color: rgba(59, 130, 246, 0.3);
    color: #93c5fd;
  }

  .odp-action-btn--primary:hover:not(:disabled) {
    background: rgba(59, 130, 246, 0.2);
    border-color: rgba(59, 130, 246, 0.5);
    color: #bfdbfe;
  }

  .odp-action-btn--danger {
    background: rgba(239, 68, 68, 0.08);
    border-color: rgba(239, 68, 68, 0.2);
    color: #fca5a5;
  }

  .odp-action-btn--danger:hover:not(:disabled) {
    background: rgba(239, 68, 68, 0.15);
    border-color: rgba(239, 68, 68, 0.4);
    color: #fecaca;
  }

  .odp-action-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .odp-btn-spinner {
    width: 10px;
    height: 10px;
    border: 1.5px solid currentColor;
    border-top-color: transparent;
    border-radius: 50%;
    animation: odp-spin 0.7s linear infinite;
    flex-shrink: 0;
  }

  @keyframes odp-spin {
    to { transform: rotate(360deg); }
  }

  /* Activity placeholder */
  .odp-activity-placeholder {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 16px 0 8px;
    color: #3a3860;
    font-size: 12px;
  }

  .odp-activity-icon {
    font-size: 16px;
    opacity: 0.4;
  }

  /* Footer */
  .odp-footer {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 12px 16px;
    flex-shrink: 0;
    border-top: 1px solid #1a1a32;
  }

  .odp-footer-item {
    font-size: 11px;
    color: #4a4870;
  }

  .odp-footer-dot {
    color: #2a2848;
    font-size: 12px;
  }

  @media (prefers-reduced-motion: reduce) {
    .odp-status-ring--pulse { animation: none; }
    .odp-btn-spinner { animation: none; }
  }
</style>
