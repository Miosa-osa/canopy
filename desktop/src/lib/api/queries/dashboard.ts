/**
 * TanStack Query factories for the /dashboard resource.
 * Single endpoint — GET /api/v1/dashboard/summary returns all 3 widget payloads.
 */

import { apiGet } from "$lib/api/client.js";
import type { DashboardSummary } from "$lib/domain/dashboard/types.js";

// ── Raw API types (snake_case from Phoenix) ──────────────────────────────────

interface RawActiveAgent {
  agent_slug: string | null;
  current_session_id: string;
  started_at: string;
  latest_entry_kind: string | null;
}

interface RawSpendByAgent {
  agent_slug: string;
  cost_usd: string;
}

interface RawSpendByRuntime {
  runtime_type: string;
  cost_usd: string;
}

interface RawSpendSummary {
  total_usd: string;
  by_agent: RawSpendByAgent[];
  by_runtime: RawSpendByRuntime[];
}

interface RawRecentSession {
  id: string;
  agent_slug: string | null;
  runtime_type: string;
  status: string;
  inserted_at: string;
  completed_at: string | null;
}

interface RawTopToolEntry {
  tool_name: string | null;
  call_count: number;
}

interface RawTopAgentEntry {
  agent_slug: string;
  session_count: number;
  total_cost_usd: string;
  avg_duration_s: number | null;
}

interface RawDashboardSummary {
  active_agents: RawActiveAgent[];
  spend_this_month: RawSpendSummary;
  recent_sessions: RawRecentSession[];
  total_messages: { count: number };
  total_sessions: { count: number };
  total_tokens: {
    total: number;
    input: number;
    output: number;
    cache_read: number;
    cache_write: number;
  };
  success_rate: { rate: number; completed: number; failed: number };
  sandbox_usage_today: {
    started: number;
    stopped: number;
    running_now: number;
    avg_lifetime_min: number;
  };
  top_tools_30d: RawTopToolEntry[];
  peak_hours_30d: number[];
  storage_overview: {
    workspaces: number;
    files: number;
    file_bytes: number;
    knowledge_bases: number;
    kb_chunks: number;
    buckets: number;
  };
  top_agents_by_usage: RawTopAgentEntry[];
  token_usage_by_period: {
    total: number;
    input_tokens: number;
    output_tokens: number;
    cache_read: number;
    cache_write: number;
  };
}

// ── Camel-case transformer ────────────────────────────────────────────────────

function transformSummary(raw: RawDashboardSummary): DashboardSummary {
  return {
    activeAgents: raw.active_agents.map((a) => ({
      agentSlug: a.agent_slug,
      currentSessionId: a.current_session_id,
      startedAt: a.started_at,
      latestEntryKind: a.latest_entry_kind,
    })),
    spendThisMonth: {
      totalUsd: raw.spend_this_month.total_usd,
      byAgent: raw.spend_this_month.by_agent.map((b) => ({
        agentSlug: b.agent_slug,
        costUsd: b.cost_usd,
      })),
      byRuntime: (raw.spend_this_month.by_runtime ?? []).map((r) => ({
        runtimeType: r.runtime_type,
        costUsd: r.cost_usd,
      })),
    },
    recentSessions: raw.recent_sessions.map((s) => ({
      id: s.id,
      agentSlug: s.agent_slug,
      runtimeType: s.runtime_type,
      status: s.status,
      insertedAt: s.inserted_at,
      completedAt: s.completed_at,
    })),
    totalMessages: raw.total_messages ?? { count: 0 },
    totalSessions: raw.total_sessions ?? { count: 0 },
    totalTokens: {
      total: raw.total_tokens?.total ?? 0,
      input: raw.total_tokens?.input ?? 0,
      output: raw.total_tokens?.output ?? 0,
      cacheRead: raw.total_tokens?.cache_read ?? 0,
      cacheWrite: raw.total_tokens?.cache_write ?? 0,
    },
    successRate: {
      rate: raw.success_rate?.rate ?? 0,
      completed: raw.success_rate?.completed ?? 0,
      failed: raw.success_rate?.failed ?? 0,
    },
    sandboxUsageToday: {
      started: raw.sandbox_usage_today?.started ?? 0,
      stopped: raw.sandbox_usage_today?.stopped ?? 0,
      runningNow: raw.sandbox_usage_today?.running_now ?? 0,
      avgLifetimeMin: raw.sandbox_usage_today?.avg_lifetime_min ?? 0,
    },
    topTools30d: (raw.top_tools_30d ?? []).map((t) => ({
      toolName: t.tool_name,
      callCount: t.call_count,
    })),
    peakHours30d: raw.peak_hours_30d ?? Array(24).fill(0),
    storageOverview: {
      workspaces: raw.storage_overview?.workspaces ?? 0,
      files: raw.storage_overview?.files ?? 0,
      fileBytes: raw.storage_overview?.file_bytes ?? 0,
      knowledgeBases: raw.storage_overview?.knowledge_bases ?? 0,
      kbChunks: raw.storage_overview?.kb_chunks ?? 0,
      buckets: raw.storage_overview?.buckets ?? 0,
    },
    topAgentsByUsage: (raw.top_agents_by_usage ?? []).map((a) => ({
      agentSlug: a.agent_slug,
      sessionCount: a.session_count,
      totalCostUsd: a.total_cost_usd,
      avgDurationS: a.avg_duration_s,
    })),
    tokenUsageByPeriod: {
      total: raw.token_usage_by_period?.total ?? 0,
      inputTokens: raw.token_usage_by_period?.input_tokens ?? 0,
      outputTokens: raw.token_usage_by_period?.output_tokens ?? 0,
      cacheRead: raw.token_usage_by_period?.cache_read ?? 0,
      cacheWrite: raw.token_usage_by_period?.cache_write ?? 0,
    },
  };
}

// ── Raw API call ─────────────────────────────────────────────────────────────

export async function getDashboardSummary(): Promise<DashboardSummary> {
  const raw = await apiGet<RawDashboardSummary>("/dashboard/summary");
  return transformSummary(raw);
}

// ── TanStack Query option factory ────────────────────────────────────────────

/**
 * Query options for the dashboard summary.
 * staleTime: 30s. refetchOnWindowFocus: true (overrides the global false default).
 */
export function dashboardSummaryQuery() {
  return {
    queryKey: ["dashboard", "summary"] as const,
    queryFn: getDashboardSummary,
    staleTime: 30_000,
    refetchOnWindowFocus: true,
  };
}
