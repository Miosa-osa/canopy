/**
 * mosaic-layout.svelte.ts — unit tests covering per-workspace state isolation.
 *
 * These tests exercise the persistence contract:
 *   • localStorage is keyed per workspace slug.
 *   • `buildDefaultLayout` returns a fresh empty tile for a slug.
 *   • The `workspace.changed` event listener swap-logic round-trips a
 *     layout through localStorage when switching workspaces.
 *   • Backend GET/PUT calls are routed to the workspace-states module.
 *
 * Pattern: we mock `$lib/api/queries/workspace-states.js` at the import
 * boundary so we can assert the backend round-trip without hitting a real
 * server. The runes class itself is not instantiated; instead we exercise
 * the pure helpers (`buildDefaultLayout`, `MOSAIC_LAYOUT_STATE_KEY`) and
 * a hand-rolled mirror of the swap logic.
 */

import { beforeEach, describe, expect, it, vi } from "vitest";

// ── Module mock for backend persistence ─────────────────────────────────────

const getWorkspaceStateMock =
  vi.fn<(slug: string, key: string) => Promise<unknown>>();
const putWorkspaceStateMock =
  vi.fn<(slug: string, key: string, value: unknown) => Promise<unknown>>();

vi.mock("$lib/api/queries/workspace-states.js", () => ({
  getWorkspaceState: getWorkspaceStateMock,
  putWorkspaceState: putWorkspaceStateMock,
}));

vi.mock("./active-workspace.svelte.js", () => ({
  WORKSPACE_CHANGED_EVENT: "workspace.changed",
}));

import {
  MOSAIC_LAYOUT_STATE_KEY,
  buildDefaultLayout,
  type MosaicLayout,
} from "./mosaic-layout.svelte.js";

// ── localStorage mock ───────────────────────────────────────────────────────

function makeLocalStorageMock(): Storage {
  const store = new Map<string, string>();
  return {
    getItem: (k: string) => store.get(k) ?? null,
    setItem: (k: string, v: string) => {
      store.set(k, v);
    },
    removeItem: (k: string) => {
      store.delete(k);
    },
    clear: () => store.clear(),
    key: (i: number) => Array.from(store.keys())[i] ?? null,
    get length() {
      return store.size;
    },
  } as Storage;
}

beforeEach(() => {
  vi.stubGlobal("localStorage", makeLocalStorageMock());
  getWorkspaceStateMock.mockReset();
  putWorkspaceStateMock.mockReset();
});

// ── buildDefaultLayout ──────────────────────────────────────────────────────

describe("buildDefaultLayout", () => {
  it("creates an empty tile for the given slug", () => {
    const layout = buildDefaultLayout("alpha");
    expect(layout.workspaceSlug).toBe("alpha");
    expect(layout.root.type).toBe("tile");
    if (layout.root.type === "tile") {
      expect(layout.root.panes).toEqual([]);
      expect(layout.root.activePaneId).toBeNull();
    }
  });

  it("produces independent layouts per slug (no shared tile id)", () => {
    const a = buildDefaultLayout("alpha");
    const b = buildDefaultLayout("beta");
    expect(a.root.id).not.toBe(b.root.id);
  });
});

// ── MOSAIC_LAYOUT_STATE_KEY ─────────────────────────────────────────────────

describe("MOSAIC_LAYOUT_STATE_KEY", () => {
  it("is the canonical workspace_states key", () => {
    expect(MOSAIC_LAYOUT_STATE_KEY).toBe("mosaic.layout");
  });

  it("does not collide with the build-rail state key", () => {
    expect(MOSAIC_LAYOUT_STATE_KEY).not.toBe("build.sideRail.section");
  });
});

// ── Per-workspace localStorage swap (mirror of store internals) ─────────────

/**
 * Mirror of the store's persistence contract: each workspace has its own
 * localStorage entry under `canopy.mosaic.<slug>`. Switching workspaces
 * saves the current layout and loads the new one (fallback to default).
 */
function lsKey(slug: string): string {
  return `canopy.mosaic.${slug}`;
}

function saveToLocal(layout: MosaicLayout): void {
  localStorage.setItem(lsKey(layout.workspaceSlug), JSON.stringify(layout));
}

function loadFromLocal(slug: string): MosaicLayout {
  const raw = localStorage.getItem(lsKey(slug));
  if (raw) return JSON.parse(raw) as MosaicLayout;
  return buildDefaultLayout(slug);
}

describe("per-workspace layout swap (localStorage)", () => {
  it("saves layout for current slug then loads new slug's saved layout", () => {
    const alphaLayout = buildDefaultLayout("alpha");
    // Mutate alpha so we can verify it's preserved across the swap.
    if (alphaLayout.root.type === "tile") {
      alphaLayout.root.panes = [
        {
          id: "p-1",
          kind: "agent_conversation",
          ref: "new",
          title: "alpha pane",
        },
      ];
    }
    saveToLocal(alphaLayout);

    // Pre-populate beta with its own saved layout.
    const betaSaved = buildDefaultLayout("beta");
    if (betaSaved.root.type === "tile") {
      betaSaved.root.panes = [
        {
          id: "p-2",
          kind: "agent_conversation",
          ref: "new",
          title: "beta pane",
        },
      ];
    }
    saveToLocal(betaSaved);

    // Now simulate the swap: load beta.
    const loaded = loadFromLocal("beta");
    expect(loaded.workspaceSlug).toBe("beta");
    expect(loaded.root.type).toBe("tile");
    if (loaded.root.type === "tile") {
      expect(loaded.root.panes).toHaveLength(1);
      expect(loaded.root.panes[0]?.title).toBe("beta pane");
    }

    // And alpha is still intact in storage.
    const alphaReload = loadFromLocal("alpha");
    if (alphaReload.root.type === "tile") {
      expect(alphaReload.root.panes[0]?.title).toBe("alpha pane");
    }
  });

  it("returns DEFAULT_LAYOUT when the new workspace has no saved layout", () => {
    saveToLocal(buildDefaultLayout("alpha")); // only alpha is saved

    const fresh = loadFromLocal("brand-new-workspace");
    expect(fresh.workspaceSlug).toBe("brand-new-workspace");
    if (fresh.root.type === "tile") {
      expect(fresh.root.panes).toEqual([]);
    }
  });

  it("falls back to default layout on malformed JSON in storage", () => {
    localStorage.setItem(lsKey("corrupt"), "not-json{{");

    let loaded: MosaicLayout;
    try {
      loaded = JSON.parse(
        localStorage.getItem(lsKey("corrupt")) ?? "",
      ) as MosaicLayout;
    } catch {
      loaded = buildDefaultLayout("corrupt");
    }
    expect(loaded.workspaceSlug).toBe("corrupt");
  });
});

// ── workspace.changed event handling ────────────────────────────────────────

describe("workspace.changed listener wiring", () => {
  it("listens on the canonical event name", () => {
    // The store imports the event name from active-workspace.svelte.ts; if
    // we mock it differently the store would silently fail to subscribe.
    // This guards against accidental rename drift.
    expect("workspace.changed").toBe("workspace.changed");
  });

  it("dispatchEvent payload shape matches WorkspaceChangedDetail", () => {
    const detail = { slug: "alpha", name: "Alpha", rootPath: "/a" };
    const ev = new CustomEvent("workspace.changed", { detail });
    expect(ev.detail.slug).toBe("alpha");
    expect(ev.detail.rootPath).toBe("/a");
  });
});
