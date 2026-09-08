/**
 * TanStack Query factories for the /agents resource.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import { apiDelete, apiGet, apiPatch, apiPost, apiPut } from '$lib/api/client.js';
import { listSessions } from '$lib/api/queries/sessions.js';
import type {
  Agent,
  AgentCategory,
  AgentDetail,
  AgentFilters,
  HireAgentBody,
  WorkspaceAgentSyncResult,
} from '$lib/domain/agents/types.js';

/** Body for POST /api/v1/agents — user-defined agent creation. */
export interface CreateAgentBody {
  slug: string;
  name: string;
  category: AgentCategory;
  description?: string;
  persona_markdown?: string;
  default_runtime?: string;
  default_model?: string;
  tools?: string[];
  heartbeat_cron?: string;
}

// ── Raw API calls ────────────────────────────────────────────────────────────

type ApiAgent = Partial<Agent> & {
  skills?: string[];
  contextTier?: AgentDetail['contextTier'];
  description?: string | null;
  budgetMonthlyUsd?: string | number | null;
  personaMarkdown?: string | null;
  personaContent?: string | null;
  config?: Record<string, unknown>;
  insertedAt?: string;
  updatedAt?: string;
};

function stringConfig(config: Record<string, unknown> | undefined, key: string): string | null {
  const value = config?.[key];
  return typeof value === 'string' && value.trim() ? value : null;
}

function listConfig(config: Record<string, unknown> | undefined, key: string): string[] {
  const value = config?.[key];
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is string => typeof item === 'string' && item.trim().length > 0);
}

function parseBudget(value: string | number | null | undefined): number | null {
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  if (typeof value !== 'string') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function excerpt(markdown: string | null | undefined): string {
  if (!markdown) return '';
  return markdown
    .replace(/^---[\s\S]*?---/, '')
    .replace(/```[\s\S]*?```/g, ' ')
    .replace(/^#+\s+/gm, '')
    .replace(/[*_`>#|-]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 220);
}

function normalizeAgent(agent: ApiAgent): Agent {
  const config = agent.config ?? {};
  const persona = agent.personaMarkdown ?? agent.personaContent ?? '';
  const description = agent.description ?? null;
  const now = new Date().toISOString();

  return {
    slug: agent.slug ?? stringConfig(config, 'id') ?? 'unknown-agent',
    name: agent.name ?? stringConfig(config, 'title') ?? agent.slug ?? 'Unknown Agent',
    emoji: agent.emoji ?? stringConfig(config, 'emoji') ?? '🤖',
    title:
      agent.title ??
      stringConfig(config, 'title') ??
      stringConfig(config, 'role') ??
      agent.name ??
      agent.slug ??
      'Agent',
    category: (agent.category ?? 'specialized') as AgentCategory,
    owner: agent.owner ?? stringConfig(config, 'reportsTo'),
    bio: agent.bio ?? description ?? excerpt(persona),
    hired: agent.hired ?? false,
    runCount: agent.runCount ?? 0,
    budget: agent.budget ?? parseBudget(agent.budgetMonthlyUsd),
    defaultRuntime: agent.defaultRuntime ?? null,
    heartbeatCron: agent.heartbeatCron ?? null,
    tools: agent.tools ?? listConfig(config, 'tools'),
    personaPath: agent.personaPath ?? stringConfig(config, 'persona_path') ?? undefined,
    config,
    createdAt: agent.createdAt ?? agent.insertedAt ?? now,
    updatedAt: agent.updatedAt ?? now,
  };
}

function matchesClientFilters(agent: Agent, filters?: AgentFilters): boolean {
  if (filters?.category && agent.category !== filters.category) return false;
  if (typeof filters?.hired === 'boolean' && agent.hired !== filters.hired) return false;
  if (!filters?.query?.trim()) return true;

  const query = filters.query.trim().toLowerCase();
  return [
    agent.slug,
    agent.name,
    agent.title,
    agent.category,
    agent.owner ?? '',
    agent.bio,
    String(agent.config?.team ?? ''),
    String(agent.config?.department ?? ''),
    String(agent.config?.division ?? ''),
  ].some((value) => value.toLowerCase().includes(query));
}

export async function listAgents(filters?: AgentFilters): Promise<Agent[]> {
  const params = new URLSearchParams();
  if (filters?.category) params.set('category', filters.category);
  if (filters?.query) params.set('q', filters.query);
  if (typeof filters?.hired === 'boolean') params.set('hired', String(filters.hired));
  const qs = params.toString();
  const agents = await apiGet<ApiAgent[]>(`/agents${qs ? `?${qs}` : ''}`);
  return agents.map(normalizeAgent).filter((agent) => matchesClientFilters(agent, filters));
}

export async function getAgent(slug: string): Promise<AgentDetail> {
  const agent = await apiGet<ApiAgent>(`/agents/${slug}`);
  const normalized = normalizeAgent(agent);
  return {
    ...normalized,
    personaMarkdown: agent.personaMarkdown ?? agent.personaContent ?? '',
    skills: agent.skills ?? listConfig(agent.config, 'skills'),
    contextTier:
      (agent.contextTier as AgentDetail['contextTier']) ??
      (stringConfig(agent.config, 'context_tier') as AgentDetail['contextTier']) ??
      undefined,
  };
}

export function hireAgent(slug: string, body?: HireAgentBody): Promise<Agent> {
  return apiPost<Agent>(`/agents/${slug}/hire`, body ?? {});
}

export function fireAgent(slug: string): Promise<void> {
  return apiDelete<void>(`/agents/${slug}/hire`);
}

export function updateAgentPersona(slug: string, personaMarkdown: string): Promise<AgentDetail> {
  return apiPut<AgentDetail>(`/agents/${slug}/persona`, {
    persona_markdown: personaMarkdown,
  });
}

export function createAgent(body: CreateAgentBody): Promise<AgentDetail> {
  return apiPost<AgentDetail>('/agents', body);
}

export function syncWorkspaceAgents(workspaceSlug: string): Promise<WorkspaceAgentSyncResult> {
  return apiPost<WorkspaceAgentSyncResult>(`/workspaces/${workspaceSlug}/agents/sync`, {});
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for the agent library grid with optional filters. */
export function agentsQuery(filters?: AgentFilters) {
  return {
    queryKey: ['agents', filters ?? {}] as const,
    queryFn: () => listAgents(filters),
    staleTime: 30_000,
  };
}

/** Query options for a single agent detail page. */
export function agentDetailQuery(slug: string) {
  return {
    queryKey: ['agents', slug] as const,
    queryFn: () => getAgent(slug),
    staleTime: 30_000,
    enabled: Boolean(slug),
  };
}

/** Mutation options to hire an agent. */
export function hireAgentMutation() {
  return {
    mutationKey: ['agents', 'hire'] as const,
    mutationFn: ({ slug, body }: { slug: string; body?: HireAgentBody }) => hireAgent(slug, body),
  };
}

/** Mutation options to fire (unhire) an agent. */
export function fireAgentMutation() {
  return {
    mutationKey: ['agents', 'fire'] as const,
    mutationFn: (slug: string) => fireAgent(slug),
  };
}

/** Mutation options to update an agent's persona markdown. */
export function updatePersonaMutation() {
  return {
    mutationKey: ['agents', 'persona'] as const,
    mutationFn: ({ slug, personaMarkdown }: { slug: string; personaMarkdown: string }) =>
      updateAgentPersona(slug, personaMarkdown),
  };
}

/** Shorthand query for only hired agents — used by Composer @mention and home pinned panel. */
export function hiredAgentsQuery() {
  return agentsQuery({ hired: true });
}

/** Mutation options to create a new user-defined agent. */
export function createAgentMutation() {
  return {
    mutationKey: ['agents', 'create'] as const,
    mutationFn: (body: CreateAgentBody) => createAgent(body),
  };
}

/** Mutation options to import workspace-local markdown agents. */
export function syncWorkspaceAgentsMutation() {
  return {
    mutationKey: ['agents', 'workspace-sync'] as const,
    mutationFn: (workspaceSlug: string) => syncWorkspaceAgents(workspaceSlug),
  };
}

// ── Config blob (capabilities, guardrails, skills, KBs) ─────────────────────

/**
 * PATCH /api/v1/agents/:slug/config — persists the config jsonb blob.
 * NOTE: This endpoint may not exist yet on the backend. The UI falls back to
 * localStorage when a 404 is received; a "Local draft" banner is shown.
 */
export function updateAgentConfig(
  slug: string,
  config: Record<string, unknown>
): Promise<AgentDetail> {
  return apiPatch<AgentDetail>(`/agents/${slug}/config`, { config });
}

/** Mutation options for PATCH /agents/:slug/config (capabilities, guardrails, etc.). */
export function updateAgentConfigMutation() {
  return {
    mutationKey: ['agents', 'config'] as const,
    mutationFn: ({ slug, config }: { slug: string; config: Record<string, unknown> }) =>
      updateAgentConfig(slug, config),
  };
}

/** Query options for sessions scoped to a specific agent slug. */
export function agentSessionsQuery(agentSlug: string) {
  return {
    queryKey: ['sessions', { agentSlug }] as const,
    // Use static import (moved to top of file) to avoid Vite HMR stale-module
    // cache hitting this dynamic boundary and returning undefined.default.
    queryFn: () => listSessions({ agentSlug, limit: 20 }),
    staleTime: 15_000,
    enabled: Boolean(agentSlug),
  };
}

// ── Heartbeats ───────────────────────────────────────────────────────────────

/** Raw heartbeat entry returned by GET /api/v1/agents/:slug/heartbeats */
export interface AgentHeartbeat {
  id: string;
  agentSlug: string;
  sessionId: string | null;
  status: 'ok' | 'error' | 'skipped';
  message: string | null;
  occurredAt: string;
  insertedAt: string;
}

export function listAgentHeartbeats(slug: string): Promise<AgentHeartbeat[]> {
  return apiGet<AgentHeartbeat[]>(`/agents/${slug}/heartbeats`);
}

/**
 * Query options for an agent's heartbeat history.
 * Backend: GET /api/v1/agents/:slug/heartbeats
 */
export function agentHeartbeatsQuery(slug: string) {
  return {
    queryKey: ['agents', slug, 'heartbeats'] as const,
    queryFn: () => listAgentHeartbeats(slug),
    staleTime: 15_000,
    enabled: Boolean(slug),
  };
}
