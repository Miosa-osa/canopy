<script lang="ts">
/**
 * /workspace — Mosaic multi-pane power-user view.
 * SSR disabled (layout store uses localStorage).
 * CSS prefix: wsp-
 */
import MosaicRoot from '$lib/design/patterns/mosaic/MosaicRoot.svelte';
import { activeWorkspace } from '$lib/stores/active-workspace.svelte.js';

const workspaceSlug = $derived(activeWorkspace.slug ?? 'default');
</script>

<div class="wsp-page">
  <MosaicRoot {workspaceSlug} />
</div>

<style>
  .wsp-page {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-height: 0;
    height: 100%;
    overflow: hidden;
  }
</style>
