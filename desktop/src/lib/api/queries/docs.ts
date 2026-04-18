/**
 * TanStack Query factories for /docs and /doc-folders resources.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 *
 * Helpers bodyJsonFromText() / bodyTextFromJson() live here because no other
 * module needs them yet. Extract to utils/ only if reuse emerges.
 */

import {
  apiDelete,
  apiGet,
  apiPatch,
  apiPost,
  apiPut,
} from "$lib/api/client.js";
import type {
  CreateDocumentBody,
  CreateFolderBody,
  DocFilters,
  Document,
  Folder,
  FolderTreeNode,
  ProseMirrorDoc,
  UpdateDocumentBody,
  UpdateFolderBody,
} from "$lib/domain/docs/types.js";

// ── Body helpers ─────────────────────────────────────────────────────────────

/**
 * Wrap a plain text string into a minimal ProseMirror doc.
 * Each line becomes a paragraph node. Empty string yields an empty paragraph.
 */
export function bodyJsonFromText(text: string): ProseMirrorDoc {
  if (text === "") {
    return { type: "doc", content: [{ type: "paragraph", content: [] }] };
  }
  return {
    type: "doc",
    content: text.split("\n").map((line) => ({
      type: "paragraph",
      content: line.length > 0 ? [{ type: "text", text: line }] : [],
    })),
  };
}

/**
 * Extract plain text from a ProseMirror doc.
 * Joins paragraph text content with newlines.
 */
export function bodyTextFromJson(doc: ProseMirrorDoc | null): string {
  if (!doc) return "";
  return doc.content
    .map((node) =>
      (node.content ?? [])
        .filter((c) => c.type === "text")
        .map((c) => c.text)
        .join(""),
    )
    .join("\n");
}

// ── Raw API calls — Folders ──────────────────────────────────────────────────

export function listDocFolders(workspaceSlug: string): Promise<Folder[]> {
  return apiGet<Folder[]>(
    `/doc-folders?workspace=${encodeURIComponent(workspaceSlug)}`,
  );
}

export function getDocFolderTree(
  workspaceSlug: string,
): Promise<FolderTreeNode[]> {
  return apiGet<FolderTreeNode[]>(
    `/doc-folders/tree?workspace=${encodeURIComponent(workspaceSlug)}`,
  );
}

export function createDocFolder(body: CreateFolderBody): Promise<Folder> {
  return apiPost<Folder>("/doc-folders", body);
}

export function updateDocFolder(
  id: string,
  body: UpdateFolderBody,
): Promise<Folder> {
  return apiPatch<Folder>(`/doc-folders/${id}`, body);
}

export function deleteDocFolder(id: string): Promise<void> {
  return apiDelete<void>(`/doc-folders/${id}`);
}

// ── Raw API calls — Documents ────────────────────────────────────────────────

export function listDocuments(filters?: DocFilters): Promise<Document[]> {
  const params = new URLSearchParams();
  if (filters?.folderId) params.set("folder_id", filters.folderId);
  if (filters?.tag) params.set("tag", filters.tag);
  if (filters?.author) params.set("author", filters.author);
  if (filters?.q) params.set("q", filters.q);
  if (filters?.workspace) params.set("workspace", filters.workspace);
  const qs = params.toString();
  return apiGet<Document[]>(`/docs${qs ? `?${qs}` : ""}`);
}

export function getDocument(id: string): Promise<Document> {
  return apiGet<Document>(`/docs/${id}`);
}

export function createDocument(body: CreateDocumentBody): Promise<Document> {
  return apiPost<Document>("/docs", body);
}

export function updateDocument(
  id: string,
  body: UpdateDocumentBody,
): Promise<Document> {
  return apiPut<Document>(`/docs/${id}`, body);
}

export function publishDocument(id: string): Promise<Document> {
  return apiPost<Document>(`/docs/${id}/publish`, {});
}

export function unpublishDocument(id: string): Promise<Document> {
  return apiPost<Document>(`/docs/${id}/unpublish`, {});
}

export function archiveDocument(id: string): Promise<Document> {
  return apiPost<Document>(`/docs/${id}/archive`, {});
}

export function unarchiveDocument(id: string): Promise<Document> {
  return apiPost<Document>(`/docs/${id}/unarchive`, {});
}

export function deleteDocument(id: string): Promise<void> {
  return apiDelete<void>(`/docs/${id}`);
}

export function searchDocuments(
  workspaceSlug: string,
  q: string,
): Promise<Document[]> {
  const params = new URLSearchParams({ workspace: workspaceSlug, q });
  return apiGet<Document[]>(`/docs/search?${params.toString()}`);
}

// ── TanStack Query option factories — Folders ────────────────────────────────

/** Query options for the flat folder list of a workspace. */
export function foldersQuery(workspaceSlug: string) {
  return {
    queryKey: ["doc-folders", workspaceSlug] as const,
    queryFn: () => listDocFolders(workspaceSlug),
    staleTime: 30_000,
    enabled: Boolean(workspaceSlug),
  };
}

/** Query options for the nested folder tree of a workspace. */
export function folderTreeQuery(workspaceSlug: string) {
  return {
    queryKey: ["doc-folders", workspaceSlug, "tree"] as const,
    queryFn: () => getDocFolderTree(workspaceSlug),
    staleTime: 30_000,
    enabled: Boolean(workspaceSlug),
  };
}

/** Mutation options to create a doc folder. */
export function createFolderMutation() {
  return {
    mutationKey: ["doc-folders", "create"] as const,
    mutationFn: (body: CreateFolderBody) => createDocFolder(body),
  };
}

/** Mutation options to update a doc folder. */
export function updateFolderMutation() {
  return {
    mutationKey: ["doc-folders", "update"] as const,
    mutationFn: ({ id, body }: { id: string; body: UpdateFolderBody }) =>
      updateDocFolder(id, body),
  };
}

/** Mutation options to delete a doc folder. */
export function deleteFolderMutation() {
  return {
    mutationKey: ["doc-folders", "delete"] as const,
    mutationFn: (id: string) => deleteDocFolder(id),
  };
}

// ── TanStack Query option factories — Documents ──────────────────────────────

/** Query options for the document list with optional filters. */
export function documentsQuery(filters?: DocFilters) {
  return {
    queryKey: ["docs", filters ?? {}] as const,
    queryFn: () => listDocuments(filters),
    staleTime: 10_000,
  };
}

/** Query options for a single document. */
export function documentQuery(id: string) {
  return {
    queryKey: ["docs", id] as const,
    queryFn: () => getDocument(id),
    staleTime: 5_000,
    enabled: Boolean(id),
  };
}

/** Mutation options to create a document. */
export function createDocumentMutation() {
  return {
    mutationKey: ["docs", "create"] as const,
    mutationFn: (body: CreateDocumentBody) => createDocument(body),
  };
}

/** Mutation options to update a document. */
export function updateDocumentMutation() {
  return {
    mutationKey: ["docs", "update"] as const,
    mutationFn: ({ id, body }: { id: string; body: UpdateDocumentBody }) =>
      updateDocument(id, body),
  };
}

/** Mutation options to publish a document. */
export function publishDocumentMutation() {
  return {
    mutationKey: ["docs", "publish"] as const,
    mutationFn: (id: string) => publishDocument(id),
  };
}

/** Mutation options to unpublish a document. */
export function unpublishDocumentMutation() {
  return {
    mutationKey: ["docs", "unpublish"] as const,
    mutationFn: (id: string) => unpublishDocument(id),
  };
}

/** Mutation options to archive a document. */
export function archiveDocumentMutation() {
  return {
    mutationKey: ["docs", "archive"] as const,
    mutationFn: (id: string) => archiveDocument(id),
  };
}

/** Mutation options to unarchive a document. */
export function unarchiveDocumentMutation() {
  return {
    mutationKey: ["docs", "unarchive"] as const,
    mutationFn: (id: string) => unarchiveDocument(id),
  };
}

/** Mutation options to delete a document. */
export function deleteDocumentMutation() {
  return {
    mutationKey: ["docs", "delete"] as const,
    mutationFn: (id: string) => deleteDocument(id),
  };
}

/** Query options for full-text document search. */
export function searchDocumentsQuery(workspaceSlug: string, q: string) {
  return {
    queryKey: ["docs", "search", workspaceSlug, q] as const,
    queryFn: () => searchDocuments(workspaceSlug, q),
    staleTime: 0,
    enabled: Boolean(workspaceSlug) && q.trim().length > 0,
  };
}
