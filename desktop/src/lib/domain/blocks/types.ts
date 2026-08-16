/**
 * Block primitive — domain types.
 *
 * Mirrors the Elixir backend struct at /api/v1/sessions/:session_id/blocks/*.
 * Keys arrive camelCased via the client conversion layer.
 *
 * Coexists beside SessionMessage (flat append-only transcript). A Block is a
 * higher-level discrete navigable unit: command + output, agent message with
 * its tool-calls nested, an approval card, etc.
 */

export type BlockKind =
  | "command"
  | "agent_message"
  | "tool_call"
  | "tool_result"
  | "approval"
  | "diff"
  | "system_event"
  | "error";

export type BlockStatus =
  | "running"
  | "completed"
  | "failed"
  | "cancelled"
  | "pending_approval";

/** Single Block row — see backend `Canopy.Sessions.Block`. */
export interface Block {
  id: string;
  sessionId: string;
  parentBlockId: string | null;
  sequence: number;
  kind: BlockKind;
  status: BlockStatus;
  inputText: string | null;
  outputText: string | null;
  exitCode: number | null;
  startedAt: string | null;
  endedAt: string | null;
  durationMs: number | null;
  costCents: number | null;
  metadata: Record<string, unknown>;
  tags: string[];
  insertedAt: string;
  updatedAt: string;
}

/** List response shape — matches BlocksController.index. */
export interface BlockList {
  sessionId: string;
  count: number;
  data: Block[];
}

/** Filters for `/blocks` index. */
export interface BlockListQuery {
  kind?: BlockKind;
  status?: BlockStatus;
  parentBlockId?: string;
  since?: string;
  limit?: number;
}

/** Filters for `/blocks/search`. */
export interface BlockSearchQuery {
  q?: string;
  kind?: BlockKind;
  status?: BlockStatus;
  tag?: string;
  limit?: number;
}

/** All block kinds — useful for icon-map / pill-color tables. */
export const BLOCK_KINDS: readonly BlockKind[] = [
  "command",
  "agent_message",
  "tool_call",
  "tool_result",
  "approval",
  "diff",
  "system_event",
  "error",
] as const;

/** All block statuses. */
export const BLOCK_STATUSES: readonly BlockStatus[] = [
  "running",
  "completed",
  "failed",
  "cancelled",
  "pending_approval",
] as const;
