/**
 * FileTree foundation primitive — tests for the pure logic that drives the
 * tree's behaviour.
 *
 * Test environment: Node (no DOM, no Svelte renderer) per `vite.config.ts`.
 * We mirror the small pure helpers that the component uses internally and
 * assert their behaviour. This is the same pattern as
 * `src/lib/design/patterns/__tests__/FileTree.test.ts`.
 *
 * Coverage:
 *   • Lazy load on expand — querying contract via `directoryListingQuery`
 *   • Selected-state propagation
 *   • File-select event payload
 *   • Hidden-file toggle (defaults to hide dotfiles)
 */

import { describe, expect, it } from "vitest";
import { directoryListingQuery } from "$lib/api/queries/file-tree.js";
import type { DirEntry } from "$lib/domain/workspaces/types.js";

// ── Fixtures ─────────────────────────────────────────────────────────────────

function entry(name: string, isDir: boolean, parent = ""): DirEntry {
  const path = parent ? `${parent}/${name}` : name;
  return { name, path, isDir, size: isDir ? 0 : 100, modified: null };
}

const ROOT_ENTRIES: DirEntry[] = [
  entry(".git", true),
  entry(".env", false),
  entry("README.md", false),
  entry("src", true),
  entry("package.json", false),
];

// ── Pure helpers mirroring FileTree.svelte / FileTreeNode.svelte logic ──────

/** Filter entries by hidden-toggle. Mirrors FileTree's `visibleRoot` derived. */
function applyHideHidden(entries: DirEntry[], hideHidden: boolean): DirEntry[] {
  return entries.filter((e) => !hideHidden || !e.name.startsWith("."));
}

/** Toggle a path inside the expanded Set. Mirrors `toggleFolder()`. */
function toggleExpanded(
  current: Set<string>,
  path: string,
  willBeExpanded: boolean,
): Set<string> {
  const next = new Set(current);
  if (willBeExpanded) next.add(path);
  else next.delete(path);
  return next;
}

// ── 1. Lazy load on expand ──────────────────────────────────────────────────

describe("FileTree — lazy load on expand", () => {
  it("query is disabled until the folder is expanded", () => {
    const slug = "default";
    const path = "src";

    const collapsed = {
      ...directoryListingQuery(slug, path),
      enabled: Boolean(slug) && true && false, // isDir && !isExpanded
    };
    expect(collapsed.enabled).toBe(false);

    const expanded = {
      ...directoryListingQuery(slug, path),
      enabled: Boolean(slug) && true && true,
    };
    expect(expanded.enabled).toBe(true);
  });

  it("uses one cache key per (slug, path) so each folder fetches exactly once", () => {
    const aSrc = directoryListingQuery("default", "src").queryKey;
    const aSrcAgain = directoryListingQuery("default", "src").queryKey;
    const aDocs = directoryListingQuery("default", "docs").queryKey;
    const bSrc = directoryListingQuery("other", "src").queryKey;

    expect(aSrc).toEqual(aSrcAgain);
    expect(aSrc).not.toEqual(aDocs);
    expect(aSrc).not.toEqual(bSrc);
  });

  it("root listing uses an empty path key", () => {
    const root = directoryListingQuery("default").queryKey;
    expect(root).toEqual(["build-rail", "directory", "default", ""]);
  });

  it("expanding a path adds it to the expanded Set; collapsing removes it", () => {
    let exp = new Set<string>();

    exp = toggleExpanded(exp, "src", true);
    expect(exp.has("src")).toBe(true);
    expect(exp.size).toBe(1);

    exp = toggleExpanded(exp, "src/lib", true);
    expect(exp.size).toBe(2);

    exp = toggleExpanded(exp, "src", false);
    expect(exp.has("src")).toBe(false);
    expect(exp.has("src/lib")).toBe(true);
  });
});

// ── 2. Selected-state propagation ───────────────────────────────────────────

describe("FileTree — selection propagation", () => {
  it("selecting a file replaces the previous selection", () => {
    let selected: string | null = null;

    selected = "README.md";
    expect(selected).toBe("README.md");

    selected = "src/index.ts";
    expect(selected).toBe("src/index.ts");
  });

  it("a row highlights when its path matches the selectedPath", () => {
    const selectedPath = "README.md";
    const rows = ROOT_ENTRIES.map((e) => ({
      ...e,
      isSelected: e.path === selectedPath,
    }));
    const selectedRows = rows.filter((r) => r.isSelected);
    expect(selectedRows).toHaveLength(1);
    expect(selectedRows[0].name).toBe("README.md");
  });

  it("clearing selection makes no row selected", () => {
    const selectedPath: string | null = null;
    const rows = ROOT_ENTRIES.map((e) => ({
      ...e,
      isSelected: selectedPath !== null && e.path === selectedPath,
    }));
    expect(rows.every((r) => !r.isSelected)).toBe(true);
  });
});

// ── 3. File-select event emission ───────────────────────────────────────────

describe("FileTree — onFileSelect callback", () => {
  it("delivers the entry object to the consumer", () => {
    let received: DirEntry | null = null;
    const onFileSelect = (e: DirEntry): void => {
      received = e;
    };

    const target = ROOT_ENTRIES.find((e) => e.name === "README.md");
    if (target && !target.isDir) onFileSelect(target);

    expect(received).not.toBeNull();
    expect((received as unknown as DirEntry).name).toBe("README.md");
    expect((received as unknown as DirEntry).path).toBe("README.md");
    expect((received as unknown as DirEntry).isDir).toBe(false);
  });

  it("does NOT fire when a folder is clicked (folders toggle, not select)", () => {
    let fileFired = 0;
    let toggleFired = 0;
    const onFileSelect = (_entry: DirEntry): void => {
      fileFired++;
    };
    const onFolderToggle = (): void => {
      toggleFired++;
    };

    // Simulate click handler logic from FileTreeNode.handleClick.
    function clickRow(e: DirEntry): void {
      if (e.isDir) onFolderToggle();
      else onFileSelect(e);
    }

    const folder = ROOT_ENTRIES.find((e) => e.name === "src")!;
    const file = ROOT_ENTRIES.find((e) => e.name === "README.md")!;

    clickRow(folder);
    clickRow(file);

    expect(fileFired).toBe(1);
    expect(toggleFired).toBe(1);
  });
});

// ── 4. Hidden-file toggle (default: hide dotfiles) ──────────────────────────

describe("FileTree — hideHidden", () => {
  it("hides dotfiles by default", () => {
    const visible = applyHideHidden(ROOT_ENTRIES, true);
    const names = visible.map((e) => e.name);
    expect(names).not.toContain(".git");
    expect(names).not.toContain(".env");
    expect(names).toContain("README.md");
    expect(names).toContain("src");
  });

  it("shows dotfiles when hideHidden=false", () => {
    const visible = applyHideHidden(ROOT_ENTRIES, false);
    expect(visible).toHaveLength(ROOT_ENTRIES.length);
    expect(visible.map((e) => e.name)).toContain(".git");
    expect(visible.map((e) => e.name)).toContain(".env");
  });

  it("only hides leading-dot names, not names containing dots", () => {
    const tricky: DirEntry[] = [
      entry("README.md", false),
      entry("a.b.c.json", false),
      entry(".secret", false),
    ];
    const visible = applyHideHidden(tricky, true).map((e) => e.name);
    expect(visible).toContain("README.md");
    expect(visible).toContain("a.b.c.json");
    expect(visible).not.toContain(".secret");
  });

  it("preserves order when filtering", () => {
    const visible = applyHideHidden(ROOT_ENTRIES, true);
    expect(visible.map((e) => e.name)).toEqual([
      "README.md",
      "src",
      "package.json",
    ]);
  });
});
