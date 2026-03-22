// src/lib/stores/costs.svelte.ts
import { costs as costsApi } from "$api/client";
import type {
  CostSummary,
  AgentCostBreakdown,
  ModelCostBreakdown,
  BudgetPolicy,
  BudgetIncident,
} from "$api/types";
import { toastStore } from "./toasts.svelte";

export interface DailyCostPoint {
  date: string; // "YYYY-MM-DD"
  cost_cents: number;
}

export type DateRange = "7d" | "30d" | "90d";

class CostsStore {
  isLoading = $state(true);
  error = $state<string | null>(null);
  lastFetched = $state<Date | null>(null);

  dateRange = $state<DateRange>("30d");
  // Tracks the active workspace so date-range changes can re-fetch scoped data
  private _workspaceId: string | undefined = undefined;

  summary = $state<CostSummary>({
    today_cents: 0,
    week_cents: 0,
    month_cents: 0,
    daily_budget_cents: 0,
    monthly_budget_cents: 0,
    daily_remaining_cents: 0,
    monthly_remaining_cents: 0,
    cache_savings_cents: 0,
  });

  agentBreakdown = $state<AgentCostBreakdown[]>([]);
  modelBreakdown = $state<ModelCostBreakdown[]>([]);
  policies = $state<BudgetPolicy[]>([]);
  incidents = $state<BudgetIncident[]>([]);
  dailyTrend = $state<DailyCostPoint[]>([]);

  // ── Derived ────────────────────────────────────────────────────────────────

  todayDollars = $derived(this.summary.today_cents / 100);
  weekDollars = $derived(this.summary.week_cents / 100);
  monthDollars = $derived(this.summary.month_cents / 100);
  dailyBudgetDollars = $derived(this.summary.daily_budget_cents / 100);
  monthlyBudgetDollars = $derived(this.summary.monthly_budget_cents / 100);
  cacheSavingsDollars = $derived(this.summary.cache_savings_cents / 100);

  cacheSavingsPct = $derived(
    this.summary.month_cents > 0
      ? Math.round(
          (this.summary.cache_savings_cents /
            (this.summary.month_cents + this.summary.cache_savings_cents)) *
            100,
        )
      : 0,
  );

  dailyUsagePct = $derived(
    this.summary.daily_budget_cents > 0
      ? (this.summary.today_cents / this.summary.daily_budget_cents) * 100
      : 0,
  );

  monthlyUsagePct = $derived(
    this.summary.monthly_budget_cents > 0
      ? (this.summary.month_cents / this.summary.monthly_budget_cents) * 100
      : 0,
  );

  activeIncidents = $derived(this.incidents.filter((i) => !i.resolved));

  hasAnomaly = $derived(this.activeIncidents.some((i) => i.type === "anomaly"));

  topAnomaly = $derived(
    this.activeIncidents.find((i) => i.type === "anomaly") ?? null,
  );

  totalModelCost = $derived(
    this.modelBreakdown.reduce((sum, m) => sum + m.cost_cents, 0),
  );

  modelDistribution = $derived(
    this.modelBreakdown.map((m) => ({
      ...m,
      percentage:
        this.totalModelCost > 0
          ? Math.round((m.cost_cents / this.totalModelCost) * 100)
          : 0,
    })),
  );

  maxDailyTrendCents = $derived(
    this.dailyTrend.reduce((max, p) => Math.max(max, p.cost_cents), 0),
  );

  // ── Methods ────────────────────────────────────────────────────────────────

  async fetch(workspaceId?: string): Promise<void> {
    this.isLoading = true;
    this.error = null;
    try {
      const [summaryData, agentData, modelData] = await Promise.all([
        costsApi.summary(workspaceId),
        costsApi.byAgent(workspaceId),
        costsApi.byModel(workspaceId),
      ]);
      this.summary = summaryData;
      this.agentBreakdown = agentData.agents ?? [];
      this.modelBreakdown = modelData.models ?? [];
      this.lastFetched = new Date();
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load costs", msg);
    } finally {
      this.isLoading = false;
    }
  }

  async fetchPolicies(workspaceId?: string): Promise<void> {
    try {
      const [policiesData, incidentsData] = await Promise.all([
        costsApi.policies(workspaceId),
        costsApi.incidents(workspaceId),
      ]);
      this.policies = policiesData.policies ?? [];
      this.incidents = incidentsData.incidents ?? [];
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load budget policies", msg);
    }
  }

  async fetchTrends(workspaceId?: string): Promise<void> {
    try {
      const to = new Date();
      const daysBack =
        this.dateRange === "7d" ? 7 : this.dateRange === "90d" ? 90 : 30;
      const from = new Date(to);
      from.setDate(from.getDate() - daysBack);
      const fmt = (d: Date) => d.toISOString().slice(0, 10);
      const data = await costsApi.daily({
        from: fmt(from),
        to: fmt(to),
        workspace_id: workspaceId,
      });
      this.dailyTrend = data.points ?? [];
    } catch {
      // Endpoint may not exist yet — fail silently with empty trend
      this.dailyTrend = [];
    }
  }

  async fetchAll(workspaceId?: string): Promise<void> {
    this._workspaceId = workspaceId;
    await this.fetch(workspaceId);
    await this.fetchTrends(workspaceId);
    await this.fetchPolicies(workspaceId);
  }

  setDateRange(range: DateRange): void {
    this.dateRange = range;
    void this.fetchTrends(this._workspaceId);
  }
}

export const costsStore = new CostsStore();
