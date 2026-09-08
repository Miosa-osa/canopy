/**
 * Workspace domain types — matches the Elixir backend at /api/v1/workspaces.
 * See backend/lib/canopy_web/schemas/workspace_schema.ex for the source contracts.
 */

/** Summary row for the workspace list grid. */
export interface Workspace {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  rootPath: string;
  template: string | null;
  deletedAt: string | null;
  insertedAt: string;
  updatedAt: string;
}

/** Workspace detail — same shape as summary today, extended later for counts. */
export type WorkspaceDetail = Workspace;

/** A starter template offered at create time. */
export interface WorkspaceTemplate {
  slug: 'blank' | 'sales-engine' | 'dev-shop' | 'content-factory';
  name: string;
  description: string;
  files: string[];
}

/** Request body for POST /workspaces. */
export interface CreateWorkspaceBody {
  slug: string;
  name?: string;
  rootPath: string;
  description?: string | null;
  /** Maps to backend `template_slug` — if set, materialises starter files on disk. */
  templateSlug?: WorkspaceTemplate['slug'] | null;
}

// ── Init jobs ───────────────────────────────────────────────────────────────

export type InitJobStatus = 'pending' | 'running' | 'succeeded' | 'failed' | 'cancelled';
export type InitJobStep =
  | 'detect_base_branch'
  | 'ensure_clone'
  | 'create_initial_worktree'
  | 'run_setup_script'
  | 'done';

export interface InitJob {
  id: string;
  workspaceSlug: string;
  status: InitJobStatus;
  currentStep: InitJobStep | null;
  progressPct: number;
  output: string;
  error: string | null;
  startedAt: string | null;
  finishedAt: string | null;
  insertedAt: string;
  updatedAt: string;
}

// ── Filesystem tree + file ops ──────────────────────────────────────────────

/** One node in the nested file tree returned by GET /workspaces/:slug/tree. */
export interface FileTreeNode {
  name: string;
  path: string;
  isDir: boolean;
  size: number;
  modified: string | null;
  children: FileTreeNode[];
}

/** One row in the flat directory listing returned by GET /workspaces/:slug/files. */
export interface DirEntry {
  name: string;
  path: string;
  isDir: boolean;
  size: number;
  modified: string | null;
}

/** Response body for GET /workspaces/:slug/files/*path (text files). */
export interface FileReadResponse {
  path: string;
  contents: string;
  size: number;
  modified: string | null;
}

/** Request body for PUT /workspaces/:slug/files/*path. */
export interface FileWriteBody {
  contents: string;
}

/** Request body for POST /workspaces/:slug/files/move. */
export interface FileMoveBody {
  from: string;
  to: string;
}

// ── Filters + query shapes ──────────────────────────────────────────────────

export interface WorkspaceFilters {
  /** Include soft-deleted rows. Default: false (backend filters `deleted_at IS NULL`). */
  includeDeleted?: boolean;
}
