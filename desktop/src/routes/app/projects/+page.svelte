<!-- src/routes/app/projects/+page.svelte -->
<script lang="ts">
  import { goto } from '$app/navigation';
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import { projectsStore } from '$lib/stores/projects.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';
  import type { ProjectStatus } from '$api/types';

  // Re-fetch whenever the active workspace changes (covers onMount + workspace switches)
  $effect(() => {
    const wsId = workspaceStore.activeWorkspaceId ?? undefined;
    void projectsStore.fetchProjects(wsId);
  });

  // Status filter options
  const STATUS_FILTERS: { value: ProjectStatus | 'all'; label: string }[] = [
    { value: 'all', label: 'All' },
    { value: 'active', label: 'Active' },
    { value: 'completed', label: 'Completed' },
    { value: 'archived', label: 'Archived' },
  ];

  // Create form
  let showForm = $state(false);
  let formName = $state('');
  let formDescription = $state('');
  let formStatus = $state<ProjectStatus>('active');
  let creating = $state(false);

  async function handleCreate() {
    if (!formName.trim()) return;
    creating = true;
    const created = await projectsStore.createProject({
      name: formName.trim(),
      description: formDescription.trim() || null,
      status: formStatus,
      workspace_id: workspaceStore.activeWorkspaceId ?? undefined,
    });
    creating = false;
    if (created) {
      showForm = false;
      formName = '';
      formDescription = '';
      formStatus = 'active';
    }
  }

  function cancelForm() {
    showForm = false;
    formName = '';
    formDescription = '';
    formStatus = 'active';
  }
</script>

<PageShell
  title="Projects"
  subtitle="{projectsStore.activeCount} active"
  badge={projectsStore.totalCount > 0 ? projectsStore.totalCount : undefined}
>
  {#snippet actions()}
    <div class="proj-filter-group" role="group" aria-label="Filter by status">
      {#each STATUS_FILTERS as opt (opt.value)}
        <button
          class="proj-filter-btn"
          class:proj-filter-btn--active={projectsStore.filterStatus === opt.value}
          onclick={() => projectsStore.filterStatus = opt.value}
          aria-pressed={projectsStore.filterStatus === opt.value}
        >
          {opt.label}
        </button>
      {/each}
    </div>
    <input
      class="proj-search"
      type="search"
      placeholder="Search projects…"
      value={projectsStore.searchQuery}
      oninput={(e) => projectsStore.searchQuery = (e.target as HTMLInputElement).value}
      aria-label="Search projects"
    />
    <button
      class="proj-btn"
      onclick={() => showForm = true}
      type="button"
      aria-label="New project"
    >
      + New Project
    </button>
  {/snippet}

  {#if projectsStore.loading && projectsStore.projects.length === 0}
    <div class="proj-loading" role="status" aria-live="polite">
      <div class="proj-spinner" aria-hidden="true"></div>
      <span>Loading projects…</span>
    </div>
  {:else if projectsStore.error && projectsStore.projects.length === 0}
    <div class="proj-error" role="alert">
      <p>Failed to load projects: {projectsStore.error}</p>
      <button onclick={() => void projectsStore.fetchProjects(workspaceStore.activeWorkspaceId ?? undefined)}>Retry</button>
    </div>
  {:else if projectsStore.filteredProjects.length === 0}
    <div class="proj-empty" role="status">
      <p>No projects yet. Create your first project to get started.</p>
    </div>
  {:else}
    <div class="proj-grid" role="list" aria-label="Projects">
      {#each projectsStore.filteredProjects as project (project.id)}
        <div
          class="proj-card"
          class:proj-card--selected={projectsStore.selected?.id === project.id}
          role="listitem"
        >
          <button
            class="proj-card-btn"
            onclick={() => { projectsStore.selectProject(project); goto(`/app/projects/${project.id}`); }}
            aria-pressed={projectsStore.selected?.id === project.id}
            aria-label="Select project {project.name}"
          >
            <div class="proj-header">
              <span class="proj-name">{project.name}</span>
              <span class="proj-status proj-status--{project.status}">{project.status}</span>
            </div>
            {#if project.description}
              <p class="proj-desc">{project.description}</p>
            {/if}
            <div class="proj-meta">
              <span class="proj-stat">{project.goal_count} goals</span>
              <span class="proj-stat">{project.issue_count} issues</span>
              <span class="proj-stat">{project.agent_count} agents</span>
            </div>
          </button>
        </div>
      {/each}
    </div>
  {/if}
</PageShell>

<!-- Create project dialog -->
{#if showForm}
  <div
    class="proj-overlay"
    role="dialog"
    aria-modal="true"
    aria-label="Create project"
    onclick={(e) => { if (e.target === e.currentTarget) cancelForm(); }}
  >
    <div class="proj-dialog">
      <h2 class="proj-dialog-title">New Project</h2>
      <div class="proj-field">
        <label class="proj-label" for="proj-name-input">Name</label>
        <input
          id="proj-name-input"
          class="proj-input"
          type="text"
          placeholder="Project name"
          bind:value={formName}
          autofocus
        />
      </div>
      <div class="proj-field">
        <label class="proj-label" for="proj-desc-input">Description</label>
        <textarea
          id="proj-desc-input"
          class="proj-textarea"
          placeholder="Optional description…"
          rows="3"
          bind:value={formDescription}
        ></textarea>
      </div>
      <div class="proj-field">
        <label class="proj-label" for="proj-status-input">Status</label>
        <select id="proj-status-input" class="proj-select" bind:value={formStatus}>
          <option value="active">Active</option>
          <option value="completed">Completed</option>
          <option value="archived">Archived</option>
        </select>
      </div>
      <div class="proj-dialog-actions">
        <button class="proj-btn-ghost" onclick={cancelForm} disabled={creating}>Cancel</button>
        <button
          class="proj-btn-primary"
          onclick={handleCreate}
          disabled={creating || !formName.trim()}
        >
          {creating ? 'Creating…' : 'Create Project'}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  /* Toolbar */
  .proj-filter-group {
    display: flex; align-items: center; gap: 2px;
    background: var(--dbg2); border: 1px solid var(--dbd); border-radius: 8px; padding: 2px;
  }
  .proj-filter-btn {
    background: none; border: none; border-radius: 6px; color: var(--dt3);
    font-size: 12px; font-weight: 500; padding: 3px 10px; cursor: pointer;
    transition: background 120ms ease, color 120ms ease;
  }
  .proj-filter-btn:hover { color: var(--dt2); background: rgba(255,255,255,0.05); }
  .proj-filter-btn--active { background: var(--dbg3); color: var(--dt); border: 1px solid var(--dbd); }
  .proj-search {
    height: 28px; padding: 0 10px; border-radius: 6px; font-size: 12px;
    background: var(--dbg2); border: 1px solid var(--dbd); color: var(--dt); min-width: 180px;
  }
  .proj-search:focus { outline: none; border-color: #6366f1; }
  .proj-btn {
    height: 28px; padding: 0 12px; border-radius: 6px; font-size: 12px; font-weight: 500;
    background: #6366f1; border: none; color: white; cursor: pointer; transition: background 120ms ease;
  }
  .proj-btn:hover { background: #4f46e5; }
  .proj-loading, .proj-empty, .proj-error {
    display: flex; flex-direction: column; align-items: center;
    justify-content: center; gap: 12px; height: 200px;
    color: var(--dt3); font-size: 13px;
  }
  .proj-spinner {
    width: 24px; height: 24px; border-radius: 50%;
    border: 2px solid var(--dbd); border-top-color: var(--dt2);
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }
  .proj-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 12px; padding: 24px; }
  .proj-card {
    background: var(--dbg2); border: 1px solid var(--dbd); border-radius: 10px;
    transition: border-color 120ms ease;
  }
  .proj-card--selected { border-color: #6366f1; background: color-mix(in srgb, #6366f1 6%, var(--dbg2)); }
  .proj-card:hover { border-color: var(--dbd2); }
  .proj-card-btn { width: 100%; padding: 16px; text-align: left; background: none; border: none; cursor: pointer; }
  .proj-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px; }
  .proj-name { font-size: 15px; font-weight: 600; color: var(--dt); }
  .proj-status { font-size: 10px; padding: 2px 6px; border-radius: 4px; text-transform: uppercase; font-weight: 500; }
  .proj-status--active { background: rgba(34, 197, 94, 0.1); color: rgba(34, 197, 94, 0.65); }
  .proj-status--archived { background: var(--dbg3); color: var(--dt4); }
  .proj-status--planning { background: color-mix(in srgb, #6366f1 15%, transparent); color: #a5b4fc; }
  .proj-desc { font-size: 12px; color: var(--dt3); margin: 0 0 10px; line-height: 1.5; }
  .proj-meta { display: flex; gap: 12px; }
  .proj-stat { font-size: 11px; color: var(--dt4); }

  /* Dialog overlay */
  .proj-overlay {
    position: fixed; inset: 0; background: rgba(0,0,0,0.5);
    display: flex; align-items: center; justify-content: center; z-index: 1000;
  }
  .proj-dialog {
    background: var(--dbg2); border: 1px solid var(--dbd); border-radius: 12px;
    padding: 24px; width: 440px; max-width: calc(100vw - 40px);
    display: flex; flex-direction: column; gap: 16px;
  }
  .proj-dialog-title { font-size: 16px; font-weight: 600; color: var(--dt); margin: 0; }
  .proj-field { display: flex; flex-direction: column; gap: 6px; }
  .proj-label { font-size: 12px; font-weight: 500; color: var(--dt2); }
  .proj-input, .proj-select {
    height: 34px; padding: 0 10px; border-radius: 6px; font-size: 13px;
    background: var(--dbg3); border: 1px solid var(--dbd); color: var(--dt);
    width: 100%; box-sizing: border-box;
  }
  .proj-input:focus, .proj-select:focus { outline: none; border-color: #6366f1; }
  .proj-textarea {
    padding: 8px 10px; border-radius: 6px; font-size: 13px; font-family: inherit;
    background: var(--dbg3); border: 1px solid var(--dbd); color: var(--dt);
    width: 100%; box-sizing: border-box; resize: vertical;
  }
  .proj-textarea:focus { outline: none; border-color: #6366f1; }
  .proj-dialog-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 4px; }
  .proj-btn-ghost, .proj-btn-primary {
    padding: 7px 16px; border-radius: 6px; font-size: 13px; font-weight: 500; cursor: pointer;
    transition: all 120ms ease;
  }
  .proj-btn-ghost { background: transparent; border: 1px solid var(--dbd); color: var(--dt3); }
  .proj-btn-ghost:hover:not(:disabled) { background: var(--dbg3); color: var(--dt2); }
  .proj-btn-primary { background: #6366f1; border: none; color: #fff; }
  .proj-btn-primary:hover:not(:disabled) { background: #4f46e5; }
  .proj-btn-ghost:disabled, .proj-btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
