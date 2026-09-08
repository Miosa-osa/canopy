/**
 * TanStack Query factories for the Analytics super-module.
 * Endpoints under /api/v1/analytics/*.
 */

import { apiGet, apiPost } from '$lib/api/client.js';
import type {
  Alert,
  AlertCreate,
  BreadcrumbList,
  CostBuckets,
  Granularity,
  Insight,
  InsightCreate,
  InsightSeverity,
  TelemetryEvent,
} from '$lib/domain/analytics/types.js';

// ── Telemetry ────────────────────────────────────────────────────────────────

export interface TelemetryQuery {
  event?: string;
  agentId?: string;
  sessionId?: string;
  runId?: string;
  workspaceSlug?: string;
  runtime?: string;
  from?: string;
  to?: string;
  limit?: number;
}

export function telemetryQuery(opts: TelemetryQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['analytics', 'telemetry', opts],
    queryFn: () =>
      apiGet<{ data: TelemetryEvent[] }>(`/analytics/telemetry${qs}`).then((r) => r.data),
  };
}

// ── Costs ────────────────────────────────────────────────────────────────────

export interface CostQuery {
  granularity?: Granularity;
  from?: string;
  to?: string;
  agentId?: string;
  workspaceSlug?: string;
  runtime?: string;
}

export function costQuery(opts: CostQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['analytics', 'costs', opts],
    queryFn: () => apiGet<CostBuckets>(`/analytics/costs${qs}`),
  };
}

// ── Breadcrumbs ──────────────────────────────────────────────────────────────

export interface BreadcrumbQuery {
  level?: string;
  type?: string;
  limit?: number;
}

export function breadcrumbQuery(runId: string, opts: BreadcrumbQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['analytics', 'breadcrumbs', runId, opts],
    queryFn: () =>
      apiGet<BreadcrumbList>(`/analytics/breadcrumbs/${runId}${qs}`).then((r) => r.data),
    enabled: Boolean(runId),
  } as const;
}

// ── Insights ─────────────────────────────────────────────────────────────────

export interface InsightQuery {
  severity?: InsightSeverity;
  kind?: string;
  workspaceSlug?: string;
  since?: string;
  limit?: number;
}

export function insightsQuery(opts: InsightQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['analytics', 'insights', opts],
    queryFn: () => apiGet<{ data: Insight[] }>(`/analytics/insights${qs}`).then((r) => r.data),
  };
}

export async function createInsight(insight: InsightCreate): Promise<Insight> {
  return apiPost<Insight>('/analytics/insights', insight);
}

export async function acknowledgeInsight(
  slug: string,
  by: string,
  feedback?: 'true_positive' | 'false_positive'
): Promise<Insight> {
  return apiPost<Insight>(`/analytics/insights/${slug}/ack`, { by, feedback });
}

// ── Alerts ───────────────────────────────────────────────────────────────────

export interface AlertQuery {
  enabled?: boolean;
  metric?: string;
  workspaceSlug?: string;
}

export function alertsQuery(opts: AlertQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['analytics', 'alerts', opts],
    queryFn: () => apiGet<{ data: Alert[] }>(`/analytics/alerts${qs}`).then((r) => r.data),
  };
}

export async function createAlert(alert: AlertCreate): Promise<Alert> {
  return apiPost<Alert>('/analytics/alerts', alert);
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
  Breadcrumb,
  CostBuckets,
  Insight,
  TelemetryEvent,
} from '$lib/domain/analytics/types.js';
