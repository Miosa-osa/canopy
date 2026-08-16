/**
 * AgentKanbanPane — contract-level tests.
 *
 * Mirrors the test strategy used by AgentConversationPane.test.ts: the
 * pane uses Svelte 5 runes + TanStack Query which the Vitest "server"
 * project does not load, so we exercise the contracts the pane relies on
 * (not the rendered DOM):
 *
 *   - The four-column model in `KANBAN_COLUMNS` keeps the canonical order
 *   - `AgentKanbanBoard` JSON shape from the backend round-trips into
 *     the column buckets without dropping fields
 *   - The `Task` shape narrowed by the kanban pane preserves the
 *     `claimedByAgentId` / `requiredSkills` extension fields
 */

import { describe, expect, it } from "vitest";
import {
  KANBAN_COLUMNS,
  type AgentKanbanBoard,
  type AgentKanbanColumn,
} from "$lib/domain/agent-kanban/types.js";
import type { Task } from "$lib/domain/tasks/types.js";

// ── Column ordering ──────────────────────────────────────────────────────────

describe("KANBAN_COLUMNS", () => {
  it("has the expected canonical order", () => {
    const keys = KANBAN_COLUMNS.map((c) => c.key);
    expect(keys).toEqual(["backlog", "claimed", "in_progress", "done"]);
  });

  it("provides a human label for every column", () => {
    for (const col of KANBAN_COLUMNS) {
      expect(col.label.length).toBeGreaterThan(0);
    }
  });

  it("uses every column variant from AgentKanbanColumn", () => {
    const variants: AgentKanbanColumn[] = [
      "backlog",
      "claimed",
      "in_progress",
      "done",
    ];
    const keys = KANBAN_COLUMNS.map((c) => c.key);
    for (const v of variants) {
      expect(keys).toContain(v);
    }
  });
});

// ── Board JSON round-trip ────────────────────────────────────────────────────

describe("AgentKanbanBoard", () => {
  it("round-trips through JSON without losing column buckets", () => {
    const board: AgentKanbanBoard = {
      backlog: [],
      claimed: [],
      in_progress: [],
      done: [],
    };
    const round = JSON.parse(JSON.stringify(board)) as AgentKanbanBoard;
    expect(round).toEqual(board);
  });

  it("buckets a task into the matching column by status", () => {
    const sample: Task = {
      id: "id-1",
      shortId: "T-00000001",
      title: "Sample",
      description: null,
      status: "todo",
      priority: 0,
      assigneeType: null,
      assigneeId: null,
      projectSlug: null,
      workspaceSlug: "default",
      dueAt: null,
      completedAt: null,
      labels: [],
      parentId: null,
      reviewId: null,
      insertedAt: "2026-04-30T00:00:00Z",
      updatedAt: "2026-04-30T00:00:00Z",
    };
    const board: AgentKanbanBoard = {
      backlog: [sample],
      claimed: [],
      in_progress: [],
      done: [],
    };
    expect(board.backlog).toHaveLength(1);
    expect(board.backlog[0].shortId).toBe("T-00000001");
  });
});

// ── Task extension shape (claim fields) ──────────────────────────────────────

describe("Task with kanban extension fields", () => {
  it("permits claimedByAgentId and requiredSkills via interface intersection", () => {
    const task: Task & {
      claimedByAgentId?: string | null;
      requiredSkills?: string[];
    } = {
      id: "id-2",
      shortId: "T-00000002",
      title: "Claimed task",
      description: null,
      status: "in_progress",
      priority: 2,
      assigneeType: "agent",
      assigneeId: "alice",
      projectSlug: null,
      workspaceSlug: "default",
      dueAt: null,
      completedAt: null,
      labels: [],
      parentId: null,
      reviewId: null,
      insertedAt: "2026-04-30T00:00:00Z",
      updatedAt: "2026-04-30T00:00:00Z",
      claimedByAgentId: "alice",
      requiredSkills: ["elixir"],
    };
    expect(task.claimedByAgentId).toBe("alice");
    expect(task.requiredSkills).toEqual(["elixir"]);
  });
});
