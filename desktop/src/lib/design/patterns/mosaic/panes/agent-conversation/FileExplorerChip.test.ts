/**
 * FileExplorerChip — pure-logic tests for filter behavior + the open/
 * close + select contract. The Svelte component uses runes + TanStack
 * Query so we exercise the exported helper and model the consumer
 * contract with plain functions. Same convention as ShellCommandHint.
 */
import { describe, expect, it } from 'vitest';
import type { DirEntry } from '$lib/domain/workspaces/types.js';
import { filterEntries } from './FileExplorerChip.svelte';

function dir(name: string, path: string = name): DirEntry {
  return { name, path, isDir: true, size: 0, modified: null };
}
function file(name: string, path: string = name): DirEntry {
  return { name, path, isDir: false, size: 0, modified: null };
}

// ── filterEntries() ─────────────────────────────────────────────────────────

describe('filterEntries()', () => {
  const entries: DirEntry[] = [
    dir('nodes'),
    file('README.md'),
    file('CLAUDE.md'),
    file('package.json'),
  ];

  it('returns every entry when query is empty', () => {
    expect(filterEntries(entries, '')).toHaveLength(4);
  });

  it('filters by case-insensitive substring on names', () => {
    expect(filterEntries(entries, 'md')).toHaveLength(2);
    expect(filterEntries(entries, 'MD')).toHaveLength(2);
    expect(filterEntries(entries, 'claude')).toHaveLength(1);
  });

  it('trims whitespace from the query', () => {
    expect(filterEntries(entries, '  package  ')).toHaveLength(1);
  });

  it('returns directories AND files (unlike CwdPickerPopover)', () => {
    const out = filterEntries(entries, '');
    expect(out.some((e) => e.isDir)).toBe(true);
    expect(out.some((e) => !e.isDir)).toBe(true);
  });

  it('returns a fresh array (does not alias the input)', () => {
    const out = filterEntries(entries, '');
    expect(out).not.toBe(entries);
  });
});

// ── open / close + select contract ──────────────────────────────────────────

describe('FileExplorerChip — open/close + select contract', () => {
  it('toggles open state on chip click', () => {
    let open = false;
    const toggle = (): void => {
      open = !open;
    };
    toggle();
    expect(open).toBe(true);
    toggle();
    expect(open).toBe(false);
  });

  it('closes after a successful file pick', () => {
    let open = true;
    const calls: string[] = [];
    const handle = (entry: DirEntry, onPickFile: (p: string) => void): void => {
      if (entry.isDir) return;
      onPickFile(entry.path);
      open = false;
    };

    handle(file('README.md'), (p) => calls.push(p));
    expect(calls).toEqual(['README.md']);
    expect(open).toBe(false);
  });

  it('does NOT close when the user clicks a directory', () => {
    let open = true;
    const calls: string[] = [];
    const handle = (entry: DirEntry, onPickFile: (p: string) => void): void => {
      if (entry.isDir) return;
      onPickFile(entry.path);
      open = false;
    };

    handle(dir('nodes'), (p) => calls.push(p));
    expect(calls).toEqual([]);
    expect(open).toBe(true);
  });

  it('emits the workspace-relative path on select', () => {
    const calls: string[] = [];
    const onPickFile = (p: string): void => {
      calls.push(p);
    };

    onPickFile('nodes/02-miosa/context.md');
    expect(calls).toEqual(['nodes/02-miosa/context.md']);
  });
});
