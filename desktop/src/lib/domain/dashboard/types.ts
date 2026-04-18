/**
 * Dashboard domain types — matches the Elixir backend at /api/v1/dashboard/summary.
 * All three widgets are returned in a single response object.
 */

/** A single agent with an active (running) session. */
export interface ActiveAgent {
  agentSlug: string | null;
  currentSessionId: string;
  startedAt: string;
  /** Latest transcript entry kind, e.g. "assistant" | "tool_call" etc. */
  latestEntryKind: string | null;
}

/** Per-agent cost breakdown for the current month. */
export interface SpendByAgent {
  agentSlug: string;
  costUsd: string;
}

/** Per-runtime cost breakdown for the current month. */
export interface SpendByRuntime {
  runtimeType: string;
  costUsd: string;
}

/** Monthly spend totals. */
export interface SpendSummary {
  totalUsd: string;
  byAgent: SpendByAgent[];
  byRuntime: SpendByRuntime[];
}

/** Minimal session row shown in the Recent Sessions widget. */
export interface RecentSession {
  id: string;
  agentSlug: string | null;
  runtimeType: string;
  status: string;
  insertedAt: string;
  completedAt: string | null;
}

/** Full dashboard summary — single payload from GET /api/v1/dashboard/summary. */
export interface DashboardSummary {
  activeAgents: ActiveAgent[];
  spendThisMonth: SpendSummary;
  recentSessions: RecentSession[];
}
