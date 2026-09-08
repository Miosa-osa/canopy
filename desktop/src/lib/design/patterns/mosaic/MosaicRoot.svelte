<script lang="ts">
/**
 * MosaicRoot — top-level mosaic layout host.
 * Loads layout from store on mount. Registers keyboard shortcuts.
 * Hosts the global Mosaic settings popover (gear icon, top-right).
 * Provides `mosaic-prefs` Svelte context so descendants (MosaicTile) read
 * the same store without each importing it independently.
 * CSS prefix: mr-
 * LOC target: ≤ 220.
 */

import { Settings } from 'lucide-svelte';
import { onMount, setContext } from 'svelte';
import Popover from '$lib/design/foundation/popover/Popover.svelte';
import { mosaicLayout } from '$lib/stores/mosaic-layout.svelte.js';
import { mosaicPrefs } from '$lib/stores/mosaic-prefs.svelte.js';
import MosaicNode from './MosaicNode.svelte';
import MosaicSettings from './MosaicSettings.svelte';
import PanePicker from './PanePicker.svelte';

interface Props {
  workspaceSlug: string;
}

let { workspaceSlug }: Props = $props();

let pickerOpen = $state(false);
let pickerTargetTileId = $state<string | null>(null);
let settingsOpen = $state(false);

// Expose the prefs store via context so child tiles don't have to re-import.
// Children read `getContext('mosaic-prefs')` which returns the singleton.
setContext('mosaic-prefs', mosaicPrefs);

onMount(() => {
  if (!mosaicLayout.layout.root || mosaicLayout.layout.workspaceSlug !== workspaceSlug) {
    mosaicLayout.load(workspaceSlug);
  }
});

// ── Keyboard shortcuts ──────────────────────────────────────────────────────

function handleKeydown(e: KeyboardEvent): void {
  const mod = e.metaKey || e.ctrlKey;
  if (!mod) return;

  // ⌘\ — split active tile vertically
  if (!e.shiftKey && e.key === '\\') {
    e.preventDefault();
    if (mosaicLayout.activeTileId) {
      mosaicLayout.splitTile(mosaicLayout.activeTileId, 'vertical');
    }
    return;
  }

  // ⌘⇧\ — split horizontally
  if (e.shiftKey && e.key === '|') {
    e.preventDefault();
    if (mosaicLayout.activeTileId) {
      mosaicLayout.splitTile(mosaicLayout.activeTileId, 'horizontal');
    }
    return;
  }

  // ⌘w — close active pane
  if (!e.shiftKey && e.key === 'w') {
    e.preventDefault();
    const tid = mosaicLayout.activeTileId;
    if (!tid) return;
    const found = mosaicLayout.allTiles().find((t) => t.id === tid);
    if (found?.activePaneId) {
      mosaicLayout.closePane(tid, found.activePaneId);
    }
    return;
  }

  // ⌘t — open new-pane picker
  if (!e.shiftKey && e.key === 't') {
    e.preventDefault();
    pickerTargetTileId = mosaicLayout.activeTileId;
    pickerOpen = true;
    return;
  }

  // ⌘1–9 — activate pane N in active tile
  if (!e.shiftKey && e.key >= '1' && e.key <= '9') {
    const idx = parseInt(e.key, 10) - 1;
    const tid = mosaicLayout.activeTileId;
    if (!tid) return;
    const found = mosaicLayout.allTiles().find((t) => t.id === tid);
    if (found && found.panes[idx]) {
      e.preventDefault();
      mosaicLayout.activatePane(tid, found.panes[idx].id);
    }
    return;
  }

  // ⌘d — split right (vertical split = side by side)
  if (!e.shiftKey && e.key === 'd') {
    e.preventDefault();
    if (mosaicLayout.activeTileId) {
      mosaicLayout.splitTile(mosaicLayout.activeTileId, 'vertical');
    }
    return;
  }

  // ⌘⇧d — split down (horizontal split = stacked)
  if (e.shiftKey && e.key === 'D') {
    e.preventDefault();
    if (mosaicLayout.activeTileId) {
      mosaicLayout.splitTile(mosaicLayout.activeTileId, 'horizontal');
    }
    return;
  }

  // ⌘⇧] — next pane in active tile
  if (e.shiftKey && e.key === ']') {
    e.preventDefault();
    const tid = mosaicLayout.activeTileId;
    if (!tid) return;
    const found = mosaicLayout.allTiles().find((t) => t.id === tid);
    if (!found || found.panes.length === 0) return;
    const cur = found.panes.findIndex((p) => p.id === found.activePaneId);
    const next = (cur + 1) % found.panes.length;
    mosaicLayout.activatePane(tid, found.panes[next].id);
    return;
  }

  // ⌘⇧[ — prev pane in active tile
  if (e.shiftKey && e.key === '[') {
    e.preventDefault();
    const tid = mosaicLayout.activeTileId;
    if (!tid) return;
    const found = mosaicLayout.allTiles().find((t) => t.id === tid);
    if (!found || found.panes.length === 0) return;
    const cur = found.panes.findIndex((p) => p.id === found.activePaneId);
    const prev = (cur - 1 + found.panes.length) % found.panes.length;
    mosaicLayout.activatePane(tid, found.panes[prev].id);
    return;
  }

  // ⌘⇧← / ⌘⇧→ — move focus between tiles
  if (e.shiftKey && (e.key === 'ArrowLeft' || e.key === 'ArrowRight')) {
    e.preventDefault();
    const tiles = mosaicLayout.allTiles();
    if (tiles.length === 0) return;
    const idx = tiles.findIndex((t) => t.id === mosaicLayout.activeTileId);
    const next =
      e.key === 'ArrowRight' ? (idx + 1) % tiles.length : (idx - 1 + tiles.length) % tiles.length;
    mosaicLayout.setActiveTile(tiles[next].id);
    return;
  }
}
</script>

<svelte:window onkeydown={handleKeydown} />

<div
  class="mr-root"
  role="region"
  aria-label="Mosaic workspace"
  data-density={mosaicPrefs.prefs.density}
  data-view-mode={mosaicPrefs.prefs.view_mode}
>
  <div class="mr-tree">
    {#if mosaicLayout.layout.root}
      <MosaicNode node={mosaicLayout.layout.root} />
    {/if}
  </div>

  <!-- Settings gear (anchored top-right, floats over the tile chrome). -->
  <div class="mr-settings-anchor">
    <Popover bind:open={settingsOpen} side="bottom" align="end" sideOffset={6}>
      {#snippet trigger()}
        <button
          type="button"
          class="mr-gear"
          aria-label="Mosaic display settings"
          aria-haspopup="menu"
          aria-expanded={settingsOpen}
          title="Display settings"
        >
          <Settings size={13} aria-hidden="true" />
        </button>
      {/snippet}
      {#snippet children()}
        <MosaicSettings onClose={() => { settingsOpen = false; }} />
      {/snippet}
    </Popover>
  </div>
</div>

{#if pickerOpen}
  <PanePicker
    targetTileId={pickerTargetTileId}
    onClose={() => { pickerOpen = false; pickerTargetTileId = null; }}
  />
{/if}

<style>
  .mr-root {
    position: relative;
    display: flex;
    width: 100%;
    height: 100%;
    overflow: hidden;
    min-height: 0;
  }

  .mr-tree {
    flex: 1;
    display: flex;
    width: 100%;
    height: 100%;
    overflow: hidden;
    min-height: 0;
  }

  /* Settings anchor — sits above the tile content, top-right. */
  .mr-settings-anchor {
    position: absolute;
    top: 6px;
    right: 8px;
    z-index: 30;
  }

  .mr-gear {
    appearance: none;
    border: 1px solid transparent;
    background: transparent;
    color: var(--fg-subtle);
    width: 22px;
    height: 22px;
    border-radius: var(--radius-sm, 6px);
    display: inline-flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: background 0.1s ease, color 0.1s ease, border-color 0.1s ease;
  }

  .mr-gear:hover {
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    border-color: var(--border);
  }

  .mr-gear:focus-visible {
    outline: 2px solid var(--cnp-accent, oklch(0.72 0.18 145));
    outline-offset: 2px;
  }

  /* Density variants — surface as data-attrs, consumed by MosaicTile. */
  /* Roomy: roomier tab heights / metadata visible by default. */
  .mr-root[data-density='roomy'] :global(.mt-tabbar) { height: 42px; }
  .mr-root[data-density='roomy'] :global(.mt-tab)    { height: 34px; padding: 0 12px; gap: 6px; }

  /* Compact: tighter chrome. */
  .mr-root[data-density='compact'] :global(.mt-tabbar) { height: 28px; }
  .mr-root[data-density='compact'] :global(.mt-tab)    { height: 22px; padding: 0 6px; font-size: 10px; }
</style>
