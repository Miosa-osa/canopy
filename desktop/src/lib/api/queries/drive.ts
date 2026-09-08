/**
 * TanStack Query factories for the Drive super-module.
 * Endpoints under /api/v1/drive/*.
 */

import { apiDelete, apiGet, apiPatch, apiPost } from '$lib/api/client.js';
import type {
  DriveEntry,
  DriveEntryCreate,
  DriveEntryUpdate,
  DriveListQuery,
  DriveScope,
  DriveSearchQuery,
  DriveTree,
} from '$lib/domain/drive/types.js';

// ── List ─────────────────────────────────────────────────────────────────────

export function driveListQuery(opts: DriveListQuery = {}) {
  const qs = buildQuery(opts);
  return {
    queryKey: ['drive', 'list', opts],
    queryFn: () => apiGet<{ data: DriveEntry[] }>(`/drive${qs}`).then((r) => r.data),
  };
}

// ── Tree ─────────────────────────────────────────────────────────────────────

export function driveTreeQuery(scope: DriveScope, archived?: 'true' | 'false' | 'all') {
  const qs = buildQuery({ scope, archived });
  return {
    queryKey: ['drive', 'tree', scope, archived ?? 'false'],
    queryFn: () => apiGet<DriveTree>(`/drive/tree${qs}`),
  };
}

// ── Show ─────────────────────────────────────────────────────────────────────

export function driveEntryQuery(id: string) {
  return {
    queryKey: ['drive', 'entry', id],
    queryFn: () => apiGet<DriveEntry>(`/drive/${id}`),
    enabled: Boolean(id),
  } as const;
}

// ── Search ───────────────────────────────────────────────────────────────────

export function driveSearchQuery(q: string, opts: DriveSearchQuery = {}) {
  const qs = buildQuery({ q, ...opts });
  return {
    queryKey: ['drive', 'search', q, opts],
    queryFn: () =>
      apiGet<{ query: string; data: DriveEntry[] }>(`/drive/search${qs}`).then((r) => r.data),
    enabled: Boolean(q),
  } as const;
}

// ── Mutations ────────────────────────────────────────────────────────────────

export async function createDriveEntry(entry: DriveEntryCreate): Promise<DriveEntry> {
  return apiPost<DriveEntry>('/drive', entry);
}

export async function updateDriveEntry(id: string, patch: DriveEntryUpdate): Promise<DriveEntry> {
  return apiPatch<DriveEntry>(`/drive/${id}`, patch);
}

export async function archiveDriveEntry(id: string): Promise<DriveEntry> {
  return apiPost<DriveEntry>(`/drive/${id}/archive`, {});
}

export async function restoreDriveEntry(id: string): Promise<DriveEntry> {
  return apiPost<DriveEntry>(`/drive/${id}/restore`, {});
}

export async function moveDriveEntry(id: string, parentId: string | null): Promise<DriveEntry> {
  return apiPost<DriveEntry>(`/drive/${id}/move`, { parentId });
}

export async function reorderDriveEntries(ids: string[]): Promise<{ count: number }> {
  return apiPost<{ count: number }>('/drive/reorder', { ids });
}

export async function deleteDriveEntry(id: string): Promise<void> {
  return apiDelete<void>(`/drive/${id}`);
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
  DriveEntry,
  DriveEntryCreate,
  DriveEntryUpdate,
  DriveTree,
} from '$lib/domain/drive/types.js';
