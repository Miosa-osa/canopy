/**
 * TanStack Query factories for the /runtimes resource.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import { apiGet, apiPost } from '$lib/api/client.js';
import type {
  Runtime,
  RuntimeDetail,
  RuntimeModel,
  TestEnvironmentResult,
} from '$lib/domain/runtimes/types.js';

// ── Raw API calls ────────────────────────────────────────────────────────────

export function listRuntimes(): Promise<Runtime[]> {
  return apiGet<Runtime[]>('/runtimes');
}

export function getRuntime(type: string): Promise<RuntimeDetail> {
  return apiGet<RuntimeDetail>(`/runtimes/${type}`);
}

export function listRuntimeModels(type: string): Promise<RuntimeModel[]> {
  return apiGet<RuntimeModel[]>(`/runtimes/${type}/models`);
}

export function testRuntimeEnvironment(type: string): Promise<TestEnvironmentResult> {
  return apiPost<TestEnvironmentResult>(`/runtimes/${type}/test`);
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for the full runtime list (Runtime Dashboard). */
export function runtimesQuery() {
  return {
    queryKey: ['runtimes'] as const,
    queryFn: listRuntimes,
    staleTime: 30_000,
  };
}

/** Query options for a single runtime detail page. */
export function runtimeDetailQuery(type: string) {
  return {
    queryKey: ['runtimes', type] as const,
    queryFn: () => getRuntime(type),
    staleTime: 30_000,
    enabled: Boolean(type),
  };
}

/** Query options for a runtime's model list. */
export function runtimeModelsQuery(type: string) {
  return {
    queryKey: ['runtimes', type, 'models'] as const,
    queryFn: () => listRuntimeModels(type),
    staleTime: 60_000,
    enabled: Boolean(type),
  };
}

/** Mutation options for running testEnvironment on a runtime. */
export function testEnvironmentMutation(type: string) {
  return {
    mutationKey: ['runtimes', type, 'test'] as const,
    mutationFn: () => testRuntimeEnvironment(type),
  };
}
