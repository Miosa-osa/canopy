/**
 * Skill Curator domain types — match Elixir backend at /api/v1/skill-curator/*.
 * Keys arrive camelCased via the client conversion layer.
 */

export interface LockfileEntry {
  id: string;
  workspaceSlug: string;
  skillSlug: string;
  lockedVersion: string;
  contentHash: string;
  source: string | null;
  sourceUrl: string | null;
  lockedAt: string | null;
  lockedBy: string | null;
  notes: string | null;
  insertedAt: string;
  updatedAt: string;
}

export interface LockfileCreate {
  workspaceSlug?: string;
  skillSlug: string;
  lockedVersion: string;
  contentHash: string;
  source?: string;
  sourceUrl?: string;
  notes?: string;
}

export interface SkillVersion {
  id: string;
  skillId: string;
  skillSlug: string;
  version: string;
  contentHash: string;
  changelog: string | null;
  publishedAt: string;
  publishedBy: string | null;
  source: string | null;
}

export interface VersionDiff {
  skillSlug: string;
  from: SkillVersion;
  to: SkillVersion;
  hashChanged: boolean;
}

export interface Verification {
  slug: string;
  verified: boolean;
  verifiedAt: string | null;
  verifiedBy: string | null;
}

export interface UnverifiedList {
  count: number;
  data: string[];
}

export interface RegistrySource {
  name: string;
  url: string | null;
  kind: string;
  lastSyncedAt: string | null;
}

export interface RegistrySourceCreate {
  name: string;
  url: string;
  kind?: string;
}

export interface RefreshResult {
  refreshed: number;
  errors: number;
  note: string | null;
}

/** Policy modes for the unverified-source gating. */
export type UnverifiedPolicy = "block" | "prompt" | "allow";
