<script lang="ts">
  /**
   * IssueDetailActions — header action bar for the issue detail page.
   * Owns dispatch / complete / reopen / delete / properties-panel mutations
   * and the two-step delete confirmation UI.
   * CSS prefix: id- (shared with /issues/[short_id] page).
   */
  import {
    type CreateMutationOptions,
    createMutation,
    useQueryClient,
  } from '@tanstack/svelte-query';
  import { Trash2 } from 'lucide-svelte';
  import { goto } from '$app/navigation';
  import {
    completeIssueMutation,
    deleteIssueMutation,
    dispatchIssueMutation,
    reopenIssueMutation,
  } from '$lib/api/queries/issues.js';
  import IssueStatusPill from '$lib/design/patterns/IssueStatusPill.svelte';
  import type { Issue } from '$lib/domain/issues/types.js';
  import { toasts } from '$lib/stores/toasts.svelte.js';

  interface Props {
    issue: Issue;
    shortId: string;
    panelOpen: boolean;
    onPanelToggle: () => void;
    onInvalidate: () => void;
    onAllowNavigation: () => void;
  }

  let {
    issue,
    shortId,
    panelOpen,
    onPanelToggle,
    onInvalidate,
    onAllowNavigation,
  }: Props = $props();

  const queryClient = useQueryClient();

  const completeMut = createMutation<Issue, Error, string>(
    completeIssueMutation() as CreateMutationOptions<Issue, Error, string>,
  );
  const reopenMut = createMutation<Issue, Error, string>(
    reopenIssueMutation() as CreateMutationOptions<Issue, Error, string>,
  );
  const deleteMut = createMutation<void, Error, string>(
    deleteIssueMutation() as CreateMutationOptions<void, Error, string>,
  );
  const dispatchMut = createMutation<Issue, Error, string>(
    dispatchIssueMutation() as CreateMutationOptions<Issue, Error, string>,
  );

  // suppress unused-variable warning — queryClient used via invalidateQueries
  void queryClient;

  let deleteConfirm = $state(false);

  const isTerminal = $derived(issue.status === 'closed');

  function handleComplete(): void {
    $completeMut.mutate(shortId, {
      onSuccess: () => { onInvalidate(); toasts.success('Issue closed'); },
    });
  }

  function handleReopen(): void {
    $reopenMut.mutate(shortId, {
      onSuccess: () => { onInvalidate(); toasts.success('Issue reopened'); },
    });
  }

  function handleDispatch(): void {
    $dispatchMut.mutate(shortId, {
      onSuccess: (result) => {
        onInvalidate();
        toasts.success('Issue dispatched');
        if (result.sessionId) goto(`/sessions/${result.sessionId}`);
      },
      onError: (err: Error) => toasts.error(`Dispatch failed: ${err.message}`),
    });
  }

  function handleDelete(): void {
    $deleteMut.mutate(shortId, {
      onSuccess: () => {
        onAllowNavigation();
        toasts.success('Issue deleted');
        goto('/issues');
      },
      onError: (err: Error) => {
        toasts.error(`Delete failed: ${err.message}`);
        deleteConfirm = false;
      },
    });
  }
</script>

<div class="id-actions">
  <IssueStatusPill status={issue.status} />

  <button
    class="btn-pill btn-pill-secondary btn-pill-sm"
    onclick={handleDispatch}
    disabled={$dispatchMut.isPending || isTerminal}
    aria-label="Dispatch issue to agent"
  >
    {$dispatchMut.isPending ? 'Dispatching…' : 'Dispatch'}
  </button>

  {#if isTerminal}
    <button
      class="btn-pill btn-pill-secondary btn-pill-sm"
      onclick={handleReopen}
      disabled={$reopenMut.isPending}
      aria-label="Reopen issue"
    >{$reopenMut.isPending ? 'Reopening…' : 'Reopen'}</button>
  {:else}
    <button
      class="btn-pill btn-pill-primary btn-pill-sm"
      onclick={handleComplete}
      disabled={$completeMut.isPending}
      aria-label="Close issue"
    >{$completeMut.isPending ? 'Closing…' : 'Close'}</button>
  {/if}

  {#if !deleteConfirm}
    <button
      class="btn-compact btn-compact-ghost id-delete-btn"
      onclick={() => { deleteConfirm = true; }}
      aria-label="Delete issue"
    >
      <Trash2 size={13} aria-hidden="true" />
    </button>
  {:else}
    <button
      class="id-confirm-delete"
      onclick={handleDelete}
      disabled={$deleteMut.isPending}
      aria-label="Confirm delete"
    >{$deleteMut.isPending ? 'Deleting…' : 'Confirm delete'}</button>
    <button
      class="btn-compact btn-compact-ghost"
      onclick={() => { deleteConfirm = false; }}
      aria-label="Cancel delete"
    >Cancel</button>
  {/if}

  <button
    class="btn-compact btn-compact-secondary"
    onclick={onPanelToggle}
    aria-label="Toggle properties panel"
    aria-expanded={panelOpen}
  >Properties</button>
</div>

<style>
  .id-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-wrap: wrap;
  }

  .id-delete-btn { color: var(--signal-error, red); }

  .id-confirm-delete {
    background: color-mix(in oklch, red 80%, transparent 20%);
    color: white;
    border: none;
    border-radius: 9999px;
    padding: 4px 12px;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    cursor: pointer;
  }
</style>
