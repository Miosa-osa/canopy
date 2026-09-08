/**
 * Goal domain types — mirrors /api/v1/goals.
 * All fields camelCase; client.ts unwraps {data:...} envelopes.
 */

export type GoalStatus = 'proposed' | 'active' | 'blocked' | 'achieved' | 'cancelled';
export type GoalPriority = 'low' | 'medium' | 'high' | 'critical';

export interface Goal {
  id: string;
  shortId: string;
  workspaceSlug: string | null;
  title: string;
  description: string | null;
  successCriteria: string | null;
  status: GoalStatus;
  priority: GoalPriority;
  progress: number; // 0-100
  ownerType: string | null;
  ownerId: string | null;
  targetDate: string | null;
  achievedAt: string | null;
  cancelledAt: string | null;
  insertedAt: string;
  updatedAt: string;
}

export interface CreateGoalBody {
  title: string;
  description?: string;
  successCriteria?: string;
  status?: GoalStatus;
  priority?: GoalPriority;
  ownerType?: string;
  ownerId?: string;
  targetDate?: string;
  workspaceSlug?: string;
}

export interface UpdateGoalBody {
  title?: string;
  description?: string;
  successCriteria?: string;
  status?: GoalStatus;
  priority?: GoalPriority;
  ownerType?: string;
  ownerId?: string;
  targetDate?: string | null;
}

export interface GoalProgressBody {
  progress: number;
  note?: string;
}

export interface GoalFilters {
  workspaceSlug?: string;
  status?: GoalStatus;
}
