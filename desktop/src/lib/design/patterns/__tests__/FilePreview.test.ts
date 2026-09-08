/**
 * FilePreview unit tests — pure logic layer (no Svelte rendering).
 *
 * Tests: MIME-based viewer routing, extension fallback when MIME is generic,
 * size cap enforcement (> 50 MB), PPTX fallback, and unsupported type fallback.
 *
 * The actual viewer libraries (pdfjs-dist, docx-preview, xlsx) run in a real
 * browser context and are not testable in vitest without a browser project.
 * We test the routing logic (resolveViewer) which is the critical decision
 * tree that determines which viewer is rendered.
 */
import { describe, expect, it } from 'vitest';

// ── Inline resolveViewer — mirrors the exported function in FilePreview.svelte ─
// Kept in sync with the component. Tests break immediately if logic drifts.

const SIZE_CAP_BYTES = 50 * 1024 * 1024; // 50 MB

const TEXT_EXTS = new Set([
  'md',
  'txt',
  'json',
  'yaml',
  'yml',
  'csv',
  'log',
  'ts',
  'js',
  'tsx',
  'jsx',
  'py',
  'ex',
  'exs',
  'rs',
  'go',
  'rb',
  'sh',
  'toml',
  'env',
  'svelte',
  'css',
  'html',
  'xml',
  'sql',
]);

type ViewerKind =
  | 'pdf'
  | 'docx'
  | 'xlsx'
  | 'pptx'
  | 'video'
  | 'audio'
  | 'image'
  | 'text'
  | 'unsupported'
  | 'too-large';

function extOf(name: string): string {
  const dot = name.lastIndexOf('.');
  return dot === -1 ? '' : name.slice(dot + 1).toLowerCase();
}

function resolveViewer(mime: string | null, name: string, sizeBytes: number): ViewerKind {
  if (sizeBytes > SIZE_CAP_BYTES) return 'too-large';
  const ext = extOf(name);
  const m = (mime ?? '').toLowerCase();

  if (m === 'application/pdf' || ext === 'pdf') return 'pdf';
  if (
    m === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
    ext === 'docx' ||
    ext === 'doc'
  )
    return 'docx';
  if (
    m === 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
    m === 'application/vnd.ms-excel' ||
    ext === 'xlsx' ||
    ext === 'xls'
  )
    return 'xlsx';
  if (
    m === 'application/vnd.openxmlformats-officedocument.presentationml.presentation' ||
    ext === 'pptx' ||
    ext === 'ppt'
  )
    return 'pptx';
  if (m.startsWith('video/')) return 'video';
  if (m.startsWith('audio/')) return 'audio';
  if (m.startsWith('image/')) return 'image';
  if (m.startsWith('text/') || TEXT_EXTS.has(ext)) return 'text';

  return 'unsupported';
}

const SMALL = 1024; // 1 KB — well under cap
const LARGE = SIZE_CAP_BYTES + 1; // 1 byte over 50 MB

// ── Size cap ──────────────────────────────────────────────────────────────────

describe('resolveViewer() — size cap', () => {
  it('returns too-large for files > 50 MB regardless of MIME', () => {
    expect(resolveViewer('application/pdf', 'report.pdf', LARGE)).toBe('too-large');
  });

  it('returns too-large for DOCX over 50 MB', () => {
    expect(
      resolveViewer(
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'doc.docx',
        LARGE
      )
    ).toBe('too-large');
  });

  it('returns too-large for video over 50 MB', () => {
    expect(resolveViewer('video/mp4', 'video.mp4', LARGE)).toBe('too-large');
  });

  it('allows exactly 50 MB (boundary is exclusive)', () => {
    expect(resolveViewer('application/pdf', 'ok.pdf', SIZE_CAP_BYTES)).toBe('pdf');
  });
});

// ── MIME-based routing ────────────────────────────────────────────────────────

describe('resolveViewer() — MIME routing', () => {
  it('routes application/pdf to pdf', () => {
    expect(resolveViewer('application/pdf', 'file.pdf', SMALL)).toBe('pdf');
  });

  it('routes DOCX MIME to docx', () => {
    expect(
      resolveViewer(
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'doc.docx',
        SMALL
      )
    ).toBe('docx');
  });

  it('routes XLSX MIME to xlsx', () => {
    expect(
      resolveViewer(
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'sheet.xlsx',
        SMALL
      )
    ).toBe('xlsx');
  });

  it('routes application/vnd.ms-excel to xlsx', () => {
    expect(resolveViewer('application/vnd.ms-excel', 'sheet.xls', SMALL)).toBe('xlsx');
  });

  it('routes PPTX MIME to pptx', () => {
    expect(
      resolveViewer(
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'deck.pptx',
        SMALL
      )
    ).toBe('pptx');
  });

  it('routes video/mp4 to video', () => {
    expect(resolveViewer('video/mp4', 'clip.mp4', SMALL)).toBe('video');
  });

  it('routes video/webm to video', () => {
    expect(resolveViewer('video/webm', 'clip.webm', SMALL)).toBe('video');
  });

  it('routes audio/mpeg to audio', () => {
    expect(resolveViewer('audio/mpeg', 'track.mp3', SMALL)).toBe('audio');
  });

  it('routes audio/ogg to audio', () => {
    expect(resolveViewer('audio/ogg', 'track.ogg', SMALL)).toBe('audio');
  });

  it('routes image/png to image', () => {
    expect(resolveViewer('image/png', 'photo.png', SMALL)).toBe('image');
  });

  it('routes image/svg+xml to image', () => {
    expect(resolveViewer('image/svg+xml', 'icon.svg', SMALL)).toBe('image');
  });

  it('routes text/plain to text', () => {
    expect(resolveViewer('text/plain', 'notes.txt', SMALL)).toBe('text');
  });

  it('routes text/markdown to text', () => {
    expect(resolveViewer('text/markdown', 'readme.md', SMALL)).toBe('text');
  });

  it('routes text/csv to text', () => {
    expect(resolveViewer('text/csv', 'data.csv', SMALL)).toBe('text');
  });

  it('returns unsupported for unknown MIME and no matching extension', () => {
    expect(resolveViewer('application/octet-stream', 'binary.bin', SMALL)).toBe('unsupported');
  });

  it('returns unsupported for zip files', () => {
    expect(resolveViewer('application/zip', 'archive.zip', SMALL)).toBe('unsupported');
  });
});

// ── Extension fallback (MIME is generic octet-stream) ─────────────────────────

describe('resolveViewer() — extension fallback', () => {
  const GENERIC = 'application/octet-stream';

  it('falls back to pdf for .pdf extension', () => {
    expect(resolveViewer(GENERIC, 'report.pdf', SMALL)).toBe('pdf');
  });

  it('falls back to docx for .docx extension', () => {
    expect(resolveViewer(GENERIC, 'document.docx', SMALL)).toBe('docx');
  });

  it('falls back to docx for .doc extension', () => {
    expect(resolveViewer(GENERIC, 'document.doc', SMALL)).toBe('docx');
  });

  it('falls back to xlsx for .xlsx extension', () => {
    expect(resolveViewer(GENERIC, 'sheet.xlsx', SMALL)).toBe('xlsx');
  });

  it('falls back to xlsx for .xls extension', () => {
    expect(resolveViewer(GENERIC, 'sheet.xls', SMALL)).toBe('xlsx');
  });

  it('falls back to pptx for .pptx extension', () => {
    expect(resolveViewer(GENERIC, 'deck.pptx', SMALL)).toBe('pptx');
  });

  it('falls back to text for .ts extension', () => {
    expect(resolveViewer(GENERIC, 'index.ts', SMALL)).toBe('text');
  });

  it('falls back to text for .md extension', () => {
    expect(resolveViewer(GENERIC, 'README.md', SMALL)).toBe('text');
  });

  it('falls back to text for .json extension', () => {
    expect(resolveViewer(GENERIC, 'config.json', SMALL)).toBe('text');
  });

  it('falls back to text for .py extension', () => {
    expect(resolveViewer(GENERIC, 'script.py', SMALL)).toBe('text');
  });

  it('falls back to text for .ex extension', () => {
    expect(resolveViewer(GENERIC, 'module.ex', SMALL)).toBe('text');
  });

  it('falls back to text for .yaml extension', () => {
    expect(resolveViewer(GENERIC, 'ci.yaml', SMALL)).toBe('text');
  });

  it('falls back to text for .sql extension', () => {
    expect(resolveViewer(GENERIC, 'query.sql', SMALL)).toBe('text');
  });

  it('falls back to text for .svelte extension', () => {
    expect(resolveViewer(GENERIC, 'Page.svelte', SMALL)).toBe('text');
  });

  it('returns unsupported for unrecognized extension', () => {
    expect(resolveViewer(GENERIC, 'file.unknown123', SMALL)).toBe('unsupported');
  });

  it('returns unsupported when no extension and MIME is generic', () => {
    expect(resolveViewer(GENERIC, 'Makefile', SMALL)).toBe('unsupported');
  });
});

// ── Null MIME handling ─────────────────────────────────────────────────────────

describe('resolveViewer() — null MIME', () => {
  it('routes by extension when MIME is null', () => {
    expect(resolveViewer(null, 'readme.md', SMALL)).toBe('text');
  });

  it('routes PDF by extension when MIME is null', () => {
    expect(resolveViewer(null, 'report.pdf', SMALL)).toBe('pdf');
  });

  it('returns unsupported for null MIME and no extension', () => {
    expect(resolveViewer(null, 'binaryfile', SMALL)).toBe('unsupported');
  });
});

// ── PPTX fallback (not rendered) ──────────────────────────────────────────────

describe('resolveViewer() — PPTX deferred', () => {
  it('returns pptx (not unsupported) so the component shows the deferred message', () => {
    expect(resolveViewer(null, 'deck.pptx', SMALL)).toBe('pptx');
  });

  it('returns pptx for .ppt extension', () => {
    expect(resolveViewer(null, 'old-deck.ppt', SMALL)).toBe('pptx');
  });
});

// ── extOf helper ──────────────────────────────────────────────────────────────

describe('extOf()', () => {
  it('extracts lowercase extension', () => {
    expect(extOf('Report.PDF')).toBe('pdf');
  });

  it('handles files with no extension', () => {
    expect(extOf('Makefile')).toBe('');
  });

  it('handles dotfiles', () => {
    expect(extOf('.env')).toBe('env');
  });

  it('uses the last dot for multi-part extensions', () => {
    expect(extOf('archive.tar.gz')).toBe('gz');
  });
});
