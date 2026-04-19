/**
 * TanStack Query factories for the /skills resource.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 *
 * Backend endpoints:
 *   GET  /api/v1/skills          — list (filter: ?source=, ?enabled=, ?tag=)
 *   GET  /api/v1/skills/:slug    — detail
 *   POST /api/v1/skills/import   — bulk import from registry {source}
 *
 * There is no standalone POST /api/v1/skills create endpoint.
 * "Create local skill" is not supported by the current backend.
 */

import { apiGet, apiPost, apiPut } from "$lib/api/client.js";
import type {
  CreateSkillBody,
  ImportSkillBody,
  ImportSkillResponse,
  Skill,
  SkillFilters,
} from "$lib/domain/skills/types.js";

// ── Raw API calls ────────────────────────────────────────────────────────────

export function listSkills(filters?: SkillFilters): Promise<Skill[]> {
  const params = new URLSearchParams();
  if (filters?.source) params.set("source", filters.source);
  if (typeof filters?.enabled === "boolean")
    params.set("enabled", String(filters.enabled));
  if (filters?.tag) params.set("tag", filters.tag);
  const qs = params.toString();
  return apiGet<Skill[]>(`/skills${qs ? `?${qs}` : ""}`);
}

export function getSkill(slug: string): Promise<Skill> {
  return apiGet<Skill>(`/skills/${slug}`);
}

/**
 * Bulk import from an external registry (clawhub or skills_sh).
 * POST /api/v1/skills/import { source }
 */
export function importSkills(
  body: ImportSkillBody,
): Promise<ImportSkillResponse> {
  return apiPost<ImportSkillResponse>("/skills/import", body);
}

/**
 * Update a skill's content/metadata.
 * PUT /api/v1/skills/:slug — used by the detail page ⌘S save flow.
 */
export function updateSkill(
  slug: string,
  body: Partial<CreateSkillBody>,
): Promise<Skill> {
  return apiPut<Skill>(`/skills/${slug}`, body);
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for the skills list with optional filters. */
export function skillsQuery(filters?: SkillFilters) {
  return {
    queryKey: ["skills", filters ?? {}] as const,
    queryFn: () => listSkills(filters),
    staleTime: 30_000,
  };
}

/** Query options for a single skill detail page. */
export function skillQuery(slug: string) {
  return {
    queryKey: ["skills", slug] as const,
    queryFn: () => getSkill(slug),
    staleTime: 30_000,
    enabled: Boolean(slug),
  };
}

/**
 * Mutation options for bulk importing from an external registry.
 * Body: { source: "clawhub" | "skills_sh" }
 */
export function importSkillMutation() {
  return {
    mutationKey: ["skills", "import"] as const,
    mutationFn: (body: ImportSkillBody) => importSkills(body),
  };
}

/** Mutation options to update a skill's content/metadata. */
export function updateSkillMutation() {
  return {
    mutationKey: ["skills", "update"] as const,
    mutationFn: ({
      slug,
      body,
    }: {
      slug: string;
      body: Partial<CreateSkillBody>;
    }) => updateSkill(slug, body),
  };
}
