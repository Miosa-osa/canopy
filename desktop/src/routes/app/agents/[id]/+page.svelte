<!-- src/routes/app/agents/[id]/+page.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import StatusDot from '$lib/components/shared/StatusDot.svelte';
  import MetricCard from '$lib/components/shared/MetricCard.svelte';
  import TimeAgo from '$lib/components/shared/TimeAgo.svelte';
  import LoadingSpinner from '$lib/components/shared/LoadingSpinner.svelte';
  import { agentsStore } from '$lib/stores/agents.svelte';
  import { environmentStore } from '$lib/stores/environment.svelte';
  import { gatewaysStore } from '$lib/stores/gateways.svelte';
  import { agents as agentsApi } from '$api/client';
  import type { CanopyAgent, AgentStatus, AgentLifecycleAction, Session, InboxItem, AdapterType } from '$api/types';

  const agentId = $derived($page.params.id ?? '');

  let agent = $state<CanopyAgent | null>(null);
  let isLoading = $state(true);
  let activeTab = $state<'overview' | 'config' | 'schedules' | 'skills' | 'runs' | 'budget' | 'inbox' | 'access'>('overview');

  // Runs tab state
  let runs = $state<Session[]>([]);
  let runsLoading = $state(false);
  let runsFetched = $state(false);

  // Inbox tab state
  let inboxItems = $state<InboxItem[]>([]);
  let inboxLoading = $state(false);
  let inboxFetched = $state(false);

  // Access tab state
  const TOOLS = [
    { id: 'computer_use',   label: 'Computer Use',   description: 'Desktop control, screenshots' },
    { id: 'file_system',    label: 'File System',     description: 'Read/write local files' },
    { id: 'shell',          label: 'Shell',           description: 'Execute shell commands' },
    { id: 'web_fetch',      label: 'Web Fetch',       description: 'HTTP requests, web scraping' },
    { id: 'knowledge',      label: 'Knowledge',       description: 'Semantic knowledge graph' },
    { id: 'code_execution', label: 'Code Execution',  description: 'Run code in sandbox' },
  ] as const;

  const ADAPTER_OPTIONS: { value: AdapterType; label: string; description: string }[] = [
    { value: 'claude-code',  label: 'Claude Code',  description: 'Runs claude CLI in its own terminal — full coding agent' },
    { value: 'claude_code',  label: 'Claude Code',  description: 'Runs claude CLI in its own terminal — full coding agent' },
    { value: 'osa',          label: 'OSA Agent',     description: 'OSA runtime — orchestrated agent execution' },
    { value: 'codex',        label: 'Codex',         description: 'OpenAI Codex runtime' },
    { value: 'bash',         label: 'Bash Shell',    description: 'Runs shell commands directly' },
    { value: 'http',         label: 'HTTP API',      description: 'Calls an external API endpoint' },
    { value: 'cursor',       label: 'Cursor',        description: 'Cursor IDE agent runtime' },
    { value: 'gemini',       label: 'Gemini',        description: 'Google Gemini runtime' },
    { value: 'custom',       label: 'Custom',        description: 'Custom adapter implementation' },
  ];

  // Local editable copies for config & access tabs
  let localAdapter = $state<AdapterType>('osa');
  let localModel = $state('');
  let localWorkingDir = $state('');
  let localSystemPrompt = $state('');
  let localTemperature = $state(0.3);
  let localMaxConcurrent = $state(1);
  let localGatewayId = $state<string>('');
  let configSaving = $state(false);
  let configSaved = $state(false);
  let enabledTools = $state<Record<string, boolean>>({
    computer_use: false,
    file_system: false,
    shell: false,
    web_fetch: false,
    knowledge: false,
    code_execution: false,
  });

  let accessFetched = $state(false);

  function adapterDescription(adapter: AdapterType): string {
    return ADAPTER_OPTIONS.find(a => a.value === adapter)?.description ?? '';
  }

  // Save runtime config to backend
  async function saveRuntimeConfig() {
    if (!agent) return;
    configSaving = true;
    configSaved = false;
    try {
      const config = { ...(agent.config ?? {}) };
      if (localWorkingDir) config.working_dir = localWorkingDir;
      if (localAdapter === 'claude-code' || localAdapter === 'claude_code') {
        config.model = localModel || agent.model;
      }

      const toolsList = Object.entries(enabledTools)
        .filter(([, v]) => v)
        .map(([k]) => k);
      config.tools = toolsList;

      await agentsApi.update(agent.id, {
        adapter: localAdapter,
        model: localModel || agent.model,
        system_prompt: localSystemPrompt || agent.system_prompt,
        temperature: localTemperature,
        max_concurrent_runs: localMaxConcurrent,
        config,
      });

      // Refresh agent from store
      agent = await agentsStore.fetchAgent(agent.id) ?? agent;
      configSaved = true;
      setTimeout(() => { configSaved = false; }, 2000);
    } catch {
      // Error handling via store
    }
    configSaving = false;
  }

  const TABS = [
    { id: 'overview'  as const, label: 'Overview'       },
    { id: 'config'    as const, label: 'Config'         },
    { id: 'schedules' as const, label: 'Schedules'      },
    { id: 'skills'    as const, label: 'Skills'         },
    { id: 'runs'      as const, label: 'Runs'           },
    { id: 'budget'    as const, label: 'Budget'         },
    { id: 'inbox'     as const, label: 'Inbox'          },
    { id: 'access'    as const, label: 'Tools & Access' },
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

  $effect(() => {
    // Fetch runs when the tab becomes active (once per page load)
    if (activeTab === 'runs' && !runsFetched && agentId) {
      runsFetched = true;
      runsLoading = true;
      void agentsApi.runs(agentId).then((data) => {
        runs = (data.runs as Session[]) ?? [];
        runsLoading = false;
      }).catch(() => {
        runsLoading = false;
      });
    }
  });

  $effect(() => {
    // Fetch inbox items when the tab becomes active (once per page load)
    if (activeTab === 'inbox' && !inboxFetched && agentId) {
      inboxFetched = true;
      inboxLoading = true;
      void agentsApi.inbox(agentId).then((data) => {
        inboxItems = (data.items as InboxItem[]) ?? [];
        inboxLoading = false;
      }).catch(() => {
        inboxLoading = false;
      });
    }
  });

  $effect(() => {
    // Populate editable state from agent data once loaded
    if (agent && !accessFetched) {
      localAdapter = agent.adapter;
      localModel = agent.model;
      localWorkingDir = (agent.config?.working_dir as string) ?? (agent.config?.workspace_path as string) ?? '';
      localSystemPrompt = agent.system_prompt ?? '';
      localTemperature = agent.temperature ?? 0.3;
      localMaxConcurrent = agent.max_concurrent_runs ?? 1;
      // Derive enabled tools from agent.config.tools array if present
      const configTools = (agent.config?.tools ?? []) as string[];
      if (configTools.length > 0) {
        for (const t of TOOLS) {
          enabledTools[t.id] = configTools.includes(t.id);
        }
      }
    }
  });

  $effect(() => {
    // Lazy-load environment apps and gateways when access tab opens
    if (activeTab === 'access' && !accessFetched) {
      accessFetched = true;
      if (environmentStore.apps.length === 0) {
        void environmentStore.fetchApps();
      }
      if (gatewaysStore.gateways.length === 0) {
        void gatewaysStore.fetchGateways();
      }
      // Set gateway selection to primary if not already set
      if (!localGatewayId && gatewaysStore.primaryGateway) {
        localGatewayId = gatewaysStore.primaryGateway.id;
      }
    }
  });

  $effect(() => {
    // Once gateways load, set default selection if still empty
    if (activeTab === 'access' && !localGatewayId && gatewaysStore.primaryGateway) {
      localGatewayId = gatewaysStore.primaryGateway.id;
    }
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

  function categoryEmoji(cat: string): string {
    switch (cat) {
      case 'development':   return '🛠️';
      case 'database':      return '🗄️';
      case 'automation':    return '⚙️';
      case 'browser':       return '🌐';
      case 'design':        return '🎨';
      case 'communication': return '💬';
      default:              return '📦';
    }
  }

  function adapterStatusColor(a: AdapterType): string {
    switch (a) {
      case 'osa':         return '#a78bfa';
      case 'claude_code': return '#60a5fa';
      case 'bash':        return '#34d399';
      default:            return 'var(--text-tertiary)';
    }
  }

  function selectedGateway() {
    return gatewaysStore.gateways.find((g) => g.id === localGatewayId) ?? null;
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
        {#if agent.status === 'running' || agent.status === 'active' || agent.status === 'working' || agent.status === 'idle'}
          <button class="ad-btn ad-btn--accent" onclick={() => handleAction('focus')} aria-label="Focus agent on current task">
            Focus
          </button>
        {/if}
        {#if agent.status === 'running' || agent.status === 'active' || agent.status === 'working' || agent.status === 'idle'}
          <button class="ad-btn" onclick={() => handleAction('sleep')} aria-label="Put agent to sleep">
            Sleep
          </button>
        {/if}
        {#if agent.status === 'running' || agent.status === 'active' || agent.status === 'working'}
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
          <!-- Runtime / Adapter -->
          <section class="ad-card" aria-label="Runtime configuration">
            <h2 class="ad-card-title">Runtime</h2>
            <p class="ad-card-subtitle">How this agent executes — which engine and where it runs.</p>

            <div class="ad-form-group">
              <label class="ad-form-label" for="cfg-adapter">Adapter</label>
              <select id="cfg-adapter" class="ad-form-select" bind:value={localAdapter} aria-label="Select runtime adapter">
                {#each ADAPTER_OPTIONS as opt}
                  <option value={opt.value}>{opt.label}</option>
                {/each}
              </select>
              <span class="ad-form-hint">{adapterDescription(localAdapter)}</span>
            </div>

            {#if localAdapter === 'claude-code' || localAdapter === 'claude_code'}
              <div class="ad-runtime-callout">
                <span class="ad-runtime-callout-icon" aria-hidden="true">⌨️</span>
                <div>
                  <strong>Claude Code</strong> — This agent runs the <code>claude</code> CLI in its own isolated terminal process.
                  It has full coding capabilities: file read/write, shell execution, and autonomous task completion.
                </div>
              </div>
            {/if}

            <div class="ad-form-group">
              <label class="ad-form-label" for="cfg-model">Model</label>
              <select id="cfg-model" class="ad-form-select" bind:value={localModel} aria-label="Select LLM model">
                <option value="sonnet">Claude Sonnet</option>
                <option value="opus">Claude Opus</option>
                <option value="haiku">Claude Haiku</option>
                <option value="claude-sonnet-4-6">Claude Sonnet 4.6</option>
                <option value="claude-opus-4-6">Claude Opus 4.6</option>
                <option value="claude-haiku-4-5">Claude Haiku 4.5</option>
              </select>
            </div>

            <div class="ad-form-group">
              <label class="ad-form-label" for="cfg-workdir">Working Directory</label>
              <input
                id="cfg-workdir"
                type="text"
                class="ad-form-input"
                placeholder="/path/to/workspace"
                bind:value={localWorkingDir}
                aria-label="Working directory for agent execution"
              />
              <span class="ad-form-hint">Where the agent operates — its file system root.</span>
            </div>

            <div class="ad-form-row-inline">
              <div class="ad-form-group" style="flex:1">
                <label class="ad-form-label" for="cfg-temp">Temperature</label>
                <input
                  id="cfg-temp"
                  type="number"
                  class="ad-form-input"
                  min="0" max="1" step="0.1"
                  bind:value={localTemperature}
                />
              </div>
              <div class="ad-form-group" style="flex:1">
                <label class="ad-form-label" for="cfg-concurrent">Max Concurrent Runs</label>
                <input
                  id="cfg-concurrent"
                  type="number"
                  class="ad-form-input"
                  min="1" max="10"
                  bind:value={localMaxConcurrent}
                />
              </div>
            </div>
          </section>

          <!-- System Prompt -->
          <section class="ad-card" aria-label="System prompt">
            <h2 class="ad-card-title">System Prompt</h2>
            <textarea
              class="ad-form-textarea"
              rows="8"
              placeholder="Instructions for this agent..."
              bind:value={localSystemPrompt}
              aria-label="Agent system prompt"
            ></textarea>
          </section>

          <!-- Save -->
          <div class="ad-config-actions">
            <button
              class="ad-save-btn"
              onclick={saveRuntimeConfig}
              disabled={configSaving}
              aria-label="Save runtime configuration"
            >
              {#if configSaving}
                Saving…
              {:else if configSaved}
                Saved
              {:else}
                Save Configuration
              {/if}
            </button>
          </div>

          <!-- Raw Config (collapsible for debugging) -->
          <details class="ad-card ad-config-details">
            <summary class="ad-card-title" style="cursor:pointer">Raw Config JSON</summary>
            <pre class="ad-code-block" aria-label="Agent configuration JSON">{JSON.stringify(agent.config, null, 2)}</pre>
          </details>
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
          {#if runsLoading}
            <div class="ad-empty-tab" role="status" aria-live="polite">
              <LoadingSpinner size="sm" />
              <span>Loading runs…</span>
            </div>
          {:else if runs.length === 0}
            <div class="ad-empty-tab" role="status">
              <span class="ad-empty-icon" aria-hidden="true">🏃</span>
              <p>No runs yet.</p>
            </div>
          {:else}
            <section class="ad-card" aria-label="Agent runs">
              <h2 class="ad-card-title">Runs ({runs.length})</h2>
              <div class="ad-runs-list" role="list" aria-label="Session runs">
                {#each runs as run (run.id)}
                  <div class="ad-run-row" role="listitem">
                    <div class="ad-run-status-col">
                      <span
                        class="ad-run-dot"
                        class:ad-run-dot--active={run.status === 'active'}
                        class:ad-run-dot--completed={run.status === 'completed'}
                        class:ad-run-dot--failed={run.status === 'failed'}
                        aria-hidden="true"
                      ></span>
                      <span class="ad-run-status">{run.status}</span>
                    </div>
                    <div class="ad-run-meta">
                      <span class="ad-run-title">{run.title ?? run.id}</span>
                      <span class="ad-run-detail">
                        <TimeAgo date={run.started_at} />
                        · {formatTokens(run.token_usage.input + run.token_usage.output)} tokens
                        · {formatCost(run.cost_cents)}
                      </span>
                    </div>
                    <span class="ad-run-model">{run.message_count} msgs</span>
                  </div>
                {/each}
              </div>
            </section>
          {/if}
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
          {#if inboxLoading}
            <div class="ad-empty-tab" role="status" aria-live="polite">
              <LoadingSpinner size="sm" />
              <span>Loading notifications…</span>
            </div>
          {:else if inboxItems.length === 0}
            <div class="ad-empty-tab" role="status">
              <span class="ad-empty-icon" aria-hidden="true">📬</span>
              <p>No notifications.</p>
            </div>
          {:else}
            <section class="ad-card" aria-label="Agent inbox">
              <h2 class="ad-card-title">Notifications ({inboxItems.length})</h2>
              <div class="ad-inbox-list" role="list" aria-label="Inbox notifications">
                {#each inboxItems as item (item.id)}
                  <div
                    class="ad-inbox-row"
                    class:ad-inbox-row--unread={item.status === 'unread'}
                    role="listitem"
                  >
                    <div class="ad-inbox-meta">
                      <span class="ad-inbox-type ad-inbox-type--{item.type}">{item.type.replace('_', ' ')}</span>
                      <span class="ad-inbox-time"><TimeAgo date={item.created_at} /></span>
                    </div>
                    <p class="ad-inbox-title">{item.title}</p>
                    <p class="ad-inbox-body">{item.body}</p>
                  </div>
                {/each}
              </div>
            </section>
          {/if}
        </div>

      <!-- TOOLS & ACCESS -->
      {:else if activeTab === 'access'}
        <div
          id="ad-panel-access"
          role="tabpanel"
          aria-label="Tools and Access tab"
          class="ad-panel"
        >

          <!-- Section 1: Adapter -->
          <section class="ad-card" aria-label="Adapter configuration">
            <h2 class="ad-card-title">Adapter</h2>
            <div class="ad-access-dl">
              <div class="ad-access-row">
                <dt class="ad-access-dt">Type</dt>
                <dd class="ad-access-dd">
                  <div class="ad-select-wrap">
                    <span class="ad-adapter-dot" style="background: {adapterStatusColor(localAdapter)};" aria-hidden="true"></span>
                    <select
                      class="ad-select"
                      bind:value={localAdapter}
                      aria-label="Select adapter type"
                    >
                      {#each ADAPTER_OPTIONS as opt}
                        <option value={opt.value}>{opt.label}</option>
                      {/each}
                    </select>
                  </div>
                </dd>
              </div>
              <div class="ad-access-row">
                <dt class="ad-access-dt">Runtime</dt>
                <dd class="ad-access-dd">
                  <span class="ad-muted">{adapterDescription(localAdapter)}</span>
                </dd>
              </div>
              <div class="ad-access-row">
                <dt class="ad-access-dt">Status</dt>
                <dd class="ad-access-dd">
                  <span class="ad-adapter-status-pill">
                    <span class="ad-run-dot ad-run-dot--active" aria-hidden="true" style="width:6px;height:6px;"></span>
                    active
                  </span>
                </dd>
              </div>
            </div>
          </section>

          <!-- Section 2: Gateway -->
          <section class="ad-card" aria-label="LLM gateway configuration">
            <h2 class="ad-card-title">Gateway</h2>
            {#if gatewaysStore.loading}
              <p class="ad-muted">Loading gateways…</p>
            {:else if gatewaysStore.gateways.length === 0}
              <p class="ad-muted">No gateways configured. Add one in <a href="/app/gateways" class="ad-link">Gateways</a>.</p>
            {:else}
              <div class="ad-access-dl">
                <div class="ad-access-row">
                  <dt class="ad-access-dt">Gateway</dt>
                  <dd class="ad-access-dd">
                    <select
                      class="ad-select"
                      bind:value={localGatewayId}
                      aria-label="Select LLM gateway"
                    >
                      <option value="">— none —</option>
                      {#each gatewaysStore.gateways as gw}
                        <option value={gw.id}>
                          {gw.name}
                          {gw.is_primary ? ' (primary)' : ''}
                          {gw.status === 'healthy' || gw.status === 'connected' ? '' : ' ⚠'}
                        </option>
                      {/each}
                    </select>
                  </dd>
                </div>
                {#if selectedGateway()}
                  <div class="ad-access-row">
                    <dt class="ad-access-dt">Provider</dt>
                    <dd class="ad-access-dd">
                      <code class="ad-code-inline">{selectedGateway()!.provider}</code>
                    </dd>
                  </div>
                  <div class="ad-access-row">
                    <dt class="ad-access-dt">Model</dt>
                    <dd class="ad-access-dd">
                      <code class="ad-code-inline">{agent!.model}</code>
                    </dd>
                  </div>
                  <div class="ad-access-row">
                    <dt class="ad-access-dt">Latency</dt>
                    <dd class="ad-access-dd">
                      <span class="ad-muted">
                        {selectedGateway()!.latency_ms != null ? `${selectedGateway()!.latency_ms}ms` : '—'}
                      </span>
                    </dd>
                  </div>
                {/if}
              </div>
            {/if}
          </section>

          <!-- Section 3: Tools -->
          <section class="ad-card" aria-label="Tool permissions">
            <h2 class="ad-card-title">Tools</h2>
            <div class="ad-tools-list" role="list" aria-label="Available tools">
              {#each TOOLS as tool}
                <div class="ad-tool-row" role="listitem">
                  <div class="ad-tool-info">
                    <span class="ad-tool-name">{tool.label}</span>
                    <span class="ad-tool-desc">{tool.description}</span>
                  </div>
                  <button
                    class="ad-toggle"
                    class:ad-toggle--on={enabledTools[tool.id]}
                    role="switch"
                    aria-checked={enabledTools[tool.id]}
                    aria-label="Toggle {tool.label}"
                    onclick={() => { enabledTools[tool.id] = !enabledTools[tool.id]; }}
                  >
                    <span class="ad-toggle-thumb" aria-hidden="true"></span>
                  </button>
                </div>
              {/each}
            </div>
          </section>

          <!-- Section 4: App Access -->
          <section class="ad-card" aria-label="Application access control">
            <h2 class="ad-card-title">
              App Access
              {#if environmentStore.apps.length > 0}
                <span class="ad-card-count">
                  {environmentStore.apps.filter(a => a.agent_access.includes(agentId)).length}/{environmentStore.apps.length}
                </span>
              {/if}
            </h2>

            {#if environmentStore.loading}
              <div class="ad-access-loading" aria-live="polite">
                <span class="ad-muted">Detecting apps…</span>
              </div>
            {:else if environmentStore.apps.length === 0}
              <p class="ad-muted">No apps detected in the environment.</p>
            {:else}
              <div class="ad-apps-grid" role="list" aria-label="Detected apps">
                {#each environmentStore.apps as app (app.id)}
                  {@const hasAccess = app.agent_access.includes(agentId)}
                  <div
                    class="ad-app-card"
                    class:ad-app-card--granted={hasAccess}
                    role="listitem"
                    aria-label="{app.name}, access {hasAccess ? 'granted' : 'revoked'}"
                  >
                    <div class="ad-app-header">
                      <span class="ad-app-emoji" aria-hidden="true">{categoryEmoji(app.category)}</span>
                      <div class="ad-app-meta">
                        <span class="ad-app-name">{app.name}</span>
                        <span class="ad-app-proc">{app.process_name}</span>
                      </div>
                      <div class="ad-app-status" aria-label="App status: {app.status}">
                        <span
                          class="ad-run-dot"
                          class:ad-run-dot--active={app.status === 'running'}
                          style={app.status !== 'running' ? 'background: var(--border-default)' : ''}
                          aria-hidden="true"
                        ></span>
                      </div>
                    </div>
                    <div class="ad-app-footer">
                      <span class="ad-app-cat">{app.category}</span>
                      <button
                        class="ad-toggle ad-toggle--sm"
                        class:ad-toggle--on={hasAccess}
                        role="switch"
                        aria-checked={hasAccess}
                        aria-label="{hasAccess ? 'Revoke' : 'Grant'} access to {app.name}"
                        onclick={() => {
                          if (hasAccess) {
                            void environmentStore.revokeAccess(app.id, agentId);
                          } else {
                            void environmentStore.grantAccess(app.id, agentId);
                          }
                        }}
                      >
                        <span class="ad-toggle-thumb" aria-hidden="true"></span>
                      </button>
                    </div>
                  </div>
                {/each}
              </div>
            {/if}
          </section>

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

  /* Runs list */
  .ad-runs-list {
    display: flex;
    flex-direction: column;
    gap: 0;
  }

  .ad-run-row {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px 0;
    border-bottom: 1px solid var(--border-default);
  }

  .ad-run-row:last-child {
    border-bottom: none;
    padding-bottom: 0;
  }

  .ad-run-status-col {
    display: flex;
    align-items: center;
    gap: 6px;
    min-width: 90px;
    flex-shrink: 0;
  }

  .ad-run-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: var(--border-default);
    flex-shrink: 0;
  }

  .ad-run-dot--active    { background: #22c55e; box-shadow: 0 0 5px rgba(34, 197, 94, 0.5); }
  .ad-run-dot--completed { background: #60a5fa; }
  .ad-run-dot--failed    { background: #f87171; }

  .ad-run-status {
    font-size: 11px;
    color: var(--text-tertiary);
    text-transform: capitalize;
  }

  .ad-run-meta {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .ad-run-title {
    font-size: 13px;
    color: var(--text-primary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ad-run-detail {
    font-size: 11px;
    color: var(--text-tertiary);
  }

  .ad-run-model {
    font-size: 11px;
    color: var(--text-tertiary);
    font-variant-numeric: tabular-nums;
    flex-shrink: 0;
  }

  /* Inbox list */
  .ad-inbox-list {
    display: flex;
    flex-direction: column;
    gap: 0;
  }

  .ad-inbox-row {
    padding: 12px 0;
    border-bottom: 1px solid var(--border-default);
  }

  .ad-inbox-row:last-child {
    border-bottom: none;
    padding-bottom: 0;
  }

  .ad-inbox-row--unread .ad-inbox-title {
    font-weight: 600;
  }

  .ad-inbox-meta {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 4px;
  }

  .ad-inbox-type {
    font-size: 10px;
    padding: 1px 6px;
    border-radius: 4px;
    text-transform: capitalize;
    background: var(--bg-secondary);
    color: var(--text-tertiary);
    border: 1px solid var(--border-default);
  }

  .ad-inbox-type--approval     { background: rgba(59, 130, 246, 0.1); border-color: rgba(59, 130, 246, 0.25); color: #93c5fd; }
  .ad-inbox-type--alert        { background: rgba(239, 68, 68, 0.1); border-color: rgba(239, 68, 68, 0.25); color: #f87171; }
  .ad-inbox-type--failure      { background: rgba(239, 68, 68, 0.1); border-color: rgba(239, 68, 68, 0.25); color: #f87171; }
  .ad-inbox-type--budget_warning { background: rgba(234, 179, 8, 0.1); border-color: rgba(234, 179, 8, 0.25); color: #fde047; }
  .ad-inbox-type--mention      { background: rgba(139, 92, 246, 0.1); border-color: rgba(139, 92, 246, 0.25); color: #c4b5fd; }
  .ad-inbox-type--report       { background: rgba(34, 197, 94, 0.1); border-color: rgba(34, 197, 94, 0.25); color: #86efac; }

  .ad-inbox-time {
    font-size: 11px;
    color: var(--text-tertiary);
    margin-left: auto;
  }

  .ad-inbox-title {
    font-size: 13px;
    color: var(--text-primary);
    margin: 0 0 4px 0;
  }

  .ad-inbox-body {
    font-size: 12px;
    color: var(--text-tertiary);
    line-height: 1.5;
    margin: 0;
  }

  /* ── Config tab form elements ─────────────────────────────────────────────── */

  .ad-card-subtitle {
    font-size: 12px;
    color: var(--text-tertiary);
    margin: -4px 0 16px;
  }

  .ad-form-group {
    margin-bottom: 14px;
  }

  .ad-form-label {
    display: block;
    font-size: 11px;
    font-weight: 600;
    color: var(--text-secondary);
    margin-bottom: 4px;
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }

  .ad-form-select,
  .ad-form-input {
    width: 100%;
    height: 34px;
    padding: 0 10px;
    border: 1px solid var(--border-default);
    background: var(--bg-secondary);
    color: var(--text-primary);
    border-radius: var(--radius-sm);
    font-size: 13px;
    font-family: inherit;
    transition: border-color 120ms ease;
  }

  .ad-form-select:focus,
  .ad-form-input:focus {
    outline: none;
    border-color: var(--accent-primary, #60a5fa);
  }

  .ad-form-textarea {
    width: 100%;
    padding: 10px;
    border: 1px solid var(--border-default);
    background: var(--bg-secondary);
    color: var(--text-primary);
    border-radius: var(--radius-sm);
    font-size: 12px;
    font-family: var(--font-mono);
    line-height: 1.5;
    resize: vertical;
    transition: border-color 120ms ease;
  }

  .ad-form-textarea:focus {
    outline: none;
    border-color: var(--accent-primary, #60a5fa);
  }

  .ad-form-hint {
    display: block;
    font-size: 11px;
    color: var(--text-muted);
    margin-top: 4px;
  }

  .ad-form-row-inline {
    display: flex;
    gap: 12px;
  }

  .ad-runtime-callout {
    display: flex;
    align-items: flex-start;
    gap: 10px;
    padding: 10px 12px;
    background: rgba(96, 165, 250, 0.08);
    border: 1px solid rgba(96, 165, 250, 0.2);
    border-radius: var(--radius-sm);
    margin-bottom: 14px;
    font-size: 12px;
    color: var(--text-secondary);
    line-height: 1.5;
  }

  .ad-runtime-callout-icon {
    font-size: 18px;
    flex-shrink: 0;
    margin-top: 1px;
  }

  .ad-runtime-callout code {
    font-family: var(--font-mono);
    font-size: 11px;
    background: rgba(96, 165, 250, 0.15);
    padding: 1px 4px;
    border-radius: 3px;
  }

  .ad-config-actions {
    display: flex;
    justify-content: flex-end;
    padding: 0 0 8px;
  }

  .ad-save-btn {
    padding: 8px 20px;
    background: var(--accent-primary, #60a5fa);
    color: #fff;
    border: none;
    border-radius: var(--radius-sm);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: opacity 120ms ease;
  }

  .ad-save-btn:hover:not(:disabled) {
    opacity: 0.9;
  }

  .ad-save-btn:disabled {
    opacity: 0.5;
    cursor: default;
  }

  .ad-config-details {
    opacity: 0.7;
  }

  .ad-config-details[open] {
    opacity: 1;
  }

  /* ── Tools & Access tab ──────────────────────────────────────────────────── */

  /* Card count badge in title */
  .ad-card-count {
    font-size: 10px;
    font-weight: 500;
    color: var(--text-tertiary);
    background: var(--bg-secondary);
    border: 1px solid var(--border-default);
    border-radius: 10px;
    padding: 1px 7px;
    margin-left: 6px;
    text-transform: none;
    letter-spacing: 0;
  }

  /* Access definition list — shares ad-dl visual rhythm */
  .ad-access-dl {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .ad-access-row {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .ad-access-dt {
    font-size: 12px;
    color: var(--text-tertiary);
    min-width: 80px;
    flex-shrink: 0;
  }

  .ad-access-dd {
    display: flex;
    align-items: center;
    gap: 8px;
    margin: 0;
  }

  /* Adapter color dot */
  .ad-adapter-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .ad-adapter-status-pill {
    display: flex;
    align-items: center;
    gap: 5px;
    font-size: 12px;
    color: var(--text-secondary);
  }

  /* Select dropdown */
  .ad-select-wrap {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .ad-select {
    height: 28px;
    padding: 0 28px 0 10px;
    border-radius: var(--radius-xs);
    border: 1px solid var(--border-default);
    background: var(--bg-elevated);
    color: var(--text-primary);
    font-size: 12px;
    font-family: var(--font-sans);
    cursor: pointer;
    appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='10' height='6' viewBox='0 0 10 6'%3E%3Cpath d='M1 1l4 4 4-4' stroke='%236b7280' stroke-width='1.5' fill='none' stroke-linecap='round'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 8px center;
    transition: border-color 120ms ease;
  }

  .ad-select:hover {
    border-color: var(--border-hover);
  }

  .ad-select:focus {
    outline: none;
    border-color: var(--accent-primary);
  }

  /* Toggle switch */
  .ad-toggle {
    position: relative;
    width: 36px;
    height: 20px;
    border-radius: 10px;
    border: 1px solid var(--border-default);
    background: var(--bg-secondary);
    cursor: pointer;
    flex-shrink: 0;
    transition: background 150ms ease, border-color 150ms ease;
    padding: 0;
  }

  .ad-toggle--sm {
    width: 30px;
    height: 17px;
    border-radius: 9px;
  }

  .ad-toggle--on {
    background: rgba(34, 197, 94, 0.2);
    border-color: rgba(34, 197, 94, 0.5);
  }

  .ad-toggle-thumb {
    position: absolute;
    top: 2px;
    left: 2px;
    width: 14px;
    height: 14px;
    border-radius: 50%;
    background: var(--text-tertiary);
    transition: transform 150ms ease, background 150ms ease;
    pointer-events: none;
  }

  .ad-toggle--sm .ad-toggle-thumb {
    width: 11px;
    height: 11px;
  }

  .ad-toggle--on .ad-toggle-thumb {
    transform: translateX(16px);
    background: #22c55e;
  }

  .ad-toggle--sm.ad-toggle--on .ad-toggle-thumb {
    transform: translateX(13px);
  }

  /* Tools list */
  .ad-tools-list {
    display: flex;
    flex-direction: column;
    gap: 0;
  }

  .ad-tool-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 10px 0;
    border-bottom: 1px solid var(--border-default);
  }

  .ad-tool-row:last-child {
    border-bottom: none;
    padding-bottom: 0;
  }

  .ad-tool-info {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }

  .ad-tool-name {
    font-size: 13px;
    font-weight: 500;
    color: var(--text-primary);
  }

  .ad-tool-desc {
    font-size: 11px;
    color: var(--text-tertiary);
  }

  /* Apps grid */
  .ad-access-loading {
    padding: 12px 0;
  }

  .ad-apps-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
    gap: 10px;
    margin-top: 4px;
  }

  .ad-app-card {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 12px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-default);
    background: var(--bg-secondary);
    transition: border-color 150ms ease, background 150ms ease;
  }

  .ad-app-card--granted {
    border-color: rgba(34, 197, 94, 0.3);
    background: rgba(34, 197, 94, 0.04);
  }

  .ad-app-header {
    display: flex;
    align-items: flex-start;
    gap: 8px;
  }

  .ad-app-emoji {
    font-size: 20px;
    line-height: 1;
    flex-shrink: 0;
    margin-top: 1px;
  }

  .ad-app-meta {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
    flex: 1;
  }

  .ad-app-name {
    font-size: 12px;
    font-weight: 500;
    color: var(--text-primary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ad-app-proc {
    font-size: 10px;
    color: var(--text-tertiary);
    font-family: var(--font-mono);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ad-app-status {
    flex-shrink: 0;
    margin-top: 3px;
  }

  .ad-app-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .ad-app-cat {
    font-size: 10px;
    color: var(--text-tertiary);
    text-transform: capitalize;
  }
</style>
