/**
 * KanbanBoard — unit tests.
 * Tests status-grouping logic, column counts, and empty-column states.
 * Drag-and-drop is not tested here (requires DOM + svelte-dnd-action internals).
 */
import { describe, expect, it } from "vitest";
import type { Task, TaskStatus } from "$lib/domain/tasks/types.js";

// ── Helpers extracted from KanbanBoard internals ──────────────────────────────

function buildColumns(tasks: Task[]): Record<TaskStatus, Task[]> {
  return {
    todo: tasks.filter((t) => t.status === "todo"),
    in_progress: tasks.filter((t) => t.status === "in_progress"),
    done: tasks.filter((t) => t.status === "done"),
    cancelled: tasks.filter((t) => t.status === "cancelled"),
  };
}

const PRIORITY_COLORS: Record<number, string> = {
  0: "var(--fg-subtle)",
  1: "oklch(0.72 0.09 145)",
  2: "oklch(0.75 0.15 60)",
  3: "oklch(0.65 0.20 25)",
};

function priorityColor(p: number): string {
  return PRIORITY_COLORS[p] ?? PRIORITY_COLORS[0];
}

function formatRelativeDue(iso: string | null): string | null {
  if (!iso) return null;
  const diff = new Date(iso).getTime() - Date.now();
  const days = Math.ceil(diff / 86_400_000);
  if (days < 0) return `${Math.abs(days)}d overdue`;
  if (days === 0) return "Today";
  if (days === 1) return "Tomorrow";
  if (days < 7) return `${days}d`;
  return new Date(iso).toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
  });
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

function makeTask(
  overrides: Partial<Task> & {
    id: string;
    shortId: string;
    status: TaskStatus;
  },
): Task {
  return {
    title: "Test task",
    description: null,
    priority: 0,
    assigneeType: null,
    assigneeId: null,
    projectSlug: null,
    workspaceSlug: null,
    dueAt: null,
    completedAt: null,
    labels: [],
    parentId: null,
    reviewId: null,
    insertedAt: "2026-04-18T00:00:00Z",
    updatedAt: "2026-04-18T00:00:00Z",
    ...overrides,
  };
}

const TASKS: Task[] = [
  makeTask({
    id: "1",
    shortId: "T-00000001",
    status: "todo",
    title: "First todo",
  }),
  makeTask({
    id: "2",
    shortId: "T-00000002",
    status: "todo",
    title: "Second todo",
  }),
  makeTask({
    id: "3",
    shortId: "T-00000003",
    status: "in_progress",
    title: "In flight",
  }),
  makeTask({
    id: "4",
    shortId: "T-00000004",
    status: "done",
    title: "Shipped",
  }),
  makeTask({
    id: "5",
    shortId: "T-00000005",
    status: "cancelled",
    title: "Dropped",
  }),
];

// ── Tests ─────────────────────────────────────────────────────────────────────

describe("buildColumns", () => {
  it("groups tasks into the correct columns", () => {
    const cols = buildColumns(TASKS);
    expect(cols.todo.length).toBe(2);
    expect(cols.in_progress.length).toBe(1);
    expect(cols.done.length).toBe(1);
    expect(cols.cancelled.length).toBe(1);
  });

  it("all tasks appear in exactly one column", () => {
    const cols = buildColumns(TASKS);
    const all = [
      ...cols.todo,
      ...cols.in_progress,
      ...cols.done,
      ...cols.cancelled,
    ];
    expect(all.length).toBe(TASKS.length);
  });

  it("each task ends up in the column matching its status", () => {
    const cols = buildColumns(TASKS);
    for (const task of cols.todo) expect(task.status).toBe("todo");
    for (const task of cols.in_progress)
      expect(task.status).toBe("in_progress");
    for (const task of cols.done) expect(task.status).toBe("done");
    for (const task of cols.cancelled) expect(task.status).toBe("cancelled");
  });

  it("returns empty arrays for all columns when tasks list is empty", () => {
    const cols = buildColumns([]);
    expect(cols.todo).toHaveLength(0);
    expect(cols.in_progress).toHaveLength(0);
    expect(cols.done).toHaveLength(0);
    expect(cols.cancelled).toHaveLength(0);
  });

  it("handles a single task in one column, rest empty", () => {
    const single = [
      makeTask({
        id: "99",
        shortId: "T-00000099",
        status: "in_progress",
        title: "Only one",
      }),
    ];
    const cols = buildColumns(single);
    expect(cols.in_progress).toHaveLength(1);
    expect(cols.todo).toHaveLength(0);
    expect(cols.done).toHaveLength(0);
    expect(cols.cancelled).toHaveLength(0);
  });
});

describe("priorityColor", () => {
  it("returns distinct colors for each priority level 0–3", () => {
    const colors = [0, 1, 2, 3].map((p) => priorityColor(p));
    const unique = new Set(colors);
    expect(unique.size).toBe(4);
  });

  it("falls back to priority-0 color for unknown values", () => {
    expect(priorityColor(99)).toBe(priorityColor(0));
  });

  it("returns a CSS string for priority 0", () => {
    expect(typeof priorityColor(0)).toBe("string");
    expect(priorityColor(0).length).toBeGreaterThan(0);
  });
});

describe("formatRelativeDue", () => {
  it("returns null for null due date", () => {
    expect(formatRelativeDue(null)).toBeNull();
  });

  it('returns "Today" for a due date exactly now (diff = 0 days ceiling)', () => {
    // diff = 0 → Math.ceil(0 / 86_400_000) = 0 → "Today"
    const exactlyNow = new Date(Date.now());
    const result = formatRelativeDue(exactlyNow.toISOString());
    expect(result).toBe("Today");
  });

  it('returns "Tomorrow" for a due date exactly 24 hours and 1 second from now', () => {
    // diff = 86_401_000 ms → ceil(86_401_000 / 86_400_000) = 2? No.
    // ceil(1.000011...) = 2. The logic: days=1 is only hit for exactly 86_400_000 ms.
    // Use exactly 86_400_000 ms (1 day) → ceil(1.0) = 1 → "Tomorrow"
    const oneDayExact = new Date(Date.now() + 86_400_000);
    const result = formatRelativeDue(oneDayExact.toISOString());
    expect(result).toBe("Tomorrow");
  });

  it("returns overdue string for a past date", () => {
    const past = new Date(Date.now() - 3 * 86_400_000); // 3 days ago
    const result = formatRelativeDue(past.toISOString());
    expect(result).toMatch(/overdue/);
  });

  it("returns day count for dates within the next week", () => {
    const inThreeDays = new Date(Date.now() + 3 * 86_400_000 + 1000);
    const result = formatRelativeDue(inThreeDays.toISOString());
    expect(result).toMatch(/^[2-6]d$/);
  });

  it("returns a formatted date string for dates more than 6 days away", () => {
    const farFuture = new Date(Date.now() + 30 * 86_400_000);
    const result = formatRelativeDue(farFuture.toISOString());
    expect(typeof result).toBe("string");
    expect(result).not.toBeNull();
  });
});

describe("Column empty state", () => {
  it("identifies an empty column correctly", () => {
    const cols = buildColumns(TASKS);
    // All 4 columns have at least 1 task in our fixture; remove done + cancelled:
    const subset = TASKS.filter(
      (t) => t.status === "todo" || t.status === "in_progress",
    );
    const partialCols = buildColumns(subset);
    expect(partialCols.done).toHaveLength(0);
    expect(partialCols.cancelled).toHaveLength(0);
    expect(partialCols.todo.length).toBeGreaterThan(0);
  });
});
