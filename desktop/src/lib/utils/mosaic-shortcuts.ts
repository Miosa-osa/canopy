/**
 * Mosaic keyboard shortcut helpers.
 *
 * Centralises the ⌘1–9 / ⌘Tab / ⌘⇧Tab / ⌘W / ⌘T behaviour for tabs in the
 * active Mosaic tile. Returns a single keydown handler — callers attach it
 * via <svelte:window onkeydown={...}> and provide the side-effects.
 *
 * The Mosaic existing tile-level shortcuts (⌘\, ⌘⇧|, ⌘⇧←/→, etc.) stay in
 * MosaicRoot.svelte. This module only owns the *tab strip* shortcuts.
 *
 * Pure: no Svelte runes, no DOM globals beyond KeyboardEvent.
 */

export interface MosaicTabShortcutHooks {
  /** Returns the active tile id, or null if none. */
  getActiveTileId: () => string | null;
  /** Returns the panes for a tile, in display order. */
  getTilePanes: (tileId: string) => Array<{ id: string }>;
  /** Returns the active pane id within a tile, or null. */
  getActivePaneId: (tileId: string) => string | null;
  /** Activate a pane by id within a tile. */
  activatePane: (tileId: string, paneId: string) => void;
  /** Close a pane by id within a tile. */
  closePane: (tileId: string, paneId: string) => void;
  /** Open the pane picker (delegates to MosaicTile / MosaicRoot). */
  openPicker: (tileId: string | null) => void;
}

/**
 * Build a keydown handler for the Mosaic tab strip shortcuts.
 *
 * Recognised shortcuts (Mac ⌘ / Win-Linux Ctrl):
 *   ⌘1 .. ⌘9         → activate Nth pane in active tile
 *   ⌘Tab             → cycle to next pane (wraps)
 *   ⌘⇧Tab            → cycle to previous pane (wraps)
 *   ⌘W               → close active pane (Mosaic root already handles; harmless duplicate)
 *   ⌘T               → open pane picker for active tile
 *
 * Returns true if the event was handled (consumer should NOT also process it).
 */
export function makeMosaicTabKeydown(
  hooks: MosaicTabShortcutHooks,
): (e: KeyboardEvent) => boolean {
  return function handleTabKeydown(e: KeyboardEvent): boolean {
    const mod = e.metaKey || e.ctrlKey;
    if (!mod) return false;

    // ⌘Tab / ⌘⇧Tab — cycle between panes in active tile.
    if (e.key === "Tab") {
      const tid = hooks.getActiveTileId();
      if (!tid) return false;
      const panes = hooks.getTilePanes(tid);
      if (panes.length === 0) return false;
      const activeId = hooks.getActivePaneId(tid);
      const idx = panes.findIndex((p) => p.id === activeId);
      const safeIdx = idx === -1 ? 0 : idx;
      const next = e.shiftKey
        ? (safeIdx - 1 + panes.length) % panes.length
        : (safeIdx + 1) % panes.length;
      e.preventDefault();
      hooks.activatePane(tid, panes[next].id);
      return true;
    }

    // ⌘1..⌘9 — direct pane activation in active tile.
    if (!e.shiftKey && /^[1-9]$/.test(e.key)) {
      const tid = hooks.getActiveTileId();
      if (!tid) return false;
      const panes = hooks.getTilePanes(tid);
      const target = panes[parseInt(e.key, 10) - 1];
      if (!target) return false;
      e.preventDefault();
      hooks.activatePane(tid, target.id);
      return true;
    }

    // ⌘W — close active pane.
    if (!e.shiftKey && e.key === "w") {
      const tid = hooks.getActiveTileId();
      if (!tid) return false;
      const activeId = hooks.getActivePaneId(tid);
      if (!activeId) return false;
      e.preventDefault();
      hooks.closePane(tid, activeId);
      return true;
    }

    // ⌘T — new pane picker.
    if (!e.shiftKey && e.key === "t") {
      e.preventDefault();
      hooks.openPicker(hooks.getActiveTileId());
      return true;
    }

    return false;
  };
}

/**
 * Reference list of tab-strip shortcuts — surfaced in the Settings popover and
 * in the Help / cheatsheet wiring (`desktop/src/lib/utils/shortcuts.ts`).
 */
export const MOSAIC_TAB_SHORTCUTS: ReadonlyArray<{
  keys: string[];
  description: string;
}> = [
  { keys: ["⌘", "1"], description: "Jump to tab 1 (1–9 supported)" },
  { keys: ["⌘", "Tab"], description: "Next tab in active tile" },
  { keys: ["⌘", "⇧", "Tab"], description: "Previous tab in active tile" },
  { keys: ["⌘", "W"], description: "Close active tab" },
  { keys: ["⌘", "T"], description: "Open new pane picker" },
];
