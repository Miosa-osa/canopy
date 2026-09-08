/**
 * Agent domain types — matches the Elixir backend at /api/v1/agents.
 * Sourced from the 336 agent personas in backend/priv/agents/.
 */

/** 19 canonical categories from the agents directory. */
export type AgentCategory =
  | 'academic'
  | 'creative-content'
  | 'design'
  | 'engineering'
  | 'executive'
  | 'game-development'
  | 'growth'
  | 'marketing'
  | 'operations'
  | 'paid-media'
  | 'product'
  | 'project-management'
  | 'revenue'
  | 'sales'
  | 'spatial-computing'
  | 'specialized'
  | 'support'
  | 'technology'
  | 'testing';

/** Agent summary for the library grid. Matches backend /api/v1/agents shape. */
export interface Agent {
  slug: string;
  name: string;
  emoji: string;
  title: string;
  category: AgentCategory;
  owner: string | null;
  bio: string;
  /** Whether the user has hired this agent. Maps 1:1 to backend `hired` bool. */
  hired: boolean;
  runCount: number;
  budget: number | null;
  defaultRuntime: string | null;
  heartbeatCron: string | null;
  tools: string[];
  personaPath?: string;
  config?: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

/** Full agent detail — includes persona markdown for the editor. */
export interface AgentDetail extends Agent {
  personaMarkdown: string;
  skills?: string[];
  contextTier?: 'l0' | 'l1' | 'l2';
}

export interface WorkspaceAgentSyncResult {
  workspaceSlug: string;
  rootPath: string;
  scanned: number;
  imported: number;
  updated: number;
  skipped: number;
  errors: Array<{ path: string; reason: string }>;
}

/** Filters applied on the library grid. */
export interface AgentFilters {
  category?: AgentCategory;
  query?: string;
  /** true = only hired agents; false = only available; undefined = all. */
  hired?: boolean;
}

/** Body for POST /api/v1/agents/:slug/hire */
export interface HireAgentBody {
  defaultRuntime?: string;
  heartbeatCron?: string;
  budget?: number;
}
