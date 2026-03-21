import type { DashboardData } from "../types";

export function mockDashboard(): DashboardData {
  return {
    kpis: {
      active_agents: 0,
      total_agents: 0,
      live_runs: 0,
      open_issues: 0,
      budget_remaining_pct: 0,
    },
    live_runs: [],
    recent_activity: [],
    finance_summary: {
      today_cents: 0,
      week_cents: 0,
      month_cents: 0,
      daily_limit_cents: 0,
      cache_savings_pct: 0,
    },
    system_health: {
      backend: "ok",
      primary_gateway: null,
      gateway_status: "healthy",
      memory_mb: 0,
      cpu_pct: 0,
    },
  };
}
