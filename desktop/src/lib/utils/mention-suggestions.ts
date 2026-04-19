/**
 * mention-suggestions.ts — shared mention resolver for TiptapEditor and MentionInput.
 *
 * Exports:
 *   MentionCategory, MentionItem — domain types
 *   fuzzyScore()                 — 4-tier fuzzy scoring (prefix=4, word-boundary=3, contains=2, subsequence=1)
 *   scoreAndFilter()             — scored + sliced filter over any item array
 *   buildMentionResults()        — aggregates agents/workspaces/tasks/channels into a flat MentionItem list
 *   extractMentions()            — extracts @slug strings compatible with backend regex ~r/(?:^|\s)@([a-z0-9-]+)/
 *
 * NOT a Svelte component — pure TypeScript, safe to import in tests without jsdom.
 */

import type { Agent } from "$lib/domain/agents/types.js";
import type { Workspace } from "$lib/domain/workspaces/types.js";
import type { Task } from "$lib/domain/tasks/types.js";
import type { Channel } from "$lib/domain/channels/types.js";

// ── Types ─────────────────────────────────────────────────────────────────────

export type MentionCategory = "agents" | "workspaces" | "tasks" | "channels";

export interface MentionItem {
  id: string;
  slug: string;
  label: string;
  sublabel: string;
  category: MentionCategory;
  emoji?: string;
  taskStatus?: Task["status"];
}

// ── Fuzzy scoring ─────────────────────────────────────────────────────────────

/** 4-tier fuzzy score. Returns 0 when no match. */
export function fuzzyScore(text: string, q: string): number {
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

export function scoreAndFilter<T>(
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

// ── Category aggregation ──────────────────────────────────────────────────────

export function buildMentionResults(
  q: string,
  allAgents: Agent[],
  allWorkspaces: Workspace[],
  allTasks: Task[],
  allChannels: Channel[],
): MentionItem[] {
  const agentItems = scoreAndFilter(
    allAgents,
    (a) => `${a.name} ${a.slug}`,
    q,
    3,
  ).map(({ item: a }) => ({
    id: a.slug,
    slug: a.slug,
    label: a.name,
    sublabel: a.title,
    category: "agents" as const,
    emoji: a.emoji,
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
    sublabel: w.slug,
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
    sublabel: t.title.length > 40 ? t.title.slice(0, 40) + "…" : t.title,
    category: "tasks" as const,
    taskStatus: t.status,
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
    sublabel: c.slug,
    category: "channels" as const,
    emoji: c.icon ?? "#",
  }));

  return [...agentItems, ...wsItems, ...taskItems, ...channelItems].slice(
    0,
    10,
  );
}

// ── Mention extraction ────────────────────────────────────────────────────────

/** Extracts @slug strings compatible with backend regex ~r/(?:^|\s)@([a-z0-9-]+)/ */
export function extractMentions(text: string): string[] {
  const matches = text.matchAll(/(?:^|\s)@([a-z0-9-]+)/g);
  return Array.from(matches, (m) => m[1]);
}
