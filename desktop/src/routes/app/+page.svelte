<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import KpiGrid from '$lib/components/dashboard/KpiGrid.svelte';
  import LiveRunsWidget from '$lib/components/dashboard/LiveRunsWidget.svelte';
  import RecentActivityFeed from '$lib/components/dashboard/RecentActivityFeed.svelte';
  import FinanceSummary from '$lib/components/dashboard/FinanceSummary.svelte';
  import QuickActions from '$lib/components/dashboard/QuickActions.svelte';
  import SystemHealthBar from '$lib/components/dashboard/SystemHealthBar.svelte';
  import { dashboardStore } from '$lib/stores/dashboard.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';

  onMount(() => dashboardStore.startAutoRefresh(30_000));

  // Re-fetch dashboard whenever the active workspace changes.
  // setActiveWorkspace() already triggers this, but the $effect here ensures
  // the dashboard page also reacts if the workspace is changed from another
  // entry point (e.g. WorkspaceSwitcher in the sidebar, syncFromBackend, etc.).
  $effect(() => {
    // Track activeWorkspaceId so this effect re-runs on workspace switches.
    // setActiveWorkspace() calls dashboardStore.fetch() directly, but this
    // $effect also covers external workspace changes (syncFromBackend, etc.).
    void workspaceStore.activeWorkspaceId;
    void dashboardStore.fetch();
  });

  // True once the layout has had a chance to hydrate workspaces from localStorage.
  // The layout calls fetchWorkspaces() synchronously, so by the time this page
  // component mounts the store is already populated — but we guard on the derived
  // value so the empty-state prompt never flashes for users who have workspaces.
  const hasWorkspaces = $derived(workspaceStore.workspaces.length > 0);
</script>

<PageShell title="Dashboard">
  {#if !hasWorkspaces}
    <!-- Empty state: no workspace configured yet (fresh install or cleared storage) -->
    <div class="dash-empty">
      <div class="dash-empty-icon" aria-hidden="true">
        <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.25" stroke-linecap="round" stroke-linejoin="round">
          <path d="M20.25 6.375c0 2.278-3.694 4.125-8.25 4.125S3.75 8.653 3.75 6.375m16.5 0c0-2.278-3.694-4.125-8.25-4.125S3.75 4.097 3.75 6.375m16.5 0v11.25c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125V6.375m16.5 0v3.75m-16.5-3.75v3.75m16.5 0v3.75C20.25 16.153 16.556 18 12 18s-8.25-1.847-8.25-4.125v-3.75m16.5 0c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125" />
        </svg>
      </div>
      <h2 class="dash-empty-title">No workspace yet</h2>
      <p class="dash-empty-body">
        Add a workspace to start orchestrating agents. Use the workspace switcher in
        the sidebar, or run through the setup wizard.
      </p>
      <div class="dash-empty-actions">
        <button
          class="dash-empty-btn dash-empty-btn--primary"
          onclick={() => goto('/onboarding')}
          type="button"
        >
          Run setup wizard
        </button>
        <button
          class="dash-empty-btn dash-empty-btn--secondary"
          onclick={() => goto('/app/settings')}
          type="button"
        >
          Go to Settings
        </button>
      </div>
    </div>
  {:else}
    <div class="dashboard-grid">
      <div class="dashboard-top"><KpiGrid /></div>
      <div class="dashboard-quick"><QuickActions /></div>
      <div class="dashboard-runs"><LiveRunsWidget /></div>
      <div class="dashboard-activity"><RecentActivityFeed /></div>
      <div class="dashboard-finance"><FinanceSummary /></div>
      <div class="dashboard-health"><SystemHealthBar /></div>
    </div>
  {/if}
</PageShell>

<style>
  .dashboard-grid {
    display: grid; gap: 16px; padding: 20px 24px;
    grid-template-columns: 1fr 1fr;
    grid-template-areas:
      "top top"
      "quick quick"
      "runs activity"
      "finance finance"
      "health health";
  }
  .dashboard-top { grid-area: top; }
  .dashboard-quick { grid-area: quick; }
  .dashboard-runs { grid-area: runs; }
  .dashboard-activity { grid-area: activity; }
  .dashboard-finance { grid-area: finance; }
  .dashboard-health { grid-area: health; }

  /* ── Empty state ────────────────────────────────────────────────────────── */

  .dash-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    height: 100%;
    padding: 48px 24px;
    text-align: center;
  }

  .dash-empty-icon {
    color: var(--text-muted);
    margin-bottom: 4px;
  }

  .dash-empty-title {
    font-size: 18px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
  }

  .dash-empty-body {
    font-size: 13px;
    color: var(--text-secondary);
    max-width: 360px;
    line-height: 1.6;
    margin: 0;
  }

  .dash-empty-actions {
    display: flex;
    gap: 8px;
    margin-top: 8px;
    flex-wrap: wrap;
    justify-content: center;
  }

  .dash-empty-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 8px 16px;
    border-radius: var(--radius-md);
    font-size: 13px;
    font-weight: 500;
    cursor: pointer;
    transition: opacity 150ms ease, background 150ms ease, border-color 150ms ease;
    border: none;
  }

  .dash-empty-btn--primary {
    background: var(--accent-primary, #3b82f6);
    color: #ffffff;
  }

  .dash-empty-btn--primary:hover {
    opacity: 0.88;
  }

  .dash-empty-btn--secondary {
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    color: var(--text-secondary);
  }

  .dash-empty-btn--secondary:hover {
    background: var(--bg-elevated);
    border-color: var(--border-hover);
    color: var(--text-primary);
  }
</style>
