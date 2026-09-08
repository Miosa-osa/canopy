/**
 * Types for MIOSA integration endpoints.
 *
 * GET /api/v1/miosa/health  → MiosaHealthResponse
 * GET /api/v1/miosa         → MiosaSettingsResponse  (api_key NEVER returned — write-only)
 * PUT /api/v1/settings/miosa → MiosaSaveResponse
 */

export type MiosaStatus = 'ok' | 'unreachable' | 'unconfigured';

export type MiosaTier = 'free' | 'pro' | 'growth' | 'business';

export type MiosaRegion = 'us-east' | 'us-west' | 'eu-central' | null;

export interface MiosaHealthResponse {
  status: MiosaStatus;
  /** ISO 8601 timestamp of last health check. Null if never checked. */
  last_check_at: string | null;
  /** Optional human-readable detail for unreachable/unconfigured states. */
  detail?: string;
}

export interface MiosaSettingsResponse {
  configured: boolean;
  /** Base URL of the MIOSA API. Null if not configured. */
  api_url: string | null;
  /**
   * api_key is NEVER returned by GET — it is write-only.
   * This field will always be absent or undefined in responses.
   * On save: send the value if the user typed one; omit if blank.
   */
  default_tier: MiosaTier;
  auto_provision: boolean;
  region: MiosaRegion;
  last_check_at: string | null;
}

export interface MiosaSavePayload {
  api_url?: string;
  /** Only sent when the user explicitly fills in a new key. Never sent empty. */
  api_key?: string;
  default_tier?: MiosaTier;
  auto_provision?: boolean;
  region?: MiosaRegion;
}

export interface MiosaSaveResponse {
  ok: boolean;
  settings: MiosaSettingsResponse;
}
