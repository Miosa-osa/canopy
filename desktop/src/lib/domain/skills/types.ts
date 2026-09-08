/**
 * Skill domain types — matches the Elixir backend at /api/v1/skills.
 * Schema: id, slug, name, description, content, content_hash, source,
 * source_url, provider_format, tags, enabled, imported_at, inserted_at, updated_at.
 */

/** Valid source registries for a skill. */
export type SkillSource = 'local' | 'clawhub' | 'skills_sh' | 'user';

/** Provider formats — which agent context file the skill is injected into. */
export type SkillProviderFormat = 'claude' | 'agents_md' | 'generic';

/** Skill kinds — determines how it is organized in the library. */
export type SkillKind = 'prompt' | 'workflow' | 'reference';

/** Skill summary shape returned by GET /api/v1/skills. */
export interface Skill {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  kind: SkillKind;
  frontmatter: Record<string, unknown> | null;
  provider_format: SkillProviderFormat;
  content: string;
  content_hash: string;
  source: SkillSource;
  source_url: string | null;
  imported_at: string | null;
  tags: string[];
  enabled: boolean;
  inserted_at: string;
  updated_at: string;
}

/** An agent ↔ skill assignment with joined skill data. */
export interface AgentSkillAssignment {
  id: string;
  agent_slug: string;
  skill_slug: string;
  priority: number;
  enabled: boolean;
  inserted_at: string;
  skill: Skill;
}

/** Filters for GET /api/v1/skills. */
export interface SkillFilters {
  source?: SkillSource;
  enabled?: boolean;
  tag?: string;
  kind?: SkillKind;
}

/**
 * Body for POST /api/v1/skills/import — bulk import from an external registry.
 * The backend only supports "clawhub" and "skills_sh" as import sources.
 */
export interface ImportSkillBody {
  source: 'clawhub' | 'skills_sh';
}

/** Response from POST /api/v1/skills/import. */
export interface ImportSkillResponse {
  imported: number;
  errors: number;
}

/**
 * Body for creating a local skill via POST /api/v1/skills/import
 * with source "local" — used when the backend has no standalone CREATE endpoint.
 * This mirrors the upsert attrs accepted by Skills.upsert/1.
 */
export interface CreateSkillBody {
  slug: string;
  name: string;
  description?: string;
  content: string;
  provider_format?: SkillProviderFormat;
  tags?: string[];
  source: 'local' | 'user';
}
