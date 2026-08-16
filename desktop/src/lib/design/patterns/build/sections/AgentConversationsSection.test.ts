/**
 * AgentConversationsSection — pure-logic tests.
 *
 * Test environment: Node (no DOM, no Svelte renderer) — same precedent as
 * SearchSection.test.ts and BuildSideRail.test.ts. We test:
 *   - The conversations query factory contract (kind filter, key shape).
 *   - The grouping/filtering helpers used by the section.
 *   - The mutation contract (create + delete).
 */

import { describe, expect, it } from "vitest";
import {
  agentConversationsQuery,
  createAgentConversationMutation,
  deleteAgentConversationMutation,
  isActiveConversation,
  isAgentConversation,
} from "$lib/api/queries/conversations.js";
import type { Session, SessionStatus } from "$lib/domain/sessions/types.js";

// ── Fixtures ──────────────────────────────────────────────────────────────────

function makeSession(over: Partial<Session> = {}): Session {
  const base: Session = {
    id: "s_" + Math.random().toString(36).slice(2, 8),
    status: "running",
    kind: "agent_conversation",
    agentSlug: null,
    runtimeType: "claude-local",
    modelId: null,
    workspaceSlug: "default",
    cwd: "~",
    prompt: null,
    promptBundleKey: null,
    wakeReason: null,
    costUsd: "0",
    inputTokens: 0,
    outputTokens: 0,
    cacheReadTokens: 0,
    cacheWriteTokens: 0,
    startedAt: null,
    completedAt: null,
    parentSessionId: null,
    sequenceNumber: 0,
    externalSessionId: null,
    worktreePath: null,
    branch: null,
    baseBranch: null,
    insertedAt: "2026-04-27T00:00:00Z",
    updatedAt: "2026-04-27T00:00:00Z",
  };
  return { ...base, ...over };
}

// ── agentConversationsQuery factory ──────────────────────────────────────────

describe("agentConversationsQuery()", () => {
  it("uses a conversation-scoped queryKey root", () => {
    const q = agentConversationsQuery();
    expect(q.queryKey[0]).toBe("agent-conversations");
  });

  it("forces kind='agent_conversation' into the filter shape", () => {
    const q = agentConversationsQuery({ workspaceSlug: "ws" });
    expect(q.queryKey[1]).toMatchObject({
      kind: "agent_conversation",
      workspaceSlug: "ws",
    });
  });

  it("defaults limit to 100 when omitted", () => {
    const q = agentConversationsQuery({ workspaceSlug: "ws" });
    expect(q.queryKey[1]).toMatchObject({ limit: 100 });
  });

  it("respects an explicit limit override", () => {
    const q = agentConversationsQuery({ workspaceSlug: "ws", limit: 25 });
    expect(q.queryKey[1]).toMatchObject({ limit: 25 });
  });

  it("threads status through into the underlying filters", () => {
    const q = agentConversationsQuery({
      workspaceSlug: "ws",
      status: "running",
    });
    expect(q.queryKey[1]).toMatchObject({ status: "running" });
  });

  it("inherits a queryFn from sessionsQuery", () => {
    const q = agentConversationsQuery();
    expect(typeof q.queryFn).toBe("function");
  });

  it("queryKey changes identity when workspaceSlug changes", () => {
    const a = agentConversationsQuery({ workspaceSlug: "a" });
    const b = agentConversationsQuery({ workspaceSlug: "b" });
    expect(a.queryKey).not.toEqual(b.queryKey);
  });
});

// ── isAgentConversation guard ────────────────────────────────────────────────

describe("isAgentConversation()", () => {
  it("returns true for agent_conversation rows", () => {
    expect(
      isAgentConversation(makeSession({ kind: "agent_conversation" })),
    ).toBe(true);
  });

  it("returns false for terminal rows", () => {
    expect(isAgentConversation(makeSession({ kind: "terminal" }))).toBe(false);
  });

  it("returns false for legacy rows missing the kind discriminator", () => {
    expect(isAgentConversation(makeSession({ kind: null }))).toBe(false);
  });
});

// ── isActiveConversation grouping logic ──────────────────────────────────────

describe("isActiveConversation()", () => {
  const cases: Array<{ status: SessionStatus; active: boolean }> = [
    { status: "running", active: true },
    { status: "pending", active: true },
    { status: "paused", active: true },
    { status: "completed", active: false },
    { status: "cancelled", active: false },
    { status: "error", active: false },
  ];

  for (const { status, active } of cases) {
    it(`status="${status}" → ${active ? "ACTIVE" : "RECENT"}`, () => {
      expect(isActiveConversation(makeSession({ status }))).toBe(active);
    });
  }
});

// ── Search/filter logic mirrors what the component does ─────────────────────

describe("conversation filter logic", () => {
  function filterConversations(sessions: Session[], needle: string): Session[] {
    const n = needle.trim().toLowerCase();
    if (!n) return sessions;
    return sessions.filter((s) => {
      const title = (s.prompt ?? s.agentSlug ?? s.id).toLowerCase();
      const cwd = (s.cwd ?? "").toLowerCase();
      return title.includes(n) || cwd.includes(n);
    });
  }

  it("returns the whole list when the filter is empty", () => {
    const xs = [makeSession(), makeSession()];
    expect(filterConversations(xs, "")).toHaveLength(2);
  });

  it("matches on the prompt/title", () => {
    const xs = [
      makeSession({ prompt: "fix the bug" }),
      makeSession({ prompt: "ship the feature" }),
    ];
    expect(filterConversations(xs, "BUG")).toHaveLength(1);
  });

  it("matches on the cwd", () => {
    const xs = [
      makeSession({ prompt: "x", cwd: "/repo/desktop" }),
      makeSession({ prompt: "y", cwd: "/repo/backend" }),
    ];
    expect(filterConversations(xs, "backend")).toHaveLength(1);
  });

  it("returns nothing when nothing matches", () => {
    const xs = [makeSession({ prompt: "x" })];
    expect(filterConversations(xs, "zzz")).toHaveLength(0);
  });
});

// ── Mutation factories ───────────────────────────────────────────────────────

describe("createAgentConversationMutation()", () => {
  it("emits a conversation-scoped mutationKey", () => {
    const m = createAgentConversationMutation();
    expect(m.mutationKey).toEqual(["agent-conversations", "create"]);
  });

  it("has a mutationFn function", () => {
    expect(typeof createAgentConversationMutation().mutationFn).toBe(
      "function",
    );
  });
});

describe("deleteAgentConversationMutation()", () => {
  it("emits a conversation-scoped mutationKey", () => {
    const m = deleteAgentConversationMutation();
    expect(m.mutationKey).toEqual(["agent-conversations", "delete"]);
  });

  it("has a mutationFn function", () => {
    expect(typeof deleteAgentConversationMutation().mutationFn).toBe(
      "function",
    );
  });
});

// ── Relative-time formatter logic ────────────────────────────────────────────

describe("relative time formatter", () => {
  function relativeTime(iso: string | null, now: number): string {
    if (!iso) return "";
    const then = new Date(iso).getTime();
    if (Number.isNaN(then)) return "";
    const diff = now - then;
    const m = Math.round(diff / 60000);
    if (m < 1) return "just now";
    if (m < 60) return `${m}m`;
    const h = Math.round(m / 60);
    if (h < 24) return `${h}h`;
    const d = Math.round(h / 24);
    return `${d}d`;
  }

  const NOW = Date.parse("2026-04-27T12:00:00Z");

  it("renders 'just now' for sub-minute deltas", () => {
    expect(relativeTime("2026-04-27T11:59:50Z", NOW)).toBe("just now");
  });

  it("renders minutes when under an hour", () => {
    expect(relativeTime("2026-04-27T11:30:00Z", NOW)).toBe("30m");
  });

  it("renders hours when under a day", () => {
    expect(relativeTime("2026-04-27T03:00:00Z", NOW)).toBe("9h");
  });

  it("renders days for older entries", () => {
    expect(relativeTime("2026-04-22T12:00:00Z", NOW)).toBe("5d");
  });

  it("returns empty string for null", () => {
    expect(relativeTime(null, NOW)).toBe("");
  });
});
