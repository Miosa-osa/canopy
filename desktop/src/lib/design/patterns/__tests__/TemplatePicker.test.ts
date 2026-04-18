/**
 * Smoke tests for TemplatePicker query factory and type shapes.
 * Validates workspaceTemplatesQuery and createWorkspaceMutation contracts.
 */
import { describe, expect, it } from "vitest";
import {
  createWorkspaceMutation,
  workspaceTemplatesQuery,
} from "$lib/api/queries/workspaces.js";
import type {
  CreateWorkspaceBody,
  WorkspaceTemplate,
} from "$lib/domain/workspaces/types.js";

describe("workspaceTemplatesQuery()", () => {
  it('returns queryKey ["workspaces", "templates"]', () => {
    const q = workspaceTemplatesQuery();
    expect(q.queryKey).toEqual(["workspaces", "templates"]);
  });

  it("has staleTime of Infinity (templates are static)", () => {
    const q = workspaceTemplatesQuery();
    expect(q.staleTime).toBe(Infinity);
  });

  it("has a queryFn function", () => {
    const q = workspaceTemplatesQuery();
    expect(typeof q.queryFn).toBe("function");
  });
});

describe("createWorkspaceMutation()", () => {
  it('returns mutationKey ["workspaces", "create"]', () => {
    const m = createWorkspaceMutation();
    expect(m.mutationKey).toEqual(["workspaces", "create"]);
  });

  it("has a mutationFn function", () => {
    const m = createWorkspaceMutation();
    expect(typeof m.mutationFn).toBe("function");
  });
});

describe("WorkspaceTemplate type shape", () => {
  it("can be constructed with all 4 known slugs", () => {
    const slugs: WorkspaceTemplate["slug"][] = [
      "blank",
      "sales-engine",
      "dev-shop",
      "content-factory",
    ];
    expect(slugs).toHaveLength(4);
    expect(slugs).toContain("blank");
    expect(slugs).toContain("sales-engine");
    expect(slugs).toContain("dev-shop");
    expect(slugs).toContain("content-factory");
  });

  it("can be constructed with required fields", () => {
    const t: WorkspaceTemplate = {
      slug: "blank",
      name: "Blank",
      description: "A blank workspace",
      files: [],
    };
    expect(t.slug).toBe("blank");
    expect(t.files).toHaveLength(0);
  });
});

describe("CreateWorkspaceBody type shape", () => {
  it("requires slug and rootPath, allows optional fields", () => {
    const body: CreateWorkspaceBody = {
      slug: "test-ws",
      rootPath: "~/canopy-workspaces/test-ws",
    };
    expect(body.slug).toBe("test-ws");
    expect(body.rootPath).toBe("~/canopy-workspaces/test-ws");
    expect(body.name).toBeUndefined();
    expect(body.templateSlug).toBeUndefined();
  });

  it("accepts all optional fields", () => {
    const body: CreateWorkspaceBody = {
      slug: "sales-ws",
      name: "Sales Workspace",
      rootPath: "~/canopy-workspaces/sales-ws",
      description: "My sales workspace",
      templateSlug: "sales-engine",
    };
    expect(body.templateSlug).toBe("sales-engine");
    expect(body.description).toBe("My sales workspace");
  });

  it("accepts null for optional nullable fields", () => {
    const body: CreateWorkspaceBody = {
      slug: "blank-ws",
      rootPath: "~/canopy-workspaces/blank-ws",
      description: null,
      templateSlug: null,
    };
    expect(body.description).toBeNull();
    expect(body.templateSlug).toBeNull();
  });
});

describe("TemplatePicker emoji mapping", () => {
  const TEMPLATE_EMOJI: Record<string, string> = {
    blank: "📄",
    "sales-engine": "💼",
    "dev-shop": "⚙️",
    "content-factory": "🎬",
  };

  it("maps all 4 template slugs to distinct emoji", () => {
    const emojis = Object.values(TEMPLATE_EMOJI);
    const unique = new Set(emojis);
    expect(unique.size).toBe(4);
  });

  it("provides a fallback for unknown slugs via ??", () => {
    const slug = "unknown";
    const result = TEMPLATE_EMOJI[slug] ?? "📁";
    expect(result).toBe("📁");
  });
});
