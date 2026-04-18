/**
 * FileTree tests — smoke + keyboard navigation logic.
 *
 * The test environment is Node (no DOM, no Svelte renderer) per vite.config.ts.
 * We test the pure functions that drive visible-node collection and keyboard
 * state transitions, extracted and replicated here from FileTree.svelte logic.
 *
 * This is the correct pattern for this project — see keyboard.test.ts and
 * agents.test.ts for precedent.
 */

import { describe, expect, it } from "vitest";
import type { FileTreeNode } from "$lib/domain/workspaces/types.js";

// ── Pure functions mirroring FileTree.svelte logic ───────────────────────────

/** Collect all visible nodes given the current expanded set. */
function collectVisible(
  node: FileTreeNode,
  expandedPaths: Set<string>,
): FileTreeNode[] {
  const result: FileTreeNode[] = [node];
  if (node.isDir && expandedPaths.has(node.path)) {
    for (const child of node.children) {
      result.push(...collectVisible(child, expandedPaths));
    }
  }
  return result;
}

function visibleNodes(
  root: FileTreeNode,
  expandedPaths: Set<string>,
): FileTreeNode[] {
  return root.children.flatMap((child) => collectVisible(child, expandedPaths));
}

/** Toggle a dir's expanded state. Returns new Set. */
function toggleDir(path: string, expandedPaths: Set<string>): Set<string> {
  const next = new Set(expandedPaths);
  if (next.has(path)) {
    next.delete(path);
  } else {
    next.add(path);
  }
  return next;
}

/** Resolve next focused index after ↑ / ↓. Wraps. */
function moveFocus(
  direction: "up" | "down",
  currentPath: string | undefined,
  nodes: FileTreeNode[],
): string | undefined {
  if (nodes.length === 0) return undefined;
  const currentIdx =
    currentPath != null ? nodes.findIndex((n) => n.path === currentPath) : -1;

  if (direction === "down") {
    const nextIdx = currentIdx < nodes.length - 1 ? currentIdx + 1 : 0;
    return nodes[nextIdx]?.path;
  } else {
    const prevIdx = currentIdx > 0 ? currentIdx - 1 : nodes.length - 1;
    return nodes[prevIdx]?.path;
  }
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

function makeNode(
  name: string,
  path: string,
  isDir: boolean,
  children: FileTreeNode[] = [],
): FileTreeNode {
  return {
    name,
    path,
    isDir,
    size: isDir ? 0 : 1024,
    modified: null,
    children,
  };
}

const TREE: FileTreeNode = makeNode("root", "", true, [
  makeNode("agents", "agents", true, [
    makeNode("sales.md", "agents/sales.md", false),
    makeNode("research.md", "agents/research.md", false),
  ]),
  makeNode("notes", "notes", true, [makeNode("Q2.md", "notes/Q2.md", false)]),
  makeNode("SYSTEM.md", "SYSTEM.md", false),
]);

// ── Tests — visible node collection ──────────────────────────────────────────

describe("visibleNodes()", () => {
  it("shows only top-level nodes when nothing is expanded", () => {
    const nodes = visibleNodes(TREE, new Set());
    expect(nodes.map((n) => n.path)).toEqual(["agents", "notes", "SYSTEM.md"]);
  });

  it("shows children of expanded dirs", () => {
    const nodes = visibleNodes(TREE, new Set(["agents"]));
    expect(nodes.map((n) => n.path)).toEqual([
      "agents",
      "agents/sales.md",
      "agents/research.md",
      "notes",
      "SYSTEM.md",
    ]);
  });

  it("shows deeply nested nodes when multiple dirs expanded", () => {
    const nodes = visibleNodes(TREE, new Set(["agents", "notes"]));
    expect(nodes.map((n) => n.path)).toEqual([
      "agents",
      "agents/sales.md",
      "agents/research.md",
      "notes",
      "notes/Q2.md",
      "SYSTEM.md",
    ]);
  });

  it("returns empty array when root has no children", () => {
    const emptyRoot = makeNode("root", "", true, []);
    const nodes = visibleNodes(emptyRoot, new Set());
    expect(nodes).toHaveLength(0);
  });
});

// ── Tests — toggleDir ─────────────────────────────────────────────────────────

describe("toggleDir()", () => {
  it("adds a path when not expanded", () => {
    const next = toggleDir("agents", new Set());
    expect(next.has("agents")).toBe(true);
  });

  it("removes a path when already expanded", () => {
    const next = toggleDir("agents", new Set(["agents"]));
    expect(next.has("agents")).toBe(false);
  });

  it("does not mutate the original set", () => {
    const original = new Set(["agents"]);
    toggleDir("agents", original);
    expect(original.has("agents")).toBe(true);
  });
});

// ── Tests — keyboard navigation ───────────────────────────────────────────────

describe("moveFocus()", () => {
  const nodes = visibleNodes(TREE, new Set());
  // nodes = ['agents', 'notes', 'SYSTEM.md']

  it("moves down from first node", () => {
    const next = moveFocus("down", "agents", nodes);
    expect(next).toBe("notes");
  });

  it("moves down from last node — wraps to first", () => {
    const next = moveFocus("down", "SYSTEM.md", nodes);
    expect(next).toBe("agents");
  });

  it("moves up from last node", () => {
    const next = moveFocus("up", "SYSTEM.md", nodes);
    expect(next).toBe("notes");
  });

  it("moves up from first node — wraps to last", () => {
    const next = moveFocus("up", "agents", nodes);
    expect(next).toBe("SYSTEM.md");
  });

  it("starts at first node when currentPath is undefined", () => {
    const next = moveFocus("down", undefined, nodes);
    expect(next).toBe("agents");
  });

  it("returns undefined when node list is empty", () => {
    const next = moveFocus("down", undefined, []);
    expect(next).toBeUndefined();
  });
});

// ── Tests — keyboard: right/left expand/collapse ──────────────────────────────

describe("keyboard expand/collapse logic", () => {
  it("→ expands a collapsed dir", () => {
    const nodes = visibleNodes(TREE, new Set());
    const agentNode = nodes.find((n) => n.path === "agents")!;
    expect(agentNode.isDir).toBe(true);

    let expandedPaths = new Set<string>();
    if (agentNode.isDir && !expandedPaths.has(agentNode.path)) {
      expandedPaths = toggleDir(agentNode.path, expandedPaths);
    }
    expect(expandedPaths.has("agents")).toBe(true);
  });

  it("← collapses an expanded dir", () => {
    const nodes = visibleNodes(TREE, new Set(["agents"]));
    const agentNode = nodes.find((n) => n.path === "agents")!;

    let expandedPaths = new Set<string>(["agents"]);
    if (agentNode.isDir && expandedPaths.has(agentNode.path)) {
      expandedPaths = toggleDir(agentNode.path, expandedPaths);
    }
    expect(expandedPaths.has("agents")).toBe(false);
  });

  it("→ on a file does nothing to expandedPaths", () => {
    const nodes = visibleNodes(TREE, new Set());
    const fileNode = nodes.find((n) => n.path === "SYSTEM.md")!;
    expect(fileNode.isDir).toBe(false);

    let expandedPaths = new Set<string>();
    if (fileNode.isDir && !expandedPaths.has(fileNode.path)) {
      expandedPaths = toggleDir(fileNode.path, expandedPaths);
    }
    expect(expandedPaths.size).toBe(0);
  });
});

// ── Tests — workspaceTreeQuery factory (smoke) ────────────────────────────────

describe("workspaceTreeQuery()", () => {
  it("returns correct query key shape", async () => {
    const { workspaceTreeQuery } =
      await import("$lib/api/queries/workspaces.js");
    const q = workspaceTreeQuery("sales-engine");
    expect(q.queryKey).toEqual(["workspaces", "sales-engine", "tree"]);
  });

  it("is disabled when slug is empty", async () => {
    const { workspaceTreeQuery } =
      await import("$lib/api/queries/workspaces.js");
    const q = workspaceTreeQuery("");
    expect(q.enabled).toBe(false);
  });

  it("is enabled when slug is non-empty", async () => {
    const { workspaceTreeQuery } =
      await import("$lib/api/queries/workspaces.js");
    const q = workspaceTreeQuery("dev-shop");
    expect(q.enabled).toBe(true);
  });

  it("has staleTime of 10_000", async () => {
    const { workspaceTreeQuery } =
      await import("$lib/api/queries/workspaces.js");
    const q = workspaceTreeQuery("dev-shop");
    expect(q.staleTime).toBe(10_000);
  });
});
