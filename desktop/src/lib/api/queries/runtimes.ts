/**
 * TanStack Query factories for the /runtimes resource.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import { apiGet, apiPost, apiPut } from '$lib/api/client.js';
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

/** Save credentials for a runtime. Values are never returned from the server. */
export function saveRuntimeCredentials(
  type: string,
  values: Record<string, unknown>
): Promise<void> {
  return apiPut<void>(`/runtimes/${type}/credentials`, { values });
}

/** List which credential field keys have been stored (no values returned). */
export function getRuntimeCredentials(type: string): Promise<{ field_keys: string[] }> {
  return apiGet<{ field_keys: string[] }>(`/runtimes/${type}/credentials`);
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

/** Mutation options to save runtime credentials. */
export function saveRuntimeCredentialsMutation(type: string) {
  return {
    mutationKey: ['runtimes', type, 'credentials'] as const,
    mutationFn: (values: Record<string, unknown>) => saveRuntimeCredentials(type, values),
  };
}

/** Query options for runtime credential field keys (which fields are stored). */
export function runtimeCredentialsQuery(type: string) {
  return {
    queryKey: ['runtimes', type, 'credentials'] as const,
    queryFn: () => getRuntimeCredentials(type),
    staleTime: 60_000,
    enabled: Boolean(type),
  };
}
