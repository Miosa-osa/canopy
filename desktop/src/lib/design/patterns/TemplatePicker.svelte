<script lang="ts">
/**
 * TemplatePicker — modal for selecting a starter template and creating a workspace.
 * Fetches templates from workspaceTemplatesQuery(). 2x2 grid of template cards.
 * After selection: mini form → createWorkspaceMutation → navigate to /workspaces/:slug.
 * CSS prefix: tp- (TemplatePicker)
 * LOC target: ≤ 250
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { goto } from '$app/navigation';
import { createWorkspaceMutation, startInitJob, workspaceTemplatesQuery } from '$lib/api/queries/workspaces.js';
import type { CreateWorkspaceBody, Workspace, WorkspaceTemplate } from '$lib/domain/workspaces/types.js';

interface Props {
  open: boolean;
  onClose: () => void;
}

let { open, onClose }: Props = $props();

const queryClient = useQueryClient();

const templatesQ = createQuery<WorkspaceTemplate[]>(
  workspaceTemplatesQuery() as CreateQueryOptions<WorkspaceTemplate[]>
);

const createMut = createMutation<Workspace, Error, CreateWorkspaceBody>(
  createWorkspaceMutation() as CreateMutationOptions<Workspace, Error, CreateWorkspaceBody>
);

const TEMPLATE_EMOJI: Record<string, string> = {
  blank: '📄',
  'sales-engine': '💼',
  'dev-shop': '⚙️',
  'content-factory': '🎬',
};

let selectedTemplate = $state<WorkspaceTemplate | null>(null);
let formSlug = $state('');
let formRootPath = $state('');
let formDescription = $state('');
let formCloneUrl = $state('');
let formError = $state('');

function isValidCloneUrl(url: string): boolean {
  return url === '' || url.startsWith('http') || url.startsWith('git@');
}

function selectTemplate(t: WorkspaceTemplate): void {
  selectedTemplate = t;
  formSlug = t.slug;
  formRootPath = `~/canopy-workspaces/${t.slug}`;
  formDescription = '';
  formCloneUrl = '';
  formError = '';
}

function handleClose(): void {
  selectedTemplate = null;
  formSlug = '';
  formRootPath = '';
  formDescription = '';
  formCloneUrl = '';
  formError = '';
  onClose();
}

function handleBack(): void {
  selectedTemplate = null;
  formError = '';
}

async function handleSubmit(e: SubmitEvent): Promise<void> {
  e.preventDefault();
  formError = '';

  if (!formSlug.trim()) {
    formError = 'Slug is required.';
    return;
  }
  if (!formRootPath.trim()) {
    formError = 'Root path is required.';
    return;
  }
  if (formCloneUrl.trim() && !isValidCloneUrl(formCloneUrl.trim())) {
    formError = 'Clone URL must start with http or git@.';
    return;
  }

  const body: CreateWorkspaceBody = {
    slug: formSlug.trim(),
    name: selectedTemplate?.name,
    rootPath: formRootPath.trim(),
    description: formDescription.trim() || null,
    templateSlug: selectedTemplate?.slug ?? null,
  };

  $createMut.mutate(body, {
    onSuccess: async (workspace) => {
      queryClient.invalidateQueries({ queryKey: ['workspaces'] });
      // Fire init job if clone URL was provided — store job_id so detail page picks it up
      const cloneUrl = formCloneUrl.trim() || undefined;
      if (cloneUrl) {
        try {
          const resp = await startInitJob(workspace.slug, cloneUrl);
          if (typeof window !== 'undefined') {
            sessionStorage.setItem(`canopy.ws.${workspace.slug}.init_job_id`, resp.jobId);
          }
        } catch {
          // Non-fatal — workspace was created; user can retry init from detail page
        }
      }
      handleClose();
      void goto(`/workspaces/${workspace.slug}`);
    },
    onError: (err) => {
      formError = err.message ?? 'Failed to create workspace.';
    },
  });
}

function handleBackdropClick(e: MouseEvent): void {
  if (e.target === e.currentTarget) handleClose();
}

function handleKeydown(e: KeyboardEvent): void {
  if (e.key === 'Escape') handleClose();
}
</script>

{#if open}
  <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
  <div
    class="tp-backdrop"
    role="dialog"
    tabindex="-1"
    aria-modal="true"
    aria-label="Choose a workspace template"
    onclick={handleBackdropClick}
    onkeydown={handleKeydown}
  >
    <div class="tp-modal glass-panel">
      <!-- Header -->
      <div class="tp-header">
        <h2 class="tp-title">
          {selectedTemplate ? 'Configure workspace' : 'New workspace'}
        </h2>
        <button
          class="btn-compact btn-compact-ghost tp-close"
          aria-label="Close"
          onclick={handleClose}
        >
          ✕
        </button>
      </div>

      {#if !selectedTemplate}
        <!-- Template grid -->
        {#if $templatesQ.isLoading}
          <div class="tp-grid tp-grid--loading" aria-busy="true" aria-label="Loading templates">
            {#each Array(4) as _, i (i)}
              <div class="tp-skeleton" aria-hidden="true">
                <div class="tp-sk tp-sk--icon"></div>
                <div class="tp-sk tp-sk--line tp-sk--wide"></div>
                <div class="tp-sk tp-sk--line tp-sk--medium"></div>
              </div>
            {/each}
          </div>
        {:else if $templatesQ.isError}
          <p class="tp-error">Failed to load templates. Please try again.</p>
        {:else}
          <div class="tp-grid">
            {#each ($templatesQ.data ?? []) as t (t.slug)}
              <button
                class="tp-template glass-card"
                onclick={() => selectTemplate(t)}
                aria-label="Select {t.name} template"
              >
                <span class="tp-t-icon" aria-hidden="true">
                  {TEMPLATE_EMOJI[t.slug] ?? '📁'}
                </span>
                <p class="tp-t-name">{t.name}</p>
                <p class="tp-t-desc">{t.description}</p>
                <p class="tp-t-count">{t.files.length} file{t.files.length !== 1 ? 's' : ''}</p>
                <span class="btn-pill btn-pill-secondary btn-pill-sm tp-t-select">Select</span>
              </button>
            {/each}
          </div>
        {/if}
      {:else}
        <!-- Create form -->
        <form class="tp-form" onsubmit={handleSubmit}>
          <div class="tp-form-template">
            <span class="tp-form-icon" aria-hidden="true">
              {TEMPLATE_EMOJI[selectedTemplate.slug] ?? '📁'}
            </span>
            <span class="tp-form-tname">{selectedTemplate.name}</span>
          </div>

          <div class="tp-field">
            <label class="tp-label" for="tp-slug">Slug</label>
            <input
              id="tp-slug"
              class="tp-input"
              type="text"
              bind:value={formSlug}
              placeholder="my-workspace"
              autocomplete="off"
              spellcheck="false"
              required
            />
          </div>

          <div class="tp-field">
            <label class="tp-label" for="tp-root">Root path</label>
            <input
              id="tp-root"
              class="tp-input tp-input--mono"
              type="text"
              bind:value={formRootPath}
              placeholder="~/canopy-workspaces/my-workspace"
              autocomplete="off"
              spellcheck="false"
              required
            />
          </div>

          <div class="tp-field">
            <label class="tp-label" for="tp-desc">Description <span class="tp-optional">(optional)</span></label>
            <input
              id="tp-desc"
              class="tp-input"
              type="text"
              bind:value={formDescription}
              placeholder="What is this workspace for?"
            />
          </div>

          <div class="tp-field">
            <label class="tp-label" for="tp-clone">Git clone URL <span class="tp-optional">(optional — triggers init)</span></label>
            <input
              id="tp-clone"
              class="tp-input tp-input--mono"
              type="text"
              bind:value={formCloneUrl}
              placeholder="https://github.com/org/repo.git"
              autocomplete="off"
              spellcheck="false"
            />
          </div>

          {#if formError}
            <p class="tp-form-error" role="alert">{formError}</p>
          {/if}

          <div class="tp-form-actions">
            <button type="button" class="btn-pill btn-pill-ghost btn-pill-sm" onclick={handleBack}>
              ← Back
            </button>
            <button
              type="submit"
              class="btn-pill btn-pill-primary btn-pill-sm"
              disabled={$createMut.isPending}
            >
              {#if $createMut.isPending}
                <span class="btn-pill-spinner" aria-hidden="true"></span>
                Creating…
              {:else}
                Create workspace
              {/if}
            </button>
          </div>
        </form>
      {/if}
    </div>
  </div>
{/if}

<style>
  .tp-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.6);
    backdrop-filter: blur(4px);
    -webkit-backdrop-filter: blur(4px);
    z-index: 100;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: var(--space-4);
  }

  .tp-modal {
    width: 100%;
    max-width: 560px;
    max-height: 80vh;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-5);
  }

  .tp-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-shrink: 0;
  }

  .tp-title {
    font-family: var(--font-sans);
    font-size: var(--text-lg);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
    letter-spacing: -0.02em;
  }

  .tp-close {
    font-size: 14px;
    line-height: 1;
  }

  .tp-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: var(--space-3);
  }

  .tp-grid--loading {
    opacity: 0.6;
  }

  .tp-template {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-4);
    text-align: left;
    cursor: pointer;
    border: none;
    background: none;
    font-family: inherit;
    outline: none;
    transition: transform 0.15s ease;
  }

  .tp-template:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .tp-t-icon {
    font-size: 28px;
    line-height: 1;
  }

  .tp-t-name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
  }

  .tp-t-desc {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    margin: 0;
    line-height: 1.4;
    flex: 1;
  }

  .tp-t-count {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    margin: 0;
  }

  .tp-t-select {
    align-self: flex-start;
    margin-top: var(--space-1);
  }

  /* Skeleton */
  .tp-skeleton {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-4);
    border-radius: var(--radius-xl);
    border: 1px solid var(--border);
    background: var(--bg-elevated);
  }

  .tp-sk {
    background: var(--border);
    border-radius: var(--radius-sm);
    animation: tp-pulse 1.5s ease-in-out infinite;
  }

  .tp-sk--icon { width: 28px; height: 28px; border-radius: var(--radius-sm); }
  .tp-sk--line { height: 12px; }
  .tp-sk--wide { width: 75%; }
  .tp-sk--medium { width: 55%; }

  @keyframes tp-pulse {
    0%, 100% { opacity: 0.35; }
    50% { opacity: 0.65; }
  }

  .tp-error {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--signal-error);
    margin: 0;
    text-align: center;
  }

  /* Form */
  .tp-form {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  .tp-form-template {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .tp-form-icon {
    font-size: 20px;
    line-height: 1;
  }

  .tp-form-tname {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg-muted);
  }

  .tp-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .tp-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    letter-spacing: 0.01em;
  }

  .tp-optional {
    color: var(--fg-subtle);
    font-weight: 400;
  }

  .tp-input {
    width: 100%;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    transition: border-color 0.15s ease;
    box-sizing: border-box;
  }

  .tp-input--mono {
    font-family: var(--font-mono);
    font-size: 12px;
  }

  .tp-input:focus {
    border-color: var(--border-strong);
  }

  .tp-input::placeholder {
    color: var(--fg-subtle);
  }

  .tp-form-error {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--signal-error);
    margin: 0;
  }

  .tp-form-actions {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
</style>
