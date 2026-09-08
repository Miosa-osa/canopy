<script lang="ts">
/**
 * MosaicTile — tab-bar + pane body for a single mosaic tile.
 * Supports HTML5 drag-and-drop for tab movement + edge-drop splitting +
 * intra-tile reorder. Reads `mosaic-prefs` via context for density,
 * title format, and hover-card visibility.
 *
 * CSS prefix: mt-
 * LOC target: ≤ 280.
 */

import {
  BookMarked,
  BookOpen,
  Bot,
  CheckSquare,
  CircleDot,
  FileText,
  FolderKanban,
  FolderOpen,
  GitPullRequest,
  History,
  Pin,
  Plus,
  Terminal,
  Workflow,
  X,
} from 'lucide-svelte';
import { getContext } from 'svelte';
import {
  mosaicLayout,
  type Pane,
  type PaneKind,
  type Tile,
} from '$lib/stores/mosaic-layout.svelte.js';
import type { MosaicTitleFormat } from '$lib/stores/mosaic-prefs.svelte.js';
import PaneContent from './PaneContent.svelte';
import PanePicker from './PanePicker.svelte';
import TabHoverCard from './TabHoverCard.svelte';

interface Props {
  tile: Tile;
}

let { tile }: Props = $props();

// ── Prefs (via context, falls back to defaults if unmounted standalone) ─────

type PrefsCtx = {
  prefs: {
    view_mode: 'panes' | 'tabs';
    density: 'compact' | 'comfortable' | 'roomy';
    pane_title_format: MosaicTitleFormat;
    metadata_fields: string[];
    show_details_on_hover: boolean;
  };
};
const prefs = getContext<PrefsCtx | undefined>('mosaic-prefs');

let pickerOpen = $state(false);
let dropZone = $state<'none' | 'top' | 'bottom' | 'left' | 'right' | 'tab'>('none');

// ── Tab context menu ────────────────────────────────────────────────────────
let contextMenu = $state<{ paneId: string; x: number; y: number } | null>(null);

function openContextMenu(e: MouseEvent, paneId: string): void {
  e.preventDefault();
  e.stopPropagation();
  contextMenu = { paneId, x: e.clientX, y: e.clientY };
}

function closeContextMenu(): void {
  contextMenu = null;
}

function ctxNewTab(): void {
  closeContextMenu();
  mosaicLayout.setActiveTile(tile.id);
  pickerOpen = true;
}

function ctxSplitRight(): void {
  closeContextMenu();
  mosaicLayout.splitTile(tile.id, 'vertical');
}

function ctxSplitDown(): void {
  closeContextMenu();
  mosaicLayout.splitTile(tile.id, 'horizontal');
}

function ctxClosePane(paneId: string): void {
  closeContextMenu();
  mosaicLayout.closePane(tile.id, paneId);
}

function ctxPinPane(paneId: string): void {
  closeContextMenu();
  mosaicLayout.pinPane(tile.id, paneId);
}

function ctxCloseTile(): void {
  closeContextMenu();
  mosaicLayout.closeTile(tile.id);
}
let isActive = $derived(mosaicLayout.activeTileId === tile.id);

/** Whether the pane currently targeted by the context menu is pinned. */
let ctxPaneIsPinned = $derived(
  contextMenu !== null
    ? (tile.panes.find((p) => p.id === (contextMenu as NonNullable<typeof contextMenu>).paneId)
        ?.pinned ?? false)
    : false
);

$effect(() => {
  const id = tile.activePaneId;
  if (!id) return;
  const el = document.querySelector(`[data-pane-id="${id}"]`);
  el?.scrollIntoView({ inline: 'nearest', block: 'nearest' });
});

// Hover card lifecycle.
let hoveredPaneId = $state<string | null>(null);
let hoverCardStyle = $state<string>('');
let hoverTimer: ReturnType<typeof setTimeout> | null = null;
const HOVER_DELAY_MS = 350;

// ── Icon lookup ─────────────────────────────────────────────────────────────

type IconComp = unknown;
const KIND_ICONS: Record<PaneKind, IconComp> = {
  session: Terminal as IconComp,
  issue: CircleDot as IconComp,
  task: CheckSquare as IconComp,
  doc: FileText as IconComp,
  file: FolderOpen as IconComp,
  terminal: Terminal as IconComp,
  changes: GitPullRequest as IconComp,
  knowledge: BookOpen as IconComp,
  agent_conversation: Bot as IconComp,
  agent_kanban: FolderKanban as IconComp,
  block_stream: Terminal as IconComp,
  workflow: Workflow as IconComp,
  notebook: BookMarked as IconComp,
  history: History as IconComp,
};

// ── Title formatting ────────────────────────────────────────────────────────

function paneTitle(pane: Pane): string {
  const fmt = prefs?.prefs.pane_title_format ?? 'command';
  const cfg = (pane.config ?? {}) as Record<string, unknown>;
  const command = typeof cfg.command === 'string' ? cfg.command : null;
  const cwd =
    typeof cfg.cwd === 'string'
      ? cfg.cwd
      : typeof cfg.working_directory === 'string'
        ? cfg.working_directory
        : null;
  const branch = typeof cfg.branch === 'string' ? cfg.branch : null;

  if (fmt === 'working_directory' && cwd) return cwd.split('/').pop() || cwd;
  if (fmt === 'branch' && branch) return branch;
  return command || pane.title;
}

// ── Metadata badges ─────────────────────────────────────────────────────────

/** Returns the display value for a given metadata field on a pane, or null if absent. */
function metaBadgeValue(pane: Pane, field: string): string | null {
  const cfg = (pane.config ?? {}) as Record<string, unknown>;
  switch (field) {
    case 'branch':
      return typeof cfg.branch === 'string' ? cfg.branch : null;
    case 'working_directory': {
      const cwd =
        typeof cfg.cwd === 'string'
          ? cfg.cwd
          : typeof cfg.working_directory === 'string'
            ? cfg.working_directory
            : null;
      return cwd ? cwd.split('/').pop() || cwd : null;
    }
    case 'agent':
      return typeof cfg.agent === 'string'
        ? cfg.agent
        : typeof cfg.agent_slug === 'string'
          ? cfg.agent_slug
          : null;
    case 'runtime':
      return typeof cfg.runtime === 'string' ? cfg.runtime : null;
    case 'model':
      return typeof cfg.model === 'string' ? cfg.model : null;
    default:
      return null;
  }
}

// ── Drag-and-drop ───────────────────────────────────────────────────────────

interface DragPayload {
  fromTile: string;
  paneId: string;
}

function onTabDragStart(e: DragEvent, paneId: string): void {
  if (!e.dataTransfer) return;
  const payload: DragPayload = { fromTile: tile.id, paneId };
  e.dataTransfer.setData('application/x-canopy-pane', JSON.stringify(payload));
  e.dataTransfer.effectAllowed = 'move';
  cancelHover();
}

function onTileDragOver(e: DragEvent): void {
  if (!e.dataTransfer?.types.includes('application/x-canopy-pane')) return;
  e.preventDefault();
  e.dataTransfer.dropEffect = 'move';
  const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
  const x = e.clientX - rect.left;
  const y = e.clientY - rect.top;
  const edgeThreshold = Math.min(rect.width, rect.height) * 0.25;
  if (y < edgeThreshold) dropZone = 'top';
  else if (y > rect.height - edgeThreshold) dropZone = 'bottom';
  else if (x < edgeThreshold) dropZone = 'left';
  else if (x > rect.width - edgeThreshold) dropZone = 'right';
  else dropZone = 'tab';
}

function onTabBarDragOver(e: DragEvent): void {
  if (!e.dataTransfer?.types.includes('application/x-canopy-pane')) return;
  e.preventDefault();
  e.stopPropagation();
  e.dataTransfer.dropEffect = 'move';
  dropZone = 'tab';
}

/** Compute insertion index from clientX over the tab strip. */
function computeReorderIndex(e: DragEvent): number {
  const tabsEl = (e.currentTarget as HTMLElement).querySelector('.mt-tabs');
  if (!tabsEl) return tile.panes.length;
  const tabs = Array.from(tabsEl.querySelectorAll<HTMLElement>('.mt-tab'));
  for (let i = 0; i < tabs.length; i++) {
    const r = tabs[i].getBoundingClientRect();
    if (e.clientX < r.left + r.width / 2) return i;
  }
  return tabs.length;
}

function onDrop(e: DragEvent): void {
  e.preventDefault();
  const raw = e.dataTransfer?.getData('application/x-canopy-pane');
  if (!raw) {
    dropZone = 'none';
    return;
  }
  const { fromTile, paneId } = JSON.parse(raw) as DragPayload;
  const zone = dropZone;
  dropZone = 'none';

  if (zone === 'tab') {
    // Tab-bar drop: cross-tile move OR intra-tile reorder.
    const insertAt = computeReorderIndex(e);
    if (fromTile === tile.id) {
      const currentIdx = tile.panes.findIndex((p) => p.id === paneId);
      if (currentIdx === -1 || currentIdx === insertAt || currentIdx + 1 === insertAt) return;
      // Adjust insert idx to compensate for the removed item.
      const adjusted = insertAt > currentIdx ? insertAt - 1 : insertAt;
      mosaicLayout.movePane(fromTile, paneId, tile.id, adjusted);
    } else {
      mosaicLayout.movePane(fromTile, paneId, tile.id, insertAt);
    }
  } else if (zone === 'top' || zone === 'bottom' || zone === 'left' || zone === 'right') {
    // Edge drop → split
    const orientation = zone === 'left' || zone === 'right' ? 'vertical' : 'horizontal';
    mosaicLayout.splitTile(tile.id, orientation);
    const tiles = mosaicLayout.allTiles();
    const newTile = tiles[tiles.length - 1];
    if (newTile && fromTile !== newTile.id) {
      mosaicLayout.movePane(fromTile, paneId, newTile.id);
    }
  }
}

function onDragLeave(e: DragEvent): void {
  if (!(e.currentTarget as HTMLElement).contains(e.relatedTarget as HTMLElement)) {
    dropZone = 'none';
  }
}

// ── Hover card ──────────────────────────────────────────────────────────────

function cancelHover(): void {
  if (hoverTimer) {
    clearTimeout(hoverTimer);
    hoverTimer = null;
  }
  hoveredPaneId = null;
}

function onTabPointerEnter(e: PointerEvent, paneId: string): void {
  if (!prefs?.prefs.show_details_on_hover) return;
  const tab = e.currentTarget as HTMLElement;
  const tileEl = tab.closest('.mt-tile') as HTMLElement | null;
  if (!tileEl) return;
  const tabRect = tab.getBoundingClientRect();
  const tileRect = tileEl.getBoundingClientRect();
  const top = tabRect.bottom - tileRect.top + 4;
  const left = Math.max(4, Math.min(tabRect.left - tileRect.left, tileRect.width - 320));
  hoverCardStyle = `top: ${top}px; left: ${left}px;`;
  if (hoverTimer) clearTimeout(hoverTimer);
  hoverTimer = setTimeout(() => {
    hoveredPaneId = paneId;
  }, HOVER_DELAY_MS);
}

function onTabPointerLeave(): void {
  cancelHover();
}

const hoveredPane = $derived(
  hoveredPaneId ? (tile.panes.find((p) => p.id === hoveredPaneId) ?? null) : null
);

const isPanesView = $derived(prefs?.prefs.view_mode === 'panes');
</script>

<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
<div
  class="mt-tile"
  class:mt-tile--active={isActive}
  data-density={prefs?.prefs.density ?? 'comfortable'}
  data-view-mode={prefs?.prefs.view_mode ?? 'tabs'}
  role="region"
  aria-label="Mosaic tile"
  onclick={() => mosaicLayout.setActiveTile(tile.id)}
  ondragover={onTileDragOver}
  ondrop={onDrop}
  ondragleave={onDragLeave}
>
  <!-- Drop zone overlays -->
  {#if dropZone !== 'none' && dropZone !== 'tab'}
    <div class="mt-drop-overlay mt-drop-overlay--{dropZone}" aria-hidden="true"></div>
  {/if}

  <!-- Tab bar (rendered in both modes; in panes-mode it shrinks to a header strip). -->
  <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
  <div
    class="mt-tabbar"
    role="tablist"
    aria-label="Tile tabs"
    ondragover={onTabBarDragOver}
    ondrop={onDrop}
  >
    {#if !isPanesView}
      <div class="mt-tabs">
        {#each tile.panes as pane (pane.id)}
          {@const active = pane.id === tile.activePaneId}
          <!-- svelte-ignore a11y_interactive_supports_focus -->
          <div
            class="mt-tab"
            class:mt-tab--active={active}
            role="tab"
            aria-selected={active}
            draggable="true"
            data-pane-id={pane.id}
            onclick={() => mosaicLayout.activatePane(tile.id, pane.id)}
            oncontextmenu={(e) => openContextMenu(e, pane.id)}
            ondragstart={(e) => onTabDragStart(e, pane.id)}
            onpointerenter={(e) => onTabPointerEnter(e, pane.id)}
            onpointerleave={onTabPointerLeave}
          >
            {#if pane.pinned}
              <span class="mt-tab__pin" aria-label="Pinned" title="Pinned">
                <Pin size={9} aria-hidden="true" />
              </span>
            {/if}
            <!-- svelte-ignore svelte_component_deprecated -->
            <svelte:component this={KIND_ICONS[pane.kind] as unknown as typeof import('svelte').SvelteComponent} size={11} aria-hidden="true" />
            <span class="mt-tab__title">{paneTitle(pane)}</span>
            {#if prefs && prefs.prefs.metadata_fields.length > 0}
              {@const badges = prefs.prefs.metadata_fields
                .map((f) => ({ field: f, value: metaBadgeValue(pane, f) }))
                .filter((b) => b.value !== null)}
              {#each badges as badge (badge.field)}
                <span class="mt-tab__badge" title={badge.field}>{badge.value}</span>
              {/each}
            {/if}
            {#if !pane.pinned}
              <button
                class="mt-tab__close"
                onclick={(e) => { e.stopPropagation(); mosaicLayout.closePane(tile.id, pane.id); }}
                aria-label="Close {paneTitle(pane)}"
              >
                <X size={10} aria-hidden="true" />
              </button>
            {/if}
          </div>
        {/each}
      </div>
    {:else}
      <span class="mt-panes-label">Panes view</span>
    {/if}

    <button
      class="mt-add-btn"
      onclick={() => { mosaicLayout.setActiveTile(tile.id); pickerOpen = true; }}
      aria-label="Open pane picker (⌘T)"
      title="Open pane (⌘T)"
    >
      <Plus size={11} aria-hidden="true" />
    </button>
  </div>

  <!-- Body -->
  <div class="mt-body">
    {#if isPanesView}
      {#if tile.panes.length === 0}
        <div class="mt-empty">
          <span>No panes open.</span>
          <span>Press <kbd>⌘T</kbd> to open one.</span>
        </div>
      {:else}
        <!-- Panes view: horizontal pane-card row + the active pane content below.
             Full side-by-side rendering of every pane is non-trivial (each pane
             needs its own runtime/scroller); this stub keeps the active pane
             primary while exposing every pane as a clickable card.
             Tracked in `mosaic-polish-finish-wiring.md`. -->
        <div class="mt-panes-stub">
          {#each tile.panes as pane (pane.id)}
            {@const active = pane.id === tile.activePaneId}
            <button
              type="button"
              class="mt-pane-card"
              class:mt-pane-card--active={active}
              onclick={() => mosaicLayout.activatePane(tile.id, pane.id)}
              aria-pressed={active}
            >
              <span class="mt-pane-card__title">{paneTitle(pane)}</span>
              <span class="mt-pane-card__kind">{pane.kind}</span>
            </button>
          {/each}
        </div>
        <div class="mt-panes-active">
          {#if tile.activePaneId}
            {#key tile.activePaneId}
              {@const activePane = tile.panes.find((p) => p.id === tile.activePaneId)}
              {#if activePane}
                <PaneContent pane={activePane} />
              {/if}
            {/key}
          {/if}
        </div>
      {/if}
    {:else if tile.activePaneId}
      {#key tile.activePaneId}
        {@const activePane = tile.panes.find((p) => p.id === tile.activePaneId)}
        {#if activePane}
          <PaneContent pane={activePane} />
        {/if}
      {/key}
    {:else}
      <div class="mt-empty">
        <span>No panes open.</span>
        <span>Press <kbd>⌘T</kbd> to open one.</span>
      </div>
    {/if}
  </div>

  <!-- Hover detail card (only when pref enabled and a tab is hovered) -->
  {#if hoveredPane && prefs?.prefs.show_details_on_hover}
    <TabHoverCard pane={hoveredPane} style={hoverCardStyle} />
  {/if}
</div>

{#if pickerOpen}
  <PanePicker
    targetTileId={tile.id}
    onClose={() => { pickerOpen = false; }}
  />
{/if}

<!-- Tab context menu -->
{#if contextMenu !== null}
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
  <div
    class="mt-ctx-backdrop"
    onclick={closeContextMenu}
    aria-hidden="true"
  ></div>
  <menu
    class="mt-ctx-menu"
    style="left: {contextMenu.x}px; top: {contextMenu.y}px;"
    role="menu"
    aria-label="Tab actions"
  >
    <li role="none">
      <button type="button" role="menuitem" class="mt-ctx-item" onclick={ctxNewTab}>
        New tab <kbd>⌘T</kbd>
      </button>
    </li>
    <li role="none">
      <button type="button" role="menuitem" class="mt-ctx-item" onclick={ctxSplitRight}>
        Split right <kbd>⌘D</kbd>
      </button>
    </li>
    <li role="none">
      <button type="button" role="menuitem" class="mt-ctx-item" onclick={ctxSplitDown}>
        Split down <kbd>⌘⇧D</kbd>
      </button>
    </li>
    <li role="none">
      <button
        type="button"
        role="menuitem"
        class="mt-ctx-item"
        onclick={() => ctxPinPane(contextMenu!.paneId)}
      >
        {ctxPaneIsPinned ? 'Unpin tab' : 'Pin tab'}
      </button>
    </li>
    <li role="none" class="mt-ctx-separator" aria-hidden="true"></li>
    <li role="none">
      <button
        type="button"
        role="menuitem"
        class="mt-ctx-item mt-ctx-item--danger"
        onclick={() => ctxClosePane(contextMenu!.paneId)}
        disabled={ctxPaneIsPinned}
      >
        Close tab <kbd>⌘W</kbd>
      </button>
    </li>
    <li role="none">
      <button
        type="button"
        role="menuitem"
        class="mt-ctx-item mt-ctx-item--danger"
        onclick={ctxCloseTile}
      >
        Close tile
      </button>
    </li>
  </menu>
{/if}

<style>
  .mt-tile {
    display: flex;
    flex-direction: column;
    width: 100%;
    height: 100%;
    min-height: 0;
    overflow: hidden;
    position: relative;
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    background: var(--bg);
    transition: border-color 0.12s ease;
  }

  .mt-tile--active {
    border-color: var(--cnp-accent, oklch(0.72 0.18 145));
  }

  /* Drop overlays */
  .mt-drop-overlay {
    position: absolute;
    z-index: 20;
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 25%, transparent);
    border: 2px dashed var(--cnp-accent, oklch(0.72 0.18 145));
    border-radius: var(--radius-sm);
    pointer-events: none;
  }
  .mt-drop-overlay--top    { inset: 0 0 50% 0; }
  .mt-drop-overlay--bottom { inset: 50% 0 0 0; }
  .mt-drop-overlay--left   { inset: 0 50% 0 0; }
  .mt-drop-overlay--right  { inset: 0 0 0 50%; }

  /* Tab bar */
  .mt-tabbar {
    display: flex;
    align-items: center;
    border-bottom: 1px solid var(--border);
    background: var(--sidebar);
    flex-shrink: 0;
    height: 34px;
    gap: 0;
    padding: 0 30px 0 4px;
  }

  .mt-tabs {
    display: flex;
    align-items: center;
    gap: 2px;
    overflow-x: auto;
    flex: 1;
    scrollbar-width: none;
  }
  .mt-tabs::-webkit-scrollbar { display: none; }

  .mt-tab {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 0 8px;
    height: 28px;
    border-radius: var(--radius-sm);
    cursor: pointer;
    font-size: var(--text-xs, 11px);
    font-family: var(--font-sans);
    color: var(--fg-muted);
    white-space: nowrap;
    flex-shrink: 0;
    user-select: none;
    transition: background 0.1s ease, color 0.1s ease;
    position: relative;
  }
  .mt-tab:hover { background: color-mix(in oklch, var(--fg) 8%, transparent); color: var(--fg); }

  .mt-tab--active {
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 10%, transparent);
  }
  .mt-tab--active::after {
    content: '';
    position: absolute;
    bottom: -1px;
    left: 6px;
    right: 6px;
    height: 2px;
    background: var(--cnp-accent, oklch(0.72 0.18 145));
    border-radius: 9999px;
  }

  /* Density variants — tile-scoped, override the default 28px tab height. */
  .mt-tile[data-density='compact'] .mt-tab    { height: 22px; padding: 0 6px; font-size: 10px; gap: 3px; }
  .mt-tile[data-density='compact'] .mt-tabbar { height: 28px; }
  .mt-tile[data-density='roomy'] .mt-tab      { height: 34px; padding: 0 12px; gap: 6px; }
  .mt-tile[data-density='roomy'] .mt-tabbar   { height: 42px; }

  .mt-tab__title {
    max-width: 120px;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .mt-tab__close {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 14px;
    height: 14px;
    border: none;
    background: transparent;
    color: var(--fg-subtle);
    border-radius: var(--radius-sm);
    cursor: pointer;
    opacity: 0;
    padding: 0;
    transition: opacity 0.1s ease, background 0.1s ease;
    flex-shrink: 0;
  }
  .mt-tab:hover .mt-tab__close,
  .mt-tab--active .mt-tab__close { opacity: 1; }
  .mt-tab__close:hover { background: color-mix(in oklch, var(--fg) 12%, transparent); color: var(--fg); }

  .mt-tab__pin {
    display: inline-flex;
    align-items: center;
    color: var(--cnp-accent, oklch(0.72 0.18 145));
    flex-shrink: 0;
  }

  .mt-add-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    border: none;
    background: transparent;
    color: var(--fg-subtle);
    border-radius: var(--radius-sm);
    cursor: pointer;
    flex-shrink: 0;
    transition: background 0.1s ease, color 0.1s ease;
  }
  .mt-add-btn:hover { background: color-mix(in oklch, var(--fg) 10%, transparent); color: var(--fg); }

  .mt-panes-label {
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--fg-subtle);
    padding: 0 8px;
    flex: 1;
  }

  .mt-body {
    flex: 1;
    min-height: 0;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  /* Panes-view stub: pane cards row + active pane below. */
  .mt-panes-stub {
    display: flex;
    gap: 6px;
    padding: 8px;
    overflow-x: auto;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .mt-pane-card {
    appearance: none;
    border: 1px solid var(--border);
    background: var(--bg);
    border-radius: var(--radius-sm, 6px);
    padding: 8px 10px;
    min-width: 140px;
    max-width: 200px;
    text-align: left;
    cursor: pointer;
    display: flex;
    flex-direction: column;
    gap: 2px;
    color: var(--fg);
    transition: border-color 0.1s ease, background 0.1s ease;
  }

  .mt-pane-card:hover { border-color: color-mix(in oklch, var(--fg) 25%, transparent); }

  .mt-pane-card--active {
    border-color: var(--cnp-accent, oklch(0.72 0.18 145));
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 8%, transparent);
  }

  .mt-pane-card__title {
    font-size: 12px;
    font-weight: 500;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .mt-pane-card__kind {
    font-size: 10px;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .mt-panes-active {
    flex: 1;
    min-height: 0;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .mt-empty {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 6px;
    color: var(--fg-subtle);
    font-size: var(--text-sm);
    font-family: var(--font-sans);
  }

  kbd {
    font-family: var(--font-mono, monospace);
    font-size: 11px;
    padding: 1px 4px;
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    border: 1px solid var(--border);
    border-radius: 3px;
  }

  /* Metadata badges inside tab labels */
  .mt-tab__badge {
    display: inline-flex;
    align-items: center;
    font-size: 9px;
    font-family: var(--font-mono, monospace);
    color: var(--fg-subtle);
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    border: 1px solid var(--border);
    border-radius: 3px;
    padding: 0 4px;
    height: 14px;
    max-width: 64px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex-shrink: 0;
  }

  /* Context menu backdrop */
  .mt-ctx-backdrop {
    position: fixed;
    inset: 0;
    z-index: 200;
  }

  /* Context menu */
  .mt-ctx-menu {
    position: fixed;
    z-index: 201;
    margin: 0;
    padding: 4px;
    list-style: none;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius-md, 8px);
    box-shadow: 0 8px 24px color-mix(in oklch, black 20%, transparent);
    min-width: 200px;
    font-family: var(--font-sans);
    font-size: 12px;
  }

  .mt-ctx-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    padding: 6px 10px;
    border: none;
    background: transparent;
    color: var(--fg);
    border-radius: var(--radius-sm, 5px);
    cursor: pointer;
    text-align: left;
    gap: 16px;
    font: inherit;
    transition: background 0.08s ease;
  }

  .mt-ctx-item:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
  }

  .mt-ctx-item--danger {
    color: var(--fg-muted);
  }

  .mt-ctx-item--danger:hover {
    color: oklch(0.65 0.2 25);
    background: color-mix(in oklch, oklch(0.65 0.2 25) 10%, transparent);
  }

  .mt-ctx-item kbd {
    font-family: var(--font-mono, monospace);
    font-size: 10px;
    padding: 1px 4px;
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    border: 1px solid var(--border);
    border-radius: 3px;
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  .mt-ctx-separator {
    height: 1px;
    background: var(--border);
    margin: 3px 6px;
  }
</style>
