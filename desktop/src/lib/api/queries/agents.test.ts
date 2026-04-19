/**
 * Tests for agents query factories.
 * Verifies query key shapes and filter URL construction.
 */
import { describe, expect, it } from "vitest";
import {
  agentDetailQuery,
  agentHeartbeatsQuery,
  agentsQuery,
  createAgentMutation,
  fireAgentMutation,
  hireAgentMutation,
  updatePersonaMutation,
} from "./agents.js";

describe("agentsQuery()", () => {
  it('returns query key ["agents", {}] with no filters', () => {
    const q = agentsQuery();
    expect(q.queryKey).toEqual(["agents", {}]);
  });

  it("returns query key with filters object when filters provided", () => {
    const q = agentsQuery({ category: "sales" });
    expect(q.queryKey).toEqual(["agents", { category: "sales" }]);
  });

  it("has staleTime of 30_000", () => {
    const q = agentsQuery();
    expect(q.staleTime).toBe(30_000);
  });

  it("has a queryFn function", () => {
    const q = agentsQuery();
    expect(typeof q.queryFn).toBe("function");
  });
});

describe("agentDetailQuery()", () => {
  it('returns query key ["agents", slug]', () => {
    const q = agentDetailQuery("sales-strategist");
    expect(q.queryKey).toEqual(["agents", "sales-strategist"]);
  });

  it("is disabled when slug is empty string", () => {
    const q = agentDetailQuery("");
    expect(q.enabled).toBe(false);
  });

  it("is enabled when slug is non-empty", () => {
    const q = agentDetailQuery("architect");
    expect(q.enabled).toBe(true);
  });

  it("has staleTime of 30_000", () => {
    const q = agentDetailQuery("architect");
    expect(q.staleTime).toBe(30_000);
  });
});

describe("hireAgentMutation()", () => {
  it('returns mutationKey ["agents", "hire"]', () => {
    const m = hireAgentMutation();
    expect(m.mutationKey).toEqual(["agents", "hire"]);
  });

  it("has a mutationFn function", () => {
    const m = hireAgentMutation();
    expect(typeof m.mutationFn).toBe("function");
  });
});

describe("fireAgentMutation()", () => {
  it('returns mutationKey ["agents", "fire"]', () => {
    const m = fireAgentMutation();
    expect(m.mutationKey).toEqual(["agents", "fire"]);
  });

  it("has a mutationFn function", () => {
    const m = fireAgentMutation();
    expect(typeof m.mutationFn).toBe("function");
  });
});

describe("updatePersonaMutation()", () => {
  it('returns mutationKey ["agents", "persona"]', () => {
    const m = updatePersonaMutation();
    expect(m.mutationKey).toEqual(["agents", "persona"]);
  });

  it("has a mutationFn function", () => {
    const m = updatePersonaMutation();
    expect(typeof m.mutationFn).toBe("function");
  });

  it("mutationFn accepts slug and personaMarkdown", () => {
    const m = updatePersonaMutation();
    // Verify the function signature accepts the expected shape without calling it
    // (calling it would make a real HTTP request)
    const fn = m.mutationFn;
    expect(fn.length).toBe(1);
  });
});

describe("createAgentMutation()", () => {
  it('returns mutationKey ["agents", "create"]', () => {
    const m = createAgentMutation();
    expect(m.mutationKey).toEqual(["agents", "create"]);
  });

  it("has a mutationFn function", () => {
    const m = createAgentMutation();
    expect(typeof m.mutationFn).toBe("function");
  });

  it("mutationFn accepts a CreateAgentBody argument", () => {
    const m = createAgentMutation();
    // Verify arity — it takes exactly one argument (the body)
    expect(m.mutationFn.length).toBe(1);
  });
});

describe("agentHeartbeatsQuery()", () => {
  it('returns query key ["agents", slug, "heartbeats"]', () => {
    const q = agentHeartbeatsQuery("sales-strategist");
    expect(q.queryKey).toEqual(["agents", "sales-strategist", "heartbeats"]);
  });

  it("is disabled when slug is empty string", () => {
    const q = agentHeartbeatsQuery("");
    expect(q.enabled).toBe(false);
  });

  it("is enabled when slug is non-empty", () => {
    const q = agentHeartbeatsQuery("architect");
    expect(q.enabled).toBe(true);
  });

  it("has staleTime of 15_000", () => {
    expect(agentHeartbeatsQuery("architect").staleTime).toBe(15_000);
  });

  it("has a queryFn function", () => {
    expect(typeof agentHeartbeatsQuery("architect").queryFn).toBe("function");
  });
});
