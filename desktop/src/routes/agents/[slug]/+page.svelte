<script lang="ts">
  /**
   * Agent configuration studio — /agents/:slug
   * Tabbed layout with 9 tabs. Sub-components handle each panel.
   * CSS prefix: ads- (AgentDetailStudio)
   *
   * Backend contracts confirmed:
   *   LIVE: GET /agents/:slug, PUT /agents/:slug/persona, POST/DELETE /agents/:slug/hire
   *         GET /skills, GET /knowledge-bases, GET /tools, GET /governance/rules, GET /budgets
   *         GET /sessions?agent_slug=
   *   STASH (localStorage draft): PATCH /agents/:slug/config (capabilities, guardrails, skill assignments)
   *         KB assignment endpoint exists (POST/DELETE /knowledge-bases/:slug/assignments) — wired live.
   */

  import {
    type CreateMutationOptions,
    type CreateQueryOptions,
    createMutation,
    createQuery,
    useQueryClient,
  } from '@tanstack/svelte-query';
  import { AlertCircle } from 'lucide-svelte';
  import { untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import { beforeNavigate, goto } from '$app/navigation';
  import { page } from '$app/state';

  // Queries
  import {
    agentDetailQuery,
    agentSessionsQuery,
    fireAgentMutation,
    hireAgentMutation,
    updatePersonaMutation,
  } from '$lib/api/queries/agents.js';
  import { skillsQuery } from '$lib/api/queries/skills.js';
  import { createSession } from '$lib/api/queries/sessions.js';
  import { knowledgeBasesQuery, assignAgentMutation, unassignAgentMutation } from '$lib/api/queries/knowledge.js';
  import { toolsQuery } from '$lib/api/queries/tools.js';
  import { rulesQuery } from '$lib/api/queries/governance.js';
  import { budgetsQuery, type Budget } from '$lib/api/queries/budgets.js';

  // Patterns
  import AgentHeader from '$lib/design/patterns/agent-detail/AgentHeader.svelte';
  import PersonaEditor from '$lib/design/patterns/agent-detail/PersonaEditor.svelte';
  import SkillsPanel from '$lib/design/patterns/agent-detail/SkillsPanel.svelte';
  import CapabilitiesPanel from '$lib/design/patterns/agent-detail/CapabilitiesPanel.svelte';
  import GuardrailsPanel from '$lib/design/patterns/agent-detail/GuardrailsPanel.svelte';
  import KnowledgeBasesPanel from '$lib/design/patterns/agent-detail/KnowledgeBasesPanel.svelte';
  import AgentToolsList from '$lib/design/patterns/agent-detail/AgentToolsList.svelte';
  import AgentSessionsList from '$lib/design/patterns/agent-detail/AgentSessionsList.svelte';
  import EmptyState from '$lib/design/patterns/EmptyState.svelte';
  import AgentLiveCard from '$lib/design/patterns/AgentLiveCard.svelte';
  import DirtyGuardModal from '$lib/design/patterns/DirtyGuardModal.svelte';
  import { Breadcrumb, BreadcrumbItem } from '$lib/design/foundation/breadcrumb';

  // Domain
  import type { Agent, AgentDetail, HireAgentBody } from '$lib/domain/agents/types.js';
  import type { Skill } from '$lib/domain/skills/types.js';
  import type { KnowledgeBase } from '$lib/domain/knowledge/types.js';
  import type { Tool } from '$lib/domain/tools/types.js';
  import type { Rule } from '$lib/domain/governance/types.js';
  import type { Session } from '$lib/domain/sessions/types.js';
  import {
    type Capability,
    type AgentGuardrails,
    type AgentConfig,
    DEFAULT_AGENT_CONFIG,
  } from '$lib/domain/agents/config.js';
  import { kanbanBoards } from '$lib/stores/kanban-boards.svelte.js';
  import { toasts } from '$lib/stores/toasts.svelte.js';

  const queryClient = useQueryClient();
  const slug = $derived(page.params.slug ?? '');

  // ── Agent detail query ────────────────────────────────────────────────────────
  const agentOptsStore = writable(
    untrack(() => agentDetailQuery(slug) as CreateQueryOptions<AgentDetail>),
  );
  $effect(() => {
    agentOptsStore.set(agentDetailQuery(slug) as CreateQueryOptions<AgentDetail>);
  });
  const agentQ = createQuery<AgentDetail>(agentOptsStore);
  const agent = $derived(($agentQ.data ?? null) as AgentDetail | null);
  const hired = $derived(agent?.hired === true);

  // ── Supporting queries ────────────────────────────────────────────────────────
  const skillsQ = createQuery<Skill[]>(writable(skillsQuery() as CreateQueryOptions<Skill[]>));
  const basesQ = createQuery<KnowledgeBase[]>(
    writable(knowledgeBasesQuery() as CreateQueryOptions<KnowledgeBase[]>),
  );
  const toolsQ = createQuery<Tool[]>(writable(toolsQuery() as CreateQueryOptions<Tool[]>));
  const rulesQ = createQuery<Rule[]>(writable(rulesQuery() as CreateQueryOptions<Rule[]>));
  const budgetsQ = createQuery<Budget[]>(writable(budgetsQuery() as CreateQueryOptions<Budget[]>));

  const sessionsOptsStore = writable(
    untrack(() => agentSessionsQuery(slug) as CreateQueryOptions<Session[]>),
  );
  $effect(() => {
    sessionsOptsStore.set(agentSessionsQuery(slug) as CreateQueryOptions<Session[]>);
  });
  const sessionsQ = createQuery<Session[]>(sessionsOptsStore);

  // ── Mutations ─────────────────────────────────────────────────────────────────
  const hireMut = createMutation<Agent, Error, { slug: string; body?: HireAgentBody }>(
    hireAgentMutation() as CreateMutationOptions<Agent, Error, { slug: string; body?: HireAgentBody }>,
  );
  const fireMut = createMutation<void, Error, string>(
    fireAgentMutation() as CreateMutationOptions<void, Error, string>,
  );
  const personaMut = createMutation<AgentDetail, Error, { slug: string; personaMarkdown: string }>(
    updatePersonaMutation() as CreateMutationOptions<AgentDetail, Error, { slug: string; personaMarkdown: string }>,
  );
  const assignKbMut = createMutation<unknown, Error, { slug: string; agentSlug: string }>(
    assignAgentMutation() as CreateMutationOptions<unknown, Error, { slug: string; agentSlug: string }>,
  );
  const unassignKbMut = createMutation<unknown, Error, { slug: string; agentSlug: string }>(
    unassignAgentMutation() as CreateMutationOptions<unknown, Error, { slug: string; agentSlug: string }>,
  );

  function invalidateAgent() {
    queryClient.invalidateQueries({ queryKey: ['agents', slug] });
  }

  // ── Tab state ─────────────────────────────────────────────────────────────────
  type Tab =
    | 'overview'
    | 'config'
    | 'persona'
    | 'skills'
    | 'capabilities'
    | 'knowledge'
    | 'guardrails'
    | 'tools'
    | 'sessions'
    | 'kanban';

  const TABS: Array<{ id: Tab; label: string }> = [
    { id: 'overview', label: 'Overview' },
    { id: 'config', label: 'Config' },
    { id: 'persona', label: 'Persona' },
    { id: 'skills', label: 'Skills' },
    { id: 'capabilities', label: 'Capabilities' },
    { id: 'knowledge', label: 'Knowledge' },
    { id: 'guardrails', label: 'Guardrails' },
    { id: 'tools', label: 'Tools' },
    { id: 'sessions', label: 'Sessions' },
  ];

  let activeTab = $state<Tab>('overview');

  // ── Local config draft (capabilities, guardrails, skills) ─────────────────────
  // Stashed in localStorage because PATCH /agents/:slug/config does not exist yet.
  const LS_KEY = $derived(`canopy:agent-config:${slug}`);
  let localConfig = $state<AgentConfig>({ ...DEFAULT_AGENT_CONFIG });
  let configIsLocalDraft = $state(false);

  interface LocalAgentDraft {
    name: string;
    title: string;
    defaultRuntime: string;
    budget: string;
    heartbeatCron: string;
    contextTier: string;
    skillsText: string;
    toolsText: string;
  }

  let hydratedSlug = $state('');
  let draft = $state<LocalAgentDraft>({
    name: '',
    title: '',
    defaultRuntime: '',
    budget: '',
    heartbeatCron: '',
    contextTier: 'l1',
    skillsText: '',
    toolsText: '',
  });

  function splitList(value: string): string[] {
    return value
      .split(/[\n,]/)
      .map((item) => item.trim())
      .filter(Boolean);
  }

  function configString(agentConfig: Record<string, unknown> | undefined, key: string): string {
    const value = agentConfig?.[key];
    return typeof value === 'string' ? value : '';
  }

  function configList(agentConfig: Record<string, unknown> | undefined, key: string): string[] {
    const value = agentConfig?.[key];
    if (Array.isArray(value)) return value.map(String).filter(Boolean);
    if (typeof value === 'string') return splitList(value);
    return [];
  }

  function draftStorageKey(currentSlug = slug): string {
    return `canopy:agent-draft:${currentSlug}`;
  }

  function loadAgentDraft(currentAgent: AgentDetail) {
    let saved: Partial<LocalAgentDraft> = {};
    try {
      const raw = localStorage.getItem(draftStorageKey(currentAgent.slug));
      if (raw) saved = JSON.parse(raw) as Partial<LocalAgentDraft>;
    } catch {
      saved = {};
    }

    draft = {
      name: saved.name ?? currentAgent.name ?? '',
      title: saved.title ?? currentAgent.title ?? '',
      defaultRuntime: saved.defaultRuntime ?? currentAgent.defaultRuntime ?? '',
      budget: saved.budget ?? (currentAgent.budget != null ? String(currentAgent.budget) : ''),
      heartbeatCron: saved.heartbeatCron ?? currentAgent.heartbeatCron ?? '',
      contextTier: (saved.contextTier ?? currentAgent.contextTier ?? configString(currentAgent.config, 'context_tier')) || 'l1',
      skillsText: saved.skillsText ?? (currentAgent.skills ?? configList(currentAgent.config, 'skills')).join('\n'),
      toolsText: saved.toolsText ?? (currentAgent.tools ?? configList(currentAgent.config, 'tools')).join('\n'),
    };
  }

  function saveAgentDraft(showToast = true) {
    if (!agent) return;
    try {
      localStorage.setItem(draftStorageKey(agent.slug), JSON.stringify(draft));
      if (showToast) toasts.success('Agent config saved locally.');
    } catch {
      toasts.error('Failed to save agent config.');
    }
  }

  $effect(() => {
    if (agent && hydratedSlug !== agent.slug) {
      hydratedSlug = agent.slug;
      loadAgentDraft(agent);
    }
  });

  const effectiveAgent = $derived.by<AgentDetail | null>(() => {
    if (!agent) return null;
    return {
      ...agent,
      name: draft.name.trim() || agent.name,
      title: draft.title.trim() || agent.title,
      defaultRuntime: draft.defaultRuntime.trim() || agent.defaultRuntime,
      budget: draft.budget.trim() ? Number(draft.budget) : agent.budget,
      heartbeatCron: draft.heartbeatCron.trim() || agent.heartbeatCron,
      contextTier: (draft.contextTier.trim() || agent.contextTier) as AgentDetail['contextTier'],
      skills: splitList(draft.skillsText),
      tools: splitList(draft.toolsText),
    };
  });

  const agentTools = $derived(effectiveAgent?.tools ?? []);
  const agentSkills = $derived(effectiveAgent?.skills ?? []);
  const sourcePath = $derived(
    typeof agent?.config?.workspace_path === 'string'
      ? `${agent.config.workspace_slug ?? 'workspace'}/${agent.config.workspace_path}`
      : agent?.personaPath ?? 'Database persona'
  );
  const isWorkspaceAgent = $derived(agent?.config?.source === 'workspace' || agent?.personaPath?.startsWith('workspace:'));

  function loadLocalConfig() {
    try {
      const raw = localStorage.getItem(LS_KEY);
      if (raw) {
        localConfig = { ...DEFAULT_AGENT_CONFIG, ...(JSON.parse(raw) as Partial<AgentConfig>) };
        configIsLocalDraft = true;
      }
    } catch {
      // ignore parse errors
    }
  }

  function saveLocalConfig(next: Partial<AgentConfig>) {
    localConfig = { ...localConfig, ...next };
    try {
      localStorage.setItem(LS_KEY, JSON.stringify(localConfig));
      configIsLocalDraft = true;
    } catch {
      toasts.error('Failed to save local draft.');
    }
  }

  $effect(() => {
    // Re-load when slug changes
    slug;
    loadLocalConfig();
  });

  // ── KB assigned slugs (derived from bases + agent_count heuristic) ───────────
  // The KB list includes agent_count but not which agents. We track assignments
  // optimistically in localConfig.kb_slugs and call the real endpoint.
  const assignedKbSlugs = $derived(localConfig.kb_slugs);

  function handleAssignKb(kbSlug: string) {
    $assignKbMut.mutate(
      { slug: kbSlug, agentSlug: slug },
      {
        onSuccess: () => {
          saveLocalConfig({ kb_slugs: [...localConfig.kb_slugs, kbSlug] });
          queryClient.invalidateQueries({ queryKey: ['knowledge-bases'] });
          toasts.success('Knowledge base assigned.');
        },
        onError: (err) => toasts.error(err.message ?? 'Assignment failed.'),
      },
    );
  }

  function handleUnassignKb(kbSlug: string) {
    $unassignKbMut.mutate(
      { slug: kbSlug, agentSlug: slug },
      {
        onSuccess: () => {
          saveLocalConfig({ kb_slugs: localConfig.kb_slugs.filter((s) => s !== kbSlug) });
          queryClient.invalidateQueries({ queryKey: ['knowledge-bases'] });
          toasts.success('Knowledge base unassigned.');
        },
        onError: (err) => toasts.error(err.message ?? 'Unassignment failed.'),
      },
    );
  }

  // ── Dirty guard (Persona tab only — other tabs save immediately) ───────────────
  let guardOpen = $state(false);
  let bypassGuard = $state(false);
  let pendingNavigation: (() => void) | null = null;
  let personaIsDirty = $state(false);

  beforeNavigate(({ cancel, to }) => {
    if (personaIsDirty && !bypassGuard) {
      cancel();
      pendingNavigation = () => {
        bypassGuard = true;
        if (to?.url) window.location.assign(to.url.href);
      };
      guardOpen = true;
    }
  });

  // ── Kanban deep-link ──────────────────────────────────────────────────────────
  function openAgentKanban() {
    let board = kanbanBoards.boards.find(
      (b) => b.scope.type === 'agent' && b.scope.agentId === slug,
    );
    if (!board) {
      board = kanbanBoards.createBoard(`${agent?.name ?? slug} tasks`, { type: 'agent', agentId: slug });
    } else {
      kanbanBoards.setActive(board.id);
    }
    goto(`/tasks?board=${board.id}`);
  }

  // ── Persona save ──────────────────────────────────────────────────────────────
  function savePersona(systemPrompt: string, _traits: string[]) {
    $personaMut.mutate(
      { slug, personaMarkdown: systemPrompt },
      {
        onSuccess: () => {
          invalidateAgent();
          toasts.success('Persona saved.');
          personaIsDirty = false;
          // Also stash traits locally
          saveLocalConfig({ persona_traits: _traits });
        },
        onError: (err) => toasts.error(err.message ?? 'Save failed.'),
      },
    );
  }

  async function runAgent() {
    if (!agent) return;
    try {
      const session = await createSession({
        agentSlug: slug,
        runtimeType: effectiveAgent?.defaultRuntime ?? agent.defaultRuntime ?? 'claude-local',
        cwd: '~',
        kind: 'agent_conversation',
        prompt: `Run ${effectiveAgent?.name ?? agent.name}.`,
      }) as { id?: string; sessionId?: string };
      const sessionId = session.id ?? session.sessionId;
      if (!sessionId) throw new Error('Session started, but the backend did not return a session id.');
      await goto(`/sessions/${sessionId}`);
    } catch (err) {
      toasts.error(err instanceof Error ? err.message : 'Failed to start agent run.');
    }
  }
</script>

<div class="ads-page">
  {#if $agentQ.isLoading}
    <div class="ads-skeleton" aria-live="polite" aria-label="Loading agent">
      <div class="sk sk--avatar"></div>
      <div class="sk sk--title"></div>
      <div class="sk sk--body"></div>
    </div>
  {:else if $agentQ.isError || !effectiveAgent}
    <EmptyState
      icon={AlertCircle as never}
      title="Agent not found"
      body="This agent doesn't exist or couldn't be loaded."
      action="Back to agents"
      onAction={() => goto('/agents')}
    />
  {:else}
    <!-- Top bar: breadcrumb -->
    <header class="ads-topbar">
      <Breadcrumb>
        <BreadcrumbItem href="/agents">Agents</BreadcrumbItem>
        <BreadcrumbItem>{effectiveAgent.name}</BreadcrumbItem>
      </Breadcrumb>
    </header>

    <!-- Agent header (always visible) -->
    <AgentHeader
      agent={effectiveAgent}
      {hired}
      onHire={() => $hireMut.mutate({ slug }, { onSuccess: invalidateAgent })}
      onFire={() => $fireMut.mutate(slug, { onSuccess: invalidateAgent })}
      onRun={runAgent}
      onKanban={openAgentKanban}
      hireIsPending={$hireMut.isPending}
      fireIsPending={$fireMut.isPending}
    />

    <!-- Tab bar -->
    <div class="ads-tabs" role="tablist" aria-label="Agent configuration tabs">
      {#each TABS as tab (tab.id)}
        <button
          class="ads-tab"
          class:ads-tab--active={activeTab === tab.id}
          role="tab"
          aria-selected={activeTab === tab.id}
          aria-controls="ads-panel-{tab.id}"
          onclick={() => (activeTab = tab.id)}
        >
          {tab.label}
        </button>
      {/each}
    </div>

    <!-- Tab panels -->
    <div class="ads-body">

      <!-- Overview -->
      {#if activeTab === 'overview'}
        <div class="ads-panel" id="ads-panel-overview" role="tabpanel" aria-label="Overview">
          <div class="ads-overview">
            <section class="ads-overview-section">
              <h3 class="ads-overview-label">About</h3>
              <p class="ads-overview-bio">{effectiveAgent.bio}</p>
            </section>
            <section class="ads-overview-section">
              <h3 class="ads-overview-label">Configuration</h3>
              <dl class="ads-meta">
                <div class="ads-meta-row">
                  <dt>Source</dt>
                  <dd class="ads-mono">{sourcePath}</dd>
                </div>
                <div class="ads-meta-row">
                  <dt>Default runtime</dt>
                  <dd>{effectiveAgent.defaultRuntime ?? '—'}</dd>
                </div>
                <div class="ads-meta-row">
                  <dt>Context tier</dt>
                  <dd class="ads-mono">{effectiveAgent.contextTier ?? '—'}</dd>
                </div>
                <div class="ads-meta-row">
                  <dt>Heartbeat</dt>
                  <dd class="ads-mono">{effectiveAgent.heartbeatCron ?? 'none'}</dd>
                </div>
                <div class="ads-meta-row">
                  <dt>Run count</dt>
                  <dd>{effectiveAgent.runCount}</dd>
                </div>
                <div class="ads-meta-row">
                  <dt>Budget</dt>
                  <dd>{effectiveAgent.budget != null ? `$${effectiveAgent.budget}/mo` : '—'}</dd>
                </div>
              </dl>
            </section>
            {#if agentTools.length > 0}
              <section class="ads-overview-section">
                <h3 class="ads-overview-label">Tools</h3>
                <div class="ads-chips">
                  {#each agentTools as tool (tool)}
                    <span class="ads-chip">{tool}</span>
                  {/each}
                </div>
              </section>
            {/if}
            {#if agentSkills.length > 0}
              <section class="ads-overview-section">
                <h3 class="ads-overview-label">Skills</h3>
                <div class="ads-chips">
                  {#each agentSkills as skill (skill)}
                    <span class="ads-chip">{skill}</span>
                  {/each}
                </div>
              </section>
            {/if}
          </div>
        </div>

      <!-- Config -->
      {:else if activeTab === 'config'}
        <div class="ads-panel ads-panel--scroll" id="ads-panel-config" role="tabpanel" aria-label="Config">
          <div class="ads-config">
            <section class="ads-config-card">
              <div class="ads-config-head">
                <div>
                  <h3 class="ads-config-title">Agent Identity</h3>
                  <p class="ads-config-sub">
                    {isWorkspaceAgent
                      ? 'Permanent config comes from the .canopy agent frontmatter. Persona saves write back to that markdown file.'
                      : 'This legacy agent is database-backed. Config changes are kept as a local draft until a backend config endpoint is added.'}
                  </p>
                </div>
                <button class="ads-save-btn" onclick={() => saveAgentDraft()} aria-label="Save agent config">
                  Save Config
                </button>
              </div>

              <div class="ads-form-grid">
                <label class="ads-field">
                  <span>Name</span>
                  <input class="ads-input" bind:value={draft.name} />
                </label>
                <label class="ads-field">
                  <span>Title</span>
                  <input class="ads-input" bind:value={draft.title} />
                </label>
                <label class="ads-field">
                  <span>Runtime</span>
                  <select class="ads-input" bind:value={draft.defaultRuntime}>
                    <option value="">Default</option>
                    <option value="claude-local">Claude Code</option>
                    <option value="codex-local">Codex</option>
                    <option value="gemini-local">Gemini</option>
                    <option value="bash">Bash</option>
                  </select>
                </label>
                <label class="ads-field">
                  <span>Context Tier</span>
                  <select class="ads-input" bind:value={draft.contextTier}>
                    <option value="l0">L0 catalog</option>
                    <option value="l1">L1 manifest</option>
                    <option value="l2">L2 full context</option>
                  </select>
                </label>
                <label class="ads-field">
                  <span>Budget / month</span>
                  <input class="ads-input" type="number" min="0" step="1" bind:value={draft.budget} />
                </label>
                <label class="ads-field">
                  <span>Heartbeat Cron</span>
                  <input class="ads-input" placeholder="*/30 * * * *" bind:value={draft.heartbeatCron} />
                </label>
              </div>

              <div class="ads-config-columns">
                <label class="ads-field">
                  <span>Skills</span>
                  <textarea class="ads-textarea" rows="8" bind:value={draft.skillsText} placeholder="strategy/plan&#10;content/write&#10;analysis/stats"></textarea>
                </label>
                <label class="ads-field">
                  <span>Tools</span>
                  <textarea class="ads-textarea" rows="8" bind:value={draft.toolsText} placeholder="read_files&#10;write_files&#10;exec_shell"></textarea>
                </label>
              </div>
            </section>
          </div>
        </div>

      <!-- Persona -->
      {:else if activeTab === 'persona'}
        <div class="ads-panel ads-panel--scroll" id="ads-panel-persona" role="tabpanel" aria-label="Persona">
          <PersonaEditor
            agent={effectiveAgent}
            onSave={savePersona}
            isSaving={$personaMut.isPending}
          />
        </div>

      <!-- Skills -->
      {:else if activeTab === 'skills'}
        <div class="ads-panel ads-panel--scroll" id="ads-panel-skills" role="tabpanel" aria-label="Skills">
          {#if (($skillsQ.data ?? []) as Skill[]).length > 0}
            <SkillsPanel
              agentSlug={slug}
              skills={($skillsQ.data ?? []) as Skill[]}
              isLoading={$skillsQ.isLoading}
            />
          {:else}
            <div class="ads-config">
              <section class="ads-config-card">
                <div class="ads-config-head">
                  <div>
                    <h3 class="ads-config-title">Skills</h3>
                    <p class="ads-config-sub">No registry skills are available, so this agent uses editable local skill slugs.</p>
                  </div>
                  <button class="ads-save-btn" onclick={() => saveAgentDraft()} aria-label="Save agent skills">
                    Save Skills
                  </button>
                </div>
                <label class="ads-field">
                  <span>Skill slugs</span>
                  <textarea class="ads-textarea" rows="12" bind:value={draft.skillsText} placeholder="strategy/plan&#10;content/write&#10;analysis/stats"></textarea>
                </label>
              </section>
            </div>
          {/if}
        </div>

      <!-- Capabilities -->
      {:else if activeTab === 'capabilities'}
        <div class="ads-panel ads-panel--scroll" id="ads-panel-capabilities" role="tabpanel" aria-label="Capabilities">
          <CapabilitiesPanel
            enabled={localConfig.capabilities as Capability[]}
            onChange={(caps) => saveLocalConfig({ capabilities: caps })}
            isLocalDraft={configIsLocalDraft}
          />
        </div>

      <!-- Knowledge bases -->
      {:else if activeTab === 'knowledge'}
        <div class="ads-panel ads-panel--scroll" id="ads-panel-knowledge" role="tabpanel" aria-label="Knowledge bases">
          <KnowledgeBasesPanel
            agentSlug={slug}
            bases={($basesQ.data ?? []) as KnowledgeBase[]}
            isLoading={$basesQ.isLoading}
            assignedSlugs={assignedKbSlugs}
            onAssign={handleAssignKb}
            onUnassign={handleUnassignKb}
            isPending={$assignKbMut.isPending || $unassignKbMut.isPending}
          />
        </div>

      <!-- Guardrails -->
      {:else if activeTab === 'guardrails'}
        <div class="ads-panel ads-panel--scroll" id="ads-panel-guardrails" role="tabpanel" aria-label="Guardrails">
          <GuardrailsPanel
            guardrails={localConfig.guardrails as AgentGuardrails}
            budgets={($budgetsQ.data ?? []) as Budget[]}
            rules={($rulesQ.data ?? []) as Rule[]}
            budgetsLoading={$budgetsQ.isLoading}
            rulesLoading={$rulesQ.isLoading}
            onChange={(g) => saveLocalConfig({ guardrails: g })}
            isLocalDraft={configIsLocalDraft}
          />
        </div>

      <!-- Tools -->
      {:else if activeTab === 'tools'}
        <div class="ads-panel ads-panel--scroll" id="ads-panel-tools" role="tabpanel" aria-label="Tools">
          <AgentToolsList
            tools={($toolsQ.data ?? []) as Tool[]}
            isLoading={$toolsQ.isLoading}
            capabilities={localConfig.capabilities as Capability[]}
          />
        </div>

      <!-- Sessions -->
      {:else if activeTab === 'sessions'}
        <div class="ads-panel ads-panel--scroll" id="ads-panel-sessions" role="tabpanel" aria-label="Sessions">
          <AgentSessionsList
            sessions={($sessionsQ.data ?? []) as Session[]}
            isLoading={$sessionsQ.isLoading}
            agentSlug={slug}
          />
        </div>
      {/if}
    </div>
  {/if}
</div>

<DirtyGuardModal
  open={guardOpen}
  onCancel={() => { guardOpen = false; pendingNavigation = null; }}
  onDiscard={() => { guardOpen = false; pendingNavigation?.(); pendingNavigation = null; }}
/>

<style>
  .ads-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  /* Live banner */
  .ads-live-banner {
    position: sticky;
    top: 0;
    z-index: 10;
    padding: var(--space-2) var(--space-5);
    background: var(--bg);
    border-bottom: 1px solid transparent;
  }

  /* Top bar */
  .ads-topbar {
    display: flex;
    align-items: center;
    padding: var(--space-3) var(--space-5);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  /* Tab nav */
  .ads-tabs {
    display: flex;
    align-items: center;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    overflow-x: auto;
    padding: 0 var(--space-5);
    gap: 0;
    scrollbar-width: none;
  }

  .ads-tabs::-webkit-scrollbar {
    display: none;
  }

  .ads-tab {
    padding: var(--space-2) var(--space-4);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg-muted);
    background: transparent;
    border: none;
    border-bottom: 2px solid transparent;
    cursor: pointer;
    white-space: nowrap;
    margin-bottom: -1px;
    transition: color 0.1s, border-color 0.1s;
  }

  .ads-tab:hover {
    color: var(--fg);
  }

  .ads-tab--active {
    color: var(--fg);
    border-bottom-color: var(--cnp-accent, oklch(0.55 0.18 250));
  }

  /* Body / panel area */
  .ads-body {
    flex: 1;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .ads-panel {
    flex: 1;
    overflow: hidden;
  }

  .ads-panel--scroll {
    overflow-y: auto;
  }

  /* Overview content */
  .ads-overview {
    display: flex;
    flex-direction: column;
    gap: var(--space-6);
    padding: var(--space-6);
    max-width: 700px;
  }

  .ads-overview-section {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .ads-overview-label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    margin: 0;
    padding-bottom: var(--space-1);
    border-bottom: 1px solid var(--border);
  }

  .ads-overview-bio {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    line-height: 1.6;
    margin: 0;
  }

  .ads-meta {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    margin: 0;
    padding: 0;
  }

  .ads-meta-row {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: var(--space-3);
  }

  .ads-meta-row dt {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    flex-shrink: 0;
  }

  .ads-meta-row dd {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
    text-align: right;
  }

  .ads-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs) !important;
  }

  .ads-chips {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
  }

  .ads-chip {
    display: inline-flex;
    padding: 2px 8px;
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    border-radius: 9999px;
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-muted);
    border: 1px solid var(--border);
  }

  /* Config editor */
  .ads-config {
    padding: var(--space-5);
    max-width: 960px;
  }

  .ads-config-card {
    display: flex;
    flex-direction: column;
    gap: var(--space-5);
    padding: var(--space-5);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    background: color-mix(in oklch, var(--fg) 3%, transparent);
  }

  .ads-config-head {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: var(--space-4);
    border-bottom: 1px solid var(--border);
    padding-bottom: var(--space-4);
  }

  .ads-config-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-base);
    font-weight: 600;
    color: var(--fg);
  }

  .ads-config-sub {
    margin: var(--space-1) 0 0;
    max-width: 620px;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    line-height: 1.5;
    color: var(--fg-muted);
  }

  .ads-save-btn {
    height: 30px;
    padding: 0 var(--space-3);
    border: 1px solid var(--border-strong, var(--border));
    border-radius: var(--radius-sm);
    background: var(--bg-elevated);
    color: var(--fg);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    cursor: pointer;
    white-space: nowrap;
  }

  .ads-save-btn:hover {
    background: color-mix(in oklch, var(--fg) 8%, var(--bg-elevated));
  }

  .ads-form-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: var(--space-4);
  }

  .ads-config-columns {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: var(--space-4);
  }

  .ads-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    min-width: 0;
  }

  .ads-field > span {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-muted);
  }

  .ads-input,
  .ads-textarea {
    width: 100%;
    box-sizing: border-box;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--bg-inset);
    color: var(--fg);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    outline: none;
  }

  .ads-input {
    height: 34px;
    padding: 0 var(--space-3);
  }

  .ads-textarea {
    resize: vertical;
    min-height: 140px;
    padding: var(--space-3);
    line-height: 1.5;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
  }

  .ads-input:focus,
  .ads-textarea:focus {
    border-color: var(--border-strong, var(--fg-subtle));
    box-shadow: 0 0 0 2px color-mix(in oklch, var(--fg) 8%, transparent);
  }

  @media (max-width: 800px) {
    .ads-form-grid,
    .ads-config-columns {
      grid-template-columns: 1fr;
    }

    .ads-config-head {
      flex-direction: column;
    }
  }

  /* Skeleton */
  .ads-skeleton {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-8);
    max-width: 600px;
  }

  .sk {
    background: var(--border);
    border-radius: var(--radius-sm);
    animation: sk-pulse 1.5s ease-in-out infinite;
  }

  .sk--avatar { width: 44px; height: 44px; border-radius: 9999px; }
  .sk--title { height: 28px; width: 50%; }
  .sk--body { height: 14px; width: 90%; }

  @keyframes sk-pulse {
    0%, 100% { opacity: 0.3; }
    50% { opacity: 0.6; }
  }
</style>
