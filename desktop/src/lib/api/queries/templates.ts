/**
 * TanStack Query factories for the Templates super-module.
 * Endpoints under /api/v1/templates/*.
 */

import { apiGet, apiPatch, apiPost } from '$lib/api/client.js';
import type {
  ForkRequest,
  InstantiateRequest,
  Instantiation,
  PreviewRequest,
  PreviewResponse,
  PublishRequest,
  PublishResponse,
  Template,
  TemplateCreate,
  TemplateKind,
  TemplateVersion,
} from '$lib/domain/templates/types.js';

// ── Templates list / show ────────────────────────────────────────────────────

export interface TemplateListQuery {
  kind?: TemplateKind;
  verified?: boolean;
  published?: boolean;
  search?: string;
  tag?: string;
  limit?: number;
}

export function templatesQuery(opts: TemplateListQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['templates', 'list', opts],
    queryFn: () => apiGet<Template[]>(`/templates${qs}`),
  };
}

export function templateQuery(slug: string) {
  return {
    queryKey: ['templates', 'show', slug],
    queryFn: () => apiGet<Template>(`/templates/${slug}`),
    enabled: Boolean(slug),
  } as const;
}

export async function createTemplate(body: TemplateCreate): Promise<Template> {
  return apiPost<Template>('/templates', body);
}

export async function updateTemplate(
  slug: string,
  body: Partial<TemplateCreate>
): Promise<Template> {
  return apiPatch<Template>(`/templates/${slug}`, body);
}

// ── Preview / instantiate ────────────────────────────────────────────────────

export async function previewTemplate(
  slug: string,
  body: PreviewRequest
): Promise<PreviewResponse> {
  return apiPost<PreviewResponse>(`/templates/${slug}/preview`, body);
}

export async function instantiateTemplate(
  slug: string,
  body: InstantiateRequest
): Promise<Instantiation> {
  return apiPost<Instantiation>(`/templates/${slug}/instantiate`, body);
}

// ── Publish / fork ───────────────────────────────────────────────────────────

export async function publishTemplate(
  slug: string,
  body: PublishRequest
): Promise<PublishResponse> {
  return apiPost<PublishResponse>(`/templates/${slug}/publish`, body);
}

export async function forkTemplate(slug: string, body: ForkRequest): Promise<Template> {
  return apiPost<Template>(`/templates/${slug}/fork`, body);
}

// ── Versions / instantiations ────────────────────────────────────────────────

export function templateVersionsQuery(slug: string, limit?: number) {
  const qs = buildQuery({ limit });
  return {
    queryKey: ['templates', 'versions', slug, limit ?? null],
    queryFn: () =>
      apiGet<{ slug: string; count: number; data: TemplateVersion[] }>(
        `/templates/${slug}/versions${qs}`
      ).then((r) => r.data),
    enabled: Boolean(slug),
  } as const;
}

export interface InstantiationListQuery {
  templateSlug?: string;
  targetWorkspaceSlug?: string;
  status?: string;
  limit?: number;
}

export function instantiationsQuery(opts: InstantiationListQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['templates', 'instantiations', opts],
    queryFn: () =>
      apiGet<{ data: Instantiation[] }>(`/templates/instantiations${qs}`).then((r) => r.data),
  };
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function buildQuery(opts: object): string {
  const entries = Object.entries(opts as Record<string, unknown>).filter(
    ([, v]) => v !== undefined && v !== null && v !== ''
  );
  if (entries.length === 0) return '';

  const params = new URLSearchParams();
  for (const [key, value] of entries) {
    const snakeKey = key.replace(/[A-Z]/g, (m) => `_${m.toLowerCase()}`);
    params.set(snakeKey, String(value));
  }
  return `?${params.toString()}`;
}

export type {
  ForkRequest,
  InstantiateRequest,
  Instantiation,
  PreviewRequest,
  PreviewResponse,
  PublishRequest,
  PublishResponse,
  Template,
  TemplateCreate,
  TemplateKind,
  TemplateVersion,
} from '$lib/domain/templates/types.js';
