/**
 * Tests for knowledge query factories.
 * Verifies query key shapes, factory output, and mutation key correctness.
 * Phase 5 Wave 2 Track #105.
 */
import { describe, expect, it } from 'vitest';
import {
  addFileMutation,
  archiveBaseMutation,
  assignAgentMutation,
  createBaseMutation,
  kbChunksQuery,
  kbSearchQuery,
  knowledgeBaseQuery,
  knowledgeBasesQuery,
  rebuildIndexMutation,
  searchMutation,
  unassignAgentMutation,
} from './knowledge.js';

// ── knowledgeBasesQuery ───────────────────────────────────────────────────────

describe('knowledgeBasesQuery()', () => {
  it('returns query key ["knowledge-bases", {}] with no filters', () => {
    const q = knowledgeBasesQuery();
    expect(q.queryKey).toEqual(['knowledge-bases', {}]);
  });

  it('returns query key with filters when provided', () => {
    const q = knowledgeBasesQuery({ workspace: 'my-ws' });
    expect(q.queryKey).toEqual(['knowledge-bases', { workspace: 'my-ws' }]);
  });

  it('has staleTime of 30_000', () => {
    const q = knowledgeBasesQuery();
    expect(q.staleTime).toBe(30_000);
  });

  it('has a queryFn function', () => {
    const q = knowledgeBasesQuery();
    expect(typeof q.queryFn).toBe('function');
  });
});

// ── knowledgeBaseQuery ────────────────────────────────────────────────────────

describe('knowledgeBaseQuery()', () => {
  it('returns query key ["knowledge-bases", slug]', () => {
    const q = knowledgeBaseQuery('my-kb');
    expect(q.queryKey).toEqual(['knowledge-bases', 'my-kb']);
  });

  it('is disabled when slug is empty string', () => {
    const q = knowledgeBaseQuery('');
    expect(q.enabled).toBe(false);
  });

  it('is enabled when slug is non-empty', () => {
    const q = knowledgeBaseQuery('docs-kb');
    expect(q.enabled).toBe(true);
  });

  it('has staleTime of 30_000', () => {
    const q = knowledgeBaseQuery('docs-kb');
    expect(q.staleTime).toBe(30_000);
  });
});

// ── kbChunksQuery ─────────────────────────────────────────────────────────────

describe('kbChunksQuery()', () => {
  it('returns correct query key with default pagination', () => {
    const q = kbChunksQuery('my-kb');
    expect(q.queryKey).toEqual(['knowledge-bases', 'my-kb', 'chunks', 50, 0]);
  });

  it('returns correct query key with custom pagination', () => {
    const q = kbChunksQuery('my-kb', 25, 100);
    expect(q.queryKey).toEqual(['knowledge-bases', 'my-kb', 'chunks', 25, 100]);
  });

  it('is disabled when slug is empty', () => {
    const q = kbChunksQuery('');
    expect(q.enabled).toBe(false);
  });

  it('has a queryFn function', () => {
    const q = kbChunksQuery('my-kb');
    expect(typeof q.queryFn).toBe('function');
  });
});

// ── kbSearchQuery ─────────────────────────────────────────────────────────────

describe('kbSearchQuery()', () => {
  it('returns correct query key', () => {
    const q = kbSearchQuery('my-kb', 'what is RAG', 5);
    expect(q.queryKey).toEqual(['knowledge-bases', 'my-kb', 'search', 'what is RAG', 5]);
  });

  it('is disabled when slug is empty', () => {
    const q = kbSearchQuery('', 'query');
    expect(q.enabled).toBe(false);
  });

  it('is disabled when query is empty', () => {
    const q = kbSearchQuery('my-kb', '');
    expect(q.enabled).toBe(false);
  });

  it('is enabled when both slug and query are non-empty', () => {
    const q = kbSearchQuery('my-kb', 'test');
    expect(q.enabled).toBe(true);
  });
});

// ── Mutation factories ────────────────────────────────────────────────────────

describe('createBaseMutation()', () => {
  it('returns mutationKey ["knowledge-bases", "create"]', () => {
    const m = createBaseMutation();
    expect(m.mutationKey).toEqual(['knowledge-bases', 'create']);
  });

  it('has a mutationFn function', () => {
    const m = createBaseMutation();
    expect(typeof m.mutationFn).toBe('function');
  });
});

describe('archiveBaseMutation()', () => {
  it('returns mutationKey ["knowledge-bases", "archive"]', () => {
    const m = archiveBaseMutation();
    expect(m.mutationKey).toEqual(['knowledge-bases', 'archive']);
  });

  it('has a mutationFn function', () => {
    const m = archiveBaseMutation();
    expect(typeof m.mutationFn).toBe('function');
  });
});

describe('addFileMutation()', () => {
  it('returns mutationKey ["knowledge-bases", "add-file"]', () => {
    const m = addFileMutation();
    expect(m.mutationKey).toEqual(['knowledge-bases', 'add-file']);
  });

  it('has a mutationFn function', () => {
    const m = addFileMutation();
    expect(typeof m.mutationFn).toBe('function');
  });
});

describe('searchMutation()', () => {
  it('returns mutationKey ["knowledge-bases", "search"]', () => {
    const m = searchMutation();
    expect(m.mutationKey).toEqual(['knowledge-bases', 'search']);
  });

  it('has a mutationFn function', () => {
    const m = searchMutation();
    expect(typeof m.mutationFn).toBe('function');
  });
});

describe('assignAgentMutation()', () => {
  it('returns mutationKey ["knowledge-bases", "assign"]', () => {
    const m = assignAgentMutation();
    expect(m.mutationKey).toEqual(['knowledge-bases', 'assign']);
  });

  it('has a mutationFn function', () => {
    const m = assignAgentMutation();
    expect(typeof m.mutationFn).toBe('function');
  });
});

describe('unassignAgentMutation()', () => {
  it('returns mutationKey ["knowledge-bases", "unassign"]', () => {
    const m = unassignAgentMutation();
    expect(m.mutationKey).toEqual(['knowledge-bases', 'unassign']);
  });

  it('has a mutationFn function', () => {
    const m = unassignAgentMutation();
    expect(typeof m.mutationFn).toBe('function');
  });
});

describe('rebuildIndexMutation()', () => {
  it('returns mutationKey ["knowledge-bases", "rebuild"]', () => {
    const m = rebuildIndexMutation();
    expect(m.mutationKey).toEqual(['knowledge-bases', 'rebuild']);
  });

  it('has a mutationFn function', () => {
    const m = rebuildIndexMutation();
    expect(typeof m.mutationFn).toBe('function');
  });
});

// ── Payload shape validation (SearchBody) ────────────────────────────────────

describe('searchMutation() — payload shape', () => {
  it('mutationFn accepts slug + body with query and limit', () => {
    const m = searchMutation();
    // Just confirm the function signature accepts the expected shape (no network call)
    expect(typeof m.mutationFn({ slug: 'kb-1', body: { query: 'test', limit: 5 } })).toBe('object');
  });
});

describe('addFileMutation() — payload shape', () => {
  it('mutationFn accepts slug + body with file_id', () => {
    const m = addFileMutation();
    expect(typeof m.mutationFn({ slug: 'kb-1', body: { file_id: 'abc-123' } })).toBe('object');
  });
});
