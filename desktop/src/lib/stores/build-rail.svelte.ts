/**
 * build-rail.svelte.ts — Svelte 5 runes store for the Build Side Rail.
 * CSS prefix: brl- (build-rail).
 *
 * Persists active section per-workspace:
 *   1. localStorage (`canopy.build.sideRail.section`) — synchronous fast cache
 *      shared across all workspaces (back-compat for first paint before the
 *      backend hydrates).
 *   2. Backend `workspace_states` (key `build.sideRail.section`) — per-
 *      workspace source of truth, persisted via the workspace-states module.
 *
 * On `workspace.changed`, the active section auto-swaps to the new
 * workspace's saved section (or DEFAULT_RAIL_SECTION if missing).
 *
 * Keys:
 *   canopy.build.sideRail.section    — RailSection | "none" (collapsed)
 *
 * Sections (in display order, top → bottom in the icon column):
 *   conversations  — Agent conversations panel (primary, ⌘1)
 *   tabs           — Open mosaic panes (⌘2)
 *   explorer       — Project file tree (⌘3)
 *   search         — Cross-file ripgrep search (⌘4)
 *   drive          — Drive entries (⌘5)
 *
 * LOC target: ≤ 240.
 */
import {
  getWorkspaceState,
  putWorkspaceState,
} from "$lib/api/queries/workspace-states.js";
import {
  activeWorkspace,
  WORKSPACE_CHANGED_EVENT,
} from "./active-workspace.svelte.js";

export type RailSection =
  | "conversations"
  | "tabs"
  | "explorer"
  | "search"
  | "drive";

/** All rail sections in display order. The icon column renders these top-to-bottom. */
export const RAIL_SECTIONS: readonly RailSection[] = [
  "conversations",
  "tabs",
  "explorer",
  "search",
  "drive",
] as const;

/** Default section selected on first boot when no localStorage entry exists. */
export const DEFAULT_RAIL_SECTION: RailSection = "conversations";

const LS_SECTION_KEY = "canopy.build.sideRail.section";

/** Backend `workspace_states` key for the per-workspace active section. */
export const RAIL_SECTION_STATE_KEY = "build.sideRail.section";

/** Debounce window for backend PUTs — matches `useWorkspaceState` (500 ms). */
const BACKEND_DEBOUNCE_MS = 500;

/** Verifies an unknown string is a valid RailSection. */
export function isRailSection(value: unknown): value is RailSection {
  return (
    typeof value === "string" &&
    (RAIL_SECTIONS as readonly string[]).includes(value)
  );
}

/** Pure helper — load the persisted section, or null if none/invalid. */
export function loadActiveSection(): RailSection | null {
  try {
    if (typeof localStorage === "undefined") return null;
    const raw = localStorage.getItem(LS_SECTION_KEY);
    if (raw === null || raw === "none") return null;
    return isRailSection(raw) ? raw : null;
  } catch {
    return null;
  }
}

/** Pure helper — persist the active section (or "none" when collapsed). */
export function saveActiveSection(section: RailSection | null): void {
  try {
    if (typeof localStorage === "undefined") return;
    localStorage.setItem(LS_SECTION_KEY, section ?? "none");
  } catch {
    // Quota / private mode — ignore.
  }
}

/** Pure helper — clear persisted state (used by tests + reset). */
export function clearActiveSection(): void {
  try {
    if (typeof localStorage !== "undefined") {
      localStorage.removeItem(LS_SECTION_KEY);
    }
  } catch {
    // ignore
  }
}

// ── Store ────────────────────────────────────────────────────────────────────

class BuildRailStore {
  /** Currently expanded section, or null when the rail is collapsed (40px only). */
  activeSection = $state<RailSection | null>(null);

  /** Pending backend-PUT timer (debounced per-workspace). */
  #backendTimer: ReturnType<typeof setTimeout> | null = null;
  /** Has the workspace.changed listener been wired? */
  #listenerWired = false;

  /** Convenience derived flag — true when a section panel is showing. */
  get isExpanded(): boolean {
    return this.activeSection !== null;
  }

  constructor() {
    if (typeof localStorage !== "undefined") {
      // First-boot: nothing persisted (load returns null) AND no explicit
      // 'none' sentinel saved → seed with DEFAULT_RAIL_SECTION so the
      // primary panel is visible on day one.
      const persisted = loadActiveSection();
      const sentinel = (() => {
        try {
          return localStorage.getItem(LS_SECTION_KEY);
        } catch {
          return null;
        }
      })();
      if (persisted) {
        this.activeSection = persisted;
      } else if (sentinel === null) {
        this.activeSection = DEFAULT_RAIL_SECTION;
        saveActiveSection(DEFAULT_RAIL_SECTION);
      }
      // sentinel === "none" → user collapsed it; respect that.
    }
    this.#wireWorkspaceListener();
    // Hydrate from backend for the currently-active workspace (if any).
    const initial = activeWorkspace.slug;
    if (initial) void this.#hydrateFromBackend(initial);
  }

  /** Subscribe once to the workspace.changed event so the active section
   *  swaps to the new workspace's saved value. Idempotent. */
  #wireWorkspaceListener(): void {
    if (this.#listenerWired) return;
    if (typeof window === "undefined") return;
    this.#listenerWired = true;
    window.addEventListener(WORKSPACE_CHANGED_EVENT, (ev: Event) => {
      const detail = (ev as CustomEvent<{ slug: string | null }>).detail;
      const nextSlug = detail?.slug ?? null;
      // eslint-disable-next-line no-console
      console.debug("[build-rail] workspace.changed →", nextSlug);
      if (nextSlug) void this.#hydrateFromBackend(nextSlug);
    });
  }

  /** GET the workspace's saved section and apply it; fall back to default. */
  async #hydrateFromBackend(slug: string): Promise<void> {
    try {
      const remote = await getWorkspaceState<RailSection | "none">(
        slug,
        RAIL_SECTION_STATE_KEY,
      );
      if (remote === null) {
        // No per-workspace value yet → keep current localStorage-derived
        // value (already shown). Do NOT overwrite the user's session.
        return;
      }
      if (remote === "none") {
        this.activeSection = null;
      } else if (isRailSection(remote)) {
        this.activeSection = remote;
      }
    } catch (err) {
      // eslint-disable-next-line no-console
      console.debug("[build-rail] backend hydrate failed:", err);
    }
  }

  /** Schedule a debounced backend PUT for the current section. */
  #scheduleBackendWrite(): void {
    if (typeof window === "undefined") return;
    const slug = activeWorkspace.slug;
    if (!slug) return;
    if (this.#backendTimer !== null) clearTimeout(this.#backendTimer);
    const sectionAtSchedule = this.activeSection;
    this.#backendTimer = setTimeout(() => {
      this.#backendTimer = null;
      const value: RailSection | "none" = sectionAtSchedule ?? "none";
      void putWorkspaceState<RailSection | "none">(
        slug,
        RAIL_SECTION_STATE_KEY,
        value,
      ).catch((err) => {
        // eslint-disable-next-line no-console
        console.debug("[build-rail] backend PUT failed:", err);
      });
    }, BACKEND_DEBOUNCE_MS);
  }

  /** Open a section. If it's already active, this is a no-op. */
  open(section: RailSection): void {
    this.activeSection = section;
    saveActiveSection(section);
    this.#scheduleBackendWrite();
  }

  /** Toggle a section: open if closed/different, collapse if same. */
  toggle(section: RailSection): void {
    if (this.activeSection === section) {
      this.collapse();
    } else {
      this.open(section);
    }
  }

  /** Collapse back to the 40px icon column. */
  collapse(): void {
    this.activeSection = null;
    saveActiveSection(null);
    this.#scheduleBackendWrite();
  }
}

export const buildRail = new BuildRailStore();
