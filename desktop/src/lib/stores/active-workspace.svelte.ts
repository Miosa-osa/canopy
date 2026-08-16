/**
 * active-workspace.svelte.ts — Svelte 5 runes singleton tracking the
 * **currently active workspace**.
 *
 * Every module that needs to read the user's active workspace (Mosaic
 * shells, AgentConversationPane, terminal cwd, files page, build cockpit)
 * imports `activeWorkspace` from this module and reads `slug | name |
 * rootPath`. When `setActive(slug)` is called the store:
 *
 *   1. Validates the slug exists in the most-recent workspace list
 *   2. Updates `slug | name | rootPath`
 *   3. Persists `slug` to `localStorage` under `canopy.activeWorkspace.slug`
 *   4. Dispatches a `workspace.changed` CustomEvent on `window` so any
 *      listeners (legacy non-rune code, Tauri shell) can react
 *
 * On boot the store hydrates from localStorage; if no slug is persisted
 * (or the persisted slug no longer exists) it falls back to the first
 * workspace returned from the API.
 *
 * Pattern note: this DOES NOT replace `ui.currentWorkspaceSlug`. Existing
 * components (WorkspaceSwitcher) keep using `ui` for the dropdown UI;
 * `activeWorkspace` is the canonical source of truth that includes
 * `name` and `rootPath`. Both are kept in sync via `setActive()`.
 */

import type { Workspace } from "$lib/domain/workspaces/types.js";

const LS_KEY = "canopy.activeWorkspace.slug";
const EVENT_NAME = "workspace.changed";

/**
 * Detail payload for the `workspace.changed` CustomEvent. Listeners can
 * inspect `slug`, `name`, `rootPath` without re-querying the API.
 */
export interface WorkspaceChangedDetail {
  slug: string | null;
  name: string | null;
  rootPath: string | null;
}

/**
 * Class-based Svelte 5 rune store. Singleton — see `activeWorkspace`
 * export at the bottom of this module.
 */
class ActiveWorkspaceStore {
  /** Slug of the active workspace, or `null` if none is active. */
  slug = $state<string | null>(null);

  /** Display name of the active workspace, or `null` if none is active. */
  name = $state<string | null>(null);

  /** Absolute filesystem root, or `null` if none is active. */
  rootPath = $state<string | null>(null);

  /** Most-recent workspace list from the API — used to look up name/rootPath. */
  #pool: Workspace[] = [];

  constructor() {
    if (typeof localStorage !== "undefined") {
      const saved = localStorage.getItem(LS_KEY);
      if (saved) this.slug = saved;
    }
  }

  /**
   * Update the cached workspace pool (called by any consumer that has
   * already fetched the list — typically TanStack Query subscribers).
   *
   * If the active slug is unset the first workspace is auto-selected.
   * If the active slug is set but no longer exists in the pool, it is
   * cleared and the first workspace is auto-selected (fail-safe — the
   * persisted slug was deleted by a different client).
   */
  syncPool(workspaces: Workspace[]): void {
    this.#pool = workspaces;

    if (this.slug === null && workspaces.length > 0) {
      this.#applyWorkspace(workspaces[0]);
      this.#persist(workspaces[0].slug);
      return;
    }

    if (this.slug !== null) {
      const found = workspaces.find((w) => w.slug === this.slug) ?? null;
      if (found) {
        // Refresh name/rootPath in case the workspace was renamed/moved.
        this.name = found.name;
        this.rootPath = found.rootPath;
      } else if (workspaces.length > 0) {
        this.#applyWorkspace(workspaces[0]);
        this.#persist(workspaces[0].slug);
      } else {
        this.#clear();
      }
    }
  }

  /**
   * Switch the active workspace to the given slug.
   *
   * Validates the slug exists in the cached pool. Returns `true` on
   * success, `false` if the slug is unknown (in which case nothing
   * changes — call `syncPool()` first if the workspace was just
   * created).
   */
  setActive(slug: string | null): boolean {
    if (slug === null) {
      this.#clear();
      this.#persist(null);
      this.#emit();
      return true;
    }

    const found = this.#pool.find((w) => w.slug === slug);
    if (!found) return false;

    this.#applyWorkspace(found);
    this.#persist(slug);
    this.#emit();
    return true;
  }

  /**
   * Returns true when a workspace is active. Components can `$derived`
   * this to gate their rendering.
   */
  get isActive(): boolean {
    return this.slug !== null;
  }

  // ── Private helpers ────────────────────────────────────────────────────

  #applyWorkspace(ws: Workspace): void {
    this.slug = ws.slug;
    this.name = ws.name;
    this.rootPath = ws.rootPath;
  }

  #clear(): void {
    this.slug = null;
    this.name = null;
    this.rootPath = null;
  }

  #persist(slug: string | null): void {
    if (typeof localStorage === "undefined") return;
    if (slug === null) {
      localStorage.removeItem(LS_KEY);
    } else {
      localStorage.setItem(LS_KEY, slug);
    }
  }

  #emit(): void {
    if (typeof window === "undefined") return;
    const detail: WorkspaceChangedDetail = {
      slug: this.slug,
      name: this.name,
      rootPath: this.rootPath,
    };
    window.dispatchEvent(new CustomEvent(EVENT_NAME, { detail }));
  }
}

/** Singleton — import this from any module that needs the active workspace. */
export const activeWorkspace = new ActiveWorkspaceStore();

/** Persistence key (exported for tests + parity with `ui.svelte.ts`). */
export const ACTIVE_WORKSPACE_LS_KEY = LS_KEY;

/** CustomEvent name dispatched on every `setActive()` call. */
export const WORKSPACE_CHANGED_EVENT = EVENT_NAME;
