/**
 * Unit tests for case transformation utilities.
 * Verifies bidirectional snake_case ↔ camelCase conversion with nesting.
 */
import { describe, expect, it } from "vitest";

import { toCamel, toSnake } from "../case.js";

// ── toCamel ──────────────────────────────────────────────────────────────────

describe("toCamel()", () => {
  it("converts a flat snake_case object to camelCase", () => {
    expect(
      toCamel({ agent_slug: "dev", runtime_type: "claude-local" }),
    ).toEqual({ agentSlug: "dev", runtimeType: "claude-local" });
  });

  it("converts nested objects recursively", () => {
    expect(
      toCamel({ session_detail: { started_at: "2026-01-01", cost_usd: 0.01 } }),
    ).toEqual({ sessionDetail: { startedAt: "2026-01-01", costUsd: 0.01 } });
  });

  it("converts arrays of objects recursively", () => {
    const input = [{ agent_slug: "a" }, { agent_slug: "b" }];
    expect(toCamel(input)).toEqual([{ agentSlug: "a" }, { agentSlug: "b" }]);
  });

  it("passes through scalar values unchanged", () => {
    expect(toCamel("hello")).toBe("hello");
    expect(toCamel(42)).toBe(42);
    expect(toCamel(null)).toBeNull();
    expect(toCamel(true)).toBe(true);
  });

  it("passes through arrays of scalars unchanged", () => {
    expect(toCamel([1, 2, 3])).toEqual([1, 2, 3]);
  });

  it("handles keys with consecutive underscores (double __)", () => {
    expect(toCamel({ some__key: "v" })).toEqual({ some_Key: "v" });
  });

  it("handles empty object", () => {
    expect(toCamel({})).toEqual({});
  });

  it("handles already-camelCase keys without altering them", () => {
    expect(toCamel({ agentSlug: "x" })).toEqual({ agentSlug: "x" });
  });

  it("converts deeply nested structure", () => {
    const input = {
      top_level: {
        second_level: {
          third_level_key: 99,
        },
      },
    };
    expect(toCamel(input)).toEqual({
      topLevel: {
        secondLevel: {
          thirdLevelKey: 99,
        },
      },
    });
  });
});

// ── toSnake ──────────────────────────────────────────────────────────────────

describe("toSnake()", () => {
  it("converts a flat camelCase object to snake_case", () => {
    expect(toSnake({ agentSlug: "dev", runtimeType: "claude-local" })).toEqual({
      agent_slug: "dev",
      runtime_type: "claude-local",
    });
  });

  it("converts nested objects recursively", () => {
    expect(
      toSnake({ sessionDetail: { startedAt: "2026-01-01", costUsd: 0.01 } }),
    ).toEqual({ session_detail: { started_at: "2026-01-01", cost_usd: 0.01 } });
  });

  it("converts arrays of objects recursively", () => {
    const input = [{ agentSlug: "a" }, { agentSlug: "b" }];
    expect(toSnake(input)).toEqual([{ agent_slug: "a" }, { agent_slug: "b" }]);
  });

  it("passes through scalar values unchanged", () => {
    expect(toSnake("hello")).toBe("hello");
    expect(toSnake(42)).toBe(42);
    expect(toSnake(null)).toBeNull();
    expect(toSnake(true)).toBe(true);
  });

  it("handles empty object", () => {
    expect(toSnake({})).toEqual({});
  });

  it("handles already-snake_case keys without double-underscoring", () => {
    expect(toSnake({ agent_slug: "x" })).toEqual({ agent_slug: "x" });
  });

  it("converts deeply nested structure", () => {
    const input = {
      topLevel: {
        secondLevel: {
          thirdLevelKey: 99,
        },
      },
    };
    expect(toSnake(input)).toEqual({
      top_level: {
        second_level: {
          third_level_key: 99,
        },
      },
    });
  });
});

// ── Roundtrip ────────────────────────────────────────────────────────────────

describe("toCamel → toSnake roundtrip", () => {
  it("roundtrips a realistic session payload", () => {
    const snake = {
      id: "uuid-1",
      agent_slug: "senior-dev",
      runtime_type: "claude-local",
      workspace_slug: "my-ws",
      status: "completed",
      cost_usd: "0.0123",
      started_at: "2026-01-01T00:00:00Z",
      completed_at: "2026-01-01T00:05:00Z",
    };
    expect(toSnake(toCamel(snake))).toEqual(snake);
  });
});
