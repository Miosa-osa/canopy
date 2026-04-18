/**
 * CommandPalette — unit tests for pure logic extracted from the component.
 *
 * Tests cover:
 *   1. Fuzzy scoring algorithm (exact prefix > word-boundary > contains > subsequence)
 *   2. Match span / segment highlighting
 *   3. Recency LRU: cap at 8, LRU eviction, read/write round-trip
 *   4. Empty search shows all commands (no filter applied)
 *   5. No match returns empty
 */

import { beforeEach, describe, expect, it } from "vitest";

// ── Fuzzy scoring (mirrored from CommandPalette.svelte) ───────────────────────

interface Command {
  id: string;
  label: string;
  group: string;
}

function fuzzyScore(cmd: Command, q: string): number {
  if (!q) return 1;
  const label = cmd.label.toLowerCase();
  const lower = q.toLowerCase();

  const words = label.split(/\s+/);
  if (words.some((w) => w.startsWith(lower))) return 4;

  if (
    words.some((w) => w.charAt(0) === lower.charAt(0)) &&
    label.includes(lower.charAt(0))
  ) {
    if (
      words.some((w) => w.startsWith(lower.charAt(0)) && label.includes(lower))
    )
      return 3;
  }

  if (label.includes(lower)) return 2;

  if (isSubsequence(lower, label)) return 1;

  return 0;
}

function isSubsequence(needle: string, haystack: string): boolean {
  let ni = 0;
  for (let hi = 0; hi < haystack.length && ni < needle.length; hi++) {
    if (haystack[hi] === needle[ni]) ni++;
  }
  return ni === needle.length;
}

function makeCmd(id: string, label: string, group = "Test"): Command {
  return { id, label, group };
}

// ── Match spans (mirrored from CommandPalette.svelte) ─────────────────────────

function matchSpans(label: string, q: string): Array<[number, number]> {
  if (!q.trim()) return [];
  const lower = q.toLowerCase();
  const labelLower = label.toLowerCase();

  const idx = labelLower.indexOf(lower);
  if (idx !== -1) return [[idx, idx + lower.length]];

  const spans: Array<[number, number]> = [];
  let ni = 0;
  for (let hi = 0; hi < labelLower.length && ni < lower.length; hi++) {
    if (labelLower[hi] === lower[ni]) {
      spans.push([hi, hi + 1]);
      ni++;
    }
  }
  return spans;
}

interface LabelSegment {
  text: string;
  bold: boolean;
}

function segmentLabel(label: string, q: string): LabelSegment[] {
  const spans = matchSpans(label, q);
  if (spans.length === 0) return [{ text: label, bold: false }];

  const segments: LabelSegment[] = [];
  let cursor = 0;
  for (const [start, end] of spans) {
    if (start > cursor)
      segments.push({ text: label.slice(cursor, start), bold: false });
    segments.push({ text: label.slice(start, end), bold: true });
    cursor = end;
  }
  if (cursor < label.length)
    segments.push({ text: label.slice(cursor), bold: false });
  return segments;
}

// ── Recency LRU (mirrored from CommandPalette.svelte) ─────────────────────────

const RECENT_MAX = 8;

function pushRecent(ids: string[], id: string): string[] {
  const prev = ids.filter((x) => x !== id);
  return [id, ...prev].slice(0, RECENT_MAX);
}

// ── Tests: fuzzy scoring ──────────────────────────────────────────────────────

describe("fuzzyScore() — exact prefix (score 4)", () => {
  it("scores 4 when query matches start of label word", () => {
    const cmd = makeCmd("1", "Go to Home");
    expect(fuzzyScore(cmd, "go")).toBe(4);
  });

  it("scores 4 for prefix of second word", () => {
    const cmd = makeCmd("1", "Open Settings");
    expect(fuzzyScore(cmd, "set")).toBe(4);
  });

  it("is case-insensitive", () => {
    const cmd = makeCmd("1", "New Session");
    expect(fuzzyScore(cmd, "NEW")).toBe(4);
  });
});

describe("fuzzyScore() — contains match (score 2)", () => {
  it("scores 2 for mid-word substring", () => {
    const cmd = makeCmd("1", "Toggle Theme");
    expect(fuzzyScore(cmd, "oggle")).toBe(2);
  });
});

describe("fuzzyScore() — subsequence match (score 1)", () => {
  it("scores 1 for scattered chars present in order", () => {
    const cmd = makeCmd("1", "Open Settings");
    // 'oes' appears in order: O-pen S-et-t-ing-s
    expect(fuzzyScore(cmd, "oes")).toBeGreaterThanOrEqual(1);
  });
});

describe("fuzzyScore() — no match (score 0)", () => {
  it("scores 0 when chars are not a subsequence", () => {
    const cmd = makeCmd("1", "Go to Home");
    // 'xyz' cannot appear as subsequence in 'go to home'
    expect(fuzzyScore(cmd, "xyz")).toBe(0);
  });
});

describe("fuzzyScore() — empty query (score 1)", () => {
  it("returns 1 for all commands when query is empty", () => {
    const cmd = makeCmd("1", "Any Command");
    expect(fuzzyScore(cmd, "")).toBe(1);
  });
});

// ── Tests: match segment highlighting ────────────────────────────────────────

describe("segmentLabel()", () => {
  it("returns single non-bold segment when no query", () => {
    const segs = segmentLabel("Go to Home", "");
    expect(segs).toEqual([{ text: "Go to Home", bold: false }]);
  });

  it("highlights substring match", () => {
    const segs = segmentLabel("Go to Home", "Home");
    const boldSeg = segs.find((s) => s.bold);
    expect(boldSeg?.text.toLowerCase()).toBe("home");
  });

  it("produces exactly 3 segments for mid-string match", () => {
    const segs = segmentLabel("Open Settings", "Set");
    expect(segs.length).toBe(3);
    expect(segs[1].bold).toBe(true);
  });

  it("bold segment text matches query (case-preserved from label)", () => {
    const segs = segmentLabel("Toggle Theme", "theme");
    const boldSeg = segs.find((s) => s.bold);
    expect(boldSeg?.text).toBe("Theme");
  });
});

// ── Tests: recency LRU ────────────────────────────────────────────────────────

describe("pushRecent() — LRU list", () => {
  let recent: string[];

  beforeEach(() => {
    recent = [];
  });

  it("adds a new id to front", () => {
    recent = pushRecent(recent, "go-home");
    expect(recent[0]).toBe("go-home");
    expect(recent.length).toBe(1);
  });

  it("moves existing id to front (LRU)", () => {
    recent = pushRecent(recent, "go-home");
    recent = pushRecent(recent, "settings");
    recent = pushRecent(recent, "go-home"); // promote
    expect(recent[0]).toBe("go-home");
    expect(recent[1]).toBe("settings");
    expect(recent.length).toBe(2);
  });

  it("caps list at 8 entries", () => {
    for (let i = 0; i < 12; i++) {
      recent = pushRecent(recent, `cmd-${i}`);
    }
    expect(recent.length).toBe(RECENT_MAX);
  });

  it("newest item is always at index 0", () => {
    for (let i = 0; i < 5; i++) {
      recent = pushRecent(recent, `cmd-${i}`);
    }
    expect(recent[0]).toBe("cmd-4");
  });

  it("evicts oldest entry (index 7 becomes 0 after 8 inserts then one more)", () => {
    for (let i = 0; i < 8; i++) {
      recent = pushRecent(recent, `cmd-${i}`);
    }
    // oldest is cmd-0 at index 7
    recent = pushRecent(recent, "cmd-new");
    expect(recent[0]).toBe("cmd-new");
    expect(recent).not.toContain("cmd-0");
    expect(recent.length).toBe(RECENT_MAX);
  });

  it("de-duplicates: same id appears only once", () => {
    recent = pushRecent(recent, "a");
    recent = pushRecent(recent, "b");
    recent = pushRecent(recent, "a");
    const count = recent.filter((x) => x === "a").length;
    expect(count).toBe(1);
  });
});

// ── Tests: empty search returns all commands ──────────────────────────────────

describe("fuzzyScore() — empty search shows all", () => {
  const sampleCommands = [
    makeCmd("go-home", "Go to Home", "Navigate"),
    makeCmd("new-session", "New Session", "Actions"),
    makeCmd("settings", "Open Settings", "Actions"),
    makeCmd("toggle-theme", "Toggle Dark / Light", "Actions"),
  ];

  it("all commands have score ≥ 1 when query is empty", () => {
    for (const cmd of sampleCommands) {
      expect(fuzzyScore(cmd, "")).toBeGreaterThanOrEqual(1);
    }
  });

  it("no commands are filtered out with empty query", () => {
    const visible = sampleCommands.filter((c) => fuzzyScore(c, "") > 0);
    expect(visible.length).toBe(sampleCommands.length);
  });
});
