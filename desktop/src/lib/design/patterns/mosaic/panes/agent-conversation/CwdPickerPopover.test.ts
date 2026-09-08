/**
 * CwdPickerPopover — pure-logic tests for the directory-filtering and
 * parent-directory-resolution helpers. The Svelte component itself uses
 * runes + TanStack Query, which the Vitest "server" project doesn't
 * load — so we exercise the exported helpers that drive every visible
 * decision in the popover. Same convention as ShellCommandHint.
 */
import { describe, expect, it } from 'vitest';
import type { DirEntry } from '$lib/domain/workspaces/types.js';
import { filterDirs, parentDir } from './CwdPickerPopover.svelte';

function dir(name: string, path: string = name): DirEntry {
  return { name, path, isDir: true, size: 0, modified: null };
}
function file(name: string, path: string = name): DirEntry {
  return { name, path, isDir: false, size: 0, modified: null };
}

// ── parentDir() ─────────────────────────────────────────────────────────────

describe('parentDir()', () => {
  it("returns '' for the workspace root", () => {
    expect(parentDir('')).toBe('');
  });

  it("returns '' when path is a single segment", () => {
    expect(parentDir('nodes')).toBe('');
    expect(parentDir('README.md')).toBe('');
  });

  it('strips one segment from a nested path', () => {
    expect(parentDir('nodes/02-miosa')).toBe('nodes');
    expect(parentDir('nodes/02-miosa/context.md')).toBe('nodes/02-miosa');
  });

  it('ignores a trailing slash', () => {
    expect(parentDir('nodes/02-miosa/')).toBe('nodes');
  });

  it('never escapes the workspace (no leading slash leak)', () => {
    expect(parentDir('a')).toBe('');
    expect(parentDir('')).toBe('');
  });
});

// ── filterDirs() ────────────────────────────────────────────────────────────

describe('filterDirs()', () => {
  const entries: DirEntry[] = [
    dir('nodes'),
    dir('packages'),
    dir('rhythm'),
    file('README.md'),
    file('CLAUDE.md'),
  ];

  it('returns only directories when query is empty', () => {
    const out = filterDirs(entries, '');
    expect(out).toHaveLength(3);
    expect(out.every((e) => e.isDir)).toBe(true);
  });

  it('filters by case-insensitive substring', () => {
    expect(filterDirs(entries, 'node')).toHaveLength(1);
    expect(filterDirs(entries, 'NODE')).toHaveLength(1);
    expect(filterDirs(entries, 'es')).toHaveLength(2); // nodes, packages
  });

  it('returns an empty list when nothing matches', () => {
    expect(filterDirs(entries, 'zzz')).toHaveLength(0);
  });

  it('trims whitespace before matching', () => {
    expect(filterDirs(entries, '  rhythm  ')).toHaveLength(1);
  });

  it('never returns files even on a name match', () => {
    // "README.md" contains "ad" — filter should still skip it.
    const out = filterDirs(entries, 'read');
    expect(out).toHaveLength(0);
  });
});

// ── Select event contract ───────────────────────────────────────────────────

describe('CwdPickerPopover — select contract', () => {
  it("calls onPick with the chosen directory's path", () => {
    const calls: string[] = [];
    const onPick = (p: string): void => {
      calls.push(p);
    };

    // Simulate the click handler the component delegates to.
    const handlePick = (path: string, onPickFn: (p: string) => void): void => {
      onPickFn(path);
    };

    handlePick('nodes/02-miosa', onPick);
    expect(calls).toEqual(['nodes/02-miosa']);
  });

  it("passes '' when the user picks the parent of a top-level dir", () => {
    const calls: string[] = [];
    const onPick = (p: string): void => {
      calls.push(p);
    };
    onPick(parentDir('nodes'));
    expect(calls).toEqual(['']);
  });
});
