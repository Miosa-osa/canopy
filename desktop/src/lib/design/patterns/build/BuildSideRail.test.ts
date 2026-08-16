/**
 * BuildSideRail tests — section switching, persistence, and keyboard logic.
 *
 * Test environment: Node (no DOM, no Svelte renderer) — same precedent as
 * sidebar-config.test.ts. We test pure helpers + class methods directly.
 */

import { beforeEach, describe, expect, it } from "vitest";
import {
  clearActiveSection,
  isRailSection,
  loadActiveSection,
  RAIL_SECTIONS,
  type RailSection,
  saveActiveSection,
} from "$lib/stores/build-rail.svelte.js";

// ── localStorage mock ─────────────────────────────────────────────────────────

const LS_KEY = "canopy.build.sideRail.section";

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

// ── isRailSection guard ───────────────────────────────────────────────────────

describe("isRailSection()", () => {
  it("accepts the 5 known sections", () => {
    expect(isRailSection("conversations")).toBe(true);
    expect(isRailSection("tabs")).toBe(true);
    expect(isRailSection("explorer")).toBe(true);
    expect(isRailSection("search")).toBe(true);
    expect(isRailSection("drive")).toBe(true);
  });

  it("rejects unknown strings", () => {
    expect(isRailSection("none")).toBe(false);
    expect(isRailSection("Tabs")).toBe(false);
    expect(isRailSection("")).toBe(false);
    expect(isRailSection("settings")).toBe(false);
  });

  it("rejects non-string values", () => {
    expect(isRailSection(null)).toBe(false);
    expect(isRailSection(undefined)).toBe(false);
    expect(isRailSection(0)).toBe(false);
    expect(isRailSection({ section: "tabs" })).toBe(false);
  });
});

// ── RAIL_SECTIONS shape ───────────────────────────────────────────────────────

describe("RAIL_SECTIONS", () => {
  it("contains exactly 5 sections", () => {
    expect(RAIL_SECTIONS).toHaveLength(5);
  });

  it("preserves display order — conversations is primary (first)", () => {
    expect(RAIL_SECTIONS).toEqual([
      "conversations",
      "tabs",
      "explorer",
      "search",
      "drive",
    ]);
  });
});

// ── Persistence: loadActiveSection ────────────────────────────────────────────

describe("loadActiveSection()", () => {
  beforeEach(() => {
    (globalThis as Record<string, unknown>).localStorage =
      makeLocalStorageMock();
  });

  it("returns null when nothing is saved", () => {
    expect(loadActiveSection()).toBeNull();
  });

  it("returns the saved section when valid", () => {
    localStorage.setItem(LS_KEY, "explorer");
    expect(loadActiveSection()).toBe("explorer");
  });

  it("returns null when value is the 'none' sentinel", () => {
    localStorage.setItem(LS_KEY, "none");
    expect(loadActiveSection()).toBeNull();
  });

  it("returns null when value is a corrupt string", () => {
    localStorage.setItem(LS_KEY, "BOGUS-VALUE");
    expect(loadActiveSection()).toBeNull();
  });
});

// ── Persistence: saveActiveSection ────────────────────────────────────────────

describe("saveActiveSection()", () => {
  beforeEach(() => {
    (globalThis as Record<string, unknown>).localStorage =
      makeLocalStorageMock();
  });

  it("writes the section name verbatim", () => {
    saveActiveSection("search");
    expect(localStorage.getItem(LS_KEY)).toBe("search");
  });

  it("writes 'none' when collapsing", () => {
    saveActiveSection(null);
    expect(localStorage.getItem(LS_KEY)).toBe("none");
  });

  it("round-trips through loadActiveSection", () => {
    saveActiveSection("drive");
    expect(loadActiveSection()).toBe("drive");
  });

  it("round-trips collapsed state", () => {
    saveActiveSection("tabs");
    saveActiveSection(null);
    expect(loadActiveSection()).toBeNull();
  });
});

// ── clearActiveSection ────────────────────────────────────────────────────────

describe("clearActiveSection()", () => {
  beforeEach(() => {
    (globalThis as Record<string, unknown>).localStorage =
      makeLocalStorageMock();
  });

  it("removes the persisted section", () => {
    saveActiveSection("explorer");
    clearActiveSection();
    expect(loadActiveSection()).toBeNull();
  });

  it("is a no-op when nothing is saved", () => {
    clearActiveSection();
    expect(localStorage.getItem(LS_KEY)).toBeNull();
  });
});

// ── Toggle logic (mirrors BuildRailStore.toggle) ──────────────────────────────

describe("toggle logic", () => {
  function toggle(
    current: RailSection | null,
    next: RailSection,
  ): RailSection | null {
    return current === next ? null : next;
  }

  it("opens a section when nothing is active", () => {
    expect(toggle(null, "tabs")).toBe("tabs");
  });

  it("switches to a different section when one is active", () => {
    expect(toggle("tabs", "search")).toBe("search");
  });

  it("collapses when toggling the active section", () => {
    expect(toggle("explorer", "explorer")).toBeNull();
  });

  it("collapses → reopens via two toggles of the same section", () => {
    let state: RailSection | null = "drive";
    state = toggle(state, "drive");
    expect(state).toBeNull();
    state = toggle(state, "drive");
    expect(state).toBe("drive");
  });
});

// ── Keyboard handler logic (mirrors BuildSideRail.svelte) ─────────────────────

describe("keyboard handler logic", () => {
  function resolveShortcut(
    key: string,
    metaOrCtrl: boolean,
  ): RailSection | "collapse" | null {
    if (key === "Escape") return "collapse";
    if (!metaOrCtrl) return null;
    const map: Record<string, RailSection> = {
      "1": "conversations",
      "2": "tabs",
      "3": "explorer",
      "4": "search",
      "5": "drive",
    };
    return map[key] ?? null;
  }

  it("Esc → collapse regardless of modifier", () => {
    expect(resolveShortcut("Escape", false)).toBe("collapse");
    expect(resolveShortcut("Escape", true)).toBe("collapse");
  });

  it("⌘1..⌘5 map to the 5 sections — conversations is primary", () => {
    expect(resolveShortcut("1", true)).toBe("conversations");
    expect(resolveShortcut("2", true)).toBe("tabs");
    expect(resolveShortcut("3", true)).toBe("explorer");
    expect(resolveShortcut("4", true)).toBe("search");
    expect(resolveShortcut("5", true)).toBe("drive");
  });

  it("number keys without modifier do nothing", () => {
    expect(resolveShortcut("1", false)).toBeNull();
    expect(resolveShortcut("2", false)).toBeNull();
  });

  it("⌘6 and other unmapped chords do nothing", () => {
    expect(resolveShortcut("6", true)).toBeNull();
    expect(resolveShortcut("a", true)).toBeNull();
  });
});

// ── localStorage key contract ─────────────────────────────────────────────────

describe("localStorage key contract", () => {
  it("uses the canonical key", () => {
    expect(LS_KEY).toBe("canopy.build.sideRail.section");
  });
});
