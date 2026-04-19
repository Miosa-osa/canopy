/**
 * TanStack Query factories for the /sandboxes resource.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import { apiDelete, apiGet } from "$lib/api/client.js";
import type { Sandbox } from "$lib/domain/sandboxes/types.js";

// ── Raw API calls ────────────────────────────────────────────────────────────

export function listSandboxes(): Promise<{ data: Sandbox[] }> {
  return apiGet<{ data: Sandbox[] }>("/sandboxes");
}

export function getSandbox(id: string): Promise<Sandbox> {
  return apiGet<Sandbox>(`/sandboxes/${id}`);
}

export function destroySandbox(id: string): Promise<void> {
  return apiDelete<void>(`/sandboxes/${id}`);
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for the full sandbox list. */
export function sandboxesQuery() {
  return {
    queryKey: ["sandboxes"] as const,
    queryFn: listSandboxes,
    staleTime: 15_000,
  };
}

/** Query options for a single sandbox. */
export function sandboxQuery(id: string) {
  return {
    queryKey: ["sandboxes", id] as const,
    queryFn: () => getSandbox(id),
    staleTime: 15_000,
    enabled: Boolean(id),
  };
}

/** Mutation options to destroy a sandbox. */
export function deleteSandboxMutation(id: string) {
  return {
    mutationKey: ["sandboxes", id, "delete"] as const,
    mutationFn: () => destroySandbox(id),
  };
}
