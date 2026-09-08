/**
 * TanStack Query factories for the Block primitive.
 *
 * Endpoints under /api/v1/sessions/:session_id/blocks/*. Uses the existing
 * apiGet client (snake_case → camelCase conversion at the boundary).
 *
 * Invalidation key: `["blocks", sessionId]` — components mutating session
 * state should invalidate that prefix.
 */

import { apiGet } from '$lib/api/client.js';
import type {
  Block,
  BlockList,
  BlockListQuery,
  BlockSearchQuery,
} from '$lib/domain/blocks/types.js';

// ── Helpers ──────────────────────────────────────────────────────────────────

function buildQuery(opts: object): string {
  const entries = Object.entries(opts as Record<string, unknown>).filter(
    ([, v]) => v !== undefined && v !== null && v !== ''
  );
  if (entries.length === 0) return '';

  const params = new URLSearchParams();
  for (const [key, value] of entries) {
    const snakeKey = key.replace(/[A-Z]/g, (m) => `_${m.toLowerCase()}`);
    params.set(snakeKey, String(value));
  }
  return `?${params.toString()}`;
}

// ── Raw API calls ────────────────────────────────────────────────────────────

export function listBlocks(sessionId: string, opts: BlockListQuery = {}): Promise<BlockList> {
  const qs = buildQuery(opts);
  return apiGet<BlockList>(`/sessions/${sessionId}/blocks${qs}`);
}

export function showBlock(sessionId: string, blockId: string): Promise<Block> {
  return apiGet<Block>(`/sessions/${sessionId}/blocks/${blockId}`);
}

export function searchBlocks(sessionId: string, opts: BlockSearchQuery = {}): Promise<BlockList> {
  const qs = buildQuery(opts);
  return apiGet<BlockList>(`/sessions/${sessionId}/blocks/search${qs}`);
}

// ── TanStack Query option factories ──────────────────────────────────────────

/** Invalidation key prefix — use `["blocks", sessionId]` for session-scoped invalidation. */
export const blocksKey = (sessionId: string) => ['blocks', sessionId] as const;

/** Query options for the blocks list, scoped to a single session. */
export function blocksListQuery(sessionId: string, opts: BlockListQuery = {}) {
  return {
    queryKey: ['blocks', sessionId, 'list', opts] as const,
    queryFn: () =>
      listBlocks(sessionId, opts)
        .then((r) => r.data ?? [])
        .catch(() => []),
    enabled: Boolean(sessionId),
    staleTime: 5_000,
  };
}

/** Query options for one block by id. */
export function blockQuery(sessionId: string, blockId: string) {
  return {
    queryKey: ['blocks', sessionId, 'show', blockId] as const,
    queryFn: () => showBlock(sessionId, blockId),
    enabled: Boolean(sessionId && blockId),
  };
}

/** Query options for the search endpoint. */
export function blocksSearchQuery(sessionId: string, opts: BlockSearchQuery = {}) {
  return {
    queryKey: ['blocks', sessionId, 'search', opts] as const,
    queryFn: () => searchBlocks(sessionId, opts).then((r) => r.data),
    enabled: Boolean(sessionId),
    staleTime: 5_000,
  };
}

export type {
  Block,
  BlockList,
  BlockListQuery,
  BlockSearchQuery,
} from '$lib/domain/blocks/types.js';
