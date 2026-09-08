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

import { apiGet, apiPost, apiPut } from '$lib/api/client.js';
import { LOCAL_SKILLS } from '$lib/data/local-skills.js';
import type {
  CreateSkillBody,
  ImportSkillBody,
  ImportSkillResponse,
  Skill,
  SkillFilters,
} from '$lib/domain/skills/types.js';

// ── Raw API calls ────────────────────────────────────────────────────────────

function applyLocalFilters(skills: Skill[], filters?: SkillFilters): Skill[] {
  return skills.filter((skill) => {
    if (filters?.source && skill.source !== filters.source) return false;
    if (typeof filters?.enabled === 'boolean' && skill.enabled !== filters.enabled) return false;
    if (filters?.tag && !skill.tags.includes(filters.tag)) return false;
    if (filters?.kind && skill.kind !== filters.kind) return false;
    return true;
  });
}

function mergeSkills(remoteSkills: Skill[], localSkills: Skill[]): Skill[] {
  return [
    ...remoteSkills,
    ...localSkills.filter(
      (local) =>
        !remoteSkills.some((remote) => remote.slug === local.slug || remote.id === local.id)
    ),
  ].sort((a, b) => a.name.localeCompare(b.name));
}

export async function listSkills(filters?: SkillFilters): Promise<Skill[]> {
  const params = new URLSearchParams();
  if (filters?.source) params.set('source', filters.source);
  if (typeof filters?.enabled === 'boolean') params.set('enabled', String(filters.enabled));
  if (filters?.tag) params.set('tag', filters.tag);
  if (filters?.kind) params.set('kind', filters.kind);
  const qs = params.toString();
  const remoteSkills = await apiGet<Skill[]>(`/skills${qs ? `?${qs}` : ''}`, {
    rawKeys: true,
  });
  return mergeSkills(remoteSkills, applyLocalFilters(LOCAL_SKILLS, filters));
}

export async function getSkill(slug: string): Promise<Skill> {
  const localSkill = LOCAL_SKILLS.find((skill) => skill.slug === slug);
  if (localSkill) return localSkill;
  return apiGet<Skill>(`/skills/${slug}`, { rawKeys: true });
}

/**
 * Bulk import from an external registry (clawhub or skills_sh).
 * POST /api/v1/skills/import { source }
 */
export function importSkills(body: ImportSkillBody): Promise<ImportSkillResponse> {
  return apiPost<ImportSkillResponse>('/skills/import', body);
}

/**
 * Update a skill's content/metadata.
 * PUT /api/v1/skills/:slug — used by the detail page ⌘S save flow.
 */
export function updateSkill(slug: string, body: Partial<CreateSkillBody>): Promise<Skill> {
  return apiPut<Skill>(`/skills/${slug}`, body, { rawKeys: true });
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for the skills list with optional filters. */
export function skillsQuery(filters?: SkillFilters) {
  return {
    queryKey: ['skills', filters ?? {}] as const,
    queryFn: () => listSkills(filters),
    staleTime: 30_000,
  };
}

/** Query options for a single skill detail page. */
export function skillQuery(slug: string) {
  return {
    queryKey: ['skills', slug] as const,
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
    mutationKey: ['skills', 'import'] as const,
    mutationFn: (body: ImportSkillBody) => importSkills(body),
  };
}

/** Mutation options to update a skill's content/metadata. */
export function updateSkillMutation() {
  return {
    mutationKey: ['skills', 'update'] as const,
    mutationFn: ({ slug, body }: { slug: string; body: Partial<CreateSkillBody> }) =>
      updateSkill(slug, body),
  };
}
