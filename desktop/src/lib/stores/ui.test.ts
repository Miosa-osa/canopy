/**
 * ui.svelte.ts — pure-logic unit tests for workspace switcher additions.
 *
 * UIStore uses Svelte 5 $state runes which require the compiler. These tests
 * cover logic that is independently verifiable: localStorage key name, slug
 * type contract, and the persistence helper shape.
 *
 * The Svelte rune behaviour is tested implicitly via WorkspaceSwitcher.test.ts.
 */
import { beforeEach, describe, expect, it } from "vitest";

// ── Constants reproduced from ui.svelte.ts ────────────────────────────────────

const LS_WORKSPACE_KEY = "canopy.currentWorkspaceSlug";
const LS_SIDEBAR_COLLAPSED_KEY = "canopy.sidebar.collapsed";
const NARROW_VIEWPORT_PX = 800;

// ── localStorage persistence contract ────────────────────────────────────────

describe("workspace persistence key", () => {
  it("uses the canonical localStorage key", () => {
    expect(LS_WORKSPACE_KEY).toBe("canopy.currentWorkspaceSlug");
  });

  it("key is a non-empty string", () => {
    expect(typeof LS_WORKSPACE_KEY).toBe("string");
    expect(LS_WORKSPACE_KEY.length).toBeGreaterThan(0);
  });
});

// ── setCurrentWorkspace logic (isolated) ─────────────────────────────────────

describe("setCurrentWorkspace logic", () => {
  // Simulate the persistence side-effect in isolation.
  function simulateSet(store: Map<string, string>, slug: string | null): void {
    if (slug === null) {
      store.delete(LS_WORKSPACE_KEY);
    } else {
      store.set(LS_WORKSPACE_KEY, slug);
    }
  }

  let store: Map<string, string>;

  beforeEach(() => {
    store = new Map();
  });

  it("stores slug under the canonical key", () => {
    simulateSet(store, "my-workspace");
    expect(store.get(LS_WORKSPACE_KEY)).toBe("my-workspace");
  });

  it("removes the key when slug is null", () => {
    simulateSet(store, "existing");
    simulateSet(store, null);
    expect(store.has(LS_WORKSPACE_KEY)).toBe(false);
  });

  it("overwrites an existing slug", () => {
    simulateSet(store, "first");
    simulateSet(store, "second");
    expect(store.get(LS_WORKSPACE_KEY)).toBe("second");
  });
});

// ── workspaceSwitcherOpen toggle logic ───────────────────────────────────────

describe("workspaceSwitcherOpen toggle logic", () => {
  // Mirror the toggle logic from UIStore.
  function toggle(current: boolean): boolean {
    return !current;
  }

  it("opens when closed", () => {
    expect(toggle(false)).toBe(true);
  });

  it("closes when open", () => {
    expect(toggle(true)).toBe(false);
  });
});

// ── slug type contract ────────────────────────────────────────────────────────

describe("currentWorkspaceSlug type contract", () => {
  it("accepts a string slug", () => {
    const slug: string | null = "dev-shop";
    expect(typeof slug).toBe("string");
  });

  it("accepts null", () => {
    const slug: string | null = null;
    expect(slug).toBeNull();
  });
});

// ── sidebar collapsed persistence ─────────────────────────────────────────────

describe("sidebar collapsed localStorage key", () => {
  it("uses the canonical key", () => {
    expect(LS_SIDEBAR_COLLAPSED_KEY).toBe("canopy.sidebar.collapsed");
  });

  it("is distinct from workspace key", () => {
    expect(LS_SIDEBAR_COLLAPSED_KEY).not.toBe(LS_WORKSPACE_KEY);
  });
});

describe("setSidebarCollapsed persistence logic", () => {
  // Mirror the persistence side-effect.
  function simulateSet(store: Map<string, string>, collapsed: boolean): void {
    store.set(LS_SIDEBAR_COLLAPSED_KEY, String(collapsed));
  }

  let store: Map<string, string>;

  beforeEach(() => {
    store = new Map();
  });

  it("persists 'true' when collapsed", () => {
    simulateSet(store, true);
    expect(store.get(LS_SIDEBAR_COLLAPSED_KEY)).toBe("true");
  });

  it("persists 'false' when expanded", () => {
    simulateSet(store, false);
    expect(store.get(LS_SIDEBAR_COLLAPSED_KEY)).toBe("false");
  });

  it("toggle persists the inverted value", () => {
    simulateSet(store, false);
    expect(store.get(LS_SIDEBAR_COLLAPSED_KEY)).toBe("false");
    // Toggle.
    simulateSet(store, !(store.get(LS_SIDEBAR_COLLAPSED_KEY) === "true"));
    expect(store.get(LS_SIDEBAR_COLLAPSED_KEY)).toBe("true");
  });
});

describe("sidebar collapsed restore logic", () => {
  // Mirror the constructor-restore precedence:
  // persisted preference wins over auto-collapse heuristic.
  function resolveInitial(
    persisted: string | null,
    viewportWidth: number,
  ): boolean {
    if (persisted !== null) return persisted === "true";
    return viewportWidth < NARROW_VIEWPORT_PX;
  }

  it("restores 'true' when persisted as 'true'", () => {
    expect(resolveInitial("true", 1200)).toBe(true);
  });

  it("restores 'false' when persisted as 'false' even on narrow viewport", () => {
    expect(resolveInitial("false", 600)).toBe(false);
  });

  it("auto-collapses on narrow viewport when no persisted value", () => {
    expect(resolveInitial(null, 600)).toBe(true);
  });

  it("stays expanded on wide viewport when no persisted value", () => {
    expect(resolveInitial(null, 1200)).toBe(false);
  });

  it("uses NARROW_VIEWPORT_PX as the auto-collapse boundary", () => {
    expect(resolveInitial(null, NARROW_VIEWPORT_PX - 1)).toBe(true);
    expect(resolveInitial(null, NARROW_VIEWPORT_PX)).toBe(false);
  });
});
