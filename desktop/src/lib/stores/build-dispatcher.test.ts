/**
 * build-dispatcher.svelte.ts — unit tests.
 *
 * The dispatcher is a thin translator: each `ConductorAction` should produce
 * exactly the right `mosaicLayout` / `mosaicPrefs` mutation.
 *
 * Pattern: the dispatcher is plain TS (no `$state` runes — see the source
 * docstring), so it can be instantiated directly inside Node-environment
 * vitest. We mock the `mosaic-layout.svelte.js` and `mosaic-prefs.svelte.js`
 * modules at the import boundary and assert call shape.
 */

import { beforeEach, describe, expect, it, vi } from "vitest";

// ── Module mocks (must be hoisted before the dispatcher import) ──────────────

const openPaneMock = vi.fn();
const closePaneMock = vi.fn();
const activatePaneMock = vi.fn();
const splitTileMock = vi.fn();
const allTilesMock =
  vi.fn<() => Array<{ id: string; panes: Array<{ id: string }> }>>();

const setDensityMock = vi.fn();
const setTitleFormatMock = vi.fn();

vi.mock("./mosaic-layout.svelte.js", () => ({
  mosaicLayout: {
    openPane: openPaneMock,
    closePane: closePaneMock,
    activatePane: activatePaneMock,
    splitTile: splitTileMock,
    allTiles: allTilesMock,
  },
}));

vi.mock("./mosaic-prefs.svelte.js", () => ({
  mosaicPrefs: {
    setDensity: setDensityMock,
    setTitleFormat: setTitleFormatMock,
  },
}));

// Imports must come AFTER vi.mock declarations.
import { buildDispatcher, __test } from "./build-dispatcher.svelte.js";

// ── Setup ────────────────────────────────────────────────────────────────────

beforeEach(() => {
  openPaneMock.mockReset();
  closePaneMock.mockReset();
  activatePaneMock.mockReset();
  splitTileMock.mockReset();
  allTilesMock.mockReset();
  setDensityMock.mockReset();
  setTitleFormatMock.mockReset();
  // Default: no tiles found (covers no-op safety paths).
  allTilesMock.mockReturnValue([]);
});

// ── Pure helpers ─────────────────────────────────────────────────────────────

describe("mapBackendPaneKind", () => {
  it("maps terminal to terminal", () => {
    expect(__test.mapBackendPaneKind("terminal")).toBe("terminal");
  });

  it("maps file_viewer and code_editor to file", () => {
    expect(__test.mapBackendPaneKind("file_viewer")).toBe("file");
    expect(__test.mapBackendPaneKind("code_editor")).toBe("file");
  });

  it("maps diff to changes", () => {
    expect(__test.mapBackendPaneKind("diff")).toBe("changes");
  });

  it("maps block_stream to session", () => {
    expect(__test.mapBackendPaneKind("block_stream")).toBe("session");
  });

  it("maps mcp to agent_conversation", () => {
    expect(__test.mapBackendPaneKind("mcp")).toBe("agent_conversation");
  });
});

describe("directionToOrientation", () => {
  it("treats left/right as vertical", () => {
    expect(__test.directionToOrientation("left")).toBe("vertical");
    expect(__test.directionToOrientation("right")).toBe("vertical");
  });

  it("treats up/down as horizontal", () => {
    expect(__test.directionToOrientation("up")).toBe("horizontal");
    expect(__test.directionToOrientation("down")).toBe("horizontal");
  });
});

describe("deriveTitle", () => {
  it("prefers path", () => {
    expect(__test.deriveTitle("file_viewer", { path: "lib/foo.ex" })).toBe(
      "lib/foo.ex",
    );
  });

  it("falls back to queued_command for terminal", () => {
    expect(__test.deriveTitle("terminal", { queued_command: "mix test" })).toBe(
      "mix test",
    );
  });

  it("uses pane kind as last resort", () => {
    expect(__test.deriveTitle("mcp", {})).toBe("mcp");
  });
});

describe("deriveRef", () => {
  it("prefers file_id", () => {
    expect(__test.deriveRef({ file_id: "abc", path: "foo.ex" })).toBe("abc");
  });

  it("falls back through known keys", () => {
    expect(__test.deriveRef({ block_id: "blk-1" })).toBe("blk-1");
    expect(__test.deriveRef({ session_id: "sess-1" })).toBe("sess-1");
    expect(__test.deriveRef({ path: "foo.ex" })).toBe("foo.ex");
  });

  it("returns empty string when no recognised key is present", () => {
    expect(__test.deriveRef({ irrelevant: "x" })).toBe("");
    expect(__test.deriveRef({})).toBe("");
  });
});

// ── dispatch — open_pane ────────────────────────────────────────────────────

describe("dispatch open_pane", () => {
  it("calls mosaicLayout.openPane with mapped kind and config preserved", () => {
    buildDispatcher.dispatch({
      action: "open_pane",
      pane_kind: "terminal",
      config: { queued_command: "ls" },
    });

    expect(openPaneMock).toHaveBeenCalledTimes(1);
    const [pane] = openPaneMock.mock.calls[0];
    expect(pane.kind).toBe("terminal");
    expect(pane.title).toBe("ls");
    expect(pane.config).toEqual({ queued_command: "ls" });
    expect(pane.id).toMatch(/^cond-/);
  });

  it("accepts a wrapped tool result", () => {
    buildDispatcher.dispatch({
      tool: "build.open_file",
      result: {
        action: "open_pane",
        pane_kind: "code_editor",
        config: { path: "lib/foo.ex" },
      },
    });

    expect(openPaneMock).toHaveBeenCalledTimes(1);
    const [pane] = openPaneMock.mock.calls[0];
    expect(pane.kind).toBe("file");
    expect(pane.title).toBe("lib/foo.ex");
  });
});

// ── dispatch — split_pane ───────────────────────────────────────────────────

describe("dispatch split_pane", () => {
  it("looks up the owning tile and calls mosaicLayout.splitTile", () => {
    allTilesMock.mockReturnValue([
      { id: "tile-1", panes: [{ id: "pane-A" }] },
      { id: "tile-2", panes: [{ id: "pane-B" }] },
    ]);

    buildDispatcher.dispatch({
      action: "split_pane",
      pane_id: "pane-B",
      direction: "right",
      new_pane_kind: "terminal",
      new_config: {},
    });

    expect(splitTileMock).toHaveBeenCalledTimes(1);
    const [tileId, orientation, newPane] = splitTileMock.mock.calls[0];
    expect(tileId).toBe("tile-2");
    expect(orientation).toBe("vertical");
    expect(newPane.kind).toBe("terminal");
  });

  it("is a safe no-op when the target pane is gone", () => {
    allTilesMock.mockReturnValue([{ id: "tile-1", panes: [] }]);

    buildDispatcher.dispatch({
      action: "split_pane",
      pane_id: "missing",
      direction: "down",
      new_pane_kind: "diff",
      new_config: {},
    });

    expect(splitTileMock).not.toHaveBeenCalled();
  });
});

// ── dispatch — close_pane / focus_pane ──────────────────────────────────────

describe("dispatch close_pane", () => {
  it("delegates to mosaicLayout.closePane", () => {
    allTilesMock.mockReturnValue([{ id: "tile-1", panes: [{ id: "pane-A" }] }]);

    buildDispatcher.dispatch({ action: "close_pane", pane_id: "pane-A" });

    expect(closePaneMock).toHaveBeenCalledWith("tile-1", "pane-A");
  });

  it("is a no-op when the target pane is gone", () => {
    allTilesMock.mockReturnValue([]);
    buildDispatcher.dispatch({ action: "close_pane", pane_id: "ghost" });
    expect(closePaneMock).not.toHaveBeenCalled();
  });
});

describe("dispatch focus_pane", () => {
  it("delegates to mosaicLayout.activatePane", () => {
    allTilesMock.mockReturnValue([{ id: "tile-1", panes: [{ id: "pane-A" }] }]);

    buildDispatcher.dispatch({ action: "focus_pane", pane_id: "pane-A" });

    expect(activatePaneMock).toHaveBeenCalledWith("tile-1", "pane-A");
  });

  it("is a no-op when the target pane is gone", () => {
    allTilesMock.mockReturnValue([]);
    buildDispatcher.dispatch({ action: "focus_pane", pane_id: "ghost" });
    expect(activatePaneMock).not.toHaveBeenCalled();
  });
});

// ── dispatch — load_layout / set_density ────────────────────────────────────

describe("dispatch load_layout", () => {
  it("applies density and pane_title_format to mosaicPrefs", () => {
    buildDispatcher.dispatch({
      action: "load_layout",
      slug: "review-pr",
      scope: "personal",
      layout_json: {},
      density: "compact",
      pane_title_format: "branch",
    });

    expect(setDensityMock).toHaveBeenCalledWith("compact");
    expect(setTitleFormatMock).toHaveBeenCalledWith("branch");
  });

  it("ignores invalid pane_title_format", () => {
    buildDispatcher.dispatch({
      action: "load_layout",
      slug: "x",
      scope: "personal",
      layout_json: {},
      density: null,
      pane_title_format: "totally-bogus",
    });

    expect(setTitleFormatMock).not.toHaveBeenCalled();
  });
});

describe("dispatch set_density", () => {
  it("delegates to mosaicPrefs.setDensity", () => {
    buildDispatcher.dispatch({ action: "set_density", level: "roomy" });
    expect(setDensityMock).toHaveBeenCalledWith("roomy");
  });
});

// ── dispatch — save_layout (acknowledged but no mosaic mutation) ────────────

describe("dispatch save_layout", () => {
  it("does not mutate the mosaic but is recognized (no warning)", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => undefined);

    buildDispatcher.dispatch({
      action: "save_layout",
      slug: "x",
      scope: "personal",
      id: "id-1",
    });

    expect(openPaneMock).not.toHaveBeenCalled();
    expect(splitTileMock).not.toHaveBeenCalled();
    expect(warn).not.toHaveBeenCalled();

    warn.mockRestore();
  });
});

// ── dispatch — malformed and unknown ────────────────────────────────────────

describe("dispatch malformed input", () => {
  it("logs a warning and does not throw on null", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    expect(() => buildDispatcher.dispatch(null)).not.toThrow();
    expect(warn).toHaveBeenCalled();
    warn.mockRestore();
  });

  it("logs a warning and does not throw on string input", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    expect(() => buildDispatcher.dispatch("oops")).not.toThrow();
    expect(warn).toHaveBeenCalled();
    warn.mockRestore();
  });

  it("logs a warning when action is unknown", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    // Cast through unknown — runtime path expects loose input.
    buildDispatcher.dispatch({ action: "bogus_op" } as unknown);
    expect(warn).toHaveBeenCalled();
    warn.mockRestore();
  });
});
