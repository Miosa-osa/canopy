<!-- src/routes/app/divisions/+page.svelte -->
<script lang="ts">
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import LoadingSpinner from '$lib/components/shared/LoadingSpinner.svelte';
  import { hierarchyStore } from '$lib/stores/hierarchy.svelte';
  import { organizationsStore } from '$lib/stores/organizations.svelte';
  import type { Division } from '$api/types';

  $effect(() => {
    const orgId = organizationsStore.current?.id;
    void hierarchyStore.fetchDivisions(orgId);
  });

  let searchQuery = $state('');

  let filtered = $derived(
    searchQuery.trim().length === 0
      ? hierarchyStore.divisions
      : hierarchyStore.divisions.filter((d) =>
          d.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
          d.slug.toLowerCase().includes(searchQuery.toLowerCase()) ||
          (d.description ?? '').toLowerCase().includes(searchQuery.toLowerCase()),
        ),
  );

  function budgetLabel(cents: number | null): string {
    if (cents === null) return '—';
    const k = Math.round(cents / 100);
    return k >= 1000 ? `$${(k / 1000).toFixed(0)}k/mo` : `$${k}/mo`;
  }

  function truncate(text: string | null, max = 80): string {
    if (!text) return '';
    return text.length <= max ? text : text.slice(0, max) + '…';
  }

  // Simple create dialog state
  let showCreate = $state(false);
  let createName = $state('');
  let createSlug = $state('');
  let createDesc = $state('');
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
    const data: Partial<Division> = {
      name: createName.trim(),
      slug: createSlug.trim() || slugify(createName.trim()),
      description: createDesc.trim() || null,
      organization_id: organizationsStore.current?.id ?? '',
    };
    const result = await hierarchyStore.createDivision(data);
    creating = false;
    if (result) {
      showCreate = false;
      createName = '';
      createSlug = '';
      createDesc = '';
    }
  }
</script>

<PageShell
  title="Divisions"
  badge={hierarchyStore.divisionCount}
>
  {#snippet actions()}
    <button
      class="dv-btn dv-btn--primary"
      onclick={() => (showCreate = true)}
      aria-label="New division"
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d="M12 4.5v15m7.5-7.5h-15" />
      </svg>
      New Division
    </button>
  {/snippet}

  {#snippet children()}
    <!-- Search -->
    <div class="dv-toolbar">
      <div class="dv-search-wrap">
        <svg class="dv-search-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 15.803a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <input
          class="dv-search"
          type="search"
          placeholder="Search divisions…"
          bind:value={searchQuery}
          aria-label="Search divisions"
        />
      </div>
    </div>

    {#if hierarchyStore.loading && hierarchyStore.divisions.length === 0}
      <div class="dv-loading" aria-live="polite" aria-label="Loading divisions">
        <LoadingSpinner size="md" />
        <span>Loading divisions…</span>
      </div>

    {:else if filtered.length === 0}
      <div class="dv-empty" role="status">
        <div class="dv-empty-icon" aria-hidden="true">
          <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">
            <path d="M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75M6.75 21v-3.375c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21" />
          </svg>
        </div>
        <p class="dv-empty-text">
          {searchQuery ? 'No divisions match the search.' : 'No divisions yet.'}
        </p>
        {#if !searchQuery}
          <p class="dv-empty-sub">Create your first division to start organizing agents.</p>
        {/if}
      </div>

    {:else}
      <div class="dv-grid" role="list" aria-label="Divisions">
        {#each filtered as div (div.id)}
          <article
            class="dv-card"
            class:dv-card--selected={hierarchyStore.selectedDivision?.id === div.id}
            role="listitem"
          >
            <button
              class="dv-card-inner"
              onclick={() => hierarchyStore.selectDivision(div)}
              aria-label="Select division {div.name}"
              aria-pressed={hierarchyStore.selectedDivision?.id === div.id}
            >
              <header class="dv-card-header">
                <div class="dv-card-icon" aria-hidden="true">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75M6.75 21v-3.375c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21" />
                  </svg>
                </div>
                <div class="dv-card-title-group">
                  <h3 class="dv-card-name">{div.name}</h3>
                  <span class="dv-card-slug">/{div.slug}</span>
                </div>
                {#if div.budget_enforcement}
                  <span class="dv-badge dv-badge--{div.budget_enforcement}">{div.budget_enforcement}</span>
                {/if}
              </header>

              {#if div.description}
                <p class="dv-card-desc">{truncate(div.description)}</p>
              {/if}

              <footer class="dv-card-footer">
                <span class="dv-stat">
                  <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                    <path d="M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 00-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 01-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 003 15h-.75M15 10.5a3 3 0 11-6 0 3 3 0 016 0zm3 0h.008v.008H18V10.5zm-12 0h.008v.008H6V10.5z" />
                  </svg>
                  {budgetLabel(div.budget_monthly_cents)}
                </span>
                {#if div.operating_model}
                  <span class="dv-stat dv-stat--muted">{div.operating_model}</span>
                {/if}
              </footer>
            </button>
          </article>
        {/each}
      </div>
    {/if}

    <!-- Create dialog -->
    {#if showCreate}
      <div class="dv-overlay" role="dialog" aria-modal="true" aria-label="New division">
        <div class="dv-dialog">
          <header class="dv-dialog-header">
            <h2 class="dv-dialog-title">New Division</h2>
            <button class="dv-dialog-close" onclick={() => (showCreate = false)} aria-label="Close">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </header>

          <div class="dv-dialog-body">
            <label class="dv-field">
              <span class="dv-label">Name <span class="dv-required" aria-hidden="true">*</span></span>
              <input
                class="dv-input"
                type="text"
                placeholder="e.g. Marketing"
                value={createName}
                oninput={onNameInput}
                aria-required="true"
              />
            </label>

            <label class="dv-field">
              <span class="dv-label">Slug</span>
              <input
                class="dv-input"
                type="text"
                placeholder="auto-generated"
                bind:value={createSlug}
                aria-label="Division slug"
              />
            </label>

            <label class="dv-field">
              <span class="dv-label">Description</span>
              <textarea
                class="dv-input dv-textarea"
                placeholder="Optional description…"
                bind:value={createDesc}
                rows={3}
                aria-label="Division description"
              ></textarea>
            </label>
          </div>

          <footer class="dv-dialog-footer">
            <button class="dv-btn dv-btn--ghost" onclick={() => (showCreate = false)}>Cancel</button>
            <button
              class="dv-btn dv-btn--primary"
              onclick={handleCreate}
              disabled={creating || !createName.trim()}
              aria-busy={creating}
            >
              {creating ? 'Creating…' : 'Create Division'}
            </button>
          </footer>
        </div>
      </div>
    {/if}
  {/snippet}
</PageShell>

<style>
  /* ── Toolbar ────────────────────────────────────────────────────────────── */
  .dv-toolbar {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 16px;
  }

  .dv-search-wrap {
    position: relative;
    flex: 1;
    max-width: 320px;
  }

  .dv-search-icon {
    position: absolute;
    left: 10px;
    top: 50%;
    transform: translateY(-50%);
    color: var(--text-tertiary);
    pointer-events: none;
  }

  .dv-search {
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

  .dv-search:focus {
    border-color: var(--accent-primary);
  }

  /* ── Loading & Empty ────────────────────────────────────────────────────── */
  .dv-loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    height: 200px;
    color: var(--text-tertiary);
    font-size: 13px;
  }

  .dv-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 8px;
    height: 240px;
    text-align: center;
  }

  .dv-empty-icon {
    color: var(--text-tertiary);
    opacity: 0.4;
    margin-bottom: 4px;
  }

  .dv-empty-text {
    font-size: 14px;
    font-weight: 500;
    color: var(--text-secondary);
    margin: 0;
  }

  .dv-empty-sub {
    font-size: 13px;
    color: var(--text-tertiary);
    margin: 0;
    max-width: 300px;
  }

  /* ── Grid ───────────────────────────────────────────────────────────────── */
  .dv-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
    gap: 12px;
  }

  /* ── Card ───────────────────────────────────────────────────────────────── */
  .dv-card {
    border-radius: 10px;
    border: 1px solid var(--border-default);
    background: var(--bg-elevated);
    overflow: hidden;
    transition: border-color 0.1s;
  }

  .dv-card:hover {
    border-color: var(--border-hover, var(--border-default));
  }

  .dv-card--selected {
    border-color: var(--accent-primary);
  }

  .dv-card-inner {
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

  .dv-card-header {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .dv-card-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 30px;
    height: 30px;
    border-radius: 7px;
    background: color-mix(in srgb, #3b82f6 15%, transparent);
    color: #3b82f6;
    flex-shrink: 0;
  }

  .dv-card-title-group {
    flex: 1;
    min-width: 0;
  }

  .dv-card-name {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .dv-card-slug {
    font-size: 11px;
    color: var(--text-tertiary);
    font-family: var(--font-mono, monospace);
  }

  .dv-badge {
    padding: 2px 7px;
    border-radius: 99px;
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .dv-badge--soft {
    background: color-mix(in srgb, #f59e0b 12%, transparent);
    color: #f59e0b;
  }

  .dv-badge--hard {
    background: color-mix(in srgb, #ef4444 12%, transparent);
    color: #ef4444;
  }

  .dv-card-desc {
    font-size: 12px;
    color: var(--text-secondary);
    margin: 0;
    line-height: 1.5;
  }

  .dv-card-footer {
    display: flex;
    align-items: center;
    gap: 12px;
    padding-top: 4px;
    border-top: 1px solid var(--border-default);
    margin-top: 2px;
  }

  .dv-stat {
    display: flex;
    align-items: center;
    gap: 4px;
    font-size: 12px;
    color: var(--text-secondary);
  }

  .dv-stat--muted {
    color: var(--text-tertiary);
  }

  /* ── Buttons ────────────────────────────────────────────────────────────── */
  .dv-btn {
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

  .dv-btn--primary {
    background: var(--accent-primary);
    color: #fff;
    border-color: var(--accent-primary);
  }

  .dv-btn--primary:hover:not(:disabled) {
    opacity: 0.88;
  }

  .dv-btn--primary:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .dv-btn--ghost {
    background: transparent;
    color: var(--text-secondary);
    border-color: var(--border-default);
  }

  .dv-btn--ghost:hover {
    background: var(--bg-elevated);
  }

  /* ── Dialog ─────────────────────────────────────────────────────────────── */
  .dv-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 100;
  }

  .dv-dialog {
    background: var(--bg-surface, var(--bg-elevated));
    border: 1px solid var(--border-default);
    border-radius: 12px;
    width: 440px;
    max-width: calc(100vw - 32px);
    display: flex;
    flex-direction: column;
    gap: 0;
    overflow: hidden;
  }

  .dv-dialog-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    border-bottom: 1px solid var(--border-default);
  }

  .dv-dialog-title {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
  }

  .dv-dialog-close {
    background: none;
    border: none;
    cursor: pointer;
    color: var(--text-tertiary);
    padding: 4px;
    border-radius: 4px;
    display: flex;
    align-items: center;
  }

  .dv-dialog-close:hover {
    color: var(--text-primary);
  }

  .dv-dialog-body {
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 14px;
  }

  .dv-dialog-footer {
    padding: 14px 20px;
    border-top: 1px solid var(--border-default);
    display: flex;
    justify-content: flex-end;
    gap: 8px;
  }

  .dv-field {
    display: flex;
    flex-direction: column;
    gap: 5px;
  }

  .dv-label {
    font-size: 12px;
    font-weight: 500;
    color: var(--text-secondary);
  }

  .dv-required {
    color: var(--accent-primary);
  }

  .dv-input {
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

  .dv-input:focus {
    border-color: var(--accent-primary);
  }

  .dv-textarea {
    resize: vertical;
    min-height: 72px;
  }
</style>
