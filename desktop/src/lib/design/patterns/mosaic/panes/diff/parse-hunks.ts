/**
 * parse-hunks.ts — small helpers for the diff pane that operate on the
 * already-parsed `DiffHunk` shape from parse-diff.ts.
 *
 * Not a parser — the actual unified-diff parser lives in
 * `$lib/utils/parse-diff.ts` and is REUSED. This file owns one job:
 * rebuild the hunk's body text (with +/-/space prefixes) so the backend
 * can reverse-apply it via `git apply --reverse`.
 */

import type { DiffHunk, DiffLine } from "$lib/domain/diff/types.js";

/** Returns true if this DiffLine should appear in the rebuilt hunk body. */
function isBodyLine(line: DiffLine): boolean {
  return line.type !== "hunk_header";
}

/** Single-character prefix used in unified-diff hunk bodies. */
function prefixFor(line: DiffLine): string {
  if (line.type === "add") return "+";
  if (line.type === "del") return "-";
  return " ";
}

/**
 * Rebuilds the hunk body — every body line prefixed with +, -, or space —
 * separated by newlines. Does NOT include the @@ header line.
 *
 * The resulting string + the hunk's `header` form a minimal patch suitable
 * for `git apply --unidiff-zero --reverse`.
 */
export function buildHunkContent(hunk: DiffHunk): string {
  return hunk.lines
    .filter(isBodyLine)
    .map((l) => `${prefixFor(l)}${l.content}`)
    .join("\n");
}

/**
 * Counts the number of changed (+/-) lines in a hunk. Used by the Hunk
 * action toolbar for the "N changes" label.
 */
export function changedLineCount(hunk: DiffHunk): number {
  return hunk.lines.filter((l) => l.type === "add" || l.type === "del").length;
}
