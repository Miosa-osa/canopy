<!-- src/routes/app/agents/+page.svelte -->
<script lang="ts">
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import AgentRosterHeader from '$lib/components/agents/AgentRosterHeader.svelte';
  import AgentCard from '$lib/components/agents/AgentCard.svelte';
  import AgentTable from '$lib/components/agents/AgentTable.svelte';
  import HireAgentDialog from '$lib/components/agents/HireAgentDialog.svelte';
  import LoadingSpinner from '$lib/components/shared/LoadingSpinner.svelte';
  import { agentsStore } from '$lib/stores/agents.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';

  // Re-fetch whenever the active workspace changes (including after backend sync)
  $effect(() => {
    const wsId = workspaceStore.activeWorkspaceId ?? undefined;
    void agentsStore.fetchAgents(wsId);
  });

  let showHireDialog = $state(false);
</script>

<PageShell
  title="Agents"
  subtitle="{agentsStore.activeCount} active"
>
  {#snippet children()}
    {#if agentsStore.loading && agentsStore.agents.length === 0}
      <div class="ar-loading" aria-label="Loading agents" aria-live="polite">
        <LoadingSpinner size="md" />
        <span>Loading agents…</span>
      </div>
    {:else}
      <AgentRosterHeader onHire={() => showHireDialog = true} />

      {#if agentsStore.viewMode === 'grid'}
        {#if agentsStore.filteredAgents.length === 0}
          <div class="ar-empty" role="status" aria-live="polite">
            <span class="ar-empty-icon" aria-hidden="true">🤖</span>
            <p class="ar-empty-text">
              {agentsStore.searchQuery || agentsStore.filterStatus !== 'all'
                ? 'No agents match the current filter.'
                : 'No agents yet. Hire your first agent to get started.'}
            </p>
          </div>
        {:else}
          <div class="ar-grid" role="list" aria-label="Agent roster">
            {#each agentsStore.filteredAgents as agent (agent.id)}
              <div role="listitem">
                <AgentCard {agent} />
              </div>
            {/each}
          </div>
        {/if}

      {:else if agentsStore.viewMode === 'table'}
        <AgentTable agents={agentsStore.filteredAgents} />

      {:else}
        <div class="ar-org-placeholder" role="status">
          <span class="ar-empty-icon" aria-hidden="true">🌐</span>
          <p class="ar-empty-text">Org chart view coming soon.</p>
        </div>
      {/if}
    {/if}
  {/snippet}
</PageShell>

<HireAgentDialog open={showHireDialog} onClose={() => showHireDialog = false} />

<style>
  .ar-loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    height: 200px;
    color: var(--text-tertiary);
    font-size: 13px;
  }

  .ar-grid {
    display: flex;
    flex-wrap: wrap;
    gap: 16px;
    align-content: flex-start;
  }

  .ar-empty,
  .ar-org-placeholder {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    height: 240px;
  }

  .ar-empty-icon {
    font-size: 40px;
    opacity: 0.4;
  }

  .ar-empty-text {
    font-size: 13px;
    color: var(--text-tertiary);
    text-align: center;
    margin: 0;
    max-width: 320px;
  }
</style>
