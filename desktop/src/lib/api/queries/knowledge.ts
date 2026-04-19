/**
 * TanStack Query factories for the /knowledge-bases resource.
 * Phase 5 Wave 2 Track #105.
 *
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import { apiDelete, apiGet, apiPost } from "$lib/api/client.js";
import type {
  AddFileBody,
  CreateBaseBody,
  IndexResult,
  KbAssignment,
  KbChunk,
  KbChunkListResponse,
  KnowledgeBase,
  SearchBody,
  SearchResponse,
} from "$lib/domain/knowledge/types.js";

// ── Raw API calls ────────────────────────────────────────────────────────────

export function listBases(filters?: {
  workspace?: string;
  archived?: boolean;
}): Promise<KnowledgeBase[]> {
  const params = new URLSearchParams();
  if (filters?.workspace) params.set("workspace", filters.workspace);
  if (typeof filters?.archived === "boolean")
    params.set("archived", String(filters.archived));
  const qs = params.toString();
  return apiGet<KnowledgeBase[]>(`/knowledge-bases${qs ? `?${qs}` : ""}`);
}

export function getBase(slug: string): Promise<KnowledgeBase> {
  return apiGet<KnowledgeBase>(`/knowledge-bases/${slug}`);
}

export function createBase(body: CreateBaseBody): Promise<KnowledgeBase> {
  return apiPost<KnowledgeBase>("/knowledge-bases", body);
}

export function archiveBase(slug: string): Promise<KnowledgeBase> {
  return apiDelete<KnowledgeBase>(`/knowledge-bases/${slug}`);
}

export function addFileToBase(
  slug: string,
  body: AddFileBody,
): Promise<IndexResult> {
  return apiPost<IndexResult>(`/knowledge-bases/${slug}/files`, body);
}

export function listChunks(
  slug: string,
  limit = 50,
  offset = 0,
): Promise<KbChunkListResponse> {
  return apiGet<KbChunkListResponse>(
    `/knowledge-bases/${slug}/chunks?limit=${limit}&offset=${offset}`,
  );
}

export function searchBase(
  slug: string,
  body: SearchBody,
): Promise<SearchResponse> {
  return apiPost<SearchResponse>(`/knowledge-bases/${slug}/search`, body);
}

export function assignAgent(
  slug: string,
  agentSlug: string,
): Promise<KbAssignment> {
  return apiPost<KbAssignment>(`/knowledge-bases/${slug}/assignments`, {
    agent_slug: agentSlug,
  });
}

export function unassignAgent(slug: string, agentSlug: string): Promise<void> {
  return apiDelete<void>(`/knowledge-bases/${slug}/assignments/${agentSlug}`);
}

export function rebuildIndex(slug: string): Promise<IndexResult> {
  return apiPost<IndexResult>(`/knowledge-bases/${slug}/rebuild`, {});
}

export function listAssignments(slug: string): Promise<KbAssignment[]> {
  // Assignments are embedded in the show response; this helper re-fetches
  // the list from the assignments sub-resource via show + parse.
  // The backend exposes assignments through the KB show + a dedicated path;
  // for the UI we fetch show and derive assignment count from agent_count.
  return apiGet<KbAssignment[]>(`/knowledge-bases/${slug}/assignments`);
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for the KB list page with optional filters. */
export function knowledgeBasesQuery(filters?: {
  workspace?: string;
  archived?: boolean;
}) {
  return {
    queryKey: ["knowledge-bases", filters ?? {}] as const,
    queryFn: () => listBases(filters),
    staleTime: 30_000,
  };
}

/** Query options for a single KB detail page. */
export function knowledgeBaseQuery(slug: string) {
  return {
    queryKey: ["knowledge-bases", slug] as const,
    queryFn: () => getBase(slug),
    staleTime: 30_000,
    enabled: Boolean(slug),
  };
}

/** Query options for the chunk list (paginated). */
export function kbChunksQuery(slug: string, limit = 50, offset = 0) {
  return {
    queryKey: ["knowledge-bases", slug, "chunks", limit, offset] as const,
    queryFn: () => listChunks(slug, limit, offset),
    staleTime: 60_000,
    enabled: Boolean(slug),
  };
}

/** Mutation options to create a KB. */
export function createBaseMutation() {
  return {
    mutationKey: ["knowledge-bases", "create"] as const,
    mutationFn: (body: CreateBaseBody) => createBase(body),
  };
}

/** Mutation options to archive (soft-delete) a KB. */
export function archiveBaseMutation() {
  return {
    mutationKey: ["knowledge-bases", "archive"] as const,
    mutationFn: (slug: string) => archiveBase(slug),
  };
}

/** Mutation options to add a file to a KB. */
export function addFileMutation() {
  return {
    mutationKey: ["knowledge-bases", "add-file"] as const,
    mutationFn: ({ slug, body }: { slug: string; body: AddFileBody }) =>
      addFileToBase(slug, body),
  };
}

/** Mutation options to search a KB. */
export function searchMutation() {
  return {
    mutationKey: ["knowledge-bases", "search"] as const,
    mutationFn: ({ slug, body }: { slug: string; body: SearchBody }) =>
      searchBase(slug, body),
  };
}

/** Mutation options to assign an agent to a KB. */
export function assignAgentMutation() {
  return {
    mutationKey: ["knowledge-bases", "assign"] as const,
    mutationFn: ({ slug, agentSlug }: { slug: string; agentSlug: string }) =>
      assignAgent(slug, agentSlug),
  };
}

/** Mutation options to remove an agent from a KB. */
export function unassignAgentMutation() {
  return {
    mutationKey: ["knowledge-bases", "unassign"] as const,
    mutationFn: ({ slug, agentSlug }: { slug: string; agentSlug: string }) =>
      unassignAgent(slug, agentSlug),
  };
}

/** Mutation options to trigger a full KB rebuild. */
export function rebuildIndexMutation() {
  return {
    mutationKey: ["knowledge-bases", "rebuild"] as const,
    mutationFn: (slug: string) => rebuildIndex(slug),
  };
}

/** Query options for chunk search results (query-based). */
export function kbSearchQuery(slug: string, query: string, limit = 5) {
  return {
    queryKey: ["knowledge-bases", slug, "search", query, limit] as const,
    queryFn: () => searchBase(slug, { query, limit }),
    staleTime: 10_000,
    enabled: Boolean(slug) && Boolean(query),
  };
}
