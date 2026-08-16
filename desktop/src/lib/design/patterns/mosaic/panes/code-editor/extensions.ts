/**
 * extensions.ts — Code Editor language + theme setup.
 *
 * INTENDED state (when CodeMirror is installed):
 *   exports a buildExtensions() function that returns an array of CodeMirror
 *   extensions: language pack, oneDark theme, line numbers, history, search,
 *   keymaps (default + ⌘S save callback), and an updateListener that syncs
 *   the editor doc back into our save-state runes.
 *
 * CURRENT state (CodeMirror NOT yet installed):
 *   exports the language-detection helpers and a Shiki language ID map. The
 *   pane uses a textarea fallback + Shiki for read-only highlighting, then
 *   upgrades transparently when CodeMirror is added.
 *
 * To upgrade: add the packages listed in wiring/code-editor-wiring.md, then
 * implement `buildExtensions(opts)` against the @codemirror/* APIs. The pane
 * will dynamic-import this module so a missing dep here cannot break the
 * build elsewhere.
 */

import {
  type CodeLanguage,
  languageFromExtension,
} from "$lib/domain/code-editor/types.js";

// ── Shiki language IDs (today's source of highlighting) ──────────────────────

/**
 * Map our internal CodeLanguage to a Shiki language identifier. Shiki is
 * already at ^4.0.2 in package.json (used by patterns/diff/DiffViewer.svelte
 * and patterns/mosaic/panes/file-viewer/MarkdownViewer.svelte) so we reuse
 * that infrastructure rather than introducing a parallel highlighter.
 */
export const SHIKI_LANGUAGE_BY_CODE_LANGUAGE: Record<CodeLanguage, string> = {
  javascript: "javascript",
  typescript: "typescript",
  tsx: "tsx",
  jsx: "jsx",
  elixir: "elixir",
  rust: "rust",
  python: "python",
  json: "json",
  markdown: "markdown",
  svelte: "svelte",
  yaml: "yaml",
  go: "go",
  html: "html",
  css: "css",
  bash: "bash",
  sql: "sql",
  toml: "toml",
  text: "text",
};

/** Shiki theme used across the app. Match DiffViewer.svelte for visual consistency. */
export const SHIKI_THEME = "github-dark-dimmed" as const;

/**
 * Resolve `extension → CodeLanguage → Shiki id` in one shot. Returns
 * "text" for unknown extensions (Shiki accepts "text" without loading
 * a grammar pack).
 */
export function shikiLanguageFromExtension(extension: string | null): string {
  const lang = languageFromExtension(extension);
  return SHIKI_LANGUAGE_BY_CODE_LANGUAGE[lang];
}

/**
 * The full set of Shiki languages this pane will lazy-load. Used by the
 * single createHighlighter() call in CodeEditorPane.svelte.
 */
export const SHIKI_LANGUAGES_TO_PRELOAD: string[] = [
  "javascript",
  "typescript",
  "tsx",
  "jsx",
  "elixir",
  "rust",
  "python",
  "json",
  "markdown",
  "svelte",
  "yaml",
  "go",
  "html",
  "css",
  "bash",
  "sql",
  "toml",
];

// ── CodeMirror buildExtensions() — TODO until packages are installed ─────────

/**
 * Future API:
 *
 *   buildExtensions({
 *     language,            // CodeLanguage from languageFromExtension(ext)
 *     onChange,            // (doc: string) => void  — wire to saveState.setDraft()
 *     onSaveShortcut,      // () => void             — wire to triggerSave()
 *     readOnly = false,
 *   })
 *
 * Returns: Extension[] for `new EditorView({ state: EditorState.create({...}) })`
 *
 * NOT IMPLEMENTED — see wiring/code-editor-wiring.md → "pnpm packages required"
 * for the install list. Do NOT import @codemirror/* from this file until the
 * packages are in node_modules — Vite will hard-fail.
 */
export interface BuildExtensionsOptions {
  language: CodeLanguage;
  onChange: (doc: string) => void;
  onSaveShortcut: () => void;
  readOnly?: boolean;
}

/**
 * Stub — throws to make accidental upgrade-without-install attempts loud.
 * Replace this body with the real CodeMirror wiring once the packages land.
 */
export function buildExtensions(_opts: BuildExtensionsOptions): unknown[] {
  throw new Error(
    "CodeMirror extensions not available — install @codemirror/* packages " +
      "(see wiring/code-editor-wiring.md) before calling buildExtensions(). " +
      "The pane currently uses a textarea + Shiki fallback.",
  );
}
