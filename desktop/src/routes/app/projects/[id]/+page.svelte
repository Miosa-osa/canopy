<!-- src/routes/app/projects/[id]/+page.svelte -->
<script lang="ts">
  import { page } from '$app/state';
  import { goto } from '$app/navigation';
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import { projectsStore } from '$lib/stores/projects.svelte';
  import type { Project } from '$lib/api/types';

  const id = $derived(page.params.id ?? '');

  // Local state for the resolved project and loading
  let project = $state<Project | null>(null);
  let notFound = $state(false);

  $effect(() => {
    if (!id) return;
    // Check store first (may already be loaded from list page)
    const cached = projectsStore.projects.find((p) => p.id === id) ?? null;
    if (cached) {
      project = cached;
      notFound = false;
    } else {
      // Fetch from API
      void projectsStore.fetchProject(id).then((fetched) => {
        if (fetched) {
          project = fetched;
          notFound = false;
        } else {
          notFound = true;
        }
      });
    }
  });

  // Keep project in sync with store updates (e.g. optimistic updates)
  $effect(() => {
    const updated = projectsStore.projects.find((p) => p.id === id) ?? null;
    if (updated) project = updated;
  });

  function formatDate(iso: string): string {
    return new Date(iso).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  }
</script>

<svelte:head>
  <title>{project ? `${project.name} — Projects — Canopy` : 'Project — Projects — Canopy'}</title>
</svelte:head>

<PageShell title={project?.name ?? 'Project'} subtitle={project ? project.status : undefined}>
  {#if projectsStore.loading && !project}
    <div class="pjd-loading" role="status" aria-live="polite">
      <div class="pjd-spinner" aria-hidden="true"></div>
      <span>Loading project…</span>
    </div>
  {:else if notFound || (!project && !projectsStore.loading)}
    <div class="pjd-not-found" role="main">
      <span class="pjd-not-found-icon" aria-hidden="true">📁</span>
      <p class="pjd-not-found-text">Project not found.</p>
      <button
        class="pjd-back-btn"
        onclick={() => goto('/app/projects')}
        aria-label="Go back to projects"
      >
        ← Back to projects
      </button>
    </div>
  {:else if project}
    <div class="pjd-page">

      <!-- Top bar -->
      <div class="pjd-topbar">
        <button
          class="pjd-back"
          onclick={() => goto('/app/projects')}
          aria-label="Back to projects"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <path d="M19 12H5M12 19l-7-7 7-7" />
          </svg>
          Projects
        </button>
        <span class="pjd-breadcrumb-sep" aria-hidden="true">/</span>
        <span class="pjd-breadcrumb-cur">{project.name}</span>
      </div>

      <!-- Two-column layout -->
      <div class="pjd-layout">

        <!-- LEFT: main content -->
        <div class="pjd-main">

          <!-- Header -->
          <div class="pjd-hero">
            <div class="pjd-hero-left">
              <div class="pjd-hero-badges">
                <span class="pjd-status pjd-status--{project.status}">{project.status}</span>
              </div>
              <h1 class="pjd-hero-name">{project.name}</h1>
              {#if project.description}
                <p class="pjd-hero-desc">{project.description}</p>
              {/if}
            </div>
            <div class="pjd-hero-actions" role="group" aria-label="Project actions">
              <button
                class="pjd-btn-ghost"
                onclick={() => void projectsStore.updateProject(project!.id, { status: project!.status })}
                aria-label="Edit project"
              >
                Edit
              </button>
              <button
                class="pjd-btn-ghost"
                onclick={() => void projectsStore.updateProject(project!.id, { status: 'archived' })}
                aria-label="Archive project"
              >
                Archive
              </button>
            </div>
          </div>

          <!-- Metrics -->
          <section class="pjd-card" aria-label="Project metrics">
            <h2 class="pjd-card-title">Overview</h2>
            <div class="pjd-metrics" role="list">
              <div class="pjd-metric" role="listitem">
                <span class="pjd-metric-value">{project.goal_count}</span>
                <span class="pjd-metric-label">Goals</span>
              </div>
              <div class="pjd-metric" role="listitem">
                <span class="pjd-metric-value">{project.issue_count}</span>
                <span class="pjd-metric-label">Issues</span>
              </div>
              <div class="pjd-metric" role="listitem">
                <span class="pjd-metric-value">{project.agent_count}</span>
                <span class="pjd-metric-label">Agents</span>
              </div>
            </div>
          </section>

          <!-- Goals section -->
          <section class="pjd-card" aria-label="Goals">
            <div class="pjd-section-header">
              <h2 class="pjd-card-title">Goals</h2>
              <a href="/app/goals" class="pjd-section-link" aria-label="View all goals">
                View all →
              </a>
            </div>
            <p class="pjd-section-body">
              {project.goal_count === 0
                ? 'No goals yet for this project.'
                : `${project.goal_count} goal${project.goal_count === 1 ? '' : 's'} in this project.`}
            </p>
          </section>

          <!-- Issues section -->
          <section class="pjd-card" aria-label="Issues">
            <div class="pjd-section-header">
              <h2 class="pjd-card-title">Issues</h2>
              <a href="/app/issues" class="pjd-section-link" aria-label="View all issues">
                View all →
              </a>
            </div>
            <p class="pjd-section-body">
              {project.issue_count === 0
                ? 'No open issues for this project.'
                : `${project.issue_count} open issue${project.issue_count === 1 ? '' : 's'}.`}
            </p>
          </section>

          <!-- Agents section -->
          <section class="pjd-card" aria-label="Agents">
            <div class="pjd-section-header">
              <h2 class="pjd-card-title">Agents</h2>
            </div>
            <p class="pjd-section-body">
              {project.agent_count === 0
                ? 'No agents assigned to this project.'
                : `${project.agent_count} agent${project.agent_count === 1 ? '' : 's'} assigned.`}
            </p>
          </section>

        </div>

        <!-- RIGHT: metadata panel -->
        <aside class="pjd-sidebar" aria-label="Project details">
          <div class="pjd-panel">
            <h2 class="pjd-panel-title">Details</h2>

            <div class="pjd-panel-meta">
              <div class="pjd-meta-row">
                <span class="pjd-meta-label">Status</span>
                <span class="pjd-meta-value pjd-status pjd-status--{project.status}">{project.status}</span>
              </div>
              <div class="pjd-meta-row">
                <span class="pjd-meta-label">ID</span>
                <span class="pjd-meta-value pjd-meta-mono">{project.id}</span>
              </div>
              {#if project.workspace_path}
                <div class="pjd-meta-row">
                  <span class="pjd-meta-label">Workspace</span>
                  <span class="pjd-meta-value pjd-meta-mono">{project.workspace_path}</span>
                </div>
              {/if}
              <div class="pjd-meta-row">
                <span class="pjd-meta-label">Created</span>
                <span class="pjd-meta-value">{formatDate(project.created_at)}</span>
              </div>
              <div class="pjd-meta-row">
                <span class="pjd-meta-label">Updated</span>
                <span class="pjd-meta-value">{formatDate(project.updated_at)}</span>
              </div>
            </div>
          </div>
        </aside>

      </div>
    </div>
  {/if}
</PageShell>

<style>
  /* Loading */
  .pjd-loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    height: 200px;
    color: var(--dt3, var(--text-tertiary));
    font-size: 13px;
  }

  .pjd-spinner {
    width: 24px;
    height: 24px;
    border-radius: 50%;
    border: 2px solid var(--dbd, var(--border-default));
    border-top-color: var(--dt2, var(--text-secondary));
    animation: pjd-spin 0.8s linear infinite;
  }

  @keyframes pjd-spin { to { transform: rotate(360deg); } }

  /* Not found */
  .pjd-not-found {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    height: 100%;
    color: var(--text-tertiary);
    font-size: 13px;
  }

  .pjd-not-found-icon {
    font-size: 40px;
    opacity: 0.4;
  }

  .pjd-not-found-text {
    margin: 0;
  }

  .pjd-back-btn {
    height: 32px;
    padding: 0 14px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-default);
    background: transparent;
    color: var(--text-secondary);
    font-size: 13px;
    font-family: var(--font-sans);
    cursor: pointer;
    transition: all 120ms ease;
  }

  .pjd-back-btn:hover {
    background: var(--bg-elevated);
    color: var(--text-primary);
  }

  /* Page wrapper */
  .pjd-page {
    display: flex;
    flex-direction: column;
    min-height: 100%;
  }

  /* Top bar */
  .pjd-topbar {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 16px 24px 0;
  }

  .pjd-back {
    display: flex;
    align-items: center;
    gap: 6px;
    height: 28px;
    padding: 0 10px;
    border-radius: var(--radius-xs);
    border: 1px solid transparent;
    background: transparent;
    color: var(--text-tertiary);
    font-size: 12px;
    font-family: var(--font-sans);
    cursor: pointer;
    transition: all 120ms ease;
  }

  .pjd-back:hover {
    background: var(--bg-elevated);
    border-color: var(--border-default);
    color: var(--text-primary);
  }

  .pjd-breadcrumb-sep {
    color: var(--text-muted);
    font-size: 12px;
  }

  .pjd-breadcrumb-cur {
    font-size: 12px;
    color: var(--text-secondary);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 240px;
  }

  /* Two-column layout */
  .pjd-layout {
    display: grid;
    grid-template-columns: 1fr 280px;
    gap: 24px;
    padding: 24px;
    align-items: start;
  }

  .pjd-main {
    display: flex;
    flex-direction: column;
    gap: 16px;
    min-width: 0;
  }

  /* Hero */
  .pjd-hero {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 16px;
  }

  .pjd-hero-left {
    display: flex;
    flex-direction: column;
    gap: 6px;
    min-width: 0;
  }

  .pjd-hero-badges {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }

  .pjd-hero-name {
    font-size: 22px;
    font-weight: 700;
    color: var(--text-primary);
    margin: 0;
    line-height: 1.2;
  }

  .pjd-hero-desc {
    font-size: 13px;
    line-height: 1.5;
    color: var(--text-tertiary);
    margin: 0;
  }

  /* Action buttons */
  .pjd-hero-actions {
    display: flex;
    gap: 6px;
    flex-shrink: 0;
    align-items: flex-start;
    padding-top: 4px;
  }

  .pjd-btn-ghost {
    height: 30px;
    padding: 0 12px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-default);
    background: transparent;
    color: var(--text-secondary);
    font-size: 12px;
    font-weight: 500;
    font-family: var(--font-sans);
    cursor: pointer;
    transition: all 120ms ease;
  }

  .pjd-btn-ghost:hover {
    background: var(--bg-elevated);
    color: var(--text-primary);
  }

  /* Status badge */
  .pjd-status {
    display: inline-flex;
    align-items: center;
    height: 20px;
    padding: 0 8px;
    border-radius: 10px;
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.2px;
    text-transform: capitalize;
    white-space: nowrap;
  }

  .pjd-status--active {
    background: rgba(34, 197, 94, 0.08);
    border: 1px solid rgba(34, 197, 94, 0.2);
    color: rgba(34, 197, 94, 0.65);
  }

  .pjd-status--completed {
    background: rgba(99, 102, 241, 0.12);
    border: 1px solid rgba(99, 102, 241, 0.25);
    color: #a5b4fc;
  }

  .pjd-status--archived {
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    color: var(--text-muted);
  }

  /* Cards */
  .pjd-card {
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-md);
    padding: 16px;
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
  }

  .pjd-card-title {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: var(--text-tertiary);
    margin: 0 0 12px 0;
  }

  /* Metrics row */
  .pjd-metrics {
    display: flex;
    gap: 12px;
  }

  .pjd-metric {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    padding: 14px 8px;
    background: var(--bg-secondary);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
  }

  .pjd-metric-value {
    font-size: 24px;
    font-weight: 700;
    color: var(--text-primary);
    font-variant-numeric: tabular-nums;
    line-height: 1;
  }

  .pjd-metric-label {
    font-size: 11px;
    color: var(--text-muted);
    text-align: center;
  }

  /* Section headers with link */
  .pjd-section-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 12px;
  }

  .pjd-section-header .pjd-card-title {
    margin-bottom: 0;
  }

  .pjd-section-link {
    font-size: 12px;
    color: var(--accent-primary, #6366f1);
    text-decoration: none;
    transition: opacity 120ms ease;
  }

  .pjd-section-link:hover {
    opacity: 0.75;
  }

  .pjd-section-body {
    font-size: 13px;
    line-height: 1.5;
    color: var(--text-secondary);
    margin: 0;
  }

  /* Sidebar */
  .pjd-sidebar {
    position: sticky;
    top: 24px;
  }

  .pjd-panel {
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-md);
    padding: 20px;
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .pjd-panel-title {
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
  }

  .pjd-panel-meta {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 12px;
    background: var(--bg-secondary);
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-default);
  }

  .pjd-meta-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
  }

  .pjd-meta-label {
    font-size: 11px;
    color: var(--text-muted);
    flex-shrink: 0;
  }

  .pjd-meta-value {
    font-size: 12px;
    color: var(--text-secondary);
    text-align: right;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 160px;
  }

  .pjd-meta-mono {
    font-family: var(--font-mono);
    font-size: 11px;
  }
</style>
