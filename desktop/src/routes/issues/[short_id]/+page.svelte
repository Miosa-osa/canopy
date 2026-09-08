<script lang="ts">
/**
 * /issues/[short_id] — Issue detail: two-pane (main + sidebar).
 * CSS prefix: id- (IssueDetail)
 * LOC target: ≤ 280.
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { beforeNavigate, goto } from '$app/navigation';
import { page } from '$app/state';
import { ApiError } from '$lib/api/client.js';
import { issueQuery, updateIssueMutation } from '$lib/api/queries/issues.js';
import DirtyGuardModal from '$lib/design/patterns/DirtyGuardModal.svelte';
import ChangesPanel from '$lib/design/patterns/diff/ChangesPanel.svelte';
import IssueDetailActions from '$lib/design/patterns/issues/IssueDetailActions.svelte';
import IssueDetailMain from '$lib/design/patterns/issues/IssueDetailMain.svelte';
import IssueDetailSidebar from '$lib/design/patterns/issues/IssueDetailSidebar.svelte';
import ResizablePanel from '$lib/design/primitives/ResizablePanel.svelte';
import type {
  Issue,
  IssuePriority,
  IssueStatus,
  UpdateIssueBody,
} from '$lib/domain/issues/types.js';
import { toasts } from '$lib/stores/toasts.svelte.js';

const shortId = $derived(page.params.short_id ?? '');
const queryClient = useQueryClient();

// ── Query ─────────────────────────────────────────────────────────────────────

const queryOptsStore = writable(untrack(() => issueQuery(shortId) as CreateQueryOptions<Issue>));

$effect(() => {
  queryOptsStore.set(issueQuery(shortId) as CreateQueryOptions<Issue>);
});

const query = createQuery<Issue>(queryOptsStore);
const issue = $derived($query.data as Issue | undefined);

const backendUnavailable = $derived(
  $query.isError &&
    ($query.error instanceof ApiError
      ? $query.error.status === 404
      : String(($query.error as Error)?.message ?? '').includes('404'))
);

// ── Local edit state ──────────────────────────────────────────────────────────

let localTitle = $state('');
let localDesc = $state('');
let titleDirty = $state(false);
let descDirty = $state(false);
let panelOpen = $state(true);
let issueTab = $state<'properties' | 'changes'>('properties');

$effect(() => {
  if (issue && !titleDirty && !descDirty) {
    localTitle = issue.title;
    localDesc = issue.description ?? '';
  }
});

const isDirty = $derived(titleDirty || descDirty);

// ── Dirty guard ───────────────────────────────────────────────────────────────

let guardOpen = $state(false);
let pendingUrl = $state('');
let allowNavigation = $state(false);

beforeNavigate(({ to, cancel }) => {
  if (isDirty && !allowNavigation) {
    cancel();
    pendingUrl = to?.url.pathname ?? '/issues';
    guardOpen = true;
  }
});

function handleGuardCancel(): void {
  guardOpen = false;
  pendingUrl = '';
}
function handleGuardDiscard(): void {
  allowNavigation = true;
  guardOpen = false;
  goto(pendingUrl || '/issues');
}

// ── Update mutation (title / description / status / priority) ─────────────────

const updateMut = createMutation<Issue, Error, { shortId: string; body: UpdateIssueBody }>(
  updateIssueMutation() as CreateMutationOptions<
    Issue,
    Error,
    { shortId: string; body: UpdateIssueBody }
  >
);

function invalidate(): void {
  queryClient.invalidateQueries({ queryKey: ['issues', shortId] });
  queryClient.invalidateQueries({ queryKey: ['issues'] });
}

function saveTitle(): void {
  if (!issue || !titleDirty || !localTitle.trim()) return;
  $updateMut.mutate(
    { shortId, body: { title: localTitle.trim() } },
    {
      onSuccess: () => {
        titleDirty = false;
        invalidate();
        toasts.success('Title saved');
      },
      onError: (err: Error) => toasts.error(`Save failed: ${err.message}`),
    }
  );
}

function saveDescription(): void {
  if (!issue || !descDirty) return;
  $updateMut.mutate(
    { shortId, body: { description: localDesc } },
    {
      onSuccess: () => {
        descDirty = false;
        invalidate();
        toasts.success('Description saved');
      },
      onError: (err: Error) => toasts.error(`Save failed: ${err.message}`),
    }
  );
}

function updateStatus(status: IssueStatus): void {
  $updateMut.mutate({ shortId, body: { status } }, { onSuccess: invalidate });
}
function updatePriority(priority: IssuePriority): void {
  $updateMut.mutate({ shortId, body: { priority } }, { onSuccess: invalidate });
}
</script>

<svelte:window
  onkeydown={(e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 's') {
      e.preventDefault();
      if (descDirty) saveDescription();
      if (titleDirty) saveTitle();
    }
  }}
/>

<DirtyGuardModal open={guardOpen} onCancel={handleGuardCancel} onDiscard={handleGuardDiscard} />

<div class="id-shell">
  <!-- Header / breadcrumb + actions -->
  <header class="id-header">
    <nav class="id-breadcrumb" aria-label="Breadcrumb">
      <a class="id-bc-link" href="/issues">Issues</a>
      <span class="id-bc-sep" aria-hidden="true">/</span>
      <span class="id-bc-cur" aria-current="page">{shortId}</span>
    </nav>

    {#if issue}
      <IssueDetailActions
        {issue}
        {shortId}
        {panelOpen}
        onPanelToggle={() => { panelOpen = !panelOpen; }}
        onInvalidate={invalidate}
        onAllowNavigation={() => { allowNavigation = true; }}
      />
    {/if}
  </header>

  <!-- Body -->
  <div class="id-body">
    <ResizablePanel persistKey="issue.detail.sidebar" defaultSize={340} minSize={240} maxSize={560}>
      {#snippet left()}
        <IssueDetailMain
          {issue}
          isLoading={$query.isLoading}
          isError={$query.isError}
          {backendUnavailable}
          errorMessage={($query.error as Error)?.message ?? 'Failed to load issue.'}
          {localTitle}
          {localDesc}
          {titleDirty}
          {descDirty}
          isSaving={$updateMut.isPending}
          onTitleInput={(v) => { localTitle = v; titleDirty = true; }}
          onTitleBlur={saveTitle}
          onTitleKeydown={(e) => {
            if (e.key === 'Enter') { e.preventDefault(); saveTitle(); }
            if ((e.metaKey || e.ctrlKey) && e.key === 's') { e.preventDefault(); saveTitle(); }
          }}
          onSaveTitle={saveTitle}
          onDescInput={(v) => { localDesc = v; descDirty = true; }}
          onDescKeydown={(e) => {
            if ((e.metaKey || e.ctrlKey) && e.key === 's') { e.preventDefault(); saveDescription(); }
          }}
          onSaveDesc={saveDescription}
          onDiscardDesc={() => { localDesc = issue?.description ?? ''; descDirty = false; }}
        />
      {/snippet}

      {#snippet right()}
        {#if issue}
          {@const boundSessionId = issue.sessionId ?? null}
          {#if boundSessionId}
            <!-- Tab bar: Properties | Changes -->
            <div class="id-detail-tabs" role="tablist" aria-label="Issue detail tabs">
              {#each (['properties', 'changes'] as const) as tab (tab)}
                <button
                  class="id-detail-tab"
                  class:id-detail-tab--active={issueTab === tab}
                  role="tab"
                  aria-selected={issueTab === tab}
                  onclick={() => { issueTab = tab; }}
                >
                  {tab.charAt(0).toUpperCase() + tab.slice(1)}
                </button>
              {/each}
            </div>
            {#if issueTab === 'changes'}
              <div class="id-changes-pane">
                <ChangesPanel sessionId={boundSessionId} />
              </div>
            {:else}
              <IssueDetailSidebar
                {issue}
                open={panelOpen}
                onClose={() => { panelOpen = false; }}
                onUpdateStatus={updateStatus}
                onUpdatePriority={updatePriority}
              />
            {/if}
          {:else}
            <IssueDetailSidebar
              {issue}
              open={panelOpen}
              onClose={() => { panelOpen = false; }}
              onUpdateStatus={updateStatus}
              onUpdatePriority={updatePriority}
            />
          {/if}
        {/if}
      {/snippet}
    </ResizablePanel>
  </div>
</div>

<style>
  .id-shell {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  /* Header */
  .id-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-5);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    flex-wrap: wrap;
  }

  .id-breadcrumb {
    display: flex;
    align-items: center;
    gap: var(--space-1);
  }

  .id-bc-link {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    text-decoration: none;
    transition: color 0.12s ease;
  }
  .id-bc-link:hover { color: var(--fg); }

  .id-bc-sep {
    font-size: var(--text-sm);
    color: var(--fg-subtle);
  }

  .id-bc-cur {
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    color: var(--fg);
  }

  /* Body — ResizablePanel fills the flex child */
  .id-body {
    flex: 1;
    display: flex;
    overflow: hidden;
    padding: 0 var(--space-2) var(--space-2);
    min-height: 0;
  }

  .id-detail-tabs {
    display: flex;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    background: var(--bg-elevated);
    border-radius: var(--radius-lg) var(--radius-lg) 0 0;
  }

  .id-detail-tab {
    flex: 1;
    padding: var(--space-2) 0;
    border: none;
    background: transparent;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-subtle);
    cursor: pointer;
    border-bottom: 2px solid transparent;
    transition: color 0.1s ease, border-color 0.1s ease;
  }
  .id-detail-tab:hover:not(.id-detail-tab--active) { color: var(--fg-muted); }
  .id-detail-tab--active { color: var(--fg); border-bottom-color: var(--cnp-accent); }
  .id-detail-tab:focus-visible { outline: 2px solid var(--cnp-accent); outline-offset: -2px; }

  .id-changes-pane {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    border: 1px solid var(--border);
    border-top: none;
    border-radius: 0 0 var(--radius-lg) var(--radius-lg);
  }
</style>
