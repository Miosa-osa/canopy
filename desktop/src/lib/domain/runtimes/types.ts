/**
 * Runtime domain types matching the Elixir backend structs served at /api/v1/runtimes.
 */

export type RuntimeStatus =
  | "installed"
  | "not_installed"
  | "misconfigured"
  | "error";

export type RuntimeKind = "cli" | "api" | "local_model" | "mcp";

export type RuntimeCapability =
  | "heartbeat"
  | "interactive"
  | "task_queued"
  | "mcp"
  | "diff"
  | "thinking";

/** Auth method a runtime supports */
export type AuthMethod =
  | "subscription_detect"
  | "cli_login"
  | "api_key"
  | "oauth_device";

/** Shape of auth_profile from the backend runtime row */
export interface AuthProfile {
  methods: AuthMethod[];
  subscription_detect?: {
    check_path?: string;
    alt_env_var?: string;
  };
  cli_login?: {
    command: string;
    detect_command: string;
    detect_success_pattern: string;
  };
  api_key?: {
    env_var: string;
    signup_url: string;
    placeholder: string;
  };
  note?: string;
}

/** Response from GET /api/v1/runtimes/:type/auth/status */
export interface AuthStatus {
  type: string;
  methods: AuthMethod[];
  subscription_detected: boolean | null;
  cli_logged_in: boolean | null;
  api_key_stored: boolean | null;
  active_method: AuthMethod | null;
  session_env: string[];
}

/** Quota window from a provider (Anthropic, OpenAI, etc.) */
export interface ProviderQuotaWindow {
  /** Display label, e.g. "Claude API — Tier 3" */
  label: string;
  /** 0–100 */
  usedPercent: number;
  /** ISO-8601 timestamp when this window resets */
  resetsAt: string;
  /** Human-readable value, e.g. "$12.40 / $50.00" */
  valueLabel: string;
}

/** Single field in a declarative config schema (matches getConfigSchema callback) */
export interface ConfigFieldSchema {
  key: string;
  label: string;
  type: "text" | "select" | "toggle" | "number";
  required?: boolean;
  placeholder?: string;
  options?: Array<{ value: string; label: string }>;
  description?: string;
  secret?: boolean;
}

/** Summary card shown on the Runtime Dashboard */
export interface Runtime {
  type: string;
  kind: RuntimeKind;
  name: string;
  version: string | null;
  status: RuntimeStatus;
  binaryPath: string | null;
  capabilities: RuntimeCapability[];
  monthlyCostUsd: number;
  lastRunAt: string | null;
  quotaWindows: ProviderQuotaWindow[];
  iconUrl: string | null;
  authProfile: AuthProfile | null;
}

/** Full detail fetched on the Runtime Detail page */
export interface RuntimeDetail extends Runtime {
  configSchema: ConfigFieldSchema[];
  config: Record<string, unknown>;
}

/** Model option listed under a runtime */
export interface RuntimeModel {
  id: string;
  name: string;
  provider: string;
  contextWindow: number | null;
  isDefault: boolean;
}

/** Result of testEnvironment() */
export interface EnvironmentCheckItem {
  level: "info" | "warn" | "error";
  message: string;
}

export interface TestEnvironmentResult {
  ok: boolean;
  checks: EnvironmentCheckItem[];
}
