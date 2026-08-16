/**
 * TanStack Query factories for the /workspaces resource.
 * Covers all 11 endpoints: CRUD, templates, tree, file ops.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import {
  apiDelete,
  apiGet,
  apiPatch,
  apiPost,
  apiPut,
} from "$lib/api/client.js";
import { toCamel } from "$lib/api/case.js";
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
//
// NOTE: apiGet/apiPost/apiDelete in client.ts already unwrap the Phoenix
// {data: ...} envelope. The backend sends snake_case; toCamel() converts
// keys to camelCase so TypeScript domain types (rootPath, isDir, etc.) match.

export async function listWorkspaces(
  filters?: WorkspaceFilters,
): Promise<Workspace[]> {
  const params = new URLSearchParams();
  if (filters?.includeDeleted) params.set("include_deleted", "true");
  const qs = params.toString();
  const raw = await apiGet<unknown>(`/workspaces${qs ? `?${qs}` : ""}`);
  return toCamel(raw) as Workspace[];
}

export async function getWorkspace(slug: string): Promise<WorkspaceDetail> {
  const raw = await apiGet<unknown>(`/workspaces/${slug}`);
  return toCamel(raw) as WorkspaceDetail;
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
  const raw = await apiPost<unknown>("/workspaces", payload);
  return toCamel(raw) as Workspace;
}

export function deleteWorkspace(slug: string): Promise<void> {
  return apiDelete<void>(`/workspaces/${slug}`);
}

export async function listTemplates(): Promise<WorkspaceTemplate[]> {
  const raw = await apiGet<unknown>("/workspaces/templates");
  return toCamel(raw) as WorkspaceTemplate[];
}

export async function getFileTree(slug: string): Promise<FileTreeNode> {
  const raw = await apiGet<unknown>(`/workspaces/${slug}/tree`);
  return toCamel(raw) as FileTreeNode;
}

export async function listDir(
  slug: string,
  path: string = "",
): Promise<DirEntry[]> {
  const qs = path ? `?path=${encodeURIComponent(path)}` : "";
  const raw = await apiGet<unknown>(`/workspaces/${slug}/files${qs}`);
  return toCamel(raw) as DirEntry[];
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

export interface UpdateWorkspaceBody {
  name?: string;
  rootPath?: string;
}

export async function updateWorkspace(
  slug: string,
  body: UpdateWorkspaceBody,
): Promise<Workspace> {
  const payload: Record<string, string> = {};
  if (body.name !== undefined) payload.name = body.name;
  if (body.rootPath !== undefined) payload.root_path = body.rootPath;
  const raw = await apiPatch<unknown>(`/workspaces/${slug}`, payload);
  return toCamel(raw) as Workspace;
}

/** Mutation options to update a workspace's name or root_path. */
export function updateWorkspaceMutation() {
  return {
    mutationKey: ["workspaces", "update"] as const,
    mutationFn: ({ slug, body }: { slug: string; body: UpdateWorkspaceBody }) =>
      updateWorkspace(slug, body),
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

// ── Init job API calls ───────────────────────────────────────────────────────

export interface StartInitResponse {
  jobId: string;
  streamUrl: string;
}

export async function startInitJob(
  slug: string,
  cloneUrl?: string,
): Promise<StartInitResponse> {
  const payload = cloneUrl ? { clone_url: cloneUrl } : {};
  const raw = await apiPost<{ job_id: string; stream_url: string }>(
    `/workspaces/${slug}/init`,
    payload,
  );
  return {
    jobId: raw.job_id,
    stream_url: raw.stream_url,
  } as unknown as StartInitResponse;
}

export async function cancelInitJob(
  slug: string,
  jobId: string,
): Promise<void> {
  await apiPost<unknown>(`/workspaces/${slug}/init/${jobId}/cancel`, {});
}

/** Query options for polling the latest init job for a workspace. */
export function workspaceInitJobQuery(slug: string, jobId: string) {
  return {
    queryKey: ["workspaces", slug, "init", jobId] as const,
    queryFn: async () => {
      const raw = await apiGet<unknown>(`/workspaces/${slug}/init/${jobId}`);
      return toCamel(raw) as import("$lib/domain/workspaces/types.js").InitJob;
    },
    refetchInterval: (query: { state: { data?: { status?: string } } }) => {
      const status = query.state.data?.status;
      if (
        status === "succeeded" ||
        status === "failed" ||
        status === "cancelled"
      ) {
        return false as const;
      }
      return 2000;
    },
    enabled: Boolean(slug) && Boolean(jobId),
  };
}
