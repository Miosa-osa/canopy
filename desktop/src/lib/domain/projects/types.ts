/**
 * Project domain types — mirrors /api/v1/projects.
 * All fields camelCase; client.ts unwraps {data:...} envelopes.
 */

export type ProjectStatus = "active" | "paused" | "archived";
export type ProjectOwnerType = "agent" | "human";

export interface Project {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  workspaceSlug: string;
  status: ProjectStatus;
  color: string | null;
  icon: string | null;
  ownerType: ProjectOwnerType | null;
  ownerId: string | null;
  targetDate: string | null;
  archivedAt: string | null;
  insertedAt: string;
  updatedAt: string;
}

export interface ProjectSummary {
  project: Project;
  issuesCount: number;
  tasksCount: number;
  goalsCount: number;
  sessionsCount: number;
}

export interface CreateProjectBody {
  name: string;
  workspaceSlug: string;
  slug?: string;
  description?: string;
  status?: ProjectStatus;
  color?: string;
  icon?: string;
  ownerType?: ProjectOwnerType;
  ownerId?: string;
  targetDate?: string;
}

export interface UpdateProjectBody {
  name?: string;
  description?: string;
  status?: ProjectStatus;
  color?: string;
  icon?: string;
  ownerType?: ProjectOwnerType;
  ownerId?: string;
  targetDate?: string | null;
}

export interface ProjectFilters {
  workspaceSlug?: string;
  status?: ProjectStatus;
  limit?: number;
}
