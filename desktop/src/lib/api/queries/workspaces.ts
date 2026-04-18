/**
 * TanStack Query factories for the /workspaces resource.
 * Covers all 11 endpoints: CRUD, templates, tree, file ops.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import { apiDelete, apiGet, apiPost, apiPut } from "$lib/api/client.js";
import type {
  CreateWorkspaceBody,
  DirEntry,
  FileMoveBody,
  FileReadResponse,
  FileTreeNode,
  FileWriteBody,
  Workspace,
  WorkspaceDetail,
  WorkspaceFilters,
  WorkspaceTemplate,
} from "$lib/domain/workspaces/types.js";

// ── Raw API calls ────────────────────────────────────────────────────────────

interface ListEnvelope<T> {
  data: T[];
}

interface DetailEnvelope<T> {
  data: T;
}

interface DirListEnvelope {
  data: DirEntry[];
  path: string;
}

export async function listWorkspaces(
  filters?: WorkspaceFilters,
): Promise<Workspace[]> {
  const params = new URLSearchParams();
  if (filters?.includeDeleted) params.set("include_deleted", "true");
  const qs = params.toString();
  const response = await apiGet<ListEnvelope<Workspace>>(
    `/workspaces${qs ? `?${qs}` : ""}`,
  );
  return response.data;
}

export async function getWorkspace(slug: string): Promise<WorkspaceDetail> {
  const response = await apiGet<DetailEnvelope<WorkspaceDetail>>(
    `/workspaces/${slug}`,
  );
  return response.data;
}

export async function createWorkspace(
  body: CreateWorkspaceBody,
): Promise<Workspace> {
  const payload = {
    slug: body.slug,
    name: body.name,
    root_path: body.rootPath,
    description: body.description ?? null,
    template_slug: body.templateSlug ?? null,
  };
  const response = await apiPost<DetailEnvelope<Workspace>>(
    "/workspaces",
    payload,
  );
  return response.data;
}

export function deleteWorkspace(slug: string): Promise<void> {
  return apiDelete<void>(`/workspaces/${slug}`);
}

export async function listTemplates(): Promise<WorkspaceTemplate[]> {
  const response = await apiGet<ListEnvelope<WorkspaceTemplate>>(
    "/workspaces/templates",
  );
  return response.data;
}

export async function getFileTree(slug: string): Promise<FileTreeNode> {
  const response = await apiGet<DetailEnvelope<FileTreeNode>>(
    `/workspaces/${slug}/tree`,
  );
  return response.data;
}

export async function listDir(
  slug: string,
  path: string = "",
): Promise<DirEntry[]> {
  const qs = path ? `?path=${encodeURIComponent(path)}` : "";
  const response = await apiGet<DirListEnvelope>(
    `/workspaces/${slug}/files${qs}`,
  );
  return response.data;
}

export function readFile(
  slug: string,
  path: string,
): Promise<FileReadResponse> {
  return apiGet<FileReadResponse>(
    `/workspaces/${slug}/files/${encodePath(path)}`,
  );
}

export function writeFile(
  slug: string,
  path: string,
  body: FileWriteBody,
): Promise<FileReadResponse> {
  return apiPut<FileReadResponse>(
    `/workspaces/${slug}/files/${encodePath(path)}`,
    body,
  );
}

export function deleteFile(slug: string, path: string): Promise<void> {
  return apiDelete<void>(`/workspaces/${slug}/files/${encodePath(path)}`);
}

export function moveFile(
  slug: string,
  body: FileMoveBody,
): Promise<FileReadResponse> {
  return apiPost<FileReadResponse>(`/workspaces/${slug}/files/move`, body);
}

/**
 * Splat-path encoding — each segment is URI-encoded but the slashes between
 * them are preserved so Phoenix's `*path` splat pattern matches correctly.
 */
function encodePath(path: string): string {
  return path
    .split("/")
    .filter((seg) => seg.length > 0)
    .map(encodeURIComponent)
    .join("/");
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for the workspace list grid. */
export function workspacesQuery(filters?: WorkspaceFilters) {
  return {
    queryKey: ["workspaces", filters ?? {}] as const,
    queryFn: () => listWorkspaces(filters),
    staleTime: 30_000,
  };
}

/** Query options for a single workspace detail page. */
export function workspaceDetailQuery(slug: string) {
  return {
    queryKey: ["workspaces", slug] as const,
    queryFn: () => getWorkspace(slug),
    staleTime: 30_000,
    enabled: Boolean(slug),
  };
}

/** Query options for the workspace file tree — used on detail page sidebar. */
export function workspaceTreeQuery(slug: string) {
  return {
    queryKey: ["workspaces", slug, "tree"] as const,
    queryFn: () => getFileTree(slug),
    staleTime: 10_000,
    enabled: Boolean(slug),
  };
}

/** Query options for reading a single file's contents. */
export function workspaceFileQuery(slug: string, path: string) {
  return {
    queryKey: ["workspaces", slug, "file", path] as const,
    queryFn: () => readFile(slug, path),
    staleTime: 0,
    enabled: Boolean(slug) && Boolean(path),
  };
}

/** Query options for the 4 starter templates. Templates are static, so cache forever. */
export function workspaceTemplatesQuery() {
  return {
    queryKey: ["workspaces", "templates"] as const,
    queryFn: () => listTemplates(),
    staleTime: Infinity,
  };
}

/** Mutation options to create a workspace (optionally from a template). */
export function createWorkspaceMutation() {
  return {
    mutationKey: ["workspaces", "create"] as const,
    mutationFn: (body: CreateWorkspaceBody) => createWorkspace(body),
  };
}

/** Mutation options to soft-delete a workspace. */
export function deleteWorkspaceMutation() {
  return {
    mutationKey: ["workspaces", "delete"] as const,
    mutationFn: (slug: string) => deleteWorkspace(slug),
  };
}

/** Mutation options to write a file. */
export function writeFileMutation(slug: string) {
  return {
    mutationKey: ["workspaces", slug, "write-file"] as const,
    mutationFn: ({ path, contents }: { path: string; contents: string }) =>
      writeFile(slug, path, { contents }),
  };
}

/** Mutation options to delete a file. */
export function deleteFileMutation(slug: string) {
  return {
    mutationKey: ["workspaces", slug, "delete-file"] as const,
    mutationFn: (path: string) => deleteFile(slug, path),
  };
}

/** Mutation options to move/rename a file within a workspace. */
export function moveFileMutation(slug: string) {
  return {
    mutationKey: ["workspaces", slug, "move-file"] as const,
    mutationFn: (body: FileMoveBody) => moveFile(slug, body),
  };
}
