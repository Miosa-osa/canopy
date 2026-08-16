/**
 * Analytics domain types — match Elixir backend structs at /api/v1/analytics/*.
 * Keys arrive camelCased via the client conversion layer.
 */

export interface TelemetryEvent {
  id: string;
  ts: string;
  event: string;
  runId: string | null;
  sessionId: string | null;
  agentId: string | null;
  workspaceSlug: string | null;
  runtime: string | null;
  model: string | null;
  durationMs: number | null;
  costCents: number | null;
  status: string | null;
  payload: Record<string, unknown>;
  insertedAt: string;
}

export type Granularity = "hour" | "day" | "week" | "month";

export interface CostBucket {
  bucket: string;
  costCents: number;
  count: number;
}

export interface CostBuckets {
  granularity: Granularity;
  rows: CostBucket[];
}

export type BreadcrumbType =
  | "tool_call"
  | "http"
  | "db"
  | "governance"
  | "navigation"
  | "user"
  | "system";

export type BreadcrumbLevel = "debug" | "info" | "warning" | "error" | "fatal";

export interface Breadcrumb {
  id: string;
  runId: string;
  sessionId: string | null;
  sequence: number;
  ts: string;
  type: BreadcrumbType;
  category: string | null;
  level: BreadcrumbLevel;
  message: string | null;
  data: Record<string, unknown>;
}

export interface BreadcrumbList {
  runId: string;
  count: number;
  data: Breadcrumb[];
}

export type InsightSeverity = "info" | "medium" | "high" | "critical";
export type InsightKind =
  | "anomaly"
  | "trend"
  | "correlation"
  | "pattern"
  | "saved"
  | "forecast";
export type InsightFeedback = "true_positive" | "false_positive" | "unverified";

export interface Insight {
  id: string;
  slug: string;
  title: string;
  body: string;
  severity: InsightSeverity;
  kind: InsightKind;
  metric: string | null;
  detectedAt: string;
  windowStart: string | null;
  windowEnd: string | null;
  workspaceSlug: string | null;
  createdByAgentId: string | null;
  relatedRunId: string | null;
  relatedSessionId: string | null;
  acknowledgedAt: string | null;
  acknowledgedBy: string | null;
  feedback: InsightFeedback | null;
  dashboards: string[];
  tags: string[];
  query: Record<string, unknown>;
  result: Record<string, unknown>;
  insertedAt: string;
  updatedAt: string;
}

export type AlertType = "threshold" | "anomaly" | "composite";

export interface Alert {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  metric: string;
  type: AlertType;
  config: Record<string, unknown>;
  routing: Record<string, unknown>;
  enabled: boolean;
  severity: InsightSeverity;
  sensitivity: number;
  workspaceSlug: string | null;
  lastEvaluatedAt: string | null;
  lastFiredAt: string | null;
  fireCount: number;
  insertedAt: string;
  updatedAt: string;
}

export interface InsightCreate {
  slug: string;
  title: string;
  body: string;
  detectedAt: string;
  severity?: InsightSeverity;
  kind?: InsightKind;
  metric?: string;
  workspaceSlug?: string;
  relatedRunId?: string;
  relatedSessionId?: string;
  tags?: string[];
}

export interface AlertCreate {
  slug: string;
  name: string;
  metric: string;
  type: AlertType;
  description?: string;
  config?: Record<string, unknown>;
  routing?: Record<string, unknown>;
  enabled?: boolean;
  severity?: InsightSeverity;
  sensitivity?: number;
  workspaceSlug?: string;
}
