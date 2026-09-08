/**
 * Agent Kanban domain types — mirrors the Elixir backend at
 * /api/v1/agent-kanban/*. All fields are camelCase; the API client unwraps
 * the {data: ...} envelope.
 *
 * The four-column model maps to:
 *   backlog     — unclaimed tasks (status in todo / in_progress, no claim)
 *   claimed     — claimed but no live session yet
 *   inProgress  — claimed AND has an active session
 *   done        — terminal status
 */

import type { Task } from '$lib/domain/tasks/types.js';

/** Kanban column key — matches the backend `kanban_column` type. */
export type AgentKanbanColumn = 'backlog' | 'claimed' | 'in_progress' | 'done';

/** Server response shape for GET /agent-kanban/board. */
export interface AgentKanbanBoard {
  backlog: Task[];
  claimed: Task[];
  in_progress: Task[];
  done: Task[];
}

/** Filters accepted by GET /agent-kanban/board. */
export interface AgentKanbanBoardFilters {
  workspaceSlug?: string;
  limit?: number;
}

/** Body for POST /agent-kanban/claim. */
export interface ClaimRequest {
  agentSlug: string;
  taskId: string;
}

/** Body for POST /agent-kanban/complete/:task_id. */
export interface CompleteRequest {
  sessionId?: string;
}

/** Idle agent row from GET /agent-kanban/idle-agents. */
export interface IdleAgent {
  slug: string;
  name: string;
  category: string;
  capabilities: string[];
  activeSessionCount: number;
  autoPickupEnabled: boolean;
}

/** UI-only column descriptor — pairs the column key with a human label. */
export interface ColumnDescriptor {
  key: AgentKanbanColumn;
  label: string;
}

/** Static column ordering used by the pane. */
export const KANBAN_COLUMNS: ColumnDescriptor[] = [
  { key: 'backlog', label: 'Backlog' },
  { key: 'claimed', label: 'Claimed' },
  { key: 'in_progress', label: 'In Progress' },
  { key: 'done', label: 'Done' },
];
