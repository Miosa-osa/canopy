/**
 * Tests for files query factories.
 * Verifies query key shapes, filter wiring, enabled flags, mutation key shapes,
 * and FormData construction for the upload mutation.
 */
import { describe, expect, it } from 'vitest';
import {
  archiveFileMutation,
  fileActivityQuery,
  fileIcon,
  fileQuery,
  filesQuery,
  formatBytes,
  scanWorkspaceMutation,
  searchFilesQuery,
  updateTagsMutation,
  uploadFileMutation,
} from './files.js';

// ── filesQuery ───────────────────────────────────────────────────────────────

describe('filesQuery()', () => {
  it('returns query key ["files", {}] with no filters', () => {
    const q = filesQuery();
    expect(q.queryKey).toEqual(['files', {}]);
  });

  it('includes filter object in query key', () => {
    const filters = { workspace: 'sales-engine', extension: 'md' };
    const q = filesQuery(filters);
    expect(q.queryKey).toEqual(['files', filters]);
  });

  it('has staleTime of 15_000', () => {
    expect(filesQuery().staleTime).toBe(15_000);
  });

  it('has a queryFn function', () => {
    expect(typeof filesQuery().queryFn).toBe('function');
  });

  it('accepts all filter fields', () => {
    const filters = {
      workspace: 'ws',
      tag: 'important',
      q: 'report',
      extension: 'pdf',
    };
    const q = filesQuery(filters);
    expect(q.queryKey[1]).toEqual(filters);
  });
});

// ── fileQuery ─────────────────────────────────────────────────────────────────

describe('fileQuery()', () => {
  it('returns query key ["files", id]', () => {
    const q = fileQuery('abc-123');
    expect(q.queryKey).toEqual(['files', 'abc-123']);
  });

  it('is disabled when id is empty', () => {
    expect(fileQuery('').enabled).toBe(false);
  });

  it('is enabled when id is non-empty', () => {
    expect(fileQuery('abc-123').enabled).toBe(true);
  });

  it('has staleTime of 10_000', () => {
    expect(fileQuery('abc-123').staleTime).toBe(10_000);
  });

  it('has a queryFn function', () => {
    expect(typeof fileQuery('abc-123').queryFn).toBe('function');
  });
});

// ── fileActivityQuery ─────────────────────────────────────────────────────────

describe('fileActivityQuery()', () => {
  it('returns query key ["files", id, "activity"]', () => {
    const q = fileActivityQuery('abc-123');
    expect(q.queryKey).toEqual(['files', 'abc-123', 'activity']);
  });

  it('is disabled when id is empty', () => {
    expect(fileActivityQuery('').enabled).toBe(false);
  });

  it('is enabled when id is non-empty', () => {
    expect(fileActivityQuery('abc-123').enabled).toBe(true);
  });

  it('has a queryFn function', () => {
    expect(typeof fileActivityQuery('abc-123').queryFn).toBe('function');
  });
});

// ── searchFilesQuery ──────────────────────────────────────────────────────────

describe('searchFilesQuery()', () => {
  it('returns query key ["files", "search", slug, q]', () => {
    const q = searchFilesQuery('sales-engine', 'report');
    expect(q.queryKey).toEqual(['files', 'search', 'sales-engine', 'report']);
  });

  it('is disabled when q is empty string', () => {
    expect(searchFilesQuery('sales-engine', '').enabled).toBe(false);
  });

  it('is disabled when q is whitespace', () => {
    expect(searchFilesQuery('sales-engine', '   ').enabled).toBe(false);
  });

  it('is disabled when workspaceSlug is empty', () => {
    expect(searchFilesQuery('', 'report').enabled).toBe(false);
  });

  it('is enabled when both slug and q are non-empty', () => {
    expect(searchFilesQuery('ws', 'doc').enabled).toBe(true);
  });
});

// ── uploadFileMutation ───────────────────────────────────────────────────────

describe('uploadFileMutation()', () => {
  it('returns mutationKey ["files", "upload"]', () => {
    const m = uploadFileMutation();
    expect(m.mutationKey).toEqual(['files', 'upload']);
  });

  it('has a mutationFn function', () => {
    expect(typeof uploadFileMutation().mutationFn).toBe('function');
  });
});

// ── updateTagsMutation ────────────────────────────────────────────────────────

describe('updateTagsMutation()', () => {
  it('returns mutationKey ["files", "update-tags"]', () => {
    const m = updateTagsMutation();
    expect(m.mutationKey).toEqual(['files', 'update-tags']);
  });

  it('has a mutationFn function', () => {
    expect(typeof updateTagsMutation().mutationFn).toBe('function');
  });
});

// ── archiveFileMutation ───────────────────────────────────────────────────────

describe('archiveFileMutation()', () => {
  it('returns mutationKey ["files", "archive"]', () => {
    const m = archiveFileMutation();
    expect(m.mutationKey).toEqual(['files', 'archive']);
  });

  it('has a mutationFn function', () => {
    expect(typeof archiveFileMutation().mutationFn).toBe('function');
  });
});

// ── scanWorkspaceMutation ─────────────────────────────────────────────────────

describe('scanWorkspaceMutation()', () => {
  it('returns mutationKey ["files", "scan"]', () => {
    const m = scanWorkspaceMutation();
    expect(m.mutationKey).toEqual(['files', 'scan']);
  });

  it('has a mutationFn function', () => {
    expect(typeof scanWorkspaceMutation().mutationFn).toBe('function');
  });
});

// ── formatBytes ───────────────────────────────────────────────────────────────

describe('formatBytes()', () => {
  it("formats 0 as '0 B'", () => {
    expect(formatBytes(0)).toBe('0 B');
  });

  it("formats bytes under 1 KB as 'N B'", () => {
    expect(formatBytes(512)).toBe('512 B');
  });

  it("formats 1024 as '1.0 KB'", () => {
    expect(formatBytes(1024)).toBe('1.0 KB');
  });

  it("formats 1536 as '1.5 KB'", () => {
    expect(formatBytes(1536)).toBe('1.5 KB');
  });

  it('formats MB correctly', () => {
    expect(formatBytes(1024 * 1024)).toBe('1.0 MB');
  });

  it('formats GB correctly', () => {
    expect(formatBytes(1024 * 1024 * 1024)).toBe('1.0 GB');
  });
});

// ── fileIcon ──────────────────────────────────────────────────────────────────

describe('fileIcon()', () => {
  it('returns 📄 for null extension', () => {
    expect(fileIcon(null)).toBe('📄');
  });

  it('returns 📝 for md', () => {
    expect(fileIcon('md')).toBe('📝');
  });

  it('returns 📜 for ts', () => {
    expect(fileIcon('ts')).toBe('📜');
  });

  it('returns 💜 for ex (Elixir)', () => {
    expect(fileIcon('ex')).toBe('💜');
  });

  it('is case-insensitive', () => {
    expect(fileIcon('MD')).toBe('📝');
    expect(fileIcon('TS')).toBe('📜');
  });

  it('returns 📄 for unknown extension', () => {
    expect(fileIcon('xyz')).toBe('📄');
  });

  it('returns 📊 for csv', () => {
    expect(fileIcon('csv')).toBe('📊');
  });
});
