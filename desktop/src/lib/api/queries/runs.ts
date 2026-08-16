/**
 * TanStack Query factories for the /runs resource.
 *
 * Runs are execution records that tie agent-originated actions to a specific
 * tracked invocation. Every mutation carrying X-Run-Id is attributed to a run.
 */

import { apiGet, apiPost, apiPatch } from "$lib/api/client.js";

// ── Types ─────────────────────────────────────────────────────────────────────

export interface Run {
  id: string;
  shortId: string;
  sessionId: string | null;
  agentSlug: string | null;
  workspaceSlug: string;
  issueShortId: string | null;
  taskShortId: string | null;
  projectSlug: string | null;
  processPid: number | null;
  status: RunStatus;
  promptBundleKey: string | null;
  usageJson: RunUsage;
  logRef: string | null;
  contextSnapshot: Record<string, unknown> | null;
  startedAt: string;
  finishedAt: string | null;
  errorReason: string | null;
  wakeReason: string | null;
  insertedAt: string;
  updatedAt: string;
}

export type RunStatus =
  | "queued"
  | "running"
  | "paused"
  | "succeeded"
  | "failed"
  | "cancelled";

export interface RunUsage {
  tokensIn?: number;
  tokensOut?: number;
  cacheRead?: number;
  cacheWrite?: number;
  costUsd?: string;
}

export interface RunLogLine {
  seq: number;
  at: string | null;
  kind: "stdout" | "stderr" | "event" | "tool_call" | "tool_result";
  data: string;
}

export type TranscriptBlockKind =
  | "stdout"
  | "stderr"
  | "tool_call"
  | "tool_result"
  | "thinking"
  | "user_prompt"
  | "permission_request"
  | "exit";

export interface TranscriptBlock {
  kind: TranscriptBlockKind;
  payload: Record<string, unknown>;
  at: string;
}

export interface TranscriptResponse {
  run_id: string;
  short_id: string;
  blocks: TranscriptBlock[];
  count: number;
}

export interface RunLogPage {
  runId: string;
  shortId: string;
  offset: number;
  limit: number;
  lines: RunLogLine[];
  hasMore: boolean;
  totalSoFar: number;
}

export interface RunFilters {
  sessionId?: string;
  workspaceSlug?: string;
  agentSlug?: string;
  status?: RunStatus;
  limit?: number;
}

// ── Raw API calls ─────────────────────────────────────────────────────────────

export function listRuns(
  filters?: RunFilters,
): Promise<{ data: Run[]; count: number }> {
  const params = new URLSearchParams();
  if (filters?.sessionId) params.set("session_id", filters.sessionId);
  if (filters?.workspaceSlug)
    params.set("workspace_slug", filters.workspaceSlug);
  if (filters?.agentSlug) params.set("agent_slug", filters.agentSlug);
  if (filters?.status) params.set("status", filters.status);
  if (filters?.limit !== undefined) params.set("limit", String(filters.limit));
  const qs = params.toString();
  return apiGet<{ data: Run[]; count: number }>(`/runs${qs ? `?${qs}` : ""}`);
}

export function getRun(id: string): Promise<{ data: Run }> {
  return apiGet<{ data: Run }>(`/runs/${id}`);
}

export function createRun(attrs: Partial<Run>): Promise<{ data: Run }> {
  return apiPost<{ data: Run }>("/runs", attrs);
}

export function finishRun(
  id: string,
  payload: {
    status: "succeeded" | "failed" | "cancelled";
    usageJson?: RunUsage;
    error?: string;
  },
): Promise<{ data: Run }> {
  return apiPost<{ data: Run }>(`/runs/${id}/finish`, payload);
}

export function getRunLog(
  id: string,
  offset = 0,
  limit = 200,
): Promise<RunLogPage> {
  return apiGet<RunLogPage>(`/runs/${id}/log?offset=${offset}&limit=${limit}`);
}

// ── TanStack Query factories ──────────────────────────────────────────────────

export function runsQuery(filters?: RunFilters) {
  return {
    queryKey: ["runs", filters ?? {}],
    queryFn: () => listRuns(filters).then((r) => r.data),
    staleTime: 10_000,
  };
}

export function runQuery(id: string) {
  return {
    queryKey: ["runs", id],
    queryFn: () => getRun(id).then((r) => r.data),
    staleTime: 5_000,
    enabled: !!id,
  };
}

export function listRunsForSession(
  sessionId: string,
  opts?: { limit?: number },
) {
  return {
    queryKey: ["runs", "session", sessionId],
    queryFn: () =>
      listRuns({ sessionId, limit: opts?.limit ?? 20 }).then((r) => r.data),
    staleTime: 10_000,
    enabled: !!sessionId,
  };
}

export function runLogQuery(runId: string, offset = 0) {
  return {
    queryKey: ["runs", runId, "log", offset],
    queryFn: () => getRunLog(runId, offset),
    staleTime: 5_000,
    enabled: !!runId,
  };
}

export function getRunTranscript(runId: string): Promise<TranscriptResponse> {
  return apiGet<TranscriptResponse>(`/runs/${runId}/transcript`);
}

export function transcriptQuery(runId: string) {
  return {
    queryKey: ["runs", runId, "transcript"],
    queryFn: () => getRunTranscript(runId),
    staleTime: 30_000,
    enabled: !!runId,
  };
}
