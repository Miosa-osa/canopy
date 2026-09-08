/**
 * TanStack Query factories for the /agent-kanban resource.
 *
 * Mirrors the patterns in `tasks.ts`: each factory returns a query/mutation
 * options object — pass directly to `createQuery()` / `createMutation()` in
 * component scripts.
 */

import { apiGet, apiPost } from '$lib/api/client.js';
import type {
  AgentKanbanBoard,
  AgentKanbanBoardFilters,
  ClaimRequest,
  CompleteRequest,
  IdleAgent,
} from '$lib/domain/agent-kanban/types.js';
import type { Task } from '$lib/domain/tasks/types.js';

// ── Raw API calls ────────────────────────────────────────────────────────────

export function getBoard(filters?: AgentKanbanBoardFilters): Promise<AgentKanbanBoard> {
  const params = new URLSearchParams();
  if (filters?.workspaceSlug) params.set('workspace_slug', filters.workspaceSlug);
  if (filters?.limit !== undefined) params.set('limit', String(filters.limit));
  const qs = params.toString();
  return apiGet<AgentKanbanBoard>(`/agent-kanban/board${qs ? `?${qs}` : ''}`);
}

export function claimTask(body: ClaimRequest): Promise<Task> {
  return apiPost<Task>('/agent-kanban/claim', {
    agent_slug: body.agentSlug,
    task_id: body.taskId,
  });
}

export function releaseTask(taskId: string): Promise<Task> {
  return apiPost<Task>(`/agent-kanban/release/${taskId}`, {});
}

export function completeTask(taskId: string, body?: CompleteRequest): Promise<Task> {
  return apiPost<Task>(`/agent-kanban/complete/${taskId}`, {
    session_id: body?.sessionId,
  });
}

export function listIdleAgents(): Promise<IdleAgent[]> {
  return apiGet<IdleAgent[]>('/agent-kanban/idle-agents');
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for the full kanban board. */
export function agentKanbanBoardQuery(filters?: AgentKanbanBoardFilters) {
  return {
    queryKey: ['agent-kanban', 'board', filters ?? {}] as const,
    queryFn: () => getBoard(filters),
    staleTime: 10_000,
    refetchInterval: 15_000,
  };
}

/** Query options for the idle-agents rail. */
export function idleAgentsQuery() {
  return {
    queryKey: ['agent-kanban', 'idle-agents'] as const,
    queryFn: () => listIdleAgents(),
    staleTime: 15_000,
    refetchInterval: 20_000,
  };
}

/** Mutation options to manually claim a task for an agent. */
export function claimTaskMutation() {
  return {
    mutationKey: ['agent-kanban', 'claim'] as const,
    mutationFn: (body: ClaimRequest) => claimTask(body),
  };
}

/** Mutation options to release a claim back to the backlog. */
export function releaseTaskMutation() {
  return {
    mutationKey: ['agent-kanban', 'release'] as const,
    mutationFn: (taskId: string) => releaseTask(taskId),
  };
}

/** Mutation options to mark a task done. */
export function completeTaskMutation() {
  return {
    mutationKey: ['agent-kanban', 'complete'] as const,
    mutationFn: ({ taskId, sessionId }: { taskId: string; sessionId?: string }) =>
      completeTask(taskId, { sessionId }),
  };
}
