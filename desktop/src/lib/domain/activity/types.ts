/**
 * Activity domain types — maps 1:1 to GET /api/v1/activity response.
 * No `any`. Explicit union of all known event types.
 */

export type ActivityEventType =
  | "session_started"
  | "session_ended"
  | "session_paused"
  | "session_resumed"
  | "session_cancelled"
  | "session_error"
  | "task_dispatched"
  | "task_completed"
  | "task_failed"
  | "issue_opened"
  | "issue_closed"
  | "issue_updated"
  | "agent_registered"
  | "runtime_created"
  | "runtime_deleted"
  | "workspace_created"
  | "workspace_updated";

export type ActorType = "agent" | "human" | "system";

export interface ActivityEvent {
  id: string;
  type: ActivityEventType;
  session_id: string | null;
  task_id: string | null;
  issue_id: string | null;
  workspace_slug: string;
  actor_type: ActorType;
  actor_id: string;
  title: string;
  preview: string | null;
  wake_reason: string | null;
  at: string; // ISO 8601
}

export interface ActivityResponse {
  count: number;
  data: ActivityEvent[];
}

export interface ActivityFilters {
  workspace_slug?: string;
  type?: ActivityEventType[];
  limit?: number;
  after?: string; // ISO 8601 — for date range lower bound
  before?: string; // ISO 8601 — for date range upper bound
}
