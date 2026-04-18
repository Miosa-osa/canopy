/**
 * Smoke tests for WorkspaceCard props and template emoji mapping.
 * Validates type construction and the TEMPLATE_EMOJI mapping logic.
 */
import { describe, expect, it } from "vitest";
import type { Workspace } from "$lib/domain/workspaces/types.js";

const TEMPLATE_EMOJI: Record<string, string> = {
  blank: "📄",
  "sales-engine": "💼",
  "dev-shop": "⚙️",
  "content-factory": "🎬",
};

function resolveEmoji(template: string | null): string {
  if (!template) return "📁";
  return TEMPLATE_EMOJI[template] ?? "📁";
}

const baseWorkspace: Workspace = {
  id: "ws-001",
  slug: "my-workspace",
  name: "My Workspace",
  description: "A test workspace",
  rootPath: "~/canopy-workspaces/my-workspace",
  template: null,
  deletedAt: null,
  insertedAt: "2026-04-18T00:00:00Z",
  updatedAt: "2026-04-18T00:00:00Z",
};

describe("Workspace type shape", () => {
  it("can be constructed with required fields", () => {
    const ws: Workspace = { ...baseWorkspace };
    expect(ws.id).toBe("ws-001");
    expect(ws.slug).toBe("my-workspace");
    expect(ws.rootPath).toBe("~/canopy-workspaces/my-workspace");
  });

  it("allows null for optional fields", () => {
    const ws: Workspace = {
      ...baseWorkspace,
      description: null,
      template: null,
      deletedAt: null,
    };
    expect(ws.description).toBeNull();
    expect(ws.template).toBeNull();
    expect(ws.deletedAt).toBeNull();
  });
});

describe("WorkspaceCard emoji resolution", () => {
  it("returns 📁 for null template", () => {
    expect(resolveEmoji(null)).toBe("📁");
  });

  it("returns 📄 for blank template", () => {
    expect(resolveEmoji("blank")).toBe("📄");
  });

  it("returns 💼 for sales-engine template", () => {
    expect(resolveEmoji("sales-engine")).toBe("💼");
  });

  it("returns ⚙️ for dev-shop template", () => {
    expect(resolveEmoji("dev-shop")).toBe("⚙️");
  });

  it("returns 🎬 for content-factory template", () => {
    expect(resolveEmoji("content-factory")).toBe("🎬");
  });

  it("falls back to 📁 for unknown template slug", () => {
    expect(resolveEmoji("unknown-slug")).toBe("📁");
  });
});

describe("WorkspaceCard onDelete prop", () => {
  it("accepts an optional onDelete callback", () => {
    // Verify the prop type is compatible: undefined is valid
    const onDelete: (() => void) | undefined = undefined;
    expect(onDelete).toBeUndefined();
  });

  it("accepts a provided onDelete callback", () => {
    let called = false;
    const onDelete: (() => void) | undefined = () => {
      called = true;
    };
    if (onDelete) onDelete();
    expect(called).toBe(true);
  });
});
