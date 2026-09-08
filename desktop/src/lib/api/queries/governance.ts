/**
 * TanStack Query factories for the /governance resource.
 * Covers Rules (CRUD), Approvals (list + approve/reject), and Audit log.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import { apiDelete, apiGet, apiPost, apiPut } from '$lib/api/client.js';
import type {
  Approval,
  ApprovalFilters,
  ApprovalStatus,
  AuditEntry,
  AuditFilters,
  CreateRuleBody,
  DecisionBody,
  Rule,
  UpdateRuleBody,
} from '$lib/domain/governance/types.js';

// ── Raw API calls ─────────────────────────────────────────────────────────────

export function listRules(): Promise<Rule[]> {
  return apiGet<Rule[]>('/governance/rules');
}

export function createRule(body: CreateRuleBody): Promise<Rule> {
  return apiPost<Rule>('/governance/rules', body);
}

export function updateRule(id: string, body: UpdateRuleBody): Promise<Rule> {
  return apiPut<Rule>(`/governance/rules/${id}`, body);
}

export function deleteRule(id: string): Promise<void> {
  return apiDelete<void>(`/governance/rules/${id}`);
}

export function listApprovals(filters?: ApprovalFilters): Promise<Approval[]> {
  const params = new URLSearchParams();
  if (filters?.status) params.set('status', filters.status);
  const qs = params.toString();
  return apiGet<Approval[]>(`/governance/approvals${qs ? `?${qs}` : ''}`);
}

export function approveApproval(id: string, body?: DecisionBody): Promise<Approval> {
  return apiPost<Approval>(`/governance/approvals/${id}/approve`, body ?? {});
}

export function rejectApproval(id: string, body?: DecisionBody): Promise<Approval> {
  return apiPost<Approval>(`/governance/approvals/${id}/reject`, body ?? {});
}

export function listAudit(filters?: AuditFilters): Promise<AuditEntry[]> {
  const params = new URLSearchParams();
  if (filters?.event_type) params.set('event_type', filters.event_type);
  if (filters?.session_id) params.set('session_id', filters.session_id);
  if (filters?.before) params.set('before', filters.before);
  if (filters?.after) params.set('after', filters.after);
  const qs = params.toString();
  return apiGet<AuditEntry[]>(`/governance/audit${qs ? `?${qs}` : ''}`);
}

// ── TanStack Query option factories ──────────────────────────────────────────

/** Query options for the full rules list. */
export function rulesQuery() {
  return {
    queryKey: ['governance', 'rules'] as const,
    queryFn: () => listRules(),
    staleTime: 30_000,
  };
}

/** Mutation options to create a new governance rule. */
export function createRuleMutation() {
  return {
    mutationKey: ['governance', 'rules', 'create'] as const,
    mutationFn: (body: CreateRuleBody) => createRule(body),
  };
}

/** Mutation options to update an existing governance rule. */
export function updateRuleMutation() {
  return {
    mutationKey: ['governance', 'rules', 'update'] as const,
    mutationFn: ({ id, body }: { id: string; body: UpdateRuleBody }) => updateRule(id, body),
  };
}

/** Mutation options to delete a governance rule. */
export function deleteRuleMutation() {
  return {
    mutationKey: ['governance', 'rules', 'delete'] as const,
    mutationFn: (id: string) => deleteRule(id),
  };
}

/** Query options for the approvals list with optional status filter. */
export function approvalsQuery(status?: ApprovalStatus) {
  const filters: ApprovalFilters = status ? { status } : {};
  return {
    queryKey: ['governance', 'approvals', status ?? 'all'] as const,
    queryFn: () => listApprovals(filters),
    staleTime: 10_000,
  };
}

/** Mutation options to approve a pending approval. */
export function approveApprovalMutation() {
  return {
    mutationKey: ['governance', 'approvals', 'approve'] as const,
    mutationFn: ({ id, body }: { id: string; body?: DecisionBody }) => approveApproval(id, body),
  };
}

/** Mutation options to reject a pending approval. */
export function rejectApprovalMutation() {
  return {
    mutationKey: ['governance', 'approvals', 'reject'] as const,
    mutationFn: ({ id, body }: { id: string; body?: DecisionBody }) => rejectApproval(id, body),
  };
}

/** Query options for the audit log with optional filters. */
export function auditQuery(filters?: AuditFilters) {
  return {
    queryKey: ['governance', 'audit', filters ?? {}] as const,
    queryFn: () => listAudit(filters),
    staleTime: 30_000,
  };
}
