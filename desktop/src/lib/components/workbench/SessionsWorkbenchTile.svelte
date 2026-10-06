<script lang="ts">
  import { goto } from "$app/navigation";
  import SessionList from "$lib/components/sessions/SessionList.svelte";
  import { sessionsStore } from "$lib/stores/sessions.svelte";
  import { workspaceStore } from "$lib/stores/workspace.svelte";
  import type { Session } from "$api/types";

  $effect(() => {
    void sessionsStore.fetch(workspaceStore.activeWorkspaceId ?? undefined);
  });

  function handleSelect(session: Session): void {
    void goto(`/app/sessions/${session.id}`);
  }
</script>

<div class="sessions-tile">
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

<style>
  .sessions-tile {
    height: 100%;
    min-height: 0;
    overflow: hidden;
  }
</style>

