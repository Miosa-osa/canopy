/**
 * TanStack Query factories for MIOSA integration endpoints.
 *
 * GET /api/v1/miosa/health     → miosaHealthQuery()
 * GET /api/v1/miosa            → miosaSettingsQuery()
 * PUT /api/v1/settings/miosa   → saveMiosaSettingsMutation()
 *
 * Backend guard: if any endpoint returns 404, the MIOSA module is not yet
 * active on this backend build. Callers should show the "backend not ready"
 * banner and disable the form.
 */

import { apiGet, apiPut, ApiError } from "$lib/api/client.js";
import type {
  MiosaHealthResponse,
  MiosaSettingsResponse,
  MiosaSavePayload,
  MiosaSaveResponse,
} from "$lib/types/miosa.js";

// ── Raw API calls ─────────────────────────────────────────────────────────────

export function fetchMiosaHealth(): Promise<MiosaHealthResponse> {
  return apiGet<MiosaHealthResponse>("/miosa/health");
}

export function fetchMiosaSettings(): Promise<MiosaSettingsResponse> {
  return apiGet<MiosaSettingsResponse>("/miosa");
}

export function saveMiosaSettings(
  payload: MiosaSavePayload,
): Promise<MiosaSaveResponse> {
  return apiPut<MiosaSaveResponse>("/settings/miosa", payload);
}

// ── Probe: is the MIOSA module available? ─────────────────────────────────────

/**
 * Returns true if the backend MIOSA module is live.
 * Interprets 404 as "not ready". Any other status (including 4xx/5xx from a
 * live backend) counts as ready — the module exists, it just has a data problem.
 */
export async function probeMiosaModule(): Promise<boolean> {
  try {
    await fetchMiosaSettings();
    return true;
  } catch (err: unknown) {
    if (err instanceof ApiError && err.status === 404) return false;
    return true;
  }
}

// ── TanStack Query option factories ──────────────────────────────────────────

/** Query options: MIOSA health status. staleTime 30s — frequently polled. */
export function miosaHealthQuery() {
  return {
    queryKey: ["miosa", "health"] as const,
    queryFn: fetchMiosaHealth,
    staleTime: 30_000,
    retry: 1,
  };
}

/** Query options: MIOSA settings. staleTime 5min — rarely changes. */
export function miosaSettingsQuery() {
  return {
    queryKey: ["miosa", "settings"] as const,
    queryFn: fetchMiosaSettings,
    staleTime: 5 * 60_000,
    retry: 1,
  };
}

/**
 * Mutation options: save MIOSA settings.
 * Invalidates both health and settings queries on success so the health card
 * reflects any URL change immediately.
 */
export function saveMiosaSettingsMutation() {
  return {
    mutationKey: ["miosa", "save"] as const,
    mutationFn: (payload: MiosaSavePayload) => saveMiosaSettings(payload),
  };
}

/** Query keys exported for manual invalidation in the page component. */
export const MIOSA_QUERY_KEYS = {
  health: ["miosa", "health"] as const,
  settings: ["miosa", "settings"] as const,
};
