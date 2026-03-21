<!-- src/lib/components/layout/TitleBar.svelte -->
<script lang="ts">
  import { isTauri, isMacOS } from '$lib/utils/platform';

  const inTauri = isTauri();
  const macOS = isMacOS();
</script>

{#if inTauri && macOS}
  <div class="tb-spacer" aria-hidden="true"></div>
  <div
    class="tb-drag"
    data-tauri-drag-region
    aria-hidden="true"
  ></div>
{/if}

<style>
  /* Spacer pushes content below the drag region */
  .tb-spacer {
    height: 28px;
    width: 100%;
    flex-shrink: 0;
  }

  /* Drag region overlays the top of the window */
  .tb-drag {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    height: 28px;
    z-index: 99999;
    -webkit-app-region: drag;
    app-region: drag;
  }
</style>
