/**
 * parse-diff.ts — Pure unified diff parser.
 * No regex black boxes. Line-by-line imperative parsing.
 * Handles: file headers, added/deleted/renamed, binary, hunks, context/add/del lines.
 * LOC target: ≤ 180.
 */

export interface DiffLine {
  type: 'context' | 'add' | 'del' | 'hunk_header';
  content: string;
  oldLineNo: number | null;
  newLineNo: number | null;
}

export interface DiffHunk {
  oldStart: number;
  oldLines: number;
  newStart: number;
  newLines: number;
  header: string;
  lines: DiffLine[];
}

export interface DiffFile {
  path: string;
  oldPath: string | null;
  status: 'added' | 'deleted' | 'modified' | 'renamed';
  additions: number;
  deletions: number;
  hunks: DiffHunk[];
  binary: boolean;
}

// ── Hunk header parser ────────────────────────────────────────────────────────

function parseHunkHeader(line: string): {
  oldStart: number;
  oldLines: number;
  newStart: number;
  newLines: number;
} | null {
  // @@ -X,Y +A,B @@ optional_context
  const i = line.indexOf('@@', 2);
  if (i < 0) return null;
  const inner = line.slice(3, i).trim(); // "-X,Y +A,B"
  const parts = inner.split(' ');
  if (parts.length < 2) return null;

  function parseRange(s: string): [number, number] {
    const clean = s.startsWith('-') || s.startsWith('+') ? s.slice(1) : s;
    const [start, len] = clean.split(',');
    return [parseInt(start ?? '1', 10), parseInt(len ?? '1', 10)];
  }

  const [oldStart, oldLines] = parseRange(parts[0] ?? '');
  const [newStart, newLines] = parseRange(parts[1] ?? '');
  return { oldStart, oldLines, newStart, newLines };
}

// ── Main parser ───────────────────────────────────────────────────────────────

export function parseDiff(raw: string): DiffFile[] {
  const lines = raw.split('\n');
  const files: DiffFile[] = [];
  let current: DiffFile | null = null;
  let currentHunk: DiffHunk | null = null;
  let oldLineNo = 0;
  let newLineNo = 0;
  let renameFrom: string | null = null;
  let renameTo: string | null = null;

  function finaliseHunk(): void {
    if (currentHunk && current) {
      current.hunks.push(currentHunk);
      currentHunk = null;
    }
  }

  function finaliseFile(): void {
    finaliseHunk();
    if (current) {
      // Apply rename paths if captured
      if (renameFrom && renameTo) {
        current.path = renameTo;
        current.oldPath = renameFrom;
        current.status = 'renamed';
      }
      files.push(current);
      current = null;
      renameFrom = null;
      renameTo = null;
    }
  }

  for (let idx = 0; idx < lines.length; idx++) {
    const line = lines[idx] ?? '';

    // ── New file block ────────────────────────────────────────────────────────
    if (line.startsWith('diff --git ')) {
      finaliseFile();
      // Extract path from "diff --git a/foo b/foo" — take the b/ side
      const match = line.match(/^diff --git a\/.+ b\/(.+)$/);
      const path = match?.[1] ?? line.slice('diff --git a/'.length);
      current = {
        path,
        oldPath: null,
        status: 'modified',
        additions: 0,
        deletions: 0,
        hunks: [],
        binary: false,
      };
      continue;
    }

    if (!current) continue;

    // ── Metadata lines ────────────────────────────────────────────────────────
    if (line.startsWith('new file mode')) {
      current.status = 'added';
      continue;
    }
    if (line.startsWith('deleted file mode')) {
      current.status = 'deleted';
      continue;
    }
    if (line.startsWith('rename from ')) {
      renameFrom = line.slice('rename from '.length);
      continue;
    }
    if (line.startsWith('rename to ')) {
      renameTo = line.slice('rename to '.length);
      continue;
    }
    if (line.startsWith('similarity index')) continue;
    if (line.startsWith('index ')) continue;

    // ── Binary detection ──────────────────────────────────────────────────────
    if (line.startsWith('Binary files')) {
      current.binary = true;
      continue;
    }

    // ── --- / +++ lines ───────────────────────────────────────────────────────
    if (line.startsWith('--- ')) {
      const path = line.slice(4);
      if (path === '/dev/null') current.status = 'added';
      // If current.status wasn't already set to added, leave it; oldPath from rename handles renames
      continue;
    }
    if (line.startsWith('+++ ')) {
      const path = line.slice(4);
      if (path === '/dev/null') current.status = 'deleted';
      continue;
    }

    // ── Hunk header ───────────────────────────────────────────────────────────
    if (line.startsWith('@@ ')) {
      finaliseHunk();
      const parsed = parseHunkHeader(line);
      if (!parsed) continue;
      oldLineNo = parsed.oldStart;
      newLineNo = parsed.newStart;
      currentHunk = { ...parsed, header: line, lines: [] };
      // Push the @@ line itself as a hunk_header DiffLine
      currentHunk.lines.push({
        type: 'hunk_header',
        content: line,
        oldLineNo: null,
        newLineNo: null,
      });
      continue;
    }

    // ── Diff content lines ────────────────────────────────────────────────────
    if (!currentHunk) continue;

    if (line.startsWith('+')) {
      currentHunk.lines.push({
        type: 'add',
        content: line.slice(1),
        oldLineNo: null,
        newLineNo: newLineNo,
      });
      current.additions++;
      newLineNo++;
    } else if (line.startsWith('-')) {
      currentHunk.lines.push({
        type: 'del',
        content: line.slice(1),
        oldLineNo: oldLineNo,
        newLineNo: null,
      });
      current.deletions++;
      oldLineNo++;
    } else if (line.startsWith(' ') || line === '') {
      // Context line — space-prefixed or empty (trailing newline of context block)
      currentHunk.lines.push({
        type: 'context',
        content: line.slice(1),
        oldLineNo: oldLineNo,
        newLineNo: newLineNo,
      });
      oldLineNo++;
      newLineNo++;
    }
    // Ignore "\ No newline at end of file" etc.
  }

  finaliseFile();
  return files;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

export function isTruncated(raw: string): boolean {
  return raw.includes('... (truncated)');
}

export function fileStatusIcon(status: DiffFile['status']): string {
  switch (status) {
    case 'added':
      return '+';
    case 'deleted':
      return '−';
    case 'renamed':
      return '→';
    default:
      return '~';
  }
}
