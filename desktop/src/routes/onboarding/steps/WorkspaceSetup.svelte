<script lang="ts">
  import type { TeamTemplate, AgentTemplateData } from '$lib/stores/onboarding.svelte';
  import { isTauri } from '$lib/utils/platform';

  const TEAM_TEMPLATES: { id: TeamTemplate; name: string; description: string; count: number }[] = [
    { id: 'solo',     name: 'Solo',      description: '1 general-purpose agent',     count: 1 },
    { id: 'dev-team', name: 'Dev Team',  description: '4 specialised agents',        count: 4 },
    { id: 'research', name: 'Research',  description: '3 research & writing agents', count: 3 },
    { id: 'custom',   name: 'Custom',    description: 'Start empty, add later',      count: 0 },
  ];

  const TEMPLATE_AGENTS: Record<TeamTemplate, AgentTemplateData[]> = {
    solo: [
      { id: 'main-agent', name: 'Main Agent', emoji: 'bot', role: 'engineer', adapter: 'osa', skills: ['code', 'debug', 'test'], system_prompt: 'You are a skilled software engineer...' },
    ],
    'dev-team': [
      { id: 'orchestrator',    name: 'Orchestrator',    emoji: 'brain',  role: 'orchestrator', adapter: 'osa', skills: ['delegate', 'plan'],             system_prompt: 'You coordinate a development team...' },
      { id: 'code-worker',     name: 'Code Worker',     emoji: 'code',   role: 'developer',    adapter: 'osa', skills: ['code', 'debug'],                system_prompt: 'You are a focused code implementation specialist...' },
      { id: 'research-worker', name: 'Research Worker', emoji: 'search', role: 'researcher',   adapter: 'osa', skills: ['web_search', 'analyze'],        system_prompt: 'You research solutions, APIs, and best practices...' },
      { id: 'qa-agent',        name: 'QA Agent',        emoji: 'shield', role: 'engineer',     adapter: 'osa', skills: ['test', 'validate'],             system_prompt: 'You ensure code quality through testing...' },
    ],
    research: [
      { id: 'lead-researcher', name: 'Lead Researcher', emoji: 'search', role: 'researcher', adapter: 'osa', skills: ['web_search', 'analyze', 'summarize'], system_prompt: 'You lead research investigations...' },
      { id: 'data-analyst',    name: 'Data Analyst',    emoji: 'chart',  role: 'researcher', adapter: 'osa', skills: ['analyze', 'visualize'],              system_prompt: 'You analyze data and produce insights...' },
      { id: 'writer',          name: 'Writer',          emoji: 'pen',    role: 'writer',     adapter: 'osa', skills: ['write', 'edit', 'format'],            system_prompt: 'You produce clear, well-structured written content...' },
    ],
    custom: [],
  };

  interface Props {
    workspacePath: string;
    workspaceName: string;
    teamTemplate: TeamTemplate;
  }

  let {
    workspacePath = $bindable(),
    workspaceName = $bindable(),
    teamTemplate  = $bindable(),
  }: Props = $props();

  const teamAgents = $derived(TEMPLATE_AGENTS[teamTemplate]);

  // Auto-fill workspace name from path when path changes
  let lastAutoPath = $state(workspacePath);
  $effect(() => {
    const p = workspacePath;
    if (p === lastAutoPath) return;
    lastAutoPath = p;
    const parts = p.split('/');
    const last = parts[parts.length - 1];
    if (last && last !== '~' && last !== '.canopy') {
      workspaceName = last.replace(/[-_]/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
    } else if (p.includes('.canopy') || p === '~/.canopy') {
      workspaceName = 'My Workspace';
    }
  });

  async function choosePath() {
    if (!isTauri()) return;
    try {
      const { open } = await import('@tauri-apps/plugin-dialog');
      const selected = await open({ directory: true, multiple: false, title: 'Choose Workspace Directory' });
      if (selected && typeof selected === 'string') {
        workspacePath = selected;
      }
    } catch {
      // Dialog cancelled or unavailable — no action needed
    }
  }
</script>

<div class="ob-step">
  <div class="ob-step-icon">
    <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="28" height="28">
      <path d="M3 7a2 2 0 012-2h3.586a1 1 0 01.707.293L10.707 6.7A1 1 0 0011.414 7H15a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2V7z"/>
    </svg>
  </div>
  <h1 class="ob-title">Workspace Setup</h1>
  <p class="ob-subtitle">Where your agents live and who's on your team</p>

  <!-- Workspace path -->
  <div class="ob-field">
    <label class="ob-label" for="ob-path">DIRECTORY PATH</label>
    <div class="ob-path-row">
      <input
        id="ob-path"
        class="ob-input ob-input--path"
        type="text"
        placeholder="~/.canopy"
        bind:value={workspacePath}
      />
      <button class="ob-choose-btn" onclick={choosePath} aria-label="Choose directory">
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="13" height="13"><path d="M2 4a1 1 0 011-1h3l1.5 1.5H13a1 1 0 011 1V12a1 1 0 01-1 1H3a1 1 0 01-1-1V4z"/></svg>
        Choose
      </button>
    </div>
  </div>

  <!-- Workspace name -->
  <div class="ob-field">
    <label class="ob-label" for="ob-ws-name">WORKSPACE NAME</label>
    <input
      id="ob-ws-name"
      class="ob-input"
      type="text"
      placeholder="My Workspace"
      bind:value={workspaceName}
    />
  </div>

  <!-- Team template -->
  <div class="ob-field ob-field--no-mb">
    <span class="ob-label">TEAM TEMPLATE</span>
    <div class="ob-templates">
      {#each TEAM_TEMPLATES as t}
        <button
          class="ob-template-card"
          class:ob-template-card--selected={teamTemplate === t.id}
          onclick={() => teamTemplate = t.id}
        >
          <span class="ob-template-name">{t.name}</span>
          <span class="ob-template-meta">
            {t.count === 0 ? 'empty' : t.count === 1 ? '1 agent' : `${t.count} agents`}
          </span>
          <p class="ob-template-desc">{t.description}</p>
        </button>
      {/each}
    </div>
  </div>

  <!-- Agent preview (only when template has agents) -->
  {#if teamAgents.length > 0}
    <div class="ob-agent-list">
      {#each teamAgents as agent}
        <div class="ob-agent-item">
          <span class="ob-agent-dot"></span>
          <span class="ob-agent-name">{agent.name}</span>
          <span class="ob-agent-role">{agent.role}</span>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .ob-step {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    flex: 1;
    gap: 0;
  }

  .ob-step-icon {
    width: 52px;
    height: 52px;
    border-radius: 14px;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.08);
    display: flex;
    align-items: center;
    justify-content: center;
    color: rgba(255, 255, 255, 0.6);
    margin: 0 auto 1.25rem;
  }

  .ob-title {
    font-size: 1.625rem;
    font-weight: 700;
    color: #ffffff;
    margin: 0 0 0.375rem;
    letter-spacing: -0.02em;
  }

  .ob-subtitle {
    font-size: 0.875rem;
    color: rgba(255, 255, 255, 0.45);
    margin: 0 0 1.75rem;
  }

  .ob-label {
    display: block;
    font-size: 0.6875rem;
    font-weight: 600;
    letter-spacing: 0.08em;
    color: rgba(255, 255, 255, 0.35);
    margin-bottom: 0.375rem;
    text-align: left;
  }

  .ob-field {
    width: 100%;
    text-align: left;
    margin-bottom: 1rem;
  }

  .ob-field--no-mb {
    margin-bottom: 0;
  }

  .ob-input {
    width: 100%;
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 8px;
    padding: 0.625rem 0.875rem;
    font-size: 0.9375rem;
    color: #f0f0f0;
    outline: none;
    transition: border-color 150ms ease;
    box-sizing: border-box;
  }

  .ob-input::placeholder {
    color: rgba(255, 255, 255, 0.2);
  }

  .ob-input:focus {
    border-color: rgba(59, 130, 246, 0.5);
  }

  .ob-input--path {
    flex: 1;
    font-family: 'SF Mono', 'Fira Code', monospace;
    font-size: 0.8125rem;
  }

  .ob-path-row {
    display: flex;
    gap: 0.5rem;
    align-items: center;
  }

  .ob-choose-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0.5rem 0.75rem;
    border-radius: 9999px;
    font-size: 0.8125rem;
    font-weight: 500;
    cursor: pointer;
    background: rgba(255, 255, 255, 0.05);
    color: #a1a1a6;
    border: 1px solid rgba(255, 255, 255, 0.1);
    flex-shrink: 0;
    transition: background 150ms ease;
  }

  .ob-choose-btn:hover {
    background: rgba(255, 255, 255, 0.1);
    border-color: rgba(255, 255, 255, 0.15);
  }

  /* ─── Team template cards ─────────────────────────────────────────── */

  .ob-templates {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.5rem;
  }

  .ob-template-card {
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.07);
    border-radius: 10px;
    padding: 0.75rem;
    text-align: left;
    cursor: pointer;
    transition: background 150ms ease, border-color 150ms ease;
    display: flex;
    flex-direction: column;
    gap: 0.125rem;
  }

  .ob-template-card:hover {
    background: rgba(255, 255, 255, 0.06);
    border-color: rgba(255, 255, 255, 0.12);
  }

  .ob-template-card--selected {
    background: rgba(59, 130, 246, 0.07);
    border-color: rgba(59, 130, 246, 0.4);
  }

  .ob-template-name {
    font-size: 0.875rem;
    font-weight: 600;
    color: #e0e0e0;
  }

  .ob-template-meta {
    font-size: 0.6875rem;
    color: rgba(255, 255, 255, 0.3);
  }

  .ob-template-desc {
    font-size: 0.6875rem;
    color: rgba(255, 255, 255, 0.4);
    margin: 0.25rem 0 0;
    line-height: 1.4;
  }

  /* ─── Agent preview ───────────────────────────────────────────────── */

  .ob-agent-list {
    width: 100%;
    margin-top: 0.625rem;
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
  }

  .ob-agent-item {
    display: flex;
    align-items: center;
    gap: 0.625rem;
    background: rgba(255, 255, 255, 0.02);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 7px;
    padding: 0.4rem 0.75rem;
  }

  .ob-agent-dot {
    width: 5px;
    height: 5px;
    border-radius: 50%;
    background: #3b82f6;
    flex-shrink: 0;
  }

  .ob-agent-name {
    font-size: 0.8125rem;
    font-weight: 600;
    color: #d0d0d0;
    flex: 1;
    text-align: left;
  }

  .ob-agent-role {
    font-size: 0.6875rem;
    color: rgba(255, 255, 255, 0.3);
    text-align: right;
  }
</style>
