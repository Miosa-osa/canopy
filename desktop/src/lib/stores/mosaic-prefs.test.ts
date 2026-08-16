/**
 * mosaic-prefs.svelte.ts — pure-logic unit tests.
 *
 * Tests cover: defaults, sanitize() coercion, loadPrefs/savePrefs round-trip,
 * malformed input, missing key fallback, and resetPrefs.
 *
 * Pattern mirrors `sidebar-config.test.ts` — use the exported pure helpers
 * with an in-memory localStorage mock; do not instantiate the runes class
 * inside tests (runes only run inside the Svelte runtime).
 */

import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  defaultPrefs,
  loadPrefs,
  resetPrefs,
  sanitize,
  savePrefs,
  type MosaicPrefs,
} from "./mosaic-prefs.svelte.js";

const LS_KEY = "canopy.mosaic.prefs";

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
});

// ── defaultPrefs ──────────────────────────────────────────────────────────────

describe("defaultPrefs", () => {
  it("uses panes view mode", () => {
    expect(defaultPrefs.view_mode).toBe("panes");
  });

  it("uses comfortable density", () => {
    expect(defaultPrefs.density).toBe("comfortable");
  });

  it("uses command title format", () => {
    expect(defaultPrefs.pane_title_format).toBe("command");
  });

  it("includes branch in metadata_fields by default", () => {
    expect(defaultPrefs.metadata_fields).toEqual(["branch"]);
  });

  it("enables show_details_on_hover by default", () => {
    expect(defaultPrefs.show_details_on_hover).toBe(true);
  });
});

// ── sanitize ──────────────────────────────────────────────────────────────────

describe("sanitize", () => {
  it("returns defaults for null", () => {
    expect(sanitize(null)).toEqual(defaultPrefs);
  });

  it("returns defaults for undefined", () => {
    expect(sanitize(undefined)).toEqual(defaultPrefs);
  });

  it("returns defaults for non-objects", () => {
    expect(sanitize("oops")).toEqual(defaultPrefs);
    expect(sanitize(42)).toEqual(defaultPrefs);
  });

  it("coerces unknown view_mode to default", () => {
    const out = sanitize({ view_mode: "bogus" });
    expect(out.view_mode).toBe(defaultPrefs.view_mode);
  });

  it("preserves valid view_mode tabs", () => {
    expect(sanitize({ view_mode: "tabs" }).view_mode).toBe("tabs");
  });

  it("coerces unknown density to default", () => {
    expect(sanitize({ density: "huge" }).density).toBe(defaultPrefs.density);
  });

  it("preserves valid density compact", () => {
    expect(sanitize({ density: "compact" }).density).toBe("compact");
  });

  it("preserves valid density roomy", () => {
    expect(sanitize({ density: "roomy" }).density).toBe("roomy");
  });

  it("coerces unknown title format", () => {
    expect(sanitize({ pane_title_format: "wat" }).pane_title_format).toBe(
      defaultPrefs.pane_title_format,
    );
  });

  it("filters unknown metadata fields", () => {
    const out = sanitize({
      metadata_fields: ["branch", "evil", "model"],
    });
    expect(out.metadata_fields).toEqual(["branch", "model"]);
  });

  it("returns empty metadata_fields when array contains only invalid entries", () => {
    expect(sanitize({ metadata_fields: ["nope"] }).metadata_fields).toEqual([]);
  });

  it("coerces non-array metadata_fields to default", () => {
    expect(sanitize({ metadata_fields: "branch" }).metadata_fields).toEqual(
      defaultPrefs.metadata_fields,
    );
  });

  it("coerces non-boolean show_details_on_hover", () => {
    expect(
      sanitize({ show_details_on_hover: "yes" }).show_details_on_hover,
    ).toBe(defaultPrefs.show_details_on_hover);
  });

  it("preserves boolean false for show_details_on_hover", () => {
    expect(
      sanitize({ show_details_on_hover: false }).show_details_on_hover,
    ).toBe(false);
  });
});

// ── loadPrefs / savePrefs round-trip ──────────────────────────────────────────

describe("loadPrefs / savePrefs", () => {
  it("returns defaults when key missing", () => {
    expect(loadPrefs()).toEqual(defaultPrefs);
  });

  it("returns defaults when stored JSON is malformed", () => {
    localStorage.setItem(LS_KEY, "{broken json");
    expect(loadPrefs()).toEqual(defaultPrefs);
  });

  it("round-trips a saved prefs object", () => {
    const custom: MosaicPrefs = {
      view_mode: "tabs",
      density: "roomy",
      pane_title_format: "branch",
      metadata_fields: ["branch", "working_directory"],
      show_details_on_hover: false,
    };
    savePrefs(custom);
    expect(loadPrefs()).toEqual(custom);
  });

  it("sanitises a saved-then-corrupted prefs object on load", () => {
    localStorage.setItem(
      LS_KEY,
      JSON.stringify({
        view_mode: "tabs",
        density: "imaginary",
        pane_title_format: "branch",
        metadata_fields: ["branch", "totally-fake"],
        show_details_on_hover: false,
      }),
    );
    const out = loadPrefs();
    expect(out.view_mode).toBe("tabs");
    expect(out.density).toBe(defaultPrefs.density);
    expect(out.pane_title_format).toBe("branch");
    expect(out.metadata_fields).toEqual(["branch"]);
    expect(out.show_details_on_hover).toBe(false);
  });
});

// ── resetPrefs ────────────────────────────────────────────────────────────────

describe("resetPrefs", () => {
  it("clears the persisted key", () => {
    savePrefs({ ...defaultPrefs, view_mode: "tabs" });
    resetPrefs();
    expect(localStorage.getItem(LS_KEY)).toBeNull();
  });

  it("loadPrefs returns defaults after reset", () => {
    savePrefs({ ...defaultPrefs, view_mode: "tabs" });
    resetPrefs();
    expect(loadPrefs()).toEqual(defaultPrefs);
  });
});
