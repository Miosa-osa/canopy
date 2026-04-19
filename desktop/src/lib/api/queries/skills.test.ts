/**
 * Tests for skills query factories.
 * Verifies query key shapes, filter wiring, enabled flags, and mutation key shapes.
 * Mirrors the agents.test.ts pattern.
 */
import { describe, expect, it } from "vitest";
import {
  importSkillMutation,
  skillQuery,
  skillsQuery,
  updateSkillMutation,
} from "./skills.js";

describe("skillsQuery()", () => {
  it('returns query key ["skills", {}] with no filters', () => {
    const q = skillsQuery();
    expect(q.queryKey).toEqual(["skills", {}]);
  });

  it("returns query key with filters object when filters provided", () => {
    const q = skillsQuery({ source: "clawhub" });
    expect(q.queryKey).toEqual(["skills", { source: "clawhub" }]);
  });

  it("includes enabled flag in query key", () => {
    const q = skillsQuery({ enabled: true });
    expect(q.queryKey).toEqual(["skills", { enabled: true }]);
  });

  it("includes tag filter in query key", () => {
    const q = skillsQuery({ tag: "coding" });
    expect(q.queryKey).toEqual(["skills", { tag: "coding" }]);
  });

  it("has staleTime of 30_000", () => {
    expect(skillsQuery().staleTime).toBe(30_000);
  });

  it("has a queryFn function", () => {
    expect(typeof skillsQuery().queryFn).toBe("function");
  });
});

describe("skillQuery()", () => {
  it('returns query key ["skills", slug]', () => {
    const q = skillQuery("systematic-debugging");
    expect(q.queryKey).toEqual(["skills", "systematic-debugging"]);
  });

  it("is disabled when slug is empty string", () => {
    const q = skillQuery("");
    expect(q.enabled).toBe(false);
  });

  it("is enabled when slug is non-empty", () => {
    const q = skillQuery("coding-workflow");
    expect(q.enabled).toBe(true);
  });

  it("has staleTime of 30_000", () => {
    expect(skillQuery("coding-workflow").staleTime).toBe(30_000);
  });
});

describe("importSkillMutation()", () => {
  it('returns mutationKey ["skills", "import"]', () => {
    const m = importSkillMutation();
    expect(m.mutationKey).toEqual(["skills", "import"]);
  });

  it("has a mutationFn function", () => {
    expect(typeof importSkillMutation().mutationFn).toBe("function");
  });

  it("mutationFn accepts a single body argument", () => {
    expect(importSkillMutation().mutationFn.length).toBe(1);
  });
});

describe("updateSkillMutation()", () => {
  it('returns mutationKey ["skills", "update"]', () => {
    const m = updateSkillMutation();
    expect(m.mutationKey).toEqual(["skills", "update"]);
  });

  it("has a mutationFn function", () => {
    expect(typeof updateSkillMutation().mutationFn).toBe("function");
  });

  it("mutationFn accepts a single argument (slug + body shape)", () => {
    expect(updateSkillMutation().mutationFn.length).toBe(1);
  });
});
