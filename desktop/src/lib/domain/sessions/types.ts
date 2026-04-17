/**
 * Session domain types — TranscriptEntry discriminated union from Paperclip lift.
 * Matches the Elixir backend structs served at /api/v1/sessions.
 */

export type SessionStatus = 'pending' | 'running' | 'paused' | 'completed' | 'cancelled' | 'error';

/** Discriminated union of all transcript entry kinds (Paperclip §7 lift) */
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

/** Session summary — shown in list rows */
export interface Session {
  id: string;
  status: SessionStatus;
  agentSlug: string;
  agentName: string;
  runtimeType: string;
  runtimeName: string;
  workspaceSlug: string | null;
  durationMs: number | null;
  costUsd: number;
  startedAt: string;
  endedAt: string | null;
  parentId: string | null;
}

/** Full session detail fetched on the Session Detail page */
export interface SessionDetail extends Session {
  prompt: string;
  skillsInjected: string[];
  sandboxId: string | null;
  sandboxUrl: string | null;
  governanceMode: 'auto_approved' | 'manual_approval' | 'blocked';
}

/** Create session request body */
export interface CreateSessionBody {
  agentSlug: string;
  runtimeType: string;
  workspaceSlug?: string;
  prompt: string;
}

/** SSE event types from /sessions/:id/events */
export type SseStatusPayload = { status: SessionStatus };
export type SseDonePayload = { reason: string };
