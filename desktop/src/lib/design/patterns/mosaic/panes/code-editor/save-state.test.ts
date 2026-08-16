/**
 * save-state — pure-logic unit tests.
 *
 * Follows the convention from src/lib/stores/toasts.test.ts: the class itself
 * uses Svelte 5 $state runes (which need the compiler context), so we test
 * the pure helpers exposed alongside it. They're the contract that drives the
 * rune-derived `isDirty` flag, so verifying them here is equivalent to
 * verifying the dirty-tracking behaviour.
 */
import { describe, expect, it } from "vitest";
import {
  computeDirty,
  dirtyTitleMarker,
  normalizeNewlines,
} from "./save-state.svelte.js";

// ── normalizeNewlines ────────────────────────────────────────────────────────

describe("normalizeNewlines()", () => {
  it("returns an LF-only string unchanged", () => {
    expect(normalizeNewlines("a\nb\nc")).toBe("a\nb\nc");
  });

  it("collapses CRLF to LF", () => {
    expect(normalizeNewlines("a\r\nb\r\nc")).toBe("a\nb\nc");
  });

  it("collapses lone CR to LF", () => {
    expect(normalizeNewlines("a\rb\rc")).toBe("a\nb\nc");
  });

  it("handles a mixed-line-ending paste from Windows + Mac OS 9", () => {
    expect(normalizeNewlines("a\r\nb\rc\nd")).toBe("a\nb\nc\nd");
  });

  it("returns empty string unchanged", () => {
    expect(normalizeNewlines("")).toBe("");
  });
});

// ── computeDirty ─────────────────────────────────────────────────────────────

describe("computeDirty()", () => {
  it("returns false when baseline and draft are identical", () => {
    expect(computeDirty("hello", "hello")).toBe(false);
  });

  it("returns false for two empty strings", () => {
    expect(computeDirty("", "")).toBe(false);
  });

  it("returns true when draft has new content", () => {
    expect(computeDirty("hello", "hello world")).toBe(true);
  });

  it("returns true when draft truncates content", () => {
    expect(computeDirty("hello world", "hello")).toBe(true);
  });

  it("returns false when draft only differs in line endings", () => {
    // CRLF baseline (server-saved) vs LF draft (textarea-typed) is NOT dirty.
    expect(computeDirty("a\r\nb", "a\nb")).toBe(false);
  });

  it("returns true when content differs after newline normalization", () => {
    expect(computeDirty("a\r\nb", "a\nB")).toBe(true);
  });

  it("is case-sensitive", () => {
    expect(computeDirty("Hello", "hello")).toBe(true);
  });

  it("treats a single whitespace difference as dirty", () => {
    expect(computeDirty("foo", "foo ")).toBe(true);
  });
});

// ── dirtyTitleMarker ─────────────────────────────────────────────────────────

describe("dirtyTitleMarker()", () => {
  it("returns '• ' (bullet + space) when dirty", () => {
    expect(dirtyTitleMarker(true)).toBe("• ");
  });

  it("returns '' (empty) when clean", () => {
    expect(dirtyTitleMarker(false)).toBe("");
  });

  it("formats consistently for direct title concatenation", () => {
    const title = "main.ts";
    expect(`${dirtyTitleMarker(true)}${title}`).toBe("• main.ts");
    expect(`${dirtyTitleMarker(false)}${title}`).toBe("main.ts");
  });
});

// ── Lifecycle invariants (pure simulation, no rune compiler needed) ─────────

describe("dirty-tracking lifecycle (pure simulation)", () => {
  it("becomes clean after a successful save baseline update", () => {
    let baseline = "v1";
    let draft = "v2"; // user typed
    expect(computeDirty(baseline, draft)).toBe(true);

    // Simulate markSaved(): new baseline = whatever was just persisted.
    baseline = draft;
    expect(computeDirty(baseline, draft)).toBe(false);
  });

  it("stays dirty when the user keeps typing during an in-flight save", () => {
    let baseline = "v1";
    let draft = "v2";
    // Save round-trip starts with draft = "v2".
    const inFlight = draft;

    // User types more before the save resolves.
    draft = "v2 + more";

    // Save resolves — baseline becomes v2 (what we sent), but draft is now v2 + more.
    baseline = inFlight;
    expect(computeDirty(baseline, draft)).toBe(true);
  });

  it("revertToBaseline drops the draft back to the saved version", () => {
    let baseline = "v1";
    let draft = "v2";
    // Simulate revertToBaseline().
    draft = baseline;
    expect(computeDirty(baseline, draft)).toBe(false);
  });

  it("loadFromRemote resets both baseline and draft to a clean state", () => {
    let baseline = "stale";
    let draft = "stale + edits";
    expect(computeDirty(baseline, draft)).toBe(true);

    // Simulate loadFromRemote(): both reset to the same fresh value.
    const fresh = "freshly fetched content";
    baseline = fresh;
    draft = fresh;
    expect(computeDirty(baseline, draft)).toBe(false);
  });
});
