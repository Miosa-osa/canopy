/**
 * TanStack Query factories for the /files resource.
 * Covers all endpoints: list, detail, activity, search, upload, update tags, archive, scan.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import { API_BASE, apiDelete, apiGet, apiPatch, apiPost } from '$lib/api/client.js';
import type {
  FileActivity,
  FileFilters,
  FileRecord,
  UpdateTagsBody,
  UploadBody,
} from '$lib/domain/files/types.js';

// ── Raw API calls ────────────────────────────────────────────────────────────

export async function listFiles(filters?: FileFilters): Promise<FileRecord[]> {
  const params = new URLSearchParams();
  if (filters?.workspace) params.set('workspace', filters.workspace);
  if (filters?.tag) params.set('tag', filters.tag);
  if (filters?.q) params.set('q', filters.q);
  if (filters?.extension) params.set('extension', filters.extension);
  const qs = params.toString();
  return apiGet<FileRecord[]>(`/files${qs ? `?${qs}` : ''}`);
}

export async function getFile(id: string): Promise<FileRecord> {
  return apiGet<FileRecord>(`/files/${id}`);
}

export async function getFileActivity(id: string): Promise<FileActivity[]> {
  return apiGet<FileActivity[]>(`/files/${id}/activity`);
}

export async function searchFiles(
  workspaceSlug: string,
  q: string,
  limit = 50
): Promise<FileRecord[]> {
  const params = new URLSearchParams({
    workspace: workspaceSlug,
    q,
    limit: String(limit),
  });
  return apiGet<FileRecord[]>(`/files/search?${params.toString()}`);
}

export async function uploadFile(body: UploadBody): Promise<FileRecord> {
  const fd = new FormData();
  fd.append('workspace_slug', body.workspaceSlug);
  fd.append('path', body.path);
  fd.append('file', body.file);

  const res = await fetch(`${API_BASE}/files`, {
    method: 'POST',
    body: fd,
    // No Content-Type header — browser sets multipart/form-data + boundary automatically
  });

  if (!res.ok) {
    let message = `HTTP ${res.status}`;
    try {
      const err = (await res.json()) as { error?: string; message?: string };
      message = err.error ?? err.message ?? message;
    } catch {
      // non-JSON body — keep status message
    }
    throw new Error(message);
  }

  const json = (await res.json()) as { data?: FileRecord } | FileRecord;
  if (json !== null && typeof json === 'object' && 'data' in json && json.data !== undefined) {
    return (json as { data: FileRecord }).data;
  }
  return json as FileRecord;
}

export async function updateTags(id: string, body: UpdateTagsBody): Promise<FileRecord> {
  return apiPatch<FileRecord>(`/files/${id}`, body);
}

export async function archiveFile(id: string): Promise<FileRecord> {
  return apiDelete<FileRecord>(`/files/${id}`);
}

export async function scanWorkspace(workspaceSlug: string): Promise<void> {
  return apiPost<void>('/files/scan', { workspace_slug: workspaceSlug });
}

// ── Helpers (inline — no separate util module per spec) ──────────────────────

const UNITS = ['B', 'KB', 'MB', 'GB', 'TB'] as const;

/** Format a byte count into a human-readable string. e.g. 1536 → "1.5 KB" */
export function formatBytes(n: number): string {
  if (n === 0) return '0 B';
  const i = Math.min(Math.floor(Math.log(n) / Math.log(1024)), UNITS.length - 1);
  const value = n / 1024 ** i;
  return `${i === 0 ? value : value.toFixed(1)} ${UNITS[i]}`;
}

const ICON_MAP: Record<string, string> = {
  // Documents
  md: '📝',
  mdx: '📝',
  txt: '📄',
  pdf: '📕',
  doc: '📘',
  docx: '📘',
  // Code
  ts: '📜',
  tsx: '📜',
  js: '📜',
  jsx: '📜',
  ex: '💜',
  exs: '💜',
  py: '🐍',
  rs: '🦀',
  go: '🐹',
  rb: '💎',
  sh: '⚙️',
  // Config
  json: '🔧',
  yaml: '🔧',
  yml: '🔧',
  toml: '🔧',
  env: '🔒',
  // Images
  png: '🖼️',
  jpg: '🖼️',
  jpeg: '🖼️',
  gif: '🖼️',
  svg: '🖼️',
  webp: '🖼️',
  // Archives
  zip: '📦',
  tar: '📦',
  gz: '📦',
  // Data
  csv: '📊',
  sql: '🗄️',
};

/** Return an emoji icon for a file extension (or null extension). */
export function fileIcon(extension: string | null): string {
  if (!extension) return '📄';
  return ICON_MAP[extension.toLowerCase()] ?? '📄';
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for the file list with optional filters. */
export function filesQuery(filters?: FileFilters) {
  return {
    queryKey: ['files', filters ?? {}] as const,
    queryFn: () => listFiles(filters),
    staleTime: 15_000,
  };
}

/** Query options for a single file's metadata. */
export function fileQuery(id: string) {
  return {
    queryKey: ['files', id] as const,
    queryFn: () => getFile(id),
    staleTime: 10_000,
    enabled: Boolean(id),
  };
}

/** Query options for a file's activity log. */
export function fileActivityQuery(id: string) {
  return {
    queryKey: ['files', id, 'activity'] as const,
    queryFn: () => getFileActivity(id),
    staleTime: 15_000,
    enabled: Boolean(id),
  };
}

/** Query options for file name search. */
export function searchFilesQuery(workspaceSlug: string, q: string) {
  return {
    queryKey: ['files', 'search', workspaceSlug, q] as const,
    queryFn: () => searchFiles(workspaceSlug, q),
    staleTime: 10_000,
    enabled: Boolean(workspaceSlug) && q.trim().length > 0,
  };
}

/** Mutation options to upload a file (multipart FormData). */
export function uploadFileMutation() {
  return {
    mutationKey: ['files', 'upload'] as const,
    mutationFn: (body: UploadBody) => uploadFile(body),
  };
}

/** Mutation options to update a file's tags. */
export function updateTagsMutation() {
  return {
    mutationKey: ['files', 'update-tags'] as const,
    mutationFn: ({ id, body }: { id: string; body: UpdateTagsBody }) => updateTags(id, body),
  };
}

/** Mutation options to archive (soft-delete) a file. */
export function archiveFileMutation() {
  return {
    mutationKey: ['files', 'archive'] as const,
    mutationFn: (id: string) => archiveFile(id),
  };
}

/** Mutation options to trigger workspace re-index scan. */
export function scanWorkspaceMutation() {
  return {
    mutationKey: ['files', 'scan'] as const,
    mutationFn: (workspaceSlug: string) => scanWorkspace(workspaceSlug),
  };
}
