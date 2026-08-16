<script lang="ts">
import AgentKanbanPane from '$lib/design/patterns/mosaic/panes/AgentKanbanPane.svelte';
import { activeWorkspace } from '$lib/stores/active-workspace.svelte.js';

const workspaceSlug = $derived(activeWorkspace.slug ?? 'default');
</script>

<div class="akr-root">
  <AgentKanbanPane {workspaceSlug} />
</div>

<style>
  .akr-root {
    flex: 1;
    display: flex;
    min-height: 0;
    height: 100%;
    overflow: hidden;
    background: var(--bg);
  }
</style>
