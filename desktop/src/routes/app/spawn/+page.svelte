<!-- src/routes/app/spawn/+page.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import SpawnForm from '$lib/components/spawn/SpawnForm.svelte';
  import SpawnPresets from '$lib/components/spawn/SpawnPresets.svelte';
  import ActiveInstances from '$lib/components/spawn/ActiveInstances.svelte';
  import SpawnHistory from '$lib/components/spawn/SpawnHistory.svelte';
  import LoadingSpinner from '$lib/components/shared/LoadingSpinner.svelte';
  import { spawnStore } from '$lib/stores/spawn.svelte';
  import { agentsStore } from '$lib/stores/agents.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';

  let formRef: SpawnForm | undefined = $state();

  function handlePreset(preset: { task: string; model?: string }) {
    formRef?.applyPrefill(preset);
  }

  async function handleSpawn(data: {
    agent_id: string;
    task: string;
    model?: string;
  }) {
    await spawnStore.createSpawn(data);
  }

  // Re-fetch agents whenever the active workspace changes (covers onMount + workspace switches)
  $effect(() => {
    const wsId = workspaceStore.activeWorkspaceId ?? undefined;
    void agentsStore.fetchAgents(wsId);
  });

  onMount(() => {
    return spawnStore.startPolling(5_000);
  });
</script>

<PageShell
  title="Spawn"
  badge={spawnStore.activeCount > 0 ? spawnStore.activeCount : undefined}
>
  {#if spawnStore.loading && spawnStore.instances.length === 0}
    <div class="sp-loading" aria-label="Loading spawn instances">
      <LoadingSpinner label="Loading…" />
    </div>
  {:else}
    <div class="sp-layout">
      <!-- Left column: form + presets -->
      <div class="sp-left">
        <section class="sp-section" aria-label="Create spawn">
          <h2 class="sp-section-title">New spawn</h2>
          <div class="sp-form-card">
            <SpawnForm bind:this={formRef} onSubmit={handleSpawn} />
          </div>
        </section>

        <SpawnPresets onSelect={handlePreset} />
      </div>

      <!-- Right column: active instances -->
      <div class="sp-right">
        <ActiveInstances instances={spawnStore.activeInstances} />
      </div>
    </div>

    <!-- History below full-width -->
    {#if spawnStore.completedInstances.length > 0}
      <div class="sp-history">
        <SpawnHistory instances={spawnStore.completedInstances} />
      </div>
    {/if}
  {/if}
</PageShell>

<style>
  /* ── Loading ── */
  .sp-loading {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 200px;
  }

  /* ── Two-column layout ── */
  .sp-layout {
    display: grid;
    grid-template-columns: 360px 1fr;
    gap: 20px;
    align-items: start;
    margin-bottom: 24px;
  }

  .sp-left {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .sp-right {
    min-width: 0;
  }

  /* ── Section ── */
  .sp-section {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .sp-section-title {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    color: var(--text-tertiary);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin: 0;
  }

  .sp-form-card {
    background: var(--glass-bg);
    backdrop-filter: var(--glass-blur);
    border: 1px solid var(--glass-border);
    border-radius: var(--radius-md);
    padding: 16px;
  }

  /* ── History ── */
  .sp-history {
    margin-top: 4px;
  }

  /* ── Responsive ── */
  @media (max-width: 820px) {
    .sp-layout {
      grid-template-columns: 1fr;
    }
  }
</style>
