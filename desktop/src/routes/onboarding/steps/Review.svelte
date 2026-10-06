<script lang="ts">
  import type { AdapterType, TeamTemplate, AgentTemplateData } from '$lib/stores/onboarding.svelte';

  interface Provider {
    slug: string;
    name: string;
    noKey?: boolean;
  }

  const ALL_PROVIDERS: Provider[] = [
    { slug: 'anthropic',    name: 'Anthropic' },
    { slug: 'ollama-cloud', name: 'Ollama Cloud' },
    { slug: 'ollama-local', name: 'Ollama Local', noKey: true },
    { slug: 'google',       name: 'Google' },
    { slug: 'groq',         name: 'Groq' },
    { slug: 'deepseek',     name: 'DeepSeek' },
    { slug: 'mistral',      name: 'Mistral' },
    { slug: 'cohere',       name: 'Cohere' },
    { slug: 'together',     name: 'Together AI' },
    { slug: 'fireworks',    name: 'Fireworks AI' },
    { slug: 'perplexity',   name: 'Perplexity' },
    { slug: 'cerebras',     name: 'Cerebras' },
    { slug: 'sambanova',    name: 'SambaNova' },
    { slug: 'openrouter',   name: 'OpenRouter' },
    { slug: 'openai',       name: 'OpenAI' },
    { slug: 'replicate',    name: 'Replicate' },
    { slug: 'xai',          name: 'xAI' },
    { slug: 'lambda',       name: 'Lambda' },
    { slug: 'lepton',       name: 'Lepton AI' },
  ];

  const ADAPTER_NAMES: Record<AdapterType, string> = {
    'osa':         'OSA',
    'claude-code': 'Claude Code',
    'codex':       'Codex',
    'openclaw':    'OpenClaw',
    'jidoclaw':    'JidoClaw',
    'hermes':      'Hermes Agent',
    'bash':        'Bash',
    'http':        'HTTP',
  };

  const TEMPLATE_NAMES: Record<TeamTemplate, string> = {
    'solo':     'Solo Developer',
    'dev-team': 'Dev Team',
    'research': 'Research Lab',
    'custom':   'Custom',
  };

  interface Props {
    displayName: string;
    selectedProviderSlug: string;
    selectedAdapter: AdapterType;
    workspacePath: string;
    teamTemplate: TeamTemplate;
    teamAgents: AgentTemplateData[];
    miosaCloud: boolean;
    isLaunching: boolean;
    onLaunch: () => void;
    onSkip: () => void;
  }

  let {
    displayName,
    selectedProviderSlug,
    selectedAdapter,
    workspacePath,
    teamTemplate,
    teamAgents,
    miosaCloud = $bindable(),
    isLaunching,
    onLaunch,
    onSkip,
  }: Props = $props();

  const currentProvider = $derived(ALL_PROVIDERS.find(p => p.slug === selectedProviderSlug) ?? null);
</script>

<div class="ob-step">
  <div class="ob-step-icon ob-step-icon--ready">
    <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="28" height="28">
      <path d="M4 10l4 4 8-8"/>
    </svg>
  </div>
  <h1 class="ob-title">Ready to Launch</h1>
  <p class="ob-subtitle">Here's your configuration</p>

  <div class="ob-summary">
    <div class="ob-summary-row">
      <span class="ob-summary-key">
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="13" height="13"><circle cx="8" cy="6" r="3"/><path d="M2 14c0-2.761 2.686-5 6-5s6 2.239 6 5"/></svg>
        Name
      </span>
      <span class="ob-summary-val">{displayName || 'Not set'}</span>
    </div>
    <div class="ob-summary-row">
      <span class="ob-summary-key">
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="13" height="13"><path d="M8 2l6 12H2L8 2z"/></svg>
        Provider
      </span>
      <span class="ob-summary-val">
        {#if currentProvider}
          {currentProvider.name}
          {#if currentProvider.noKey}<span class="ob-badge">No key</span>{/if}
        {:else}
          <span class="ob-summary-empty">None selected</span>
        {/if}
      </span>
    </div>
    <div class="ob-summary-row">
      <span class="ob-summary-key">
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="13" height="13"><rect x="2" y="2" width="5" height="5" rx="0.5"/><rect x="9" y="2" width="5" height="5" rx="0.5"/><rect x="2" y="9" width="5" height="5" rx="0.5"/><rect x="9" y="9" width="5" height="5" rx="0.5"/></svg>
        Adapter
      </span>
      <span class="ob-summary-val">{ADAPTER_NAMES[selectedAdapter] ?? selectedAdapter}</span>
    </div>
    <div class="ob-summary-row">
      <span class="ob-summary-key">
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="13" height="13"><path d="M2 4a1 1 0 011-1h2.5L7 4.5H13a1 1 0 011 1V12a1 1 0 01-1 1H3a1 1 0 01-1-1V4z"/></svg>
        Workspace
      </span>
      <span class="ob-summary-val ob-summary-val--mono">{workspacePath}</span>
    </div>
    <div class="ob-summary-row">
      <span class="ob-summary-key">
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="13" height="13"><circle cx="5" cy="5" r="2.5"/><circle cx="11" cy="5" r="2.5"/><path d="M1 13c0-2.209 1.791-4 4-4M11 9c2.209 0 4 1.791 4 4"/><path d="M5 9c2.209 0 4 1.791 4 4H1c0-2.209 1.791-4 4-4z"/></svg>
        Team
      </span>
      <span class="ob-summary-val">
        {TEMPLATE_NAMES[teamTemplate] ?? teamTemplate}
        <span class="ob-summary-count">
          {teamAgents.length === 0 ? '(empty)' : teamAgents.length === 1 ? '(1 agent)' : `(${teamAgents.length} agents)`}
        </span>
      </span>
    </div>
    <div class="ob-summary-row ob-summary-row--toggle">
      <span class="ob-summary-key">
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="13" height="13"><path d="M8 1l7 4v6l-7 4-7-4V5l7-4z"/></svg>
        MIOSA Cloud
      </span>
      <span class="ob-summary-val ob-summary-val--toggle">
        <span class="ob-toggle-hint-text">Firecracker microVM sandboxing</span>
        <button
          class="ob-toggle"
          class:ob-toggle--on={miosaCloud}
          onclick={() => miosaCloud = !miosaCloud}
          role="switch"
          aria-checked={miosaCloud}
          aria-label="Enable MIOSA Cloud sandboxing"
        >
          <span class="ob-toggle-thumb"></span>
        </button>
      </span>
    </div>
  </div>

  <button
    class="ob-btn ob-btn--launch"
    onclick={onLaunch}
    disabled={isLaunching}
    aria-label="Launch Canopy"
  >
    {#if isLaunching}
      <svg class="ob-spinner" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" width="18" height="18"><circle cx="10" cy="10" r="7" stroke-dasharray="22 22" stroke-dashoffset="0"/></svg>
      Launching...
    {:else}
      <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="18" height="18"><path d="M10 3l7 4v6l-7 4-7-4V7l7-4z"/><path d="M10 7v6M7 9l3-2 3 2"/></svg>
      Launch Canopy
    {/if}
  </button>

  <button class="ob-skip-link" onclick={onSkip}>
    Skip setup and launch with defaults
  </button>
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

  .ob-step-icon--ready {
    background: rgba(59, 130, 246, 0.12);
    border-color: rgba(59, 130, 246, 0.3);
    color: #3b82f6;
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

  .ob-badge {
    font-size: 0.625rem;
    font-weight: 600;
    letter-spacing: 0.04em;
    padding: 1px 6px;
    border-radius: 100px;
    background: rgba(255, 255, 255, 0.1);
    color: rgba(255, 255, 255, 0.55);
    border: 1px solid rgba(255, 255, 255, 0.12);
    white-space: nowrap;
  }

  .ob-summary {
    width: 100%;
    background: rgba(255, 255, 255, 0.02);
    border: 1px solid rgba(255, 255, 255, 0.07);
    border-radius: 10px;
    overflow: hidden;
    margin-bottom: 1.5rem;
    text-align: left;
  }

  .ob-summary-row {
    display: flex;
    align-items: center;
    gap: 0.875rem;
    padding: 0.625rem 1rem;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
  }

  .ob-summary-row:last-child {
    border-bottom: none;
  }

  .ob-summary-key {
    display: flex;
    align-items: center;
    gap: 0.375rem;
    font-size: 0.75rem;
    color: rgba(255, 255, 255, 0.35);
    min-width: 100px;
    flex-shrink: 0;
  }

  .ob-summary-val {
    font-size: 0.8125rem;
    color: #d0d0d0;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .ob-summary-val--mono {
    font-family: 'SF Mono', 'Fira Code', monospace;
    font-size: 0.75rem;
    color: rgba(255, 255, 255, 0.55);
  }

  .ob-summary-count {
    font-size: 0.6875rem;
    color: rgba(255, 255, 255, 0.3);
  }

  .ob-summary-empty {
    color: rgba(255, 255, 255, 0.25);
    font-style: italic;
  }

  .ob-summary-on {
    color: #3b82f6;
    font-size: 0.75rem;
  }

  .ob-summary-off {
    color: rgba(255, 255, 255, 0.3);
    font-size: 0.75rem;
  }

  .ob-summary-row--toggle {
    align-items: center;
  }

  .ob-summary-val--toggle {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 0.625rem;
  }

  .ob-toggle-hint-text {
    font-size: 0.6875rem;
    color: rgba(255, 255, 255, 0.28);
  }

  .ob-toggle {
    position: relative;
    width: 40px;
    height: 22px;
    border-radius: 100px;
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid rgba(255, 255, 255, 0.12);
    cursor: pointer;
    transition: background 200ms ease, border-color 200ms ease;
    flex-shrink: 0;
  }

  .ob-toggle--on {
    background: #3b82f6;
    border-color: rgba(59, 130, 246, 0.6);
  }

  .ob-toggle-thumb {
    position: absolute;
    top: 2px;
    left: 2px;
    width: 16px;
    height: 16px;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.5);
    transition: transform 200ms ease, background 200ms ease;
    pointer-events: none;
  }

  .ob-toggle--on .ob-toggle-thumb {
    transform: translateX(18px);
    background: #ffffff;
  }

  .ob-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    border-radius: 9999px;
    font-size: 0.875rem;
    font-weight: 500;
    cursor: pointer;
    border: none;
    padding: 0.625rem 1.25rem;
    transition: background 150ms ease, opacity 150ms ease, transform 150ms ease, box-shadow 150ms ease;
  }

  .ob-btn:disabled {
    opacity: 0.35;
    cursor: not-allowed;
  }

  .ob-btn--launch {
    width: 100%;
    justify-content: center;
    padding: 0.875rem;
    font-size: 1rem;
    font-weight: 600;
    background: linear-gradient(180deg, #1a1a1a 0%, #000000 100%);
    color: #ffffff;
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-radius: 9999px;
    letter-spacing: -0.01em;
    box-shadow:
      0 1px 0 0 rgba(255, 255, 255, 0.1) inset,
      0 4px 16px 0 rgba(0, 0, 0, 0.3),
      0 8px 24px 0 rgba(0, 0, 0, 0.15);
    position: relative;
    overflow: hidden;
  }

  .ob-btn--launch::before {
    content: '';
    position: absolute;
    top: 0; left: 0; right: 0;
    height: 50%;
    background: linear-gradient(180deg, rgba(255, 255, 255, 0.12) 0%, transparent 100%);
    border-radius: inherit;
    pointer-events: none;
  }

  .ob-btn--launch:not(:disabled):hover {
    transform: translateY(-2px);
    background: linear-gradient(180deg, #2a2a2a 0%, #0a0a0a 100%);
    box-shadow:
      0 1px 0 0 rgba(255, 255, 255, 0.15) inset,
      0 6px 24px 0 rgba(0, 0, 0, 0.4),
      0 12px 32px 0 rgba(0, 0, 0, 0.2);
  }

  .ob-skip-link {
    background: none;
    border: none;
    color: rgba(255, 255, 255, 0.25);
    font-size: 0.75rem;
    cursor: pointer;
    padding: 0.5rem 0 0;
    transition: color 150ms ease;
    text-decoration: underline;
    text-underline-offset: 2px;
  }

  .ob-skip-link:hover {
    color: rgba(255, 255, 255, 0.5);
  }

  @keyframes ob-spin {
    from { transform: rotate(0deg); }
    to   { transform: rotate(360deg); }
  }

  .ob-spinner {
    animation: ob-spin 800ms linear infinite;
    opacity: 0.7;
  }
</style>
