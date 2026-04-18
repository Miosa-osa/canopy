/**
 * useListKeyboard — unit tests.
 *
 * The composable is a pure Svelte 5 runes function. In Vitest (Node env) we
 * cannot use $state directly, but we CAN test the keyboard dispatch logic by
 * calling the returned handleKeydown with synthetic events and inspecting the
 * exposed selectedIndex getter.
 *
 * Strategy: call useListKeyboard() with a fixed items array + mock callbacks,
 * then fire synthetic KeyboardEvent objects (Node-safe plain objects) to verify
 * index advances, clamping, onSelect, onRefresh, onHelp, and Esc clearing.
 */

import { describe, expect, it, vi, beforeEach } from "vitest";

// We import the function directly — it uses $state internally but the vitest
// svelte plugin transforms rune syntax at test time.
import { useListKeyboard } from "../useListKeyboard.svelte.js";

// ── Helpers ───────────────────────────────────────────────────────────────────

function makeEvent(
  key: string,
  extra: Partial<KeyboardEvent> = {},
): KeyboardEvent {
  const preventDefault = vi.fn();
  return {
    key,
    metaKey: false,
    ctrlKey: false,
    altKey: false,
    target: {
      tagName: "DIV",
      isContentEditable: false,
    } as unknown as HTMLElement,
    preventDefault,
    ...extra,
  } as unknown as KeyboardEvent;
}

const ITEMS = ["alpha", "beta", "gamma", "delta", "epsilon"];

// ── Tests: index navigation ───────────────────────────────────────────────────

describe("useListKeyboard — ArrowDown / j", () => {
  it("starts at -1 (no selection)", () => {
    const kb = useListKeyboard({ items: () => ITEMS, onSelect: vi.fn() });
    expect(kb.selectedIndex).toBe(-1);
  });

  it("advances from -1 to 0 on first ArrowDown", () => {
    const kb = useListKeyboard({ items: () => ITEMS, onSelect: vi.fn() });
    kb.handleKeydown(makeEvent("ArrowDown"));
    expect(kb.selectedIndex).toBe(0);
  });

  it("advances index on each j press", () => {
    const kb = useListKeyboard({ items: () => ITEMS, onSelect: vi.fn() });
    kb.handleKeydown(makeEvent("j"));
    kb.handleKeydown(makeEvent("j"));
    expect(kb.selectedIndex).toBe(1);
  });

  it("wraps to 0 when past end on ArrowDown", () => {
    const kb = useListKeyboard({ items: () => ITEMS, onSelect: vi.fn() });
    // advance to last item
    for (let i = 0; i < ITEMS.length; i++)
      kb.handleKeydown(makeEvent("ArrowDown"));
    // one more wraps to 0
    kb.handleKeydown(makeEvent("ArrowDown"));
    expect(kb.selectedIndex).toBe(0);
  });
});

describe("useListKeyboard — ArrowUp / k", () => {
  it("wraps to last when at -1 on ArrowUp", () => {
    const kb = useListKeyboard({ items: () => ITEMS, onSelect: vi.fn() });
    kb.handleKeydown(makeEvent("ArrowUp"));
    expect(kb.selectedIndex).toBe(ITEMS.length - 1);
  });

  it("decrements index on k", () => {
    const kb = useListKeyboard({ items: () => ITEMS, onSelect: vi.fn() });
    // Go to index 3
    for (let i = 0; i < 4; i++) kb.handleKeydown(makeEvent("ArrowDown"));
    kb.handleKeydown(makeEvent("k"));
    expect(kb.selectedIndex).toBe(2);
  });
});

// ── Tests: Enter / onSelect ───────────────────────────────────────────────────

describe("useListKeyboard — Enter", () => {
  it("calls onSelect with the correct item when index ≥ 0", () => {
    const onSelect = vi.fn();
    const kb = useListKeyboard({ items: () => ITEMS, onSelect });
    kb.handleKeydown(makeEvent("ArrowDown")); // index 0
    kb.handleKeydown(makeEvent("ArrowDown")); // index 1
    kb.handleKeydown(makeEvent("Enter"));
    expect(onSelect).toHaveBeenCalledOnce();
    expect(onSelect).toHaveBeenCalledWith("beta", 1);
  });

  it("does NOT call onSelect when selectedIndex is -1", () => {
    const onSelect = vi.fn();
    const kb = useListKeyboard({ items: () => ITEMS, onSelect });
    kb.handleKeydown(makeEvent("Enter"));
    expect(onSelect).not.toHaveBeenCalled();
  });
});

// ── Tests: r / onRefresh ──────────────────────────────────────────────────────

describe("useListKeyboard — r key (refresh)", () => {
  it("calls onRefresh when r is pressed", () => {
    const onRefresh = vi.fn();
    const kb = useListKeyboard({
      items: () => ITEMS,
      onSelect: vi.fn(),
      onRefresh,
    });
    kb.handleKeydown(makeEvent("r"));
    expect(onRefresh).toHaveBeenCalledOnce();
  });

  it("does not throw when onRefresh is not provided", () => {
    const kb = useListKeyboard({ items: () => ITEMS, onSelect: vi.fn() });
    expect(() => kb.handleKeydown(makeEvent("r"))).not.toThrow();
  });
});

// ── Tests: ? / onHelp ────────────────────────────────────────────────────────

describe("useListKeyboard — ? key (help)", () => {
  it("calls onHelp when ? is pressed", () => {
    const onHelp = vi.fn();
    const kb = useListKeyboard({
      items: () => ITEMS,
      onSelect: vi.fn(),
      onHelp,
    });
    kb.handleKeydown(makeEvent("?"));
    expect(onHelp).toHaveBeenCalledOnce();
  });
});

// ── Tests: Escape ─────────────────────────────────────────────────────────────

describe("useListKeyboard — Escape", () => {
  it("resets selectedIndex to -1 on Escape", () => {
    const kb = useListKeyboard({ items: () => ITEMS, onSelect: vi.fn() });
    kb.handleKeydown(makeEvent("ArrowDown")); // index 0
    kb.handleKeydown(makeEvent("Escape"));
    expect(kb.selectedIndex).toBe(-1);
  });
});

// ── Tests: clearSelection ────────────────────────────────────────────────────

describe("useListKeyboard — clearSelection()", () => {
  it("resets selectedIndex to -1", () => {
    const kb = useListKeyboard({ items: () => ITEMS, onSelect: vi.fn() });
    kb.handleKeydown(makeEvent("j")); // index 0
    kb.clearSelection();
    expect(kb.selectedIndex).toBe(-1);
  });
});

// ── Tests: skip when input focused ───────────────────────────────────────────

describe("useListKeyboard — input focus guard", () => {
  it("does nothing when focus is in an INPUT element", () => {
    const onSelect = vi.fn();
    const kb = useListKeyboard({ items: () => ITEMS, onSelect });
    const inputEvent = makeEvent("j", {
      target: {
        tagName: "INPUT",
        isContentEditable: false,
      } as unknown as HTMLElement,
    });
    kb.handleKeydown(inputEvent);
    expect(kb.selectedIndex).toBe(-1);
  });

  it("does nothing when metaKey is held", () => {
    const kb = useListKeyboard({ items: () => ITEMS, onSelect: vi.fn() });
    kb.handleKeydown(makeEvent("j", { metaKey: true }));
    expect(kb.selectedIndex).toBe(-1);
  });
});

// ── Tests: empty list ────────────────────────────────────────────────────────

describe("useListKeyboard — empty items array", () => {
  it("does nothing when items is empty", () => {
    const onSelect = vi.fn();
    const kb = useListKeyboard({ items: () => [], onSelect });
    kb.handleKeydown(makeEvent("j"));
    expect(kb.selectedIndex).toBe(-1);
    expect(onSelect).not.toHaveBeenCalled();
  });
});
