<!-- src/routes/app/departments/+page.svelte -->
<script lang="ts">
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import LoadingSpinner from '$lib/components/shared/LoadingSpinner.svelte';
  import { hierarchyStore } from '$lib/stores/hierarchy.svelte';
  import { organizationsStore } from '$lib/stores/organizations.svelte';
  import type { Department } from '$api/types';

  $effect(() => {
    // Load both divisions (for filter) and departments
    const orgId = organizationsStore.current?.id;
    void hierarchyStore.fetchDivisions(orgId);
    void hierarchyStore.fetchDepartments();
  });

  let searchQuery = $state('');
  let filterDivision = $state('');

  let filtered = $derived(
    hierarchyStore.departments.filter((d) => {
      const matchesDivision = !filterDivision || d.division_id === filterDivision;
      const q = searchQuery.toLowerCase();
      const matchesSearch =
        !q ||
        d.name.toLowerCase().includes(q) ||
        d.slug.toLowerCase().includes(q) ||
        (d.description ?? '').toLowerCase().includes(q);
      return matchesDivision && matchesSearch;
    }),
  );

  function divisionName(divisionId: string): string {
    return hierarchyStore.divisions.find((d) => d.id === divisionId)?.name ?? divisionId;
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

  // Create dialog
  let showCreate = $state(false);
  let createName = $state('');
  let createSlug = $state('');
  let createDesc = $state('');
  let createDivisionId = $state('');
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
    const data: Partial<Department> = {
      name: createName.trim(),
      slug: createSlug.trim() || slugify(createName.trim()),
      description: createDesc.trim() || null,
      division_id: createDivisionId || (hierarchyStore.divisions[0]?.id ?? ''),
    };
    const result = await hierarchyStore.createDepartment(data);
    creating = false;
    if (result) {
      showCreate = false;
      createName = '';
      createSlug = '';
      createDesc = '';
      createDivisionId = '';
    }
  }
</script>

<PageShell
  title="Departments"
  badge={hierarchyStore.departmentCount}
>
  {#snippet actions()}
    <button
      class="dp-btn dp-btn--primary"
      onclick={() => (showCreate = true)}
      aria-label="New department"
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d="M12 4.5v15m7.5-7.5h-15" />
      </svg>
      New Department
    </button>
  {/snippet}

  {#snippet children()}
    <!-- Toolbar -->
    <div class="dp-toolbar">
      <div class="dp-search-wrap">
        <svg class="dp-search-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 15.803a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <input
          class="dp-search"
          type="search"
          placeholder="Search departments…"
          bind:value={searchQuery}
          aria-label="Search departments"
        />
      </div>

      {#if hierarchyStore.divisions.length > 0}
        <select
          class="dp-select"
          bind:value={filterDivision}
          aria-label="Filter by division"
        >
          <option value="">All divisions</option>
          {#each hierarchyStore.divisions as div (div.id)}
            <option value={div.id}>{div.name}</option>
          {/each}
        </select>
      {/if}
    </div>

    {#if hierarchyStore.loading && hierarchyStore.departments.length === 0}
      <div class="dp-loading" aria-live="polite" aria-label="Loading departments">
        <LoadingSpinner size="md" />
        <span>Loading departments…</span>
      </div>

    {:else if filtered.length === 0}
      <div class="dp-empty" role="status">
        <div class="dp-empty-icon" aria-hidden="true">
          <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">
            <path d="M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5m-1.5 3h1.5m-1.5 3h1.5m3-6H15m-1.5 3H15m-1.5 3H15M9 21v-3.375c0-.621.504-1.125 1.125-1.125h3.75c.621 0 1.125.504 1.125 1.125V21" />
          </svg>
        </div>
        <p class="dp-empty-text">
          {searchQuery || filterDivision ? 'No departments match the filter.' : 'No departments yet.'}
        </p>
        {#if !searchQuery && !filterDivision}
          <p class="dp-empty-sub">Add departments to organize teams within divisions.</p>
        {/if}
      </div>

    {:else}
      <div class="dp-grid" role="list" aria-label="Departments">
        {#each filtered as dept (dept.id)}
          <article
            class="dp-card"
            class:dp-card--selected={hierarchyStore.selectedDepartment?.id === dept.id}
            role="listitem"
          >
            <button
              class="dp-card-inner"
              onclick={() => hierarchyStore.selectDepartment(dept)}
              aria-label="Select department {dept.name}"
              aria-pressed={hierarchyStore.selectedDepartment?.id === dept.id}
            >
              <header class="dp-card-header">
                <div class="dp-card-icon" aria-hidden="true">
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5m-1.5 3h1.5m-1.5 3h1.5m3-6H15m-1.5 3H15m-1.5 3H15M9 21v-3.375c0-.621.504-1.125 1.125-1.125h3.75c.621 0 1.125.504 1.125 1.125V21" />
                  </svg>
                </div>
                <div class="dp-card-title-group">
                  <h3 class="dp-card-name">{dept.name}</h3>
                  <span class="dp-card-slug">/{dept.slug}</span>
                </div>
                {#if dept.budget_enforcement}
                  <span class="dp-badge dp-badge--{dept.budget_enforcement}">{dept.budget_enforcement}</span>
                {/if}
              </header>

              {#if dept.description}
                <p class="dp-card-desc">{truncate(dept.description)}</p>
              {/if}

              <footer class="dp-card-footer">
                <span class="dp-stat">
                  <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                    <path d="M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75" />
                  </svg>
                  {divisionName(dept.division_id)}
                </span>
                <span class="dp-stat">
                  <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                    <path d="M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75" />
                  </svg>
                  {budgetLabel(dept.budget_monthly_cents)}
                </span>
              </footer>
            </button>
          </article>
        {/each}
      </div>
    {/if}

    <!-- Create dialog -->
    {#if showCreate}
      <div class="dp-overlay" role="dialog" aria-modal="true" aria-label="New department">
        <div class="dp-dialog">
          <header class="dp-dialog-header">
            <h2 class="dp-dialog-title">New Department</h2>
            <button class="dp-dialog-close" onclick={() => (showCreate = false)} aria-label="Close">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </header>

          <div class="dp-dialog-body">
            <label class="dp-field">
              <span class="dp-label">Division <span class="dp-required" aria-hidden="true">*</span></span>
              <select
                class="dp-input"
                bind:value={createDivisionId}
                aria-required="true"
                aria-label="Division"
              >
                <option value="" disabled selected>Select a division…</option>
                {#each hierarchyStore.divisions as div (div.id)}
                  <option value={div.id}>{div.name}</option>
                {/each}
              </select>
            </label>

            <label class="dp-field">
              <span class="dp-label">Name <span class="dp-required" aria-hidden="true">*</span></span>
              <input
                class="dp-input"
                type="text"
                placeholder="e.g. Demand Generation"
                value={createName}
                oninput={onNameInput}
                aria-required="true"
              />
            </label>

            <label class="dp-field">
              <span class="dp-label">Slug</span>
              <input
                class="dp-input"
                type="text"
                placeholder="auto-generated"
                bind:value={createSlug}
                aria-label="Department slug"
              />
            </label>

            <label class="dp-field">
              <span class="dp-label">Description</span>
              <textarea
                class="dp-input dp-textarea"
                placeholder="Optional description…"
                bind:value={createDesc}
                rows={3}
                aria-label="Department description"
              ></textarea>
            </label>
          </div>

          <footer class="dp-dialog-footer">
            <button class="dp-btn dp-btn--ghost" onclick={() => (showCreate = false)}>Cancel</button>
            <button
              class="dp-btn dp-btn--primary"
              onclick={handleCreate}
              disabled={creating || !createName.trim() || !createDivisionId}
              aria-busy={creating}
            >
              {creating ? 'Creating…' : 'Create Department'}
            </button>
          </footer>
        </div>
      </div>
    {/if}
  {/snippet}
</PageShell>

<style>
  .dp-toolbar {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 16px;
  }

  .dp-search-wrap {
    position: relative;
    flex: 1;
    max-width: 320px;
  }

  .dp-search-icon {
    position: absolute;
    left: 10px;
    top: 50%;
    transform: translateY(-50%);
    color: var(--text-tertiary);
    pointer-events: none;
  }

  .dp-search {
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

  .dp-search:focus {
    border-color: var(--accent-primary);
  }

  .dp-select {
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

  .dp-select:focus {
    border-color: var(--accent-primary);
  }

  .dp-loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    height: 200px;
    color: var(--text-tertiary);
    font-size: 13px;
  }

  .dp-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 8px;
    height: 240px;
    text-align: center;
  }

  .dp-empty-icon {
    color: var(--text-tertiary);
    opacity: 0.4;
    margin-bottom: 4px;
  }

  .dp-empty-text {
    font-size: 14px;
    font-weight: 500;
    color: var(--text-secondary);
    margin: 0;
  }

  .dp-empty-sub {
    font-size: 13px;
    color: var(--text-tertiary);
    margin: 0;
    max-width: 300px;
  }

  .dp-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
    gap: 12px;
  }

  .dp-card {
    border-radius: 10px;
    border: 1px solid var(--border-default);
    background: var(--bg-elevated);
    overflow: hidden;
    transition: border-color 0.1s;
  }

  .dp-card:hover {
    border-color: var(--border-hover, var(--border-default));
  }

  .dp-card--selected {
    border-color: var(--accent-primary);
  }

  .dp-card-inner {
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

  .dp-card-header {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .dp-card-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 30px;
    height: 30px;
    border-radius: 7px;
    background: color-mix(in srgb, #8b5cf6 15%, transparent);
    color: #8b5cf6;
    flex-shrink: 0;
  }

  .dp-card-title-group {
    flex: 1;
    min-width: 0;
  }

  .dp-card-name {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .dp-card-slug {
    font-size: 11px;
    color: var(--text-tertiary);
    font-family: var(--font-mono, monospace);
  }

  .dp-badge {
    padding: 2px 7px;
    border-radius: 99px;
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .dp-badge--soft {
    background: color-mix(in srgb, #f59e0b 12%, transparent);
    color: #f59e0b;
  }

  .dp-badge--hard {
    background: color-mix(in srgb, #ef4444 12%, transparent);
    color: #ef4444;
  }

  .dp-card-desc {
    font-size: 12px;
    color: var(--text-secondary);
    margin: 0;
    line-height: 1.5;
  }

  .dp-card-footer {
    display: flex;
    align-items: center;
    gap: 12px;
    padding-top: 4px;
    border-top: 1px solid var(--border-default);
    margin-top: 2px;
  }

  .dp-stat {
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

  .dp-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 12px;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 500;
    cursor: pointer;
    border: 1px solid transparent;
    transition: background 0.12s, opacity 0.12s;
  }

  .dp-btn--primary {
    background: var(--accent-primary);
    color: #fff;
    border-color: var(--accent-primary);
  }

  .dp-btn--primary:hover:not(:disabled) {
    opacity: 0.88;
  }

  .dp-btn--primary:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .dp-btn--ghost {
    background: transparent;
    color: var(--text-secondary);
    border-color: var(--border-default);
  }

  .dp-btn--ghost:hover {
    background: var(--bg-elevated);
  }

  .dp-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 100;
  }

  .dp-dialog {
    background: var(--bg-surface, var(--bg-elevated));
    border: 1px solid var(--border-default);
    border-radius: 12px;
    width: 440px;
    max-width: calc(100vw - 32px);
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .dp-dialog-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    border-bottom: 1px solid var(--border-default);
  }

  .dp-dialog-title {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
  }

  .dp-dialog-close {
    background: none;
    border: none;
    cursor: pointer;
    color: var(--text-tertiary);
    padding: 4px;
    border-radius: 4px;
    display: flex;
    align-items: center;
  }

  .dp-dialog-close:hover {
    color: var(--text-primary);
  }

  .dp-dialog-body {
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 14px;
  }

  .dp-dialog-footer {
    padding: 14px 20px;
    border-top: 1px solid var(--border-default);
    display: flex;
    justify-content: flex-end;
    gap: 8px;
  }

  .dp-field {
    display: flex;
    flex-direction: column;
    gap: 5px;
  }

  .dp-label {
    font-size: 12px;
    font-weight: 500;
    color: var(--text-secondary);
  }

  .dp-required {
    color: var(--accent-primary);
  }

  .dp-input {
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

  .dp-input:focus {
    border-color: var(--accent-primary);
  }

  .dp-textarea {
    resize: vertical;
    min-height: 72px;
  }
</style>
