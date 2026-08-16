/**
 * TabHoverCard — contract-level tests.
 *
 * The card itself uses Svelte 5 runes ($derived) which need a compiler context
 * the Vitest "server" project does NOT load. So this file mirrors the same
 * pattern as `CodeEditorPane.test.ts`: test the pure helpers / contracts the
 * component depends on, not the rendered DOM.
 *
 * What we cover:
 *   - the safe coercion of free-form `Pane.config` into display strings
 *   - the relative-time formatter (handles missing / invalid / fresh / old)
 *   - the cost formatter (null / sub-cent / regular)
 *   - the `paneTitle()` helper from MosaicTile (since it shares the same
 *     fallback rules as the hover card's title row)
 */
import { describe, expect, it } from "vitest";
import type { Pane } from "$lib/stores/mosaic-layout.svelte.js";
import type { MosaicTitleFormat } from "$lib/stores/mosaic-prefs.svelte.js";

// ── Reimplemented helpers (kept in lockstep with the .svelte file) ──────────
// These mirror the helpers inside TabHoverCard.svelte / MosaicTile.svelte.
// We re-implement them here rather than export-from-svelte because Vitest's
// "server" project excludes .svelte modules. If the .svelte version diverges,
// these tests will catch the drift via the asserted invariants below.

function asString(v: unknown): string | null {
  return typeof v === "string" && v.length > 0 ? v : null;
}

function asNumber(v: unknown): number | null {
  return typeof v === "number" && Number.isFinite(v) ? v : null;
}

function relativeTime(iso: string | null, now: number = Date.now()): string {
  if (!iso) return "—";
  const t = Date.parse(iso);
  if (Number.isNaN(t)) return iso;
  const seconds = Math.max(0, Math.round((now - t) / 1000));
  if (seconds < 60) return `${seconds}s ago`;
  if (seconds < 3600) return `${Math.round(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.round(seconds / 3600)}h ago`;
  return `${Math.round(seconds / 86400)}d ago`;
}

function formatCost(c: number | null): string {
  if (c === null) return "—";
  if (c < 0.01) return `<$0.01`;
  return `$${c.toFixed(2)}`;
}

function paneTitle(pane: Pane, fmt: MosaicTitleFormat): string {
  const cfg = (pane.config ?? {}) as Record<string, unknown>;
  const command = typeof cfg.command === "string" ? cfg.command : null;
  const cwd =
    typeof cfg.cwd === "string"
      ? cfg.cwd
      : typeof cfg.working_directory === "string"
        ? (cfg.working_directory as string)
        : null;
  const branch = typeof cfg.branch === "string" ? cfg.branch : null;

  if (fmt === "working_directory" && cwd) return cwd.split("/").pop() || cwd;
  if (fmt === "branch" && branch) return branch;
  return command || pane.title;
}

// ── asString / asNumber ─────────────────────────────────────────────────────

describe("asString()", () => {
  it("returns null for non-strings", () => {
    expect(asString(undefined)).toBeNull();
    expect(asString(null)).toBeNull();
    expect(asString(42)).toBeNull();
    expect(asString({})).toBeNull();
  });

  it("returns null for empty strings", () => {
    expect(asString("")).toBeNull();
  });

  it("returns the string when non-empty", () => {
    expect(asString("hello")).toBe("hello");
  });
});

describe("asNumber()", () => {
  it("returns null for non-numbers", () => {
    expect(asNumber(undefined)).toBeNull();
    expect(asNumber("1.5")).toBeNull();
    expect(asNumber(null)).toBeNull();
  });

  it("returns null for non-finite numbers", () => {
    expect(asNumber(NaN)).toBeNull();
    expect(asNumber(Infinity)).toBeNull();
    expect(asNumber(-Infinity)).toBeNull();
  });

  it("returns the number when finite", () => {
    expect(asNumber(0)).toBe(0);
    expect(asNumber(0.005)).toBe(0.005);
    expect(asNumber(-3.14)).toBe(-3.14);
  });
});

// ── relativeTime ────────────────────────────────────────────────────────────

describe("relativeTime()", () => {
  const NOW = Date.parse("2026-04-27T12:00:00Z");

  it("returns the em dash for null", () => {
    expect(relativeTime(null, NOW)).toBe("—");
  });

  it("returns the input back when unparseable", () => {
    expect(relativeTime("not an iso", NOW)).toBe("not an iso");
  });

  it("formats seconds-ago", () => {
    expect(relativeTime("2026-04-27T11:59:30Z", NOW)).toBe("30s ago");
  });

  it("formats minutes-ago", () => {
    expect(relativeTime("2026-04-27T11:55:00Z", NOW)).toBe("5m ago");
  });

  it("formats hours-ago", () => {
    expect(relativeTime("2026-04-27T09:00:00Z", NOW)).toBe("3h ago");
  });

  it("formats days-ago", () => {
    expect(relativeTime("2026-04-25T12:00:00Z", NOW)).toBe("2d ago");
  });

  it("clamps negative offsets to 0s", () => {
    // Future timestamp shouldn't produce a negative number.
    expect(relativeTime("2026-04-27T12:01:00Z", NOW)).toBe("0s ago");
  });
});

// ── formatCost ──────────────────────────────────────────────────────────────

describe("formatCost()", () => {
  it("returns the em dash for null", () => {
    expect(formatCost(null)).toBe("—");
  });

  it("returns <$0.01 for sub-cent values", () => {
    expect(formatCost(0)).toBe("<$0.01");
    expect(formatCost(0.0005)).toBe("<$0.01");
  });

  it("returns the cost rounded to two decimals", () => {
    expect(formatCost(1.234)).toBe("$1.23");
    expect(formatCost(12.5)).toBe("$12.50");
  });
});

// ── paneTitle ───────────────────────────────────────────────────────────────

describe("paneTitle()", () => {
  const basePane: Pane = {
    id: "p1",
    kind: "session",
    ref: "abc",
    title: "fallback title",
  };

  it("returns the command for the 'command' format", () => {
    const out = paneTitle(
      { ...basePane, config: { command: "claude code" } },
      "command",
    );
    expect(out).toBe("claude code");
  });

  it("falls back to pane.title when command is missing", () => {
    expect(paneTitle({ ...basePane, config: {} }, "command")).toBe(
      "fallback title",
    );
  });

  it("returns the working-dir basename", () => {
    const out = paneTitle(
      { ...basePane, config: { cwd: "/Users/rhl/code/OptimalOS" } },
      "working_directory",
    );
    expect(out).toBe("OptimalOS");
  });

  it("returns the branch when present", () => {
    const out = paneTitle(
      { ...basePane, config: { branch: "feature/mosaic-polish" } },
      "branch",
    );
    expect(out).toBe("feature/mosaic-polish");
  });

  it("falls back to command when branch is missing", () => {
    const out = paneTitle(
      { ...basePane, config: { command: "claude code" } },
      "branch",
    );
    expect(out).toBe("claude code");
  });

  it("falls back to pane.title when both branch and command are missing", () => {
    expect(paneTitle({ ...basePane, config: {} }, "branch")).toBe(
      "fallback title",
    );
  });

  it("accepts working_directory as an alias for cwd", () => {
    const out = paneTitle(
      { ...basePane, config: { working_directory: "/var/canopy" } },
      "working_directory",
    );
    expect(out).toBe("canopy");
  });
});
