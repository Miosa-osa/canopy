/**
 * TanStack Query factories for the /tasks resource.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import { apiDelete, apiGet, apiPatch, apiPost } from '$lib/api/client.js';
import type {
  AssignBody,
  CreateTaskBody,
  Task,
  TaskFilters,
  TaskStatus,
  UpdateTaskBody,
} from '$lib/domain/tasks/types.js';
import type { TransitionVerb } from '$lib/stores/kanban-boards.svelte.js';

// ── Raw API calls ────────────────────────────────────────────────────────────

export function listTasks(filters?: TaskFilters): Promise<Task[]> {
  const params = new URLSearchParams();
  if (filters?.status) params.set('status', filters.status);
  if (filters?.assigneeType) params.set('assignee_type', filters.assigneeType);
  if (filters?.assigneeId) params.set('assignee_id', filters.assigneeId);
  if (filters?.projectSlug) params.set('project_slug', filters.projectSlug);
  if (filters?.parentId) params.set('parent_id', filters.parentId);
  if (filters?.q) params.set('q', filters.q);
  const qs = params.toString();
  return apiGet<Task[]>(`/tasks${qs ? `?${qs}` : ''}`);
}

export function getTask(shortId: string): Promise<Task> {
  return apiGet<Task>(`/tasks/${shortId}`);
}

export function createTask(body: CreateTaskBody): Promise<Task> {
  return apiPost<Task>('/tasks', body);
}

export function updateTask(shortId: string, body: UpdateTaskBody): Promise<Task> {
  return apiPatch<Task>(`/tasks/${shortId}`, body);
}

export function deleteTask(shortId: string): Promise<void> {
  return apiDelete<void>(`/tasks/${shortId}`);
}

export function completeTask(shortId: string): Promise<Task> {
  return apiPost<Task>(`/tasks/${shortId}/complete`, {});
}

export function reopenTask(shortId: string): Promise<Task> {
  return apiPost<Task>(`/tasks/${shortId}/reopen`, {});
}

export function assignTask(shortId: string, body: AssignBody): Promise<Task> {
  return apiPost<Task>(`/tasks/${shortId}/assign`, body);
}

/**
 * POST /tasks/:short_id/transition — emit a verb to the backend transition endpoint.
 * Returns the updated Task (may include session_id when verb is start/build).
 * Throws ApiError on non-2xx. Callers check status === 404 for graceful fallback.
 */
export function transitionTask(
  shortId: string,
  status: TaskStatus,
  verb: TransitionVerb
): Promise<Task> {
  return apiPost<Task>(`/tasks/${shortId}/transition`, { status, verb });
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for the task list with optional filters. */
export function tasksQuery(filters?: TaskFilters) {
  return {
    queryKey: ['tasks', filters ?? {}] as const,
    queryFn: () => listTasks(filters),
    staleTime: 15_000,
  };
}

/** Query options for a single task by short_id. */
export function taskQuery(shortId: string) {
  return {
    queryKey: ['tasks', shortId] as const,
    queryFn: () => getTask(shortId),
    staleTime: 10_000,
    enabled: Boolean(shortId),
  };
}

/** Mutation options to create a task. */
export function createTaskMutation() {
  return {
    mutationKey: ['tasks', 'create'] as const,
    mutationFn: (body: CreateTaskBody) => createTask(body),
  };
}

/** Mutation options to update a task. */
export function updateTaskMutation() {
  return {
    mutationKey: ['tasks', 'update'] as const,
    mutationFn: ({ shortId, body }: { shortId: string; body: UpdateTaskBody }) =>
      updateTask(shortId, body),
  };
}

/** Mutation options to delete a task. */
export function deleteTaskMutation() {
  return {
    mutationKey: ['tasks', 'delete'] as const,
    mutationFn: (shortId: string) => deleteTask(shortId),
  };
}

/** Mutation options to mark a task complete. */
export function completeTaskMutation() {
  return {
    mutationKey: ['tasks', 'complete'] as const,
    mutationFn: (shortId: string) => completeTask(shortId),
  };
}

/** Mutation options to reopen a completed/cancelled task. */
export function reopenTaskMutation() {
  return {
    mutationKey: ['tasks', 'reopen'] as const,
    mutationFn: (shortId: string) => reopenTask(shortId),
  };
}

/** Mutation options to assign a task to an agent or user. */
export function assignTaskMutation() {
  return {
    mutationKey: ['tasks', 'assign'] as const,
    mutationFn: ({ shortId, body }: { shortId: string; body: AssignBody }) =>
      assignTask(shortId, body),
  };
}
