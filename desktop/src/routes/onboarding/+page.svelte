<script lang="ts">
  import { goto } from '$app/navigation';
  import { onboardingStore } from '$lib/stores/onboarding.svelte';
  import type { AdapterType, TeamTemplate, AgentTemplateData } from '$lib/stores/onboarding.svelte';
  import { isTauri } from '$lib/utils/platform';
  import Welcome from './steps/Welcome.svelte';
  import Provider from './steps/Provider.svelte';
  import Adapter from './steps/Adapter.svelte';
  import Workspace from './steps/Workspace.svelte';
  import Team from './steps/Team.svelte';
  import MiosaCloud from './steps/MiosaCloud.svelte';
  import Review from './steps/Review.svelte';

  // ─── Shared state ─────────────────────────────────────────────────────────

  let step = $state(onboardingStore.currentStep);

  let displayName        = $state(onboardingStore.data.displayName);
  let selectedProviderSlug = $state(onboardingStore.data.provider?.slug ?? '');
  let providerKeys       = $state<Record<string, string>>({});
  let selectedAdapter    = $state<AdapterType>(onboardingStore.data.adapter);
  let workspacePath      = $state(onboardingStore.data.workspace?.path ?? '~/.canopy');
  let workspaceName      = $state(onboardingStore.data.workspace?.name ?? 'My Workspace');
  let workspaceDesc      = $state(onboardingStore.data.workspace?.description ?? '');
  let teamTemplate       = $state<TeamTemplate>(onboardingStore.data.teamTemplate ?? 'dev-team');
  let miosaCloud         = $state(onboardingStore.data.miosaCloud);
  let isLaunching        = $state(false);

  // Initialize API key from stored provider
  $effect(() => {
    if (onboardingStore.data.provider) {
      providerKeys[onboardingStore.data.provider.slug] = onboardingStore.data.provider.apiKey;
    }
  });

  // ─── Template data ────────────────────────────────────────────────────────

  const TEMPLATE_AGENTS: Record<TeamTemplate, AgentTemplateData[]> = {
    solo: [
      { id: 'main-agent', name: 'Main Agent', emoji: 'bot', role: 'engineer', adapter: 'osa', skills: ['code', 'debug', 'test'], system_prompt: 'You are a skilled software engineer...' },
    ],
    'dev-team': [
      { id: 'orchestrator',    name: 'Orchestrator',    emoji: 'brain',  role: 'orchestrator', adapter: 'osa', skills: ['delegate', 'plan'],      system_prompt: 'You coordinate a development team...' },
      { id: 'code-worker',     name: 'Code Worker',     emoji: 'code',   role: 'developer',    adapter: 'osa', skills: ['code', 'debug'],          system_prompt: 'You are a focused code implementation specialist...' },
      { id: 'research-worker', name: 'Research Worker', emoji: 'search', role: 'researcher',   adapter: 'osa', skills: ['web_search', 'analyze'],  system_prompt: 'You research solutions, APIs, and best practices...' },
      { id: 'qa-agent',        name: 'QA Agent',        emoji: 'shield', role: 'engineer',     adapter: 'osa', skills: ['test', 'validate'],       system_prompt: 'You ensure code quality through testing...' },
    ],
    research: [
      { id: 'lead-researcher', name: 'Lead Researcher', emoji: 'search', role: 'researcher', adapter: 'osa', skills: ['web_search', 'analyze', 'summarize'], system_prompt: 'You lead research investigations...' },
      { id: 'data-analyst',    name: 'Data Analyst',    emoji: 'chart',  role: 'researcher', adapter: 'osa', skills: ['analyze', 'visualize'],              system_prompt: 'You analyze data and produce insights...' },
      { id: 'writer',          name: 'Writer',          emoji: 'pen',    role: 'writer',     adapter: 'osa', skills: ['write', 'edit', 'format'],            system_prompt: 'You produce clear, well-structured written content...' },
    ],
    custom: [],
  };

  // ─── Derived ──────────────────────────────────────────────────────────────

  const teamAgents = $derived(TEMPLATE_AGENTS[teamTemplate]);

  // $derived evaluates to a boolean directly so Svelte tracks every reactive
  // read (step, selectedProviderSlug, providerKeys, workspacePath) and
  // recomputes whenever any of them change.
  const canContinue = $derived((() => {
    if (step === 1) {
      if (!selectedProviderSlug) return false;
      const allProviders = [
        { slug: 'anthropic' }, { slug: 'ollama-cloud' }, { slug: 'ollama-local', noKey: true },
        { slug: 'google' }, { slug: 'groq' }, { slug: 'deepseek' }, { slug: 'mistral' },
        { slug: 'cohere' }, { slug: 'together' }, { slug: 'fireworks' }, { slug: 'perplexity' },
        { slug: 'cerebras' }, { slug: 'sambanova' }, { slug: 'openrouter' }, { slug: 'openai' },
        { slug: 'replicate' }, { slug: 'xai' }, { slug: 'lambda' }, { slug: 'lepton' },
      ];
      const prov = allProviders.find(p => p.slug === selectedProviderSlug);
      if (!prov) return false;
      if ((prov as { noKey?: boolean }).noKey) return true;
      return (providerKeys[selectedProviderSlug] ?? '').trim().length > 0;
    }
    if (step === 3) return workspacePath.trim().length > 0;
    return true;
  })());

  // ─── Navigation ───────────────────────────────────────────────────────────

  function next() {
    if (!canContinue) return;
    syncToStore();
    onboardingStore.nextStep();
    step = onboardingStore.currentStep;
  }

  function prev() {
    onboardingStore.prevStep();
    step = onboardingStore.currentStep;
  }

  function syncToStore() {
    onboardingStore.updateData({
      displayName,
      provider: selectedProviderSlug
        ? { slug: selectedProviderSlug, apiKey: providerKeys[selectedProviderSlug] ?? '', verified: false }
        : null,
      adapter: selectedAdapter,
      workspace: { path: workspacePath, name: workspaceName, description: workspaceDesc },
      teamTemplate,
      agents: TEMPLATE_AGENTS[teamTemplate],
      miosaCloud,
    });
  }

  // ─── Import callback from Welcome step ────────────────────────────────────

  function handleImport(result: {
    workspacePath: string;
    workspaceName: string;
    adapter: AdapterType;
    teamTemplate: TeamTemplate;
    agents: AgentTemplateData[];
    jumpToStep: number;
  }) {
    if (result.workspacePath) workspacePath = result.workspacePath;
    if (result.workspaceName) workspaceName = result.workspaceName;
    selectedAdapter = result.adapter;
    teamTemplate = result.teamTemplate;
    if (result.agents.length > 0) {
      onboardingStore.updateData({ agents: result.agents });
    }
    onboardingStore.updateData({
      displayName,
      workspace: { path: workspacePath, name: workspaceName, description: workspaceDesc },
      adapter: selectedAdapter,
      teamTemplate,
    });
    step = result.jumpToStep;
    onboardingStore.goToStep(result.jumpToStep);
  }

  // ─── Launch ───────────────────────────────────────────────────────────────

  async function launch() {
    if (isLaunching) return;
    isLaunching = true;
    syncToStore();

    try {
      if (isTauri() && workspacePath.trim()) {
        const { invoke } = await import('@tauri-apps/api/core');
        const agents = TEMPLATE_AGENTS[teamTemplate].map(a => ({
          id: a.id,
          name: a.name,
          emoji: a.emoji,
          role: a.role,
          adapter: a.adapter,
          model: a.model ?? null,
          skills: a.skills,
          system_prompt: a.system_prompt ?? null,
        }));

        try {
          await invoke('scaffold_canopy_dir', {
            path: workspacePath,
            name: workspaceName,
            description: workspaceDesc || null,
            agents,
          });
        } catch (e) {
          console.warn('Scaffold warning:', e);
        }

        const { workspaceStore } = await import('$lib/stores/workspace.svelte');
        const wsEntry = {
          id: crypto.randomUUID(),
          path: workspacePath,
          name: workspaceName,
          description: workspaceDesc,
          addedAt: new Date().toISOString(),
        };
        workspaceStore.addWorkspace(wsEntry);
        await workspaceStore.setActiveWorkspace(wsEntry.id);
      }

      onboardingStore.complete();
      if (typeof localStorage !== 'undefined') {
        localStorage.setItem('canopy-onboarding-complete', 'true');
        localStorage.setItem('canopy-display-name', displayName);
        localStorage.setItem('canopy-default-adapter', selectedAdapter);
        if (selectedProviderSlug) {
          localStorage.setItem('canopy-provider-slug', selectedProviderSlug);
          const key = providerKeys[selectedProviderSlug];
          if (key) localStorage.setItem(`canopy-provider-${selectedProviderSlug}`, key);
        }
      }

      if (isTauri() && selectedProviderSlug) {
        const { Store } = await import('@tauri-apps/plugin-store');
        const credStore = await Store.load('credentials.json');
        await credStore.set('provider', {
          slug: selectedProviderSlug,
          apiKey: providerKeys[selectedProviderSlug] ?? '',
        });
        await credStore.save();
      }

      if (isTauri()) {
        const { Store } = await import('@tauri-apps/plugin-store');
        const settStore = await Store.load('settings.json');
        await settStore.set('default_adapter', selectedAdapter);
        await settStore.set('miosa_cloud', miosaCloud);
        await settStore.save();
      }

      goto('/app');
    } catch (e) {
      console.error('Launch failed:', e);
      isLaunching = false;
    }
  }

  function skip() {
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem('canopy-onboarding-complete', 'true');
    }
    onboardingStore.complete();
    goto('/app');
  }
</script>

<div class="ob-root">
  <!-- Progress dots -->
  <div class="ob-dots">
    {#each { length: 7 } as _, i}
      <button
        class="ob-dot"
        class:ob-dot--active={i === step}
        class:ob-dot--done={i < step}
        onclick={() => { if (i <= step) { step = i; onboardingStore.goToStep(i); } }}
        aria-label="Step {i + 1}"
      ></button>
    {/each}
  </div>

  <!-- Step content card -->
  <div class="ob-card">
    {#if step === 0}
      <Welcome bind:displayName onImport={handleImport} />
    {:else if step === 1}
      <Provider bind:selectedProviderSlug bind:providerKeys />
    {:else if step === 2}
      <Adapter bind:selectedAdapter />
    {:else if step === 3}
      <Workspace bind:workspacePath bind:workspaceName bind:workspaceDesc />
    {:else if step === 4}
      <Team bind:teamTemplate />
    {:else if step === 5}
      <MiosaCloud bind:miosaCloud />
    {:else if step === 6}
      <Review
        {displayName}
        {selectedProviderSlug}
        {selectedAdapter}
        {workspacePath}
        {teamTemplate}
        {teamAgents}
        {miosaCloud}
        {isLaunching}
        onLaunch={launch}
        onSkip={skip}
      />
    {/if}
  </div>

  <!-- Navigation -->
  {#if step < 6}
    <div class="ob-nav" class:ob-nav--center={step === 0}>
      {#if step > 0}
        <button
          class="ob-btn ob-btn--secondary"
          onclick={prev}
          aria-label="Go back"
        >
          <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="14" height="14"><path d="M10 4L6 8l4 4"/></svg>
          Back
        </button>
      {/if}
      <button
        class="ob-btn ob-btn--primary"
        onclick={next}
        disabled={!canContinue}
        aria-label="Continue to next step"
      >
        {step === 0 ? 'Get Started' : 'Continue'}
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="14" height="14"><path d="M6 4l4 4-4 4"/></svg>
      </button>
    </div>
  {:else}
    <div class="ob-nav ob-nav--center">
      <button
        class="ob-btn ob-btn--secondary"
        onclick={prev}
        aria-label="Go back"
      >
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="14" height="14"><path d="M10 4L6 8l4 4"/></svg>
        Back
      </button>
    </div>
  {/if}
</div>

<style>
  /* ─── Root & layout ─────────────────────────────────────────────────── */

  .ob-root {
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 2rem 1rem;
    background: #0a0a0a;
    color: #f0f0f0;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
  }

  /* ─── Progress dots ──────────────────────────────────────────────────── */

  .ob-dots {
    display: flex;
    gap: 6px;
    margin-bottom: 1.5rem;
  }

  .ob-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.15);
    border: none;
    padding: 0;
    cursor: pointer;
    transition: background 200ms ease, transform 200ms ease;
  }

  .ob-dot--active {
    background: #3b82f6;
    transform: scale(1.3);
  }

  .ob-dot--done {
    background: rgba(59, 130, 246, 0.45);
  }

  /* ─── Card ───────────────────────────────────────────────────────────── */

  .ob-card {
    width: 100%;
    max-width: 560px;
    background: rgba(255, 255, 255, 0.06);
    backdrop-filter: blur(24px);
    -webkit-backdrop-filter: blur(24px);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 20px;
    box-shadow:
      0 8px 32px rgba(0, 0, 0, 0.12),
      0 2px 8px rgba(0, 0, 0, 0.08),
      inset 0 1px 0 rgba(255, 255, 255, 0.1);
    padding: 2rem;
    min-height: 340px;
    display: flex;
    flex-direction: column;
  }

  /* ─── Navigation ─────────────────────────────────────────────────────── */

  .ob-nav {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    max-width: 560px;
    margin-top: 1rem;
  }

  .ob-nav--center {
    justify-content: center;
  }

  /* ─── Buttons ────────────────────────────────────────────────────────── */

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

  .ob-btn--primary {
    background: linear-gradient(180deg, #1a1a1a 0%, #000000 100%);
    color: #ffffff;
    border: 1px solid rgba(255, 255, 255, 0.1);
    box-shadow:
      0 1px 0 0 rgba(255, 255, 255, 0.1) inset,
      0 4px 16px 0 rgba(0, 0, 0, 0.3);
    position: relative;
    overflow: hidden;
  }

  .ob-btn--primary::before {
    content: '';
    position: absolute;
    top: 0; left: 0; right: 0;
    height: 50%;
    background: linear-gradient(180deg, rgba(255, 255, 255, 0.15) 0%, transparent 100%);
    border-radius: inherit;
    pointer-events: none;
  }

  .ob-btn--primary:not(:disabled):hover {
    transform: translateY(-1px);
    background: linear-gradient(180deg, #2a2a2a 0%, #0a0a0a 100%);
    box-shadow:
      0 1px 0 0 rgba(255, 255, 255, 0.15) inset,
      0 6px 24px 0 rgba(0, 0, 0, 0.4);
  }

  .ob-btn--secondary {
    background: rgba(255, 255, 255, 0.05);
    backdrop-filter: blur(10px);
    -webkit-backdrop-filter: blur(10px);
    color: #a1a1a6;
    border: 1px solid rgba(255, 255, 255, 0.1);
    box-shadow: 0 1px 0 0 rgba(255, 255, 255, 0.04) inset;
  }

  .ob-btn--secondary:not(:disabled):hover {
    background: rgba(255, 255, 255, 0.1);
    border-color: rgba(255, 255, 255, 0.15);
  }
</style>
