// src/lib/stores/dashboard.svelte.ts
import { dashboard as dashboardApi } from "$api/client";
import type {
  DashboardKpis,
  LiveRun,
  ActivityEvent,
  FinanceSummary,
  SystemHealth,
} from "$api/types";

class DashboardStore {
  isLoading = $state(true);
  error = $state<string | null>(null);
  lastFetched = $state<Date | null>(null);

  kpis = $state<DashboardKpis | null>(null);
  liveRuns = $state<LiveRun[]>([]);
  recentActivity = $state<ActivityEvent[]>([]);
  financeSummary = $state<FinanceSummary | null>(null);
  systemHealth = $state<SystemHealth | null>(null);

  #refreshTimer: ReturnType<typeof setInterval> | null = null;

  async fetch(): Promise<void> {
    this.isLoading = true;
    try {
      const data = await dashboardApi.get();
      this.kpis = data.kpis;
      this.liveRuns = data.live_runs;
      this.recentActivity = data.recent_activity;
      this.financeSummary = data.finance_summary;
      this.systemHealth = data.system_health;
      this.lastFetched = new Date();
      this.error = null;
    } catch (e) {
      this.error = (e as Error).message;
    } finally {
      this.isLoading = false;
    }
  }

  startAutoRefresh(intervalMs = 30_000): () => void {
    void this.fetch();
    this.#refreshTimer = setInterval(() => void this.fetch(), intervalMs);
    return () => this.stopAutoRefresh();
  }

  stopAutoRefresh(): void {
    if (this.#refreshTimer !== null) {
      clearInterval(this.#refreshTimer);
      this.#refreshTimer = null;
    }
  }
}

export const dashboardStore = new DashboardStore();
