/**
 * TanStack Query factories for the /sessions/:id/worktree resource.
 *
 * Provides typed wrappers for all worktree endpoints:
 *   GET    /sessions/:id/worktree        — status (branch, changes, ahead/behind)
 *   GET    /sessions/:id/worktree/diff   — raw unified diff
 *   POST   /sessions/:id/worktree/commit — git add [-A|files] && git commit
 *   POST   /sessions/:id/worktree/push   — git push origin <branch>
 *   POST   /sessions/:id/worktree/merge  — merge session branch → base
 *   DELETE /sessions/:id/worktree        — remove worktree from disk
 */

import { apiDelete, apiGet, apiPost } from '$lib/api/client.js';

// ── Types ────────────────────────────────────────────────────────────────────

export interface WorktreeStatus {
  path: string | null;
  branch: string | null;
  baseBranch: string | null;
  exists: boolean;
  hasChanges: boolean;
  changesCount: number;
  ahead: number;
  behind: number;
}

export interface WorktreeDiffResult {
  stat: string;
  diff: string;
  truncated: boolean;
  message?: string;
}

export interface CommitBody {
  message: string;
  files?: string[];
}

export interface CommitResult {
  ok: boolean;
  sha?: string;
  output?: string;
  error?: string;
}

export interface PushResult {
  ok: boolean;
  ref?: string;
  error?: string;
  output?: string;
}

export interface MergeResult {
  ok: boolean;
  baseBranch?: string;
  conflictFiles?: string[];
  error?: string;
}

export interface CleanupResult {
  ok: boolean;
}

// ── API calls ────────────────────────────────────────────────────────────────

export function getWorktreeStatus(sessionId: string): Promise<WorktreeStatus> {
  return apiGet<WorktreeStatus>(`/sessions/${sessionId}/worktree`);
}

export function getWorktreeDiff(
  sessionId: string,
  opts?: { file?: string; maxBytes?: number }
): Promise<WorktreeDiffResult> {
  const params = new URLSearchParams();
  if (opts?.file) params.set('file', opts.file);
  if (opts?.maxBytes != null) params.set('max_bytes', String(opts.maxBytes));
  const qs = params.toString();
  return apiGet<WorktreeDiffResult>(`/sessions/${sessionId}/worktree/diff${qs ? `?${qs}` : ''}`);
}

export function commitWorktree(sessionId: string, body: CommitBody): Promise<CommitResult> {
  return apiPost<CommitResult>(`/sessions/${sessionId}/worktree/commit`, body);
}

export function pushWorktree(sessionId: string, remote?: string): Promise<PushResult> {
  return apiPost<PushResult>(`/sessions/${sessionId}/worktree/push`, {
    remote: remote ?? 'origin',
  });
}

export function mergeWorktree(sessionId: string): Promise<MergeResult> {
  return apiPost<MergeResult>(`/sessions/${sessionId}/worktree/merge`, {});
}

export function cleanupWorktreeDelete(
  sessionId: string,
  opts?: { keepBranch?: boolean }
): Promise<CleanupResult> {
  const params = new URLSearchParams();
  if (opts?.keepBranch) params.set('keep_branch', 'true');
  const qs = params.toString();
  return apiDelete<CleanupResult>(`/sessions/${sessionId}/worktree${qs ? `?${qs}` : ''}`);
}

// ── TanStack Query factories ─────────────────────────────────────────────────

/** Query options for worktree status (branch, changes, ahead/behind). */
export function worktreeStatusQuery(sessionId: string) {
  return {
    queryKey: ['sessions', sessionId, 'worktree'] as const,
    queryFn: () => getWorktreeStatus(sessionId),
    staleTime: 8_000,
    enabled: Boolean(sessionId),
  };
}

/** Query options for raw unified diff. */
export function worktreeDiffQuery(
  sessionId: string,
  enabled: boolean,
  opts?: { file?: string; maxBytes?: number }
) {
  return {
    queryKey: ['sessions', sessionId, 'worktree', 'diff', opts ?? {}] as const,
    queryFn: () => getWorktreeDiff(sessionId, opts),
    staleTime: 10_000,
    enabled: Boolean(sessionId) && enabled,
  };
}
