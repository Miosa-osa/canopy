<script lang="ts">
/**
 * /workspaces — Workspace list page (docs/02-frontend-design.md §6).
 * Grid of WorkspaceCards. Empty state with "Create workspace" CTA.
 * Top bar: heading + "New workspace" pill button → TemplatePicker modal.
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { goto } from '$app/navigation';
import { FolderOpen } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { deleteWorkspaceMutation, workspacesQuery } from '$lib/api/queries/workspaces.js';
import TemplatePicker from '$lib/design/patterns/TemplatePicker.svelte';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import WorkspaceCard from '$lib/design/patterns/WorkspaceCard.svelte';
import type { Workspace } from '$lib/domain/workspaces/types.js';
import { useListKeyboard } from '$lib/utils/useListKeyboard.svelte.js';

const queryClient = useQueryClient();

const wsOptsStore = writable(
  untrack(() => workspacesQuery() as CreateQueryOptions<Workspace[]>)
);

const wsQ = createQuery<Workspace[]>(wsOptsStore);

const deleteMut = createMutation<void, Error, string>(
  deleteWorkspaceMutation() as CreateMutationOptions<void, Error, string>
);

const workspaces = $derived(($wsQ.data ?? []) as Workspace[]);

let pickerOpen = $state(false);

const kb = useListKeyboard({
  items: () => workspaces,
  onSelect: (ws) => goto(`/workspaces/${ws.slug}`),
  onRefresh: () => {
    queryClient.invalidateQueries({ queryKey: ['workspaces'] });
  },
});

function handleDelete(slug: string): void {
  $deleteMut.mutate(slug, {
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['workspaces'] });
    },
  });
}
</script>

<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
<div
  class="wp-page"
  role="region"
  aria-label="Workspaces list"
  onkeydown={kb.handleKeydown}
  tabindex="0"
>
  <!-- Header -->
  <header class="wp-header">
    <div class="wp-title-row">
      <h1 class="wp-title">Workspaces</h1>
      <button
        class="btn-pill btn-pill-primary btn-pill-sm"
        onclick={() => { pickerOpen = true; }}
        aria-label="Create a new workspace"
      >
        + New workspace
      </button>
    </div>
  </header>

  <!-- Grid -->
  <main class="wp-grid-wrap">
    {#if $wsQ.isLoading}
      <div class="wp-grid">
        {#each Array(6) as _, i (i)}
          <div class="wp-skeleton glass-card" aria-hidden="true">
            <div class="wp-sk wp-sk--icon"></div>
            <div class="wp-sk wp-sk--line wp-sk--wide"></div>
            <div class="wp-sk wp-sk--line wp-sk--medium"></div>
            <div class="wp-sk wp-sk--line wp-sk--narrow"></div>
          </div>
        {/each}
      </div>
    {:else if $wsQ.isError}
      <EmptyState
        icon={FolderOpen as never}
        title="Failed to load workspaces"
        body="Check your connection and try again."
        action="Retry"
        onAction={() => $wsQ.refetch()}
      />
    {:else if workspaces.length === 0}
      <EmptyState
        icon={FolderOpen as never}
        title="No workspaces yet"
        body="Create your first workspace from a starter template."
        action="Create workspace"
        onAction={() => { pickerOpen = true; }}
      />
    {:else}
      <div class="wp-grid">
        {#each workspaces as workspace (workspace.id)}
          <WorkspaceCard
            {workspace}
            onDelete={() => handleDelete(workspace.slug)}
          />
        {/each}
      </div>
    {/if}
  </main>
</div>

<TemplatePicker open={pickerOpen} onClose={() => { pickerOpen = false; }} />

<style>
  .wp-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  .wp-header {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-5) var(--space-6) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .wp-title-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .wp-title {
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
    letter-spacing: -0.025em;
  }

  .wp-grid-wrap {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-5) var(--space-6);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .wp-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--space-3);
  }

  @media (max-width: 900px) {
    .wp-grid { grid-template-columns: repeat(2, 1fr); }
  }

  @media (max-width: 600px) {
    .wp-grid { grid-template-columns: 1fr; }
  }

  /* Skeletons */
  .wp-skeleton {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-4);
    min-height: 160px;
  }

  .wp-sk {
    animation: wp-pulse 1.5s ease-in-out infinite;
    background: var(--border);
    border-radius: var(--radius-sm);
  }

  .wp-sk--icon { width: 32px; height: 32px; border-radius: var(--radius-sm); }
  .wp-sk--line { height: 12px; }
  .wp-sk--wide { width: 72%; }
  .wp-sk--medium { width: 50%; }
  .wp-sk--narrow { width: 38%; }

  @keyframes wp-pulse {
    0%, 100% { opacity: 0.35; }
    50% { opacity: 0.65; }
  }
</style>
