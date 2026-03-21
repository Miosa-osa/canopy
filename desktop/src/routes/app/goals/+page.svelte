<!-- src/routes/app/goals/+page.svelte -->
<script lang="ts">
  import type { Goal } from '$api/types';

  import PageShell from '$lib/components/layout/PageShell.svelte';
  import GoalHierarchy from '$lib/components/goals/GoalHierarchy.svelte';
  import GoalForm from '$lib/components/goals/GoalForm.svelte';
  import { goalsStore } from '$lib/stores/goals.svelte';
  import { projectsStore } from '$lib/stores/projects.svelte';

  let showForm = $state(false);

  // Derive the active project ID from the selected project, not from workspaces
  let activeProjectId = $derived(projectsStore.selected?.id ?? null);

  // Re-fetch goals whenever the active project changes.
  // This covers initial mount, workspace switches (which reset projectsStore.selected
  // via workspaceStore.setActiveWorkspace), and in-page project selection changes.
  $effect(() => {
    if (activeProjectId) {
      void goalsStore.fetchGoals(activeProjectId);
    } else {
      goalsStore.setActiveProject('');
    }
  });

  async function handleSubmit(data: Partial<Goal>) {
    await goalsStore.createGoal(data);
    showForm = false;
  }
</script>

<PageShell title="Goals" badge={goalsStore.totalCount > 0 ? goalsStore.totalCount : undefined}>
  {#snippet actions()}
    <div class="gp-actions">
      {#if goalsStore.totalCount > 0}
        <span class="gp-progress-summary" aria-label="Overall progress: {goalsStore.overallProgress}%">
          {goalsStore.overallProgress}% overall
        </span>
      {/if}
      <button
        class="gp-new-btn"
        onclick={() => showForm = true}
        aria-label="Create new goal"
        type="button"
      >
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true">
          <path d="M12 5v14M5 12h14" />
        </svg>
        New Goal
      </button>
    </div>
  {/snippet}

  <div class="gp-content">
    {#if goalsStore.loading && goalsStore.goals.length === 0}
      <div class="gp-loading" role="status" aria-label="Loading goals">
        <div class="gp-spinner" aria-hidden="true"></div>
        <span>Loading goals…</span>
      </div>
    {:else if goalsStore.goals.length === 0}
      <div class="gp-empty" role="status">
        <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.25" class="gp-empty-icon" aria-hidden="true">
          <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/>
        </svg>
        <h3>No goals yet</h3>
        <p>Create a goal to track progress across your project.</p>
        <button class="gp-empty-btn" onclick={() => showForm = true} type="button" aria-label="Create first goal">
          Create Goal
        </button>
      </div>
    {:else}
      <GoalHierarchy nodes={goalsStore.goals} />
    {/if}
  </div>
</PageShell>

{#if showForm}
  <GoalForm onSubmit={handleSubmit} onCancel={() => showForm = false} />
{/if}

<style>
  .gp-actions {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .gp-progress-summary {
    font-size: 12px;
    color: var(--text-tertiary);
  }

  .gp-new-btn {
    display: flex;
    align-items: center;
    gap: 6px;
    height: 30px;
    padding: 0 12px;
    background: var(--accent-primary);
    border: none;
    border-radius: var(--radius-sm);
    color: #fff;
    font-size: 12px;
    font-weight: 600;
    font-family: inherit;
    cursor: pointer;
    transition: opacity 150ms ease;
  }
  .gp-new-btn:hover { opacity: 0.9; }
  .gp-new-btn:focus-visible { outline: 2px solid var(--accent-primary); outline-offset: 2px; }

  .gp-content {
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  .gp-loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    height: 200px;
    color: var(--text-tertiary);
    font-size: 13px;
  }

  .gp-spinner {
    width: 24px;
    height: 24px;
    border: 2px solid var(--border-default);
    border-top-color: var(--accent-primary);
    border-radius: 50%;
    animation: gp-spin 0.7s linear infinite;
  }

  @keyframes gp-spin {
    to { transform: rotate(360deg); }
  }

  .gp-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 10px;
    height: 300px;
    color: var(--text-tertiary);
    text-align: center;
  }

  .gp-empty-icon { color: var(--text-muted); margin-bottom: 4px; }

  .gp-empty h3 {
    font-size: 15px;
    font-weight: 500;
    color: var(--text-secondary);
    margin: 0;
  }

  .gp-empty p {
    font-size: 13px;
    color: var(--text-tertiary);
    margin: 0;
    max-width: 280px;
  }

  .gp-empty-btn {
    height: 32px;
    padding: 0 16px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    color: var(--accent-primary);
    font-size: 13px;
    font-weight: 500;
    font-family: inherit;
    cursor: pointer;
    margin-top: 4px;
    transition: background 150ms ease;
  }
  .gp-empty-btn:hover { background: rgba(59,130,246,0.1); border-color: rgba(59,130,246,0.3); }
  .gp-empty-btn:focus-visible { outline: 2px solid var(--accent-primary); outline-offset: 2px; }
</style>
