/**
 * TanStack Query factories for the /agents resource.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import { apiDelete, apiGet, apiPost, apiPut } from "$lib/api/client.js";
import type {
  Agent,
  AgentCategory,
  AgentDetail,
  AgentFilters,
  HireAgentBody,
} from "$lib/domain/agents/types.js";

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

export function listAgents(filters?: AgentFilters): Promise<Agent[]> {
  const params = new URLSearchParams();
  if (filters?.category) params.set("category", filters.category);
  if (filters?.query) params.set("q", filters.query);
  if (typeof filters?.hired === "boolean")
    params.set("hired", String(filters.hired));
  const qs = params.toString();
  return apiGet<Agent[]>(`/agents${qs ? `?${qs}` : ""}`);
}

export function getAgent(slug: string): Promise<AgentDetail> {
  return apiGet<AgentDetail>(`/agents/${slug}`);
}

export function hireAgent(slug: string, body?: HireAgentBody): Promise<Agent> {
  return apiPost<Agent>(`/agents/${slug}/hire`, body ?? {});
}

export function fireAgent(slug: string): Promise<void> {
  return apiDelete<void>(`/agents/${slug}/hire`);
}

export function updateAgentPersona(
  slug: string,
  personaMarkdown: string,
): Promise<AgentDetail> {
  return apiPut<AgentDetail>(`/agents/${slug}/persona`, {
    persona_markdown: personaMarkdown,
  });
}

export function createAgent(body: CreateAgentBody): Promise<AgentDetail> {
  return apiPost<AgentDetail>("/agents", body);
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for the agent library grid with optional filters. */
export function agentsQuery(filters?: AgentFilters) {
  return {
    queryKey: ["agents", filters ?? {}] as const,
    queryFn: () => listAgents(filters),
    staleTime: 30_000,
  };
}

/** Query options for a single agent detail page. */
export function agentDetailQuery(slug: string) {
  return {
    queryKey: ["agents", slug] as const,
    queryFn: () => getAgent(slug),
    staleTime: 30_000,
    enabled: Boolean(slug),
  };
}

/** Mutation options to hire an agent. */
export function hireAgentMutation() {
  return {
    mutationKey: ["agents", "hire"] as const,
    mutationFn: ({ slug, body }: { slug: string; body?: HireAgentBody }) =>
      hireAgent(slug, body),
  };
}

/** Mutation options to fire (unhire) an agent. */
export function fireAgentMutation() {
  return {
    mutationKey: ["agents", "fire"] as const,
    mutationFn: (slug: string) => fireAgent(slug),
  };
}

/** Mutation options to update an agent's persona markdown. */
export function updatePersonaMutation() {
  return {
    mutationKey: ["agents", "persona"] as const,
    mutationFn: ({
      slug,
      personaMarkdown,
    }: {
      slug: string;
      personaMarkdown: string;
    }) => updateAgentPersona(slug, personaMarkdown),
  };
}

/** Shorthand query for only hired agents — used by Composer @mention and home pinned panel. */
export function hiredAgentsQuery() {
  return agentsQuery({ hired: true });
}

/** Mutation options to create a new user-defined agent. */
export function createAgentMutation() {
  return {
    mutationKey: ["agents", "create"] as const,
    mutationFn: (body: CreateAgentBody) => createAgent(body),
  };
}

// ── Heartbeats ───────────────────────────────────────────────────────────────

/** Raw heartbeat entry returned by GET /api/v1/agents/:slug/heartbeats */
export interface AgentHeartbeat {
  id: string;
  agentSlug: string;
  sessionId: string | null;
  status: "ok" | "error" | "skipped";
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
    queryKey: ["agents", slug, "heartbeats"] as const,
    queryFn: () => listAgentHeartbeats(slug),
    staleTime: 15_000,
    enabled: Boolean(slug),
  };
}
