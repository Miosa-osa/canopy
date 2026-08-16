/**
 * TanStack Query factories for the Runtime Adapter Agent surface.
 * Endpoints under /api/v1/runtime-adapter/*.
 */

import { apiGet, apiPost } from "$lib/api/client.js";
import type {
  CheckpointCreate,
  CheckpointRestoreResult,
  ModelRoleAssignment,
  ModelRoleName,
  RoleAssignmentCreate,
  RuntimeAdapterModelList,
  RuntimeCheckpoint,
  SuggestionResult,
  SwapRequest,
  SwapResult,
  TaskHints,
} from "$lib/domain/runtime_adapter/types.js";

// ── Models ──────────────────────────────────────────────────────────────

export function modelsQuery(runtimeId: string) {
  return {
    queryKey: ["runtime-adapter", "models", runtimeId],
    queryFn: () =>
      apiGet<RuntimeAdapterModelList>(
        `/runtime-adapter/models?runtime_id=${encodeURIComponent(runtimeId)}`,
      ),
    enabled: Boolean(runtimeId),
  } as const;
}

// ── Roles ───────────────────────────────────────────────────────────────

export interface RolesQueryOpts {
  runtime?: string;
  role?: ModelRoleName;
  workspaceSlug?: string;
}

export function rolesQuery(opts: RolesQueryOpts = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ["runtime-adapter", "roles", opts],
    queryFn: () =>
      apiGet<{ data: ModelRoleAssignment[] }>(
        `/runtime-adapter/roles${qs}`,
      ).then((r) => r.data),
  };
}

export async function assignRole(
  body: RoleAssignmentCreate,
): Promise<ModelRoleAssignment> {
  return apiPost<ModelRoleAssignment>("/runtime-adapter/roles", body);
}

// ── Checkpoints ─────────────────────────────────────────────────────────

export interface CheckpointsQueryOpts {
  limit?: number;
}

export function checkpointsQuery(
  sessionId: string,
  opts: CheckpointsQueryOpts = {},
) {
  const qs = buildQuery({ session_id: sessionId, ...opts });
  return {
    queryKey: ["runtime-adapter", "checkpoints", sessionId, opts],
    queryFn: () =>
      apiGet<{ session_id: string; count: number; data: RuntimeCheckpoint[] }>(
        `/runtime-adapter/checkpoints${qs}`,
      ).then((r) => r.data),
    enabled: Boolean(sessionId),
  } as const;
}

export async function createCheckpoint(
  body: CheckpointCreate,
): Promise<RuntimeCheckpoint> {
  return apiPost<RuntimeCheckpoint>("/runtime-adapter/checkpoints", body);
}

export async function restoreCheckpoint(
  id: string,
  currentMemory?: Record<string, unknown>,
): Promise<CheckpointRestoreResult> {
  return apiPost<CheckpointRestoreResult>(
    `/runtime-adapter/checkpoints/${id}/restore`,
    { current_memory: currentMemory },
  );
}

// ── Suggestions / swap ──────────────────────────────────────────────────

export interface SuggestionRequest {
  taskHints: TaskHints;
  limit?: number;
}

export async function suggestRuntime(
  body: SuggestionRequest,
): Promise<SuggestionResult> {
  return apiPost<SuggestionResult>("/runtime-adapter/suggestions", body);
}

export async function swapRuntime(body: SwapRequest): Promise<SwapResult> {
  return apiPost<SwapResult>("/runtime-adapter/swap", body);
}

// ── Helpers ─────────────────────────────────────────────────────────────

function buildQuery(opts: object): string {
  const entries = Object.entries(opts as Record<string, unknown>).filter(
    ([, v]) => v !== undefined && v !== null && v !== "",
  );
  if (entries.length === 0) return "";

  const params = new URLSearchParams();
  for (const [key, value] of entries) {
    const snakeKey = key.replace(/[A-Z]/g, (m) => `_${m.toLowerCase()}`);
    params.set(snakeKey, String(value));
  }
  return `?${params.toString()}`;
}

export type {
  ModelRoleAssignment,
  RuntimeAdapterModelList,
  RuntimeCheckpoint,
  RuntimeSuggestion,
  SwapResult,
} from "$lib/domain/runtime_adapter/types.js";
