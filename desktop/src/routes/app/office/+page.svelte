<!-- src/routes/app/office/+page.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import VirtualOffice from '$lib/components/office/VirtualOffice.svelte';
  import LoadingSpinner from '$lib/components/shared/LoadingSpinner.svelte';
  import { agentsStore } from '$lib/stores/agents.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';

  let viewMode = $state<'2d' | '3d'>('2d');

  onMount(() => {
    void agentsStore.fetchAgents(workspaceStore.activeWorkspaceId ?? undefined);
  });
</script>

<PageShell
  title="Virtual Office"
  subtitle="{agentsStore.activeCount} active · {agentsStore.totalCount} total"
  noPadding
>
  {#snippet actions()}
    <span class="op-hint">Click an agent to inspect</span>
  {/snippet}

  {#snippet children()}
    {#if agentsStore.loading && agentsStore.agents.length === 0}
      <div class="op-loading" aria-label="Loading office" aria-live="polite">
        <LoadingSpinner size="md" />
        <span>Loading agents…</span>
      </div>
    {:else if agentsStore.error && agentsStore.agents.length === 0}
      <div class="op-error" role="alert">
        <p class="op-error-msg">Failed to load agents: {agentsStore.error}</p>
        <button
          class="op-retry-btn"
          onclick={() => void agentsStore.fetchAgents(workspaceStore.activeWorkspaceId ?? undefined)}
        >
          Retry
        </button>
      </div>
    {:else}
      <VirtualOffice
        agents={agentsStore.agents}
        {viewMode}
        onViewModeChange={(m) => { viewMode = m; }}
      />
    {/if}
  {/snippet}
</PageShell>

<style>
  .op-hint {
    font-size: 12px;
    color: var(--text-muted, #4a4870);
  }

  .op-loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    height: 100%;
    min-height: 300px;
    color: var(--text-tertiary);
    font-size: 13px;
  }

  .op-error {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    height: 100%;
    min-height: 300px;
  }

  .op-error-msg {
    font-size: 13px;
    color: #fca5a5;
    margin: 0;
  }

  .op-retry-btn {
    padding: 6px 16px;
    border-radius: 6px;
    border: 1px solid #2a2848;
    background: transparent;
    color: var(--text-secondary);
    font-size: 12px;
    cursor: pointer;
    transition: all 120ms ease;
  }

  .op-retry-btn:hover {
    background: #1e1e38;
    border-color: #3a3860;
    color: var(--text-primary);
  }
</style>
