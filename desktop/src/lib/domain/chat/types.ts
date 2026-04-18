/**
 * Chat domain types — Thread and ThreadDetail from the /api/v1/chat/threads contract.
 * All fields mirror the backend Ecto schema after camelCase transformation.
 */

import type { TranscriptEntry } from "$lib/domain/sessions/types.js";

// ── Core Thread ───────────────────────────────────────────────────────────────

/** A chat thread as returned by GET /api/v1/chat/threads and detail endpoints. */
export interface Thread {
  id: string;
  title: string | null;
  userId: string | null;
  agentSlug: string | null;
  runtimeType: string;
  modelId: string | null;
  workspaceSlug: string | null;
  lastSessionId: string | null;
  lastMessageAt: string | null;
  pinned: boolean;
  archivedAt: string | null;
  metadata: Record<string, unknown> | null;
  insertedAt: string;
  updatedAt: string;
}

/** Thread with its full concatenated transcript. Returned by GET /api/v1/chat/threads/:id. */
export interface ThreadDetail {
  thread: Thread;
  messages: TranscriptEntry[];
}

// ── Request bodies ────────────────────────────────────────────────────────────

/** POST /api/v1/chat/threads */
export interface CreateThreadBody {
  title?: string;
  agentSlug?: string;
  runtimeType: string;
  modelId?: string;
  workspaceSlug?: string;
  prompt?: string;
}

/** POST /api/v1/chat/threads/:id/continue */
export interface ContinueThreadBody {
  prompt: string;
}

/** PATCH /api/v1/chat/threads/:id */
export interface UpdateThreadBody {
  title?: string;
  pinned?: boolean;
  archived?: boolean;
}

// ── Response shapes ───────────────────────────────────────────────────────────

/** Response from POST /api/v1/chat/threads (create) */
export interface CreateThreadResponse {
  thread: Thread;
  sessionId: string;
  sseUrl: string;
}

/** Response from POST /api/v1/chat/threads/:id/continue */
export interface ContinueThreadResponse {
  sessionId: string;
  sseUrl: string;
}

// ── Filters ───────────────────────────────────────────────────────────────────

/** Query params for GET /api/v1/chat/threads */
export interface ThreadFilters {
  userId?: string;
  agentSlug?: string;
  archived?: boolean;
  pinned?: boolean;
}
