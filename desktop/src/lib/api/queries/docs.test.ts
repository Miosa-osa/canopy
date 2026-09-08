/**
 * Tests for docs query factories + body helpers.
 * Verifies query key shapes, enabled flags, mutation key shapes,
 * and bodyJsonFromText / bodyTextFromJson roundtrip.
 */
import { describe, expect, it } from 'vitest';
import {
  archiveDocumentMutation,
  bodyJsonFromText,
  bodyTextFromJson,
  createDocumentMutation,
  createFolderMutation,
  deleteDocumentMutation,
  deleteFolderMutation,
  documentQuery,
  documentsQuery,
  foldersQuery,
  folderTreeQuery,
  publishDocumentMutation,
  searchDocumentsQuery,
  unarchiveDocumentMutation,
  unpublishDocumentMutation,
  updateDocumentMutation,
  updateFolderMutation,
} from './docs.js';

// ── bodyJsonFromText ──────────────────────────────────────────────────────────

describe('bodyJsonFromText()', () => {
  it('wraps empty string into a doc with one empty paragraph', () => {
    const doc = bodyJsonFromText('');
    expect(doc.type).toBe('doc');
    expect(doc.content).toHaveLength(1);
    expect(doc.content[0].type).toBe('paragraph');
    expect(doc.content[0].content).toHaveLength(0);
  });

  it('wraps a single line into one paragraph with one text node', () => {
    const doc = bodyJsonFromText('Hello world');
    expect(doc.content).toHaveLength(1);
    expect(doc.content[0].content).toEqual([{ type: 'text', text: 'Hello world' }]);
  });

  it('splits multi-line text into multiple paragraphs', () => {
    const doc = bodyJsonFromText('Line 1\nLine 2\nLine 3');
    expect(doc.content).toHaveLength(3);
    expect(doc.content[0].content).toEqual([{ type: 'text', text: 'Line 1' }]);
    expect(doc.content[1].content).toEqual([{ type: 'text', text: 'Line 2' }]);
    expect(doc.content[2].content).toEqual([{ type: 'text', text: 'Line 3' }]);
  });

  it('maps blank lines to paragraphs with empty content', () => {
    const doc = bodyJsonFromText('Hello\n\nWorld');
    expect(doc.content).toHaveLength(3);
    expect(doc.content[1].content).toHaveLength(0);
  });
});

// ── bodyTextFromJson ──────────────────────────────────────────────────────────

describe('bodyTextFromJson()', () => {
  it('returns empty string for null input', () => {
    expect(bodyTextFromJson(null)).toBe('');
  });

  it('extracts text from a single paragraph', () => {
    const doc = bodyJsonFromText('Hello world');
    expect(bodyTextFromJson(doc)).toBe('Hello world');
  });

  it('joins multiple paragraphs with newlines', () => {
    const doc = bodyJsonFromText('Line 1\nLine 2');
    expect(bodyTextFromJson(doc)).toBe('Line 1\nLine 2');
  });

  it('roundtrips correctly for multi-line text', () => {
    const original = 'First line\nSecond line\nThird line';
    const doc = bodyJsonFromText(original);
    expect(bodyTextFromJson(doc)).toBe(original);
  });

  it('roundtrips empty string', () => {
    expect(bodyTextFromJson(bodyJsonFromText(''))).toBe('');
  });
});

// ── folderTreeQuery ───────────────────────────────────────────────────────────

describe('folderTreeQuery()', () => {
  it('returns query key ["doc-folders", slug, "tree"]', () => {
    const q = folderTreeQuery('my-workspace');
    expect(q.queryKey).toEqual(['doc-folders', 'my-workspace', 'tree']);
  });

  it('is disabled when workspaceSlug is empty', () => {
    expect(folderTreeQuery('').enabled).toBe(false);
  });

  it('is enabled when workspaceSlug is non-empty', () => {
    expect(folderTreeQuery('ws').enabled).toBe(true);
  });

  it('has staleTime of 30_000', () => {
    expect(folderTreeQuery('ws').staleTime).toBe(30_000);
  });

  it('has a queryFn function', () => {
    expect(typeof folderTreeQuery('ws').queryFn).toBe('function');
  });
});

// ── foldersQuery ──────────────────────────────────────────────────────────────

describe('foldersQuery()', () => {
  it('returns query key ["doc-folders", slug]', () => {
    const q = foldersQuery('ws');
    expect(q.queryKey).toEqual(['doc-folders', 'ws']);
  });

  it('is disabled when workspaceSlug is empty', () => {
    expect(foldersQuery('').enabled).toBe(false);
  });
});

// ── Folder mutations ──────────────────────────────────────────────────────────

describe('createFolderMutation()', () => {
  it('returns mutationKey ["doc-folders", "create"]', () => {
    expect(createFolderMutation().mutationKey).toEqual(['doc-folders', 'create']);
  });

  it('has a mutationFn', () => {
    expect(typeof createFolderMutation().mutationFn).toBe('function');
  });
});

describe('updateFolderMutation()', () => {
  it('returns mutationKey ["doc-folders", "update"]', () => {
    expect(updateFolderMutation().mutationKey).toEqual(['doc-folders', 'update']);
  });
});

describe('deleteFolderMutation()', () => {
  it('returns mutationKey ["doc-folders", "delete"]', () => {
    expect(deleteFolderMutation().mutationKey).toEqual(['doc-folders', 'delete']);
  });
});

// ── documentsQuery ────────────────────────────────────────────────────────────

describe('documentsQuery()', () => {
  it('returns query key ["docs", {}] with no filters', () => {
    expect(documentsQuery().queryKey).toEqual(['docs', {}]);
  });

  it('includes filters in the query key', () => {
    const q = documentsQuery({ workspace: 'ws', tag: 'api' });
    expect(q.queryKey).toEqual(['docs', { workspace: 'ws', tag: 'api' }]);
  });

  it('has staleTime of 10_000', () => {
    expect(documentsQuery().staleTime).toBe(10_000);
  });
});

// ── documentQuery ─────────────────────────────────────────────────────────────

describe('documentQuery()', () => {
  it('returns query key ["docs", id]', () => {
    expect(documentQuery('abc-123').queryKey).toEqual(['docs', 'abc-123']);
  });

  it('is disabled when id is empty', () => {
    expect(documentQuery('').enabled).toBe(false);
  });

  it('is enabled when id is non-empty', () => {
    expect(documentQuery('abc').enabled).toBe(true);
  });

  it('has staleTime of 5_000', () => {
    expect(documentQuery('x').staleTime).toBe(5_000);
  });
});

// ── Document mutations ────────────────────────────────────────────────────────

describe('createDocumentMutation()', () => {
  it('returns mutationKey ["docs", "create"]', () => {
    expect(createDocumentMutation().mutationKey).toEqual(['docs', 'create']);
  });

  it('has a mutationFn', () => {
    expect(typeof createDocumentMutation().mutationFn).toBe('function');
  });
});

describe('updateDocumentMutation()', () => {
  it('returns mutationKey ["docs", "update"]', () => {
    expect(updateDocumentMutation().mutationKey).toEqual(['docs', 'update']);
  });
});

describe('publishDocumentMutation()', () => {
  it('returns mutationKey ["docs", "publish"]', () => {
    expect(publishDocumentMutation().mutationKey).toEqual(['docs', 'publish']);
  });
});

describe('unpublishDocumentMutation()', () => {
  it('returns mutationKey ["docs", "unpublish"]', () => {
    expect(unpublishDocumentMutation().mutationKey).toEqual(['docs', 'unpublish']);
  });
});

describe('archiveDocumentMutation()', () => {
  it('returns mutationKey ["docs", "archive"]', () => {
    expect(archiveDocumentMutation().mutationKey).toEqual(['docs', 'archive']);
  });
});

describe('unarchiveDocumentMutation()', () => {
  it('returns mutationKey ["docs", "unarchive"]', () => {
    expect(unarchiveDocumentMutation().mutationKey).toEqual(['docs', 'unarchive']);
  });
});

describe('deleteDocumentMutation()', () => {
  it('returns mutationKey ["docs", "delete"]', () => {
    expect(deleteDocumentMutation().mutationKey).toEqual(['docs', 'delete']);
  });
});

// ── searchDocumentsQuery ──────────────────────────────────────────────────────

describe('searchDocumentsQuery()', () => {
  it('returns query key ["docs", "search", workspace, q]', () => {
    const q = searchDocumentsQuery('ws', 'hello');
    expect(q.queryKey).toEqual(['docs', 'search', 'ws', 'hello']);
  });

  it('is disabled when q is empty', () => {
    expect(searchDocumentsQuery('ws', '').enabled).toBe(false);
  });

  it('is disabled when q is whitespace only', () => {
    expect(searchDocumentsQuery('ws', '   ').enabled).toBe(false);
  });

  it('is disabled when workspaceSlug is empty', () => {
    expect(searchDocumentsQuery('', 'query').enabled).toBe(false);
  });

  it('is enabled when both workspaceSlug and q are non-empty', () => {
    expect(searchDocumentsQuery('ws', 'term').enabled).toBe(true);
  });

  it('has staleTime of 0', () => {
    expect(searchDocumentsQuery('ws', 'x').staleTime).toBe(0);
  });
});
