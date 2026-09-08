<script lang="ts">
/**
 * /projects — Project list page.
 * Renders a card grid of projects for the current workspace.
 * Calls GET /api/v1/projects?workspace_slug=<active>.
 * Detail page /projects/[slug] is reachable by clicking a card.
 * CSS prefix: pj- (projects).
 * LOC target: ≤ 300.
 */
import { createMutation, createQuery, useQueryClient } from '@tanstack/svelte-query';
import { FolderKanban, Plus, X } from 'lucide-svelte';
import { goto } from '$app/navigation';
import { createProjectMutation, listProjects } from '$lib/api/queries/projects.js';
import type { ViewState } from '$lib/design/primitives/ViewPicker.svelte';
import ViewPicker from '$lib/design/primitives/ViewPicker.svelte';
import type { CreateProjectBody, Project, ProjectStatus } from '$lib/domain/projects/types.js';
import { activeWorkspace } from '$lib/stores/active-workspace.svelte.js';

// ── State ─────────────────────────────────────────────────────────────────

let view = $state<ViewState>({ layout: 'grid', density: 'comfortable', sort: 'recent' });
const workspaceSlug = $derived(activeWorkspace.slug ?? 'default');

// ── Query ──────────────────────────────────────────────────────────────────

const queryClient = useQueryClient();

const projectsQ = createQuery({
  get queryKey() {
    return ['projects', { workspaceSlug }] as const;
  },
  get queryFn() {
    return () => listProjects({ workspaceSlug });
  },
  staleTime: 15_000,
  retry: false,
});

const projects = $derived(($projectsQ.data ?? []) as Project[]);

const backendUnavailable = $derived(
  $projectsQ.isError && String(($projectsQ.error as Error)?.message ?? '').includes('404')
);

// ── Create modal ──────────────────────────────────────────────────────────

let modalOpen = $state(false);
let draft = $state<CreateProjectBody>({
  name: '',
  workspaceSlug: 'default',
  description: '',
  status: 'active',
});
let createError = $state<string | null>(null);

const createMut = createMutation(createProjectMutation());

async function submitProject() {
  if (!draft.name.trim()) return;
  createError = null;
  try {
    const body: CreateProjectBody = {
      name: draft.name.trim(),
      workspaceSlug,
      status: draft.status ?? 'active',
    };
    if (draft.description?.trim()) body.description = draft.description.trim();
    await $createMut.mutateAsync(body);
    await queryClient.invalidateQueries({ queryKey: ['projects'] });
    modalOpen = false;
    draft = { name: '', workspaceSlug: 'default', description: '', status: 'active' };
  } catch (err) {
    createError = err instanceof Error ? err.message : 'Failed to create project';
  }
}

function openModal() {
  createError = null;
  draft = { name: '', workspaceSlug, description: '', status: 'active' };
  modalOpen = true;
}

// ── Helpers ────────────────────────────────────────────────────────────────

function statusLabel(status: Project['status']): string {
  return { active: 'Active', paused: 'Paused', archived: 'Archived' }[status];
}
</script>

<div class="pj-page">
  <!-- Header -->
  <header class="pj-header">
    <div class="pj-header__left">
      <FolderKanban size={20} class="pj-header__icon" aria-hidden="true" />
      <h1 class="pj-title">Projects</h1>
      <span class="pj-count" aria-label="{projects.length} projects">
        {projects.length}
      </span>
    </div>
    <div style="display:flex;align-items:center;gap:var(--space-2)">
      <ViewPicker routeSlug="projects" bind:view />
      <button class="pj-new-btn" aria-label="New project" onclick={openModal}>
        <Plus size={14} aria-hidden="true" />
        New project
      </button>
    </div>
  </header>

  <!-- Backend 404 banner -->
  {#if backendUnavailable}
    <div class="pj-banner" role="status">
      Projects backend unreachable — ensure <code>GET /api/v1/projects</code> is responding.
    </div>
  {/if}

  <!-- Loading skeletons -->
  {#if $projectsQ.isLoading}
    <div class="pj-grid" aria-busy="true" aria-label="Loading projects">
      {#each Array(3) as _, i (i)}
        <div class="pj-card pj-card--skeleton" aria-hidden="true">
          <div class="pj-sk pj-sk--icon"></div>
          <div class="pj-sk pj-sk--title"></div>
          <div class="pj-sk pj-sk--body"></div>
        </div>
      {/each}
    </div>

  <!-- Error state (non-404) -->
  {:else if $projectsQ.isError && !backendUnavailable}
    <div class="pj-empty" role="alert">
      <p class="pj-empty__msg">Failed to load projects. Try refreshing.</p>
    </div>

  <!-- Empty state -->
  {:else if projects.length === 0}
    <div class="pj-empty" role="status">
      <FolderKanban size={40} class="pj-empty__icon" aria-hidden="true" />
      <p class="pj-empty__msg">No projects yet.</p>
      <p class="pj-empty__sub">
        Create a project to group your issues, tasks, and goals.
      </p>
    </div>

  <!-- Project cards -->
  {:else}
    <main class="pj-grid" aria-label="Projects">
      {#each projects as project (project.id)}
        <button
          class="pj-card"
          style={project.color ? `--pj-accent: ${project.color}` : ""}
          aria-label="Open {project.name}"
          onclick={() => goto(`/projects/${project.slug}`)}
        >
          <div class="pj-card__accent" aria-hidden="true"></div>
          <div class="pj-card__body">
            <div class="pj-card__head">
              <span class="pj-card__name">{project.name}</span>
              <span
                class="pj-card__status pj-card__status--{project.status}"
                aria-label="Status: {statusLabel(project.status)}"
              >
                {statusLabel(project.status)}
              </span>
            </div>
            {#if project.description}
              <p class="pj-card__desc">{project.description}</p>
            {/if}
            <div class="pj-card__slug">
              <code>{project.slug}</code>
            </div>
          </div>
        </button>
      {/each}
    </main>
  {/if}
</div>

<!-- New Project modal -->
{#if modalOpen}
  <div class="pj-overlay" role="dialog" aria-modal="true" aria-label="New project">
    <div class="pj-modal">
      <div class="pj-modal__head">
        <span class="pj-modal__label">New Project</span>
        <button
          class="pj-modal__close"
          onclick={() => { modalOpen = false; }}
          aria-label="Close"
        >
          <X size={14} aria-hidden="true" />
        </button>
      </div>

      <div class="pj-modal__body">
        <label class="pj-field">
          <span class="pj-field__label">Name</span>
          <input
            class="pj-input"
            type="text"
            placeholder="What is this project?"
            bind:value={draft.name}
            aria-required="true"
          />
        </label>

        <label class="pj-field">
          <span class="pj-field__label">Description</span>
          <textarea
            class="pj-input pj-textarea"
            placeholder="Scope and purpose..."
            bind:value={draft.description}
            rows={3}
          ></textarea>
        </label>

        <label class="pj-field">
          <span class="pj-field__label">Status</span>
          <select class="pj-select" bind:value={draft.status}>
            <option value="active">Active</option>
            <option value="paused">Paused</option>
            <option value="archived">Archived</option>
          </select>
        </label>

        {#if createError}
          <p class="pj-error">{createError}</p>
        {/if}
      </div>

      <div class="pj-modal__foot">
        <button
          class="pj-btn pj-btn--ghost"
          onclick={() => { modalOpen = false; }}
          disabled={$createMut.isPending}
        >
          Cancel
        </button>
        <button
          class="pj-btn pj-btn--primary"
          onclick={submitProject}
          disabled={$createMut.isPending || !draft.name.trim()}
        >
          {$createMut.isPending ? "Creating..." : "Create Project"}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .pj-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  /* Header */
  .pj-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-4);
    padding: var(--space-5) var(--space-6) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .pj-header__left {
    display: flex;
    align-items: center;
    gap: var(--space-3);
  }

  :global(.pj-header__icon) {
    color: var(--fg-muted);
  }

  .pj-title {
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
    letter-spacing: -0.025em;
  }

  .pj-count {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 22px;
    height: 22px;
    padding: 0 var(--space-1);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: 9999px;
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-muted);
  }

  .pj-new-btn {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    padding: var(--space-1) var(--space-3);
    background: color-mix(in oklch, var(--fg) 10%, transparent 90%);
    border: 1px solid var(--border-strong);
    border-radius: var(--radius-md);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    transition: background var(--dur-instant) var(--ease-out);
  }

  .pj-new-btn:hover {
    background: color-mix(in oklch, var(--fg) 16%, transparent 84%);
  }

  /* Banner */
  .pj-banner {
    margin: var(--space-3) var(--space-6);
    padding: var(--space-2) var(--space-3);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    flex-shrink: 0;
  }

  .pj-banner code {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-subtle);
  }

  /* Grid */
  .pj-grid {
    flex: 1;
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: var(--space-4);
    padding: var(--space-5) var(--space-6);
    overflow-y: auto;
    align-content: start;
  }

  /* Card — now a <button> for full clickability */
  .pj-card {
    position: relative;
    display: flex;
    flex-direction: column;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    overflow: hidden;
    cursor: pointer;
    text-align: left;
    transition: border-color var(--dur-instant) var(--ease-out);
    padding: 0;
  }

  .pj-card:hover {
    border-color: var(--border-strong);
  }

  .pj-card__accent {
    height: 3px;
    background: var(--pj-accent, var(--border-strong));
  }

  .pj-card__body {
    padding: var(--space-4);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .pj-card__head {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: var(--space-2);
  }

  .pj-card__name {
    font-family: var(--font-sans);
    font-size: var(--text-base);
    font-weight: 600;
    color: var(--fg);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .pj-card__status {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    padding: 2px var(--space-2);
    border-radius: 9999px;
    white-space: nowrap;
    flex-shrink: 0;
  }

  .pj-card__status--active {
    background: color-mix(in oklch, oklch(75% 0.18 145) 15%, transparent 85%);
    color: oklch(55% 0.18 145);
  }

  .pj-card__status--paused {
    background: color-mix(in oklch, oklch(75% 0.12 80) 15%, transparent 85%);
    color: oklch(55% 0.12 80);
  }

  .pj-card__status--archived {
    background: var(--bg-inset);
    color: var(--fg-subtle);
  }

  .pj-card__desc {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    line-height: 1.5;
    margin: 0;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  .pj-card__slug code {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  /* Skeleton */
  .pj-card--skeleton {
    pointer-events: none;
  }

  .pj-sk {
    background: var(--border);
    border-radius: var(--radius-sm);
    animation: pj-pulse 1.5s ease-in-out infinite;
  }

  .pj-sk--icon {
    width: 32px;
    height: 32px;
    border-radius: var(--radius-md);
  }

  .pj-sk--title {
    height: 18px;
    width: 60%;
  }

  .pj-sk--body {
    height: 40px;
    width: 90%;
  }

  @keyframes pj-pulse {
    0%, 100% { opacity: 0.3; }
    50% { opacity: 0.6; }
  }

  /* Empty state */
  .pj-empty {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--space-3);
    padding: var(--space-8);
    text-align: center;
  }

  :global(.pj-empty__icon) {
    color: var(--fg-subtle);
    opacity: 0.4;
  }

  .pj-empty__msg {
    font-family: var(--font-sans);
    font-size: var(--text-base);
    font-weight: 500;
    color: var(--fg-muted);
    margin: 0;
  }

  .pj-empty__sub {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    margin: 0;
  }

  /* Modal overlay */
  .pj-overlay {
    position: fixed;
    inset: 0;
    background: color-mix(in oklch, var(--bg) 60%, transparent 40%);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 50;
    padding: var(--space-4);
  }

  .pj-modal {
    background: var(--bg-elevated);
    border: 1px solid var(--border-strong);
    border-radius: var(--radius-xl);
    width: 100%;
    max-width: 480px;
    display: flex;
    flex-direction: column;
    box-shadow: 0 20px 60px color-mix(in oklch, var(--bg) 0%, transparent 70%);
  }

  .pj-modal__head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-4) var(--space-5);
    border-bottom: 1px solid var(--border);
  }

  .pj-modal__label {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
  }

  .pj-modal__close {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    background: transparent;
    border: none;
    border-radius: var(--radius-sm);
    cursor: pointer;
    color: var(--fg-muted);
  }

  .pj-modal__close:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .pj-modal__body {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-5);
  }

  .pj-modal__foot {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: var(--space-2);
    padding: var(--space-4) var(--space-5);
    border-top: 1px solid var(--border);
  }

  /* Form */
  .pj-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .pj-field__label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    color: var(--fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .pj-input,
  .pj-select {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    width: 100%;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .pj-input:focus,
  .pj-select:focus {
    border-color: var(--border-strong);
  }

  .pj-textarea {
    resize: vertical;
    min-height: 72px;
  }

  .pj-error {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: #f87171;
    margin: 0;
  }

  /* Buttons */
  .pj-btn {
    padding: var(--space-2) var(--space-4);
    border-radius: var(--radius-md);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    transition: background var(--dur-instant) var(--ease-out);
    border: 1px solid transparent;
  }

  .pj-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .pj-btn--ghost {
    background: transparent;
    color: var(--fg-muted);
    border-color: var(--border);
  }

  .pj-btn--ghost:not(:disabled):hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .pj-btn--primary {
    background: color-mix(in oklch, var(--fg) 10%, transparent 90%);
    border-color: var(--border-strong);
    color: var(--fg);
  }

  .pj-btn--primary:not(:disabled):hover {
    background: color-mix(in oklch, var(--fg) 16%, transparent 84%);
  }
</style>
