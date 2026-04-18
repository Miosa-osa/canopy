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

interface RawDashboardSummary {
  active_agents: RawActiveAgent[];
  spend_this_month: RawSpendSummary;
  recent_sessions: RawRecentSession[];
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
