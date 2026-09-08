/**
 * TanStack Query factories for the Schedule super-module.
 * Endpoints under /api/v1/schedule/*.
 */

import { apiDelete, apiGet, apiPatch, apiPost } from '$lib/api/client.js';
import type {
  Alert,
  AlertCategory,
  AlertCreate,
  AlertSeverity,
  AlertStatus,
  Granularity,
  Overlap,
  Run,
  RunBuckets,
  RunStatus,
  Spec,
  SpecCreate,
  SpecStatus,
} from '$lib/domain/schedule/types.js';

// ── Specs ────────────────────────────────────────────────────────────────────

export interface SpecQuery {
  status?: SpecStatus;
  agentSlug?: string;
  workspaceSlug?: string;
  limit?: number;
}

export function specsQuery(opts: SpecQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['schedule', 'specs', opts],
    queryFn: () => apiGet<{ data: Spec[] }>(`/schedule/specs${qs}`).then((r) => r.data),
  };
}

export function specQuery(slug: string) {
  return {
    queryKey: ['schedule', 'spec', slug],
    queryFn: () => apiGet<Spec>(`/schedule/specs/${slug}`),
    enabled: Boolean(slug),
  } as const;
}

export async function createSpec(spec: SpecCreate): Promise<Spec> {
  return apiPost<Spec>('/schedule/specs', spec);
}

export async function updateSpec(slug: string, patch: Partial<SpecCreate>): Promise<Spec> {
  return apiPatch<Spec>(`/schedule/specs/${slug}`, patch);
}

export async function pauseSpec(slug: string, reason?: string): Promise<Spec> {
  return apiPost<Spec>(`/schedule/specs/${slug}/pause`, { reason });
}

export async function unpauseSpec(slug: string): Promise<Spec> {
  return apiPost<Spec>(`/schedule/specs/${slug}/unpause`, {});
}

export async function archiveSpec(slug: string): Promise<Spec> {
  return apiDelete<Spec>(`/schedule/specs/${slug}`);
}

// ── Runs ─────────────────────────────────────────────────────────────────────

export interface RunQuery {
  specSlug?: string;
  specId?: string;
  status?: RunStatus;
  since?: string;
  until?: string;
  agentSlug?: string;
  workspaceSlug?: string;
  limit?: number;
}

export function runsQuery(opts: RunQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['schedule', 'runs', opts],
    queryFn: () => apiGet<{ data: Run[] }>(`/schedule/runs${qs}`).then((r) => r.data),
  };
}

export interface RunAggregateQuery {
  granularity?: Granularity;
  from?: string;
  to?: string;
  specSlug?: string;
  agentSlug?: string;
  workspaceSlug?: string;
}

export function runAggregateQuery(opts: RunAggregateQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['schedule', 'runs', 'aggregate', opts],
    queryFn: () => apiGet<RunBuckets>(`/schedule/runs/aggregate${qs}`),
  };
}

// ── Overlaps ─────────────────────────────────────────────────────────────────

export interface OverlapQuery {
  since?: string;
  toleranceSeconds?: number;
  specId?: string;
}

export function overlapsQuery(opts: OverlapQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['schedule', 'overlaps', opts],
    queryFn: () => apiGet<{ data: Overlap[] }>(`/schedule/overlaps${qs}`).then((r) => r.data),
  };
}

// ── Alerts (incidents) ───────────────────────────────────────────────────────

export interface AlertQuery {
  status?: AlertStatus;
  severity?: AlertSeverity;
  category?: AlertCategory;
  workspaceSlug?: string;
  limit?: number;
}

export function alertsQuery(opts: AlertQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['schedule', 'alerts', opts],
    queryFn: () => apiGet<{ data: Alert[] }>(`/schedule/alerts${qs}`).then((r) => r.data),
  };
}

export async function openAlert(alert: AlertCreate): Promise<Alert> {
  return apiPost<Alert>('/schedule/alerts', alert);
}

export async function closeAlert(slug: string, resolutionNote?: string): Promise<Alert> {
  return apiPost<Alert>(`/schedule/alerts/${slug}/close`, {
    resolution_note: resolutionNote,
  });
}

export async function acknowledgeAlert(slug: string, by: string): Promise<Alert> {
  return apiPost<Alert>(`/schedule/alerts/${slug}/ack`, { by });
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
  Alert,
  Overlap,
  Run,
  RunBuckets,
  Spec,
} from '$lib/domain/schedule/types.js';
