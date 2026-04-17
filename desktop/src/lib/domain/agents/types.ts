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

/** Hire status reflects whether the user has activated this agent. */
export type AgentHireStatus = 'hired' | 'available';

/** Agent summary for the library grid. */
export interface Agent {
  slug: string;
  name: string;
  emoji: string;
  title: string;
  category: AgentCategory;
  owner: string | null;
  bio: string;
  hireStatus: AgentHireStatus;
  runCount: number;
  budget: number | null;
  defaultRuntime: string | null;
  heartbeatCron: string | null;
  tools: string[];
  createdAt: string;
  updatedAt: string;
}

/** Full agent detail — includes persona markdown for the editor. */
export interface AgentDetail extends Agent {
  personaMarkdown: string;
  skills: string[];
  contextTier: 'l0' | 'l1' | 'l2';
}

/** Filters applied on the library grid. */
export interface AgentFilters {
  category?: AgentCategory;
  query?: string;
  hireStatus?: AgentHireStatus;
}

/** Body for POST /api/v1/agents/:slug/hire */
export interface HireAgentBody {
  defaultRuntime?: string;
  heartbeatCron?: string;
  budget?: number;
}
