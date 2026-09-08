/**
 * TanStack Query factories for GET /api/v1/activity.
 * Polling interval: 10s.
 * LOC target: ≤ 80.
 */

import { apiGet } from '$lib/api/client.js';
import type {
  ActivityEvent,
  ActivityFilters,
  ActivityResponse,
} from '$lib/domain/activity/types.js';

// ── Raw API call ──────────────────────────────────────────────────────────────

export async function listActivity(filters?: ActivityFilters): Promise<ActivityEvent[]> {
  const params = new URLSearchParams();
  if (filters?.workspace_slug) params.set('workspace_slug', filters.workspace_slug);
  if (filters?.limit !== undefined) params.set('limit', String(filters.limit));
  if (filters?.after) params.set('after', filters.after);
  if (filters?.before) params.set('before', filters.before);
  // Multi-value type param: ?type=session_started&type=task_completed
  if (filters?.type && filters.type.length > 0) {
    for (const t of filters.type) {
      params.append('type', t);
    }
  }
  const qs = params.toString();

  // Backend returns { count, data } — apiGet unwraps `data` if present.
  // The activity endpoint returns the full envelope, so we hit it directly.
  const raw = await apiGet<ActivityResponse | ActivityEvent[]>(`/activity${qs ? `?${qs}` : ''}`);

  // Handle both wrapped ({count, data}) and unwrapped (array) shapes.
  if (Array.isArray(raw)) return raw;
  return (raw as ActivityResponse).data;
}

// ── TanStack Query factory ────────────────────────────────────────────────────

const REFETCH_MS = 10_000;

export function activityQuery(filters?: ActivityFilters) {
  return {
    queryKey: ['activity', filters ?? {}] as const,
    queryFn: () => listActivity(filters),
    staleTime: 5_000,
    refetchInterval: REFETCH_MS,
  };
}
