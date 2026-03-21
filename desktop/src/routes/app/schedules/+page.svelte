<!-- src/routes/app/schedules/+page.svelte -->
<script lang="ts">
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import ScheduleTimeline from '$lib/components/schedules/ScheduleTimeline.svelte';
  import ScheduleCard from '$lib/components/schedules/ScheduleCard.svelte';
  import ScheduleForm from '$lib/components/schedules/ScheduleForm.svelte';
  import RunHistory from '$lib/components/schedules/RunHistory.svelte';
  import WakeupQueue from '$lib/components/schedules/WakeupQueue.svelte';
  import LoadingSpinner from '$lib/components/shared/LoadingSpinner.svelte';
  import { schedulesStore } from '$lib/stores/schedules.svelte';
  import { agentsStore } from '$lib/stores/agents.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';
  import type { Schedule } from '$api/types';

  // Modal state
  let modalOpen = $state(false);
  let editTarget = $state<Schedule | undefined>(undefined);

  // All runs flattened from the history cache
  const allRuns = $derived(
    Object.values(schedulesStore.runHistory).flat(),
  );

  const pendingRuns = $derived(allRuns.filter((r) => r.status === 'pending'));

  function openCreate() {
    editTarget = undefined;
    modalOpen = true;
  }

  function openEdit(schedule: Schedule) {
    editTarget = schedule;
    modalOpen = true;
  }

  function closeModal() {
    modalOpen = false;
    editTarget = undefined;
  }

  async function handleSubmit(data: {
    agent_id: string;
    cron: string;
    context: string;
    enabled: boolean;
  }) {
    if (editTarget) {
      await schedulesStore.updateSchedule(editTarget.id, {
        cron: data.cron,
        context: data.context,
        enabled: data.enabled,
      });
    } else {
      await schedulesStore.createSchedule({
        agent_id: data.agent_id,
        cron: data.cron,
        context: data.context || undefined,
      });
    }
    closeModal();
  }

  // Re-fetch whenever the active workspace changes (covers onMount + workspace switches)
  $effect(() => {
    const wsId = workspaceStore.activeWorkspaceId ?? undefined;
    void Promise.all([
      schedulesStore.fetchSchedules(wsId),
      agentsStore.fetchAgents(wsId),
    ]).then(() => {
      // Fetch run history for each schedule after the schedule list has loaded
      for (const schedule of schedulesStore.schedules) {
        schedulesStore.fetchRunHistory(schedule.id);
      }
    });
  });
</script>

<PageShell
  title="Schedules"
  badge={schedulesStore.totalCount || undefined}
>
  {#snippet actions()}
    <button
      class="sch-new-btn"
      onclick={openCreate}
      aria-label="Create new schedule"
      type="button"
    >
      <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true">
        <path d="M12 5v14M5 12h14" />
      </svg>
      New schedule
    </button>
  {/snippet}

  {#if schedulesStore.loading && schedulesStore.schedules.length === 0}
    <div class="sch-loading" aria-label="Loading schedules">
      <LoadingSpinner label="Loading schedules…" />
    </div>
  {:else}
    <div class="sch-layout">
      <!-- Timeline -->
      <div class="sch-timeline-wrap">
        <ScheduleTimeline schedules={schedulesStore.schedules} />
      </div>

      <!-- Main content: cards + sidebar -->
      <div class="sch-main">
        <!-- Schedule cards grid -->
        <div class="sch-cards">
          {#if schedulesStore.schedules.length === 0}
            <div class="sch-empty">
              <p class="sch-empty-text">No schedules yet.</p>
              <button
                class="sch-empty-action"
                onclick={openCreate}
                aria-label="Create your first schedule"
                type="button"
              >
                Create one
              </button>
            </div>
          {:else}
            {#each schedulesStore.schedules as schedule (schedule.id)}
              <ScheduleCard {schedule} onEdit={openEdit} />
            {/each}
          {/if}
        </div>

        <!-- Sidebar: wake-up queue + run history -->
        <aside class="sch-sidebar" aria-label="Schedules sidebar">
          <WakeupQueue runs={pendingRuns} />

          {#if allRuns.length > 0}
            <div class="sch-history-section">
              <h2 class="sch-section-title">Recent runs</h2>
              <RunHistory runs={allRuns.slice(0, 20)} />
            </div>
          {/if}
        </aside>
      </div>
    </div>
  {/if}
</PageShell>

<!-- Modal -->
{#if modalOpen}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="sch-modal-backdrop"
    onclick={(e) => { if (e.target === e.currentTarget) closeModal(); }}
    role="dialog"
    aria-modal="true"
    aria-label={editTarget ? 'Edit schedule' : 'Create schedule'}
    tabindex="-1"
  >
    <div class="sch-modal">
      <div class="sch-modal-header">
        <h2 class="sch-modal-title">
          {editTarget ? 'Edit schedule' : 'New schedule'}
        </h2>
        <button
          class="sch-modal-close"
          onclick={closeModal}
          aria-label="Close modal"
          type="button"
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true">
            <path d="M18 6L6 18M6 6l12 12" />
          </svg>
        </button>
      </div>
      <div class="sch-modal-body">
        <ScheduleForm
          schedule={editTarget}
          onSubmit={handleSubmit}
          onCancel={closeModal}
        />
      </div>
    </div>
  </div>
{/if}

<style>
  /* ── New button ── */
  .sch-new-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 12px;
    border-radius: var(--radius-sm);
    border: none;
    background: var(--accent-primary);
    color: #fff;
    font-family: var(--font-sans);
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: background var(--transition-fast) ease;
  }

  .sch-new-btn:hover {
    background: #2563eb;
  }

  .sch-new-btn:focus-visible {
    outline: 2px solid var(--accent-primary);
    outline-offset: 3px;
  }

  /* ── Loading ── */
  .sch-loading {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 200px;
  }

  /* ── Layout ── */
  .sch-layout {
    display: flex;
    flex-direction: column;
    gap: 20px;
  }

  .sch-timeline-wrap {
    width: 100%;
  }

  .sch-main {
    display: grid;
    grid-template-columns: 1fr 280px;
    gap: 20px;
    align-items: start;
  }

  /* ── Cards grid ── */
  .sch-cards {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
    gap: 12px;
    align-content: start;
  }

  /* ── Empty state ── */
  .sch-empty {
    grid-column: 1 / -1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 10px;
    padding: 48px 24px;
    border: 1px dashed var(--border-default);
    border-radius: var(--radius-md);
    text-align: center;
  }

  .sch-empty-text {
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--text-tertiary);
    margin: 0;
  }

  .sch-empty-action {
    padding: 6px 14px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-default);
    background: var(--bg-elevated);
    color: var(--accent-primary);
    font-family: var(--font-sans);
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    transition: background var(--transition-fast) ease;
  }

  .sch-empty-action:hover {
    background: rgba(59, 130, 246, 0.1);
  }

  .sch-empty-action:focus-visible {
    outline: 2px solid var(--accent-primary);
    outline-offset: 2px;
  }

  /* ── Sidebar ── */
  .sch-sidebar {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .sch-history-section {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .sch-section-title {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    color: var(--text-tertiary);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin: 0;
  }

  /* ── Modal ── */
  .sch-modal-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.6);
    backdrop-filter: blur(4px);
    z-index: var(--z-modal-backdrop);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 20px;
  }

  .sch-modal {
    background: var(--bg-secondary);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-lg);
    width: 100%;
    max-width: 540px;
    max-height: 90vh;
    overflow-y: auto;
    z-index: var(--z-modal);
    box-shadow: var(--shadow-glass);
  }

  .sch-modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 18px 20px 0;
  }

  .sch-modal-title {
    font-family: var(--font-sans);
    font-size: 16px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
  }

  .sch-modal-close {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    border-radius: var(--radius-xs);
    border: none;
    background: transparent;
    color: var(--text-tertiary);
    cursor: pointer;
    transition: color var(--transition-fast) ease, background var(--transition-fast) ease;
    padding: 0;
  }

  .sch-modal-close:hover {
    color: var(--text-secondary);
    background: var(--bg-elevated);
  }

  .sch-modal-close:focus-visible {
    outline: 2px solid var(--accent-primary);
    outline-offset: 2px;
  }

  .sch-modal-body {
    padding: 20px;
  }

  /* ── Responsive ── */
  @media (max-width: 900px) {
    .sch-main {
      grid-template-columns: 1fr;
    }
  }
</style>
