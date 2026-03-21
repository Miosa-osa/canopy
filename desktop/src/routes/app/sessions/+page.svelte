<!-- src/routes/app/sessions/+page.svelte -->
<!-- Sessions observability page: filterable list of all agent sessions -->
<script lang="ts">
  import { goto } from '$app/navigation';
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import SessionList from '$lib/components/sessions/SessionList.svelte';
  import { sessionsStore } from '$lib/stores/sessions.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';
  import type { Session } from '$api/types';

  // Re-fetch whenever the active workspace changes (covers onMount + workspace switches)
  $effect(() => {
    const wsId = workspaceStore.activeWorkspaceId ?? undefined;
    void sessionsStore.fetch(wsId);
  });

  function handleSelect(session: Session) {
    void goto(`/app/sessions/${session.id}`);
  }
</script>

<PageShell
  title="Sessions"
  subtitle="{sessionsStore.activeCount} active"
  badge={sessionsStore.totalCount}
>
  {#snippet children()}
    <div class="sp-layout">
      <SessionList
        sessions={sessionsStore.pagedSessions}
        loading={sessionsStore.loading}
        totalCount={sessionsStore.filteredSessions.length}
        page={sessionsStore.page}
        totalPages={sessionsStore.totalPages}
        searchValue={sessionsStore.filters.search}
        statusFilter={sessionsStore.filters.status}
        sortKey={sessionsStore.filters.sort}
        sortDir={sessionsStore.filters.sortDir}
        agentOptions={sessionsStore.agentOptions}
        agentFilter={sessionsStore.filters.agentId}
        onSearch={(q) => sessionsStore.setSearch(q)}
        onStatusFilter={(s) => sessionsStore.setStatusFilter(s)}
        onAgentFilter={(id) => sessionsStore.setAgentFilter(id)}
        onSort={(key) => sessionsStore.setSort(key)}
        onPageChange={(p) => sessionsStore.setPage(p)}
        onSelect={handleSelect}
      />
    </div>
  {/snippet}
</PageShell>

<style>
  .sp-layout {
    height: 100%;
    display: flex;
    flex-direction: column;
    /* Negative margin to let SessionList own its scroll and toolbar */
    margin: -20px -24px;
  }
</style>
