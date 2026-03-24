// src/lib/api/types.ts
// All TypeScript types for the Canopy Command Center API

// ── Health ────────────────────────────────────────────────────────────────────

export interface HealthResponse {
  status: "ok" | "degraded" | "error";
  version: string;
  provider: string | null;
  model?: string | null;
  context_window?: number | null;
  uptime_seconds?: number;
  agents_active?: number;
}

// ── Auth ──────────────────────────────────────────────────────────────────────

export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  user: User;
}

export interface User {
  id: string;
  email: string;
  name: string;
  role: UserRole;
  avatar_url?: string;
  created_at: string;
  inserted_at?: string;
}

export type UserRole = "admin" | "member" | "viewer";

// ── Sessions ──────────────────────────────────────────────────────────────────

export interface Session {
  id: string;
  agent_id: string;
  agent_name: string;
  title: string | null;
  status: "active" | "completed" | "failed" | "cancelled";
  message_count: number;
  token_usage: TokenUsage;
  cost_cents: number;
  started_at: string;
  completed_at: string | null;
  created_at: string;
}

export interface TokenUsage {
  input: number;
  output: number;
  cache_read: number;
  cache_write: number;
}

export interface CreateSessionRequest {
  agent_id: string;
  title?: string;
  context?: string;
}

// ── Messages ──────────────────────────────────────────────────────────────────

export type MessageRole = "user" | "assistant" | "system" | "tool";

export interface ToolCallRef {
  id: string;
  name: string;
  input: Record<string, unknown>;
}

export interface ThinkingBlock {
  type: "thinking";
  thinking: string;
}

export interface Message {
  id: string;
  session_id: string;
  role: MessageRole;
  content: string;
  timestamp: string;
  tool_calls?: ToolCallRef[];
  thinking?: ThinkingBlock;
  token_usage?: TokenUsage;
}

export interface SendMessageRequest {
  session_id: string;
  content: string;
  agent_id?: string;
  model?: string;
  stream?: boolean;
}

export interface SendMessageResponse {
  stream_id: string;
  session_id: string;
}

// ── SSE Streaming Events ──────────────────────────────────────────────────────

export type StreamEventType =
  | "streaming_token"
  | "thinking_delta"
  | "tool_call"
  | "tool_result"
  | "system_event"
  | "done"
  | "error";

export interface StreamingTokenEvent {
  type: "streaming_token";
  delta: string;
}

export interface ThinkingDeltaEvent {
  type: "thinking_delta";
  delta: string;
}

export interface ToolCallEvent {
  type: "tool_call";
  tool_use_id: string;
  tool_name: string;
  input: Record<string, unknown>;
  phase?: "awaiting_permission";
  description?: string;
  paths?: string[];
}

export interface ToolResultEvent {
  type: "tool_result";
  tool_use_id: string;
  result: string;
  is_error: boolean;
}

export interface SystemEvent {
  type: "system_event";
  event: string;
  payload?: unknown;
}

export interface DoneEvent {
  type: "done";
  session_id: string;
  message_id: string;
}

export interface ErrorEvent {
  type: "error";
  message: string;
  code?: string;
}

export type StreamEvent =
  | StreamingTokenEvent
  | ThinkingDeltaEvent
  | ToolCallEvent
  | ToolResultEvent
  | SystemEvent
  | DoneEvent
  | ErrorEvent;

// ── Agents ────────────────────────────────────────────────────────────────────

export type AgentStatus =
  | "idle"
  | "running"
  | "sleeping"
  | "paused"
  | "error"
  | "terminated"
  | "active"
  | "working";
export type AgentLifecycleAction =
  | "wake"
  | "sleep"
  | "focus"
  | "pause"
  | "resume"
  | "terminate";

export interface CanopyAgent {
  id: string;
  name: string;
  display_name: string;
  avatar_emoji: string;
  role: string;
  status: AgentStatus;
  adapter: AdapterType;
  model: string;
  system_prompt: string;
  temperature?: number;
  max_concurrent_runs?: number;
  config: Record<string, unknown>;
  skills: string[];
  team_id?: string | null;
  schedule_id: string | null;
  budget_policy_id: string | null;
  current_task: string | null;
  last_active_at: string | null;
  token_usage_today: TokenUsage;
  cost_today_cents: number;
  created_at: string;
  updated_at: string;
}

export interface AgentCreateRequest {
  name: string;
  display_name: string;
  slug?: string;
  workspace_id?: string;
  avatar_emoji?: string;
  role: string;
  adapter: AdapterType;
  model: string;
  system_prompt?: string;
  temperature?: number;
  max_concurrent_runs?: number;
  config?: Record<string, unknown>;
  skills?: string[];
  budget_policy?: BudgetPolicyInput;
  schedule?: ScheduleInput;
}

export type AdapterType =
  | "osa"
  | "claude_code"
  | "claude-code"
  | "codex"
  | "openclaw"
  | "jidoclaw"
  | "hermes"
  | "bash"
  | "http"
  | "cursor"
  | "gemini"
  | "custom";

// ── Agent Hierarchy ───────────────────────────────────────────────────────────

export type OrgRole = "ceo" | "director" | "lead" | "engineer" | "specialist";

export interface HierarchyNode {
  agent_id: string;
  agent_name: string;
  reports_to: string | null;
  org_role: OrgRole;
  title: string | null;
  org_order: number;
  children: HierarchyNode[];
}

// ── Schedules ─────────────────────────────────────────────────────────────────

export interface Schedule {
  id: string;
  agent_id: string;
  agent_name: string;
  cron: string;
  human_readable: string;
  enabled: boolean;
  context: string;
  next_run_at: string | null;
  last_run_at: string | null;
  last_run_status: "succeeded" | "failed" | null;
  run_count: number;
  created_at: string;
  updated_at: string;
}

export interface ScheduleInput {
  cron: string;
  context?: string;
  enabled?: boolean;
}

export interface HeartbeatRun {
  id: string;
  schedule_id: string;
  agent_id: string;
  agent_name: string;
  status:
    | "pending"
    | "running"
    | "succeeded"
    | "failed"
    | "timed_out"
    | "cancelled";
  trigger: "schedule" | "manual" | "event";
  started_at: string;
  completed_at: string | null;
  duration_ms: number | null;
  token_usage: TokenUsage | null;
  cost_cents: number | null;
  output_summary: string | null;
  error_message: string | null;
}

export interface CronPreset {
  id: string;
  cron: string;
  label: string;
  description: string;
}

// ── Workflows ─────────────────────────────────────────────────────────────────

export type WorkflowStatus = "draft" | "active" | "paused" | "archived";
export type WorkflowTriggerType = "manual" | "schedule" | "webhook" | "event";
export type WorkflowStepType =
  | "agent_task"
  | "condition"
  | "delay"
  | "webhook"
  | "transform";
export type WorkflowRunStatus =
  | "pending"
  | "running"
  | "completed"
  | "failed"
  | "cancelled";
export type StepOnFailure = "stop" | "skip" | "retry" | "fallback";

export interface WorkflowStep {
  id: string;
  workflow_id: string;
  agent_id: string | null;
  agent_name: string | null;
  agent_emoji: string | null;
  name: string;
  step_type: WorkflowStepType;
  position: number;
  config: Record<string, unknown>;
  depends_on: string[];
  timeout_seconds: number;
  retry_count: number;
  on_failure: StepOnFailure;
  inserted_at: string;
  updated_at: string;
}

export interface WorkflowRun {
  id: string;
  workflow_id: string;
  status: WorkflowRunStatus;
  trigger_event: string | null;
  input: Record<string, unknown>;
  output: Record<string, unknown>;
  started_at: string | null;
  completed_at: string | null;
  error: string | null;
  step_results: Record<string, unknown>;
  inserted_at: string;
  updated_at: string;
}

export interface Workflow {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  status: WorkflowStatus;
  trigger_type: WorkflowTriggerType;
  trigger_config: Record<string, unknown>;
  created_by: string | null;
  version: number;
  workspace_id: string | null;
  organization_id: string | null;
  step_count: number;
  last_run_at: string | null;
  steps: WorkflowStep[];
  inserted_at: string;
  updated_at: string;
}

export interface WorkflowCreateRequest {
  name: string;
  slug: string;
  description?: string;
  trigger_type?: WorkflowTriggerType;
  workspace_id?: string;
  steps?: Array<{
    name: string;
    agent_id?: string;
    step_type?: WorkflowStepType;
    position: number;
    config?: Record<string, unknown>;
  }>;
}

// ── Issues ────────────────────────────────────────────────────────────────────

export type IssueStatus =
  | "backlog"
  | "todo"
  | "in_progress"
  | "in_review"
  | "done";
export type IssuePriority = "low" | "medium" | "high" | "critical";

export interface Issue {
  id: string;
  title: string;
  description: string | null;
  status: IssueStatus;
  priority: IssuePriority;
  assignee_id: string | null;
  assignee_name: string | null;
  project_id: string | null;
  goal_id: string | null;
  labels: string[];
  comments_count: number;
  created_by: string;
  created_at: string;
  updated_at: string;
}

export interface IssueComment {
  id: string;
  issue_id: string;
  author: string;
  author_type: "human" | "agent";
  content: string;
  created_at: string;
}

// ── Goals ─────────────────────────────────────────────────────────────────────

export type GoalStatus = "active" | "in_progress" | "completed" | "blocked";
export type GoalPriority = "low" | "medium" | "high";

export interface Goal {
  id: string;
  title: string;
  description: string | null;
  parent_id: string | null;
  project_id: string;
  status: GoalStatus;
  priority: GoalPriority;
  progress: number;
  assignee_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface GoalTreeNode extends Goal {
  children: GoalTreeNode[];
  issue_count: number;
}

// ── Projects ──────────────────────────────────────────────────────────────────

export type ProjectStatus = "active" | "completed" | "archived";

export interface Project {
  id: string;
  name: string;
  description: string | null;
  status: ProjectStatus;
  workspace_id?: string;
  workspace_path: string | null;
  goal_count: number;
  issue_count: number;
  agent_count: number;
  created_at: string;
  updated_at: string;
}

// ── Documents ─────────────────────────────────────────────────────────────────

export interface Document {
  id: string;
  title: string;
  path: string;
  content: string;
  format: "markdown" | "yaml" | "json" | "text";
  project_id: string | null;
  last_edited_by: string;
  created_at: string;
  updated_at: string;
}

export interface DocumentTreeNode {
  name: string;
  path: string;
  type: "file" | "directory";
  children?: DocumentTreeNode[];
}

// ── Inbox ─────────────────────────────────────────────────────────────────────

export type InboxItemType =
  | "approval"
  | "alert"
  | "mention"
  | "failure"
  | "report"
  | "budget_warning";
export type InboxItemStatus = "unread" | "read" | "actioned" | "dismissed";

export interface InboxItem {
  id: string;
  type: InboxItemType;
  status: InboxItemStatus;
  title: string;
  body: string;
  source_agent: string | null;
  source_entity_type: string | null;
  source_entity_id: string | null;
  actions: InboxAction[];
  created_at: string;
}

export interface InboxAction {
  id: string;
  label: string;
  type: "approve" | "reject" | "acknowledge" | "snooze" | "navigate";
  payload?: Record<string, unknown>;
}

// ── Activity ──────────────────────────────────────────────────────────────────

export type ActivityEventType =
  | "agent_woke"
  | "agent_slept"
  | "agent_error"
  | "heartbeat_started"
  | "heartbeat_completed"
  | "heartbeat_failed"
  | "issue_created"
  | "issue_updated"
  | "goal_completed"
  | "budget_warning"
  | "budget_exceeded"
  | "session_started"
  | "session_completed"
  | "skill_triggered"
  | "config_changed"
  | "deployment";

export interface ActivityEvent {
  id: string;
  type: ActivityEventType;
  agent_id: string | null;
  agent_name: string | null;
  title: string;
  detail: string | null;
  level: "info" | "warning" | "error" | "success";
  metadata: Record<string, unknown>;
  created_at: string;
}

// ── Costs & Budget ────────────────────────────────────────────────────────────

export interface CostSummary {
  today_cents: number;
  week_cents: number;
  month_cents: number;
  daily_budget_cents: number;
  monthly_budget_cents: number;
  daily_remaining_cents: number;
  monthly_remaining_cents: number;
  cache_savings_cents: number;
}

export interface AgentCostBreakdown {
  agent_id: string;
  agent_name: string;
  cost_cents: number;
  token_usage: TokenUsage;
  run_count: number;
  percentage: number;
}

export interface ModelCostBreakdown {
  model: string;
  cost_cents: number;
  token_usage: TokenUsage;
  request_count: number;
}

export interface CostEvent {
  id: string;
  agent_id: string;
  agent_name: string;
  session_id: string | null;
  provider: string;
  model: string;
  token_usage: TokenUsage;
  cost_cents: number;
  created_at: string;
}

export interface BudgetPolicy {
  id: string;
  name: string;
  daily_limit_cents: number;
  monthly_limit_cents: number;
  per_run_limit_cents: number;
  warning_threshold: number;
  hard_stop: boolean;
  agent_ids: string[];
  created_at: string;
  updated_at: string;
}

export interface BudgetPolicyInput {
  daily_limit_cents: number;
  monthly_limit_cents: number;
  per_run_limit_cents?: number;
  warning_threshold?: number;
  hard_stop?: boolean;
}

export interface BudgetIncident {
  id: string;
  agent_id: string;
  agent_name: string;
  policy_id: string;
  type: "warning" | "hard_stop" | "anomaly";
  amount_cents: number;
  limit_cents: number;
  message: string;
  resolved: boolean;
  created_at: string;
}

// ── Skills ────────────────────────────────────────────────────────────────────

export type SkillSource = "builtin" | "user" | "marketplace" | "evolved";
export type SkillCategory =
  | "core"
  | "automation"
  | "reasoning"
  | "workflow"
  | "security"
  | "agent"
  | "utility";

export interface Skill {
  id: string;
  name: string;
  description: string;
  category: SkillCategory;
  source: SkillSource;
  enabled: boolean;
  triggers: string[];
  version: string;
  author: string;
  downloads: number;
  rating: number;
}

// ── Webhooks ──────────────────────────────────────────────────────────────────

export interface Webhook {
  id: string;
  name: string;
  direction: "incoming" | "outgoing";
  url: string;
  events: string[];
  secret: string | null;
  enabled: boolean;
  last_triggered_at: string | null;
  failure_count: number;
  created_at: string;
}

export interface WebhookDelivery {
  id: string;
  webhook_id: string;
  event_type: string;
  status: "success" | "failed" | "pending";
  status_code: number | null;
  response_body: string | null;
  created_at: string;
}

// ── Alerts ────────────────────────────────────────────────────────────────────

export interface AlertRule {
  id: string;
  name: string;
  entity_type: "agent" | "budget" | "schedule" | "system";
  entity?: "agent" | "budget" | "schedule" | "system";
  field: string;
  operator: "eq" | "neq" | "gt" | "lt" | "gte" | "lte" | "contains";
  value: string;
  action: "notify" | "pause_agent" | "webhook" | "email";
  enabled: boolean;
  triggered_count: number;
  last_triggered_at: string | null;
  created_at: string;
}

// ── Integrations ──────────────────────────────────────────────────────────────

export type IntegrationCategory =
  | "version_control"
  | "communication"
  | "ci_cd"
  | "monitoring"
  | "storage"
  | "auth"
  | "custom";

export interface Integration {
  id: string;
  name: string;
  category: IntegrationCategory;
  provider: string;
  icon_url: string | null;
  status: "connected" | "disconnected" | "error";
  config: Record<string, unknown>;
  last_sync_at: string | null;
  created_at: string;
}

// ── Adapters ──────────────────────────────────────────────────────────────────

export interface Adapter {
  id: string;
  type: AdapterType;
  name: string;
  description: string;
  status: "available" | "configured" | "error";
  config: Record<string, unknown>;
  agent_count: number;
}

// ── Gateways ──────────────────────────────────────────────────────────────────

export interface Gateway {
  id: string;
  name: string;
  provider: string;
  endpoint: string;
  api_key_set: boolean;
  is_primary: boolean;
  status: "healthy" | "degraded" | "down" | "connected" | "error";
  latency_ms: number | null;
  last_probe_at: string | null;
  models: string[];
  created_at: string;
}

// ── Workspaces ────────────────────────────────────────────────────────────────

export interface Workspace {
  id: string;
  name: string;
  description: string | null;
  directory: string;
  path?: string;
  agent_count: number;
  project_count: number;
  skill_count: number;
  status: "active" | "archived";
  created_at: string;
  updated_at: string;
}

// ── Dashboard ─────────────────────────────────────────────────────────────────

export interface DashboardData {
  kpis: DashboardKpis;
  live_runs: LiveRun[];
  recent_activity: ActivityEvent[];
  finance_summary: FinanceSummary;
  system_health: SystemHealth;
}

export interface DashboardKpis {
  active_agents: number;
  total_agents: number;
  live_runs: number;
  open_issues: number;
  budget_remaining_pct: number;
}

export interface LiveRun {
  id: string;
  agent_id: string;
  agent_name: string;
  agent_emoji: string;
  task: string;
  status: "running" | "pending";
  started_at: string;
  elapsed_ms: number;
  tokens_used: number;
}

export interface FinanceSummary {
  today_cents: number;
  week_cents: number;
  month_cents: number;
  daily_limit_cents: number;
  cache_savings_pct: number;
}

export interface SystemHealth {
  backend: "ok" | "degraded" | "error";
  primary_gateway: string | null;
  gateway_status: "healthy" | "degraded" | "down";
  memory_mb: number;
  cpu_pct: number;
}

// ── Signals ───────────────────────────────────────────────────────────────────

export type SignalMode =
  | "BUILD"
  | "EXECUTE"
  | "ANALYZE"
  | "MAINTAIN"
  | "ASSIST";
export type SignalGenre = "DIRECT" | "INFORM" | "COMMIT" | "DECIDE" | "EXPRESS";
export type SignalTier = "haiku" | "sonnet" | "opus";

export interface Signal {
  id: string;
  session_id: string;
  channel: string;
  mode: SignalMode;
  genre: SignalGenre;
  tier: SignalTier;
  weight: number;
  agent_name: string;
  input_preview: string;
  failure_mode: string | null;
  created_at: string;
}

export interface SignalPattern {
  pattern: string;
  count: number;
  avg_weight: number;
  channels: string[];
  failure_rate: number;
}

export interface SignalStats {
  total: number;
  by_mode: Record<string, number>;
  by_tier: Record<string, number>;
  by_channel: Record<string, number>;
  failure_count: number;
  avg_weight: number;
  period_hours: number;
}

// ── Audit ─────────────────────────────────────────────────────────────────────

export interface AuditEntry {
  id: string;
  actor: string;
  actor_type: "human" | "agent" | "system";
  action: string;
  entity_type: string;
  entity_id: string;
  details: Record<string, unknown>;
  ip_address: string | null;
  created_at: string;
}

// ── Config ────────────────────────────────────────────────────────────────────

export interface ConfigEntry {
  key: string;
  value: unknown;
  type: "string" | "number" | "boolean" | "object" | "array";
  description: string;
  editable: boolean;
}

export interface ConfigRevision {
  id: string;
  entity_type: string;
  entity_id: string;
  revision_number: number;
  previous_config: Record<string, unknown> | null;
  new_config: Record<string, unknown>;
  changed_fields: string[];
  changed_by: string;
  change_reason: string | null;
  created_at: string;
}

// ── Templates ─────────────────────────────────────────────────────────────────

export interface AgentTemplate {
  id: string;
  name: string;
  description: string;
  adapter: AdapterType;
  model: string;
  system_prompt: string;
  skills: string[];
  config: Record<string, unknown>;
  category: string;
  downloads: number;
  created_at: string;
}

// ── Memory ────────────────────────────────────────────────────────────────────

export interface MemoryEntryMetadata {
  agent: string;
  agent_id: string;
  created_at: string;
  updated_at: string;
  access_count: number;
  ttl_seconds: number | null;
}

export interface MemoryEntry {
  id: string;
  namespace: string;
  key: string;
  value: string;
  value_type: "string" | "json";
  metadata: MemoryEntryMetadata;
  // Legacy fields kept for backward compat
  agent_id?: string;
  agent_name?: string;
  type?: "episodic" | "semantic" | "procedural";
  content?: string;
  embedding_preview?: number[];
  relevance_score?: number;
  created_at?: string;
}

export interface MemoryNamespace {
  name: string;
  count: number;
}

export interface MemoryCreateRequest {
  namespace: string;
  key: string;
  value: string;
  value_type: "string" | "json";
  ttl_seconds?: number | null;
}

// ── Spawn ─────────────────────────────────────────────────────────────────────

export interface SpawnInstance {
  id: string;
  agent_id: string;
  agent_name: string;
  task: string;
  model: string;
  status: "running" | "completed" | "failed";
  started_at: string;
  completed_at: string | null;
  token_usage: TokenUsage | null;
  cost_cents: number | null;
}

// ── Resilience ────────────────────────────────────────────────────────────────

export interface QueuedRequest {
  id: string;
  method: string;
  path: string;
  body?: unknown;
  timestamp: number;
}

// ── Log Entries ───────────────────────────────────────────────────────────────

export interface LogEntry {
  id: string;
  level: "debug" | "info" | "warning" | "error";
  source: string;
  message: string;
  metadata: Record<string, unknown>;
  created_at: string;
}

// ── Settings ──────────────────────────────────────────────────────────────────

export interface Settings {
  theme: "dark" | "glass" | "color" | "light" | "system";
  font_size: number;
  sidebar_default_collapsed: boolean;
  notifications_enabled: boolean;
  auto_approve_budget_under_cents: number;
  default_adapter: AdapterType;
  default_model: string;
  working_directory: string;
  // Instance configuration (merged from /config)
  max_concurrent_agents: number;
  session_timeout_minutes: number;
  log_level: "debug" | "info" | "warn" | "error";
  telemetry_enabled: boolean;
  activity_retention_days: number;
  budget_enforcement: boolean;
}

// ── Secrets ───────────────────────────────────────────────────────────────────

export type SecretType =
  | "api_key"
  | "password"
  | "token"
  | "certificate"
  | "other";

export interface Secret {
  id: string;
  name: string;
  type: SecretType;
  description: string | null;
  last_rotated_at: string | null;
  expires_at: string | null;
  created_by: string;
  created_at: string;
  updated_at: string;
}

export interface SecretCreateRequest {
  name: string;
  type: SecretType;
  value: string;
  description?: string;
  expires_at?: string | null;
}

// ── Approvals ─────────────────────────────────────────────────────────────────

export type ApprovalStatus = "pending" | "approved" | "rejected" | "expired";

export interface Approval {
  id: string;
  title: string;
  description: string | null;
  status: ApprovalStatus;
  requester_id: string;
  requester_name: string;
  reviewer_id: string | null;
  reviewer_name: string | null;
  entity_type: string | null;
  entity_id: string | null;
  comment: string | null;
  expires_at: string | null;
  reviewed_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface ApprovalComment {
  comment: string;
}

export interface ApprovalCreateRequest {
  title: string;
  description?: string;
  entity_type?: string;
  entity_id?: string;
  expires_at?: string | null;
}

// ── Organizations ─────────────────────────────────────────────────────────────

export type OrganizationRole = "owner" | "admin" | "member" | "viewer";

export interface Organization {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  avatar_url: string | null;
  plan: "free" | "pro" | "enterprise";
  member_count: number;
  agent_count: number;
  budget_monthly_cents: number | null;
  budget_per_agent_cents: number | null;
  budget_enforcement: "soft" | "hard" | null;
  governance: string | null;
  mission: string | null;
  created_at: string;
  updated_at: string;
}

export interface OrganizationMembership {
  id: string;
  organization_id: string;
  user_id: string;
  user_name: string;
  user_email: string;
  role: OrganizationRole;
  joined_at: string;
}

export interface Invitation {
  id: string;
  organization_id: string;
  email: string;
  role: OrganizationRole;
  invited_by: string;
  expires_at: string;
  accepted_at: string | null;
  created_at: string;
}

export interface OrganizationCreateRequest {
  name: string;
  slug?: string;
  description?: string;
}

// ── Divisions ─────────────────────────────────────────────────────────────────

export interface Division {
  id: string;
  organization_id: string;
  name: string;
  slug: string;
  description: string | null;
  head_agent_id: string | null;
  budget_monthly_cents: number | null;
  budget_enforcement: "soft" | "hard" | null;
  signal: string | null;
  mission: string | null;
  operating_model: string | null;
  coordination: string | null;
  escalation_rules: string | null;
  inserted_at: string;
  updated_at: string;
}

// ── Departments ───────────────────────────────────────────────────────────────

export interface Department {
  id: string;
  division_id: string;
  name: string;
  slug: string;
  description: string | null;
  head_agent_id: string | null;
  budget_monthly_cents: number | null;
  budget_enforcement: "soft" | "hard" | null;
  signal: string | null;
  mission: string | null;
  teams_overview: string | null;
  coordination: string | null;
  escalation_rules: string | null;
  inserted_at: string;
  updated_at: string;
}

// ── Teams ─────────────────────────────────────────────────────────────────────

export interface Team {
  id: string;
  department_id: string;
  name: string;
  slug: string;
  description: string | null;
  manager_agent_id: string | null;
  budget_monthly_cents: number | null;
  budget_enforcement: "soft" | "hard" | null;
  signal: string | null;
  mission: string | null;
  coordination: string | null;
  escalation_rules: string | null;
  handoff_protocols: string | null;
  inserted_at: string;
  updated_at: string;
}

export interface TeamMembership {
  id: string;
  team_id: string;
  agent_id: string;
  role: "member" | "manager";
  inserted_at: string;
}

// ── Hierarchy Tree ────────────────────────────────────────────────────────────

export interface HierarchyTeamNode extends Team {
  agents: CanopyAgent[];
}

export interface HierarchyDepartmentNode extends Department {
  teams: HierarchyTeamNode[];
}

export interface HierarchyDivisionNode extends Division {
  departments: HierarchyDepartmentNode[];
}

export interface HierarchyTree {
  organization: Organization;
  divisions: HierarchyDivisionNode[];
}

// ── Labels ────────────────────────────────────────────────────────────────────

export interface Label {
  id: string;
  name: string;
  color: string;
  description: string | null;
  project_id: string | null;
  issue_count: number;
  created_at: string;
}

export interface LabelCreateRequest {
  name: string;
  color: string;
  description?: string;
  project_id?: string;
}

// ── Attachments ───────────────────────────────────────────────────────────────

export interface Attachment {
  id: string;
  entity_type: string;
  entity_id: string;
  filename: string;
  content_type: string;
  size_bytes: number;
  url: string;
  uploaded_by: string;
  created_at: string;
}

// ── Work Products ─────────────────────────────────────────────────────────────

export type WorkProductKind =
  | "report"
  | "plan"
  | "analysis"
  | "code"
  | "spec"
  | "other";

export interface WorkProduct {
  id: string;
  title: string;
  kind: WorkProductKind;
  content: string;
  format: "markdown" | "json" | "text" | "yaml";
  agent_id: string | null;
  agent_name: string | null;
  session_id: string | null;
  project_id: string | null;
  created_at: string;
  updated_at: string;
}

// ── Plugins ───────────────────────────────────────────────────────────────────

export type PluginStatus = "active" | "inactive" | "error" | "installing";

export interface Plugin {
  id: string;
  name: string;
  description: string;
  version: string;
  author: string;
  status: PluginStatus;
  enabled: boolean;
  config: Record<string, unknown>;
  capabilities: string[];
  installed_at: string;
  updated_at: string;
}

export interface PluginLog {
  id: string;
  plugin_id: string;
  level: "debug" | "info" | "warning" | "error";
  message: string;
  metadata: Record<string, unknown>;
  created_at: string;
}

// ── Role Assignments ──────────────────────────────────────────────────────────

export interface RoleAssignment {
  id: string;
  user_id: string;
  user_name: string;
  user_email: string;
  role: UserRole;
  entity_type: "organization" | "project" | "global";
  entity_id: string | null;
  assigned_by: string;
  created_at: string;
}

// ── Sidebar Badges ────────────────────────────────────────────────────────────

export interface SidebarBadges {
  inbox_unread: number;
  approvals_pending: number;
  issues_open: number;
  agents_error: number;
  budget_warnings: number;
}

// ── Execution Workspace ───────────────────────────────────────────────────────

export interface ExecutionWorkspace {
  id: string;
  agent_id: string;
  session_id: string | null;
  directory: string;
  status: "active" | "idle" | "archived";
  file_count: number;
  size_bytes: number;
  created_at: string;
  updated_at: string;
}

// ── Document Revisions ────────────────────────────────────────────────────────

export interface DocumentRevision {
  id: string;
  document_id: string;
  revision_number: number;
  content: string;
  changed_by: string;
  change_summary: string | null;
  created_at: string;
}

// ── Conversations ─────────────────────────────────────────────────────────────

export type ConversationStatus = "active" | "archived" | "closed";

export interface Conversation {
  id: string;
  title: string | null;
  agent_id: string;
  agent_name: string | null;
  agent_avatar: string | null;
  workspace_id: string | null;
  user_id: string | null;
  status: ConversationStatus;
  last_message_at: string | null;
  message_count: number;
  metadata: Record<string, unknown>;
  inserted_at: string;
  updated_at: string;
}

export type ConversationMessageRole = "user" | "agent" | "system";
export type ConversationMessageContentType =
  | "text"
  | "markdown"
  | "code"
  | "image"
  | "tool_result";

export interface ConversationMessage {
  id: string;
  conversation_id: string;
  role: ConversationMessageRole;
  content: string;
  content_type: ConversationMessageContentType;
  metadata: Record<string, unknown>;
  token_count: number | null;
  cost_cents: number | null;
  inserted_at: string;
}

export interface ConversationCreateRequest {
  agent_id: string;
  title?: string;
  workspace_id?: string;
}

export interface SendConversationMessageRequest {
  content: string;
}

export interface SendConversationMessageResponse {
  user_message: ConversationMessage;
  agent_message: ConversationMessage;
}

// ── Datasets ──────────────────────────────────────────────────────────────────

export type DatasetSourceType =
  | "upload"
  | "api"
  | "database"
  | "agent_generated"
  | "stream";

export type DatasetFormat = "csv" | "json" | "parquet" | "sql" | "api";

export type DatasetStatus = "active" | "processing" | "stale" | "archived";

export interface DatasetColumn {
  name: string;
  type:
    | "string"
    | "integer"
    | "float"
    | "boolean"
    | "timestamp"
    | "date"
    | "object"
    | "array";
  nullable: boolean;
  description?: string;
}

export interface DatasetSchemaDefinition {
  columns: DatasetColumn[];
}

export interface Dataset {
  id: string;
  workspace_id: string | null;
  created_by_agent_id: string | null;
  name: string;
  slug: string;
  description: string | null;
  source_type: DatasetSourceType;
  format: DatasetFormat;
  schema_definition: DatasetSchemaDefinition | null;
  row_count: number;
  size_bytes: number;
  status: DatasetStatus;
  refresh_schedule: string | null;
  last_refreshed_at: string | null;
  tags: string[];
  access_agents: string[];
  inserted_at: string;
  updated_at: string;
}

export interface DatasetCreateRequest {
  name: string;
  slug: string;
  description?: string;
  source_type: DatasetSourceType;
  format: DatasetFormat;
  schema_definition?: DatasetSchemaDefinition;
  row_count?: number;
  size_bytes?: number;
  status?: DatasetStatus;
  refresh_schedule?: string;
  tags?: string[];
  workspace_id?: string;
}

export interface DatasetPreviewRow {
  [column: string]: string | number | boolean | null;
}

export interface DatasetPreviewResponse {
  rows: DatasetPreviewRow[];
  total: number;
  preview_limit: number;
}

// ── Notifications ─────────────────────────────────────────────────────────────

export type NotificationCategory =
  | "task"
  | "approval"
  | "alert"
  | "mention"
  | "system"
  | "budget"
  | "workflow";

export type NotificationSeverity = "info" | "warning" | "error" | "critical";

export interface Notification {
  id: string;
  workspace_id: string;
  recipient_type: "user" | "agent" | "team" | "broadcast";
  recipient_id: string | null;
  sender_type: "system" | "agent" | "user" | "workflow" | null;
  sender_id: string | null;
  category: NotificationCategory;
  severity: NotificationSeverity;
  title: string;
  body: string | null;
  action_url: string | null;
  action_label: string | null;
  metadata: Record<string, unknown>;
  read_at: string | null;
  dismissed_at: string | null;
  expires_at: string | null;
  inserted_at: string;
}

export interface NotificationBadges {
  unread: number;
  by_category: Record<string, number>;
  by_severity: Record<string, number>;
}

export interface NotificationFilters {
  category?: NotificationCategory;
  severity?: NotificationSeverity;
  unread?: boolean;
  limit?: number;
  offset?: number;
}

// ── Reports ───────────────────────────────────────────────────────────────────

export type ReportType =
  | "agent_performance"
  | "cost_analysis"
  | "task_summary"
  | "workflow_audit"
  | "custom";

export type ReportFormat = "table" | "chart" | "pdf" | "csv";
export type ReportStatus = "active" | "generating" | "archived";

export interface ReportCachedResult {
  summary: Record<string, unknown>;
  columns: string[];
  rows: (string | number)[][];
  chart_data?: Array<{ label: string; value: number; secondary?: number }>;
}

export interface Report {
  id: string;
  name: string;
  description: string | null;
  report_type: ReportType;
  config: Record<string, unknown>;
  schedule: string | null;
  last_generated_at: string | null;
  format: ReportFormat;
  status: ReportStatus;
  cached_result: ReportCachedResult | null;
  tags: string[];
  workspace_id: string | null;
  created_by_id: string | null;
  inserted_at: string;
  updated_at: string;
}

export interface ReportCreateRequest {
  name: string;
  description?: string;
  report_type: ReportType;
  config: Record<string, unknown>;
  schedule?: string;
  format?: ReportFormat;
  tags?: string[];
}
