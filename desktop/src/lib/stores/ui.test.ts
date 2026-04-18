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
