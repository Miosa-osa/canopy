/**
 * Session domain types — TranscriptEntry discriminated union.
 * Matches the Elixir backend structs served at /api/v1/sessions.
 */

export type SessionStatus = 'pending' | 'running' | 'paused' | 'completed' | 'cancelled' | 'error';

/** Discriminated union of all transcript entry kinds */
export type TranscriptEntry =
  | { id: string; kind: 'assistant'; text: string; createdAt: string }
  | { id: string; kind: 'thinking'; text: string; createdAt: string }
  | {
      id: string;
      kind: 'tool_call';
      toolName: string;
      args: Record<string, unknown>;
      toolCallId: string;
      createdAt: string;
    }
  | {
      id: string;
      kind: 'tool_result';
      toolCallId: string;
      content: string;
      isError: boolean;
      createdAt: string;
    }
  | {
      id: string;
      kind: 'diff';
      filePath: string;
      patch: string;
      additions: number;
      deletions: number;
      createdAt: string;
    }
  | { id: string; kind: 'stdout'; text: string; createdAt: string }
  | { id: string; kind: 'stderr'; text: string; createdAt: string }
  | { id: string; kind: 'system'; text: string; createdAt: string };

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
/**
 * Discriminator for sessions.
 *  - "terminal"            — interactive shell (default for legacy rows)
 *  - "agent_conversation"  — Build-pane agent transcript
 *
 * Rows created before the backend `kind` column shipped will surface as
 * `null`; consumers should treat that as "terminal" for legacy compatibility.
 */
export type SessionKind = 'terminal' | 'agent_conversation';

export interface Session {
  id: string;
  status: SessionStatus;
  /** Discriminates terminal vs agent conversation. May be null on legacy rows. */
  kind: SessionKind | null;
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
  /** Git worktree isolation — null when workspace is not a git repo */
  worktreePath: string | null;
  branch: string | null;
  baseBranch: string | null;
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
  /** Optional discriminator. Backend defaults to "terminal" when omitted. */
  kind?: SessionKind;
  /** Starts a live PTY-backed session; the terminal channel attaches on join. */
  interactive?: boolean;
}

/** SSE event types from /sessions/:id/events */
export type SseStatusPayload = { status: SessionStatus };
export type SseDonePayload = { reason: string };
