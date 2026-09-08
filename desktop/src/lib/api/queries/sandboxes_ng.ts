/**
 * TanStack Query factories for the Sandboxes super-module.
 * Endpoints under /api/v1/sandboxes-ng/*.
 */

import { apiDelete, apiGet, apiPost } from '$lib/api/client.js';
import type {
  LifecycleEvent,
  PortForward,
  PortForwardCreate,
  SandboxAlert,
  SandboxAlertCreate,
  SandboxStateRow,
  Snapshot,
  SnapshotCreate,
} from '$lib/domain/sandboxes_ng/types.js';

// ── Sandbox state grid ───────────────────────────────────────────────────────

export interface SandboxStateQuery {
  workspaceSlug?: string;
}

export function sandboxStatesQuery(opts: SandboxStateQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['sandboxes-ng', 'states', opts],
    queryFn: () => apiGet<{ data: SandboxStateRow[] }>(`/sandboxes-ng${qs}`).then((r) => r.data),
  };
}

// ── Lifecycle events ─────────────────────────────────────────────────────────

export interface EventsQuery {
  sandboxId?: string;
  state?: string;
  ownerAgentId?: string;
  workspaceSlug?: string;
  from?: string;
  to?: string;
  limit?: number;
}

export function eventsQuery(opts: EventsQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['sandboxes-ng', 'events', opts],
    queryFn: () =>
      apiGet<{ data: LifecycleEvent[] }>(`/sandboxes-ng/events${qs}`).then((r) => r.data),
  };
}

export function eventsForSandboxQuery(sandboxId: string, opts: { limit?: number } = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['sandboxes-ng', 'events', sandboxId, opts],
    queryFn: () =>
      apiGet<{ data: LifecycleEvent[] }>(`/sandboxes-ng/events/${sandboxId}${qs}`).then(
        (r) => r.data
      ),
    enabled: Boolean(sandboxId),
  } as const;
}

// ── Snapshots ────────────────────────────────────────────────────────────────

export interface SnapshotQuery {
  sandboxId?: string;
  kind?: string;
  workspaceSlug?: string;
  activeOnly?: boolean;
  limit?: number;
}

export function snapshotsQuery(opts: SnapshotQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['sandboxes-ng', 'snapshots', opts],
    queryFn: () => apiGet<{ data: Snapshot[] }>(`/sandboxes-ng/snapshots${qs}`).then((r) => r.data),
  };
}

export async function createSnapshot(snap: SnapshotCreate): Promise<Snapshot> {
  return apiPost<Snapshot>('/sandboxes-ng/snapshots', snap);
}

// ── Port forwards ────────────────────────────────────────────────────────────

export interface PortQuery {
  sandboxId?: string;
  visibility?: string;
  workspaceSlug?: string;
  openOnly?: boolean;
  limit?: number;
}

export function portsQuery(opts: PortQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['sandboxes-ng', 'ports', opts],
    queryFn: () => apiGet<{ data: PortForward[] }>(`/sandboxes-ng/ports${qs}`).then((r) => r.data),
  };
}

export async function openPortForward(body: PortForwardCreate): Promise<PortForward> {
  return apiPost<PortForward>('/sandboxes-ng/ports', body);
}

export async function closePortForward(id: string): Promise<PortForward> {
  return apiDelete<PortForward>(`/sandboxes-ng/ports/${id}`);
}

// ── Alerts ───────────────────────────────────────────────────────────────────

export interface AlertQuery {
  enabled?: boolean;
  metric?: string;
  workspaceSlug?: string;
}

export function sandboxAlertsQuery(opts: AlertQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['sandboxes-ng', 'alerts', opts],
    queryFn: () =>
      apiGet<{ data: SandboxAlert[] }>(`/sandboxes-ng/alerts${qs}`).then((r) => r.data),
  };
}

export async function createSandboxAlert(alert: SandboxAlertCreate): Promise<SandboxAlert> {
  return apiPost<SandboxAlert>('/sandboxes-ng/alerts', alert);
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
  LifecycleEvent,
  PortForward,
  SandboxAlert,
  SandboxStateRow,
  Snapshot,
} from '$lib/domain/sandboxes_ng/types.js';
