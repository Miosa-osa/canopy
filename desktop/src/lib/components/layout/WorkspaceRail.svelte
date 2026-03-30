<!-- src/lib/components/layout/WorkspaceRail.svelte -->
<script lang="ts">
  import { Plus } from 'lucide-svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';

  interface Props {
    onAddWorkspace?: () => void;
  }

  let { onAddWorkspace }: Props = $props();

  function initials(name: string): string {
    return name.split(' ').slice(0, 2).map(w => w[0]).join('').toUpperCase();
  }
</script>

<nav class="wr-rail" aria-label="Workspace selector">
  <div class="wr-workspaces">
    {#each workspaceStore.workspaces as ws (ws.id)}
      <button
        class="wr-tile"
        class:active={ws.id === workspaceStore.activeWorkspaceId}
        onclick={() => workspaceStore.setActiveWorkspace(ws.id)}
        title={ws.name}
        aria-label="Switch to workspace {ws.name}"
        aria-pressed={ws.id === workspaceStore.activeWorkspaceId}
      >
        <span class="wr-tile-text">{initials(ws.name)}</span>
      </button>
    {/each}
  </div>

  <button
    class="wr-add"
    onclick={onAddWorkspace}
    title="Add workspace"
    aria-label="Add workspace"
  >
    <Plus size={18} />
  </button>
</nav>

<style>
  .wr-rail {
    width: 72px;
    min-width: 72px;
    height: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 12px 0;
    background: var(--bg-primary);
    border-right: 1px solid var(--border-default);
    gap: 8px;
  }

  .wr-workspaces {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    flex: 1;
    overflow-y: auto;
    padding: 0 12px;
  }

  .wr-tile {
    width: 48px;
    height: 48px;
    border-radius: var(--radius-sm);
    border: none;
    background: var(--bg-tertiary);
    color: var(--text-secondary);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 150ms ease, color 150ms ease;
    position: relative;
  }

  .wr-tile:hover {
    background: var(--bg-elevated);
    color: var(--text-primary);
  }

  .wr-tile.active {
    background: var(--bg-elevated);
    color: var(--text-primary);
  }

  .wr-tile.active::before {
    content: '';
    position: absolute;
    left: -12px;
    top: 50%;
    transform: translateY(-50%);
    width: 3px;
    height: 28px;
    background: var(--accent-primary);
    border-radius: 0 2px 2px 0;
  }

  .wr-tile-text {
    user-select: none;
  }

  .wr-add {
    width: 48px;
    height: 48px;
    border-radius: var(--radius-sm);
    border: 1px dashed var(--border-default);
    background: transparent;
    color: var(--text-tertiary);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 12px;
    transition: border-color 150ms ease, color 150ms ease;
  }

  .wr-add:hover {
    border-color: var(--border-hover);
    color: var(--text-secondary);
  }
</style>
