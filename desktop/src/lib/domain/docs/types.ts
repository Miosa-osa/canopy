/**
 * Docs domain types — matches backend /api/v1/docs and /api/v1/doc-folders.
 * No version field, no restore endpoint (Phase 3 rollback removed both).
 * body_json is a ProseMirror doc structure. For this phase, the client
 * wraps textarea text into {type:"doc", content:[...]} on save.
 */

// ── Folder ────────────────────────────────────────────────────────────────────

export interface Folder {
  id: string;
  workspaceSlug: string;
  parentId: string | null;
  name: string;
  sortOrder: number;
  archivedAt: string | null;
  insertedAt: string;
  updatedAt: string;
}

/** Recursive folder tree node returned by GET /doc-folders/tree. */
export interface FolderTreeNode {
  id: string;
  workspaceSlug: string;
  parentId: string | null;
  name: string;
  sortOrder: number;
  archivedAt: string | null;
  insertedAt: string;
  updatedAt: string;
  children: FolderTreeNode[];
}

export interface CreateFolderBody {
  workspaceSlug: string;
  name: string;
  parentId?: string | null;
  sortOrder?: number;
}

export interface UpdateFolderBody {
  name?: string;
  parentId?: string | null;
  sortOrder?: number;
}

// ── Document ──────────────────────────────────────────────────────────────────

/** ProseMirror doc root shape — minimal for phase 4 plain-textarea editing. */
export interface ProseMirrorDoc {
  type: "doc";
  content: ProseMirrorNode[];
}

export interface ProseMirrorNode {
  type: string;
  content?: ProseMirrorTextNode[];
  [key: string]: unknown;
}

export interface ProseMirrorTextNode {
  type: "text";
  text: string;
}

export type AuthorType = "user" | "agent" | "system";

export interface Document {
  id: string;
  slug: string;
  folderId: string | null;
  workspaceSlug: string;
  title: string;
  bodyJson: ProseMirrorDoc | null;
  bodyText: string;
  summary: string | null;
  authorType: AuthorType;
  authorId: string;
  lastEditorType: AuthorType;
  lastEditorId: string;
  published: boolean;
  publishedAt: string | null;
  tags: string[];
  archivedAt: string | null;
  insertedAt: string;
  updatedAt: string;
}

export interface DocFilters {
  folderId?: string;
  tag?: string;
  author?: string;
  q?: string;
  workspace?: string;
}

export interface CreateDocumentBody {
  workspaceSlug: string;
  title: string;
  bodyJson: ProseMirrorDoc;
  bodyText: string;
  folderId?: string | null;
  summary?: string | null;
  tags?: string[];
}

export interface UpdateDocumentBody {
  title?: string;
  bodyJson?: ProseMirrorDoc;
  bodyText?: string;
  folderId?: string | null;
  summary?: string | null;
  tags?: string[];
}
