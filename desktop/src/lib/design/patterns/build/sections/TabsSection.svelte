<script lang="ts">
  /**
   * TabsSection — list of currently open Mosaic panes (tabs).
   * CSS prefix: brl-tabs-.
   *
   * Click a row → focuses the pane (mosaicLayout.activatePane).
   * Right-click   → context menu (Fork in new pane / Fork in new tab / Delete).
   * Drag a row    → reorder within its current tile.
   * Search box    → filters by pane title (case-insensitive).
   *
   * Source data: mosaicLayout.allTiles() / Pane[]
   * LOC target: ≤ 220.
   */
  import { Search, X } from "lucide-svelte";
  import {
    mosaicLayout,
    type Tile,
  } from "$lib/stores/mosaic-layout.svelte.js";

  // ── Local state ────────────────────────────────────────────────────────────
  let filterText = $state("");
  let contextMenu = $state<{
    visible: boolean;
    x: number;
    y: number;
    tileId: string;
    paneId: string;
  } | null>(null);

  // Drag-reorder state (intra-tile only).
  let dragSource = $state<{ tileId: string; paneId: string } | null>(null);

  // Derived: every tile + its panes, filtered by search text.
  const tiles = $derived<Tile[]>(mosaicLayout.allTiles());
  const filteredTiles = $derived<Tile[]>(
    (() => {
      const needle = filterText.trim().toLowerCase();
      if (needle.length === 0) return tiles;
      return tiles.map((t) => ({
        ...t,
        panes: t.panes.filter((p) => p.title.toLowerCase().includes(needle)),
      }));
    })(),
  );
  const totalVisible = $derived(
    filteredTiles.reduce((acc, t) => acc + t.panes.length, 0),
  );

  // ── Handlers ───────────────────────────────────────────────────────────────
  function focusPane(tileId: string, paneId: string): void {
    mosaicLayout.activatePane(tileId, paneId);
  }

  function closePane(tileId: string, paneId: string): void {
    mosaicLayout.closePane(tileId, paneId);
    contextMenu = null;
  }

  /** Fork in new pane = split current tile and drop a clone into the
   *  new sibling. Pane id is regenerated so the two are independent. */
  function forkInNewPane(tileId: string, paneId: string): void {
    const tile = mosaicLayout.allTiles().find((t) => t.id === tileId);
    const src = tile?.panes.find((p) => p.id === paneId);
    if (!src) return;
    const clone = {
      id: Math.random().toString(36).slice(2, 9),
      kind: src.kind,
      ref: src.ref,
      title: src.title,
      config: src.config ? { ...src.config } : undefined,
    };
    mosaicLayout.splitTile(tileId, "vertical", clone);
    contextMenu = null;
  }

  /** Fork in new tab = open a clone as a new pane in the SAME tile.
   *  Same independence guarantee — fresh pane id. */
  function forkInNewTab(tileId: string, paneId: string): void {
    const tile = mosaicLayout.allTiles().find((t) => t.id === tileId);
    const src = tile?.panes.find((p) => p.id === paneId);
    if (!src) return;
    mosaicLayout.openPane(
      {
        id: Math.random().toString(36).slice(2, 9),
        kind: src.kind,
        ref: src.ref,
        title: src.title,
        config: src.config ? { ...src.config } : undefined,
      },
      tileId,
    );
    contextMenu = null;
  }

  function openContextMenu(
    tileId: string,
    paneId: string,
    ev: MouseEvent,
  ): void {
    ev.preventDefault();
    contextMenu = {
      visible: true,
      x: ev.clientX,
      y: ev.clientY,
      tileId,
      paneId,
    };
  }

  function handleGlobalClick(): void {
    contextMenu = null;
  }

  function handleDragStart(tileId: string, paneId: string): void {
    dragSource = { tileId, paneId };
  }

  function handleDragOver(ev: DragEvent): void {
    if (dragSource) ev.preventDefault();
  }

  function handleDrop(toTileId: string, toIndex: number): void {
    if (!dragSource) return;
    if (dragSource.tileId === toTileId) {
      // Intra-tile reorder via movePane (which works cross-tile too).
      mosaicLayout.movePane(
        dragSource.tileId,
        dragSource.paneId,
        toTileId,
        toIndex,
      );
    }
    dragSource = null;
  }
</script>

<svelte:window onclick={handleGlobalClick} />

<div class="brl-tabs">
  <header class="brl-tabs__header">
    <span class="brl-tabs__title">Tabs</span>
  </header>

  <div class="brl-tabs__search">
    <span class="brl-tabs__search-icon" aria-hidden="true">
      <Search size={12} />
    </span>
    <input
      type="search"
      class="brl-tabs__search-input"
      placeholder="Filter tabs…"
      bind:value={filterText}
      aria-label="Filter open tabs"
    />
  </div>

  <div class="brl-tabs__body">
    {#if totalVisible === 0}
      <div class="brl-tabs__empty">
        {filterText.trim().length > 0 ? "No matching tabs" : "No open tabs"}
      </div>
    {:else}
      {#each filteredTiles as tile (tile.id)}
        {#if tile.panes.length > 0}
          <ul class="brl-tabs__list" role="list">
            {#each tile.panes as pane, idx (pane.id)}
              <li>
                <div
                  class="brl-tabs__row"
                  class:brl-tabs__row--active={tile.activePaneId === pane.id &&
                    mosaicLayout.activeTileId === tile.id}
                  role="button"
                  tabindex="0"
                  draggable="true"
                  ondragstart={() => handleDragStart(tile.id, pane.id)}
                  ondragover={handleDragOver}
                  ondrop={() => handleDrop(tile.id, idx)}
                  onclick={() => focusPane(tile.id, pane.id)}
                  onkeydown={(e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                      e.preventDefault();
                      focusPane(tile.id, pane.id);
                    }
                  }}
                  oncontextmenu={(e) => openContextMenu(tile.id, pane.id, e)}
                  title={pane.title}
                >
                  <span class="brl-tabs__kind" data-kind={pane.kind}>
                    {pane.kind}
                  </span>
                  <span class="brl-tabs__name">{pane.title}</span>
                  <button
                    type="button"
                    class="brl-tabs__close"
                    aria-label="Close pane"
                    onclick={(e) => {
                      e.stopPropagation();
                      closePane(tile.id, pane.id);
                    }}
                  >
                    <X size={12} aria-hidden="true" />
                  </button>
                </div>
              </li>
            {/each}
          </ul>
        {/if}
      {/each}
    {/if}
  </div>

  {#if contextMenu?.visible}
    <div
      class="brl-tabs__menu"
      role="menu"
      style="left: {contextMenu.x}px; top: {contextMenu.y}px;"
    >
      <button
        type="button"
        class="brl-tabs__menu-item"
        role="menuitem"
        onclick={() => forkInNewPane(contextMenu!.tileId, contextMenu!.paneId)}
      >
        Fork in new pane
      </button>
      <button
        type="button"
        class="brl-tabs__menu-item"
        role="menuitem"
        onclick={() => forkInNewTab(contextMenu!.tileId, contextMenu!.paneId)}
      >
        Fork in new tab
      </button>
      <div class="brl-tabs__menu-sep" role="separator"></div>
      <button
        type="button"
        class="brl-tabs__menu-item brl-tabs__menu-item--danger"
        role="menuitem"
        onclick={() => closePane(contextMenu!.tileId, contextMenu!.paneId)}
      >
        Delete
      </button>
    </div>
  {/if}
</div>

<style>
  .brl-tabs {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  .brl-tabs__header {
    padding: 10px var(--space-3) 6px;
    border-bottom: 1px solid var(--border, rgba(0, 0, 0, 0.08));
  }

  .brl-tabs__title {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    color: var(--fg-muted);
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }

  .brl-tabs__search {
    position: relative;
    padding: var(--space-2) var(--space-2);
  }

  .brl-tabs__search-icon {
    position: absolute;
    left: 16px;
    top: 50%;
    transform: translateY(-50%);
    color: var(--fg-subtle);
    pointer-events: none;
  }

  .brl-tabs__search-input {
    width: 100%;
    height: 26px;
    padding: 0 var(--space-2) 0 26px;
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--fg);
    background: var(--bg-inset, rgba(0, 0, 0, 0.04));
    border: 1px solid var(--border, rgba(0, 0, 0, 0.08));
    border-radius: var(--radius-sm, 4px);
    outline: none;
  }

  .brl-tabs__search-input:focus-visible {
    border-color: var(--cnp-accent, #1e96eb);
  }

  .brl-tabs__body {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    padding: var(--space-1, 4px) 0;
  }

  .brl-tabs__list {
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .brl-tabs__row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    width: 100%;
    min-height: 26px;
    padding: 0 var(--space-2) 0 var(--space-3);
    border: none;
    background: transparent;
    cursor: pointer;
    text-align: left;
    color: var(--fg-muted);
    font-family: var(--font-mono);
    font-size: 11.5px;
    transition: background 80ms ease-out;
  }

  .brl-tabs__row:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .brl-tabs__row--active {
    background: color-mix(in oklch, var(--cnp-accent, #1e96eb) 12%, transparent 88%);
    color: var(--fg);
  }

  .brl-tabs__kind {
    flex-shrink: 0;
    font-family: var(--font-mono);
    font-size: 9px;
    text-transform: uppercase;
    color: var(--fg-subtle);
    letter-spacing: 0.05em;
  }

  .brl-tabs__name {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .brl-tabs__close {
    flex-shrink: 0;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 18px;
    height: 18px;
    border: none;
    background: transparent;
    color: var(--fg-subtle);
    cursor: pointer;
    border-radius: 3px;
    opacity: 0;
    transition: opacity 80ms ease-out;
  }

  .brl-tabs__row:hover .brl-tabs__close {
    opacity: 1;
  }

  .brl-tabs__close:hover {
    background: rgba(0, 0, 0, 0.08);
    color: var(--fg);
  }

  .brl-tabs__empty {
    padding: var(--space-6) var(--space-3);
    text-align: center;
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
  }

  .brl-tabs__menu {
    position: fixed;
    z-index: 1100;
    min-width: 140px;
    padding: 4px;
    background: var(--bg-overlay, #fbfbfc);
    border: 1px solid var(--border, rgba(0, 0, 0, 0.08));
    border-radius: var(--radius-md, 8px);
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
  }

  .brl-tabs__menu-item {
    display: block;
    width: 100%;
    padding: 6px 10px;
    border: none;
    background: transparent;
    text-align: left;
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--fg);
    border-radius: var(--radius-sm, 4px);
    cursor: pointer;
  }

  .brl-tabs__menu-item:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
  }

  .brl-tabs__menu-item--danger {
    color: var(--signal-error, oklch(0.6 0.22 25));
  }

  .brl-tabs__menu-item--danger:hover {
    background: color-mix(in oklch, var(--signal-error, oklch(0.6 0.22 25)) 10%, transparent);
  }

  .brl-tabs__menu-sep {
    height: 1px;
    margin: 4px 0;
    background: var(--border, rgba(0, 0, 0, 0.08));
  }

  :global(.dark) .brl-tabs__menu {
    background: #252525;
    border-color: rgba(255, 255, 255, 0.08);
  }
</style>
