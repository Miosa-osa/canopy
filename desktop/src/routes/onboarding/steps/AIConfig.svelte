<script lang="ts">
  import type { AdapterType } from '$lib/stores/onboarding.svelte';

  interface Provider {
    slug: string;
    name: string;
    description: string;
    noKey?: boolean;
    recommended?: boolean;
  }

  const FEATURED_PROVIDERS: Provider[] = [
    { slug: 'anthropic',    name: 'Anthropic',    description: 'Claude — most capable reasoning' },
    { slug: 'ollama-cloud', name: 'Ollama Cloud', description: 'Managed Ollama — zero infra',      recommended: true },
    { slug: 'ollama-local', name: 'Ollama Local', description: 'Run models locally — no key',      noKey: true },
    { slug: 'google',       name: 'Google',       description: 'Gemini — multimodal, long context' },
    { slug: 'groq',         name: 'Groq',         description: 'Ultra-fast inference' },
    { slug: 'deepseek',     name: 'DeepSeek',     description: 'Strong reasoning, low cost' },
  ];

  const MORE_PROVIDERS: Provider[] = [
    { slug: 'mistral',    name: 'Mistral',      description: 'European open-weight models' },
    { slug: 'cohere',     name: 'Cohere',       description: 'Enterprise NLP and embeddings' },
    { slug: 'together',   name: 'Together AI',  description: 'Open-source models at scale' },
    { slug: 'fireworks',  name: 'Fireworks AI', description: 'Fast open-source inference' },
    { slug: 'perplexity', name: 'Perplexity',   description: 'Search-augmented models' },
    { slug: 'cerebras',   name: 'Cerebras',     description: 'Wafer-scale chip inference' },
    { slug: 'sambanova',  name: 'SambaNova',    description: 'Reconfigurable dataflow arch' },
    { slug: 'openrouter', name: 'OpenRouter',   description: 'Unified API for 100+ models' },
    { slug: 'openai',     name: 'OpenAI',       description: 'GPT-4o and o-series models' },
    { slug: 'replicate',  name: 'Replicate',    description: 'Open-source models via API' },
    { slug: 'xai',        name: 'xAI',          description: 'Grok models from xAI' },
    { slug: 'lambda',     name: 'Lambda',       description: 'GPU cloud for AI workloads' },
    { slug: 'lepton',     name: 'Lepton AI',    description: 'Serverless AI inference' },
  ];

  interface AdapterDef {
    id: AdapterType;
    name: string;
    description: string;
    recommended?: boolean;
    useLogoImg?: boolean;
  }

  const ADAPTERS: AdapterDef[] = [
    { id: 'osa',         name: 'OSA',          description: 'Elixir/OTP agent runtime — full orchestration', recommended: true, useLogoImg: true },
    { id: 'claude-code', name: 'Claude Code',  description: "Anthropic's CLI coding agent" },
    { id: 'codex',       name: 'Codex',        description: "OpenAI's autonomous coding agent" },
    { id: 'openclaw',    name: 'OpenClaw',     description: 'Open-source multi-agent framework' },
    { id: 'jidoclaw',    name: 'JidoClaw',     description: 'Elixir-native agent framework' },
    { id: 'hermes',      name: 'Hermes',       description: 'Fast message-passing runtime' },
    { id: 'bash',        name: 'Bash',         description: 'Simple shell script executor' },
    { id: 'http',        name: 'HTTP',         description: 'Generic HTTP/REST adapter' },
  ];

  interface Props {
    selectedProviderSlug: string;
    providerKeys: Record<string, string>;
    selectedAdapter: AdapterType;
    onSkip: () => void;
  }

  let {
    selectedProviderSlug = $bindable(),
    providerKeys = $bindable(),
    selectedAdapter = $bindable(),
    onSkip,
  }: Props = $props();

  let showMoreProviders = $state(false);
  let testState = $state<'idle' | 'testing' | 'ok' | 'fail'>('idle');

  async function testConnection() {
    if (!selectedProviderSlug) return;
    testState = 'testing';
    // Simulate a connection test — in production this would invoke a Tauri command
    await new Promise(r => setTimeout(r, 900));
    const hasKey = FEATURED_PROVIDERS.concat(MORE_PROVIDERS)
      .find(p => p.slug === selectedProviderSlug)?.noKey
      || (providerKeys[selectedProviderSlug] ?? '').trim().length > 0;
    testState = hasKey ? 'ok' : 'fail';
    setTimeout(() => { testState = 'idle'; }, 2500);
  }
</script>

<div class="ob-step">
  <div class="ob-step-icon">
    <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="28" height="28">
      <circle cx="10" cy="10" r="7.5"/>
      <path d="M10 6v4l2.5 2.5"/>
    </svg>
  </div>
  <h1 class="ob-title">AI Configuration</h1>
  <p class="ob-subtitle">Choose your provider and execution adapter</p>

  <!-- Provider section -->
  <div class="ob-section-label">PROVIDER</div>
  <div class="ob-providers">
    {#each FEATURED_PROVIDERS as p}
      {@const isSelected = selectedProviderSlug === p.slug}
      <button
        class="ob-card"
        class:ob-card--selected={isSelected}
        onclick={() => selectedProviderSlug = p.slug}
      >
        <div class="ob-card-header">
          <span class="ob-card-icon">
            {#if p.slug === 'anthropic'}
              <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="15" height="15"><path d="M10 3L17 17H3L10 3z"/></svg>
            {:else if p.slug === 'ollama-cloud' || p.slug === 'ollama-local'}
              <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="15" height="15"><circle cx="10" cy="8" r="4"/><path d="M3 17c0-3.314 3.134-6 7-6s7 2.686 7 6"/></svg>
            {:else if p.slug === 'google'}
              <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="15" height="15"><circle cx="10" cy="10" r="7.5"/><path d="M10 10h4.5M10 10a4.5 4.5 0 100-4.5H10v4.5z"/></svg>
            {:else if p.slug === 'groq'}
              <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="15" height="15"><rect x="3" y="3" width="14" height="14" rx="2"/><path d="M7 10h6M10 7v6"/></svg>
            {:else if p.slug === 'deepseek'}
              <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="15" height="15"><circle cx="10" cy="10" r="3"/><path d="M10 3v2M10 15v2M3 10h2M15 10h2M5.636 5.636l1.414 1.414M12.95 12.95l1.414 1.414M5.636 14.364l1.414-1.414M12.95 7.05l1.414-1.414"/></svg>
            {:else}
              <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="15" height="15"><circle cx="10" cy="10" r="7.5"/><circle cx="10" cy="10" r="3"/></svg>
            {/if}
          </span>
          <span class="ob-card-name">{p.name}</span>
          {#if p.recommended}<span class="ob-badge ob-badge--accent">Recommended</span>{/if}
          {#if p.noKey}<span class="ob-badge">No key</span>{/if}
        </div>
        <p class="ob-card-desc">{p.description}</p>
        {#if isSelected && !p.noKey}
          <div class="ob-key-wrap" onclick={(e) => e.stopPropagation()} role="none">
            <input
              class="ob-key-input"
              type="password"
              placeholder="API key..."
              value={providerKeys[p.slug] ?? ''}
              oninput={(e) => { providerKeys[p.slug] = (e.currentTarget as HTMLInputElement).value; }}
            />
          </div>
        {/if}
      </button>
    {/each}
  </div>

  <button class="ob-show-more" onclick={() => showMoreProviders = !showMoreProviders}>
    <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="13" height="13" style="transform: rotate({showMoreProviders ? 180 : 0}deg); transition: transform 200ms ease">
      <path d="M4 6l4 4 4-4"/>
    </svg>
    {showMoreProviders ? 'Show fewer' : 'More providers'}
  </button>

  {#if showMoreProviders}
    <div class="ob-providers ob-providers--more">
      {#each MORE_PROVIDERS as p}
        {@const isSelected = selectedProviderSlug === p.slug}
        <button
          class="ob-card ob-card--compact"
          class:ob-card--selected={isSelected}
          onclick={() => selectedProviderSlug = p.slug}
        >
          <div class="ob-card-header">
            <span class="ob-card-icon">
              <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="13" height="13"><circle cx="10" cy="10" r="7.5"/><circle cx="10" cy="10" r="3"/></svg>
            </span>
            <span class="ob-card-name">{p.name}</span>
          </div>
          <p class="ob-card-desc">{p.description}</p>
          {#if isSelected}
            <div class="ob-key-wrap" onclick={(e) => e.stopPropagation()} role="none">
              <input
                class="ob-key-input"
                type="password"
                placeholder="API key..."
                value={providerKeys[p.slug] ?? ''}
                oninput={(e) => { providerKeys[p.slug] = (e.currentTarget as HTMLInputElement).value; }}
              />
            </div>
          {/if}
        </button>
      {/each}
    </div>
  {/if}

  <!-- Divider -->
  <div class="ob-divider"></div>

  <!-- Adapter section -->
  <div class="ob-section-label">EXECUTION ADAPTER</div>
  <div class="ob-adapters">
    {#each ADAPTERS as a}
      <button
        class="ob-card ob-card--compact"
        class:ob-card--selected={selectedAdapter === a.id}
        onclick={() => selectedAdapter = a.id}
      >
        <div class="ob-card-header">
          <span class="ob-card-icon">
            {#if a.useLogoImg}
              <img src="/OSAIconLogo.png" alt="OSA" width="15" height="15" style="border-radius:3px;object-fit:contain;" />
            {:else if a.id === 'claude-code'}
              <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="15" height="15"><path d="M6 7l-4 3 4 3M14 7l4 3-4 3M12 5l-4 10"/></svg>
            {:else if a.id === 'codex'}
              <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="15" height="15"><rect x="3" y="5" width="14" height="10" rx="2"/><path d="M7 9l2 2-2 2M11 13h2"/></svg>
            {:else if a.id === 'bash'}
              <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="15" height="15"><rect x="2" y="4" width="16" height="12" rx="2"/><path d="M6 8l3 2-3 2M11 12h3"/></svg>
            {:else if a.id === 'http'}
              <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="15" height="15"><circle cx="10" cy="10" r="7.5"/><path d="M10 2.5c0 0-3.5 3.5-3.5 7.5s3.5 7.5 3.5 7.5M10 2.5c0 0 3.5 3.5 3.5 7.5S10 17.5 10 17.5M2.5 10h15"/></svg>
            {:else}
              <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="15" height="15"><path d="M10 3l7 4v6l-7 4-7-4V7z"/></svg>
            {/if}
          </span>
          <span class="ob-card-name">{a.name}</span>
          {#if a.recommended}<span class="ob-badge ob-badge--accent">Recommended</span>{/if}
        </div>
        <p class="ob-card-desc">{a.description}</p>
      </button>
    {/each}
  </div>

  <!-- Test connection -->
  {#if selectedProviderSlug}
    <button
      class="ob-test-btn"
      class:ob-test-btn--ok={testState === 'ok'}
      class:ob-test-btn--fail={testState === 'fail'}
      onclick={testConnection}
      disabled={testState === 'testing'}
    >
      {#if testState === 'testing'}
        <svg class="ob-spin" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" width="13" height="13"><circle cx="8" cy="8" r="5" stroke-dasharray="16 16"/></svg>
        Testing...
      {:else if testState === 'ok'}
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="13" height="13"><path d="M3 8l3 3 7-7"/></svg>
        Connection OK
      {:else if testState === 'fail'}
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="13" height="13"><path d="M4 4l8 8M12 4l-8 8"/></svg>
        Check your key
      {:else}
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="13" height="13"><path d="M8 3v2M8 11v2M3 8h2M11 8h2M5.05 5.05l1.414 1.414M9.536 9.536l1.414 1.414M5.05 10.95l1.414-1.414M9.536 6.464l1.414-1.414"/></svg>
        Test Connection
      {/if}
    </button>
  {/if}

  <!-- Skip link -->
  <button class="ob-skip-link" onclick={onSkip}>
    Skip for now — configure in settings later
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
    margin: 0 0 1.25rem;
  }

  .ob-section-label {
    font-size: 0.6875rem;
    font-weight: 600;
    letter-spacing: 0.08em;
    color: rgba(255, 255, 255, 0.35);
    margin-bottom: 0.5rem;
    align-self: flex-start;
  }

  .ob-divider {
    width: 100%;
    height: 1px;
    background: rgba(255, 255, 255, 0.06);
    margin: 0.875rem 0;
  }

  /* ─── Provider & adapter grids ────────────────────────────────────── */

  .ob-providers {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.4rem;
    width: 100%;
    margin-bottom: 0.5rem;
  }

  .ob-providers--more {
    grid-template-columns: 1fr 1fr 1fr;
    margin-top: 0.4rem;
  }

  .ob-adapters {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.4rem;
    width: 100%;
    margin-bottom: 0.75rem;
  }

  /* ─── Generic card ────────────────────────────────────────────────── */

  .ob-card {
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.07);
    border-radius: 10px;
    padding: 0.625rem;
    text-align: left;
    cursor: pointer;
    transition: background 150ms ease, border-color 150ms ease;
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
  }

  .ob-card:hover {
    background: rgba(255, 255, 255, 0.06);
    border-color: rgba(255, 255, 255, 0.12);
  }

  .ob-card--selected {
    background: rgba(59, 130, 246, 0.07);
    border-color: rgba(59, 130, 246, 0.4);
  }

  .ob-card--compact {
    padding: 0.5rem 0.625rem;
  }

  .ob-card-header {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    flex-wrap: wrap;
  }

  .ob-card-icon {
    color: rgba(255, 255, 255, 0.5);
    display: flex;
    align-items: center;
    flex-shrink: 0;
  }

  .ob-card-name {
    font-size: 0.8125rem;
    font-weight: 600;
    color: #e0e0e0;
    flex: 1;
  }

  .ob-card-desc {
    font-size: 0.6875rem;
    color: rgba(255, 255, 255, 0.35);
    margin: 0;
    line-height: 1.4;
  }

  /* ─── API key input ───────────────────────────────────────────────── */

  .ob-key-wrap {
    width: 100%;
    padding-top: 0.375rem;
  }

  .ob-key-input {
    width: 100%;
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 7px;
    padding: 0.5rem 0.75rem;
    font-size: 0.8125rem;
    color: #f0f0f0;
    outline: none;
    transition: border-color 150ms ease;
    box-sizing: border-box;
  }

  .ob-key-input::placeholder { color: rgba(255, 255, 255, 0.2); }
  .ob-key-input:focus { border-color: rgba(59, 130, 246, 0.5); }

  /* ─── Badges ──────────────────────────────────────────────────────── */

  .ob-badge {
    font-size: 0.5625rem;
    font-weight: 600;
    letter-spacing: 0.04em;
    padding: 1px 5px;
    border-radius: 100px;
    background: rgba(255, 255, 255, 0.1);
    color: rgba(255, 255, 255, 0.55);
    border: 1px solid rgba(255, 255, 255, 0.12);
    white-space: nowrap;
  }

  .ob-badge--accent {
    background: rgba(59, 130, 246, 0.12);
    color: #3b82f6;
    border-color: rgba(59, 130, 246, 0.25);
  }

  /* ─── Show more ───────────────────────────────────────────────────── */

  .ob-show-more {
    display: flex;
    align-items: center;
    gap: 0.375rem;
    background: none;
    border: none;
    color: rgba(255, 255, 255, 0.4);
    font-size: 0.75rem;
    cursor: pointer;
    padding: 0.25rem 0 0;
    transition: color 150ms ease;
    align-self: flex-start;
  }

  .ob-show-more:hover { color: rgba(255, 255, 255, 0.7); }

  /* ─── Test connection ─────────────────────────────────────────────── */

  .ob-test-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0.45rem 0.875rem;
    border-radius: 9999px;
    border: 1px solid rgba(255, 255, 255, 0.1);
    background: rgba(255, 255, 255, 0.04);
    color: rgba(255, 255, 255, 0.55);
    font-size: 0.75rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 150ms ease;
    align-self: flex-start;
    margin-top: 0.25rem;
  }

  .ob-test-btn:hover:not(:disabled) {
    background: rgba(255, 255, 255, 0.08);
    color: rgba(255, 255, 255, 0.8);
    border-color: rgba(255, 255, 255, 0.18);
  }

  .ob-test-btn--ok {
    border-color: rgba(34, 197, 94, 0.4);
    background: rgba(34, 197, 94, 0.06);
    color: #22c55e;
  }

  .ob-test-btn--fail {
    border-color: rgba(239, 68, 68, 0.4);
    background: rgba(239, 68, 68, 0.06);
    color: #ef4444;
  }

  .ob-test-btn:disabled { opacity: 0.6; cursor: not-allowed; }

  /* ─── Skip link ───────────────────────────────────────────────────── */

  .ob-skip-link {
    background: none;
    border: none;
    color: rgba(255, 255, 255, 0.22);
    font-size: 0.6875rem;
    cursor: pointer;
    padding: 0.625rem 0 0;
    transition: color 150ms ease;
    text-decoration: underline;
    text-underline-offset: 2px;
    align-self: center;
  }

  .ob-skip-link:hover { color: rgba(255, 255, 255, 0.45); }

  /* ─── Spinner ─────────────────────────────────────────────────────── */

  @keyframes aicfg-spin {
    from { transform: rotate(0deg); }
    to   { transform: rotate(360deg); }
  }

  .ob-spin {
    animation: aicfg-spin 800ms linear infinite;
  }
</style>
