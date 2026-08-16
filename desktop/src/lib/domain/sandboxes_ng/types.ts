/**
 * Sandboxes (next-gen operator) domain types — match Elixir backend structs
 * at /api/v1/sandboxes-ng/*.
 * Keys arrive camelCased via the client conversion layer.
 *
 * The Sandboxes super-module operates MIOSA-provisioned VMs through the
 * Sandbox Operator agent. UI surfaces lifecycle, ports, snapshots, and
 * alerts as four parallel tabs.
 */

export type SandboxState =
  | "provisioning"
  | "running"
  | "paused"
  | "snapshotting"
  | "archived"
  | "resizing"
  | "error"
  | "destroyed";

export interface LifecycleEvent {
  id: string;
  sandboxId: string;
  state: SandboxState;
  priorState: SandboxState | null;
  reason: string | null;
  ts: string;
  runId: string | null;
  sessionId: string | null;
  ownerAgentId: string | null;
  workspaceSlug: string | null;
  payload: Record<string, unknown>;
  insertedAt: string;
}

export interface SandboxStateRow {
  sandboxId: string;
  state: SandboxState;
  priorState: SandboxState | null;
  ts: string;
  ownerAgentId: string | null;
  workspaceSlug: string | null;
  reason: string | null;
  payload: Record<string, unknown>;
}

export type SnapshotKind = "filesystem" | "directory" | "memory";

export interface Snapshot {
  id: string;
  slug: string;
  sandboxId: string;
  kind: SnapshotKind;
  name: string | null;
  imageUri: string | null;
  path: string | null;
  sizeBytes: number | null;
  parentSnapshotId: string | null;
  createdByAgentId: string | null;
  workspaceSlug: string | null;
  retentionUntil: string | null;
  reapedAt: string | null;
  metadata: Record<string, unknown>;
  insertedAt: string;
  updatedAt: string;
}

export interface SnapshotCreate {
  slug: string;
  sandboxId: string;
  kind: SnapshotKind;
  name?: string;
  path?: string;
  parentSnapshotId?: string;
  workspaceSlug?: string;
}

export type PortProtocol = "http" | "https" | "tcp";
export type PortVisibility = "private" | "token" | "public";

export interface PortForward {
  id: string;
  sandboxId: string;
  internalPort: number;
  protocol: PortProtocol;
  visibility: PortVisibility;
  externalUrl: string | null;
  tcpEndpoint: string | null;
  label: string | null;
  processName: string | null;
  openedByAgentId: string | null;
  workspaceSlug: string | null;
  accessToken: string | null;
  closedAt: string | null;
  insertedAt: string;
  updatedAt: string;
}

export interface PortForwardCreate {
  sandboxId: string;
  internalPort: number;
  protocol?: PortProtocol;
  visibility?: PortVisibility;
  label?: string;
  confirmPublic?: boolean;
  workspaceSlug?: string;
}

export type AlertType = "threshold" | "composite";
export type AlertSeverity = "info" | "medium" | "high" | "critical";

export interface SandboxAlert {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  metric: string;
  type: AlertType;
  config: Record<string, unknown>;
  routing: Record<string, unknown>;
  enabled: boolean;
  severity: AlertSeverity;
  workspaceSlug: string | null;
  lastEvaluatedAt: string | null;
  lastFiredAt: string | null;
  fireCount: number;
  insertedAt: string;
  updatedAt: string;
}

export interface SandboxAlertCreate {
  slug: string;
  name: string;
  metric: string;
  type: AlertType;
  description?: string;
  config?: Record<string, unknown>;
  routing?: Record<string, unknown>;
  enabled?: boolean;
  severity?: AlertSeverity;
  workspaceSlug?: string;
}

/** All eight states in display order, used by lifecycle status grids. */
export const SANDBOX_STATE_ORDER: readonly SandboxState[] = [
  "provisioning",
  "running",
  "paused",
  "snapshotting",
  "resizing",
  "archived",
  "error",
  "destroyed",
] as const;
