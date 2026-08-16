/**
 * Tests for parse-hunks.ts — the small DiffHunk → patch-body rebuilder used
 * by the Diff pane to send a discard-hunk request to the backend.
 *
 * The actual unified-diff parser is exercised in $lib/utils/parse-diff.test.ts
 * (Phase 5) — we don't re-test parsing here.
 */

import { describe, expect, it } from "vitest";
import type { DiffHunk } from "$lib/domain/diff/types.js";
import { buildHunkContent, changedLineCount } from "./parse-hunks.js";

function hunk(
  headerLine: string,
  body: Array<["add" | "del" | "context", string]>,
): DiffHunk {
  return {
    oldStart: 1,
    oldLines: 1,
    newStart: 1,
    newLines: 1,
    header: headerLine,
    lines: [
      {
        type: "hunk_header",
        content: headerLine,
        oldLineNo: null,
        newLineNo: null,
      },
      ...body.map(([type, content]) => ({
        type,
        content,
        oldLineNo: type === "add" ? null : 1,
        newLineNo: type === "del" ? null : 1,
      })),
    ],
  };
}

describe("buildHunkContent", () => {
  it("rebuilds context/add/del lines with the correct prefixes", () => {
    const h = hunk("@@ -1,2 +1,3 @@", [
      ["context", "line1"],
      ["context", "line2"],
      ["add", "line3"],
    ]);

    expect(buildHunkContent(h)).toBe(" line1\n line2\n+line3");
  });

  it("returns empty string when the hunk has no body lines", () => {
    const h = hunk("@@ -1 +1 @@", []);
    expect(buildHunkContent(h)).toBe("");
  });

  it("excludes the hunk_header line itself", () => {
    const h = hunk("@@ -1 +1 @@", [["add", "x"]]);
    const out = buildHunkContent(h);
    expect(out).not.toContain("@@");
    expect(out).toBe("+x");
  });

  it("preserves empty content lines (context blank line)", () => {
    const h = hunk("@@ -1,3 +1,3 @@", [
      ["context", "a"],
      ["context", ""],
      ["context", "b"],
    ]);
    expect(buildHunkContent(h)).toBe(" a\n \n b");
  });

  it("handles deletion-only hunks", () => {
    const h = hunk("@@ -1,2 +1,1 @@", [
      ["context", "keep"],
      ["del", "drop"],
    ]);
    expect(buildHunkContent(h)).toBe(" keep\n-drop");
  });
});

describe("changedLineCount", () => {
  it("counts only +/- lines", () => {
    const h = hunk("@@ -1,3 +1,4 @@", [
      ["context", "a"],
      ["add", "b"],
      ["del", "c"],
      ["add", "d"],
    ]);
    expect(changedLineCount(h)).toBe(3);
  });

  it("returns 0 when hunk only has context", () => {
    const h = hunk("@@ -1,1 +1,1 @@", [["context", "a"]]);
    expect(changedLineCount(h)).toBe(0);
  });

  it("does not count the hunk_header line", () => {
    const h = hunk("@@ -1,1 +1,1 @@", []);
    expect(changedLineCount(h)).toBe(0);
  });
});
