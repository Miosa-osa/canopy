/**
 * TanStack Query factories for the /reviews resource.
 * Human-review approval queue — artifact reviews + inline tool-call gates.
 */

import { apiGet, apiPost } from "$lib/api/client.js";
import type {
  ApproveReviewBody,
  CreateReviewBody,
  RejectReviewBody,
  RequestChangesBody,
  Review,
  ReviewFilters,
  ReviewSummary,
  ReviewStatus,
} from "$lib/domain/reviews/types.js";

// ── Raw API calls ────────────────────────────────────────────────────────────

export function listReviews(filters?: ReviewFilters): Promise<Review[]> {
  const params = new URLSearchParams();
  if (filters?.workspaceSlug)
    params.set("workspace_slug", filters.workspaceSlug);
  if (filters?.status) params.set("status", filters.status);
  if (filters?.kind) params.set("kind", filters.kind);
  if (filters?.agentId) params.set("agent_id", filters.agentId);
  if (filters?.sessionId) params.set("session_id", filters.sessionId);
  const qs = params.toString();
  return apiGet<Review[]>(`/reviews${qs ? `?${qs}` : ""}`);
}

export function getReviewSummary(
  filters?: ReviewFilters,
): Promise<ReviewSummary> {
  const params = new URLSearchParams();
  if (filters?.workspaceSlug)
    params.set("workspace_slug", filters.workspaceSlug);
  if (filters?.status) params.set("status", filters.status);
  if (filters?.kind) params.set("kind", filters.kind);
  if (filters?.agentId) params.set("agent_id", filters.agentId);
  if (filters?.sessionId) params.set("session_id", filters.sessionId);
  const qs = params.toString();
  return apiGet<ReviewSummary>(`/reviews/summary${qs ? `?${qs}` : ""}`);
}

export function getReview(id: string): Promise<Review> {
  return apiGet<Review>(`/reviews/${id}`);
}

export function createReview(body: CreateReviewBody): Promise<Review> {
  return apiPost<Review>("/reviews", body);
}

export function approveReview(
  id: string,
  body?: ApproveReviewBody,
): Promise<Review> {
  return apiPost<Review>(`/reviews/${id}/approve`, body ?? {});
}

export function rejectReview(
  id: string,
  body?: RejectReviewBody,
): Promise<Review> {
  return apiPost<Review>(`/reviews/${id}/reject`, body ?? {});
}

export function requestChangesReview(
  id: string,
  body?: RequestChangesBody,
): Promise<Review> {
  return apiPost<Review>(`/reviews/${id}/request_changes`, body ?? {});
}

export function resubmitReview(
  id: string,
  attrs?: { artifactPreview?: string },
): Promise<Review> {
  return apiPost<Review>(`/reviews/${id}/resubmit`, attrs ?? {});
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for the review list with optional filters. */
export function reviewsQuery(filters?: ReviewFilters) {
  return {
    queryKey: ["reviews", filters ?? {}] as const,
    queryFn: () => listReviews(filters),
    staleTime: 10_000,
    retry: false,
  };
}

/** Query options for queue operational summary. */
export function reviewSummaryQuery(filters?: ReviewFilters) {
  return {
    queryKey: ["reviews", "summary", filters ?? {}] as const,
    queryFn: () => getReviewSummary(filters),
    staleTime: 10_000,
    retry: false,
  };
}

/** Query options for a single review by id. */
export function reviewQuery(id: string) {
  return {
    queryKey: ["reviews", id] as const,
    queryFn: () => getReview(id),
    staleTime: 5_000,
    enabled: Boolean(id),
    retry: false,
  };
}

/** Mutation options to create a review request. */
export function createReviewMutation() {
  return {
    mutationKey: ["reviews", "create"] as const,
    mutationFn: (body: CreateReviewBody) => createReview(body),
  };
}

/** Mutation options to approve a pending review. */
export function approveReviewMutation() {
  return {
    mutationKey: ["reviews", "approve"] as const,
    mutationFn: ({ id, body }: { id: string; body?: ApproveReviewBody }) =>
      approveReview(id, body),
  };
}

/** Mutation options to reject a pending review. */
export function rejectReviewMutation() {
  return {
    mutationKey: ["reviews", "reject"] as const,
    mutationFn: ({ id, body }: { id: string; body?: RejectReviewBody }) =>
      rejectReview(id, body),
  };
}

/** Mutation options to request changes on a pending review. */
export function requestChangesMutation() {
  return {
    mutationKey: ["reviews", "request_changes"] as const,
    mutationFn: ({ id, body }: { id: string; body?: RequestChangesBody }) =>
      requestChangesReview(id, body),
  };
}

/** Mutation options to resubmit a changes_requested review back to pending. */
export function resubmitReviewMutation() {
  return {
    mutationKey: ["reviews", "resubmit"] as const,
    mutationFn: ({
      id,
      attrs,
    }: {
      id: string;
      attrs?: { artifactPreview?: string };
    }) => resubmitReview(id, attrs),
  };
}

/** Pending-count query — used for the sidebar badge. */
export function pendingReviewsCountQuery(workspaceSlug?: string) {
  return {
    queryKey: ["reviews", "pending_count", workspaceSlug ?? "all"] as const,
    queryFn: async () => {
      const filters: ReviewFilters = { status: "pending" };
      if (workspaceSlug) filters.workspaceSlug = workspaceSlug;
      const list = await listReviews(filters);
      return list.length;
    },
    staleTime: 10_000,
    retry: false,
  };
}
