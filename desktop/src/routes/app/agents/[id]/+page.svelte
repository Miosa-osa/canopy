<!-- src/routes/app/agents/[id]/+page.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import StatusDot from '$lib/components/shared/StatusDot.svelte';
  import Badge from '$lib/components/shared/Badge.svelte';
  import MetricCard from '$lib/components/shared/MetricCard.svelte';
  import TimeAgo from '$lib/components/shared/TimeAgo.svelte';
  import LoadingSpinner from '$lib/components/shared/LoadingSpinner.svelte';
  import { agentsStore } from '$lib/stores/agents.svelte';
  import type { CanopyAgent, AgentStatus, AgentLifecycleAction } from '$api/types';

  const agentId = $derived($page.params.id ?? '');

  let agent = $state<CanopyAgent | null>(null);
  let isLoading = $state(true);
  let activeTab = $state<'overview' | 'config' | 'schedules' | 'skills' | 'runs' | 'budget' | 'inbox'>('overview');

  const TABS = [
    { id: 'overview'  as const, label: 'Overview'  },
    { id: 'config'    as const, label: 'Config'    },
    { id: 'schedules' as const, label: 'Schedules' },
    { id: 'skills'    as const, label: 'Skills'    },
    { id: 'runs'      as const, label: 'Runs'      },
    { id: 'budget'    as const, label: 'Budget'    },
    { id: 'inbox'     as const, label: 'Inbox'     },
  ];

  onMount(async () => {
    // Try store first, then fetch
    agent = agentsStore.getById(agentId) ?? await agentsStore.fetchAgent(agentId);
    isLoading = false;
  });

  $effect(() => {
    // Keep agent in sync when store updates
    const fresh = agentsStore.getById(agentId);
    if (fresh) agent = fresh;
  });

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
    const labels: Record<AgentStatus, string> = {
      running: 'Running', idle: 'Idle', sleeping: 'Sleeping',
      paused: 'Paused', error: 'Error', terminated: 'Terminated',
      active: 'Active', working: 'Working',
    };
    return labels[s];
  }

  function formatCost(cents: number): string {
    if (cents === 0) return '$0.00';
    return `$${(cents / 100).toFixed(2)}`;
  }

  function formatTokens(n: number): string {
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
    if (n >= 1000) return `${(n / 1000).toFixed(1)}K`;
    return String(n);
  }

  async function handleAction(action: AgentLifecycleAction) {
    if (!agent) return;
    await agentsStore.performAction(agent.id, action);
  }

  function adapterBadgeVariant(a: string): 'default' | 'info' | 'success' | 'accent' {
    switch (a) {
      case 'osa':         return 'accent';
      case 'claude_code': return 'info';
      case 'cursor':      return 'success';
      default:            return 'default';
    }
  }
</script>

<svelte:head>
  <title>{agent ? `${agent.display_name} — Canopy` : 'Agent — Canopy'}</title>
</svelte:head>

<div class="ad-shell">
  {#if isLoading}
    <div class="ad-loading" aria-label="Loading agent" aria-live="polite">
      <LoadingSpinner size="md" />
      <span>Loading agent…</span>
    </div>

  {:else if !agent}
    <div class="ad-not-found" role="main">
      <span class="ad-not-found-icon" aria-hidden="true">🔍</span>
      <p class="ad-not-found-text">Agent not found.</p>
      <button
        class="ad-back-btn"
        onclick={() => goto('/app/agents')}
        aria-label="Go back to agents list"
      >
        ← Back to agents
      </button>
    </div>

  {:else}
    <!-- Agent header -->
    <header class="ad-header">
      <button
        class="ad-back"
        onclick={() => goto('/app/agents')}
        aria-label="Back to agents list"
      >
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
          <path d="M19 12H5M12 19l-7-7 7-7" />
        </svg>
      </button>

      <span class="ad-emoji" aria-hidden="true">{agent.avatar_emoji}</span>

      <div class="ad-identity">
        <h1 class="ad-name">{agent.display_name}</h1>
        <span class="ad-role">{agent.role}</span>
      </div>

      <div class="ad-status-badge" aria-label="Status: {statusLabel(agent.status)}">
        <StatusDot
          status={statusToDot(agent.status)}
          pulse={agent.status === 'running'}
          size="sm"
        />
        <span class="ad-status-text">{statusLabel(agent.status)}</span>
      </div>

      <div class="ad-header-spacer" aria-hidden="true"></div>

      <!-- Action buttons -->
      <div class="ad-actions" role="toolbar" aria-label="Agent lifecycle actions">
        {#if agent.status === 'sleeping' || agent.status === 'terminated'}
          <button class="ad-btn ad-btn--primary" onclick={() => handleAction('wake')} aria-label="Wake agent">
            Wake
          </button>
        {/if}
        {#if agent.status === 'running' || agent.status === 'idle'}
          <button class="ad-btn ad-btn--accent" onclick={() => handleAction('focus')} aria-label="Focus agent on current task">
            Focus
          </button>
        {/if}
        {#if agent.status === 'running' || agent.status === 'idle'}
          <button class="ad-btn" onclick={() => handleAction('sleep')} aria-label="Put agent to sleep">
            Sleep
          </button>
        {/if}
        {#if agent.status === 'running'}
          <button class="ad-btn" onclick={() => handleAction('pause')} aria-label="Pause agent">
            Pause
          </button>
        {/if}
        {#if agent.status === 'paused'}
          <button class="ad-btn ad-btn--primary" onclick={() => handleAction('resume')} aria-label="Resume paused agent">
            Resume
          </button>
        {/if}
        {#if agent.status !== 'terminated'}
          <button
            class="ad-btn ad-btn--danger"
            onclick={() => handleAction('terminate')}
            aria-label="Terminate agent"
          >
            Terminate
          </button>
        {/if}
      </div>
    </header>

    <!-- Tab bar -->
    <nav class="ad-tabs" aria-label="Agent detail tabs">
      {#each TABS as tab}
        <button
          class="ad-tab"
          class:ad-tab--active={activeTab === tab.id}
          onclick={() => activeTab = tab.id}
          aria-selected={activeTab === tab.id}
          role="tab"
          aria-controls="ad-panel-{tab.id}"
        >
          {tab.label}
        </button>
      {/each}
    </nav>

    <!-- Tab content -->
    <div class="ad-content">

      <!-- OVERVIEW -->
      {#if activeTab === 'overview'}
        <div
          id="ad-panel-overview"
          role="tabpanel"
          aria-label="Overview tab"
          class="ad-panel"
        >
          <!-- Stats row -->
          <div class="ad-metrics">
            <MetricCard
              label="Tokens Today"
              value={formatTokens(agent.token_usage_today.input + agent.token_usage_today.output)}
              subtitle="input + output"
            />
            <MetricCard
              label="Cost Today"
              value={formatCost(agent.cost_today_cents)}
            />
            <MetricCard
              label="Adapter"
              value={agent.adapter}
            />
            <MetricCard
              label="Model"
              value={agent.model}
            />
          </div>

          <!-- Current task -->
          <section class="ad-card" aria-label="Current task">
            <h2 class="ad-card-title">Current Task</h2>
            {#if agent.current_task}
              <p class="ad-current-task">{agent.current_task}</p>
            {:else}
              <p class="ad-muted">No active task</p>
            {/if}
          </section>

          <!-- Token breakdown -->
          <section class="ad-card" aria-label="Token usage breakdown">
            <h2 class="ad-card-title">Token Usage Today</h2>
            <div class="ad-token-grid">
              {#each [
                { label: 'Input',        val: agent.token_usage_today.input },
                { label: 'Output',       val: agent.token_usage_today.output },
                { label: 'Cache Read',   val: agent.token_usage_today.cache_read },
                { label: 'Cache Write',  val: agent.token_usage_today.cache_write },
              ] as row}
                <div class="ad-token-row">
                  <span class="ad-token-label">{row.label}</span>
                  <span class="ad-token-val">{formatTokens(row.val)}</span>
                </div>
              {/each}
            </div>
          </section>

          <!-- Agent info -->
          <section class="ad-card" aria-label="Agent information">
            <h2 class="ad-card-title">Agent Info</h2>
            <dl class="ad-dl">
              <div class="ad-dl-row">
                <dt>Name</dt>
                <dd>{agent.name}</dd>
              </div>
              <div class="ad-dl-row">
                <dt>Created</dt>
                <dd><TimeAgo date={agent.created_at} /></dd>
              </div>
              <div class="ad-dl-row">
                <dt>Last Active</dt>
                <dd>
                  {#if agent.last_active_at}
                    <TimeAgo date={agent.last_active_at} />
                  {:else}
                    <span class="ad-muted">Never</span>
                  {/if}
                </dd>
              </div>
              <div class="ad-dl-row">
                <dt>Schedule</dt>
                <dd>
                  {#if agent.schedule_id}
                    {agent.schedule_id}
                  {:else}
                    <span class="ad-muted">None</span>
                  {/if}
                </dd>
              </div>
              <div class="ad-dl-row">
                <dt>Budget Policy</dt>
                <dd>
                  {#if agent.budget_policy_id}
                    {agent.budget_policy_id}
                  {:else}
                    <span class="ad-muted">None</span>
                  {/if}
                </dd>
              </div>
            </dl>
          </section>
        </div>

      <!-- CONFIG -->
      {:else if activeTab === 'config'}
        <div
          id="ad-panel-config"
          role="tabpanel"
          aria-label="Config tab"
          class="ad-panel"
        >
          <section class="ad-card" aria-label="Model and adapter configuration">
            <h2 class="ad-card-title">Model & Adapter</h2>
            <div class="ad-config-row">
              <span class="ad-config-label">Adapter</span>
              <Badge value={agent.adapter} variant={adapterBadgeVariant(agent.adapter)} />
            </div>
            <div class="ad-config-row">
              <span class="ad-config-label">Model</span>
              <code class="ad-code-inline">{agent.model}</code>
            </div>
          </section>

          <section class="ad-card" aria-label="System prompt">
            <h2 class="ad-card-title">System Prompt</h2>
            {#if agent.system_prompt}
              <pre class="ad-code-block" aria-label="System prompt content">{agent.system_prompt}</pre>
            {:else}
              <p class="ad-muted">No system prompt configured.</p>
            {/if}
          </section>

          <section class="ad-card" aria-label="Extra configuration">
            <h2 class="ad-card-title">Config JSON</h2>
            <pre class="ad-code-block" aria-label="Agent configuration JSON">{JSON.stringify(agent.config, null, 2)}</pre>
          </section>
        </div>

      <!-- SCHEDULES -->
      {:else if activeTab === 'schedules'}
        <div
          id="ad-panel-schedules"
          role="tabpanel"
          aria-label="Schedules tab"
          class="ad-panel"
        >
          {#if agent.schedule_id}
            <section class="ad-card" aria-label="Assigned schedule">
              <h2 class="ad-card-title">Assigned Schedule</h2>
              <div class="ad-config-row">
                <span class="ad-config-label">Schedule ID</span>
                <code class="ad-code-inline">{agent.schedule_id}</code>
              </div>
              <p class="ad-muted" style="margin-top: 12px;">
                Full schedule detail available in the
                <a href="/app/schedules" class="ad-link">Schedules</a> section.
              </p>
            </section>
          {:else}
            <div class="ad-empty-tab" role="status">
              <span class="ad-empty-icon" aria-hidden="true">🗓️</span>
              <p>No schedule assigned to this agent.</p>
            </div>
          {/if}
        </div>

      <!-- SKILLS -->
      {:else if activeTab === 'skills'}
        <div
          id="ad-panel-skills"
          role="tabpanel"
          aria-label="Skills tab"
          class="ad-panel"
        >
          {#if agent.skills.length > 0}
            <section class="ad-card" aria-label="Assigned skills">
              <h2 class="ad-card-title">Assigned Skills ({agent.skills.length})</h2>
              <div class="ad-skills-grid" role="list" aria-label="Agent skills">
                {#each agent.skills as skill}
                  <div class="ad-skill-chip" role="listitem">
                    <span class="ad-skill-dot" aria-hidden="true"></span>
                    <span class="ad-skill-name">{skill}</span>
                  </div>
                {/each}
              </div>
            </section>
          {:else}
            <div class="ad-empty-tab" role="status">
              <span class="ad-empty-icon" aria-hidden="true">⚡</span>
              <p>No skills assigned.</p>
            </div>
          {/if}
        </div>

      <!-- RUNS -->
      {:else if activeTab === 'runs'}
        <div
          id="ad-panel-runs"
          role="tabpanel"
          aria-label="Runs tab"
          class="ad-panel"
        >
          <div class="ad-empty-tab" role="status">
            <span class="ad-empty-icon" aria-hidden="true">🏃</span>
            <p>Run history will appear here once the agent executes heartbeat tasks.</p>
          </div>
        </div>

      <!-- BUDGET -->
      {:else if activeTab === 'budget'}
        <div
          id="ad-panel-budget"
          role="tabpanel"
          aria-label="Budget tab"
          class="ad-panel"
        >
          <section class="ad-card" aria-label="Budget policy">
            <h2 class="ad-card-title">Budget Policy</h2>
            {#if agent.budget_policy_id}
              <div class="ad-config-row">
                <span class="ad-config-label">Policy ID</span>
                <code class="ad-code-inline">{agent.budget_policy_id}</code>
              </div>
              <p class="ad-muted" style="margin-top: 12px;">
                Full budget detail available in the
                <a href="/app/costs" class="ad-link">Costs</a> section.
              </p>
            {:else}
              <p class="ad-muted">No budget policy assigned.</p>
            {/if}
          </section>

          <section class="ad-card" aria-label="Spending today">
            <h2 class="ad-card-title">Spending Today</h2>
            <div class="ad-budget-summary">
              <div class="ad-budget-num">{formatCost(agent.cost_today_cents)}</div>
              <span class="ad-budget-label">total cost today</span>
            </div>
          </section>
        </div>

      <!-- INBOX -->
      {:else if activeTab === 'inbox'}
        <div
          id="ad-panel-inbox"
          role="tabpanel"
          aria-label="Inbox tab"
          class="ad-panel"
        >
          <div class="ad-empty-tab" role="status">
            <span class="ad-empty-icon" aria-hidden="true">📬</span>
            <p>No inbox items for this agent.</p>
          </div>
        </div>
      {/if}

    </div>
  {/if}
</div>

<style>
  .ad-shell {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  /* Loading & not found */
  .ad-loading,
  .ad-not-found {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    height: 100%;
    color: var(--text-tertiary);
    font-size: 13px;
  }

  .ad-not-found-icon {
    font-size: 40px;
    opacity: 0.4;
  }

  .ad-not-found-text {
    margin: 0;
  }

  .ad-back-btn {
    height: 32px;
    padding: 0 14px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-default);
    background: transparent;
    color: var(--text-secondary);
    font-size: 13px;
    font-family: var(--font-sans);
    cursor: pointer;
    transition: all 120ms ease;
  }

  .ad-back-btn:hover {
    background: var(--bg-elevated);
    color: var(--text-primary);
  }

  /* Header */
  .ad-header {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 0 20px;
    height: 56px;
    min-height: 56px;
    border-bottom: 1px solid var(--border-default);
    flex-shrink: 0;
  }

  .ad-back {
    width: 28px;
    height: 28px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: var(--radius-xs);
    border: 1px solid transparent;
    background: transparent;
    color: var(--text-tertiary);
    cursor: pointer;
    flex-shrink: 0;
    transition: all 120ms ease;
  }

  .ad-back:hover {
    background: var(--bg-elevated);
    border-color: var(--border-default);
    color: var(--text-primary);
  }

  .ad-emoji {
    font-size: 28px;
    line-height: 1;
    flex-shrink: 0;
  }

  .ad-identity {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }

  .ad-name {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ad-role {
    font-size: 12px;
    color: var(--text-tertiary);
    white-space: nowrap;
  }

  .ad-status-badge {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 8px;
    border-radius: var(--radius-xs);
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    flex-shrink: 0;
  }

  .ad-status-text {
    font-size: 12px;
    color: var(--text-secondary);
    text-transform: capitalize;
  }

  .ad-header-spacer {
    flex: 1;
  }

  .ad-actions {
    display: flex;
    gap: 6px;
    flex-shrink: 0;
  }

  .ad-btn {
    height: 28px;
    padding: 0 12px;
    border-radius: var(--radius-xs);
    border: 1px solid var(--border-default);
    background: transparent;
    color: var(--text-secondary);
    font-size: 12px;
    font-weight: 500;
    font-family: var(--font-sans);
    cursor: pointer;
    transition: all 120ms ease;
    white-space: nowrap;
  }

  .ad-btn:hover {
    background: var(--bg-elevated);
    border-color: var(--border-hover);
    color: var(--text-primary);
  }

  .ad-btn--primary {
    background: rgba(59, 130, 246, 0.15);
    border-color: rgba(59, 130, 246, 0.35);
    color: #93c5fd;
  }

  .ad-btn--primary:hover {
    background: rgba(59, 130, 246, 0.25);
    border-color: rgba(59, 130, 246, 0.5);
    color: #bfdbfe;
  }

  .ad-btn--accent {
    background: rgba(34, 197, 94, 0.08);
    border-color: rgba(34, 197, 94, 0.22);
    color: rgba(34, 197, 94, 0.65);
  }

  .ad-btn--accent:hover {
    background: rgba(34, 197, 94, 0.12);
    border-color: rgba(34, 197, 94, 0.35);
    color: rgba(34, 197, 94, 0.75);
  }

  .ad-btn--danger {
    color: #fca5a5;
  }

  .ad-btn--danger:hover {
    background: rgba(239, 68, 68, 0.1);
    border-color: rgba(239, 68, 68, 0.3);
    color: #f87171;
  }

  /* Tab bar */
  .ad-tabs {
    display: flex;
    align-items: center;
    gap: 0;
    padding: 0 20px;
    border-bottom: 1px solid var(--border-default);
    flex-shrink: 0;
  }

  .ad-tab {
    height: 40px;
    padding: 0 14px;
    border: none;
    border-bottom: 2px solid transparent;
    background: transparent;
    color: var(--text-tertiary);
    font-size: 13px;
    font-weight: 500;
    font-family: var(--font-sans);
    cursor: pointer;
    transition: color 120ms ease, border-color 120ms ease;
    margin-bottom: -1px;
    white-space: nowrap;
  }

  .ad-tab:hover {
    color: var(--text-secondary);
  }

  .ad-tab--active {
    color: var(--text-primary);
    border-bottom-color: var(--accent-primary);
  }

  /* Content */
  .ad-content {
    flex: 1;
    overflow-y: auto;
    padding: 20px;
  }

  .ad-content::-webkit-scrollbar {
    width: 5px;
  }

  .ad-content::-webkit-scrollbar-thumb {
    background: var(--border-default);
    border-radius: 3px;
  }

  .ad-panel {
    display: flex;
    flex-direction: column;
    gap: 16px;
    max-width: 900px;
  }

  /* Metrics row */
  .ad-metrics {
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
  }

  /* Cards */
  .ad-card {
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-md);
    padding: 16px;
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
  }

  .ad-card-title {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: var(--text-tertiary);
    margin: 0 0 12px 0;
  }

  .ad-current-task {
    font-size: 13px;
    color: var(--text-primary);
    line-height: 1.5;
    margin: 0;
    font-style: italic;
  }

  /* Token grid */
  .ad-token-grid {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .ad-token-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .ad-token-label {
    font-size: 12px;
    color: var(--text-tertiary);
  }

  .ad-token-val {
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
    font-variant-numeric: tabular-nums;
  }

  /* Description list */
  .ad-dl {
    display: flex;
    flex-direction: column;
    gap: 8px;
    margin: 0;
    padding: 0;
  }

  .ad-dl-row {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .ad-dl-row dt {
    font-size: 12px;
    color: var(--text-tertiary);
    min-width: 100px;
    flex-shrink: 0;
  }

  .ad-dl-row dd {
    font-size: 13px;
    color: var(--text-primary);
    margin: 0;
  }

  /* Config rows */
  .ad-config-row {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 8px;
  }

  .ad-config-row:last-child {
    margin-bottom: 0;
  }

  .ad-config-label {
    font-size: 12px;
    color: var(--text-tertiary);
    min-width: 80px;
  }

  /* Code */
  .ad-code-block {
    background: var(--bg-secondary);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    padding: 12px;
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--text-secondary);
    white-space: pre-wrap;
    word-break: break-all;
    line-height: 1.6;
    margin: 0;
    overflow-x: auto;
    max-height: 400px;
  }

  .ad-code-inline {
    font-family: var(--font-mono);
    font-size: 11px;
    color: #93c5fd;
    background: rgba(59, 130, 246, 0.1);
    padding: 2px 6px;
    border-radius: var(--radius-xs);
  }

  /* Skills grid */
  .ad-skills-grid {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }

  .ad-skill-chip {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 5px 10px;
    border-radius: var(--radius-xs);
    background: rgba(59, 130, 246, 0.08);
    border: 1px solid rgba(59, 130, 246, 0.2);
  }

  .ad-skill-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #60a5fa;
    flex-shrink: 0;
  }

  .ad-skill-name {
    font-size: 12px;
    font-family: var(--font-mono);
    color: #93c5fd;
  }

  /* Budget summary */
  .ad-budget-summary {
    display: flex;
    align-items: baseline;
    gap: 8px;
  }

  .ad-budget-num {
    font-size: 28px;
    font-weight: 700;
    color: var(--text-primary);
    font-variant-numeric: tabular-nums;
  }

  .ad-budget-label {
    font-size: 12px;
    color: var(--text-tertiary);
  }

  /* Empty states */
  .ad-empty-tab {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    height: 200px;
    color: var(--text-tertiary);
    font-size: 13px;
  }

  .ad-empty-icon {
    font-size: 36px;
    opacity: 0.35;
  }

  .ad-empty-tab p {
    margin: 0;
    text-align: center;
    max-width: 320px;
    line-height: 1.5;
  }

  /* Misc */
  .ad-muted {
    color: var(--text-muted);
    font-size: 13px;
  }

  .ad-link {
    color: #93c5fd;
    text-decoration: none;
  }

  .ad-link:hover {
    text-decoration: underline;
  }
</style>
