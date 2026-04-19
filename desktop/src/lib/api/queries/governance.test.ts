/**
 * Tests for governance query + mutation factory shapes.
 * Verifies query key structure, staleTime, and mutationFn arity.
 * Logic tests: rule priority sort, action badge color mapping, condition-builder transitions.
 */
import { describe, expect, it } from "vitest";
import type { Rule, RuleAction } from "$lib/domain/governance/types.js";
import {
  approveApprovalMutation,
  approvalsQuery,
  auditQuery,
  createRuleMutation,
  deleteRuleMutation,
  rejectApprovalMutation,
  rulesQuery,
  updateRuleMutation,
} from "./governance.js";

// ── Query factories ───────────────────────────────────────────────────────────

describe("rulesQuery()", () => {
  it('returns queryKey ["governance", "rules"]', () => {
    const q = rulesQuery();
    expect(q.queryKey).toEqual(["governance", "rules"]);
  });

  it("has staleTime of 30_000", () => {
    const q = rulesQuery();
    expect(q.staleTime).toBe(30_000);
  });

  it("has a queryFn function", () => {
    const q = rulesQuery();
    expect(typeof q.queryFn).toBe("function");
  });
});

describe("approvalsQuery()", () => {
  it('returns queryKey ["governance", "approvals", "all"] with no status', () => {
    const q = approvalsQuery();
    expect(q.queryKey).toEqual(["governance", "approvals", "all"]);
  });

  it("returns queryKey with status when provided", () => {
    const q = approvalsQuery("pending");
    expect(q.queryKey).toEqual(["governance", "approvals", "pending"]);
  });

  it("has staleTime of 10_000", () => {
    const q = approvalsQuery();
    expect(q.staleTime).toBe(10_000);
  });

  it("has a queryFn function", () => {
    const q = approvalsQuery("approved");
    expect(typeof q.queryFn).toBe("function");
  });
});

describe("auditQuery()", () => {
  it('returns queryKey ["governance", "audit", {}] with no filters', () => {
    const q = auditQuery();
    expect(q.queryKey).toEqual(["governance", "audit", {}]);
  });

  it("returns queryKey with filters object when filters provided", () => {
    const filters = { event_type: "rule_triggered" };
    const q = auditQuery(filters);
    expect(q.queryKey).toEqual(["governance", "audit", filters]);
  });

  it("has staleTime of 30_000", () => {
    const q = auditQuery();
    expect(q.staleTime).toBe(30_000);
  });
});

// ── Mutation factories ────────────────────────────────────────────────────────

describe("createRuleMutation()", () => {
  it('returns mutationKey ["governance", "rules", "create"]', () => {
    const m = createRuleMutation();
    expect(m.mutationKey).toEqual(["governance", "rules", "create"]);
  });

  it("has a mutationFn function", () => {
    const m = createRuleMutation();
    expect(typeof m.mutationFn).toBe("function");
  });

  it("mutationFn takes one argument (body)", () => {
    const m = createRuleMutation();
    expect(m.mutationFn.length).toBe(1);
  });
});

describe("updateRuleMutation()", () => {
  it('returns mutationKey ["governance", "rules", "update"]', () => {
    const m = updateRuleMutation();
    expect(m.mutationKey).toEqual(["governance", "rules", "update"]);
  });

  it("has a mutationFn function", () => {
    const m = updateRuleMutation();
    expect(typeof m.mutationFn).toBe("function");
  });

  it("mutationFn takes one argument ({ id, body })", () => {
    const m = updateRuleMutation();
    expect(m.mutationFn.length).toBe(1);
  });
});

describe("deleteRuleMutation()", () => {
  it('returns mutationKey ["governance", "rules", "delete"]', () => {
    const m = deleteRuleMutation();
    expect(m.mutationKey).toEqual(["governance", "rules", "delete"]);
  });

  it("has a mutationFn function", () => {
    const m = deleteRuleMutation();
    expect(typeof m.mutationFn).toBe("function");
  });
});

describe("approveApprovalMutation()", () => {
  it('returns mutationKey ["governance", "approvals", "approve"]', () => {
    const m = approveApprovalMutation();
    expect(m.mutationKey).toEqual(["governance", "approvals", "approve"]);
  });

  it("has a mutationFn function", () => {
    const m = approveApprovalMutation();
    expect(typeof m.mutationFn).toBe("function");
  });
});

describe("rejectApprovalMutation()", () => {
  it('returns mutationKey ["governance", "approvals", "reject"]', () => {
    const m = rejectApprovalMutation();
    expect(m.mutationKey).toEqual(["governance", "approvals", "reject"]);
  });

  it("has a mutationFn function", () => {
    const m = rejectApprovalMutation();
    expect(typeof m.mutationFn).toBe("function");
  });
});

// ── Logic: rule priority sort ─────────────────────────────────────────────────

describe("rule priority sort (DESC)", () => {
  const rules: Pick<Rule, "id" | "priority" | "name">[] = [
    { id: "a", priority: 1, name: "Low" },
    { id: "b", priority: 100, name: "High" },
    { id: "c", priority: 50, name: "Mid" },
  ];

  it("sorts rules by priority descending", () => {
    const sorted = [...rules].sort((a, b) => b.priority - a.priority);
    expect(sorted.map((r) => r.id)).toEqual(["b", "c", "a"]);
  });

  it("puts the highest priority rule first", () => {
    const sorted = [...rules].sort((a, b) => b.priority - a.priority);
    expect(sorted[0].priority).toBe(100);
  });
});

// ── Logic: action badge color mapping ────────────────────────────────────────

type ActionColorMap = Record<RuleAction, string>;

const ACTION_COLORS: ActionColorMap = {
  block: "var(--signal-error)",
  require_approval: "var(--signal-warn)",
  warn: "var(--signal-warn)",
  log: "var(--fg-muted)",
};

describe("action badge color mapping", () => {
  it('maps "block" to --signal-error', () => {
    expect(ACTION_COLORS["block"]).toBe("var(--signal-error)");
  });

  it('maps "require_approval" to --signal-warn', () => {
    expect(ACTION_COLORS["require_approval"]).toBe("var(--signal-warn)");
  });

  it('maps "warn" to --signal-warn', () => {
    expect(ACTION_COLORS["warn"]).toBe("var(--signal-warn)");
  });

  it('maps "log" to --fg-muted', () => {
    expect(ACTION_COLORS["log"]).toBe("var(--fg-muted)");
  });

  it("covers all 4 RuleAction values", () => {
    const actions: RuleAction[] = ["block", "require_approval", "warn", "log"];
    for (const action of actions) {
      expect(ACTION_COLORS[action]).toBeDefined();
    }
  });
});

// ── Logic: condition-builder state transitions ────────────────────────────────

describe("condition-builder state transitions", () => {
  type ConditionDraft = { type: string; value: string };

  function addCondition(conditions: ConditionDraft[]): ConditionDraft[] {
    return [...conditions, { type: "runtime", value: "" }];
  }

  function removeCondition(
    conditions: ConditionDraft[],
    index: number,
  ): ConditionDraft[] {
    return conditions.filter((_, i) => i !== index);
  }

  function updateCondition(
    conditions: ConditionDraft[],
    index: number,
    patch: Partial<ConditionDraft>,
  ): ConditionDraft[] {
    return conditions.map((c, i) => (i === index ? { ...c, ...patch } : c));
  }

  it("addCondition appends a blank runtime condition", () => {
    const result = addCondition([]);
    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({ type: "runtime", value: "" });
  });

  it("addCondition preserves existing conditions", () => {
    const existing = [{ type: "agent_slug", value: "sales-bot" }];
    const result = addCondition(existing);
    expect(result).toHaveLength(2);
    expect(result[0]).toEqual(existing[0]);
  });

  it("removeCondition removes the condition at the given index", () => {
    const conditions = [
      { type: "runtime", value: "claude" },
      { type: "agent_slug", value: "bot" },
      { type: "cost_over", value: "5.00" },
    ];
    const result = removeCondition(conditions, 1);
    expect(result).toHaveLength(2);
    expect(result[0].type).toBe("runtime");
    expect(result[1].type).toBe("cost_over");
  });

  it("removeCondition on last item returns empty array", () => {
    const result = removeCondition([{ type: "runtime", value: "claude" }], 0);
    expect(result).toHaveLength(0);
  });

  it("updateCondition updates only the target index", () => {
    const conditions = [
      { type: "runtime", value: "claude" },
      { type: "agent_slug", value: "" },
    ];
    const result = updateCondition(conditions, 1, { value: "sales-bot" });
    expect(result[0]).toEqual({ type: "runtime", value: "claude" });
    expect(result[1]).toEqual({ type: "agent_slug", value: "sales-bot" });
  });

  it("updateCondition can change condition type", () => {
    const conditions = [{ type: "runtime", value: "claude" }];
    const result = updateCondition(conditions, 0, {
      type: "cost_over",
      value: "10.00",
    });
    expect(result[0].type).toBe("cost_over");
    expect(result[0].value).toBe("10.00");
  });
});
