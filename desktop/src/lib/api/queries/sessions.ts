/**
 * TanStack Query factories for the /sessions resource.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 *
 * snake_case → camelCase conversion is handled at the client boundary
 * (client.ts toCamelSafe). No per-query toCamel/toSnake calls needed here.
 */

import { apiDelete, apiGet, apiPatch, apiPost } from "$lib/api/client.js";
import type {
  CreateSessionBody,
  Session,
  SessionDetail,
  SessionKind,
  TranscriptEntry,
} from "$lib/domain/sessions/types.js";

// ── Filters ──────────────────────────────────────────────────────────────────

export interface SessionFilters {
  status?: string;
  runtimeType?: string;
  workspaceSlug?: string;
  agentSlug?: string;
  /**
   * Discriminator filter. Backends prior to the kind-column rollout simply
   * ignore the query param, so callers should be defensive about mixed rows
   * (filter on the client too if strictness is required).
   */
  kind?: SessionKind;
  limit?: number;
  offset?: number;
}

export interface MessageListOpts {
  limit?: number;
  after?: string;
}

// ── Raw API calls ────────────────────────────────────────────────────────────

export function listSessions(filters?: SessionFilters): Promise<Session[]> {
  const params = new URLSearchParams();
  if (filters?.status) params.set("status", filters.status);
  if (filters?.runtimeType) params.set("runtime", filters.runtimeType);
  if (filters?.workspaceSlug) params.set("workspace", filters.workspaceSlug);
  if (filters?.agentSlug) params.set("agent_slug", filters.agentSlug);
  if (filters?.kind) params.set("kind", filters.kind);
  if (filters?.limit !== undefined) params.set("limit", String(filters.limit));
  if (filters?.offset !== undefined)
    params.set("offset", String(filters.offset));
  const qs = params.toString();
  return apiGet<Session[]>(`/sessions${qs ? `?${qs}` : ""}`);
}

export function getSession(id: string): Promise<SessionDetail> {
  return apiGet<SessionDetail>(`/sessions/${id}`);
}

export function createSession(body: CreateSessionBody): Promise<Session> {
  // client.ts toSnakeSafe converts camelCase → snake_case automatically
  return apiPost<Session>("/sessions", body);
}

export function cancelSession(id: string): Promise<void> {
  return apiDelete<void>(`/sessions/${id}`);
}

export function updateSession(
  id: string,
  patch: { title?: string },
): Promise<Session> {
  return apiPatch<Session>(`/sessions/${id}`, patch);
}

export interface BulkDeleteFilters {
  status?: "ended" | "failed" | "cancelled" | "completed";
  before?: string; // ISO8601
}

export function bulkDeleteSessions(
  filters?: BulkDeleteFilters,
): Promise<{ deleted: number }> {
  const params = new URLSearchParams();
  if (filters?.status) params.set("status", filters.status);
  if (filters?.before) params.set("before", filters.before);
  const qs = params.toString();
  return apiDelete<{ deleted: number }>(`/sessions${qs ? `?${qs}` : ""}`);
}

export function pauseSession(id: string): Promise<Session> {
  return apiPost<Session>(`/sessions/${id}/pause`, {});
}

export function resumeSession(id: string): Promise<Session> {
  return apiPost<Session>(`/sessions/${id}/resume`, {});
}

export function stopSession(id: string): Promise<Session> {
  return apiPost<Session>(`/sessions/${id}/stop`, {});
}

export function getSessionChain(id: string): Promise<Session[]> {
  return apiGet<Session[]>(`/sessions/${id}/chain`);
}

export function cleanupWorktree(id: string): Promise<{ ok: boolean }> {
  return apiPost<{ ok: boolean }>(`/sessions/${id}/cleanup_worktree`, {});
}

/**
 * POST /sessions/:id/messages — logs a structured prompt for history/audit.
 * Used alongside PTY stdin injection so prompts are persisted server-side.
 * Falls back gracefully if the backend endpoint is not yet available (204/404
 * are swallowed by the caller; only hard network errors propagate).
 */
export function sendSessionMessage(id: string, content: string): Promise<void> {
  return apiPost<void>(`/sessions/${id}/messages`, { content });
}

export function sendSessionMessageMutation() {
  return {
    mutationKey: ["sessions", "send-message"] as const,
    mutationFn: ({
      sessionId,
      content,
    }: {
      sessionId: string;
      content: string;
    }) => sendSessionMessage(sessionId, content),
  };
}

export function listSessionMessages(
  id: string,
  opts?: MessageListOpts,
): Promise<TranscriptEntry[]> {
  const params = new URLSearchParams();
  if (opts?.limit !== undefined) params.set("limit", String(opts.limit));
  if (opts?.after) params.set("after", opts.after);
  const qs = params.toString();
  return apiGet<TranscriptEntry[]>(
    `/sessions/${id}/messages${qs ? `?${qs}` : ""}`,
  );
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for the sessions list with optional filters. */
export function sessionsQuery(filters?: SessionFilters) {
  return {
    queryKey: ["sessions", filters ?? {}] as const,
    queryFn: () => listSessions(filters),
    staleTime: 10_000,
  };
}

/** Query options for a single session detail. */
export function sessionDetailQuery(id: string) {
  return {
    queryKey: ["sessions", id] as const,
    queryFn: () => getSession(id),
    staleTime: 5_000,
    enabled: Boolean(id),
  };
}

/** Query options for session transcript messages. */
export function sessionMessagesQuery(id: string, opts?: MessageListOpts) {
  return {
    queryKey: ["sessions", id, "messages", opts ?? {}] as const,
    queryFn: () => listSessionMessages(id, opts),
    staleTime: 0,
    enabled: Boolean(id),
  };
}

/** Query options for a session's parent/child chain. */
export function sessionChainQuery(id: string) {
  return {
    queryKey: ["sessions", id, "chain"] as const,
    queryFn: () => getSessionChain(id),
    staleTime: 30_000,
    enabled: Boolean(id),
  };
}

/** Mutation options to create a new session. */
export function createSessionMutation() {
  return {
    mutationKey: ["sessions", "create"] as const,
    mutationFn: (body: CreateSessionBody) => createSession(body),
  };
}

/** Mutation options to cancel a running session. */
export function cancelSessionMutation() {
  return {
    mutationKey: ["sessions", "cancel"] as const,
    mutationFn: (id: string) => cancelSession(id),
  };
}

/** Mutation options to rename a session. */
export function updateSessionMutation() {
  return {
    mutationKey: ["sessions", "update"] as const,
    mutationFn: ({ id, title }: { id: string; title: string }) =>
      updateSession(id, { title }),
  };
}

// ── Worktree ─────────────────────────────────────────────────────────────────

export interface WorktreeStatus {
  path: string | null;
  branch: string | null;
  baseBranch: string | null;
  exists: boolean;
  changesCount: number;
}

export function getWorktreeStatus(id: string): Promise<WorktreeStatus> {
  return apiGet<WorktreeStatus>(`/sessions/${id}/worktree`);
}

export async function getWorktreeDiff(
  id: string,
): Promise<{ raw: string; truncated: boolean }> {
  const res = await fetch(
    `http://localhost:9190/api/v1/sessions/${id}/worktree/diff`,
    { headers: { Accept: "text/plain" } },
  );
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const truncated = res.headers.get("x-truncated") === "true";
  const raw = await res.text();
  return {
    raw,
    truncated: truncated || raw.trimEnd().endsWith("... (truncated)"),
  };
}

/** Query options for worktree status. */
export function worktreeStatusQuery(id: string) {
  return {
    queryKey: ["sessions", id, "worktree"] as const,
    queryFn: () => getWorktreeStatus(id),
    staleTime: 10_000,
    enabled: Boolean(id),
  };
}

/** Query options for raw worktree diff. */
export function worktreeDiffQuery(id: string, enabled: boolean) {
  return {
    queryKey: ["sessions", id, "worktree", "diff"] as const,
    queryFn: () => getWorktreeDiff(id),
    staleTime: 10_000,
    enabled: Boolean(id) && enabled,
  };
}
