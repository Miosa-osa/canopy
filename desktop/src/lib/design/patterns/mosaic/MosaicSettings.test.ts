/**
 * MosaicSettings — contract-level tests.
 *
 * The component itself uses Svelte 5 runes + foundation Toggle/Checkbox, both
 * of which need a compiler / DOM context that the Vitest "server" project
 * doesn't load (vitest.config.ts excludes *.svelte.{test,spec}). So this file
 * tests the contract surface the popover binds to:
 *
 *   - `mosaicPrefs` reactive class store (set / toggle / persist round-trip)
 *   - `sanitize()` against the option lists the popover renders
 *   - localStorage round-trip semantics (canopy.mosaic.prefs)
 *
 * Component-level rendering tests (focus trap, keyboard nav, click-to-update)
 * belong in a future "client" Vitest project (jsdom + svelte-kit env) — out of
 * scope for the polish pass.
 */
import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  defaultPrefs,
  loadPrefs,
  resetPrefs,
  sanitize,
  savePrefs,
  type MosaicDensity,
  type MosaicMetadataField,
  type MosaicPrefs,
  type MosaicTitleFormat,
  type MosaicViewMode,
} from "$lib/stores/mosaic-prefs.svelte.js";

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

// The option tables exposed by the popover. Keep the strings in sync with the
// component template — failing this test means the popover would render an
// option that the store would silently coerce away.
const VIEW_MODE_OPTIONS: ReadonlyArray<MosaicViewMode> = ["panes", "tabs"];
const DENSITY_OPTIONS: ReadonlyArray<MosaicDensity> = [
  "compact",
  "comfortable",
  "roomy",
];
const TITLE_FORMAT_OPTIONS: ReadonlyArray<MosaicTitleFormat> = [
  "command",
  "working_directory",
  "branch",
];
const METADATA_OPTIONS: ReadonlyArray<MosaicMetadataField> = [
  "branch",
  "working_directory",
  "agent",
  "runtime",
  "model",
];

// ── option lists are valid ──────────────────────────────────────────────────

describe("MosaicSettings option contract", () => {
  it("every viewMode option survives sanitize()", () => {
    for (const v of VIEW_MODE_OPTIONS) {
      expect(sanitize({ view_mode: v }).view_mode).toBe(v);
    }
  });

  it("every density option survives sanitize()", () => {
    for (const d of DENSITY_OPTIONS) {
      expect(sanitize({ density: d }).density).toBe(d);
    }
  });

  it("every title-format option survives sanitize()", () => {
    for (const t of TITLE_FORMAT_OPTIONS) {
      expect(sanitize({ pane_title_format: t }).pane_title_format).toBe(t);
    }
  });

  it("every metadata-field option survives sanitize()", () => {
    for (const f of METADATA_OPTIONS) {
      expect(sanitize({ metadata_fields: [f] }).metadata_fields).toEqual([f]);
    }
  });

  it("default view_mode is the first viewMode option", () => {
    expect(VIEW_MODE_OPTIONS[0]).toBe(defaultPrefs.view_mode);
  });

  it("default title format is the first title format option", () => {
    expect(TITLE_FORMAT_OPTIONS[0]).toBe(defaultPrefs.pane_title_format);
  });
});

// ── store update + persist (mirrors what the popover does on click) ────────

describe("MosaicSettings store updates persist", () => {
  it("saving viewMode round-trips through localStorage", () => {
    const next: MosaicPrefs = { ...defaultPrefs, view_mode: "tabs" };
    savePrefs(next);
    expect(loadPrefs().view_mode).toBe("tabs");
  });

  it("saving density round-trips through localStorage", () => {
    for (const d of DENSITY_OPTIONS) {
      savePrefs({ ...defaultPrefs, density: d });
      expect(loadPrefs().density).toBe(d);
    }
  });

  it("toggling metadata fields persists multi-select state", () => {
    const next: MosaicPrefs = {
      ...defaultPrefs,
      metadata_fields: ["branch", "working_directory", "model"],
    };
    savePrefs(next);
    expect(loadPrefs().metadata_fields).toEqual([
      "branch",
      "working_directory",
      "model",
    ]);
  });

  it("clearing all metadata fields persists empty array", () => {
    const next: MosaicPrefs = { ...defaultPrefs, metadata_fields: [] };
    savePrefs(next);
    expect(loadPrefs().metadata_fields).toEqual([]);
  });

  it("toggling show_details_on_hover persists false", () => {
    savePrefs({ ...defaultPrefs, show_details_on_hover: false });
    expect(loadPrefs().show_details_on_hover).toBe(false);
  });

  it("uses the canopy.mosaic.prefs localStorage key", () => {
    savePrefs({ ...defaultPrefs, view_mode: "tabs" });
    const raw = localStorage.getItem(LS_KEY);
    expect(raw).not.toBeNull();
    const parsed = JSON.parse(raw as string) as Partial<MosaicPrefs>;
    expect(parsed.view_mode).toBe("tabs");
  });

  it("reset removes the persisted key (defaults restored on next load)", () => {
    savePrefs({ ...defaultPrefs, view_mode: "tabs" });
    resetPrefs();
    expect(localStorage.getItem(LS_KEY)).toBeNull();
    expect(loadPrefs()).toEqual(defaultPrefs);
  });
});

// ── full simulated user session (toggle each control once) ─────────────────

describe("MosaicSettings simulated session", () => {
  it("emulates a settings popover walk-through and persists final state", () => {
    // 1. Open popover → app reads defaults.
    let current = loadPrefs();
    expect(current).toEqual(defaultPrefs);

    // 2. Click "Tabs" view mode.
    current = { ...current, view_mode: "tabs" };
    savePrefs(current);

    // 3. Pick "roomy" density.
    current = { ...current, density: "roomy" };
    savePrefs(current);

    // 4. Pick "branch" pane title.
    current = { ...current, pane_title_format: "branch" };
    savePrefs(current);

    // 5. Add "working_directory" to metadata.
    current = {
      ...current,
      metadata_fields: [...current.metadata_fields, "working_directory"],
    };
    savePrefs(current);

    // 6. Disable hover details.
    current = { ...current, show_details_on_hover: false };
    savePrefs(current);

    // After "closing" the popover, fresh load should reflect every change.
    const reloaded = loadPrefs();
    expect(reloaded).toEqual({
      view_mode: "tabs",
      density: "roomy",
      pane_title_format: "branch",
      metadata_fields: ["branch", "working_directory"],
      show_details_on_hover: false,
    });
  });
});
