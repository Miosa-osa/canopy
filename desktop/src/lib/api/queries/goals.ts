/**
 * TanStack Query factories for the /goals resource.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import { apiDelete, apiGet, apiPatch, apiPost } from "$lib/api/client.js";
import type {
  CreateGoalBody,
  Goal,
  GoalFilters,
  GoalProgressBody,
  UpdateGoalBody,
} from "$lib/domain/goals/types.js";

// ── Raw API calls ────────────────────────────────────────────────────────────

export function listGoals(filters?: GoalFilters): Promise<Goal[]> {
  const params = new URLSearchParams();
  if (filters?.workspaceSlug)
    params.set("workspace_slug", filters.workspaceSlug);
  if (filters?.status) params.set("status", filters.status);
  const qs = params.toString();
  return apiGet<Goal[]>(`/goals${qs ? `?${qs}` : ""}`);
}

export function getGoal(shortId: string): Promise<Goal> {
  return apiGet<Goal>(`/goals/${shortId}`);
}

export function createGoal(body: CreateGoalBody): Promise<Goal> {
  return apiPost<Goal>("/goals", body);
}

export function updateGoal(
  shortId: string,
  body: UpdateGoalBody,
): Promise<Goal> {
  return apiPatch<Goal>(`/goals/${shortId}`, body);
}

export function deleteGoal(shortId: string): Promise<void> {
  return apiDelete<void>(`/goals/${shortId}`);
}

export function postGoalProgress(
  shortId: string,
  body: GoalProgressBody,
): Promise<Goal> {
  return apiPost<Goal>(`/goals/${shortId}/progress`, body);
}

export function achieveGoal(shortId: string): Promise<Goal> {
  return apiPost<Goal>(`/goals/${shortId}/achieve`, {});
}

export function cancelGoal(shortId: string): Promise<Goal> {
  return apiPost<Goal>(`/goals/${shortId}/cancel`, {});
}

// ── TanStack Query option factories ─────────────────────────────────────────

export function goalsQuery(filters?: GoalFilters) {
  return {
    queryKey: ["goals", filters ?? {}] as const,
    queryFn: () => listGoals(filters),
    staleTime: 15_000,
    retry: false,
  };
}

export function goalQuery(shortId: string) {
  return {
    queryKey: ["goals", shortId] as const,
    queryFn: () => getGoal(shortId),
    staleTime: 10_000,
    enabled: Boolean(shortId),
    retry: false,
  };
}

export function createGoalMutation() {
  return {
    mutationKey: ["goals", "create"] as const,
    mutationFn: (body: CreateGoalBody) => createGoal(body),
  };
}

export function updateGoalMutation() {
  return {
    mutationKey: ["goals", "update"] as const,
    mutationFn: ({
      shortId,
      body,
    }: {
      shortId: string;
      body: UpdateGoalBody;
    }) => updateGoal(shortId, body),
  };
}

export function deleteGoalMutation() {
  return {
    mutationKey: ["goals", "delete"] as const,
    mutationFn: (shortId: string) => deleteGoal(shortId),
  };
}

export function goalProgressMutation() {
  return {
    mutationKey: ["goals", "progress"] as const,
    mutationFn: ({
      shortId,
      body,
    }: {
      shortId: string;
      body: GoalProgressBody;
    }) => postGoalProgress(shortId, body),
  };
}

export function achieveGoalMutation() {
  return {
    mutationKey: ["goals", "achieve"] as const,
    mutationFn: (shortId: string) => achieveGoal(shortId),
  };
}

export function cancelGoalMutation() {
  return {
    mutationKey: ["goals", "cancel"] as const,
    mutationFn: (shortId: string) => cancelGoal(shortId),
  };
}
