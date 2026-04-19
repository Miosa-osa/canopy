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

// ── New observability widget payloads (Wave 2) ────────────────────────────────

/** Total messages across all sessions. */
export interface TotalMessages {
  count: number;
}

/** Total sessions regardless of status. */
export interface TotalSessions {
  count: number;
}

/** Aggregated token totals from completed sessions. */
export interface TotalTokens {
  total: number;
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
}

/** Success rate over the last 30 days. */
export interface SuccessRate {
  rate: number;
  completed: number;
  failed: number;
}

/** Sandbox VM usage for today. */
export interface SandboxUsageToday {
  started: number;
  stopped: number;
  runningNow: number;
  avgLifetimeMin: number;
}

/** A single tool usage entry. */
export interface TopToolEntry {
  toolName: string | null;
  callCount: number;
}

/** Storage overview across workspaces and files. */
export interface StorageOverview {
  workspaces: number;
  files: number;
  fileBytes: number;
  knowledgeBases: number;
  kbChunks: number;
  buckets: number;
}

/** A single agent's aggregated usage row. */
export interface TopAgentEntry {
  agentSlug: string;
  sessionCount: number;
  totalCostUsd: string;
  avgDurationS: number | null;
}

/** Token usage breakdown for a period. */
export interface TokenUsageByPeriod {
  total: number;
  inputTokens: number;
  outputTokens: number;
  cacheRead: number;
  cacheWrite: number;
}

/** Full dashboard summary — single payload from GET /api/v1/dashboard/summary. */
export interface DashboardSummary {
  activeAgents: ActiveAgent[];
  spendThisMonth: SpendSummary;
  recentSessions: RecentSession[];
  totalMessages: TotalMessages;
  totalSessions: TotalSessions;
  totalTokens: TotalTokens;
  successRate: SuccessRate;
  sandboxUsageToday: SandboxUsageToday;
  topTools30d: TopToolEntry[];
  peakHours30d: number[];
  storageOverview: StorageOverview;
  topAgentsByUsage: TopAgentEntry[];
  tokenUsageByPeriod: TokenUsageByPeriod;
}
