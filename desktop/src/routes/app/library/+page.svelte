<!-- src/routes/app/library/+page.svelte -->
<script lang="ts">
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import LibraryAgentCard from '$lib/components/library/LibraryAgentCard.svelte';
  import LibrarySkillCard from '$lib/components/library/LibrarySkillCard.svelte';
  import LibraryOperationCard from '$lib/components/library/LibraryOperationCard.svelte';
  import LibraryTemplateCard from '$lib/components/library/LibraryTemplateCard.svelte';
  import { goto } from '$app/navigation';
  import { deployTemplate } from '$lib/services/template-deploy';
  import { toastStore } from '$lib/stores/toasts.svelte';
  import {
    getLibraryAgents,
    getLibrarySkills,
    getLibraryOperations,
    getLibraryTemplates,
    AGENT_CATEGORIES,
    SKILL_CATEGORIES,
    type LibraryAgent,
    type LibrarySkill,
    type LibraryOperation,
    type LibraryTemplate,
    type AgentCategory,
    type SkillCategory,
  } from '$lib/api/mock/library';

  // ── Tab state ───────────────────────────────────────────────────────────────
  type Tab = 'agents' | 'skills' | 'teams' | 'companies';
  let activeTab = $state<Tab>('agents');

  // ── Raw data (loaded once) ──────────────────────────────────────────────────
  const allAgents = getLibraryAgents();
  const allSkills = getLibrarySkills();
  const allOperations = getLibraryOperations();
  const allTemplates = getLibraryTemplates();

  // ── Sort types ──────────────────────────────────────────────────────────────
  type AgentSort = 'name-asc' | 'name-desc' | 'downloads' | 'rating' | 'favorites' | 'newest' | 'oldest';
  type SkillSort  = 'name-asc' | 'name-desc' | 'downloads' | 'favorites' | 'newest' | 'oldest';

  // ── View mode ───────────────────────────────────────────────────────────────
  type ViewMode = 'grid' | 'list';

  // ── Agents tab state ────────────────────────────────────────────────────────
  let agentSearch = $state('');
  let debouncedAgentSearch = $state('');
  let selectedAgentCategory = $state<AgentCategory | null>(null);
  let agentSort = $state<AgentSort>('name-asc');
  let agentView = $state<ViewMode>('grid');

  // ── Skills tab state ────────────────────────────────────────────────────────
  let skillSearch = $state('');
  let debouncedSkillSearch = $state('');
  let selectedSkillCategory = $state<SkillCategory | null>(null);
  let skillSort = $state<SkillSort>('name-asc');
  let skillView = $state<ViewMode>('grid');

  // ── Teams tab state ──────────────────────────────────────────────────────────
  let teamSearch = $state('');
  let debouncedTeamSearch = $state('');

  // ── Companies tab state ───────────────────────────────────────────────────────
  let companySearch = $state('');
  let debouncedCompanySearch = $state('');

  // ── Debounce with $effect cleanup ──────────────────────────────────────────
  $effect(() => {
    const val = agentSearch;
    const t = setTimeout(() => { debouncedAgentSearch = val; }, 300);
    return () => clearTimeout(t);
  });

  $effect(() => {
    const val = skillSearch;
    const t = setTimeout(() => { debouncedSkillSearch = val; }, 300);
    return () => clearTimeout(t);
  });

  $effect(() => {
    const val = teamSearch;
    const t = setTimeout(() => { debouncedTeamSearch = val; }, 300);
    return () => clearTimeout(t);
  });

  $effect(() => {
    const val = companySearch;
    const t = setTimeout(() => { debouncedCompanySearch = val; }, 300);
    return () => clearTimeout(t);
  });

  // ── Category toggles ────────────────────────────────────────────────────────
  function toggleAgentCategory(cat: AgentCategory) {
    selectedAgentCategory = selectedAgentCategory === cat ? null : cat;
  }

  function toggleSkillCategory(cat: SkillCategory) {
    selectedSkillCategory = selectedSkillCategory === cat ? null : cat;
  }

  // ── Sort helpers ─────────────────────────────────────────────────────────────
  function sortAgents(list: LibraryAgent[], sort: AgentSort): LibraryAgent[] {
    return [...list].sort((a, b) => {
      switch (sort) {
        case 'name-asc':   return a.name.localeCompare(b.name);
        case 'name-desc':  return b.name.localeCompare(a.name);
        case 'downloads':  return b.downloads - a.downloads;
        case 'rating':     return b.rating - a.rating;
        case 'favorites':  return b.favorites - a.favorites;
        case 'newest':     return b.added_at.localeCompare(a.added_at);
        case 'oldest':     return a.added_at.localeCompare(b.added_at);
      }
    });
  }

  function sortSkills(list: LibrarySkill[], sort: SkillSort): LibrarySkill[] {
    return [...list].sort((a, b) => {
      switch (sort) {
        case 'name-asc':   return a.name.localeCompare(b.name);
        case 'name-desc':  return b.name.localeCompare(a.name);
        case 'downloads':  return b.downloads - a.downloads;
        case 'favorites':  return b.favorites - a.favorites;
        case 'newest':     return b.added_at.localeCompare(a.added_at);
        case 'oldest':     return a.added_at.localeCompare(b.added_at);
      }
    });
  }

  // ── Filtered + sorted agents ────────────────────────────────────────────────
  let filteredAgents = $derived.by((): LibraryAgent[] => {
    let result = allAgents;
    if (selectedAgentCategory) {
      result = result.filter((a) => a.category === selectedAgentCategory);
    }
    const q = debouncedAgentSearch.trim().toLowerCase();
    if (q) {
      result = result.filter(
        (a) =>
          a.name.toLowerCase().includes(q) ||
          a.description.toLowerCase().includes(q) ||
          a.category.includes(q) ||
          a.tags.some((t) => t.includes(q)),
      );
    }
    return sortAgents(result, agentSort);
  });

  // ── Filtered + sorted skills ────────────────────────────────────────────────
  let filteredSkills = $derived.by((): LibrarySkill[] => {
    let result = allSkills;
    if (selectedSkillCategory) {
      result = result.filter((s) => s.category === selectedSkillCategory);
    }
    const q = debouncedSkillSearch.trim().toLowerCase();
    if (q) {
      result = result.filter(
        (s) =>
          s.name.toLowerCase().includes(q) ||
          s.description.toLowerCase().includes(q) ||
          s.category.includes(q) ||
          s.tags.some((t) => t.includes(q)),
      );
    }
    return sortSkills(result, skillSort);
  });

  // ── Filtered teams ────────────────────────────────────────────────────────────
  let filteredTeams = $derived.by((): LibraryTemplate[] => {
    const q = debouncedTeamSearch.trim().toLowerCase();
    if (!q) return allTemplates;
    return allTemplates.filter(
      (tmpl) =>
        tmpl.name.toLowerCase().includes(q) ||
        tmpl.description.toLowerCase().includes(q) ||
        tmpl.size.toLowerCase().includes(q),
    );
  });

  // ── Filtered companies ───────────────────────────────────────────────────────
  let filteredCompanies = $derived.by((): LibraryOperation[] => {
    const q = debouncedCompanySearch.trim().toLowerCase();
    if (!q) return allOperations;
    return allOperations.filter(
      (op) =>
        op.name.toLowerCase().includes(q) ||
        op.description.toLowerCase().includes(q),
    );
  });

  // ── Results count text ──────────────────────────────────────────────────────
  let subtitleText = $derived.by(() => {
    switch (activeTab) {
      case 'agents':    return `${filteredAgents.length} of ${allAgents.length} agents`;
      case 'skills':    return `${filteredSkills.length} of ${allSkills.length} skills`;
      case 'teams':     return `${filteredTeams.length} of ${allTemplates.length} teams`;
      case 'companies': return `${filteredCompanies.length} of ${allOperations.length} companies`;
    }
  });

  // ── Toast-like notification ─────────────────────────────────────────────────
  let notification = $state<string | null>(null);

  $effect(() => {
    if (!notification) return;
    const t = setTimeout(() => { notification = null; }, 2500);
    return () => clearTimeout(t);
  });

  function notify(msg: string) {
    notification = msg;
  }

  function handleAgentAdd(agent: LibraryAgent) {
    notify(`${agent.emoji} ${agent.name} added to workspace`);
  }

  function handleSkillToggle(skill: LibrarySkill) {
    notify(`${skill.name} toggled`);
  }

  async function handleOperationUse(op: LibraryOperation) {
    notify(`Deploying "${op.name}"…`);
    const result = await deployTemplate(op.id, op.name);
    if (result.success) {
      const warn = result.warnings && result.warnings.length > 0
        ? ` (${result.warnings.length} warning${result.warnings.length === 1 ? '' : 's'})`
        : '';
      notify(`${op.emoji} ${op.name} deployed — ${result.agentCount} agents${warn}`);
      if (result.warnings) {
        for (const w of result.warnings) {
          toastStore.warning('Deploy warning', w);
        }
      }
      goto('/app');
    } else {
      notify(`Deploy failed: ${result.error ?? 'unknown error'}`);
    }
  }

  async function handleTemplateCreate(tmpl: LibraryTemplate) {
    notify(`Deploying "${tmpl.name}"…`);
    const result = await deployTemplate(tmpl.id, tmpl.name);
    if (result.success) {
      const warn = result.warnings && result.warnings.length > 0
        ? ` (${result.warnings.length} warning${result.warnings.length === 1 ? '' : 's'})`
        : '';
      notify(`${tmpl.emoji} ${tmpl.name} deployed — ${result.agentCount} agents${warn}`);
      if (result.warnings) {
        for (const w of result.warnings) {
          toastStore.warning('Deploy warning', w);
        }
      }
      goto('/app');
    } else {
      notify(`Deploy failed: ${result.error ?? 'unknown error'}`);
    }
  }

  // ── Count helper for category chips ────────────────────────────────────────
  function agentCatCount(cat: AgentCategory): number {
    return allAgents.filter((a) => a.category === cat).length;
  }

  function skillCatCount(cat: SkillCategory): number {
    return allSkills.filter((s) => s.category === cat).length;
  }

  function fmtCount(n: number): string {
    if (n >= 1000) return (n / 1000).toFixed(1).replace(/\.0$/, '') + 'k';
    return String(n);
  }
</script>

<PageShell title="Library" subtitle={subtitleText}>
  {#snippet actions()}
    {#if notification}
      <div class="lib-notif" role="status" aria-live="polite">{notification}</div>
    {/if}
  {/snippet}

  <!-- Tab bar -->
  <div class="lib-tabs" role="tablist" aria-label="Library sections">
    {#each (['agents', 'skills', 'teams', 'companies'] as const) as tab}
      <button
        class="lib-tab"
        class:lib-tab--active={activeTab === tab}
        role="tab"
        aria-selected={activeTab === tab}
        aria-controls="lib-panel-{tab}"
        onclick={() => { activeTab = tab; }}
        type="button"
      >
        {#if tab === 'agents'}Agents <span class="lib-tab-count">{allAgents.length}</span>
        {:else if tab === 'skills'}Skills <span class="lib-tab-count">{allSkills.length}</span>
        {:else if tab === 'teams'}Teams <span class="lib-tab-count">{allTemplates.length}</span>
        {:else}Companies <span class="lib-tab-count">{allOperations.length}</span>
        {/if}
      </button>
    {/each}
  </div>

  <!-- ── AGENTS PANEL ──────────────────────────────────────────────────────── -->
  {#if activeTab === 'agents'}
  <div id="lib-panel-agents" role="tabpanel" class="lib-panel">
    <div class="lib-toolbar">
      <div class="lib-search-wrap">
        <svg class="lib-search-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 15.803a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <input
          class="lib-search"
          type="search"
          placeholder="Search agents…"
          value={agentSearch}
          oninput={(e) => { agentSearch = (e.target as HTMLInputElement).value; }}
          aria-label="Search agents"
        />
      </div>

      <select class="lib-sort-select" bind:value={agentSort} aria-label="Sort agents">
        <option value="name-asc">Name (A-Z)</option>
        <option value="name-desc">Name (Z-A)</option>
        <option value="downloads">Most Downloads</option>
        <option value="favorites">Most Favorites</option>
        <option value="rating">Highest Rating</option>
        <option value="newest">Newest First</option>
        <option value="oldest">Oldest First</option>
      </select>

      <div class="lib-view-toggle" role="group" aria-label="View mode">
        <button class="lib-view-btn" class:lib-view-btn--active={agentView === 'grid'} onclick={() => { agentView = 'grid'; }} title="Grid view" type="button" aria-pressed={agentView === 'grid'}>
          <svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><rect x="0" y="0" width="6" height="6" rx="1"/><rect x="10" y="0" width="6" height="6" rx="1"/><rect x="0" y="10" width="6" height="6" rx="1"/><rect x="10" y="10" width="6" height="6" rx="1"/></svg>
        </button>
        <button class="lib-view-btn" class:lib-view-btn--active={agentView === 'list'} onclick={() => { agentView = 'list'; }} title="List view" type="button" aria-pressed={agentView === 'list'}>
          <svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><rect x="0" y="1" width="16" height="2" rx="1"/><rect x="0" y="7" width="16" height="2" rx="1"/><rect x="0" y="13" width="16" height="2" rx="1"/></svg>
        </button>
      </div>
    </div>

    <div class="lib-filters" role="group" aria-label="Filter by category">
      <button class="lib-chip" class:lib-chip--active={selectedAgentCategory === null} onclick={() => { selectedAgentCategory = null; }} type="button">All <span class="lib-chip-count">{allAgents.length}</span></button>
      {#each AGENT_CATEGORIES as cat}
        <button class="lib-chip lib-chip--{cat}" class:lib-chip--active={selectedAgentCategory === cat} onclick={() => toggleAgentCategory(cat)} type="button">{cat} <span class="lib-chip-count">{agentCatCount(cat)}</span></button>
      {/each}
    </div>

    <div class="lib-results-count" role="status" aria-live="polite">Showing {filteredAgents.length} of {allAgents.length} agents</div>

    {#if filteredAgents.length === 0}
      <div class="lib-empty" role="status">No agents match your search.</div>
    {:else if agentView === 'grid'}
      <div class="lib-agent-grid" role="list" aria-label="Agents">
        {#each filteredAgents as agent (agent.id)}
          <div role="listitem"><LibraryAgentCard {agent} onAdd={handleAgentAdd} /></div>
        {/each}
      </div>
    {:else}
      <div class="lib-agent-list" role="list" aria-label="Agents">
        {#each filteredAgents as agent (agent.id)}
          <div role="button" tabindex="0" class="lib-list-row" onclick={() => goto(`/app/library/agents/${agent.id}`)} onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); goto(`/app/library/agents/${agent.id}`); } }} aria-label="View {agent.name}">
            <span class="lib-list-emoji" aria-hidden="true">{agent.emoji}</span>
            <div class="lib-list-info">
              <span class="lib-list-name">{agent.name}</span>
              <span class="lib-list-desc">{agent.description}</span>
            </div>
            <span class="lib-list-badge">{agent.category}</span>
            <span class="lib-list-stat" title="Downloads">{fmtCount(agent.downloads)} dl</span>
            <span class="lib-list-stat" title="Favorites">{fmtCount(agent.favorites)}</span>
            <span class="lib-list-stat" title="Rating">{agent.rating}/5</span>
            <span class="lib-list-source lib-list-source--{agent.isOfficial ? 'official' : 'community'}">{agent.isOfficial ? 'official' : 'community'}</span>
          </div>
        {/each}
      </div>
    {/if}
  </div>
  {/if}

  <!-- ── SKILLS PANEL ──────────────────────────────────────────────────────── -->
  {#if activeTab === 'skills'}
  <div id="lib-panel-skills" role="tabpanel" class="lib-panel">
    <div class="lib-toolbar">
      <div class="lib-search-wrap">
        <svg class="lib-search-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 15.803a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <input
          class="lib-search"
          type="search"
          placeholder="Search skills…"
          value={skillSearch}
          oninput={(e) => { skillSearch = (e.target as HTMLInputElement).value; }}
          aria-label="Search skills"
        />
      </div>

      <select class="lib-sort-select" bind:value={skillSort} aria-label="Sort skills">
        <option value="name-asc">Name (A-Z)</option>
        <option value="name-desc">Name (Z-A)</option>
        <option value="downloads">Most Downloads</option>
        <option value="favorites">Most Favorites</option>
        <option value="newest">Newest First</option>
        <option value="oldest">Oldest First</option>
      </select>

      <div class="lib-view-toggle" role="group" aria-label="View mode">
        <button class="lib-view-btn" class:lib-view-btn--active={skillView === 'grid'} onclick={() => { skillView = 'grid'; }} title="Grid view" type="button" aria-pressed={skillView === 'grid'}>
          <svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><rect x="0" y="0" width="6" height="6" rx="1"/><rect x="10" y="0" width="6" height="6" rx="1"/><rect x="0" y="10" width="6" height="6" rx="1"/><rect x="10" y="10" width="6" height="6" rx="1"/></svg>
        </button>
        <button class="lib-view-btn" class:lib-view-btn--active={skillView === 'list'} onclick={() => { skillView = 'list'; }} title="List view" type="button" aria-pressed={skillView === 'list'}>
          <svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><rect x="0" y="1" width="16" height="2" rx="1"/><rect x="0" y="7" width="16" height="2" rx="1"/><rect x="0" y="13" width="16" height="2" rx="1"/></svg>
        </button>
      </div>
    </div>

    <div class="lib-filters" role="group" aria-label="Filter by category">
      <button class="lib-chip" class:lib-chip--active={selectedSkillCategory === null} onclick={() => { selectedSkillCategory = null; }} type="button">All <span class="lib-chip-count">{allSkills.length}</span></button>
      {#each SKILL_CATEGORIES as cat}
        <button class="lib-chip lib-chip--{cat}" class:lib-chip--active={selectedSkillCategory === cat} onclick={() => toggleSkillCategory(cat)} type="button">{cat} <span class="lib-chip-count">{skillCatCount(cat)}</span></button>
      {/each}
    </div>

    <div class="lib-results-count" role="status" aria-live="polite">Showing {filteredSkills.length} of {allSkills.length} skills</div>

    {#if filteredSkills.length === 0}
      <div class="lib-empty" role="status">No skills match your search.</div>
    {:else if skillView === 'grid'}
      <div class="lib-skill-grid" role="list" aria-label="Skills">
        {#each filteredSkills as skill (skill.id)}
          <div role="listitem"><LibrarySkillCard {skill} onToggle={handleSkillToggle} /></div>
        {/each}
      </div>
    {:else}
      <div class="lib-skill-list" role="list" aria-label="Skills">
        {#each filteredSkills as skill (skill.id)}
          <div role="button" tabindex="0" class="lib-list-row" onclick={() => goto(`/app/library/skills/${skill.id}`)} onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); goto(`/app/library/skills/${skill.id}`); } }} aria-label="View {skill.name}">
            <div class="lib-list-info">
              <span class="lib-list-name">{skill.name}</span>
              <span class="lib-list-desc">{skill.description}</span>
            </div>
            <span class="lib-list-badge">{skill.category}</span>
            <span class="lib-list-stat" title="Downloads">{fmtCount(skill.downloads)} dl</span>
            <span class="lib-list-stat" title="Favorites">{fmtCount(skill.favorites)}</span>
            <span class="lib-list-stat">v{skill.version}</span>
            <span class="lib-list-source lib-list-source--{skill.isOfficial ? 'official' : 'community'}">{skill.isOfficial ? 'official' : 'community'}</span>
          </div>
        {/each}
      </div>
    {/if}
  </div>
  {/if}

  <!-- ── TEAMS PANEL ───────────────────────────────────────────────────────── -->
  {#if activeTab === 'teams'}
  <div id="lib-panel-teams" role="tabpanel" class="lib-panel">
    <div class="lib-section-header">
      <p class="lib-section-desc">Pre-configured agent teams sized to your workflow. Pick a team and deploy a coordinated group of agents in seconds.</p>
    </div>
    <div class="lib-toolbar">
      <div class="lib-search-wrap">
        <svg class="lib-search-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 15.803a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <input class="lib-search" type="search" placeholder="Search teams…" value={teamSearch} oninput={(e) => { teamSearch = (e.target as HTMLInputElement).value; }} aria-label="Search teams" />
      </div>
    </div>
    <div class="lib-results-count" role="status" aria-live="polite">Showing {filteredTeams.length} of {allTemplates.length} teams</div>
    {#if filteredTeams.length === 0}
      <div class="lib-empty" role="status">No teams match your search.</div>
    {:else}
      <div class="lib-template-grid" role="list" aria-label="Teams">
        {#each filteredTeams as tmpl (tmpl.id)}
          <div role="button" tabindex="0" class="lib-list-card-wrap" onclick={() => goto(`/app/library/teams/${tmpl.id}`)} onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); goto(`/app/library/teams/${tmpl.id}`); } }} aria-label="View {tmpl.name} team">
            <LibraryTemplateCard template={tmpl} onCreate={handleTemplateCreate} />
          </div>
        {/each}
      </div>
    {/if}
  </div>
  {/if}

  <!-- ── COMPANIES PANEL ───────────────────────────────────────────────────── -->
  {#if activeTab === 'companies'}
  <div id="lib-panel-companies" role="tabpanel" class="lib-panel">
    <div class="lib-section-header">
      <p class="lib-section-desc">Pre-built AI companies — fully staffed operations ready to run. Add to your workspace and hit the ground running.</p>
    </div>
    <div class="lib-toolbar">
      <div class="lib-search-wrap">
        <svg class="lib-search-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 15.803a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <input class="lib-search" type="search" placeholder="Search companies…" value={companySearch} oninput={(e) => { companySearch = (e.target as HTMLInputElement).value; }} aria-label="Search companies" />
      </div>
    </div>
    <div class="lib-results-count" role="status" aria-live="polite">Showing {filteredCompanies.length} of {allOperations.length} companies</div>
    {#if filteredCompanies.length === 0}
      <div class="lib-empty" role="status">No companies match your search.</div>
    {:else}
      <div class="lib-operation-grid" role="list" aria-label="Companies">
        {#each filteredCompanies as op (op.id)}
          <div role="button" tabindex="0" class="lib-list-card-wrap" onclick={() => goto(`/app/library/companies/${op.id}`)} onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); goto(`/app/library/companies/${op.id}`); } }} aria-label="View {op.name}">
            <LibraryOperationCard operation={op} onUse={handleOperationUse} />
          </div>
        {/each}
      </div>
    {/if}
  </div>
  {/if}
</PageShell>

<style>
  /* ── Notification ────────────────────────────────────────────────────────── */
  .lib-notif {
    font-size: 12px;
    color: var(--text-secondary);
    padding: 4px 10px;
    border-radius: var(--radius-sm);
    background: rgba(255, 255, 255, 0.06);
    border: 1px solid var(--border-default);
    white-space: nowrap;
    animation: lib-fade-in 150ms ease;
  }

  @keyframes lib-fade-in {
    from { opacity: 0; transform: translateY(-4px); }
    to   { opacity: 1; transform: translateY(0); }
  }

  /* ── Tab bar ─────────────────────────────────────────────────────────────── */
  .lib-tabs {
    display: flex;
    align-items: center;
    gap: 2px;
    padding: 0 24px;
    border-bottom: 1px solid var(--border-default);
    flex-shrink: 0;
  }

  .lib-tab {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 10px 14px;
    font-size: 13px;
    font-weight: 500;
    color: var(--text-tertiary);
    background: transparent;
    border: none;
    border-bottom: 2px solid transparent;
    cursor: pointer;
    transition: color 150ms ease, border-color 150ms ease;
    margin-bottom: -1px;
    white-space: nowrap;
  }

  .lib-tab:hover { color: var(--text-secondary); }

  .lib-tab--active {
    color: var(--text-primary);
    border-bottom-color: var(--accent-primary);
  }

  .lib-tab:focus-visible {
    outline: 2px solid var(--accent-primary);
    outline-offset: -2px;
    border-radius: var(--radius-xs);
  }

  .lib-tab-count {
    font-size: 10px;
    font-weight: 600;
    padding: 1px 5px;
    border-radius: var(--radius-full);
    background: rgba(255, 255, 255, 0.06);
    color: var(--text-muted);
    font-variant-numeric: tabular-nums;
  }

  .lib-tab--active .lib-tab-count {
    background: rgba(59, 130, 246, 0.15);
    color: #7ab3f8;
  }

  /* ── Panel wrapper ───────────────────────────────────────────────────────── */
  .lib-panel {
    display: flex;
    flex-direction: column;
    gap: 16px;
    padding: 20px 24px 32px;
  }

  /* ── Toolbar (search + sort + view) ────────────────────────────────────── */
  .lib-toolbar {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .lib-search-wrap {
    position: relative;
    flex: 1;
    max-width: 360px;
  }

  .lib-search-icon {
    position: absolute;
    left: 10px;
    top: 50%;
    transform: translateY(-50%);
    color: var(--text-muted);
    pointer-events: none;
  }

  .lib-search {
    width: 100%;
    padding: 7px 12px 7px 32px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-default);
    background: var(--bg-tertiary);
    color: var(--text-primary);
    font-size: 13px;
    transition: border-color 150ms ease;
  }

  .lib-search::placeholder { color: var(--text-muted); }

  .lib-search:focus {
    outline: none;
    border-color: var(--accent-primary);
  }

  .lib-sort-select {
    padding: 7px 28px 7px 10px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-default);
    background: var(--bg-tertiary);
    color: var(--text-secondary);
    font-size: 12px;
    cursor: pointer;
    -webkit-appearance: none;
    appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='10' height='6' fill='%23888'%3E%3Cpath d='M0 0l5 6 5-6z'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 8px center;
    background-size: 10px 6px;
  }

  .lib-sort-select:focus {
    outline: none;
    border-color: var(--accent-primary);
  }

  .lib-view-toggle {
    display: flex;
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    overflow: hidden;
  }

  .lib-view-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 6px 8px;
    background: transparent;
    border: none;
    color: var(--text-muted);
    cursor: pointer;
    transition: background 100ms ease, color 100ms ease;
  }

  .lib-view-btn:hover { color: var(--text-secondary); }

  .lib-view-btn--active {
    background: rgba(255, 255, 255, 0.08);
    color: var(--text-primary);
  }

  .lib-view-btn + .lib-view-btn {
    border-left: 1px solid var(--border-default);
  }

  /* ── Category filter chips ───────────────────────────────────────────────── */
  .lib-filters {
    display: flex;
    align-items: center;
    gap: 6px;
    overflow-x: auto;
    padding-bottom: 2px;
    scrollbar-width: none;
  }

  .lib-filters::-webkit-scrollbar { display: none; }

  .lib-chip {
    flex-shrink: 0;
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 4px 10px;
    border-radius: var(--radius-full);
    border: 1px solid var(--border-default);
    background: transparent;
    color: var(--text-tertiary);
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    transition: all 150ms ease;
    text-transform: capitalize;
    white-space: nowrap;
  }

  .lib-chip:hover {
    border-color: rgba(255, 255, 255, 0.15);
    color: var(--text-secondary);
  }

  .lib-chip--active {
    background: rgba(59, 130, 246, 0.15);
    border-color: rgba(59, 130, 246, 0.35);
    color: #7ab3f8;
  }

  .lib-chip:focus-visible {
    outline: 2px solid var(--accent-primary);
    outline-offset: 2px;
  }

  .lib-chip-count {
    font-size: 10px;
    font-weight: 600;
    opacity: 0.6;
    font-variant-numeric: tabular-nums;
  }

  .lib-chip--active .lib-chip-count { opacity: 0.85; }

  /* ── Results count ─────────────────────────────────────────────────────── */
  .lib-results-count {
    font-size: 11px;
    color: var(--text-muted);
    padding: 0 2px;
  }

  /* ── Grids ───────────────────────────────────────────────────────────────── */
  .lib-agent-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 12px;
  }

  .lib-skill-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 10px;
  }

  .lib-operation-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 16px;
  }

  .lib-template-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 16px;
  }

  @media (max-width: 1200px) {
    .lib-agent-grid { grid-template-columns: repeat(2, 1fr); }
    .lib-skill-grid { grid-template-columns: repeat(3, 1fr); }
  }

  @media (max-width: 800px) {
    .lib-agent-grid     { grid-template-columns: 1fr; }
    .lib-skill-grid     { grid-template-columns: repeat(2, 1fr); }
    .lib-operation-grid { grid-template-columns: 1fr; }
    .lib-template-grid  { grid-template-columns: 1fr; }
  }

  @media (max-width: 480px) {
    .lib-skill-grid { grid-template-columns: 1fr; }
  }

  /* ── List view ──────────────────────────────────────────────────────────── */
  .lib-agent-list, .lib-skill-list {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .lib-list-row {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px 14px;
    border-radius: var(--radius-sm);
    cursor: pointer;
    transition: background 100ms ease;
  }

  .lib-list-row:hover {
    background: rgba(255, 255, 255, 0.04);
  }

  .lib-list-emoji {
    font-size: 18px;
    flex-shrink: 0;
    width: 28px;
    text-align: center;
  }

  .lib-list-info {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .lib-list-name {
    font-size: 13px;
    font-weight: 500;
    color: var(--text-primary);
  }

  .lib-list-desc {
    font-size: 11px;
    color: var(--text-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .lib-list-badge {
    flex-shrink: 0;
    font-size: 10px;
    font-weight: 600;
    padding: 2px 8px;
    border-radius: var(--radius-full);
    background: rgba(255, 255, 255, 0.06);
    color: var(--text-tertiary);
    text-transform: capitalize;
  }

  .lib-list-stat {
    flex-shrink: 0;
    font-size: 11px;
    color: var(--text-muted);
    font-variant-numeric: tabular-nums;
  }

  .lib-list-source {
    flex-shrink: 0;
    font-size: 10px;
    font-weight: 500;
    padding: 1px 6px;
    border-radius: var(--radius-full);
  }

  .lib-list-source--official {
    background: rgba(59, 130, 246, 0.15);
    color: #7ab3f8;
  }

  .lib-list-source--community {
    background: rgba(255, 255, 255, 0.04);
    color: var(--text-muted);
  }

  .lib-list-card-wrap {
    cursor: pointer;
  }

  /* ── Section header (teams / companies) ──────────────────────────────────── */
  .lib-section-header {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .lib-section-desc {
    font-size: 13px;
    color: var(--text-tertiary);
    margin: 0;
    max-width: 620px;
    line-height: 1.6;
  }

  /* ── Empty state ─────────────────────────────────────────────────────────── */
  .lib-empty {
    padding: 48px 24px;
    text-align: center;
    font-size: 13px;
    color: var(--text-muted);
  }
</style>
