<script lang="ts">
  /**
   * New Agent — /agents/new
   * Single-form agent creation. Linear.app aesthetic: dense, monochrome, sharp radii.
   * CSS prefix: na- (NewAgent)
   */
  import {
    type CreateMutationOptions,
    type CreateQueryOptions,
    createMutation,
    createQuery,
    useQueryClient,
  } from '@tanstack/svelte-query';
  import { untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import { goto } from '$app/navigation';
  import { createAgentMutation, type CreateAgentBody } from '$lib/api/queries/agents.js';
  import { runtimeModelsQuery, runtimesQuery } from '$lib/api/queries/runtimes.js';
  import { toolsQuery } from '$lib/api/queries/tools.js';
  import type { Tool } from '$lib/domain/tools/types.js';
  import { TOOL_BUNDLE_GROUPS, categorizeTools } from '$lib/domain/tools/bundles.js';
  import type { AgentCategory } from '$lib/domain/agents/types.js';
  import { AGENT_PRESETS } from '$lib/domain/agents/presets.js';
  import {
    CAPABILITY_PRESETS,
    CAPABILITY_PRESET_META,
    type CapabilityPreset,
    type Capability,
  } from '$lib/domain/agents/config.js';
  import type { AgentDetail } from '$lib/domain/agents/types.js';
  import type { Runtime, RuntimeModel } from '$lib/domain/runtimes/types.js';
  import { toasts } from '$lib/stores/toasts.svelte.js';

  const queryClient = useQueryClient();

  // ── Form state ───────────────────────────────────────────────────────────────

  let name = $state('');
  let slug = $state('');
  let slugEdited = $state(false);
  let emoji = $state('🤖');
  let title = $state('');
  let category = $state<AgentCategory>('engineering');
  let systemPrompt = $state('');
  let selectedRuntime = $state('');
  let selectedModel = $state('');
  let selectedTools = $state<Set<string>>(new Set());
  let heartbeatCron = $state('');
  let advancedOpen = $state(false);
  let selectedCapabilities = $state<Set<Capability>>(new Set());
  let collapsedBundleGroups = $state<Set<string>>(new Set());

  // Validation errors shown on submit attempt
  let submitAttempted = $state(false);

  const nameError = $derived(
    submitAttempted && name.trim().length < 2 ? 'Name must be at least 2 characters.' : ''
  );
  const slugError = $derived(
    submitAttempted && !/^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$/.test(slug.trim())
      ? 'Slug must be lowercase kebab-case (letters, numbers, hyphens).'
      : ''
  );
  const titleError = $derived(
    submitAttempted && title.trim().length === 0 ? 'Title is required.' : ''
  );

  // Auto-derive slug from name unless the user has manually edited it
  $effect(() => {
    if (!slugEdited && name) {
      slug = name
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '')
        .slice(0, 128);
    }
  });

  // ── 19 categories ────────────────────────────────────────────────────────────

  const CATEGORIES: Array<{ value: AgentCategory; label: string }> = [
    { value: 'academic', label: 'Academic' },
    { value: 'creative-content', label: 'Creative Content' },
    { value: 'design', label: 'Design' },
    { value: 'engineering', label: 'Engineering' },
    { value: 'executive', label: 'Executive' },
    { value: 'game-development', label: 'Game Development' },
    { value: 'growth', label: 'Growth' },
    { value: 'marketing', label: 'Marketing' },
    { value: 'operations', label: 'Operations' },
    { value: 'paid-media', label: 'Paid Media' },
    { value: 'product', label: 'Product' },
    { value: 'project-management', label: 'Project Management' },
    { value: 'revenue', label: 'Revenue' },
    { value: 'sales', label: 'Sales' },
    { value: 'spatial-computing', label: 'Spatial Computing' },
    { value: 'specialized', label: 'Specialized' },
    { value: 'support', label: 'Support' },
    { value: 'technology', label: 'Technology' },
    { value: 'testing', label: 'Testing' },
  ];

  // ── Runtime data ─────────────────────────────────────────────────────────────

  const runtimesQ = createQuery<Runtime[]>(
    writable(runtimesQuery() as CreateQueryOptions<Runtime[]>)
  );

  const runtimes = $derived(($runtimesQ.data ?? []) as Runtime[]);

  // When runtimes load, default to first available runtime
  $effect(() => {
    if (runtimes.length > 0 && !selectedRuntime) {
      selectedRuntime = runtimes[0].type;
    }
  });

  const modelsOptsStore = writable(
    untrack(() => runtimeModelsQuery(selectedRuntime) as CreateQueryOptions<RuntimeModel[]>)
  );

  $effect(() => {
    modelsOptsStore.set(runtimeModelsQuery(selectedRuntime) as CreateQueryOptions<RuntimeModel[]>);
  });

  const modelsQ = createQuery<RuntimeModel[]>(modelsOptsStore);
  const models = $derived(($modelsQ.data ?? []) as RuntimeModel[]);

  // When models load, pre-select the default model
  $effect(() => {
    const defaultModel = models.find((m) => m.isDefault);
    if (defaultModel && !selectedModel) {
      selectedModel = defaultModel.id;
    } else if (models.length > 0 && !selectedModel) {
      selectedModel = models[0].id;
    }
  });

  // Reset model selection when runtime changes
  $effect(() => {
    // Track selectedRuntime; reset model
    selectedRuntime;
    selectedModel = '';
  });

  // ── Tools data ───────────────────────────────────────────────────────────────

  const toolsQ = createQuery<Tool[]>(
    writable(toolsQuery() as CreateQueryOptions<Tool[]>)
  );
  const toolsList = $derived(($toolsQ.data ?? []) as Tool[]);

  function toggleTool(name: string): void {
    const next = new Set(selectedTools);
    if (next.has(name)) {
      next.delete(name);
    } else {
      next.add(name);
    }
    selectedTools = next;
  }

  // ── Tool bundle helpers ───────────────────────────────────────────────────────

  const categorized = $derived(categorizeTools(toolsList, TOOL_BUNDLE_GROUPS));

  function selectAll(): void {
    selectedTools = new Set(toolsList.map((t) => t.name));
  }

  function clearAll(): void {
    selectedTools = new Set();
  }

  function selectBundle(bundleId: string): void {
    const group = TOOL_BUNDLE_GROUPS.flatMap((g) => g.bundles).find((b) => b.id === bundleId);
    if (!group) return;
    const next = new Set(selectedTools);
    const available = new Set(toolsList.map((t) => t.name));
    for (const toolName of group.tools) {
      if (available.has(toolName)) next.add(toolName);
    }
    selectedTools = next;
  }

  function toggleBundleGroup(groupId: string): void {
    const next = new Set(collapsedBundleGroups);
    if (next.has(groupId)) {
      next.delete(groupId);
    } else {
      next.add(groupId);
    }
    collapsedBundleGroups = next;
  }

  // ── Capability preset helpers ─────────────────────────────────────────────────

  const PRESET_ORDER: CapabilityPreset[] = ['observer', 'reviewer', 'developer', 'admin'];

  function applyCapabilityPreset(preset: CapabilityPreset): void {
    selectedCapabilities = new Set(CAPABILITY_PRESETS[preset]);
    // Auto-select tool bundles that match this preset
    const next = new Set(selectedTools);
    const available = new Set(toolsList.map((t) => t.name));
    for (const group of TOOL_BUNDLE_GROUPS) {
      for (const bundle of group.bundles) {
        if (bundle.suggestedCapabilities === preset) {
          for (const toolName of bundle.tools) {
            if (available.has(toolName)) next.add(toolName);
          }
        }
      }
    }
    selectedTools = next;
  }

  // ── Preset chips ─────────────────────────────────────────────────────────────

  function applyPreset(index: number): void {
    const preset = AGENT_PRESETS[index];
    if (!preset) return;
    systemPrompt = preset.systemPrompt;
    category = preset.category;
  }

  // ── Mutation ─────────────────────────────────────────────────────────────────

  const createMut = createMutation<AgentDetail, Error, CreateAgentBody>(
    createAgentMutation() as CreateMutationOptions<AgentDetail, Error, CreateAgentBody>
  );

  function handleSubmit(): void {
    submitAttempted = true;
    if (nameError || slugError || titleError) return;

    const body: CreateAgentBody = {
      slug: slug.trim(),
      name: name.trim(),
      category,
      description: title.trim() || undefined,
      persona_markdown: systemPrompt || undefined,
      default_runtime: selectedRuntime || undefined,
      default_model: selectedModel || undefined,
      tools: selectedTools.size > 0 ? Array.from(selectedTools) : undefined,
      heartbeat_cron: heartbeatCron.trim() || undefined,
    };

    $createMut.mutate(body, {
      onSuccess: (agent) => {
        queryClient.invalidateQueries({ queryKey: ['agents'] });
        toasts.show(`Agent "${agent.name}" created.`, 'success');
        goto(`/agents/${agent.slug}`);
      },
      onError: (err) => {
        toasts.show(err.message ?? 'Failed to create agent.', 'error');
      },
    });
  }
</script>

<div class="na-page">
  <div class="na-form-wrap">

    <!-- Page header -->
    <header class="na-page-header">
      <h1 class="na-page-title">New Agent</h1>
    </header>

    <!-- ── Identity section ──────────────────────────────────────────────── -->
    <section class="na-section">
      <h2 class="na-section-label">Identity</h2>

      <div class="na-field-row">
        <!-- Emoji -->
        <div class="na-field na-field--emoji">
          <label class="na-label" for="agent-emoji">Emoji</label>
          <input
            id="agent-emoji"
            class="na-input na-input--emoji"
            type="text"
            maxlength="2"
            bind:value={emoji}
            aria-label="Agent emoji"
          />
        </div>

        <!-- Name -->
        <div class="na-field na-field--grow">
          <label class="na-label" for="agent-name">Name <span class="na-required" aria-hidden="true">*</span></label>
          <input
            id="agent-name"
            class="na-input"
            class:na-input--error={!!nameError}
            type="text"
            placeholder="e.g. My Sales Agent"
            bind:value={name}
            aria-required="true"
            aria-describedby={nameError ? 'name-err' : undefined}
          />
          {#if nameError}
            <span id="name-err" class="na-field-error" role="alert">{nameError}</span>
          {/if}
        </div>
      </div>

      <!-- Title -->
      <div class="na-field">
        <label class="na-label" for="agent-title">Title <span class="na-required" aria-hidden="true">*</span></label>
        <input
          id="agent-title"
          class="na-input"
          class:na-input--error={!!titleError}
          type="text"
          placeholder="e.g. Senior Sales Development Representative"
          bind:value={title}
          aria-required="true"
          aria-describedby={titleError ? 'title-err' : undefined}
        />
        {#if titleError}
          <span id="title-err" class="na-field-error" role="alert">{titleError}</span>
        {/if}
      </div>

      <!-- Slug -->
      <div class="na-field">
        <label class="na-label" for="agent-slug">Slug <span class="na-required" aria-hidden="true">*</span></label>
        <input
          id="agent-slug"
          class="na-input na-input--mono"
          class:na-input--error={!!slugError}
          type="text"
          placeholder="my-sales-agent"
          bind:value={slug}
          oninput={() => { slugEdited = true; }}
          aria-required="true"
          aria-describedby="slug-preview"
        />
        <span id="slug-preview" class="na-slug-preview">/agents/{slug || '…'}</span>
        {#if slugError}
          <span class="na-field-error" role="alert">{slugError}</span>
        {/if}
      </div>

      <!-- Category -->
      <div class="na-field">
        <label class="na-label" for="agent-category">Category</label>
        <select id="agent-category" class="na-select" bind:value={category}>
          {#each CATEGORIES as cat (cat.value)}
            <option value={cat.value}>{cat.label}</option>
          {/each}
        </select>
      </div>
    </section>

    <!-- ── System Prompt section ─────────────────────────────────────────── -->
    <section class="na-section">
      <h2 class="na-section-label">System Prompt</h2>

      <!-- Preset chips -->
      <div class="na-presets" role="group" aria-label="Preset system prompts">
        {#each AGENT_PRESETS as preset, i (preset.label)}
          <button
            type="button"
            class="btn-pill btn-pill-ghost btn-pill-sm na-preset-chip"
            onclick={() => applyPreset(i)}
            title="Fill with {preset.label} prompt"
          >
            {preset.label}
          </button>
        {/each}
      </div>

      <textarea
        id="agent-system-prompt"
        class="na-textarea"
        rows={8}
        placeholder="Describe what this agent does and how it should behave…"
        bind:value={systemPrompt}
        aria-label="System prompt"
      ></textarea>
    </section>

    <!-- ── Runtime section ──────────────────────────────────────────────── -->
    <section class="na-section">
      <h2 class="na-section-label">AI Runtime</h2>

      {#if $runtimesQ.isLoading}
        <p class="na-loading-hint">Loading runtimes…</p>
      {:else if runtimes.length === 0}
        <p class="na-loading-hint">No runtimes detected. Install a runtime adapter first.</p>
      {:else}
        <div class="na-radio-cards" role="radiogroup" aria-label="Select AI runtime">
          {#each runtimes as rt (rt.type)}
            <label
              class="na-radio-card"
              class:na-radio-card--selected={selectedRuntime === rt.type}
            >
              <input
                type="radio"
                name="runtime"
                value={rt.type}
                bind:group={selectedRuntime}
                class="na-radio-hidden"
                aria-label={rt.name}
              />
              <span class="na-radio-card__name">{rt.name}</span>
              <span class="na-radio-card__desc">{rt.version ?? rt.type}</span>
            </label>
          {/each}
        </div>
      {/if}
    </section>

    <!-- ── Model section (shown only when runtime is selected + models loaded) -->
    {#if selectedRuntime && models.length > 0}
      <section class="na-section">
        <h2 class="na-section-label">Model</h2>

        <div class="na-radio-cards" role="radiogroup" aria-label="Select model">
          {#each models as model (model.id)}
            <label
              class="na-radio-card"
              class:na-radio-card--selected={selectedModel === model.id}
            >
              <input
                type="radio"
                name="model"
                value={model.id}
                bind:group={selectedModel}
                class="na-radio-hidden"
                aria-label={model.name}
              />
              <span class="na-radio-card__name">{model.name}</span>
              <span class="na-radio-card__desc">
                {model.contextWindow != null
                  ? `${(model.contextWindow / 1000).toFixed(0)}K context`
                  : model.provider}
                {model.isDefault ? ' · default' : ''}
              </span>
            </label>
          {/each}
        </div>
      </section>
    {:else if selectedRuntime && $modelsQ.isLoading}
      <section class="na-section">
        <h2 class="na-section-label">Model</h2>
        <p class="na-loading-hint">Loading models…</p>
      </section>
    {/if}

    <!-- ── Tools section ────────────────────────────────────────────────── -->
    {#if toolsList.length > 0}
      <section class="na-section">
        <div class="na-tools-header">
          <h2 class="na-section-label">Tools <span class="na-optional-label">(optional)</span></h2>
          <div class="na-tools-global-controls">
            <button type="button" class="btn-pill btn-pill-ghost btn-pill-sm na-preset-chip" onclick={selectAll}>
              Select all
            </button>
            <button type="button" class="btn-pill btn-pill-ghost btn-pill-sm na-preset-chip" onclick={clearAll}>
              Clear all
            </button>
            <span class="na-tools-count">{selectedTools.size} / {toolsList.length}</span>
          </div>
        </div>

        <!-- Bundled groups -->
        {#each TOOL_BUNDLE_GROUPS as group (group.id)}
          {@const groupTools = categorized.bundled.get(group.id) ?? []}
          {#if groupTools.length > 0}
            {@const isCollapsed = collapsedBundleGroups.has(group.id)}
            <div class="na-bundle-group">
              <div class="na-bundle-group-header">
                <button
                  type="button"
                  class="na-bundle-group-toggle"
                  onclick={() => toggleBundleGroup(group.id)}
                  aria-expanded={!isCollapsed}
                >
                  <span class="na-bundle-group-arrow" class:na-bundle-group-arrow--open={!isCollapsed}>▶</span>
                  {group.label}
                  <span class="na-bundle-group-count">({groupTools.length})</span>
                </button>
                {#each group.bundles as bundle (bundle.id)}
                  {@const bundleTools = categorized.bundled.get(bundle.id) ?? []}
                  {#if bundleTools.length > 0}
                    <button
                      type="button"
                      class="btn-pill btn-pill-ghost btn-pill-sm na-preset-chip"
                      onclick={() => selectBundle(bundle.id)}
                      title={bundle.description}
                    >
                      + {bundle.name}
                    </button>
                  {/if}
                {/each}
              </div>
              {#if !isCollapsed}
                <div class="na-tool-chips" role="group" aria-label="Tools in {group.label}">
                  {#each groupTools as tool (tool.name)}
                    <button
                      type="button"
                      class="btn-pill btn-pill-sm na-tool-chip"
                      class:na-tool-chip--active={selectedTools.has(tool.name)}
                      onclick={() => toggleTool(tool.name)}
                      aria-pressed={selectedTools.has(tool.name)}
                      title={tool.description ?? tool.name}
                    >
                      {tool.name}
                    </button>
                  {/each}
                </div>
              {/if}
            </div>
          {/if}
        {/each}

        <!-- Unbundled / Other tools -->
        {#if categorized.unbundled.length > 0}
          <div class="na-bundle-group">
            <div class="na-bundle-group-header">
              <span class="na-bundle-group-label">Other tools</span>
            </div>
            <div class="na-tool-chips" role="group" aria-label="Other tools">
              {#each categorized.unbundled as tool (tool.name)}
                <button
                  type="button"
                  class="btn-pill btn-pill-sm na-tool-chip"
                  class:na-tool-chip--active={selectedTools.has(tool.name)}
                  onclick={() => toggleTool(tool.name)}
                  aria-pressed={selectedTools.has(tool.name)}
                  title={tool.description ?? tool.name}
                >
                  {tool.name}
                </button>
              {/each}
            </div>
          </div>
        {/if}
      </section>
    {/if}

    <!-- ── Advanced disclosure ──────────────────────────────────────────── -->
    <section class="na-section">
      <button
        type="button"
        class="na-advanced-toggle"
        onclick={() => { advancedOpen = !advancedOpen; }}
        aria-expanded={advancedOpen}
      >
        <span class="na-advanced-toggle__arrow" class:na-advanced-toggle__arrow--open={advancedOpen}>▶</span>
        Advanced
      </button>

      {#if advancedOpen}
        <div class="na-advanced-body">
          <!-- Capability presets -->
          <div class="na-field">
            <span class="na-label">Capability preset</span>
            <div class="na-presets" role="group" aria-label="Capability presets">
              {#each PRESET_ORDER as preset (preset)}
                {@const meta = CAPABILITY_PRESET_META[preset]}
                <button
                  type="button"
                  class="btn-pill btn-pill-ghost btn-pill-sm na-preset-chip"
                  class:na-preset-chip--active={CAPABILITY_PRESETS[preset].length === selectedCapabilities.size &&
                    CAPABILITY_PRESETS[preset].every((c) => selectedCapabilities.has(c))}
                  onclick={() => applyCapabilityPreset(preset)}
                  title={meta.description}
                >
                  {meta.label}
                </button>
              {/each}
            </div>
            <span class="na-hint">Presets set capability permissions and auto-select matching tool bundles.</span>
          </div>

          <!-- Heartbeat cron -->
          <div class="na-field">
            <label class="na-label" for="agent-cron">Heartbeat cron <span class="na-optional-label">(optional)</span></label>
            <input
              id="agent-cron"
              class="na-input na-input--mono"
              type="text"
              placeholder="*/5 * * * *"
              bind:value={heartbeatCron}
            />
            <span class="na-hint">Cron expression for scheduled heartbeats, e.g. <code>*/5 * * * *</code></span>
          </div>
        </div>
      {/if}
    </section>

    <!-- Spacer so sticky bar doesn't clip last field -->
    <div class="na-bottom-spacer" aria-hidden="true"></div>
  </div>

  <!-- ── Sticky submit bar ──────────────────────────────────────────────── -->
  <div class="na-submit-bar" role="group" aria-label="Form actions">
    <button
      type="button"
      class="btn-pill btn-pill-secondary btn-pill-sm"
      onclick={() => goto('/agents')}
      disabled={$createMut.isPending}
    >
      Cancel
    </button>
    <button
      type="button"
      class="btn-pill btn-pill-primary btn-pill-sm"
      onclick={handleSubmit}
      disabled={$createMut.isPending}
      aria-busy={$createMut.isPending}
    >
      {$createMut.isPending ? 'Creating…' : 'Create agent'}
    </button>
  </div>
</div>

<style>
  /* ── Layout ──────────────────────────────────────────────────────────── */

  .na-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
    position: relative;
  }

  .na-form-wrap {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-6);
    padding-bottom: calc(var(--space-6) + 56px); /* room for sticky bar */
  }

  .na-page-header {
    max-width: 720px;
    margin: 0 auto var(--space-6);
    padding-bottom: var(--space-4);
    border-bottom: 1px solid var(--border);
  }

  .na-page-title {
    font-family: var(--font-sans);
    font-size: var(--text-xl);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
    letter-spacing: -0.02em;
  }

  /* ── Sections ─────────────────────────────────────────────────────────── */

  .na-section {
    max-width: 720px;
    margin: 0 auto var(--space-8);
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  .na-section-label {
    font-family: var(--font-sans);
    font-size: 13px;
    font-weight: 500;
    color: var(--fg);
    margin: 0;
    padding-bottom: var(--space-1);
  }

  /* ── Fields ───────────────────────────────────────────────────────────── */

  .na-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .na-field-row {
    display: flex;
    gap: var(--space-3);
    align-items: flex-end;
  }

  .na-field--emoji {
    flex-shrink: 0;
  }

  .na-field--grow {
    flex: 1;
  }

  .na-label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    color: var(--fg-muted);
  }

  .na-required {
    color: var(--fg-muted);
    margin-left: 2px;
  }

  /* ── Inputs ───────────────────────────────────────────────────────────── */

  .na-input,
  .na-select,
  .na-textarea {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm, 4px);
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    transition: border-color 0.1s var(--ease-out, ease);
    width: 100%;
    box-sizing: border-box;
  }

  .na-input:focus,
  .na-select:focus,
  .na-textarea:focus {
    border-color: var(--cnp-accent, oklch(0.55 0.18 250));
    box-shadow: 0 0 0 2px color-mix(in oklch, var(--cnp-accent, oklch(0.55 0.18 250)) 20%, transparent);
  }

  .na-input::placeholder,
  .na-textarea::placeholder {
    color: var(--fg-subtle);
  }

  .na-input--error {
    border-color: oklch(0.55 0.18 25);
  }

  .na-input--emoji {
    width: 52px;
    text-align: center;
    font-size: var(--text-lg);
    padding: var(--space-1) var(--space-2);
  }

  .na-input--mono {
    font-family: var(--font-mono, ui-monospace, monospace);
    font-size: 12px;
  }

  .na-textarea {
    resize: vertical;
    min-height: 180px;
    font-family: var(--font-mono, ui-monospace, monospace);
    font-size: 12px;
    line-height: 1.6;
  }

  .na-select {
    appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%23888' d='M6 8L1 3h10z'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right var(--space-3) center;
    padding-right: calc(var(--space-3) + 20px);
    cursor: pointer;
  }

  /* ── Slug preview ─────────────────────────────────────────────────────── */

  .na-slug-preview {
    font-family: var(--font-mono, ui-monospace, monospace);
    font-size: 11px;
    color: var(--fg-subtle);
    padding-left: 2px;
  }

  /* ── Field hints / errors ─────────────────────────────────────────────── */

  .na-hint {
    font-size: 11px;
    color: var(--fg-subtle);
  }

  .na-hint code {
    font-family: var(--font-mono, ui-monospace, monospace);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: 3px;
    padding: 0 3px;
  }

  .na-field-error {
    font-size: 11px;
    color: oklch(0.55 0.18 25);
  }

  .na-optional-label {
    font-size: 11px;
    font-weight: 400;
    color: var(--fg-subtle);
    text-transform: none;
    letter-spacing: 0;
  }

  .na-loading-hint {
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  /* ── Preset chips ─────────────────────────────────────────────────────── */

  .na-presets {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-1);
  }

  .na-preset-chip {
    background: transparent;
    border: 1px solid var(--border);
    color: var(--fg-muted);
    font-size: 11px;
    cursor: pointer;
  }

  .na-preset-chip:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  /* ── Radio cards (runtime + model) ───────────────────────────────────── */

  .na-radio-cards {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-2);
  }

  .na-radio-hidden {
    position: absolute;
    opacity: 0;
    width: 0;
    height: 0;
    pointer-events: none;
  }

  .na-radio-card {
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding: var(--space-3) var(--space-4);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm, 4px);
    cursor: pointer;
    min-width: 140px;
    transition: border-color 0.1s var(--ease-out, ease);
    position: relative;
  }

  .na-radio-card:hover {
    border-color: var(--border-strong);
  }

  .na-radio-card--selected {
    border: 2px solid var(--cnp-accent, oklch(0.55 0.18 250));
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.55 0.18 250)) 6%, var(--bg-inset));
  }

  .na-radio-card__name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
  }

  .na-radio-card__desc {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-muted);
  }

  /* ── Tool chips ───────────────────────────────────────────────────────── */

  .na-tool-chips {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-1);
  }

  .na-tool-chip {
    background: transparent;
    border: 1px solid var(--border);
    color: var(--fg-muted);
    font-size: 11px;
    cursor: pointer;
  }

  .na-tool-chip:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    color: var(--fg);
  }

  .na-tool-chip--active {
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.55 0.18 250)) 12%, transparent);
    border-color: var(--cnp-accent, oklch(0.55 0.18 250));
    color: var(--fg);
  }

  /* ── Tools section — bundle layout ───────────────────────────────────── */

  .na-tools-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
  }

  .na-tools-global-controls {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
  }

  .na-tools-count {
    font-size: 11px;
    color: var(--fg-subtle);
    white-space: nowrap;
  }

  .na-bundle-group {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .na-bundle-group-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-wrap: wrap;
  }

  .na-bundle-group-toggle {
    display: flex;
    align-items: center;
    gap: 5px;
    background: none;
    border: none;
    padding: 0;
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    color: var(--fg-muted);
    transition: color 0.1s;
  }

  .na-bundle-group-toggle:hover {
    color: var(--fg);
  }

  .na-bundle-group-label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    color: var(--fg-muted);
  }

  .na-bundle-group-arrow {
    font-size: 8px;
    display: inline-block;
    transition: transform 0.12s var(--ease-out, ease);
  }

  .na-bundle-group-arrow--open {
    transform: rotate(90deg);
  }

  .na-bundle-group-count {
    font-size: 10px;
    color: var(--fg-subtle);
    font-weight: 400;
    text-transform: none;
    letter-spacing: 0;
  }

  .na-preset-chip--active {
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.55 0.18 250)) 12%, transparent);
    border-color: var(--cnp-accent, oklch(0.55 0.18 250));
    color: var(--fg);
  }

  /* ── Advanced disclosure ──────────────────────────────────────────────── */

  .na-advanced-toggle {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    background: none;
    border: none;
    padding: 0;
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg-muted);
    transition: color 0.1s;
  }

  .na-advanced-toggle:hover {
    color: var(--fg);
  }

  .na-advanced-toggle__arrow {
    font-size: 9px;
    transition: transform 0.15s var(--ease-out, ease);
    display: inline-block;
  }

  .na-advanced-toggle__arrow--open {
    transform: rotate(90deg);
  }

  .na-advanced-body {
    padding-top: var(--space-2);
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  /* ── Sticky submit bar ────────────────────────────────────────────────── */

  .na-bottom-spacer {
    height: 64px;
  }

  .na-submit-bar {
    position: sticky;
    bottom: 0;
    left: 0;
    right: 0;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-6);
    background: var(--bg);
    border-top: 1px solid var(--border);
    z-index: 10;
  }
</style>
