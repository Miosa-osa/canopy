/**
 * TanStack Query factories for runtime auth endpoints.
 * Covers the new auth module: start flow, poll, save key, revoke, test.
 *
 * Backend guard: if any endpoint returns 404, callers should show the
 * "backend not ready" banner. The probe function below handles that.
 */

import { apiDelete, apiGet, apiPost, apiPut } from "$lib/api/client.js";
import { ApiError } from "$lib/api/client.js";
import type { AuthStatus } from "$lib/domain/runtimes/types.js";

// ── Response shapes ──────────────────────────────────────────────────────────

export type FlowType = "device_code" | "api_key";

export interface AuthStartResponse {
  flow_type: FlowType;
  device_code?: string;
  user_code?: string;
  verification_url?: string;
  expires_in?: number;
  interval?: number;
}

export type PollStatus = "pending" | "active" | "expired";

export interface AuthPollResponse {
  status: PollStatus;
  credential?: Record<string, unknown>;
}

export interface TestRuntimeResponse {
  ok: boolean;
  model?: string;
  latency_ms?: number;
  error?: string;
}

// ── Raw API calls ────────────────────────────────────────────────────────────

export function startAuthFlow(runtimeId: string): Promise<AuthStartResponse> {
  return apiPost<AuthStartResponse>(`/runtimes/${runtimeId}/auth/start`);
}

export function pollAuthFlow(
  runtimeId: string,
  deviceCode: string,
): Promise<AuthPollResponse> {
  return apiPost<AuthPollResponse>(`/runtimes/${runtimeId}/auth/poll`, {
    device_code: deviceCode,
  });
}

export function saveApiKey(runtimeId: string, key: string): Promise<void> {
  return apiPut<void>(`/runtimes/${runtimeId}/credentials`, {
    auth_type: "api_key",
    api_key: key,
  });
}

export function revokeCredentials(runtimeId: string): Promise<void> {
  return apiDelete<void>(`/runtimes/${runtimeId}/credentials`);
}

export function testRuntime(runtimeId: string): Promise<TestRuntimeResponse> {
  return apiPost<TestRuntimeResponse>(`/runtimes/${runtimeId}/test`);
}

// ── Auth status ──────────────────────────────────────────────────────────────

export function getAuthStatus(runtimeId: string): Promise<AuthStatus> {
  return apiGet<AuthStatus>(`/runtimes/${runtimeId}/auth/status`);
}

/** TanStack Query options for GET /runtimes/:type/auth/status */
export function authStatusQuery(runtimeId: string) {
  return {
    queryKey: ["runtimes", runtimeId, "auth", "status"] as const,
    queryFn: () => getAuthStatus(runtimeId),
    staleTime: 30_000,
    retry: false,
  };
}

// ── Probe: is the auth module available? ─────────────────────────────────────

/**
 * Returns true if the backend auth module is live.
 * Sends a POST /auth/start and interprets 404 as "not ready".
 * Any other status (including 4xx/5xx from a live backend) counts as ready.
 */
export async function probeAuthModule(runtimeId: string): Promise<boolean> {
  try {
    await startAuthFlow(runtimeId);
    return true;
  } catch (err: unknown) {
    if (err instanceof ApiError && err.status === 404) return false;
    // Non-404 error means the route exists but had a problem — module is ready
    return true;
  }
}

// ── Poller utility ───────────────────────────────────────────────────────────

export interface PollerHandle {
  stop: () => void;
}

/**
 * Starts an interval-based poll loop for OAuth device code flow.
 * Calls onResult each tick; calls onDone when status is 'active' or 'expired'.
 * Returns a handle with stop() for cleanup on unmount.
 */
export function createAuthPoller(
  runtimeId: string,
  deviceCode: string,
  intervalMs: number,
  onResult: (result: AuthPollResponse) => void,
  onDone: (result: AuthPollResponse) => void,
  onError: (err: unknown) => void,
): PollerHandle {
  let active = true;

  async function tick() {
    if (!active) return;
    try {
      const result = await pollAuthFlow(runtimeId, deviceCode);
      if (!active) return;
      onResult(result);
      if (result.status === "active" || result.status === "expired") {
        active = false;
        onDone(result);
      }
    } catch (err: unknown) {
      if (!active) return;
      onError(err);
    }
  }

  const id = setInterval(() => void tick(), intervalMs);

  return {
    stop() {
      active = false;
      clearInterval(id);
    },
  };
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Mutation options: start OAuth device code flow */
export function startAuthFlowMutation(runtimeId: string) {
  return {
    mutationKey: ["runtimes", runtimeId, "auth", "start"] as const,
    mutationFn: () => startAuthFlow(runtimeId),
  };
}

/** Mutation options: save API key credential */
export function saveApiKeyMutation(runtimeId: string) {
  return {
    mutationKey: ["runtimes", runtimeId, "auth", "api_key"] as const,
    mutationFn: (key: string) => saveApiKey(runtimeId, key),
  };
}

/** Mutation options: revoke credentials */
export function revokeCredentialsMutation(runtimeId: string) {
  return {
    mutationKey: ["runtimes", runtimeId, "credentials", "revoke"] as const,
    mutationFn: () => revokeCredentials(runtimeId),
  };
}

/** Mutation options: test runtime connection */
export function testRuntimeMutation(runtimeId: string) {
  return {
    mutationKey: ["runtimes", runtimeId, "test"] as const,
    mutationFn: () => testRuntime(runtimeId),
  };
}
