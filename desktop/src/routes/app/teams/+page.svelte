<!-- src/routes/app/teams/+page.svelte -->
<script lang="ts">
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import LoadingSpinner from '$lib/components/shared/LoadingSpinner.svelte';
  import { hierarchyStore } from '$lib/stores/hierarchy.svelte';
  import { organizationsStore } from '$lib/stores/organizations.svelte';
  import { agentsStore } from '$lib/stores/agents.svelte';
  import { teams as teamsApi } from '$api/client';
  import type { Team, CanopyAgent } from '$api/types';

  $effect(() => {
    const orgId = organizationsStore.current?.id;
    void hierarchyStore.fetchDivisions(orgId);
    void hierarchyStore.fetchDepartments();
    void hierarchyStore.fetchTeams();
    void agentsStore.fetchAgents();
  });

  let searchQuery = $state('');
  let filterDepartment = $state('');

  let filtered = $derived(
    hierarchyStore.teams.filter((t) => {
      const matchesDept = !filterDepartment || t.department_id === filterDepartment;
      const q = searchQuery.toLowerCase();
      const matchesSearch =
        !q ||
        t.name.toLowerCase().includes(q) ||
        t.slug.toLowerCase().includes(q) ||
        (t.description ?? '').toLowerCase().includes(q);
      return matchesDept && matchesSearch;
    }),
  );

  function departmentName(departmentId: string): string {
    return hierarchyStore.departments.find((d) => d.id === departmentId)?.name ?? departmentId;
  }

  function budgetLabel(cents: number | null): string {
    if (cents === null) return '—';
    const k = Math.round(cents / 100);
    return k >= 1000 ? `$${(k / 1000).toFixed(0)}k/mo` : `$${k}/mo`;
  }

  function truncate(text: string | null, max = 80): string {
    if (!text) return '';
    return text.length <= max ? text : text.slice(0, max) + '…';
  }

  // Team members panel
  let expandedTeamId = $state<string | null>(null);
  let teamMembers = $state<Map<string, CanopyAgent[]>>(new Map());
  let loadingMembers = $state<string | null>(null);

  async function toggleTeamMembers(teamId: string): Promise<void> {
    if (expandedTeamId === teamId) {
      expandedTeamId = null;
      return;
    }
    expandedTeamId = teamId;
    if (!teamMembers.has(teamId)) {
      loadingMembers = teamId;
      try {
        const agents = await teamsApi.agents(teamId);
        const next = new Map(teamMembers);
        next.set(teamId, agents);
        teamMembers = next;
      } catch {
        // silently fail — store's error handling is in teamsApi
      } finally {
        loadingMembers = null;
      }
    }
  }

  function agentInitials(agent: CanopyAgent): string {
    const name = agent.display_name || agent.name;
    return name.split(' ').slice(0, 2).map((w: string) => w[0]).join('').toUpperCase();
  }

  // Create dialog
  let showCreate = $state(false);
  let createName = $state('');
  let createSlug = $state('');
  let createDesc = $state('');
  let createDepartmentId = $state('');
  let creating = $state(false);

  function onNameInput(e: Event): void {
    createName = (e.target as HTMLInputElement).value;
    if (!createSlug || createSlug === slugify(createName.slice(0, -1))) {
      createSlug = slugify(createName);
    }
  }

  function slugify(s: string): string {
    return s.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '');
  }

  async function handleCreate(): Promise<void> {
    if (!createName.trim()) return;
    creating = true;
    const data: Partial<Team> = {
      name: createName.trim(),
      slug: createSlug.trim() || slugify(createName.trim()),
      description: createDesc.trim() || null,
      department_id: createDepartmentId || (hierarchyStore.departments[0]?.id ?? ''),
    };
    const result = await hierarchyStore.createTeam(data);
    creating = false;
    if (result) {
      showCreate = false;
      createName = '';
      createSlug = '';
      createDesc = '';
      createDepartmentId = '';
    }
  }
</script>

<PageShell
  title="Teams"
  badge={hierarchyStore.teamCount}
>
  {#snippet actions()}
    <button
      class="tm-btn tm-btn--primary"
      onclick={() => (showCreate = true)}
      aria-label="New team"
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d="M12 4.5v15m7.5-7.5h-15" />
      </svg>
      New Team
    </button>
  {/snippet}

  {#snippet children()}
    <!-- Toolbar -->
    <div class="tm-toolbar">
      <div class="tm-search-wrap">
        <svg class="tm-search-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 15.803a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <input
          class="tm-search"
          type="search"
          placeholder="Search teams…"
          bind:value={searchQuery}
          aria-label="Search teams"
        />
      </div>

      {#if hierarchyStore.departments.length > 0}
        <select
          class="tm-select"
          bind:value={filterDepartment}
          aria-label="Filter by department"
        >
          <option value="">All departments</option>
          {#each hierarchyStore.departments as dept (dept.id)}
            <option value={dept.id}>{dept.name}</option>
          {/each}
        </select>
      {/if}
    </div>

    {#if hierarchyStore.loading && hierarchyStore.teams.length === 0}
      <div class="tm-loading" aria-live="polite" aria-label="Loading teams">
        <LoadingSpinner size="md" />
        <span>Loading teams…</span>
      </div>

    {:else if filtered.length === 0}
      <div class="tm-empty" role="status">
        <div class="tm-empty-icon" aria-hidden="true">
          <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">
            <path d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z" />
          </svg>
        </div>
        <p class="tm-empty-text">
          {searchQuery || filterDepartment ? 'No teams match the filter.' : 'No teams yet.'}
        </p>
        {#if !searchQuery && !filterDepartment}
          <p class="tm-empty-sub">Create teams to assign agents and track workstreams.</p>
        {/if}
      </div>

    {:else}
      <div class="tm-grid" role="list" aria-label="Teams">
        {#each filtered as team (team.id)}
          {@const isExpanded = expandedTeamId === team.id}
          {@const members = teamMembers.get(team.id) ?? []}
          {@const isLoadingThis = loadingMembers === team.id}

          <article
            class="tm-card"
            class:tm-card--selected={hierarchyStore.selectedTeam?.id === team.id}
            class:tm-card--expanded={isExpanded}
            role="listitem"
          >
            <button
              class="tm-card-inner"
              onclick={() => { hierarchyStore.selectTeam(team); void toggleTeamMembers(team.id); }}
              aria-label="Team {team.name}"
              aria-expanded={isExpanded}
            >
              <header class="tm-card-header">
                <div class="tm-card-icon" aria-hidden="true">
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z" />
                  </svg>
                </div>
                <div class="tm-card-title-group">
                  <h3 class="tm-card-name">{team.name}</h3>
                  <span class="tm-card-slug">/{team.slug}</span>
                </div>
                <span class="tm-chevron" class:tm-chevron--open={isExpanded} aria-hidden="true">
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M19 9l-7 7-7-7" />
                  </svg>
                </span>
              </header>

              {#if team.description}
                <p class="tm-card-desc">{truncate(team.description)}</p>
              {/if}

              <footer class="tm-card-footer">
                <span class="tm-stat">
                  <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                    <path d="M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18" />
                  </svg>
                  {departmentName(team.department_id)}
                </span>
                <span class="tm-stat">
                  <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                    <path d="M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75" />
                  </svg>
                  {budgetLabel(team.budget_monthly_cents)}
                </span>
              </footer>
            </button>

            <!-- Members panel -->
            {#if isExpanded}
              <div class="tm-members-panel" aria-label="Team members for {team.name}">
                <div class="tm-members-header">
                  <span class="tm-members-title">Members</span>
                  <button
                    class="tm-btn tm-btn--sm"
                    onclick={() => {/* TODO: add member dialog */}}
                    aria-label="Add member to {team.name}"
                  >
                    <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                      <path d="M12 4.5v15m7.5-7.5h-15" />
                    </svg>
                    Add
                  </button>
                </div>

                {#if isLoadingThis}
                  <div class="tm-members-loading" aria-live="polite">
                    <LoadingSpinner size="sm" />
                    <span>Loading members…</span>
                  </div>
                {:else if members.length === 0}
                  <p class="tm-members-empty">No members yet.</p>
                {:else}
                  <ul class="tm-members-list" aria-label="Members of {team.name}">
                    {#each members as agent (agent.id)}
                      <li class="tm-member-row">
                        <span class="tm-member-avatar" aria-hidden="true">{agentInitials(agent)}</span>
                        <div class="tm-member-info">
                          <span class="tm-member-name">{agent.display_name || agent.name}</span>
                          {#if agent.role}
                            <span class="tm-member-role">{agent.role}</span>
                          {/if}
                        </div>
                        <button
                          class="tm-btn tm-btn--danger-ghost"
                          onclick={() => void hierarchyStore.removeTeamMember(team.id, agent.id)}
                          aria-label="Remove {agent.display_name || agent.name} from team"
                          title="Remove from team"
                        >
                          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                            <path d="M6 18L18 6M6 6l12 12" />
                          </svg>
                        </button>
                      </li>
                    {/each}
                  </ul>
                {/if}
              </div>
            {/if}
          </article>
        {/each}
      </div>
    {/if}

    <!-- Create dialog -->
    {#if showCreate}
      <div class="tm-overlay" role="dialog" aria-modal="true" aria-label="New team">
        <div class="tm-dialog">
          <header class="tm-dialog-header">
            <h2 class="tm-dialog-title">New Team</h2>
            <button class="tm-dialog-close" onclick={() => (showCreate = false)} aria-label="Close">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </header>

          <div class="tm-dialog-body">
            <label class="tm-field">
              <span class="tm-label">Department <span class="tm-required" aria-hidden="true">*</span></span>
              <select
                class="tm-input"
                bind:value={createDepartmentId}
                aria-required="true"
                aria-label="Department"
              >
                <option value="" disabled selected>Select a department…</option>
                {#each hierarchyStore.departments as dept (dept.id)}
                  <option value={dept.id}>{dept.name}</option>
                {/each}
              </select>
            </label>

            <label class="tm-field">
              <span class="tm-label">Name <span class="tm-required" aria-hidden="true">*</span></span>
              <input
                class="tm-input"
                type="text"
                placeholder="e.g. Growth Hacking"
                value={createName}
                oninput={onNameInput}
                aria-required="true"
              />
            </label>

            <label class="tm-field">
              <span class="tm-label">Slug</span>
              <input
                class="tm-input"
                type="text"
                placeholder="auto-generated"
                bind:value={createSlug}
                aria-label="Team slug"
              />
            </label>

            <label class="tm-field">
              <span class="tm-label">Description</span>
              <textarea
                class="tm-input tm-textarea"
                placeholder="Optional description…"
                bind:value={createDesc}
                rows={3}
                aria-label="Team description"
              ></textarea>
            </label>
          </div>

          <footer class="tm-dialog-footer">
            <button class="tm-btn tm-btn--ghost" onclick={() => (showCreate = false)}>Cancel</button>
            <button
              class="tm-btn tm-btn--primary"
              onclick={handleCreate}
              disabled={creating || !createName.trim() || !createDepartmentId}
              aria-busy={creating}
            >
              {creating ? 'Creating…' : 'Create Team'}
            </button>
          </footer>
        </div>
      </div>
    {/if}
  {/snippet}
</PageShell>

<style>
  .tm-toolbar {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 16px;
  }

  .tm-search-wrap {
    position: relative;
    flex: 1;
    max-width: 320px;
  }

  .tm-search-icon {
    position: absolute;
    left: 10px;
    top: 50%;
    transform: translateY(-50%);
    color: var(--text-tertiary);
    pointer-events: none;
  }

  .tm-search {
    width: 100%;
    padding: 7px 10px 7px 30px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: 7px;
    font-size: 13px;
    color: var(--text-primary);
    outline: none;
    box-sizing: border-box;
  }

  .tm-search:focus {
    border-color: var(--accent-primary);
  }

  .tm-select {
    padding: 7px 10px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: 7px;
    font-size: 13px;
    color: var(--text-primary);
    outline: none;
    cursor: pointer;
    min-width: 160px;
  }

  .tm-select:focus {
    border-color: var(--accent-primary);
  }

  .tm-loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    height: 200px;
    color: var(--text-tertiary);
    font-size: 13px;
  }

  .tm-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 8px;
    height: 240px;
    text-align: center;
  }

  .tm-empty-icon {
    color: var(--text-tertiary);
    opacity: 0.4;
    margin-bottom: 4px;
  }

  .tm-empty-text {
    font-size: 14px;
    font-weight: 500;
    color: var(--text-secondary);
    margin: 0;
  }

  .tm-empty-sub {
    font-size: 13px;
    color: var(--text-tertiary);
    margin: 0;
    max-width: 300px;
  }

  .tm-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 12px;
    align-items: start;
  }

  .tm-card {
    border-radius: 10px;
    border: 1px solid var(--border-default);
    background: var(--bg-elevated);
    overflow: hidden;
    transition: border-color 0.1s;
  }

  .tm-card:hover {
    border-color: var(--border-hover, var(--border-default));
  }

  .tm-card--selected {
    border-color: var(--accent-primary);
  }

  .tm-card--expanded {
    border-color: var(--accent-primary);
  }

  .tm-card-inner {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 14px;
    width: 100%;
    text-align: left;
    background: none;
    border: none;
    cursor: pointer;
    color: inherit;
  }

  .tm-card-header {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .tm-card-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 30px;
    height: 30px;
    border-radius: 7px;
    background: color-mix(in srgb, #10b981 15%, transparent);
    color: #10b981;
    flex-shrink: 0;
  }

  .tm-card-title-group {
    flex: 1;
    min-width: 0;
  }

  .tm-card-name {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .tm-card-slug {
    font-size: 11px;
    color: var(--text-tertiary);
    font-family: var(--font-mono, monospace);
  }

  .tm-chevron {
    color: var(--text-tertiary);
    transition: transform 0.15s;
    flex-shrink: 0;
  }

  .tm-chevron--open {
    transform: rotate(180deg);
  }

  .tm-card-desc {
    font-size: 12px;
    color: var(--text-secondary);
    margin: 0;
    line-height: 1.5;
  }

  .tm-card-footer {
    display: flex;
    align-items: center;
    gap: 12px;
    padding-top: 4px;
    border-top: 1px solid var(--border-default);
    margin-top: 2px;
  }

  .tm-stat {
    display: flex;
    align-items: center;
    gap: 4px;
    font-size: 12px;
    color: var(--text-secondary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    min-width: 0;
  }

  /* ── Members panel ──────────────────────────────────────────────────────── */
  .tm-members-panel {
    border-top: 1px solid var(--border-default);
    padding: 12px 14px;
    background: color-mix(in srgb, var(--accent-primary) 3%, var(--bg-elevated));
  }

  .tm-members-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 10px;
  }

  .tm-members-title {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--text-tertiary);
  }

  .tm-members-loading {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 12px;
    color: var(--text-tertiary);
    padding: 8px 0;
  }

  .tm-members-empty {
    font-size: 12px;
    color: var(--text-tertiary);
    margin: 0;
    padding: 6px 0;
  }

  .tm-members-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .tm-member-row {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 4px 0;
  }

  .tm-member-avatar {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 26px;
    border-radius: 50%;
    background: color-mix(in srgb, #10b981 20%, var(--bg-elevated));
    color: #10b981;
    font-size: 10px;
    font-weight: 700;
    flex-shrink: 0;
    border: 1px solid var(--border-default);
  }

  .tm-member-info {
    flex: 1;
    min-width: 0;
  }

  .tm-member-name {
    font-size: 12px;
    font-weight: 500;
    color: var(--text-primary);
    display: block;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .tm-member-role {
    font-size: 10px;
    color: var(--text-tertiary);
    text-transform: capitalize;
  }

  /* ── Buttons ────────────────────────────────────────────────────────────── */
  .tm-btn {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 6px 12px;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 500;
    cursor: pointer;
    border: 1px solid transparent;
    transition: background 0.12s, opacity 0.12s;
  }

  .tm-btn--sm {
    padding: 4px 8px;
    font-size: 11px;
    border-radius: 5px;
    background: var(--bg-elevated);
    border-color: var(--border-default);
    color: var(--text-secondary);
  }

  .tm-btn--sm:hover {
    border-color: var(--accent-primary);
    color: var(--accent-primary);
  }

  .tm-btn--primary {
    background: var(--accent-primary);
    color: #fff;
    border-color: var(--accent-primary);
  }

  .tm-btn--primary:hover:not(:disabled) {
    opacity: 0.88;
  }

  .tm-btn--primary:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .tm-btn--ghost {
    background: transparent;
    color: var(--text-secondary);
    border-color: var(--border-default);
  }

  .tm-btn--ghost:hover {
    background: var(--bg-elevated);
  }

  .tm-btn--danger-ghost {
    background: none;
    border: none;
    color: var(--text-tertiary);
    padding: 3px;
    border-radius: 4px;
    flex-shrink: 0;
  }

  .tm-btn--danger-ghost:hover {
    color: #ef4444;
    background: color-mix(in srgb, #ef4444 10%, transparent);
  }

  /* ── Dialog ─────────────────────────────────────────────────────────────── */
  .tm-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 100;
  }

  .tm-dialog {
    background: var(--bg-surface, var(--bg-elevated));
    border: 1px solid var(--border-default);
    border-radius: 12px;
    width: 440px;
    max-width: calc(100vw - 32px);
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .tm-dialog-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    border-bottom: 1px solid var(--border-default);
  }

  .tm-dialog-title {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
  }

  .tm-dialog-close {
    background: none;
    border: none;
    cursor: pointer;
    color: var(--text-tertiary);
    padding: 4px;
    border-radius: 4px;
    display: flex;
    align-items: center;
  }

  .tm-dialog-close:hover {
    color: var(--text-primary);
  }

  .tm-dialog-body {
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 14px;
  }

  .tm-dialog-footer {
    padding: 14px 20px;
    border-top: 1px solid var(--border-default);
    display: flex;
    justify-content: flex-end;
    gap: 8px;
  }

  .tm-field {
    display: flex;
    flex-direction: column;
    gap: 5px;
  }

  .tm-label {
    font-size: 12px;
    font-weight: 500;
    color: var(--text-secondary);
  }

  .tm-required {
    color: var(--accent-primary);
  }

  .tm-input {
    padding: 8px 10px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: 7px;
    font-size: 13px;
    color: var(--text-primary);
    outline: none;
    width: 100%;
    box-sizing: border-box;
    font-family: inherit;
  }

  .tm-input:focus {
    border-color: var(--accent-primary);
  }

  .tm-textarea {
    resize: vertical;
    min-height: 72px;
  }
</style>
