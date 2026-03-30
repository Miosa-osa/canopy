<!-- src/lib/components/layout/MainLayout.svelte -->
<script lang="ts">
  import type { Snippet } from 'svelte';
  import WorkspaceRail from './WorkspaceRail.svelte';
  import NewSidebar from './NewSidebar.svelte';

  interface Props {
    sidebarCollapsed?: boolean;
    onAddWorkspace?: () => void;
    children: Snippet;
  }

  let { sidebarCollapsed = false, onAddWorkspace, children }: Props = $props();
</script>

<div class="ml-layout">
  <WorkspaceRail {onAddWorkspace} />
  <NewSidebar collapsed={sidebarCollapsed} />
  <main class="ml-content" id="main-content">
    {@render children()}
  </main>
</div>

<style>
  .ml-layout {
    display: flex;
    width: 100%;
    height: 100%;
    overflow: hidden;
  }

  .ml-content {
    flex: 1;
    height: 100%;
    display: flex;
    flex-direction: column;
    min-width: 0;
    overflow: hidden;
    background: var(--bg-secondary);
    box-shadow: inset 1px 0 0 rgba(255, 255, 255, 0.04);
    position: relative;
  }
</style>
