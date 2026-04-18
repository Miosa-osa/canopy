/**
 * TanStack Query factories for the /sessions resource.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import { apiDelete, apiGet, apiPost } from "$lib/api/client.js";
import type {
  CreateSessionBody,
  Session,
  SessionDetail,
  TranscriptEntry,
} from "$lib/domain/sessions/types.js";

// ── Filters ──────────────────────────────────────────────────────────────────

export interface SessionFilters {
  status?: string;
  runtimeType?: string;
  workspaceSlug?: string;
  agentSlug?: string;
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
  if (filters?.runtimeType) params.set("runtime_type", filters.runtimeType);
  if (filters?.workspaceSlug) params.set("workspace", filters.workspaceSlug);
  if (filters?.agentSlug) params.set("agent_slug", filters.agentSlug);
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
  return apiPost<Session>("/sessions", body);
}

export function cancelSession(id: string): Promise<void> {
  return apiDelete<void>(`/sessions/${id}`);
}

export function getSessionChain(id: string): Promise<Session[]> {
  return apiGet<Session[]>(`/sessions/${id}/chain`);
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
