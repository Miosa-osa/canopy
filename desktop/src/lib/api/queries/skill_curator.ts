/**
 * TanStack Query factories for the Skill Curator super-module.
 * Endpoints under /api/v1/skill-curator/*.
 */

import { apiDelete, apiGet, apiPost } from "$lib/api/client.js";
import type {
  LockfileCreate,
  LockfileEntry,
  RefreshResult,
  RegistrySource,
  RegistrySourceCreate,
  UnverifiedList,
  Verification,
  VersionDiff,
  SkillVersion,
} from "$lib/domain/skill_curator/types.js";

// ── Lockfile ─────────────────────────────────────────────────────────────────

export interface LockfileFilters {
  workspaceSlug?: string;
  skillSlug?: string;
  limit?: number;
}

export function lockfileQuery(opts: LockfileFilters = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ["skill_curator", "lockfile", opts],
    queryFn: () =>
      apiGet<{ data: LockfileEntry[] }>(`/skill-curator/lockfile${qs}`).then(
        (r) => r.data,
      ),
  };
}

export async function lockSkill(body: LockfileCreate): Promise<LockfileEntry> {
  return apiPost<LockfileEntry>("/skill-curator/lockfile", body);
}

export async function unlockSkill(
  workspaceSlug: string,
  skillSlug: string,
): Promise<LockfileEntry> {
  return apiDelete<LockfileEntry>(
    `/skill-curator/lockfile/${workspaceSlug}/${skillSlug}`,
  );
}

// ── Versions ─────────────────────────────────────────────────────────────────

export function versionsQuery(slug: string) {
  return {
    queryKey: ["skill_curator", "versions", slug],
    queryFn: () =>
      apiGet<{ skillSlug: string; data: SkillVersion[] }>(
        `/skill-curator/skills/${slug}/versions`,
      ).then((r) => r.data),
    enabled: Boolean(slug),
  } as const;
}

export async function diffVersions(
  slug: string,
  from: string,
  to: string,
): Promise<VersionDiff> {
  const params = new URLSearchParams({ from, to });
  return apiGet<VersionDiff>(
    `/skill-curator/skills/${slug}/diff?${params.toString()}`,
  );
}

// ── Verification ─────────────────────────────────────────────────────────────

export async function verifySkill(
  slug: string,
  verifiedBy: string,
): Promise<Verification> {
  return apiPost<Verification>(`/skill-curator/skills/${slug}/verify`, {
    verified_by: verifiedBy,
  });
}

export async function unverifySkill(slug: string): Promise<Verification> {
  return apiDelete<Verification>(`/skill-curator/skills/${slug}/verify`);
}

export function unverifiedQuery(limit?: number) {
  const qs = limit ? `?limit=${limit}` : "";
  return {
    queryKey: ["skill_curator", "unverified", { limit }],
    queryFn: () => apiGet<UnverifiedList>(`/skill-curator/unverified${qs}`),
  };
}

// ── Sources ──────────────────────────────────────────────────────────────────

export function sourcesQuery() {
  return {
    queryKey: ["skill_curator", "sources"],
    queryFn: () =>
      apiGet<{ sources: RegistrySource[] }>("/skill-curator/sources").then(
        (r) => r.sources,
      ),
  };
}

export async function addSource(
  body: RegistrySourceCreate,
): Promise<RegistrySource> {
  return apiPost<RegistrySource>("/skill-curator/sources", body);
}

export async function refreshSources(source?: string): Promise<RefreshResult> {
  return apiPost<RefreshResult>(
    "/skill-curator/sources/refresh",
    source ? { source } : {},
  );
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function buildQuery(opts: object): string {
  const entries = Object.entries(opts as Record<string, unknown>).filter(
    ([, v]) => v !== undefined && v !== null && v !== "",
  );
  if (entries.length === 0) return "";

  const params = new URLSearchParams();
  for (const [key, value] of entries) {
    const snakeKey = key.replace(/[A-Z]/g, (m) => `_${m.toLowerCase()}`);
    params.set(snakeKey, String(value));
  }
  return `?${params.toString()}`;
}

export type {
  LockfileEntry,
  RefreshResult,
  RegistrySource,
  Verification,
  VersionDiff,
  SkillVersion,
} from "$lib/domain/skill_curator/types.js";
