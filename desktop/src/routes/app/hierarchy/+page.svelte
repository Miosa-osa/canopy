<!-- src/routes/app/hierarchy/+page.svelte -->
<script lang="ts">
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import LoadingSpinner from '$lib/components/shared/LoadingSpinner.svelte';
  import { hierarchyStore } from '$lib/stores/hierarchy.svelte';
  import { organizationsStore } from '$lib/stores/organizations.svelte';
  import type { HierarchyTeamNode, CanopyAgent } from '$api/types';

  // Fetch hierarchy when active org changes
  $effect(() => {
    const org = organizationsStore.current;
    if (org) {
      void hierarchyStore.fetchTree(org.id);
    } else {
      void organizationsStore.fetchOrganizations();
    }
  });

  // Collapsible state per node
  let collapsedDivisions = $state<Set<string>>(new Set());
  let collapsedDepartments = $state<Set<string>>(new Set());

  function toggleDivision(id: string): void {
    const next = new Set(collapsedDivisions);
    if (next.has(id)) next.delete(id); else next.add(id);
    collapsedDivisions = next;
  }

  function toggleDepartment(id: string): void {
    const next = new Set(collapsedDepartments);
    if (next.has(id)) next.delete(id); else next.add(id);
    collapsedDepartments = next;
  }

  function budgetLabel(cents: number | null): string {
    if (cents === null) return '';
    const k = Math.round(cents / 100);
    return k >= 1000 ? `$${(k / 1000).toFixed(0)}k/mo` : `$${k}/mo`;
  }

  function agentInitials(agent: CanopyAgent): string {
    const name = agent.display_name || agent.name;
    return name.split(' ').slice(0, 2).map((w: string) => w[0]).join('').toUpperCase();
  }
</script>

<PageShell
  title="Organization"
  subtitle={organizationsStore.current?.name ?? 'No org selected'}
>
  {#snippet actions()}
    <button
      class="hc-btn hc-btn--primary"
      onclick={() => {/* TODO: add division dialog */}}
      aria-label="Add division"
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d="M12 4.5v15m7.5-7.5h-15" />
      </svg>
      Add Division
    </button>
  {/snippet}

  {#snippet children()}
    {#if hierarchyStore.loading && !hierarchyStore.tree}
      <div class="hc-loading" aria-label="Loading hierarchy" aria-live="polite">
        <LoadingSpinner size="md" />
        <span>Loading hierarchy…</span>
      </div>

    {:else if !organizationsStore.current}
      <div class="hc-empty" role="status">
        <div class="hc-empty-icon" aria-hidden="true">
          <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">
            <path d="M3 6l3-3 3 3M6 3v13M21 6l-3-3-3 3M18 3v13M3 21h18M3 17h6M15 17h6" />
          </svg>
        </div>
        <p class="hc-empty-text">No organization selected.</p>
        <p class="hc-empty-sub">Select or create an organization to view its hierarchy.</p>
      </div>

    {:else if !hierarchyStore.tree || hierarchyStore.tree.divisions.length === 0}
      <div class="hc-empty" role="status">
        <div class="hc-empty-icon" aria-hidden="true">
          <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">
            <path d="M3 6l3-3 3 3M6 3v13M21 6l-3-3-3 3M18 3v13M3 21h18M3 17h6M15 17h6" />
          </svg>
        </div>
        <p class="hc-empty-text">No hierarchy configured yet.</p>
        <p class="hc-empty-sub">Add your first division to start building the org structure.</p>
      </div>

    {:else}
      <div class="hc-tree" role="tree" aria-label="Organization hierarchy">
        {#each hierarchyStore.tree.divisions as division (division.id)}
          {@const divExpanded = !collapsedDivisions.has(division.id)}

          <!-- Division -->
          <div class="hc-division" role="treeitem" aria-expanded={divExpanded} aria-selected={hierarchyStore.selectedDivision?.id === division.id}>
            <div
              class="hc-node hc-node--division"
              class:hc-node--selected={hierarchyStore.selectedDivision?.id === division.id}
            >
              <button
                class="hc-chevron-btn"
                onclick={() => toggleDivision(division.id)}
                aria-label="{divExpanded ? 'Collapse' : 'Expand'} division {division.name}"
              >
                <span class="hc-chevron" class:hc-chevron--collapsed={!divExpanded} aria-hidden="true">
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M19 9l-7 7-7-7" />
                  </svg>
                </span>
              </button>

              <button
                class="hc-node-content"
                onclick={() => hierarchyStore.selectDivision(division)}
                aria-label="Select division {division.name}"
              >
                <div class="hc-node-icon hc-node-icon--division" aria-hidden="true">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75M6.75 21v-3.375c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21" />
                  </svg>
                </div>

                <div class="hc-node-body">
                  <span class="hc-node-name">{division.name}</span>
                  {#if division.description}
                    <span class="hc-node-desc">{division.description}</span>
                  {/if}
                </div>

                <div class="hc-node-meta">
                  {#if division.budget_monthly_cents}
                    <span class="hc-chip hc-chip--blue">{budgetLabel(division.budget_monthly_cents)}</span>
                  {/if}
                  <span class="hc-chip hc-chip--count">{division.departments?.length ?? 0} depts</span>
                </div>
              </button>
            </div>

            {#if divExpanded && division.departments?.length > 0}
              <div class="hc-children">
                {#each division.departments as dept (dept.id)}
                  {@const deptExpanded = !collapsedDepartments.has(dept.id)}

                  <!-- Department -->
                  <div class="hc-department" role="treeitem" aria-expanded={deptExpanded} aria-selected={hierarchyStore.selectedDepartment?.id === dept.id}>
                    <div
                      class="hc-node hc-node--department"
                      class:hc-node--selected={hierarchyStore.selectedDepartment?.id === dept.id}
                    >
                      <button
                        class="hc-chevron-btn"
                        onclick={() => toggleDepartment(dept.id)}
                        aria-label="{deptExpanded ? 'Collapse' : 'Expand'} department {dept.name}"
                      >
                        <span class="hc-chevron" class:hc-chevron--collapsed={!deptExpanded} aria-hidden="true">
                          <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M19 9l-7 7-7-7" />
                          </svg>
                        </span>
                      </button>

                      <button
                        class="hc-node-content"
                        onclick={() => hierarchyStore.selectDepartment(dept)}
                        aria-label="Select department {dept.name}"
                      >
                        <div class="hc-node-icon hc-node-icon--department" aria-hidden="true">
                          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5m-1.5 3h1.5m-1.5 3h1.5m3-6H15m-1.5 3H15m-1.5 3H15M9 21v-3.375c0-.621.504-1.125 1.125-1.125h3.75c.621 0 1.125.504 1.125 1.125V21" />
                          </svg>
                        </div>

                        <div class="hc-node-body">
                          <span class="hc-node-name">{dept.name}</span>
                          {#if dept.description}
                            <span class="hc-node-desc">{dept.description}</span>
                          {/if}
                        </div>

                        <div class="hc-node-meta">
                          {#if dept.budget_monthly_cents}
                            <span class="hc-chip hc-chip--purple">{budgetLabel(dept.budget_monthly_cents)}</span>
                          {/if}
                          <span class="hc-chip hc-chip--count">{dept.teams?.length ?? 0} teams</span>
                        </div>
                      </button>
                    </div>

                    {#if deptExpanded && dept.teams?.length > 0}
                      <div class="hc-children">
                        {#each dept.teams as team (team.id)}
                          <!-- Team -->
                          <div class="hc-team" role="treeitem" aria-selected={hierarchyStore.selectedTeam?.id === team.id}>
                            <button
                              class="hc-node hc-node--team"
                              class:hc-node--selected={hierarchyStore.selectedTeam?.id === team.id}
                              onclick={() => { hierarchyStore.selectTeam(team); }}
                              aria-label="Team: {team.name}"
                            >
                              <span class="hc-chevron-placeholder" aria-hidden="true"></span>

                              <div class="hc-node-icon hc-node-icon--team" aria-hidden="true">
                                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                                  <path d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z" />
                                </svg>
                              </div>

                              <div class="hc-node-body">
                                <span class="hc-node-name">{team.name}</span>
                                {#if team.description}
                                  <span class="hc-node-desc">{team.description}</span>
                                {/if}
                              </div>

                              <div class="hc-node-meta">
                                {#if team.budget_monthly_cents}
                                  <span class="hc-chip hc-chip--green">{budgetLabel(team.budget_monthly_cents)}</span>
                                {/if}
                                {#if (team as HierarchyTeamNode).agents?.length}
                                  <div class="hc-avatars" aria-label="{(team as HierarchyTeamNode).agents.length} agents">
                                    {#each (team as HierarchyTeamNode).agents.slice(0, 4) as agent (agent.id)}
                                      <span class="hc-avatar" title="{agent.display_name || agent.name}">{agentInitials(agent)}</span>
                                    {/each}
                                    {#if (team as HierarchyTeamNode).agents.length > 4}
                                      <span class="hc-avatar hc-avatar--more">+{(team as HierarchyTeamNode).agents.length - 4}</span>
                                    {/if}
                                  </div>
                                {/if}
                              </div>
                            </button>
                          </div>
                        {/each}
                      </div>
                    {/if}
                  </div>
                {/each}
              </div>
            {/if}
          </div>
        {/each}
      </div>
    {/if}
  {/snippet}
</PageShell>

<style>
  /* ── Loading & Empty ────────────────────────────────────────────────────── */
  .hc-loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    height: 200px;
    color: var(--text-tertiary);
    font-size: 13px;
  }

  .hc-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 8px;
    height: 280px;
    text-align: center;
  }

  .hc-empty-icon {
    color: var(--text-tertiary);
    opacity: 0.4;
    margin-bottom: 4px;
  }

  .hc-empty-text {
    font-size: 14px;
    font-weight: 500;
    color: var(--text-secondary);
    margin: 0;
  }

  .hc-empty-sub {
    font-size: 13px;
    color: var(--text-tertiary);
    margin: 0;
    max-width: 320px;
  }

  /* ── Action Button ──────────────────────────────────────────────────────── */
  .hc-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 12px;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 500;
    cursor: pointer;
    border: 1px solid transparent;
    transition: background 0.12s, border-color 0.12s;
  }

  .hc-btn--primary {
    background: var(--accent-primary);
    color: #fff;
    border-color: var(--accent-primary);
  }

  .hc-btn--primary:hover {
    opacity: 0.88;
  }

  /* ── Tree layout ────────────────────────────────────────────────────────── */
  .hc-tree {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .hc-children {
    padding-left: 24px;
    display: flex;
    flex-direction: column;
    gap: 4px;
    margin-top: 4px;
  }

  /* ── Node row (div wrapper for division/department, button for team) ───── */
  .hc-node {
    display: flex;
    align-items: center;
    gap: 0;
    width: 100%;
    border-radius: 8px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    transition: background 0.1s, border-color 0.1s;
    overflow: hidden;
  }

  .hc-node:hover {
    border-color: var(--border-hover, var(--border-default));
  }

  .hc-node--selected {
    border-color: var(--accent-primary);
    background: color-mix(in srgb, var(--accent-primary) 8%, var(--bg-elevated));
  }

  /* Chevron toggle button (left slim area) */
  .hc-chevron-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    width: 32px;
    align-self: stretch;
    background: none;
    border: none;
    cursor: pointer;
    color: var(--text-tertiary);
    transition: color 0.1s;
  }

  .hc-chevron-btn:hover {
    color: var(--text-secondary);
    background: color-mix(in srgb, currentColor 6%, transparent);
  }

  /* Content button (rest of the row) */
  .hc-node-content {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 8px;
    min-width: 0;
    background: none;
    border: none;
    cursor: pointer;
    text-align: left;
    color: inherit;
  }

  .hc-node--division .hc-node-content {
    padding: 10px 12px 10px 0;
  }

  .hc-node--department .hc-node-content {
    padding: 8px 10px 8px 0;
  }

  /* Team node is still a button (no nested toggle needed) */
  .hc-node--team {
    cursor: pointer;
    border: none;
    padding: 7px 10px;
    text-align: left;
    color: inherit;
  }

  .hc-node--team:hover {
    background: var(--bg-hover, var(--bg-elevated));
  }

  /* ── Chevron ────────────────────────────────────────────────────────────── */
  .hc-chevron {
    display: flex;
    align-items: center;
    color: var(--text-tertiary);
    flex-shrink: 0;
    transition: transform 0.15s;
  }

  .hc-chevron--collapsed {
    transform: rotate(-90deg);
  }

  .hc-chevron-placeholder {
    width: 12px;
    flex-shrink: 0;
  }

  /* ── Node icon ──────────────────────────────────────────────────────────── */
  .hc-node-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 26px;
    border-radius: 6px;
    flex-shrink: 0;
  }

  .hc-node-icon--division {
    background: color-mix(in srgb, #3b82f6 15%, transparent);
    color: #3b82f6;
  }

  .hc-node-icon--department {
    background: color-mix(in srgb, #8b5cf6 15%, transparent);
    color: #8b5cf6;
  }

  .hc-node-icon--team {
    background: color-mix(in srgb, #10b981 15%, transparent);
    color: #10b981;
  }

  /* ── Node body ──────────────────────────────────────────────────────────── */
  .hc-node-body {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .hc-node-name {
    font-size: 13px;
    font-weight: 500;
    color: var(--text-primary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .hc-node-desc {
    font-size: 11px;
    color: var(--text-tertiary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  /* ── Meta / chips ───────────────────────────────────────────────────────── */
  .hc-node-meta {
    display: flex;
    align-items: center;
    gap: 6px;
    flex-shrink: 0;
  }

  .hc-chip {
    display: inline-flex;
    align-items: center;
    padding: 2px 7px;
    border-radius: 99px;
    font-size: 11px;
    font-weight: 500;
    border: 1px solid transparent;
  }

  .hc-chip--count {
    background: var(--bg-elevated);
    border-color: var(--border-default);
    color: var(--text-tertiary);
  }

  .hc-chip--blue {
    background: color-mix(in srgb, #3b82f6 12%, transparent);
    border-color: color-mix(in srgb, #3b82f6 30%, transparent);
    color: #3b82f6;
  }

  .hc-chip--purple {
    background: color-mix(in srgb, #8b5cf6 12%, transparent);
    border-color: color-mix(in srgb, #8b5cf6 30%, transparent);
    color: #8b5cf6;
  }

  .hc-chip--green {
    background: color-mix(in srgb, #10b981 12%, transparent);
    border-color: color-mix(in srgb, #10b981 30%, transparent);
    color: #10b981;
  }

  /* ── Agent avatars ──────────────────────────────────────────────────────── */
  .hc-avatars {
    display: flex;
    align-items: center;
  }

  .hc-avatar {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    border-radius: 50%;
    font-size: 9px;
    font-weight: 600;
    background: var(--bg-elevated);
    border: 2px solid var(--border-default);
    color: var(--text-secondary);
    margin-left: -6px;
    flex-shrink: 0;
  }

  .hc-avatar:first-child {
    margin-left: 0;
  }

  .hc-avatar--more {
    background: var(--bg-hover, var(--bg-elevated));
    color: var(--text-tertiary);
    font-size: 8px;
  }
</style>
