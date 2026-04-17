/**
 * Runtime domain types — lifted from Paperclip's ServerAdapterModule contract.
 * Matches the Elixir backend structs served at /api/v1/runtimes.
 */

export type RuntimeStatus = 'installed' | 'not_installed' | 'misconfigured' | 'error';

export type RuntimeCapability =
  | 'heartbeat'
  | 'interactive'
  | 'task_queued'
  | 'mcp'
  | 'diff'
  | 'thinking';

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

/** Single field in a declarative config schema (Paperclip getConfigSchema lift) */
export interface ConfigFieldSchema {
  key: string;
  label: string;
  type: 'text' | 'select' | 'toggle' | 'number';
  required?: boolean;
  placeholder?: string;
  options?: Array<{ value: string; label: string }>;
  description?: string;
  secret?: boolean;
}

/** Summary card shown on the Runtime Dashboard */
export interface Runtime {
  type: string;
  name: string;
  version: string | null;
  status: RuntimeStatus;
  binaryPath: string | null;
  capabilities: RuntimeCapability[];
  monthlyCostUsd: number;
  lastRunAt: string | null;
  quotaWindows: ProviderQuotaWindow[];
  iconUrl: string | null;
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
  level: 'info' | 'warn' | 'error';
  message: string;
}

export interface TestEnvironmentResult {
  ok: boolean;
  checks: EnvironmentCheckItem[];
}
