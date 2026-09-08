/**
 * Reviews domain types — matches the Elixir backend at /api/v1/reviews/*.
 * Covers artifact reviews (doc/task/issue/pr/file/kb_chunk) and inline
 * tool-call approval gates.
 */

// ── Review ────────────────────────────────────────────────────────────────────

export type ReviewKind = 'artifact' | 'tool_call' | 'hire_agent';

export type ArtifactType = 'doc' | 'task' | 'issue' | 'pr' | 'file' | 'kb_chunk';

export type ReviewStatus = 'pending' | 'approved' | 'rejected' | 'changes_requested' | 'expired';

/** A human-review request — either for an artifact or a tool-call gate. */
export interface Review {
  id: string;
  workspaceSlug: string | null;
  kind: ReviewKind;

  // artifact fields
  artifactType: ArtifactType | null;
  artifactId: string | null;
  artifactPreview: string | null;

  // tool_call fields
  toolName: string | null;
  toolArgs: Record<string, unknown> | null;

  // session context
  sessionId: string | null;
  agentId: string | null;

  // decision
  reviewerId: string | null;
  status: ReviewStatus;
  feedback: string | null;
  revisionCount: number;
  requestedAt: string;
  decidedAt: string | null;
  expiresAt: string | null;
  insertedAt: string;
  updatedAt: string;
}

// ── Filter / query params ─────────────────────────────────────────────────────

export interface ReviewFilters {
  workspaceSlug?: string;
  status?: ReviewStatus;
  kind?: ReviewKind;
  agentId?: string;
  sessionId?: string;
}

export interface ReviewSummary {
  total: number;
  pendingCount: number;
  decidedCount: number;
  changesRequestedCount: number;
  byStatus: Record<string, number>;
  byKind: Record<string, number>;
  byWorkspace: Record<string, number>;
  byAgent: Record<string, number>;
  oldestPendingAt: string | null;
  nextExpiryAt: string | null;
  recent: Review[];
}

// ── Mutation bodies ───────────────────────────────────────────────────────────

export interface CreateArtifactReviewBody {
  kind: 'artifact';
  workspaceSlug?: string;
  artifactType?: ArtifactType;
  artifactId?: string;
  artifactPreview?: string;
  agentId?: string;
}

export interface CreateToolCallReviewBody {
  kind: 'tool_call';
  workspaceSlug?: string;
  toolName: string;
  toolArgs?: Record<string, unknown>;
  sessionId?: string;
  agentId?: string;
}

export type CreateReviewBody = CreateArtifactReviewBody | CreateToolCallReviewBody;

export interface ApproveReviewBody {
  reviewerId?: string;
}

export interface RejectReviewBody {
  reviewerId?: string;
  feedback?: string;
}

export interface RequestChangesBody {
  reviewerId?: string;
  feedback?: string;
}
