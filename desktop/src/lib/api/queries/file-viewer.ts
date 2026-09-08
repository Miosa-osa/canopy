/**
 * file-viewer query helpers — thin selectors over the existing files +
 * workspaces query factories. NO new fetch logic; this module reuses:
 *
 *   - fileQuery(id)                       (lib/api/queries/files.ts) — metadata
 *   - GET ${API_BASE}/files/:id/content   — raw bytes (handled inline by viewers)
 *   - workspaceFileQuery(slug, path)      (lib/api/queries/workspaces.ts) — text
 *
 * The pane addresses files by EITHER:
 *   { fileId }                  → uses fileQuery + the /files/:id/content URL
 *   { workspaceSlug, path }     → uses workspaceFileQuery (already returns text)
 *
 * The point of this module is to give a single import surface for the pane
 * dispatcher and keep the responsibility-per-file rule intact.
 */

import { API_BASE } from '$lib/api/client.js';
import { fileQuery as filesFileQuery } from '$lib/api/queries/files.js';
import { workspaceFileQuery as wsFileQuery } from '$lib/api/queries/workspaces.js';
import type { FileViewerPaneConfig } from '$lib/domain/file-viewer/types.js';

/** Build the binary content URL for a file row. Used by image / video / audio / pdf viewers. */
export function fileContentUrl(fileId: string): string {
  return `${API_BASE}/files/${fileId}/content`;
}

/**
 * TanStack Query options for the file's metadata when addressed by id.
 * Returns the same query as files.ts → safe to share its cache.
 */
export const fileMetadataQuery = filesFileQuery;

/**
 * TanStack Query options for the file's text contents when addressed by
 * workspace slug + path. Re-export of the workspaces query.
 */
export const workspaceFileContentsQuery = wsFileQuery;

/**
 * Validate that a pane config has enough info to fetch content. Used by the
 * dispatcher to short-circuit into an "Unconfigured" empty state.
 */
export function isResolvable(cfg: FileViewerPaneConfig): boolean {
  if (cfg.fileId && cfg.fileId.length > 0) return true;
  if (
    cfg.workspaceSlug &&
    cfg.workspaceSlug.length > 0 &&
    typeof cfg.path === 'string' &&
    cfg.path.length > 0
  ) {
    return true;
  }
  return false;
}

/**
 * Fetch text content for a file row by id. Used by code/json/csv/log/markdown
 * viewers when the pane is addressed by fileId rather than (slug,path). Uses
 * fetch directly so callers can pass an AbortSignal.
 */
export async function fetchFileText(fileId: string, signal?: AbortSignal): Promise<string> {
  const res = await fetch(fileContentUrl(fileId), {
    credentials: 'include',
    signal,
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.text();
}

/**
 * Fetch raw bytes (Uint8Array) for a file row. Used by HexPreview only.
 * `byteCap` clips the response to at most that many bytes — saves memory
 * on multi-GB binaries.
 */
export async function fetchFileBytes(
  fileId: string,
  byteCap: number,
  signal?: AbortSignal
): Promise<Uint8Array> {
  const res = await fetch(fileContentUrl(fileId), {
    credentials: 'include',
    signal,
    headers: { Range: `bytes=0-${Math.max(0, byteCap - 1)}` },
  });
  if (!res.ok && res.status !== 206) {
    throw new Error(`HTTP ${res.status}`);
  }
  const buf = await res.arrayBuffer();
  return new Uint8Array(buf.slice(0, byteCap));
}
