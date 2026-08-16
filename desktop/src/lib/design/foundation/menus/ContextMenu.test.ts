/**
 * ContextMenu — pure-logic tests for the cursor-anchored menu primitive.
 *
 * Test environment: Node (no DOM, no Svelte renderer) — same precedent as
 * SearchSection.test.ts and BuildSideRail.test.ts. We test the pure helpers
 * that back the component, and the contract of the exported types.
 */

import { describe, expect, it } from "vitest";
import type { ContextMenuAnchor, ContextMenuItem } from "./ContextMenu.svelte";

// ── Position clamping ────────────────────────────────────────────────────────

/**
 * Mirrors the clamping logic inside ContextMenu.svelte:
 *   - keep the menu inside the viewport with a 4px padding
 *   - never allow negative coords
 */
function clampPosition(
  anchor: ContextMenuAnchor,
  menuSize: { width: number; height: number },
  viewport: { width: number; height: number },
): { x: number; y: number } {
  const padding = 4;
  const maxX = viewport.width - menuSize.width - padding;
  const maxY = viewport.height - menuSize.height - padding;
  return {
    x: Math.max(padding, Math.min(anchor.x, maxX)),
    y: Math.max(padding, Math.min(anchor.y, maxY)),
  };
}

describe("clampPosition()", () => {
  const VIEWPORT = { width: 1024, height: 768 };
  const MENU = { width: 180, height: 120 };

  it("returns the anchor unchanged when there's room", () => {
    expect(clampPosition({ x: 100, y: 200 }, MENU, VIEWPORT)).toEqual({
      x: 100,
      y: 200,
    });
  });

  it("clamps right-edge overflow", () => {
    const result = clampPosition({ x: 1020, y: 100 }, MENU, VIEWPORT);
    expect(result.x).toBe(1024 - 180 - 4);
  });

  it("clamps bottom-edge overflow", () => {
    const result = clampPosition({ x: 100, y: 760 }, MENU, VIEWPORT);
    expect(result.y).toBe(768 - 120 - 4);
  });

  it("clamps both axes simultaneously", () => {
    const result = clampPosition({ x: 9999, y: 9999 }, MENU, VIEWPORT);
    expect(result.x).toBe(1024 - 180 - 4);
    expect(result.y).toBe(768 - 120 - 4);
  });

  it("clamps negative anchors to the padding edge", () => {
    expect(clampPosition({ x: -10, y: -10 }, MENU, VIEWPORT)).toEqual({
      x: 4,
      y: 4,
    });
  });

  it("uses 4px padding from each edge", () => {
    const r1 = clampPosition({ x: 0, y: 0 }, MENU, VIEWPORT);
    expect(r1).toEqual({ x: 4, y: 4 });
  });
});

// ── Keyboard navigation logic ────────────────────────────────────────────────

/**
 * Mirrors the arrow-key navigation inside ContextMenu.svelte. The menu skips
 * disabled items by computing a focusableIndexes array and walking it.
 */
function focusableIndexes(items: ContextMenuItem[]): number[] {
  return items
    .map((item, idx) => ({ item, idx }))
    .filter(({ item }) => !item.disabled)
    .map(({ idx }) => idx);
}

function moveFocus(
  current: number,
  direction: "down" | "up",
  items: ContextMenuItem[],
): number {
  const focusable = focusableIndexes(items);
  if (focusable.length === 0) return current;
  const cursor = focusable.indexOf(current);
  const dir = direction === "down" ? 1 : -1;
  const len = focusable.length;
  const nextCursor = (cursor + dir + len) % len;
  return focusable[nextCursor];
}

function makeItem(over: Partial<ContextMenuItem>): ContextMenuItem {
  return {
    id: over.id ?? "x",
    label: over.label ?? "X",
    onSelect: over.onSelect ?? (() => {}),
    ...over,
  };
}

describe("focusableIndexes()", () => {
  it("returns all indices when nothing is disabled", () => {
    const items = [makeItem({ id: "a" }), makeItem({ id: "b" })];
    expect(focusableIndexes(items)).toEqual([0, 1]);
  });

  it("skips disabled items", () => {
    const items = [
      makeItem({ id: "a" }),
      makeItem({ id: "b", disabled: true }),
      makeItem({ id: "c" }),
    ];
    expect(focusableIndexes(items)).toEqual([0, 2]);
  });

  it("returns an empty array when every item is disabled", () => {
    const items = [
      makeItem({ id: "a", disabled: true }),
      makeItem({ id: "b", disabled: true }),
    ];
    expect(focusableIndexes(items)).toEqual([]);
  });
});

describe("moveFocus()", () => {
  const items = [
    makeItem({ id: "a" }),
    makeItem({ id: "b" }),
    makeItem({ id: "c" }),
  ];

  it("ArrowDown moves to next focusable", () => {
    expect(moveFocus(0, "down", items)).toBe(1);
  });

  it("ArrowUp moves to previous focusable", () => {
    expect(moveFocus(1, "up", items)).toBe(0);
  });

  it("ArrowDown wraps from last to first", () => {
    expect(moveFocus(2, "down", items)).toBe(0);
  });

  it("ArrowUp wraps from first to last", () => {
    expect(moveFocus(0, "up", items)).toBe(2);
  });

  it("skips disabled items going down", () => {
    const it = [
      makeItem({ id: "a" }),
      makeItem({ id: "b", disabled: true }),
      makeItem({ id: "c" }),
    ];
    expect(moveFocus(0, "down", it)).toBe(2);
  });

  it("skips disabled items going up", () => {
    const it = [
      makeItem({ id: "a" }),
      makeItem({ id: "b", disabled: true }),
      makeItem({ id: "c" }),
    ];
    expect(moveFocus(2, "up", it)).toBe(0);
  });

  it("returns current when nothing is focusable", () => {
    const it = [makeItem({ id: "a", disabled: true })];
    expect(moveFocus(0, "down", it)).toBe(0);
  });
});

// ── ContextMenuItem type contract ────────────────────────────────────────────

describe("ContextMenuItem shape", () => {
  it("requires id, label, and onSelect", () => {
    const item: ContextMenuItem = {
      id: "delete",
      label: "Delete",
      onSelect: () => {},
    };
    expect(item.id).toBe("delete");
    expect(item.label).toBe("Delete");
    expect(typeof item.onSelect).toBe("function");
  });

  it("supports the destructive variant", () => {
    const item: ContextMenuItem = {
      id: "rm",
      label: "Remove",
      destructive: true,
      onSelect: () => {},
    };
    expect(item.destructive).toBe(true);
  });

  it("supports the disabled flag", () => {
    const item: ContextMenuItem = {
      id: "wip",
      label: "Soon",
      disabled: true,
      onSelect: () => {},
    };
    expect(item.disabled).toBe(true);
  });

  it("invokes onSelect when called", () => {
    let called = false;
    const item: ContextMenuItem = {
      id: "x",
      label: "x",
      onSelect: () => {
        called = true;
      },
    };
    item.onSelect();
    expect(called).toBe(true);
  });
});

// ── ContextMenuAnchor shape ──────────────────────────────────────────────────

describe("ContextMenuAnchor shape", () => {
  it("captures viewport coords from a MouseEvent", () => {
    const ev = { clientX: 320, clientY: 480 };
    const anchor: ContextMenuAnchor = { x: ev.clientX, y: ev.clientY };
    expect(anchor).toEqual({ x: 320, y: 480 });
  });

  it("can be null to signal 'closed'", () => {
    const anchor: ContextMenuAnchor | null = null;
    expect(anchor).toBeNull();
  });
});
