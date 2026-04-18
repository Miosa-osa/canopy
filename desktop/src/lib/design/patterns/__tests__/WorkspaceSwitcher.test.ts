/**
 * WorkspaceSwitcher — pure-logic unit tests.
 *
 * The component uses Svelte 5 runes + TanStack Query, which require a DOM +
 * compiler context. These tests exercise the pure helper logic that can run in
 * Node: emoji derivation, search filter, keyboard navigation index clamping,
 * and the template-emoji map exhaustiveness.
 */
import { beforeEach, describe, expect, it } from "vitest";
import type { Workspace } from "$lib/domain/workspaces/types.js";

// ── Template emoji map (mirror of WorkspaceSwitcher.svelte) ──────────────────

const TEMPLATE_EMOJI: Record<string, string> = {
  blank: "📄",
  "sales-engine": "💼",
  "dev-shop": "⚙️",
  "content-factory": "🎬",
};

function emojiFor(ws: Pick<Workspace, "template">): string {
  return ws.template ? (TEMPLATE_EMOJI[ws.template] ?? "📁") : "📁";
}

// ── Search filter (mirror of WorkspaceSwitcher.svelte filtered derived) ───────

function filterWorkspaces(workspaces: Workspace[], query: string): Workspace[] {
  if (query.trim() === "") return workspaces;
  const q = query.toLowerCase();
  return workspaces.filter(
    (w) => w.name.toLowerCase().includes(q) || w.slug.toLowerCase().includes(q),
  );
}

// ── Keyboard nav index clamp (mirror of arrow-key logic) ─────────────────────

function clampIndex(
  current: number,
  direction: "up" | "down",
  listLength: number,
): number {
  if (direction === "down") return Math.min(current + 1, listLength - 1);
  return Math.max(current - 1, 0);
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

function makeWorkspace(overrides: Partial<Workspace> = {}): Workspace {
  return {
    id: "ws-1",
    slug: "my-workspace",
    name: "My Workspace",
    description: null,
    rootPath: "/home/user/projects",
    template: null,
    deletedAt: null,
    insertedAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    ...overrides,
  };
}

const fixtures: Workspace[] = [
  makeWorkspace({
    id: "1",
    slug: "alpha",
    name: "Alpha Project",
    template: "blank",
  }),
  makeWorkspace({
    id: "2",
    slug: "beta-sales",
    name: "Beta Sales",
    template: "sales-engine",
  }),
  makeWorkspace({
    id: "3",
    slug: "dev-shop",
    name: "Dev Shop",
    template: "dev-shop",
  }),
  makeWorkspace({
    id: "4",
    slug: "content",
    name: "Content Factory",
    template: "content-factory",
  }),
  makeWorkspace({
    id: "5",
    slug: "custom-ws",
    name: "Custom WS",
    template: null,
  }),
  makeWorkspace({
    id: "6",
    slug: "unknown-tmpl",
    name: "Unknown",
    template: "future-type",
  }),
];

// ── Tests: emoji derivation ───────────────────────────────────────────────────

describe("emojiFor()", () => {
  it("returns 📄 for blank template", () => {
    expect(emojiFor({ template: "blank" })).toBe("📄");
  });

  it("returns 💼 for sales-engine template", () => {
    expect(emojiFor({ template: "sales-engine" })).toBe("💼");
  });

  it("returns ⚙️ for dev-shop template", () => {
    expect(emojiFor({ template: "dev-shop" })).toBe("⚙️");
  });

  it("returns 🎬 for content-factory template", () => {
    expect(emojiFor({ template: "content-factory" })).toBe("🎬");
  });

  it("returns 📁 when template is null", () => {
    expect(emojiFor({ template: null })).toBe("📁");
  });

  it("returns 📁 for unknown template slug", () => {
    expect(emojiFor({ template: "future-type" })).toBe("📁");
  });
});

// ── Tests: search filter ──────────────────────────────────────────────────────

describe("filterWorkspaces()", () => {
  it("returns all workspaces for empty query", () => {
    expect(filterWorkspaces(fixtures, "")).toHaveLength(fixtures.length);
  });

  it("returns all workspaces for whitespace-only query", () => {
    expect(filterWorkspaces(fixtures, "   ")).toHaveLength(fixtures.length);
  });

  it("filters by name (case-insensitive)", () => {
    const result = filterWorkspaces(fixtures, "alpha");
    expect(result).toHaveLength(1);
    expect(result[0].slug).toBe("alpha");
  });

  it("filters by slug substring", () => {
    const result = filterWorkspaces(fixtures, "beta-sales");
    expect(result).toHaveLength(1);
    expect(result[0].slug).toBe("beta-sales");
  });

  it("is case-insensitive on both name and slug", () => {
    const result = filterWorkspaces(fixtures, "CONTENT");
    expect(result.length).toBeGreaterThanOrEqual(1);
    expect(result.some((w) => w.slug === "content")).toBe(true);
  });

  it("returns empty array when no match", () => {
    const result = filterWorkspaces(fixtures, "zzznomatch");
    expect(result).toHaveLength(0);
  });

  it("matches partial slug", () => {
    const result = filterWorkspaces(fixtures, "custom");
    expect(result).toHaveLength(1);
    expect(result[0].slug).toBe("custom-ws");
  });
});

// ── Tests: keyboard navigation ────────────────────────────────────────────────

describe("clampIndex() — keyboard ↑/↓ navigation", () => {
  const listLength = 5;

  it("increments index on ArrowDown", () => {
    expect(clampIndex(0, "down", listLength)).toBe(1);
    expect(clampIndex(2, "down", listLength)).toBe(3);
  });

  it("clamps at last item on ArrowDown", () => {
    expect(clampIndex(4, "down", listLength)).toBe(4);
    expect(clampIndex(10, "down", listLength)).toBe(4);
  });

  it("decrements index on ArrowUp", () => {
    expect(clampIndex(3, "up", listLength)).toBe(2);
    expect(clampIndex(1, "up", listLength)).toBe(0);
  });

  it("clamps at 0 on ArrowUp", () => {
    expect(clampIndex(0, "up", listLength)).toBe(0);
    expect(clampIndex(-5, "up", listLength)).toBe(0);
  });
});

// ── Tests: smoke — fixture integrity ─────────────────────────────────────────

describe("fixture integrity", () => {
  it("all fixtures satisfy the Workspace interface shape", () => {
    for (const ws of fixtures) {
      expect(typeof ws.id).toBe("string");
      expect(typeof ws.slug).toBe("string");
      expect(typeof ws.name).toBe("string");
      expect(ws.slug.length).toBeGreaterThan(0);
    }
  });

  it("fixture slugs are unique", () => {
    const slugs = fixtures.map((w) => w.slug);
    expect(new Set(slugs).size).toBe(slugs.length);
  });
});
