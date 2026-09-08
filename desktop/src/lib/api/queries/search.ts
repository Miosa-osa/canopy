/**
 * TanStack Query factories for cross-file ripgrep search inside the Build rail.
 *
 * Backend contract (consumed when present):
 *   GET /api/v1/search?q=...&workspace_slug=...&regex=true|false
 *                     &case_sensitive=true|false&limit=...
 *                     &include_glob=...&exclude_glob=...
 *
 *   Response shape:
 *     {
 *       data: { file_path, line_number, line_text, match_start, match_end }[],
 *       backend: "ripgrep" | "elixir",
 *       elapsed_ms: number,
 *       truncated: boolean
 *     }
 *
 *   The `apiGet` client unwraps `{data: ...}` into the array directly. The
 *   sibling fields (`backend`, `elapsed_ms`, `truncated`) are surfaced via a
 *   raw fetch path so the UI can render backend metadata and a truncation hint.
 *
 * If the endpoint returns 404 (not yet implemented), this module degrades
 * to an empty result set so the UI can show an "empty / pending" state
 * without throwing.
 */

import { API_BASE, ApiError } from '$lib/api/client.js';

/** A single ripgrep match, normalised to camelCase by the API client. */
export interface SearchHit {
  filePath: string;
  lineNumber: number;
  lineText: string;
  matchStart: number;
  matchEnd: number;
}

/** Filter options for the search request. */
export interface SearchFilters {
  workspaceSlug: string;
  q: string;
  regex?: boolean;
  caseSensitive?: boolean;
  limit?: number;
}

/** Result grouping: matches grouped by file for rendering. */
export interface SearchResultGroup {
  filePath: string;
  hits: SearchHit[];
}

/**
 * Group raw hits by file path while preserving insertion order.
 * Pure function, exported for tests.
 */
export function groupByFile(hits: SearchHit[]): SearchResultGroup[] {
  const order: string[] = [];
  const map = new Map<string, SearchHit[]>();
  for (const hit of hits) {
    const arr = map.get(hit.filePath);
    if (arr) {
      arr.push(hit);
    } else {
      order.push(hit.filePath);
      map.set(hit.filePath, [hit]);
    }
  }
  return order.map((filePath) => ({
    filePath,
    hits: map.get(filePath) ?? [],
  }));
}

/** Sentinel marker used to distinguish "backend missing" from "no matches". */
export interface BackendStatus {
  /** True when the search endpoint is available; false when 404. */
  available: boolean;
  /** Hits — empty array when unavailable or no matches. */
  hits: SearchHit[];
  /** Which backend served the request, when available. */
  backend?: 'ripgrep' | 'elixir';
  /** Wall-clock backend time, when available. */
  elapsedMs?: number;
  /** True when at least one returned line was truncated to fit. */
  truncated?: boolean;
}

/**
 * Raw API call. Returns availability flag so the UI can render gracefully.
 *
 * Calls the endpoint directly (not via `apiGet`) because the response shape
 * carries metadata fields (`backend`, `elapsed_ms`, `truncated`) alongside
 * `data`, which the shared `apiGet` helper would strip via its
 * `{data: ...}` envelope-unwrapping pass.
 */
export async function searchWorkspace(filters: SearchFilters): Promise<BackendStatus> {
  const params = new URLSearchParams();
  params.set('workspace_slug', filters.workspaceSlug);
  params.set('q', filters.q);
  if (filters.regex !== undefined) params.set('regex', String(filters.regex));
  if (filters.caseSensitive !== undefined) {
    params.set('case_sensitive', String(filters.caseSensitive));
  }
  if (filters.limit !== undefined) params.set('limit', String(filters.limit));

  try {
    const res = await fetch(`${API_BASE}/search?${params.toString()}`, {
      method: 'GET',
      headers: { 'Content-Type': 'application/json' },
    });

    if (res.status === 404) {
      return { available: false, hits: [] };
    }

    if (!res.ok) {
      let message = `HTTP ${res.status}`;
      try {
        const body = (await res.json()) as { error?: string; message?: string };
        message = body.error ?? body.message ?? message;
      } catch {
        // non-JSON error body — keep the status message
      }
      throw new ApiError(res.status, message);
    }

    const body = (await res.json()) as {
      data?: Array<{
        file_path: string;
        line_number: number;
        line_text: string;
        match_start: number;
        match_end: number;
      }>;
      backend?: 'ripgrep' | 'elixir';
      elapsed_ms?: number;
      truncated?: boolean;
    };

    const hits: SearchHit[] = (body.data ?? []).map((m) => ({
      filePath: m.file_path,
      lineNumber: m.line_number,
      lineText: m.line_text,
      matchStart: m.match_start,
      matchEnd: m.match_end,
    }));

    return {
      available: true,
      hits,
      backend: body.backend,
      elapsedMs: body.elapsed_ms,
      truncated: body.truncated,
    };
  } catch (err) {
    if (err instanceof ApiError && err.status === 404) {
      return { available: false, hits: [] };
    }
    throw err;
  }
}

/** Query options factory. The query is disabled when q is empty. */
export function searchQuery(filters: SearchFilters) {
  return {
    queryKey: [
      'build-rail',
      'search',
      filters.workspaceSlug,
      filters.q,
      filters.regex ?? false,
      filters.caseSensitive ?? false,
      filters.limit ?? 100,
    ] as const,
    queryFn: () => searchWorkspace(filters),
    staleTime: 5_000,
    enabled: Boolean(filters.workspaceSlug) && filters.q.trim().length > 0,
  };
}
