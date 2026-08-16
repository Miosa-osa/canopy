/**
 * Agent conversation query factories.
 *
 * Conversations ARE Sessions discriminated by `kind="agent_conversation"`.
 * This module is a thin façade over `sessions.ts` so consumers can speak in
 * conversation vocabulary without duplicating fetch logic, query keys, or
 * mutation contracts.
 *
 * NEVER add a parallel /api/v1/conversations endpoint — the source of truth
 * is `Canopy.Sessions`. If a new shape is required, extend `sessions.ts` and
 * re-export from here.
 */

import {
  cancelSession,
  cancelSessionMutation,
  createSession,
  createSessionMutation,
  type SessionFilters,
  sessionsQuery,
} from "./sessions.js";
import type {
  CreateSessionBody,
  Session,
  SessionStatus,
} from "$lib/domain/sessions/types.js";

// ── Filters ──────────────────────────────────────────────────────────────────

export interface ConversationFilters {
  workspaceSlug?: string;
  status?: SessionStatus;
  limit?: number;
}

/** Treat unset/legacy `kind` as "terminal" — only true conversations pass. */
export function isAgentConversation(s: Session): boolean {
  return s.kind === "agent_conversation";
}

/**
 * Active conversations are still running (or warming up). Anything else —
 * completed, cancelled, error — is "recent" history.
 */
export function isActiveConversation(s: Session): boolean {
  return (
    s.status === "running" || s.status === "pending" || s.status === "paused"
  );
}

// ── Query factory ────────────────────────────────────────────────────────────

/**
 * Reuses `sessionsQuery` with `kind: "agent_conversation"`.
 * Returns the same Session[] shape — UI is responsible for grouping
 * (active vs recent) and for hiding legacy `kind === null` rows.
 */
export function agentConversationsQuery(filters?: ConversationFilters) {
  const merged: SessionFilters = {
    kind: "agent_conversation",
    workspaceSlug: filters?.workspaceSlug,
    status: filters?.status,
    limit: filters?.limit ?? 100,
  };
  const base = sessionsQuery(merged);
  return {
    ...base,
    // Override the queryKey root so devtools / cache eviction can target
    // conversations specifically without clobbering the broader sessions cache.
    queryKey: ["agent-conversations", merged] as const,
  };
}

// ── Mutations ────────────────────────────────────────────────────────────────

/** Mutation options to create a new agent conversation session. */
export function createAgentConversationMutation() {
  return {
    mutationKey: ["agent-conversations", "create"] as const,
    mutationFn: (body: Omit<CreateSessionBody, "kind">) =>
      createSession({ ...body, kind: "agent_conversation" }),
  };
}

/** Mutation options to delete (cancel) an agent conversation session. */
export function deleteAgentConversationMutation() {
  return {
    mutationKey: ["agent-conversations", "delete"] as const,
    mutationFn: (id: string) => cancelSession(id),
  };
}

// Re-export underlying primitives for callers that need the lower-level API.
export {
  createSession,
  cancelSession,
  createSessionMutation,
  cancelSessionMutation,
};
