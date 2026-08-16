/**
 * DrivePickerPopover tests — pure helper coverage for `filterDriveEntries`.
 *
 * Test environment: Node — same precedent as `BuildSideRail.test.ts`.
 * The component itself is a thin wrapper around `driveListQuery` + this
 * helper, with the same outside-click / Esc / focus pattern as
 * `CwdPickerPopover.svelte`. Logic-level coverage of the filter is enough
 * for confidence the picker shows the right rows.
 */

import { describe, expect, it } from "vitest";
import { filterDriveEntries } from "./DrivePickerPopover.svelte";
import type { DriveEntry } from "$lib/domain/drive/types.js";

// ── Fixtures ──────────────────────────────────────────────────────────────────

function entry(
  kind: DriveEntry["kind"],
  slug: string,
  name = slug,
): DriveEntry {
  return {
    id: `id-${slug}`,
    slug,
    name,
    kind,
    scope: "personal",
    parentId: null,
    body: {},
    ownerId: null,
    tags: [],
    position: 0,
    archivedAt: null,
    insertedAt: "2026-01-01T00:00:00Z",
    updatedAt: "2026-01-01T00:00:00Z",
  };
}

const SAMPLE: DriveEntry[] = [
  entry("workflow", "squash-commits", "Squash Commits"),
  entry("prompt", "code-review", "Code Review"),
  entry("notebook", "weekly-standup", "Weekly Standup"),
  entry("mcp_server", "mcp-fetch", "MCP Fetch"),
  entry("folder", "drafts", "Drafts"),
  entry("env_vars", "stripe-keys", "Stripe Keys"),
  entry("rule", "no-secrets", "No Secrets Rule"),
];

// ── filterDriveEntries ───────────────────────────────────────────────────────

describe("filterDriveEntries()", () => {
  it("returns only commandable kinds when query is empty", () => {
    const result = filterDriveEntries(SAMPLE, "");
    const kinds = result.map((e) => e.kind).sort();
    expect(kinds).toEqual(["mcp_server", "notebook", "prompt", "workflow"]);
  });

  it("excludes folder, env_vars, and rule kinds", () => {
    const result = filterDriveEntries(SAMPLE, "");
    expect(result.find((e) => e.kind === "folder")).toBeUndefined();
    expect(result.find((e) => e.kind === "env_vars")).toBeUndefined();
    expect(result.find((e) => e.kind === "rule")).toBeUndefined();
  });

  it("matches by name (case-insensitive)", () => {
    const result = filterDriveEntries(SAMPLE, "SQUASH");
    expect(result).toHaveLength(1);
    expect(result[0].slug).toBe("squash-commits");
  });

  it("matches by slug (case-insensitive)", () => {
    const result = filterDriveEntries(SAMPLE, "weekly-stand");
    expect(result).toHaveLength(1);
    expect(result[0].slug).toBe("weekly-standup");
  });

  it("returns empty when nothing matches", () => {
    expect(filterDriveEntries(SAMPLE, "nonexistent-zzz")).toEqual([]);
  });

  it("ignores leading/trailing whitespace in query", () => {
    const result = filterDriveEntries(SAMPLE, "  squash  ");
    expect(result).toHaveLength(1);
  });

  it("returns empty for empty input", () => {
    expect(filterDriveEntries([], "anything")).toEqual([]);
    expect(filterDriveEntries([], "")).toEqual([]);
  });
});
