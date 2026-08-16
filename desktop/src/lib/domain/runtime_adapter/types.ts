/**
 * Runtime Adapter domain types — match Elixir backend structs at
 * /api/v1/runtime-adapter/*. Keys arrive camelCased via the client conversion
 * layer.
 */

// ── Models / ModelInfo ────────────────────────────────────────────────────

export interface ModelInfoTier {
  name: string;
  thresholdTokens?: number;
  multiplier?: string;
}

export interface ModelInfo {
  maxTokens: number | null;
  contextWindow: number | null;
  supportsImages: boolean;
  supportsPromptCache: boolean;
  supportsReasoning: boolean;
  inputPrice: string | null;
  outputPrice: string | null;
  cacheWritesPrice: string | null;
  cacheReadsPrice: string | null;
  tiers: ModelInfoTier[];
}

export interface RuntimeAdapterModel {
  id: string;
  modelId: string;
  displayName: string | null;
  isDefault: boolean;
  info: ModelInfo;
}

export interface RuntimeAdapterModelList {
  runtimeId: string;
  models: RuntimeAdapterModel[];
}

// ── Roles ────────────────────────────────────────────────────────────────

export type ModelRoleName =
  | "chat"
  | "autocomplete"
  | "edit"
  | "apply"
  | "embed"
  | "rerank"
  | "summarize";

export const MODEL_ROLES: ModelRoleName[] = [
  "chat",
  "autocomplete",
  "edit",
  "apply",
  "embed",
  "rerank",
  "summarize",
];

export interface ModelRoleAssignment {
  id: string;
  runtime: string;
  model: string;
  role: ModelRoleName;
  defaultForRole: boolean;
  priority: number;
  workspaceSlug: string | null;
  metadata: Record<string, unknown>;
  insertedAt: string;
  updatedAt: string;
}

export interface RoleAssignmentCreate {
  runtime: string;
  model: string;
  role: ModelRoleName;
  defaultForRole?: boolean;
  priority?: number;
  workspaceSlug?: string;
  metadata?: Record<string, unknown>;
}

// ── Checkpoints ──────────────────────────────────────────────────────────

export interface RuntimeCheckpoint {
  id: string;
  sessionId: string;
  runtime: string;
  label: string | null;
  capturedAt: string;
  codeHash: string | null;
  transcriptId: string | null;
  transcriptSequence: number | null;
  agentMemory: Record<string, unknown>;
  parentCheckpointId: string | null;
  workspaceSlug: string | null;
  createdByAgentId: string | null;
  restoredAt: string | null;
  metadata: Record<string, unknown>;
  insertedAt: string;
  updatedAt: string;
}

export interface CheckpointCreate {
  sessionId: string;
  runtime: string;
  label?: string;
  codeHash?: string;
  transcriptId?: string;
  transcriptSequence?: number;
  agentMemory?: Record<string, unknown>;
  workspaceSlug?: string;
}

export interface CheckpointRestoreResult {
  ok: boolean;
  newCheckpointId: string;
  restoredCheckpointId: string;
}

// ── Suggestions / swap ───────────────────────────────────────────────────

export interface TaskHints {
  language?: string;
  requires?: string[];
  estTokens?: number;
}

export interface RuntimeSuggestion {
  runtimeId: string;
  score: number;
  reason: string;
}

export interface SuggestionResult {
  count: number;
  suggestions: RuntimeSuggestion[];
}

export interface SwapRequest {
  sessionId: string;
  currentRuntime: string;
  targetRuntime: string;
  agentId?: string;
  agentMemory?: Record<string, unknown>;
}

export interface SwapResult {
  ok: boolean;
  checkpointId: string;
  target: string;
  capturedAt: string;
}

// ── Settings policy (client-only state — persisted via runtime config) ───

export type RuntimeSelectionPolicy =
  | "manual"
  | "auto-cheapest"
  | "auto-fastest"
  | "auto-balanced";

export type CheckpointRetention = "session" | "7-days" | "30-days" | "forever";

export type HotSwapRule =
  | "always-confirm"
  | "auto-on-error"
  | "auto-to-local-only";

export interface RuntimeAdapterSettings {
  selectionPolicy: RuntimeSelectionPolicy;
  defaultModelByRole: Partial<Record<ModelRoleName, string>>;
  checkpointRetention: CheckpointRetention;
  hotSwapRule: HotSwapRule;
}
