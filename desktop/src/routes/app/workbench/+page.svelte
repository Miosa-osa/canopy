<script lang="ts">
  import { onMount } from "svelte";
  import PageShell from "$lib/components/layout/PageShell.svelte";
  import WorkbenchShell from "$lib/components/workbench/WorkbenchShell.svelte";
  import { workbenchStore } from "$lib/stores/workbench.svelte";
  import { workspaceStore } from "$lib/stores/workspace.svelte";

  const workspaceKey = $derived(
    workspaceStore.activeWorkspaceId ??
      workspaceStore.activeWorkspace?.path.replace(/[^a-zA-Z0-9._-]/g, "_") ??
      "default",
  );

  onMount(() => {
    workbenchStore.load(workspaceKey);
  });

  $effect(() => {
    workbenchStore.load(workspaceKey);
  });
</script>

<PageShell
  title="Workbench"
  subtitle="Spatial command center"
  badge={workbenchStore.layout.tiles.length}
  noPadding
>
  {#snippet actions()}
    <div class="wb-actions" role="toolbar" aria-label="Workbench controls">
      <button
        class="wb-action"
        class:wb-action--active={workbenchStore.layout.mode === "canvas"}
        type="button"
        aria-pressed={workbenchStore.layout.mode === "canvas"}
        onclick={() => workbenchStore.setMode("canvas")}
      >
        Canvas
      </button>
      <button
        class="wb-action"
        class:wb-action--active={workbenchStore.layout.mode === "split"}
        type="button"
        aria-pressed={workbenchStore.layout.mode === "split"}
        onclick={() => workbenchStore.setMode("split")}
      >
        Split
      </button>
      <button
        class="wb-action"
        type="button"
        onclick={() => workbenchStore.addTile("terminal")}
      >
        New Terminal
      </button>
      <button
        class="wb-action"
        type="button"
        onclick={() => workbenchStore.addTile("tmux")}
      >
        Tmux IDE
      </button>
      <button
        class="wb-action"
        type="button"
        onclick={() => workbenchStore.reset()}
      >
        Reset
      </button>
    </div>
  {/snippet}

  <WorkbenchShell />
</PageShell>

<style>
  .wb-actions {
    display: flex;
    gap: 4px;
  }

  .wb-action {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    height: 28px;
    padding: 0 10px;
    border: 1px solid var(--border-default);
    border-radius: 6px;
    background: transparent;
    color: var(--text-secondary);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: 12px;
    font-weight: 500;
  }

  .wb-action:hover,
  .wb-action--active {
    background: var(--bg-elevated);
    color: var(--text-primary);
    border-color: var(--border-hover);
  }
</style>
