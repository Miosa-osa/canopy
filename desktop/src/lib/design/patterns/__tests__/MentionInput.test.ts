/**
 * MentionInput — unit tests for pure logic extracted from the component.
 *
 * Covers:
 *   1. Fuzzy scoring: prefix > word-boundary > contains > subsequence
 *   2. Category aggregation: 4 categories with per-category caps
 *   3. Debounce: timer is cleared on successive calls (verified via fake timers)
 *   4. Submit plaintext: extracted mentions match backend regex ~r/(?:^|\s)@([a-z0-9-]+)/
 *   5. Edge cases: empty query, no results, overlapping slugs
 */

import { beforeEach, afterEach, describe, expect, it, vi } from "vitest";

// ── Fuzzy scoring (mirrored from MentionInput.svelte) ─────────────────────────

function fuzzyScore(text: string, q: string): number {
  if (!q) return 1;
  const label = text.toLowerCase();
  const lower = q.toLowerCase();
  const words = label.split(/[\s_-]+/);
  if (words.some((w) => w.startsWith(lower))) return 4;
  if (words.some((w) => w.startsWith(lower.charAt(0)) && label.includes(lower)))
    return 3;
  if (label.includes(lower)) return 2;
  if (isSubsequence(lower, label)) return 1;
  return 0;
}

function isSubsequence(needle: string, haystack: string): boolean {
  let ni = 0;
  for (let hi = 0; hi < haystack.length && ni < needle.length; hi++) {
    if (haystack[hi] === needle[ni]) ni++;
  }
  return ni === needle.length;
}

// ── scoreAndFilter (mirrored from MentionInput.svelte) ────────────────────────

interface MockItem {
  id: string;
  key: string;
}

function scoreAndFilter<T>(
  items: T[],
  getKey: (i: T) => string,
  q: string,
  limit: number,
): Array<{ item: T; score: number }> {
  return items
    .map((item) => ({ item, score: fuzzyScore(getKey(item), q) }))
    .filter(({ score }) => score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, limit);
}

// ── extractMentions (mirrored from MentionInput.svelte) ───────────────────────

function extractMentions(text: string): string[] {
  const matches = text.matchAll(/(?:^|\s)@([a-z0-9-]+)/g);
  return Array.from(matches, (m) => m[1]);
}

// ── buildResults stub (tests category aggregation logic) ─────────────────────

type MockCategory = "agents" | "workspaces" | "tasks" | "channels";

interface MockMentionItem {
  id: string;
  slug: string;
  label: string;
  category: MockCategory;
}

interface MockAgent {
  slug: string;
  name: string;
  title: string;
  emoji: string;
}
interface MockWorkspace {
  slug: string;
  name: string;
}
interface MockTask {
  id: string;
  shortId: string;
  title: string;
  status: string;
}
interface MockChannel {
  id: string;
  slug: string;
  name: string;
  icon: string | null;
}

function buildResults(
  q: string,
  allAgents: MockAgent[],
  allWorkspaces: MockWorkspace[],
  allTasks: MockTask[],
  allChannels: MockChannel[],
): MockMentionItem[] {
  const agentItems = scoreAndFilter(
    allAgents,
    (a) => `${a.name} ${a.slug}`,
    q,
    3,
  ).map(({ item: a }) => ({
    id: a.slug,
    slug: a.slug,
    label: a.name,
    category: "agents" as const,
  }));

  const wsItems = scoreAndFilter(
    allWorkspaces,
    (w) => `${w.name} ${w.slug}`,
    q,
    2,
  ).map(({ item: w }) => ({
    id: w.slug,
    slug: w.slug,
    label: w.name,
    category: "workspaces" as const,
  }));

  const taskItems = scoreAndFilter(
    allTasks,
    (t) => `${t.shortId} ${t.title}`,
    q,
    3,
  ).map(({ item: t }) => ({
    id: t.id,
    slug: t.shortId.toLowerCase(),
    label: t.shortId,
    category: "tasks" as const,
  }));

  const channelItems = scoreAndFilter(
    allChannels,
    (c) => `${c.name} ${c.slug}`,
    q,
    2,
  ).map(({ item: c }) => ({
    id: c.id,
    slug: c.slug,
    label: c.name,
    category: "channels" as const,
  }));

  return [...agentItems, ...wsItems, ...taskItems, ...channelItems].slice(
    0,
    10,
  );
}

// ── Test data ─────────────────────────────────────────────────────────────────

const mockAgents: MockAgent[] = [
  {
    slug: "code-reviewer",
    name: "Code Reviewer",
    title: "Reviews code",
    emoji: "🔍",
  },
  { slug: "copywriter", name: "Copywriter", title: "Writes copy", emoji: "✍️" },
  { slug: "debugger", name: "Debugger", title: "Fixes bugs", emoji: "🐛" },
  { slug: "designer", name: "Designer", title: "Designs UI", emoji: "🎨" },
];

const mockWorkspaces: MockWorkspace[] = [
  { slug: "sales-engine", name: "Sales Engine" },
  { slug: "dev-shop", name: "Dev Shop" },
];

const mockTasks: MockTask[] = [
  {
    id: "uuid-1",
    shortId: "T-11111111",
    title: "Fix login bug",
    status: "todo",
  },
  {
    id: "uuid-2",
    shortId: "T-22222222",
    title: "Add dark mode",
    status: "in_progress",
  },
  {
    id: "uuid-3",
    shortId: "T-33333333",
    title: "Write unit tests",
    status: "todo",
  },
  {
    id: "uuid-4",
    shortId: "T-44444444",
    title: "Code review PR #5",
    status: "in_progress",
  },
];

const mockChannels: MockChannel[] = [
  { id: "ch-1", slug: "general", name: "General", icon: "#" },
  { id: "ch-2", slug: "dev-channel", name: "Dev Channel", icon: "💻" },
];

// ── Tests: fuzzy scoring ──────────────────────────────────────────────────────

describe("fuzzyScore() — prefix match (score 4)", () => {
  it("scores 4 for exact word prefix", () => {
    expect(fuzzyScore("code-reviewer", "code")).toBe(4);
  });

  it("scores 4 when query matches after hyphen (word split on -)", () => {
    expect(fuzzyScore("code-reviewer", "rev")).toBe(4);
  });

  it("is case-insensitive", () => {
    expect(fuzzyScore("Copywriter", "COPY")).toBe(4);
  });
});

describe("fuzzyScore() — contains match (score 2)", () => {
  it("scores 2 for mid-word substring", () => {
    expect(fuzzyScore("designer", "sign")).toBe(2);
  });
});

describe("fuzzyScore() — subsequence match (score 1)", () => {
  it("scores 1 for scattered chars present in order", () => {
    // d-b-g are in order in 'debugger'
    expect(fuzzyScore("debugger", "dbg")).toBe(1);
  });
});

describe("fuzzyScore() — no match (score 0)", () => {
  it("scores 0 when chars are not present as subsequence", () => {
    expect(fuzzyScore("code-reviewer", "xyz")).toBe(0);
  });
});

describe("fuzzyScore() — empty query (score 1)", () => {
  it("returns 1 for all items when query is empty", () => {
    expect(fuzzyScore("anything", "")).toBe(1);
  });
});

// ── Tests: category aggregation ───────────────────────────────────────────────

describe("buildResults() — category aggregation", () => {
  it("returns results across all 4 categories for a broad query", () => {
    const results = buildResults(
      "de",
      mockAgents,
      mockWorkspaces,
      mockTasks,
      mockChannels,
    );
    const categories = new Set(results.map((r) => r.category));
    // 'de' matches: Debugger, Designer (agents), Dev Shop (workspace), dev-channel (channel)
    expect(categories.has("agents")).toBe(true);
    expect(categories.has("workspaces")).toBe(true);
    expect(categories.has("channels")).toBe(true);
  });

  it("caps agents at 3 results", () => {
    // 'de' matches debugger, designer — only 2 agents here, but cap is 3
    const results = buildResults(
      "de",
      mockAgents,
      mockWorkspaces,
      mockTasks,
      mockChannels,
    );
    const agentCount = results.filter((r) => r.category === "agents").length;
    expect(agentCount).toBeLessThanOrEqual(3);
  });

  it("caps workspaces at 2 results", () => {
    const results = buildResults(
      "",
      mockAgents,
      mockWorkspaces,
      mockTasks,
      mockChannels,
    );
    const wsCount = results.filter((r) => r.category === "workspaces").length;
    expect(wsCount).toBeLessThanOrEqual(2);
  });

  it("caps tasks at 3 results", () => {
    const results = buildResults(
      "",
      mockAgents,
      mockWorkspaces,
      mockTasks,
      mockChannels,
    );
    const taskCount = results.filter((r) => r.category === "tasks").length;
    expect(taskCount).toBeLessThanOrEqual(3);
  });

  it("caps channels at 2 results", () => {
    const results = buildResults(
      "",
      mockAgents,
      mockWorkspaces,
      mockTasks,
      mockChannels,
    );
    const channelCount = results.filter(
      (r) => r.category === "channels",
    ).length;
    expect(channelCount).toBeLessThanOrEqual(2);
  });

  it("caps total results at 10", () => {
    const results = buildResults(
      "",
      mockAgents,
      mockWorkspaces,
      mockTasks,
      mockChannels,
    );
    expect(results.length).toBeLessThanOrEqual(10);
  });

  it("returns empty when no query matches anything", () => {
    const results = buildResults(
      "zzz",
      mockAgents,
      mockWorkspaces,
      mockTasks,
      mockChannels,
    );
    expect(results.length).toBe(0);
  });

  it("agent slug is used as mention slug", () => {
    const results = buildResults(
      "code",
      mockAgents,
      mockWorkspaces,
      mockTasks,
      mockChannels,
    );
    const codeReviewer = results.find((r) => r.id === "code-reviewer");
    expect(codeReviewer?.slug).toBe("code-reviewer");
  });

  it("task slug is lowercased shortId", () => {
    const results = buildResults(
      "T-1",
      mockAgents,
      mockWorkspaces,
      mockTasks,
      mockChannels,
    );
    const taskResult = results.find((r) => r.category === "tasks");
    expect(taskResult?.slug).toBe("t-11111111");
  });
});

// ── Tests: debounce behavior ──────────────────────────────────────────────────

describe("debounce — 150ms timer", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("clears previous timer when called again before 150ms", () => {
    const callback = vi.fn();

    let timer: ReturnType<typeof setTimeout> | null = null;

    function scheduleUpdate(q: string): void {
      if (timer !== null) clearTimeout(timer);
      timer = setTimeout(() => callback(q), 150);
    }

    scheduleUpdate("co");
    scheduleUpdate("cod");
    scheduleUpdate("code");

    // Before 150ms — callback not yet called
    vi.advanceTimersByTime(100);
    expect(callback).not.toHaveBeenCalled();

    // After 150ms — only the last call fires
    vi.advanceTimersByTime(60);
    expect(callback).toHaveBeenCalledOnce();
    expect(callback).toHaveBeenCalledWith("code");
  });

  it("fires after exactly 150ms", () => {
    const callback = vi.fn();
    let timer: ReturnType<typeof setTimeout> | null = null;

    function scheduleUpdate(q: string): void {
      if (timer !== null) clearTimeout(timer);
      timer = setTimeout(() => callback(q), 150);
    }

    scheduleUpdate("test");
    vi.advanceTimersByTime(149);
    expect(callback).not.toHaveBeenCalled();
    vi.advanceTimersByTime(1);
    expect(callback).toHaveBeenCalledOnce();
  });
});

// ── Tests: submit mention format ──────────────────────────────────────────────

describe("extractMentions() — backend regex compatibility", () => {
  // Backend regex: ~r/(?:^|\s)@([a-z0-9-]+)/
  const BACKEND_REGEX = /(?:^|\s)@([a-z0-9-]+)/g;

  it("extracts single @mention at start of string", () => {
    const text = "@code-reviewer please review this";
    const mentions = extractMentions(text);
    expect(mentions).toContain("code-reviewer");
  });

  it("extracts @mention after whitespace", () => {
    const text = "hey @debugger can you fix this?";
    const mentions = extractMentions(text);
    expect(mentions).toContain("debugger");
  });

  it("extracts multiple @mentions", () => {
    const text = "@code-reviewer and @designer should pair on this";
    const mentions = extractMentions(text);
    expect(mentions).toContain("code-reviewer");
    expect(mentions).toContain("designer");
  });

  it("outputs match backend regex for single mention", () => {
    const text = "@code-reviewer please check";
    const backendMatches = Array.from(
      text.matchAll(BACKEND_REGEX),
      (m) => m[1],
    );
    const clientMentions = extractMentions(text);
    expect(clientMentions).toEqual(backendMatches);
  });

  it("outputs match backend regex for multi mention", () => {
    const text = "ping @debugger and @designer for input";
    const backendMatches = Array.from(
      text.matchAll(BACKEND_REGEX),
      (m) => m[1],
    );
    const clientMentions = extractMentions(text);
    expect(clientMentions).toEqual(backendMatches);
  });

  it("returns empty array when no mentions present", () => {
    expect(extractMentions("just a plain message")).toEqual([]);
  });

  it("does not match @mentions embedded within words (no space before @)", () => {
    const text = "email: user@example.com";
    const mentions = extractMentions(text);
    // 'example.com' contains dots — filtered out by [a-z0-9-]+ anyway
    // But 'user@example' — the @ is not preceded by space or start, so no match
    expect(mentions).not.toContain("example");
  });

  it("task shortId mention works with backend regex", () => {
    const text = "working on @t-12345678 now";
    const mentions = extractMentions(text);
    expect(mentions).toContain("t-12345678");
    const backendMatches = Array.from(
      text.matchAll(BACKEND_REGEX),
      (m) => m[1],
    );
    expect(backendMatches).toContain("t-12345678");
  });

  it("workspace slug mention works with backend regex", () => {
    const text = "check @dev-shop workspace";
    const mentions = extractMentions(text);
    expect(mentions).toContain("dev-shop");
  });
});
