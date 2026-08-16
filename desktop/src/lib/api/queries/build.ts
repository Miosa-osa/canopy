/**
 * TanStack Query factories + mutations for the Build super-super-module.
 * Endpoints under /api/v1/build/*.
 */

import { apiDelete, apiGet, apiPatch, apiPost } from "$lib/api/client.js";
import type {
  BuildLayout,
  BuildLayoutCreate,
  BuildLayoutScope,
  BuildLayoutUpdate,
  BuildSuggestionResult,
} from "$lib/domain/build/types.js";

// ── Layouts ──────────────────────────────────────────────────────────────────

export interface LayoutsQuery {
  scope?: BuildLayoutScope;
  ownerId?: string;
  workspaceSlug?: string;
  includeArchived?: boolean;
  limit?: number;
}

export function layoutsQuery(opts: LayoutsQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ["build", "layouts", opts],
    queryFn: () =>
      apiGet<{ data: BuildLayout[] }>(`/build/layouts${qs}`).then(
        (r) => r.data,
      ),
  };
}

export interface LayoutQueryOpts {
  scope?: BuildLayoutScope;
  ownerId?: string;
}

export function layoutQuery(slug: string, opts: LayoutQueryOpts = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ["build", "layout", slug, opts],
    queryFn: () => apiGet<BuildLayout>(`/build/layouts/${slug}${qs}`),
    enabled: Boolean(slug),
  } as const;
}

export async function createLayout(
  body: BuildLayoutCreate,
): Promise<BuildLayout> {
  return apiPost<BuildLayout>("/build/layouts", body);
}

export async function updateLayout(
  slug: string,
  body: BuildLayoutUpdate,
): Promise<BuildLayout> {
  return apiPatch<BuildLayout>(`/build/layouts/${slug}`, body);
}

export async function archiveLayout(slug: string): Promise<BuildLayout> {
  return apiDelete<BuildLayout>(`/build/layouts/${slug}`);
}

// ── Suggestions ─────────────────────────────────────────────────────────────

export interface SuggestInput {
  intent: string;
  scope?: BuildLayoutScope;
  ownerId?: string;
  workspaceSlug?: string;
}

export async function suggestLayout(
  input: SuggestInput,
): Promise<BuildSuggestionResult> {
  return apiPost<BuildSuggestionResult>("/build/suggest", input);
}

// ── Default layout per workspace ─────────────────────────────────────────────

export function defaultLayoutQuery(workspaceSlug: string) {
  return {
    queryKey: ["build", "default", workspaceSlug],
    queryFn: () =>
      apiGet<{ data: BuildLayout | null }>(
        `/build/default?workspace_slug=${encodeURIComponent(workspaceSlug)}`,
      ).then((r) => r.data),
    enabled: Boolean(workspaceSlug),
  } as const;
}

export async function setDefaultLayout(
  slug: string,
  workspaceSlug: string,
): Promise<BuildLayout> {
  return apiPost<BuildLayout>(`/build/layouts/${slug}/set-default`, {
    workspace_slug: workspaceSlug,
  });
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
  BuildLayout,
  BuildLayoutCreate,
  BuildLayoutScope,
  BuildLayoutUpdate,
  BuildSuggestionResult,
} from "$lib/domain/build/types.js";
