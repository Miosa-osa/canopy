/**
 * Task domain types — mirrors the Elixir backend at /api/v1/tasks.
 * All fields are camelCase; the client.ts fetch wrapper unwraps {data: ...} envelopes.
 */

/** Valid task statuses. */
export type TaskStatus = 'todo' | 'in_progress' | 'done' | 'cancelled';

/**
 * Priority level 0–3.
 *   0 = none, 1 = low, 2 = medium, 3 = high
 */
export type TaskPriority = 0 | 1 | 2 | 3;

/** Task summary — used in list responses and mutation returns. */
export interface Task {
  id: string;
  /** Human-readable short ID, e.g. "T-12345678". */
  shortId: string;
  title: string;
  description: string | null;
  status: TaskStatus;
  priority: TaskPriority;
  assigneeType: string | null;
  assigneeId: string | null;
  projectSlug: string | null;
  workspaceSlug: string | null;
  dueAt: string | null;
  completedAt: string | null;
  labels: string[];
  parentId: string | null;
  /** Non-null when a governance rule queued this task for human review. */
  reviewId: string | null;
  insertedAt: string;
  updatedAt: string;
}

/** Filter params accepted by GET /tasks. */
export interface TaskFilters {
  status?: TaskStatus;
  assigneeType?: string;
  assigneeId?: string;
  projectSlug?: string;
  parentId?: string;
  q?: string;
}

/** Body for POST /tasks. */
export interface CreateTaskBody {
  title: string;
  description?: string;
  status?: TaskStatus;
  priority?: TaskPriority;
  assigneeType?: string;
  assigneeId?: string;
  projectSlug?: string;
  workspaceSlug?: string;
  dueAt?: string;
  labels?: string[];
  parentId?: string;
}

/** Body for PATCH /tasks/:short_id. */
export interface UpdateTaskBody {
  title?: string;
  description?: string;
  status?: TaskStatus;
  priority?: TaskPriority;
  assigneeType?: string;
  assigneeId?: string;
  projectSlug?: string;
  workspaceSlug?: string;
  dueAt?: string | null;
  labels?: string[];
}

/** Body for POST /tasks/:short_id/assign. */
export interface AssignBody {
  assigneeType: string;
  assigneeId: string;
}
