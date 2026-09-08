/**
 * Routine domain types — mirrors /api/v1/routines.
 * All fields camelCase; client.ts unwraps {data:...} envelopes.
 */

export type RoutineStatus = 'active' | 'paused' | 'archived';
export type RoutineCreates = 'task' | 'issue' | 'goal';

export interface Routine {
  id: string;
  shortId: string;
  workspaceSlug: string | null;
  name: string;
  description: string | null;
  cron: string | null;
  promptTemplate: string | null;
  creates: RoutineCreates;
  targetAgentSlug: string | null;
  status: RoutineStatus;
  enabled: boolean;
  nextRunAt: string | null;
  lastRunAt: string | null;
  runCount: number;
  insertedAt: string;
  updatedAt: string;
}

export interface CreateRoutineBody {
  name: string;
  description?: string;
  cron?: string;
  promptTemplate?: string;
  creates?: RoutineCreates;
  targetAgentSlug?: string;
  workspaceSlug?: string;
  enabled?: boolean;
}

export interface UpdateRoutineBody {
  name?: string;
  description?: string;
  cron?: string;
  promptTemplate?: string;
  creates?: RoutineCreates;
  targetAgentSlug?: string;
  enabled?: boolean;
}

export interface RoutineFilters {
  workspaceSlug?: string;
}
