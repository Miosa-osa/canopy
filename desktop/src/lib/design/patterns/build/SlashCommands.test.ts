/**
 * SlashCommands tests — pure-helper coverage.
 *
 * Focus: source grouping (`groupBySource`) + the local re-filter
 * (`filterCommands`). The Svelte component itself wraps these with TanStack
 * Query + keyboard nav; logic-level coverage of the two pure helpers is
 * sufficient for confidence that the palette displays the right rows.
 *
 * Test environment: Node — same precedent as `BuildSideRail.test.ts`.
 */

import { describe, expect, it } from "vitest";
import { filterCommands, groupBySource } from "./SlashCommands.svelte";
import type { BuildCommand } from "$lib/api/queries/build-commands.js";

// ── Fixtures ──────────────────────────────────────────────────────────────────

function cmd(
  source: BuildCommand["source"],
  name: string,
  description = "",
): BuildCommand {
  const ns = (
    {
      builtin: "build",
      runtime: "runtimes",
      drive_workflow: "drive",
      drive_prompt: "drive",
      template: "templates",
      skill: "skills",
    } as const
  )[source];
  return {
    namespace: ns,
    name,
    description,
    icon: "Bot",
    source,
    source_id: source === "builtin" ? null : `${source}-id`,
  };
}

const SAMPLE: BuildCommand[] = [
  cmd("builtin", "/agent", "Start a new conversation"),
  cmd("builtin", "/review", "Open code review"),
  cmd("runtime", "/claude", "Spawn Claude Code in this pane"),
  cmd("drive_workflow", "/squash-commits", "Squash the last N commits"),
  cmd("drive_prompt", "/code-review-prompt", "Review code carefully"),
  cmd("template", "/ship-feature", "Ship feature playbook"),
  cmd("skill", "/use-elixir-strict", "Apply Elixir strict skill"),
];

// ── filterCommands ───────────────────────────────────────────────────────────

describe("filterCommands()", () => {
  it("returns everything when query is empty", () => {
    expect(filterCommands(SAMPLE, "")).toHaveLength(SAMPLE.length);
    expect(filterCommands(SAMPLE, "   ")).toHaveLength(SAMPLE.length);
  });

  it("matches by name (case-insensitive)", () => {
    const result = filterCommands(SAMPLE, "AGENT");
    expect(result).toHaveLength(1);
    expect(result[0].name).toBe("/agent");
  });

  it("matches by description (case-insensitive)", () => {
    const result = filterCommands(SAMPLE, "playbook");
    expect(result).toHaveLength(1);
    expect(result[0].name).toBe("/ship-feature");
  });

  it("returns empty when nothing matches", () => {
    expect(filterCommands(SAMPLE, "nonexistent-zzz")).toEqual([]);
  });

  it("matches across multiple sources", () => {
    const result = filterCommands(SAMPLE, "review");
    const names = result.map((c) => c.name).sort();
    expect(names).toEqual(["/code-review-prompt", "/review"]);
  });
});

// ── groupBySource ────────────────────────────────────────────────────────────

describe("groupBySource()", () => {
  it("preserves canonical source order", () => {
    const groups = groupBySource(SAMPLE);
    const sources = groups.map((g) => g.source);
    expect(sources).toEqual([
      "builtin",
      "runtime",
      "drive_workflow",
      "drive_prompt",
      "template",
      "skill",
    ]);
  });

  it("attaches the canonical label per source", () => {
    const groups = groupBySource(SAMPLE);
    const labelMap = Object.fromEntries(groups.map((g) => [g.source, g.label]));
    expect(labelMap.builtin).toBe("BUILT-IN");
    expect(labelMap.runtime).toBe("RUNTIMES");
    expect(labelMap.drive_workflow).toBe("DRIVE — WORKFLOWS");
    expect(labelMap.drive_prompt).toBe("DRIVE — PROMPTS");
    expect(labelMap.template).toBe("TEMPLATES");
    expect(labelMap.skill).toBe("SKILLS");
  });

  it("omits sources with no items", () => {
    const onlyBuiltins = SAMPLE.filter((c) => c.source === "builtin");
    const groups = groupBySource(onlyBuiltins);
    expect(groups).toHaveLength(1);
    expect(groups[0].source).toBe("builtin");
  });

  it("returns empty array for empty input", () => {
    expect(groupBySource([])).toEqual([]);
  });

  it("groups multiple items in the same source together", () => {
    const groups = groupBySource(SAMPLE);
    const builtins = groups.find((g) => g.source === "builtin");
    expect(builtins?.items.map((c) => c.name)).toEqual(["/agent", "/review"]);
  });
});
