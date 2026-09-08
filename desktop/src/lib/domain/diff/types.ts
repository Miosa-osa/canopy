/**
 * Diff domain types — single source of truth for the diff pane.
 *
 * Re-exports the parsed-diff types from `$lib/utils/parse-diff.js` so callers
 * import from one stable location. Adds backend-contract types for the
 * stage / discard-hunk / commit endpoints exposed by Canopy.Sessions.WorktreeManager.
 */

import type { DiffFile, DiffHunk, DiffLine } from '$lib/utils/parse-diff.js';

export type { DiffFile, DiffHunk, DiffLine };

// ── Backend contracts (matches sessions_controller worktree_* endpoints) ─────

export interface CommitRequest {
  message: string;
  files?: string[];
}

export interface CommitResult {
  ok: boolean;
  sha?: string;
  output?: string;
}

export interface StageRequest {
  files: string[];
}

export interface StageResult {
  ok: boolean;
  staged: string[];
}

export interface DiscardHunkRequest {
  filePath: string;
  hunkHeader: string;
  hunkContent: string;
}

export interface DiscardHunkResult {
  ok: boolean;
}

// ── View-mode toggles owned by the pane ──────────────────────────────────────

export type DiffViewMode = 'inline' | 'side-by-side';

export interface DiffPaneOptions {
  viewMode: DiffViewMode;
  ignoreWhitespace: boolean;
}
