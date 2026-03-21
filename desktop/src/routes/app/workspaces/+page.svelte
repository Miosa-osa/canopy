<!-- src/routes/app/workspaces/+page.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';

  onMount(() => {
    void workspaceStore.fetchWorkspaces();
  });
</script>

<PageShell
  title="Workspaces"
  badge={workspaceStore.workspaces.length > 0 ? workspaceStore.workspaces.length : undefined}
>
  {#if workspaceStore.isLoading && workspaceStore.workspaces.length === 0}
    <div class="ws-loading" role="status" aria-live="polite">
      <div class="ws-spinner" aria-hidden="true"></div>
      <span>Loading workspaces…</span>
    </div>
  {:else if workspaceStore.error && workspaceStore.workspaces.length === 0}
    <div class="ws-error" role="alert">
      <p>Failed to load workspaces: {workspaceStore.error}</p>
      <button onclick={() => void workspaceStore.fetchWorkspaces()}>Retry</button>
    </div>
  {:else if workspaceStore.workspaces.length === 0}
    <div class="ws-empty" role="status">
      <p>No workspaces found.</p>
    </div>
  {:else}
    <div class="ws-list" role="list" aria-label="Workspaces">
      {#each workspaceStore.workspaces as ws (ws.id)}
        {@const isActive = workspaceStore.activeWorkspaceId === ws.id}
        {@const scan = isActive ? workspaceStore.lastScan : null}
        <article
          class="ws-card"
          class:ws-card--active={isActive}
          role="listitem"
        >
          <div class="ws-header">
            <div class="ws-name-row">
              <span class="ws-name">{ws.name}</span>
              {#if isActive}
                <span class="ws-active-badge">Active</span>
              {/if}
              <span class="ws-status ws-status--{isActive ? 'active' : 'inactive'}">{isActive ? 'active' : 'inactive'}</span>
            </div>
            {#if ws.description}
              <div class="ws-desc">{ws.description}</div>
            {/if}
          </div>
          <div class="ws-stats">
            <span class="ws-stat">{scan?.agents.length ?? 0} agents</span>
            <span class="ws-stat">{scan?.projects.length ?? 0} projects</span>
            <span class="ws-stat">{scan?.schedules.length ?? 0} schedules</span>
          </div>
          {#if ws.path}
            <div class="ws-path">{ws.path}</div>
          {/if}
          <div class="ws-actions">
            {#if !isActive}
              <button
                class="ws-activate-btn"
                onclick={() => workspaceStore.setActiveWorkspace(ws.id)}
                aria-label="Activate workspace {ws.name}"
              >
                Activate
              </button>
            {/if}
            <button
              class="ws-delete-btn"
              onclick={() => {
                if (confirm(`Delete workspace "${ws.name}"? This cannot be undone.`)) {
                  workspaceStore.removeWorkspace(ws.id);
                }
              }}
              aria-label="Delete workspace {ws.name}"
            >
              Delete
            </button>
          </div>
        </article>
      {/each}
    </div>
  {/if}
</PageShell>

<style>
  .ws-loading, .ws-empty, .ws-error {
    display: flex; flex-direction: column; align-items: center;
    justify-content: center; gap: 12px; height: 200px;
    color: var(--dt3); font-size: 13px;
  }
  .ws-spinner {
    width: 24px; height: 24px; border-radius: 50%;
    border: 2px solid var(--dbd); border-top-color: var(--dt2);
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }
  .ws-list { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 12px; padding: 24px; }
  .ws-card {
    background: var(--dbg2); border: 1px solid var(--dbd); border-radius: 10px;
    transition: border-color 120ms ease;
  }
  .ws-card--active { border-color: #6366f1; background: rgba(99, 102, 241, 0.06); }
  .ws-card:hover { border-color: var(--dbd2); }
  .ws-card { padding: 16px; display: flex; flex-direction: column; gap: 10px; }
  .ws-header { display: flex; flex-direction: column; gap: 4px; }
  .ws-name-row { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
  .ws-name { font-size: 15px; font-weight: 600; color: var(--dt); }
  .ws-active-badge {
    font-size: 10px; font-weight: 600; padding: 1px 6px; border-radius: 4px;
    background: rgba(99, 102, 241, 0.2); color: #a5b4fc;
  }
  .ws-status {
    font-size: 10px; font-weight: 500; padding: 1px 6px; border-radius: 4px;
    text-transform: uppercase; letter-spacing: 0.04em; margin-left: auto;
  }
  .ws-status--active { background: rgba(34, 197, 94, 0.12); color: rgba(134, 239, 172, 0.8); }
  .ws-status--inactive { background: var(--dbg3); color: var(--dt4); }
  .ws-status--archived { background: var(--dbg3); color: var(--dt4); }
  .ws-desc { font-size: 12px; color: var(--dt3); line-height: 1.5; }
  .ws-stats { display: flex; gap: 14px; }
  .ws-stat { font-size: 11px; color: var(--dt4); }
  .ws-path {
    font-size: 10px; color: var(--dt4); font-family: var(--font-mono);
    overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
    padding-top: 8px; border-top: 1px solid var(--dbd);
  }
  .ws-actions { display: flex; gap: 8px; align-items: center; }
  .ws-activate-btn {
    padding: 5px 12px; border-radius: 6px; font-size: 12px;
    border: 1px solid var(--dbd); background: var(--dbg3); color: var(--dt2);
    cursor: pointer; transition: all 120ms ease;
  }
  .ws-activate-btn:hover { border-color: #6366f1; color: #a5b4fc; }
  .ws-delete-btn {
    padding: 5px 12px; border-radius: 6px; font-size: 12px;
    border: 1px solid rgba(239, 68, 68, 0.2); background: transparent; color: var(--dt4);
    cursor: pointer; transition: all 120ms ease;
  }
  .ws-delete-btn:hover { border-color: rgba(239, 68, 68, 0.5); color: #f87171; background: rgba(239, 68, 68, 0.08); }
</style>
