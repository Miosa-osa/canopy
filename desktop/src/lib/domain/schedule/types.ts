/**
 * Schedule domain types — match Elixir backend structs at /api/v1/schedule/*.
 * Keys arrive camelCased via the client conversion layer.
 */

export type SpecStatus = 'active' | 'paused' | 'archived';

export type OverlapPolicy = 'skip' | 'buffer_one' | 'cancel_other' | 'terminate_other';

export interface SpecModel {
  crons?: string[];
  intervals?: Array<{ everySeconds: number; phase?: string }>;
  calendars?: Array<{
    weekday?: string;
    hour?: number;
    minute?: number;
  }>;
  skips?: Array<{ date?: string; from?: string; to?: string }>;
}

export interface Spec {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  agentId: string | null;
  agentSlug: string | null;
  workspaceSlug: string | null;
  model: SpecModel;
  timezone: string;
  overlapPolicy: OverlapPolicy;
  jitterSeconds: number;
  graceSeconds: number;
  failureThreshold: number;
  concurrencyKey: string | null;
  startAt: string | null;
  endAt: string | null;
  nextFireAt: string | null;
  lastFireAt: string | null;
  status: SpecStatus;
  pausedReason: string | null;
  pausedAt: string | null;
  consecutiveFailures: number;
  runCount: number;
  errorCount: number;
  insertedAt: string;
  updatedAt: string;
}

export type RunStatus =
  | 'enqueued'
  | 'running'
  | 'completed'
  | 'failed'
  | 'skipped_overlap'
  | 'late'
  | 'missed'
  | 'cancelled';

export interface Run {
  id: string;
  specId: string;
  specSlug: string | null;
  agentSlug: string | null;
  workspaceSlug: string | null;
  scheduledAt: string;
  firedAt: string | null;
  completedAt: string | null;
  status: RunStatus;
  latenessMs: number | null;
  durationMs: number | null;
  attempt: number;
  sessionId: string | null;
  runId: string | null;
  payload: Record<string, unknown>;
  errorClass: string | null;
  errorMessage: string | null;
  insertedAt: string;
}

export type Granularity = 'hour' | 'day' | 'week' | 'month';

export interface RunBucket {
  bucket: string;
  total: number;
  succeeded: number;
  failed: number;
  missed: number;
  late: number;
}

export interface RunBuckets {
  granularity: Granularity;
  rows: RunBucket[];
}

export interface Overlap {
  specId: string;
  specSlug: string | null;
  runningRunId: string;
  incomingRunId: string;
  gapSeconds: number;
  detectedAt: string;
}

export type AlertCategory =
  | 'miss'
  | 'late'
  | 'failure'
  | 'circuit_breaker'
  | 'overlap'
  | 'calendar_sync'
  | 'schedule_conflict';

export type AlertSeverity = 'info' | 'medium' | 'high' | 'critical';

export type AlertStatus = 'open' | 'acknowledged' | 'closed';

export interface Alert {
  id: string;
  slug: string;
  specId: string | null;
  specSlug: string | null;
  category: AlertCategory;
  severity: AlertSeverity;
  status: AlertStatus;
  summary: string;
  detail: string | null;
  firstSeenAt: string;
  lastSeenAt: string;
  closedAt: string | null;
  acknowledgedAt: string | null;
  acknowledgedBy: string | null;
  failureCount: number;
  relatedRunIds: string[];
  workspaceSlug: string | null;
  resolutionNote: string | null;
  insertedAt: string;
  updatedAt: string;
}

export interface SpecCreate {
  slug: string;
  name: string;
  description?: string;
  agentSlug?: string;
  workspaceSlug?: string;
  model?: SpecModel;
  timezone?: string;
  overlapPolicy?: OverlapPolicy;
  jitterSeconds?: number;
  graceSeconds?: number;
  failureThreshold?: number;
  concurrencyKey?: string;
  startAt?: string;
  endAt?: string;
}

export interface AlertCreate {
  slug: string;
  category: AlertCategory;
  summary: string;
  severity?: AlertSeverity;
  detail?: string;
  specSlug?: string;
  workspaceSlug?: string;
}
