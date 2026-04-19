/**
 * TanStack Query factories for the /budgets resource.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import { apiDelete, apiGet, apiPost, apiPut } from "$lib/api/client.js";

// ── Types ────────────────────────────────────────────────────────────────────

export type BudgetPeriod = "weekly" | "monthly";
export type BudgetScopeType = "global" | "agent" | "workspace";

export interface Budget {
  id: string;
  name: string;
  scope_type: BudgetScopeType;
  /** null when scope_type === 'global' */
  scope_id: string | null;
  period: BudgetPeriod;
  limit_usd: number;
  soft_alert_pct: number;
  hard_ceiling: boolean;
  enabled: boolean;
  spent_this_period: number;
  inserted_at: string;
  updated_at: string;
}

export interface BudgetSpend {
  budget_id: string;
  period_start: string;
  period_end: string;
  spent_usd: number;
  limit_usd: number;
  pct_used: number;
}

export interface CreateBudgetBody {
  name: string;
  scope_type: BudgetScopeType;
  scope_id?: string | null;
  period: BudgetPeriod;
  limit_usd: number;
  soft_alert_pct?: number;
  hard_ceiling?: boolean;
  enabled?: boolean;
}

export interface UpdateBudgetBody {
  name?: string;
  scope_type?: BudgetScopeType;
  scope_id?: string | null;
  period?: BudgetPeriod;
  limit_usd?: number;
  soft_alert_pct?: number;
  hard_ceiling?: boolean;
  enabled?: boolean;
}

export interface BudgetCheckResult {
  allowed: boolean;
  reason: string | null;
  spent_usd: number;
  limit_usd: number;
}

// ── Raw API calls ────────────────────────────────────────────────────────────

export function listBudgets(): Promise<Budget[]> {
  return apiGet<Budget[]>("/budgets");
}

export function getBudget(id: string): Promise<Budget> {
  return apiGet<Budget>(`/budgets/${id}`);
}

export function createBudget(body: CreateBudgetBody): Promise<Budget> {
  return apiPost<Budget>("/budgets", body);
}

export function updateBudget(
  id: string,
  body: UpdateBudgetBody,
): Promise<Budget> {
  return apiPut<Budget>(`/budgets/${id}`, body);
}

export function deleteBudget(id: string): Promise<void> {
  return apiDelete<void>(`/budgets/${id}`);
}

export function getBudgetSpend(id: string): Promise<BudgetSpend> {
  return apiGet<BudgetSpend>(`/budgets/${id}/spend`);
}

export function checkBudget(id: string): Promise<BudgetCheckResult> {
  return apiPost<BudgetCheckResult>(`/budgets/${id}/check`, {});
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for the full budget list. */
export function budgetsQuery() {
  return {
    queryKey: ["budgets"] as const,
    queryFn: listBudgets,
    staleTime: 30_000,
  };
}

/** Query options for a single budget. */
export function budgetQuery(id: string) {
  return {
    queryKey: ["budgets", id] as const,
    queryFn: () => getBudget(id),
    staleTime: 30_000,
    enabled: Boolean(id),
  };
}

/** Mutation options to create a budget. */
export function createBudgetMutation() {
  return {
    mutationKey: ["budgets", "create"] as const,
    mutationFn: (body: CreateBudgetBody) => createBudget(body),
  };
}

/** Mutation options to update a budget. */
export function updateBudgetMutation(id: string) {
  return {
    mutationKey: ["budgets", id, "update"] as const,
    mutationFn: (body: UpdateBudgetBody) => updateBudget(id, body),
  };
}

/** Mutation options to delete a budget. */
export function deleteBudgetMutation(id: string) {
  return {
    mutationKey: ["budgets", id, "delete"] as const,
    mutationFn: () => deleteBudget(id),
  };
}

/** Query options for a budget's spend for the current period. */
export function budgetSpendQuery(id: string) {
  return {
    queryKey: ["budgets", id, "spend"] as const,
    queryFn: () => getBudgetSpend(id),
    staleTime: 15_000,
    enabled: Boolean(id),
  };
}

/** Mutation options to run a budget check. */
export function checkBudgetMutation(id: string) {
  return {
    mutationKey: ["budgets", id, "check"] as const,
    mutationFn: () => checkBudget(id),
  };
}
