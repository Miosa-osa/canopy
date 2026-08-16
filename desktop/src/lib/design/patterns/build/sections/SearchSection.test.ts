/**
 * SearchSection tests — covers the pure logic backing the regex/case toggles
 * and the search query factory contract.
 *
 * Test environment: Node (no DOM, no Svelte renderer) — same precedent as
 * FileTree.test.ts and keyboard.test.ts.
 */

import { describe, expect, it } from "vitest";
import {
  type BackendStatus,
  groupByFile,
  searchQuery,
  type SearchHit,
} from "$lib/api/queries/search.js";

// ── Fixtures ──────────────────────────────────────────────────────────────────

function hit(
  filePath: string,
  lineNumber: number,
  lineText: string,
  matchStart = 0,
  matchEnd = lineText.length,
): SearchHit {
  return { filePath, lineNumber, lineText, matchStart, matchEnd };
}

// ── groupByFile ──────────────────────────────────────────────────────────────

describe("groupByFile()", () => {
  it("returns an empty array for no hits", () => {
    expect(groupByFile([])).toEqual([]);
  });

  it("groups hits from the same file into one bucket", () => {
    const hits = [
      hit("a.ts", 1, "foo"),
      hit("a.ts", 5, "bar"),
      hit("a.ts", 9, "baz"),
    ];
    const groups = groupByFile(hits);
    expect(groups).toHaveLength(1);
    expect(groups[0].filePath).toBe("a.ts");
    expect(groups[0].hits).toHaveLength(3);
  });

  it("preserves insertion order across files", () => {
    const hits = [
      hit("b.ts", 1, "x"),
      hit("a.ts", 1, "y"),
      hit("b.ts", 2, "z"),
    ];
    const groups = groupByFile(hits);
    expect(groups.map((g) => g.filePath)).toEqual(["b.ts", "a.ts"]);
    expect(groups[0].hits).toHaveLength(2);
    expect(groups[1].hits).toHaveLength(1);
  });

  it("handles a single hit", () => {
    const groups = groupByFile([hit("only.md", 42, "needle")]);
    expect(groups).toHaveLength(1);
    expect(groups[0].hits[0].lineNumber).toBe(42);
  });
});

// ── searchQuery factory ───────────────────────────────────────────────────────

describe("searchQuery() factory", () => {
  it("builds a stable queryKey including all filter fields", () => {
    const q = searchQuery({
      workspaceSlug: "dev-shop",
      q: "needle",
      regex: true,
      caseSensitive: true,
      limit: 50,
    });
    expect(q.queryKey).toEqual([
      "build-rail",
      "search",
      "dev-shop",
      "needle",
      true,
      true,
      50,
    ]);
  });

  it("defaults regex/caseSensitive/limit when omitted", () => {
    const q = searchQuery({ workspaceSlug: "ws", q: "x" });
    expect(q.queryKey).toEqual([
      "build-rail",
      "search",
      "ws",
      "x",
      false,
      false,
      100,
    ]);
  });

  it("is disabled when q is empty", () => {
    const q = searchQuery({ workspaceSlug: "ws", q: "" });
    expect(q.enabled).toBe(false);
  });

  it("is disabled when q is only whitespace", () => {
    const q = searchQuery({ workspaceSlug: "ws", q: "   " });
    expect(q.enabled).toBe(false);
  });

  it("is disabled when workspaceSlug is empty", () => {
    const q = searchQuery({ workspaceSlug: "", q: "needle" });
    expect(q.enabled).toBe(false);
  });

  it("is enabled with non-empty workspaceSlug + q", () => {
    const q = searchQuery({ workspaceSlug: "ws", q: "needle" });
    expect(q.enabled).toBe(true);
  });

  it("staleTime is 5_000 (short — search results turn stale fast)", () => {
    const q = searchQuery({ workspaceSlug: "ws", q: "x" });
    expect(q.staleTime).toBe(5_000);
  });

  it("regex toggle changes the queryKey identity", () => {
    const a = searchQuery({ workspaceSlug: "ws", q: "x", regex: false });
    const b = searchQuery({ workspaceSlug: "ws", q: "x", regex: true });
    expect(a.queryKey).not.toEqual(b.queryKey);
  });

  it("caseSensitive toggle changes the queryKey identity", () => {
    const a = searchQuery({
      workspaceSlug: "ws",
      q: "x",
      caseSensitive: false,
    });
    const b = searchQuery({
      workspaceSlug: "ws",
      q: "x",
      caseSensitive: true,
    });
    expect(a.queryKey).not.toEqual(b.queryKey);
  });
});

// ── highlightLine pure logic (mirrors SearchSection.svelte) ───────────────────

describe("line highlight logic", () => {
  function highlight(h: SearchHit) {
    return {
      before: h.lineText.slice(0, h.matchStart),
      match: h.lineText.slice(h.matchStart, h.matchEnd),
      after: h.lineText.slice(h.matchEnd),
    };
  }

  it("splits the line into before/match/after", () => {
    const h = hit("a.ts", 1, "hello world", 6, 11);
    const parts = highlight(h);
    expect(parts.before).toBe("hello ");
    expect(parts.match).toBe("world");
    expect(parts.after).toBe("");
  });

  it("handles match at start of line", () => {
    const h = hit("a.ts", 1, "needle in haystack", 0, 6);
    const parts = highlight(h);
    expect(parts.before).toBe("");
    expect(parts.match).toBe("needle");
    expect(parts.after).toBe(" in haystack");
  });

  it("handles match at end of line", () => {
    const h = hit("a.ts", 1, "find the needle", 9, 15);
    const parts = highlight(h);
    expect(parts.before).toBe("find the ");
    expect(parts.match).toBe("needle");
    expect(parts.after).toBe("");
  });

  it("handles zero-width match (matchStart == matchEnd)", () => {
    const h = hit("a.ts", 1, "abc", 1, 1);
    const parts = highlight(h);
    expect(parts.before).toBe("a");
    expect(parts.match).toBe("");
    expect(parts.after).toBe("bc");
  });
});

// ── BackendStatus shape ───────────────────────────────────────────────────────

describe("BackendStatus shape", () => {
  it("represents an unavailable backend with available=false and empty hits", () => {
    const status: BackendStatus = { available: false, hits: [] };
    expect(status.available).toBe(false);
    expect(status.hits).toHaveLength(0);
  });

  it("represents a successful response with available=true and hits", () => {
    const status: BackendStatus = {
      available: true,
      hits: [hit("a.ts", 1, "x")],
    };
    expect(status.available).toBe(true);
    expect(status.hits).toHaveLength(1);
  });
});
