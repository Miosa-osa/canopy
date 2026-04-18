/**
 * Tests for sessions query factories.
 * Verifies query key shapes, filter wiring, enabled flags, and mutation key shapes.
 */
import { describe, expect, it } from "vitest";
import {
  cancelSessionMutation,
  createSessionMutation,
  sessionChainQuery,
  sessionDetailQuery,
  sessionMessagesQuery,
  sessionsQuery,
} from "./sessions.js";

describe("sessionsQuery()", () => {
  it('returns query key ["sessions", {}] with no filters', () => {
    const q = sessionsQuery();
    expect(q.queryKey).toEqual(["sessions", {}]);
  });

  it("includes filter object in query key", () => {
    const filters = { status: "running", workspaceSlug: "acme" };
    const q = sessionsQuery(filters);
    expect(q.queryKey).toEqual(["sessions", filters]);
  });

  it("has staleTime of 10_000", () => {
    expect(sessionsQuery().staleTime).toBe(10_000);
  });

  it("has a queryFn function", () => {
    expect(typeof sessionsQuery().queryFn).toBe("function");
  });

  it("accepts workspaceSlug filter without type error", () => {
    const q = sessionsQuery({ workspaceSlug: "my-workspace" });
    expect(q.queryKey[1]).toMatchObject({ workspaceSlug: "my-workspace" });
  });

  it("accepts all filter fields", () => {
    const filters = {
      status: "completed",
      runtimeType: "claude-local",
      workspaceSlug: "test-ws",
      agentSlug: "senior-dev",
      limit: 25,
      offset: 0,
    };
    const q = sessionsQuery(filters);
    expect(q.queryKey[1]).toEqual(filters);
  });
});

describe("sessionDetailQuery()", () => {
  it('returns query key ["sessions", id]', () => {
    const q = sessionDetailQuery("abc-123");
    expect(q.queryKey).toEqual(["sessions", "abc-123"]);
  });

  it("is disabled when id is empty", () => {
    expect(sessionDetailQuery("").enabled).toBe(false);
  });

  it("is enabled when id is non-empty", () => {
    expect(sessionDetailQuery("abc-123").enabled).toBe(true);
  });

  it("has staleTime of 5_000", () => {
    expect(sessionDetailQuery("x").staleTime).toBe(5_000);
  });
});

describe("sessionMessagesQuery()", () => {
  it('returns query key ["sessions", id, "messages", {}] with no opts', () => {
    const q = sessionMessagesQuery("abc-123");
    expect(q.queryKey).toEqual(["sessions", "abc-123", "messages", {}]);
  });

  it("includes opts in query key", () => {
    const q = sessionMessagesQuery("abc-123", { limit: 10 });
    expect(q.queryKey).toEqual([
      "sessions",
      "abc-123",
      "messages",
      { limit: 10 },
    ]);
  });

  it("is disabled when id is empty", () => {
    expect(sessionMessagesQuery("").enabled).toBe(false);
  });

  it("has staleTime of 0 (always fresh)", () => {
    expect(sessionMessagesQuery("abc").staleTime).toBe(0);
  });
});

describe("sessionChainQuery()", () => {
  it('returns query key ["sessions", id, "chain"]', () => {
    const q = sessionChainQuery("abc-123");
    expect(q.queryKey).toEqual(["sessions", "abc-123", "chain"]);
  });

  it("is disabled when id is empty", () => {
    expect(sessionChainQuery("").enabled).toBe(false);
  });

  it("has staleTime of 30_000", () => {
    expect(sessionChainQuery("x").staleTime).toBe(30_000);
  });
});

describe("createSessionMutation()", () => {
  it('returns mutationKey ["sessions", "create"]', () => {
    const m = createSessionMutation();
    expect(m.mutationKey).toEqual(["sessions", "create"]);
  });

  it("has a mutationFn function", () => {
    expect(typeof createSessionMutation().mutationFn).toBe("function");
  });
});

describe("cancelSessionMutation()", () => {
  it('returns mutationKey ["sessions", "cancel"]', () => {
    const m = cancelSessionMutation();
    expect(m.mutationKey).toEqual(["sessions", "cancel"]);
  });

  it("has a mutationFn function", () => {
    expect(typeof cancelSessionMutation().mutationFn).toBe("function");
  });
});
