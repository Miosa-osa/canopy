/**
 * Issue domain types — mirrors the Elixir backend at /api/v1/issues.
 * Developer persona. Identifier pattern: I-XXXXXXXX.
 * All fields are camelCase; the client.ts fetch wrapper unwraps {data: ...} envelopes.
 */

/** Valid issue statuses — linear-style developer workflow. */
export type IssueStatus =
  | "backlog"
  | "open"
  | "in_progress"
  | "in_review"
  | "closed";

/**
 * Priority level 0–3.
 *   0 = none, 1 = low, 2 = medium, 3 = high
 */
export type IssuePriority = 0 | 1 | 2 | 3;

/** Assignee type. */
export type IssueAssigneeType = "agent" | "human";

/** Label — optional colour for rendering chips. */
export interface IssueLabel {
  id: string;
  name: string;
  color?: string;
}

/** Issue summary — used in list responses and mutation returns. */
export interface Issue {
  id: string;
  /** Human-readable short ID, e.g. "I-12345678". */
  shortId: string;
  title: string;
  description: string | null;
  status: IssueStatus;
  priority: IssuePriority;
  assigneeType: IssueAssigneeType | null;
  assigneeId: string | null;
  /** Git branch associated with this issue. */
  branch: string | null;
  /** Pull-request URL. */
  prUrl: string | null;
  /** Estimated work in minutes. */
  estimateMinutes: number | null;
  labels: IssueLabel[];
  parentId: string | null;
  workspaceSlug: string | null;
  dueAt: string | null;
  insertedAt: string;
  updatedAt: string;
  /** Session created if dispatch was triggered. */
  sessionId?: string | null;
  /** Non-null when a governance rule queued this issue for human review. */
  reviewId?: string | null;
}

/** Filter params accepted by GET /issues. */
export interface IssueFilters {
  status?: IssueStatus;
  assigneeId?: string;
  assigneeType?: IssueAssigneeType;
  label?: string;
  workspaceSlug?: string;
  q?: string;
}

/** Body for POST /issues. */
export interface CreateIssueBody {
  title: string;
  description?: string;
  status?: IssueStatus;
  priority?: IssuePriority;
  assigneeType?: IssueAssigneeType;
  assigneeId?: string;
  branch?: string;
  prUrl?: string;
  estimateMinutes?: number;
  labels?: string[];
  parentId?: string;
  workspaceSlug?: string;
  dueAt?: string;
}

/** Body for PATCH /issues/:short_id. */
export interface UpdateIssueBody {
  title?: string;
  description?: string;
  status?: IssueStatus;
  priority?: IssuePriority;
  assigneeType?: IssueAssigneeType | null;
  assigneeId?: string | null;
  branch?: string | null;
  prUrl?: string | null;
  estimateMinutes?: number | null;
  labels?: string[];
  dueAt?: string | null;
}

/** Body for POST /issues/:short_id/assign. */
export interface AssignIssueBody {
  assigneeType: IssueAssigneeType;
  assigneeId: string;
}
