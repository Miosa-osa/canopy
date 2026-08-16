/**
 * API calls for the hooks observability endpoints.
 *
 * Backend endpoints:
 *   POST /api/v1/hooks/notify    — receives lifecycle event (called by notify script, not UI)
 *   POST /api/v1/hooks/install   — installs hooks into all agent global configs
 *   POST /api/v1/hooks/uninstall — removes hooks from all agent global configs
 *   GET  /api/v1/hooks/status    — per-runtime install status + last 20 hook events
 */

import { apiGet, apiPost } from "$lib/api/client.js";

// ── Types ─────────────────────────────────────────────────────────────────────

export interface RuntimeStatus {
  status: "ok" | "installed" | "not_installed" | "error";
  reason?: string;
}

export interface HookEvent {
  id: string;
  agent: string;
  event: string;
  session_id: string | null;
  payload: Record<string, unknown>;
  inserted_at: string;
}

export interface HooksStatusResponse {
  ok: boolean;
  runtimes: Record<string, RuntimeStatus>;
  recent_events: HookEvent[];
}

export interface HooksActionResponse {
  ok: boolean;
  results: Record<string, RuntimeStatus>;
}

// ── API calls ─────────────────────────────────────────────────────────────────

export function getHooksStatus(): Promise<HooksStatusResponse> {
  return apiGet<HooksStatusResponse>("/hooks/status");
}

export function installHooks(): Promise<HooksActionResponse> {
  return apiPost<HooksActionResponse>("/hooks/install", {});
}

export function uninstallHooks(): Promise<HooksActionResponse> {
  return apiPost<HooksActionResponse>("/hooks/uninstall", {});
}
