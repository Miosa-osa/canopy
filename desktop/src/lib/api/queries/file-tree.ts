/**
 * TanStack Query factories for lazy directory listing inside the Build Side Rail.
 *
 * Reuses the existing `listDir()` raw call from `workspaces.ts` — does NOT
 * introduce a new fetcher. The factory exists separately so the Build rail
 * can use a per-directory cache key (one query per expanded folder) instead
 * of pulling the full recursive tree.
 *
 * Endpoint: GET /api/v1/workspaces/:slug/files?path=<dir>
 */

import { listDir } from '$lib/api/queries/workspaces.js';
import type { DirEntry } from '$lib/domain/workspaces/types.js';

/**
 * Query options for a single directory listing inside a workspace.
 *
 * @param slug   workspace slug
 * @param path   directory path relative to workspace root ("" = root)
 */
export function directoryListingQuery(slug: string, path: string = '') {
  return {
    queryKey: ['build-rail', 'directory', slug, path] as const,
    queryFn: (): Promise<DirEntry[]> => listDir(slug, path),
    staleTime: 10_000,
    enabled: Boolean(slug),
  };
}
