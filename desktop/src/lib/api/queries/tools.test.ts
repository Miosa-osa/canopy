/**
 * Tests for tools query factories.
 * Verifies query key shapes, enabled flags, and mutation key shapes.
 * Mirrors the agents.test.ts pattern.
 */
import { describe, expect, it } from "vitest";
import { dispatchToolMutation, toolQuery, toolsQuery } from "./tools.js";

describe("toolsQuery()", () => {
  it('returns query key ["tools"]', () => {
    const q = toolsQuery();
    expect(q.queryKey).toEqual(["tools"]);
  });

  it("has staleTime of 60_000", () => {
    expect(toolsQuery().staleTime).toBe(60_000);
  });

  it("has a queryFn function", () => {
    expect(typeof toolsQuery().queryFn).toBe("function");
  });
});

describe("toolQuery()", () => {
  it('returns query key ["tools", name]', () => {
    const q = toolQuery("bash");
    expect(q.queryKey).toEqual(["tools", "bash"]);
  });

  it("is disabled when name is empty string", () => {
    const q = toolQuery("");
    expect(q.enabled).toBe(false);
  });

  it("is enabled when name is non-empty", () => {
    const q = toolQuery("file_read");
    expect(q.enabled).toBe(true);
  });

  it("has staleTime of 60_000", () => {
    expect(toolQuery("bash").staleTime).toBe(60_000);
  });

  it("has a queryFn function", () => {
    expect(typeof toolQuery("bash").queryFn).toBe("function");
  });
});

describe("dispatchToolMutation()", () => {
  it('returns mutationKey ["tools", "dispatch"]', () => {
    const m = dispatchToolMutation();
    expect(m.mutationKey).toEqual(["tools", "dispatch"]);
  });

  it("has a mutationFn function", () => {
    expect(typeof dispatchToolMutation().mutationFn).toBe("function");
  });

  it("mutationFn accepts a single argument ({ name, body })", () => {
    expect(dispatchToolMutation().mutationFn.length).toBe(1);
  });
});
