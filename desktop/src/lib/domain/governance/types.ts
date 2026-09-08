/**
 * Governance domain types — matches the Elixir backend at /api/v1/governance/*.
 * Covers Rules, Approvals, and Audit log.
 */

// ── Rule ─────────────────────────────────────────────────────────────────────

/** Condition types that a rule can evaluate. */
export type RuleConditionType =
  | 'runtime'
  | 'agent_slug'
  | 'workspace_slug'
  | 'prompt_regex'
  | 'cost_over';

/** A single condition within a rule. */
export interface RuleCondition {
  type: RuleConditionType;
  value: string;
}

/** What the rule does when its conditions are met. */
export type RuleAction = 'block' | 'require_approval' | 'warn' | 'log';

/** Governance rule — controls which sessions require approval, warn, or block. */
export interface Rule {
  id: string;
  name: string;
  description: string | null;
  enabled: boolean;
  /** Higher priority wins first when multiple rules match. */
  priority: number;
  action: RuleAction;
  conditions: RuleCondition[];
  insertedAt: string;
  updatedAt: string;
}

// ── Approval ─────────────────────────────────────────────────────────────────

export type ApprovalStatus = 'pending' | 'approved' | 'rejected';

/** A session that triggered a require_approval rule and awaits a decision. */
export interface Approval {
  id: string;
  ruleId: string;
  ruleName: string;
  sessionId: string;
  status: ApprovalStatus;
  requestedAt: string;
  decidedAt: string | null;
  decidedBy: string | null;
  decisionReason: string | null;
  payload: Record<string, unknown>;
}

// ── Audit ─────────────────────────────────────────────────────────────────────

/** A single audit log entry — immutable record of governance events. */
export interface AuditEntry {
  id: string;
  eventType: string;
  ruleId: string | null;
  sessionId: string | null;
  payload: Record<string, unknown>;
  occurredAt: string;
  insertedAt: string;
}

// ── Filter Bodies ──────────────────────────────────────────────────────────────

/** Query params for GET /governance/approvals */
export interface ApprovalFilters {
  status?: ApprovalStatus;
}

/** Query params for GET /governance/audit */
export interface AuditFilters {
  event_type?: string;
  session_id?: string;
  /** ISO timestamp — return entries that occurred before this. */
  before?: string;
  /** ISO timestamp — return entries that occurred after this. */
  after?: string;
}

// ── Mutation Bodies ────────────────────────────────────────────────────────────

/** Body for POST /governance/rules */
export interface CreateRuleBody {
  name: string;
  description?: string;
  enabled: boolean;
  priority: number;
  action: RuleAction;
  conditions: RuleCondition[];
}

/** Body for PUT /governance/rules/:id */
export interface UpdateRuleBody {
  name?: string;
  description?: string;
  enabled?: boolean;
  priority?: number;
  action?: RuleAction;
  conditions?: RuleCondition[];
}

/** Body for POST /governance/approvals/:id/approve or /reject */
export interface DecisionBody {
  reason?: string;
  decided_by?: string;
}
