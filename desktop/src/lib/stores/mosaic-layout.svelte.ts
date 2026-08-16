/**
 * mosaic-layout.svelte.ts — Mosaic multi-pane layout store.
 * CSS prefix: ml- (mosaic-layout)
 *
 * Persistence model (per-workspace state isolation):
 *   1. **localStorage** (`canopy.mosaic.<slug>`) — synchronous fast cache,
 *      used for first paint. Survives page reload.
 *   2. **Backend** (`workspace_states` table, key `mosaic.layout`) — cross-
 *      device source of truth, persisted via the workspace-states module
 *      (`getWorkspaceState` / `putWorkspaceState`). Writes are debounced
 *      via the `useWorkspaceState` hook contract; here we use the lower-
 *      level `putWorkspaceState` plus an in-store debounce so the singleton
 *      can be used outside of a runes-tracked component.
 *
 * Workspace switches (the `workspace.changed` window CustomEvent emitted
 * by `active-workspace.svelte.ts`) trigger a flush-then-load swap:
 *   - flush the current layout to its slug (localStorage + backend PUT)
 *   - load the new slug's layout (backend GET → localStorage fallback →
 *     DEFAULT_LAYOUT)
 *
 * LOC target: ≤ 320.
 */
import {
  getWorkspaceState,
  putWorkspaceState,
} from "$lib/api/queries/workspace-states.js";
import { WORKSPACE_CHANGED_EVENT } from "./active-workspace.svelte.js";

export type PaneKind =
  | "session"
  | "issue"
  | "task"
  | "doc"
  | "file"
  | "terminal"
  | "changes"
  | "knowledge"
  | "agent_conversation"
  | "agent_kanban"
  | "block_stream"
  | "workflow"
  | "notebook"
  | "history";

export interface Pane {
  id: string;
  kind: PaneKind;
  /** session_id, issue short_id, doc id, etc. */
  ref: string;
  title: string;
  /**
   * Optional pane-kind-specific config. Free-form by design — each pane
   * narrows it via its own type. Persisted verbatim through localStorage.
   * For agent_conversation: { sessionId?, cwd?, model? }.
   */
  config?: Record<string, unknown>;
  /** Pinned panes sort first in the tab strip and cannot be closed. */
  pinned?: boolean;
}

export interface Tile {
  type: "tile";
  id: string;
  panes: Pane[];
  activePaneId: string | null;
}

export interface Split {
  type: "split";
  id: string;
  orientation: "horizontal" | "vertical";
  /** 0–1 fraction for first child */
  ratio: number;
  a: Node;
  b: Node;
}

export type Node = Tile | Split;

export interface MosaicLayout {
  root: Node;
  workspaceSlug: string;
}

// ── helpers ────────────────────────────────────────────────────────────────────

function uid(): string {
  return Math.random().toString(36).slice(2, 9);
}

function lsKey(slug: string): string {
  return `canopy.mosaic.${slug}`;
}

/** Backend `workspace_states` key for the mosaic layout tree. */
export const MOSAIC_LAYOUT_STATE_KEY = "mosaic.layout";

/** Debounce window for backend PUTs — matches `useWorkspaceState` (500 ms). */
const BACKEND_DEBOUNCE_MS = 500;

function emptyTile(): Tile {
  return { type: "tile", id: uid(), panes: [], activePaneId: null };
}

/** Build the canonical empty layout for a workspace slug. */
export function buildDefaultLayout(slug: string): MosaicLayout {
  return { root: emptyTile(), workspaceSlug: slug };
}

function defaultLayout(slug: string): MosaicLayout {
  return buildDefaultLayout(slug);
}

/** Find the tile with `tileId` anywhere in the tree. Returns null if missing. */
function findTile(node: Node, tileId: string): Tile | null {
  if (node.type === "tile") return node.id === tileId ? node : null;
  return findTile(node.a, tileId) ?? findTile(node.b, tileId);
}

/** Collect all tiles in tree order. */
function allTiles(node: Node): Tile[] {
  if (node.type === "tile") return [node];
  return [...allTiles(node.a), ...allTiles(node.b)];
}

/** Replace a tile in the tree, returning the new tree root. */
function replaceTile(node: Node, tileId: string, replacement: Node): Node {
  if (node.type === "tile") {
    return node.id === tileId ? replacement : node;
  }
  return {
    ...node,
    a: replaceTile(node.a, tileId, replacement),
    b: replaceTile(node.b, tileId, replacement),
  };
}

/** Sort panes: pinned first, preserving relative order within each group. */
function sortedPanes(panes: Pane[]): Pane[] {
  const pinned = panes.filter((p) => p.pinned);
  const unpinned = panes.filter((p) => !p.pinned);
  return [...pinned, ...unpinned];
}

/** Remove a tile and collapse the sibling up. */
function removeTile(node: Node, tileId: string): Node | null {
  if (node.type === "tile") return node.id === tileId ? null : node;
  const newA = removeTile(node.a, tileId);
  const newB = removeTile(node.b, tileId);
  if (newA === null) return newB;
  if (newB === null) return newA;
  return { ...node, a: newA, b: newB };
}

// ── store class ────────────────────────────────────────────────────────────────

class MosaicLayoutStore {
  layout = $state<MosaicLayout>(defaultLayout("default"));

  /** Active tile: the first tile in tree order (updated by MosaicTile on focus). */
  activeTileId = $state<string | null>(null);

  /** Pending backend-PUT timer (per-workspace debounce). */
  #backendTimer: ReturnType<typeof setTimeout> | null = null;

  /** Has the workspace.changed listener been wired? */
  #listenerWired = false;

  constructor() {
    this.#wireWorkspaceListener();
  }

  /**
   * Subscribe once to the workspace.changed event so that switching the
   * active workspace flushes the current layout and loads the new one.
   * Idempotent — safe to call multiple times.
   */
  #wireWorkspaceListener(): void {
    if (this.#listenerWired) return;
    if (typeof window === "undefined") return;
    this.#listenerWired = true;

    window.addEventListener(WORKSPACE_CHANGED_EVENT, (ev: Event) => {
      const detail = (ev as CustomEvent<{ slug: string | null }>).detail;
      const nextSlug = detail?.slug ?? "default";
      // Console-log for debugging swap correctness — visible in DevTools.
      // eslint-disable-next-line no-console
      console.debug(
        "[mosaic-layout] workspace.changed →",
        this.layout.workspaceSlug,
        "→",
        nextSlug,
      );
      // Save the current layout under its current slug BEFORE we swap.
      this.save();
      // Flush any pending backend write synchronously for the OLD slug.
      this.#flushBackendNow(this.layout.workspaceSlug);
      // Load the new workspace's layout.
      void this.loadAsync(nextSlug);
    });
  }

  /**
   * Synchronous load — uses localStorage cache only. Kept as the public
   * entry point so existing callers (MosaicRoot) continue to work without
   * awaiting the backend round-trip. Backend hydration follows in
   * `loadAsync()`.
   */
  load(slug: string): void {
    const key = lsKey(slug);
    try {
      const raw =
        typeof localStorage !== "undefined" ? localStorage.getItem(key) : null;
      if (raw) {
        const parsed = JSON.parse(raw) as MosaicLayout;
        this.layout = parsed;
      } else {
        this.layout = defaultLayout(slug);
      }
    } catch {
      this.layout = defaultLayout(slug);
    }
    const tiles = allTiles(this.layout.root);
    this.activeTileId = tiles[0]?.id ?? null;

    // Kick off a backend hydration in the background — when it lands, the
    // layout is replaced with the cross-device source of truth.
    void this.#hydrateFromBackend(slug);
  }

  /**
   * Async load — preferred when wiring up workspace switches. Awaits the
   * backend GET, falling back to localStorage and finally DEFAULT_LAYOUT.
   */
  async loadAsync(slug: string): Promise<void> {
    // Optimistic cache hit first so the UI flips instantly.
    this.load(slug);
  }

  /**
   * Read the workspace's saved mosaic layout from the backend. Replaces
   * the in-memory layout if the slug still matches (guards against a fast
   * second switch).
   */
  async #hydrateFromBackend(slug: string): Promise<void> {
    try {
      const remote = await getWorkspaceState<MosaicLayout>(
        slug,
        MOSAIC_LAYOUT_STATE_KEY,
      );
      if (remote && this.layout.workspaceSlug === slug) {
        // Defensive: ensure the persisted slug matches; rewrite if the
        // backend has stale slug metadata.
        this.layout = { ...remote, workspaceSlug: slug };
        const tiles = allTiles(this.layout.root);
        this.activeTileId = tiles[0]?.id ?? null;
        // Mirror to localStorage for the next reload.
        this.#writeLocalStorage();
      }
    } catch (err) {
      // Backend may be down — degrade to localStorage gracefully.
      // eslint-disable-next-line no-console
      console.debug("[mosaic-layout] backend hydrate failed:", err);
    }
  }

  /** Write the current layout to its slug's localStorage key. */
  #writeLocalStorage(): void {
    try {
      if (typeof localStorage !== "undefined") {
        localStorage.setItem(
          lsKey(this.layout.workspaceSlug),
          JSON.stringify(this.layout),
        );
      }
    } catch {
      /* quota exceeded */
    }
  }

  /** Schedule a debounced backend PUT for the current layout. */
  #scheduleBackendWrite(): void {
    if (typeof window === "undefined") return;
    if (this.#backendTimer !== null) clearTimeout(this.#backendTimer);
    const slugAtSchedule = this.layout.workspaceSlug;
    this.#backendTimer = setTimeout(() => {
      this.#backendTimer = null;
      // Only flush if the active slug hasn't changed under us — otherwise
      // the workspace.changed handler already flushed the prior slug.
      if (this.layout.workspaceSlug === slugAtSchedule) {
        void this.#flushBackendNow(slugAtSchedule);
      }
    }, BACKEND_DEBOUNCE_MS);
  }

  /** Synchronously flush any pending backend PUT for the given slug. */
  async #flushBackendNow(slug: string): Promise<void> {
    if (this.#backendTimer !== null) {
      clearTimeout(this.#backendTimer);
      this.#backendTimer = null;
    }
    try {
      const payload =
        this.layout.workspaceSlug === slug
          ? this.layout
          : // The current store has already swapped to a different slug;
            // best-effort skip — localStorage already holds the prior
            // workspace's value via #writeLocalStorage.
            null;
      if (payload === null) return;
      await putWorkspaceState<MosaicLayout>(
        slug,
        MOSAIC_LAYOUT_STATE_KEY,
        payload,
      );
    } catch (err) {
      // eslint-disable-next-line no-console
      console.debug("[mosaic-layout] backend PUT failed:", err);
    }
  }

  save(): void {
    this.#writeLocalStorage();
    this.#scheduleBackendWrite();
  }

  reset(): void {
    this.layout = defaultLayout(this.layout.workspaceSlug);
    this.activeTileId = allTiles(this.layout.root)[0]?.id ?? null;
    this.save();
  }

  openPane(pane: Pane, targetTileId?: string): void {
    const tid = targetTileId ?? this.activeTileId;
    const tile = tid
      ? findTile(this.layout.root, tid)
      : allTiles(this.layout.root)[0];
    if (!tile) return;
    tile.panes = sortedPanes([...tile.panes, pane]);
    tile.activePaneId = pane.id;
    this.save();
  }

  /** Toggle pinned state on a pane; pinned panes sort first in the tab strip. */
  pinPane(tileId: string, paneId: string): void {
    const tile = findTile(this.layout.root, tileId);
    if (!tile) return;
    tile.panes = sortedPanes(
      tile.panes.map((p) =>
        p.id === paneId ? { ...p, pinned: !p.pinned } : p,
      ),
    );
    this.save();
  }

  closePane(tileId: string, paneId: string): void {
    const tile = findTile(this.layout.root, tileId);
    if (!tile) return;
    tile.panes = tile.panes.filter((p) => p.id !== paneId);
    if (tile.activePaneId === paneId) {
      tile.activePaneId = tile.panes[tile.panes.length - 1]?.id ?? null;
    }
    this.save();
  }

  activatePane(tileId: string, paneId: string): void {
    const tile = findTile(this.layout.root, tileId);
    if (!tile) return;
    tile.activePaneId = paneId;
    this.activeTileId = tileId;
    this.save();
  }

  movePane(
    fromTileId: string,
    paneId: string,
    toTileId: string,
    position?: number,
  ): void {
    const from = findTile(this.layout.root, fromTileId);
    const to = findTile(this.layout.root, toTileId);
    if (!from || !to) return;
    const pane = from.panes.find((p) => p.id === paneId);
    if (!pane) return;
    from.panes = from.panes.filter((p) => p.id !== paneId);
    if (from.activePaneId === paneId) {
      from.activePaneId = from.panes[from.panes.length - 1]?.id ?? null;
    }
    const idx = position !== undefined ? position : to.panes.length;
    to.panes = sortedPanes([
      ...to.panes.slice(0, idx),
      pane,
      ...to.panes.slice(idx),
    ]);
    to.activePaneId = pane.id;
    this.save();
  }

  splitTile(
    tileId: string,
    orientation: "horizontal" | "vertical",
    newPane?: Pane,
  ): void {
    const newTile = emptyTile();
    if (newPane) {
      newTile.panes = [newPane];
      newTile.activePaneId = newPane.id;
    }
    const split: Split = {
      type: "split",
      id: uid(),
      orientation,
      ratio: 0.5,
      a: { type: "tile", id: tileId, panes: [], activePaneId: null }, // placeholder
      b: newTile,
    };
    // Replace the target tile with a split, preserving its content
    const existing = findTile(this.layout.root, tileId);
    if (!existing) return;
    const splitNode: Split = { ...split, a: { ...existing } };
    this.layout.root = replaceTile(this.layout.root, tileId, splitNode);
    this.activeTileId = newTile.id;
    this.save();
  }

  closeTile(tileId: string): void {
    const root = removeTile(this.layout.root, tileId);
    if (!root) {
      this.layout.root = emptyTile();
    } else {
      this.layout.root = root;
    }
    const tiles = allTiles(this.layout.root);
    this.activeTileId = tiles[0]?.id ?? null;
    this.save();
  }

  setActiveTile(tileId: string): void {
    this.activeTileId = tileId;
  }

  allTiles(): Tile[] {
    return allTiles(this.layout.root);
  }
}

export const mosaicLayout = new MosaicLayoutStore();
