/**
 * TanStack Query factories for the diff pane.
 *
 * Re-exports the existing worktree status / diff query factories from
 * `$lib/api/queries/sessions.js` so callers only need to import from one
 * place when wiring the diff pane. Adds mutations for commit / stage /
 * discard-hunk that hit the corresponding backend endpoints in
 * `Canopy.Sessions.WorktreeManager`.
 *
 * snake_case ↔ camelCase conversion is handled by `apiPost` (see client.ts).
 */

import { apiPost } from '$lib/api/client.js';
import {
  worktreeDiffQuery as sessionsWorktreeDiffQuery,
  worktreeStatusQuery as sessionsWorktreeStatusQuery,
} from '$lib/api/queries/sessions.js';
import type {
  CommitRequest,
  CommitResult,
  DiscardHunkRequest,
  DiscardHunkResult,
  StageRequest,
  StageResult,
} from '$lib/domain/diff/types.js';

// ── Re-exported query factories ──────────────────────────────────────────────

/** Worktree diff (raw unified diff text + truncation flag). */
export function useWorktreeDiff(sessionId: string, enabled = true) {
  return sessionsWorktreeDiffQuery(sessionId, enabled);
}

/** Worktree status (path, branch, change count). */
export function useWorktreeStatus(sessionId: string) {
  return sessionsWorktreeStatusQuery(sessionId);
}

// ── Raw API calls ────────────────────────────────────────────────────────────

export function commitWorktree(sessionId: string, body: CommitRequest): Promise<CommitResult> {
  return apiPost<CommitResult>(`/sessions/${sessionId}/worktree/commit`, body);
}

export function stageWorktreeFiles(sessionId: string, body: StageRequest): Promise<StageResult> {
  return apiPost<StageResult>(`/sessions/${sessionId}/worktree/stage`, body);
}

export function discardWorktreeHunk(
  sessionId: string,
  body: DiscardHunkRequest
): Promise<DiscardHunkResult> {
  return apiPost<DiscardHunkResult>(`/sessions/${sessionId}/worktree/discard-hunk`, body);
}

// ── Mutation factories ───────────────────────────────────────────────────────

/** Commit changes in a session worktree. */
export function commitMutation(sessionId: string) {
  return {
    mutationKey: ['sessions', sessionId, 'worktree', 'commit'] as const,
    mutationFn: (body: CommitRequest) => commitWorktree(sessionId, body),
  };
}

/** Stage one or more files in a session worktree. */
export function stageFileMutation(sessionId: string) {
  return {
    mutationKey: ['sessions', sessionId, 'worktree', 'stage'] as const,
    mutationFn: (body: StageRequest) => stageWorktreeFiles(sessionId, body),
  };
}

/** Reverse-apply a single hunk in a session worktree (discard). */
export function discardHunkMutation(sessionId: string) {
  return {
    mutationKey: ['sessions', sessionId, 'worktree', 'discard-hunk'] as const,
    mutationFn: (body: DiscardHunkRequest) => discardWorktreeHunk(sessionId, body),
  };
}
