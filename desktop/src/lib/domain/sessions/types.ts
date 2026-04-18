/**
 * Session domain types — TranscriptEntry discriminated union from Paperclip lift.
 * Matches the Elixir backend structs served at /api/v1/sessions.
 */

export type SessionStatus =
  | "pending"
  | "running"
  | "paused"
  | "completed"
  | "cancelled"
  | "error";

/** Discriminated union of all transcript entry kinds (Paperclip §7 lift) */
export type TranscriptEntry =
  | { id: string; kind: "assistant"; text: string; createdAt: string }
  | { id: string; kind: "thinking"; text: string; createdAt: string }
  | {
      id: string;
      kind: "tool_call";
      toolName: string;
      args: Record<string, unknown>;
      toolCallId: string;
      createdAt: string;
    }
  | {
      id: string;
      kind: "tool_result";
      toolCallId: string;
      content: string;
      isError: boolean;
      createdAt: string;
    }
  | {
      id: string;
      kind: "diff";
      filePath: string;
      patch: string;
      additions: number;
      deletions: number;
      createdAt: string;
    }
  | { id: string; kind: "stdout"; text: string; createdAt: string }
  | { id: string; kind: "stderr"; text: string; createdAt: string }
  | { id: string; kind: "system"; text: string; createdAt: string };

/**
 * Session summary — shown in list rows.
 *
 * Fields map 1:1 to backend snake_case after camelCase transformation:
 *   agent_slug, runtime_type, workspace_slug, cost_usd, started_at, completed_at,
 *   parent_session_id, model_id, cwd, sequence_number, external_session_id.
 *
 * REMOVED (never existed on backend schema):
 *   agentName    — not in session_schema.ex; derive from agent lookup if needed
 *   runtimeName  — not in session_schema.ex; derive from runtime lookup if needed
 *   durationMs   — not in session_schema.ex; compute locally: completedAt - startedAt
 *
 * NOTE: backend uses `completed_at` (not `ended_at`) and `parent_session_id` (not `parentId`).
 */
export interface Session {
  id: string;
  status: SessionStatus;
  agentSlug: string | null;
  runtimeType: string;
  modelId: string | null;
  workspaceSlug: string | null;
  cwd: string;
  prompt: string | null;
  promptBundleKey: string | null;
  wakeReason: string | null;
  costUsd: string;
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
  startedAt: string | null;
  completedAt: string | null;
  parentSessionId: string | null;
  sequenceNumber: number;
  externalSessionId: string | null;
  insertedAt: string;
  updatedAt: string;
}

/** Full session detail fetched on the Session Detail page */
export interface SessionDetail {
  session: Session;
  messages: TranscriptEntry[];
}

/** Create session request body */
export interface CreateSessionBody {
  agentSlug?: string;
  runtimeType: string;
  cwd: string;
  modelId?: string;
  workspaceSlug?: string;
  prompt?: string;
  parentSessionId?: string;
}

/** SSE event types from /sessions/:id/events */
export type SseStatusPayload = { status: SessionStatus };
export type SseDonePayload = { reason: string };
