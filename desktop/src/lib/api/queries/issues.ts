/**
 * TanStack Query factories for the /issues resource.
 * Developer persona — I-XXXXXXXX identifiers, linear-style statuses.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import { apiDelete, apiGet, apiPatch, apiPost } from '$lib/api/client.js';
import type {
  AssignIssueBody,
  CreateIssueBody,
  Issue,
  IssueFilters,
  UpdateIssueBody,
} from '$lib/domain/issues/types.js';

// ── Raw API calls ────────────────────────────────────────────────────────────

export function listIssues(filters?: IssueFilters): Promise<Issue[]> {
  const params = new URLSearchParams();
  if (filters?.status) params.set('status', filters.status);
  if (filters?.assigneeType) params.set('assignee_type', filters.assigneeType);
  if (filters?.assigneeId) params.set('assignee_id', filters.assigneeId);
  if (filters?.label) params.set('label', filters.label);
  if (filters?.workspaceSlug) params.set('workspace_slug', filters.workspaceSlug);
  if (filters?.q) params.set('q', filters.q);
  const qs = params.toString();
  return apiGet<Issue[]>(`/issues${qs ? `?${qs}` : ''}`);
}

export function getIssue(shortId: string): Promise<Issue> {
  return apiGet<Issue>(`/issues/${shortId}`);
}

export function createIssue(body: CreateIssueBody): Promise<Issue> {
  return apiPost<Issue>('/issues', body);
}

export function updateIssue(shortId: string, body: UpdateIssueBody): Promise<Issue> {
  return apiPatch<Issue>(`/issues/${shortId}`, body);
}

export function deleteIssue(shortId: string): Promise<void> {
  return apiDelete<void>(`/issues/${shortId}`);
}

export function completeIssue(shortId: string): Promise<Issue> {
  return apiPost<Issue>(`/issues/${shortId}/complete`, {});
}

export function reopenIssue(shortId: string): Promise<Issue> {
  return apiPost<Issue>(`/issues/${shortId}/reopen`, {});
}

export function assignIssue(shortId: string, body: AssignIssueBody): Promise<Issue> {
  return apiPost<Issue>(`/issues/${shortId}/assign`, body);
}

export function dispatchIssue(shortId: string): Promise<Issue> {
  return apiPost<Issue>(`/issues/${shortId}/dispatch`, {});
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for the issue list with optional filters. */
export function issuesQuery(filters?: IssueFilters) {
  return {
    queryKey: ['issues', filters ?? {}] as const,
    queryFn: () => listIssues(filters),
    staleTime: 15_000,
    retry: false,
  };
}

/** Query options for a single issue by short_id. */
export function issueQuery(shortId: string) {
  return {
    queryKey: ['issues', shortId] as const,
    queryFn: () => getIssue(shortId),
    staleTime: 10_000,
    enabled: Boolean(shortId),
    retry: false,
  };
}

/** Mutation options to create an issue. */
export function createIssueMutation() {
  return {
    mutationKey: ['issues', 'create'] as const,
    mutationFn: (body: CreateIssueBody) => createIssue(body),
  };
}

/** Mutation options to update an issue. */
export function updateIssueMutation() {
  return {
    mutationKey: ['issues', 'update'] as const,
    mutationFn: ({ shortId, body }: { shortId: string; body: UpdateIssueBody }) =>
      updateIssue(shortId, body),
  };
}

/** Mutation options to delete an issue. */
export function deleteIssueMutation() {
  return {
    mutationKey: ['issues', 'delete'] as const,
    mutationFn: (shortId: string) => deleteIssue(shortId),
  };
}

/** Mutation options to close an issue. */
export function completeIssueMutation() {
  return {
    mutationKey: ['issues', 'complete'] as const,
    mutationFn: (shortId: string) => completeIssue(shortId),
  };
}

/** Mutation options to reopen a closed issue. */
export function reopenIssueMutation() {
  return {
    mutationKey: ['issues', 'reopen'] as const,
    mutationFn: (shortId: string) => reopenIssue(shortId),
  };
}

/** Mutation options to assign an issue. */
export function assignIssueMutation() {
  return {
    mutationKey: ['issues', 'assign'] as const,
    mutationFn: ({ shortId, body }: { shortId: string; body: AssignIssueBody }) =>
      assignIssue(shortId, body),
  };
}

/** Mutation options to dispatch an issue to an agent session. */
export function dispatchIssueMutation() {
  return {
    mutationKey: ['issues', 'dispatch'] as const,
    mutationFn: (shortId: string) => dispatchIssue(shortId),
  };
}
