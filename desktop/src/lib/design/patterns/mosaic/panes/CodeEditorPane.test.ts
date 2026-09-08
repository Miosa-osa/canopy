/**
 * CodeEditorPane — contract-level tests.
 *
 * The pane component itself uses Svelte 5 runes and TanStack Query, both of
 * which need a compiler / DOM context that the Vitest "server" project does
 * not load (vitest.config.ts excludes *.svelte.*.{test,spec}). So this file
 * tests the logic surface the pane consumes:
 *
 *   - the language-detection chain (extension → CodeLanguage → Shiki id)
 *   - the save-resolvability predicate (controls when ⌘S is enabled)
 *   - the saveCodeFileMutation key shape (used by TanStack devtools)
 *
 * Component-level rendering tests can be added later under a `client` Vitest
 * project (jsdom + svelte-kit env) — out of scope for this pane's first cut.
 */
import { describe, expect, it } from 'vitest';
import { isResolvable, isSaveable, saveCodeFileMutation } from '$lib/api/queries/code-editor.js';
import { type CodeEditorPaneConfig, languageFromExtension } from '$lib/domain/code-editor/types.js';
import {
  SHIKI_LANGUAGE_BY_CODE_LANGUAGE,
  SHIKI_LANGUAGES_TO_PRELOAD,
  SHIKI_THEME,
  shikiLanguageFromExtension,
} from './code-editor/extensions.js';

// ── languageFromExtension ────────────────────────────────────────────────────

describe('languageFromExtension()', () => {
  it("returns 'text' for null extension", () => {
    expect(languageFromExtension(null)).toBe('text');
  });

  it('maps ts/tsx/js/jsx to their language ids', () => {
    expect(languageFromExtension('ts')).toBe('typescript');
    expect(languageFromExtension('tsx')).toBe('tsx');
    expect(languageFromExtension('js')).toBe('javascript');
    expect(languageFromExtension('jsx')).toBe('jsx');
  });

  it('maps Elixir extensions (ex, exs, eex)', () => {
    expect(languageFromExtension('ex')).toBe('elixir');
    expect(languageFromExtension('exs')).toBe('elixir');
    expect(languageFromExtension('eex')).toBe('elixir');
  });

  it('maps Rust, Python, Go', () => {
    expect(languageFromExtension('rs')).toBe('rust');
    expect(languageFromExtension('py')).toBe('python');
    expect(languageFromExtension('go')).toBe('go');
  });

  it('maps Svelte, JSON, YAML, Markdown', () => {
    expect(languageFromExtension('svelte')).toBe('svelte');
    expect(languageFromExtension('json')).toBe('json');
    expect(languageFromExtension('yaml')).toBe('yaml');
    expect(languageFromExtension('yml')).toBe('yaml');
    expect(languageFromExtension('md')).toBe('markdown');
    expect(languageFromExtension('mdx')).toBe('markdown');
  });

  it('is case-insensitive', () => {
    expect(languageFromExtension('TS')).toBe('typescript');
    expect(languageFromExtension('Md')).toBe('markdown');
  });

  it("returns 'text' for unknown extensions", () => {
    expect(languageFromExtension('xyz')).toBe('text');
    expect(languageFromExtension('foo.bar')).toBe('text');
  });
});

// ── shikiLanguageFromExtension ───────────────────────────────────────────────

describe('shikiLanguageFromExtension()', () => {
  it('composes languageFromExtension + Shiki map', () => {
    expect(shikiLanguageFromExtension('ts')).toBe('typescript');
    expect(shikiLanguageFromExtension('ex')).toBe('elixir');
    expect(shikiLanguageFromExtension('rs')).toBe('rust');
  });

  it("returns 'text' for unknown extensions (Shiki accepts 'text' without a grammar pack)", () => {
    expect(shikiLanguageFromExtension('xyz')).toBe('text');
    expect(shikiLanguageFromExtension(null)).toBe('text');
  });

  it("preload list contains every language the map references except 'text'", () => {
    const referenced = new Set(Object.values(SHIKI_LANGUAGE_BY_CODE_LANGUAGE));
    referenced.delete('text');
    for (const lang of referenced) {
      expect(SHIKI_LANGUAGES_TO_PRELOAD).toContain(lang);
    }
  });

  it('uses the shared github-dark-dimmed theme to match DiffViewer', () => {
    expect(SHIKI_THEME).toBe('github-dark-dimmed');
  });
});

// ── Pane config resolvability ────────────────────────────────────────────────

describe('isResolvable() / isSaveable()', () => {
  it('treats a (slug, path) pair as both resolvable and saveable', () => {
    const cfg: CodeEditorPaneConfig = {
      workspaceSlug: 'default',
      path: 'main.ts',
    };
    expect(isResolvable(cfg)).toBe(true);
    expect(isSaveable(cfg)).toBe(true);
  });

  it('treats fileId-only as resolvable but NOT saveable', () => {
    const cfg: CodeEditorPaneConfig = { fileId: 'abc-123' };
    expect(isResolvable(cfg)).toBe(true);
    expect(isSaveable(cfg)).toBe(false);
  });

  it('treats an empty config as neither', () => {
    expect(isResolvable({})).toBe(false);
    expect(isSaveable({})).toBe(false);
  });

  it('rejects empty-string slug or path', () => {
    expect(isResolvable({ workspaceSlug: '', path: '' })).toBe(false);
    expect(isSaveable({ workspaceSlug: 'default', path: '' })).toBe(false);
    expect(isSaveable({ workspaceSlug: '', path: 'main.ts' })).toBe(false);
  });
});

// ── Save mutation key shape ──────────────────────────────────────────────────

describe('saveCodeFileMutation()', () => {
  it('returns mutation key scoped to the workspace slug', () => {
    const m = saveCodeFileMutation('default');
    expect(m.mutationKey).toEqual(['code-editor', 'default', 'save']);
  });

  it('differentiates keys per workspace', () => {
    const a = saveCodeFileMutation('ws-a');
    const b = saveCodeFileMutation('ws-b');
    expect(a.mutationKey).not.toEqual(b.mutationKey);
  });

  it('exposes a mutationFn that takes {path, content}', () => {
    const m = saveCodeFileMutation('default');
    expect(typeof m.mutationFn).toBe('function');
  });
});
