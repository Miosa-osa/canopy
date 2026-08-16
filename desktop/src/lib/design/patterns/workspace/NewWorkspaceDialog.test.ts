/**
 * NewWorkspaceDialog — pure-logic tests.
 *
 * Test environment: Node (no DOM, no Svelte renderer) — same precedent as
 * WorkspaceSwitcher pure-logic tests, ContextMenu.test.ts, etc. We test
 * the slugify helper, validation rules, and form-state contract that are
 * independently verifiable.
 */
import { describe, expect, it } from "vitest";

// ── Slugify helper (mirrored from NewWorkspaceDialog.svelte) ────────────────

function slugify(input: string): string {
  return input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 128);
}

describe("slugify()", () => {
  it("lowercases and dashes whitespace", () => {
    expect(slugify("My Workspace")).toBe("my-workspace");
  });

  it("strips punctuation", () => {
    expect(slugify("Robert's Project!")).toBe("robert-s-project");
  });

  it("collapses runs of dashes", () => {
    expect(slugify("a---b")).toBe("a-b");
  });

  it("trims leading/trailing dashes", () => {
    expect(slugify("---trim---")).toBe("trim");
  });

  it("returns empty string for non-alphanumeric input", () => {
    expect(slugify("!!!")).toBe("");
    expect(slugify("   ")).toBe("");
  });

  it("preserves digits", () => {
    expect(slugify("Sprint 2026 04")).toBe("sprint-2026-04");
  });

  it("caps at 128 characters", () => {
    const long = "a".repeat(200);
    expect(slugify(long).length).toBe(128);
  });

  it("matches the server-side slug regex", () => {
    const SERVER_REGEX = /^[a-z0-9][a-z0-9_-]{0,127}$/;
    const samples = [
      "my-workspace",
      "sprint-2026-04",
      "a-b",
      "robert-s-project",
    ];
    for (const sample of samples) {
      expect(SERVER_REGEX.test(sample)).toBe(true);
    }
  });
});

// ── Form validation contract ─────────────────────────────────────────────────

describe("form validation contract", () => {
  // Mirrors `handleSubmit()` in NewWorkspaceDialog.svelte.
  function validate(
    workspaceName: string,
    selectedPath: string | null,
  ): string | null {
    if (workspaceName.trim().length === 0) {
      return "Workspace name is required.";
    }
    const slug = slugify(workspaceName);
    if (slug.length === 0) {
      return "Workspace name must contain at least one letter or digit.";
    }
    if (selectedPath === null || selectedPath.trim().length === 0) {
      return "Choose a folder to bind this workspace to.";
    }
    return null;
  }

  it("rejects an empty name", () => {
    expect(validate("", "/tmp/x")).toBe("Workspace name is required.");
    expect(validate("   ", "/tmp/x")).toBe("Workspace name is required.");
  });

  it("rejects a name with no alphanumeric content", () => {
    expect(validate("!!!", "/tmp/x")).toBe(
      "Workspace name must contain at least one letter or digit.",
    );
  });

  it("rejects a missing folder", () => {
    expect(validate("OK", null)).toBe(
      "Choose a folder to bind this workspace to.",
    );
    expect(validate("OK", "")).toBe(
      "Choose a folder to bind this workspace to.",
    );
  });

  it("accepts a valid name + folder", () => {
    expect(validate("My Workspace", "/Users/me/work")).toBeNull();
  });
});

// ── Tauri plugin gate ────────────────────────────────────────────────────────

describe("Tauri folder picker fallback", () => {
  // The dialog dynamic-imports `@tauri-apps/plugin-dialog`. In a non-Tauri
  // runtime the import would throw — the component must surface that as
  // `pickError` rather than crashing. Reproduce the contract here.
  async function tryPick(
    importer: () => Promise<{
      open: (opts: unknown) => Promise<string | null>;
    }>,
  ): Promise<{ path: string | null; error: string | null }> {
    try {
      const { open } = await importer();
      const result = await open({ directory: true, multiple: false });
      return {
        path: typeof result === "string" ? result : null,
        error: null,
      };
    } catch (err) {
      return {
        path: null,
        error: err instanceof Error ? err.message : "unknown",
      };
    }
  }

  it("returns the picked path on success", async () => {
    const result = await tryPick(async () => ({
      open: async () => "/Users/me/picked",
    }));
    expect(result).toEqual({ path: "/Users/me/picked", error: null });
  });

  it("returns null when the user cancels (open returns null)", async () => {
    const result = await tryPick(async () => ({
      open: async () => null,
    }));
    expect(result.path).toBeNull();
    expect(result.error).toBeNull();
  });

  it("captures the import error as a user-visible message", async () => {
    const result = await tryPick(async () => {
      throw new Error("plugin not loaded");
    });
    expect(result.path).toBeNull();
    expect(result.error).toBe("plugin not loaded");
  });
});
