<!-- src/routes/app/issues/+page.svelte -->
<script lang="ts">
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import type { Issue } from '$api/types';

  import PageShell from '$lib/components/layout/PageShell.svelte';
  import IssueViewSwitcher from '$lib/components/issues/IssueViewSwitcher.svelte';
  import IssueKanban from '$lib/components/issues/IssueKanban.svelte';
  import IssueList from '$lib/components/issues/IssueList.svelte';
  import IssueTable from '$lib/components/issues/IssueTable.svelte';
  import IssueForm from '$lib/components/issues/IssueForm.svelte';
  import { issuesStore } from '$lib/stores/issues.svelte';
  import { agentsStore } from '$lib/stores/agents.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';

  type ViewMode = 'kanban' | 'list' | 'table';
  let viewMode = $state<ViewMode>('kanban');
  let showForm = $state(false);

  // Watch ?new=1 param
  $effect(() => {
    showForm = $page.url.searchParams.get('new') === '1';
  });

  // Re-fetch whenever the active workspace changes (covers onMount + workspace switches)
  $effect(() => {
    const wsId = workspaceStore.activeWorkspaceId ?? undefined;
    void Promise.all([
      issuesStore.fetchIssues(wsId),
      agentsStore.fetchAgents(wsId),
    ]);
  });

  function openNewIssue() {
    goto('?new=1');
  }

  function closeForm() {
    goto('?');
  }

  async function handleSubmit(data: Partial<Issue>) {
    await issuesStore.createIssue(data);
    closeForm();
  }
</script>

<PageShell title="Issues" badge={issuesStore.issues.length}>
  {#snippet actions()}
    <IssueViewSwitcher
      {viewMode}
      onViewChange={(m) => viewMode = m}
      onNewIssue={openNewIssue}
    />
  {/snippet}

  <div class="ip-content" class:ip-content--kanban={viewMode === 'kanban'}>
    {#if issuesStore.loading && issuesStore.issues.length === 0}
      <div class="ip-loading" role="status" aria-label="Loading issues">
        <div class="ip-spinner" aria-hidden="true"></div>
        <span>Loading issues…</span>
      </div>
    {:else if viewMode === 'kanban'}
      <IssueKanban />
    {:else if viewMode === 'list'}
      <IssueList issues={issuesStore.filteredIssues} />
    {:else}
      <IssueTable issues={issuesStore.filteredIssues} />
    {/if}
  </div>
</PageShell>

{#if showForm}
  <IssueForm onSubmit={handleSubmit} onCancel={closeForm} />
{/if}

<style>
  .ip-content {
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  .ip-content--kanban {
    overflow: hidden;
  }

  .ip-loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    height: 200px;
    color: var(--text-tertiary);
    font-size: 13px;
  }

  .ip-spinner {
    width: 24px;
    height: 24px;
    border: 2px solid var(--border-default);
    border-top-color: var(--accent-primary);
    border-radius: 50%;
    animation: ip-spin 0.7s linear infinite;
  }

  @keyframes ip-spin {
    to { transform: rotate(360deg); }
  }
</style>
