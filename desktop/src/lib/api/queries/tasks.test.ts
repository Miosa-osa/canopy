/**
 * Tests for tasks query factories.
 * Verifies query key shapes, filter wiring, enabled flags, and mutation key shapes.
 */
import { describe, expect, it } from "vitest";
import {
  assignTaskMutation,
  completeTaskMutation,
  createTaskMutation,
  deleteTaskMutation,
  reopenTaskMutation,
  taskQuery,
  tasksQuery,
  updateTaskMutation,
} from "./tasks.js";

describe("tasksQuery()", () => {
  it('returns query key ["tasks", {}] with no filters', () => {
    const q = tasksQuery();
    expect(q.queryKey).toEqual(["tasks", {}]);
  });

  it("includes filter object in query key", () => {
    const filters = { status: "todo" as const, q: "fix bug" };
    const q = tasksQuery(filters);
    expect(q.queryKey).toEqual(["tasks", filters]);
  });

  it("has staleTime of 15_000", () => {
    expect(tasksQuery().staleTime).toBe(15_000);
  });

  it("has a queryFn function", () => {
    expect(typeof tasksQuery().queryFn).toBe("function");
  });

  it("accepts all filter fields", () => {
    const filters = {
      status: "in_progress" as const,
      assigneeType: "agent",
      assigneeId: "senior-dev",
      projectSlug: "canopy-v2",
      parentId: "T-00001234",
      q: "search term",
    };
    const q = tasksQuery(filters);
    expect(q.queryKey[1]).toEqual(filters);
  });
});

describe("taskQuery()", () => {
  it('returns query key ["tasks", shortId]', () => {
    const q = taskQuery("T-12345678");
    expect(q.queryKey).toEqual(["tasks", "T-12345678"]);
  });

  it("is disabled when shortId is empty", () => {
    expect(taskQuery("").enabled).toBe(false);
  });

  it("is enabled when shortId is non-empty", () => {
    expect(taskQuery("T-12345678").enabled).toBe(true);
  });

  it("has staleTime of 10_000", () => {
    expect(taskQuery("T-12345678").staleTime).toBe(10_000);
  });

  it("has a queryFn function", () => {
    expect(typeof taskQuery("T-12345678").queryFn).toBe("function");
  });
});

describe("createTaskMutation()", () => {
  it('returns mutationKey ["tasks", "create"]', () => {
    const m = createTaskMutation();
    expect(m.mutationKey).toEqual(["tasks", "create"]);
  });

  it("has a mutationFn function", () => {
    expect(typeof createTaskMutation().mutationFn).toBe("function");
  });
});

describe("updateTaskMutation()", () => {
  it('returns mutationKey ["tasks", "update"]', () => {
    const m = updateTaskMutation();
    expect(m.mutationKey).toEqual(["tasks", "update"]);
  });

  it("has a mutationFn function", () => {
    expect(typeof updateTaskMutation().mutationFn).toBe("function");
  });
});

describe("deleteTaskMutation()", () => {
  it('returns mutationKey ["tasks", "delete"]', () => {
    const m = deleteTaskMutation();
    expect(m.mutationKey).toEqual(["tasks", "delete"]);
  });

  it("has a mutationFn function", () => {
    expect(typeof deleteTaskMutation().mutationFn).toBe("function");
  });
});

describe("completeTaskMutation()", () => {
  it('returns mutationKey ["tasks", "complete"]', () => {
    const m = completeTaskMutation();
    expect(m.mutationKey).toEqual(["tasks", "complete"]);
  });

  it("has a mutationFn function", () => {
    expect(typeof completeTaskMutation().mutationFn).toBe("function");
  });
});

describe("reopenTaskMutation()", () => {
  it('returns mutationKey ["tasks", "reopen"]', () => {
    const m = reopenTaskMutation();
    expect(m.mutationKey).toEqual(["tasks", "reopen"]);
  });

  it("has a mutationFn function", () => {
    expect(typeof reopenTaskMutation().mutationFn).toBe("function");
  });
});

describe("assignTaskMutation()", () => {
  it('returns mutationKey ["tasks", "assign"]', () => {
    const m = assignTaskMutation();
    expect(m.mutationKey).toEqual(["tasks", "assign"]);
  });

  it("has a mutationFn function", () => {
    expect(typeof assignTaskMutation().mutationFn).toBe("function");
  });
});
