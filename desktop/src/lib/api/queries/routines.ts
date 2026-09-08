/**
 * TanStack Query factories for the /routines resource.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import { apiDelete, apiGet, apiPatch, apiPost } from '$lib/api/client.js';
import type {
  CreateRoutineBody,
  Routine,
  RoutineFilters,
  UpdateRoutineBody,
} from '$lib/domain/routines/types.js';

// ── Raw API calls ────────────────────────────────────────────────────────────

export function listRoutines(filters?: RoutineFilters): Promise<Routine[]> {
  const params = new URLSearchParams();
  if (filters?.workspaceSlug) params.set('workspace_slug', filters.workspaceSlug);
  const qs = params.toString();
  return apiGet<Routine[]>(`/routines${qs ? `?${qs}` : ''}`);
}

export function getRoutine(shortId: string): Promise<Routine> {
  return apiGet<Routine>(`/routines/${shortId}`);
}

export function createRoutine(body: CreateRoutineBody): Promise<Routine> {
  return apiPost<Routine>('/routines', body);
}

export function updateRoutine(shortId: string, body: UpdateRoutineBody): Promise<Routine> {
  return apiPatch<Routine>(`/routines/${shortId}`, body);
}

export function deleteRoutine(shortId: string): Promise<void> {
  return apiDelete<void>(`/routines/${shortId}`);
}

export function enableRoutine(shortId: string): Promise<Routine> {
  return apiPost<Routine>(`/routines/${shortId}/enable`, {});
}

export function disableRoutine(shortId: string): Promise<Routine> {
  return apiPost<Routine>(`/routines/${shortId}/disable`, {});
}

export function fireRoutine(shortId: string): Promise<Routine> {
  return apiPost<Routine>(`/routines/${shortId}/fire`, {});
}

// ── TanStack Query option factories ─────────────────────────────────────────

export function routinesQuery(filters?: RoutineFilters) {
  return {
    queryKey: ['routines', filters ?? {}] as const,
    queryFn: () => listRoutines(filters),
    staleTime: 15_000,
    retry: false,
  };
}

export function routineQuery(shortId: string) {
  return {
    queryKey: ['routines', shortId] as const,
    queryFn: () => getRoutine(shortId),
    staleTime: 10_000,
    enabled: Boolean(shortId),
    retry: false,
  };
}

export function createRoutineMutation() {
  return {
    mutationKey: ['routines', 'create'] as const,
    mutationFn: (body: CreateRoutineBody) => createRoutine(body),
  };
}

export function updateRoutineMutation() {
  return {
    mutationKey: ['routines', 'update'] as const,
    mutationFn: ({ shortId, body }: { shortId: string; body: UpdateRoutineBody }) =>
      updateRoutine(shortId, body),
  };
}

export function deleteRoutineMutation() {
  return {
    mutationKey: ['routines', 'delete'] as const,
    mutationFn: (shortId: string) => deleteRoutine(shortId),
  };
}

export function enableRoutineMutation() {
  return {
    mutationKey: ['routines', 'enable'] as const,
    mutationFn: (shortId: string) => enableRoutine(shortId),
  };
}

export function disableRoutineMutation() {
  return {
    mutationKey: ['routines', 'disable'] as const,
    mutationFn: (shortId: string) => disableRoutine(shortId),
  };
}

export function fireRoutineMutation() {
  return {
    mutationKey: ['routines', 'fire'] as const,
    mutationFn: (shortId: string) => fireRoutine(shortId),
  };
}
