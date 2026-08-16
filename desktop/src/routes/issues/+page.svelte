<script lang="ts">
  /**
   * /issues — Issue list (developer persona). Linear-style dense rows, board secondary.
   * CSS prefix: il- (IssueList)
   * LOC target: ≤ 280.
   */
  import {
    type CreateMutationOptions,
    type CreateQueryOptions,
    createMutation,
    createQuery,
    useQueryClient,
  } from '@tanstack/svelte-query';
  import { Plus } from 'lucide-svelte';
  import { untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import { goto } from '$app/navigation';
  import {
    createIssueMutation,
    issuesQuery,
  } from '$lib/api/queries/issues.js';
  import NewIssueModal from '$lib/design/patterns/NewIssueModal.svelte';
  import { ApiError } from '$lib/api/client.js';
  import IssuesBoardView from '$lib/design/patterns/issues/IssuesBoardView.svelte';
  import IssuesListView from '$lib/design/patterns/issues/IssuesListView.svelte';
  import IssuesFilterBar from '$lib/design/patterns/issues/IssuesFilterBar.svelte';
  import type {
    CreateIssueBody,
    Issue,
    IssueFilters,
    IssueStatus,
  } from '$lib/domain/issues/types.js';
  import { toasts } from '$lib/stores/toasts.svelte.js';
  import ViewPicker from '$lib/design/primitives/ViewPicker.svelte';
  import type { ViewState } from '$lib/design/primitives/ViewPicker.svelte';

  const queryClient = useQueryClient();

  // ── View state (ViewPicker) ───────────────────────────────────────────────────

  let view = $state<ViewState>({ layout: 'list', density: 'comfortable', sort: 'recent' });
  const viewMode = $derived<'list' | 'board'>(view.layout === 'board' ? 'board' : 'list');

  // ── Status tabs ───────────────────────────────────────────────────────────────

  type StatusTab = 'all' | IssueStatus;
  let statusTab = $state<StatusTab>('all');

  // ── Assignee filter ───────────────────────────────────────────────────────────

  type AssigneeFilter = 'all' | 'human' | 'agent';
  let assigneeFilter = $state<AssigneeFilter>('all');

  // ── Query ─────────────────────────────────────────────────────────────────────

  const filters = $derived<IssueFilters>({
    status: statusTab !== 'all' ? (statusTab as IssueStatus) : undefined,
    assigneeType: assigneeFilter !== 'all' ? assigneeFilter : undefined,
  });

  const queryOptsStore = writable(
    untrack(() => issuesQuery(filters) as CreateQueryOptions<Issue[]>),
  );

  $effect(() => {
    queryOptsStore.set(issuesQuery(filters) as CreateQueryOptions<Issue[]>);
  });

  const query = createQuery<Issue[]>(queryOptsStore);
  // Deduplicate by id — API can return the same issue record more than once
  // when pagination cursors overlap, causing Svelte each_key_duplicate errors.
  const issues = $derived(
    Array.from(
      new Map(($query.data ?? []).map((i) => [i.id, i])).values(),
    ) as Issue[],
  );

  const backendUnavailable = $derived(
    $query.isError &&
      ($query.error instanceof ApiError
        ? $query.error.status === 404
        : String(($query.error as Error)?.message ?? '').includes('404')),
  );

  // ── New-issue modal ───────────────────────────────────────────────────────────

  let newIssueOpen = $state(false);

  const createMut = createMutation<Issue, Error, CreateIssueBody>(
    createIssueMutation() as CreateMutationOptions<Issue, Error, CreateIssueBody>,
  );

  function handleCreate(body: CreateIssueBody): void {
    $createMut.mutate(body, {
      onSuccess: (issue) => {
        queryClient.invalidateQueries({ queryKey: ['issues'] });
        toasts.success('Issue created');
        newIssueOpen = false;
        goto(`/issues/${issue.shortId}`);
      },
      onError: (err: Error) => {
        toasts.error(`Create failed: ${err.message}`);
      },
    });
  }
</script>

<div class="il-page">
  <!-- Header -->
  <header class="il-header">
    <h1 class="il-title">Issues</h1>

    <!-- ViewPicker (replaces manual list/board toggle) -->
    <ViewPicker routeSlug="issues" bind:view boardEnabled={true} />

    <button
      class="btn-pill btn-pill-primary btn-pill-sm il-new-btn"
      onclick={() => (newIssueOpen = true)}
      aria-label="Create new issue"
    >
      <Plus size={12} aria-hidden="true" />
      New issue
    </button>
  </header>

  <!-- Status tabs + assignee filter -->
  <IssuesFilterBar
    {statusTab}
    {assigneeFilter}
    onStatusChange={(tab) => { statusTab = tab; }}
    onAssigneeChange={(filter) => { assigneeFilter = filter; }}
  />

  <!-- Backend-not-ready banner -->
  {#if backendUnavailable}
    <div class="il-backend-banner" role="status">
      Backend not ready — retry later. Issues endpoint returning 404.
    </div>
  {/if}

  <!-- Board view -->
  {#if viewMode === 'board'}
    <IssuesBoardView {issues} />

  <!-- List view (loading / error / empty / rows) -->
  {:else}
    <IssuesListView
      {issues}
      isLoading={$query.isLoading}
      isError={$query.isError && !backendUnavailable}
      errorMessage={($query.error as Error)?.message || 'Check your connection and try again.'}
      statusTab={statusTab}
      assigneeFilter={assigneeFilter}
      onRetry={() => $query.refetch()}
      onNewIssue={() => { newIssueOpen = true; }}
    />
  {/if}
</div>

<!-- New issue modal -->
{#if newIssueOpen}
  <NewIssueModal
    onSubmit={handleCreate}
    onClose={() => (newIssueOpen = false)}
    isPending={$createMut.isPending}
  />
{/if}

<style>
  .il-page {
    display: flex;
    flex-direction: column;
    gap: 0;
    height: 100%;
    overflow: hidden;
  }

  /* Header */
  .il-header {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-5) var(--space-6) var(--space-3);
    flex-shrink: 0;
  }

  .il-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: -0.025em;
    flex: 1;
  }

  .il-new-btn {
    display: flex;
    align-items: center;
    gap: 4px;
    flex-shrink: 0;
  }

  /* Backend banner */
  .il-backend-banner {
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
</style>
