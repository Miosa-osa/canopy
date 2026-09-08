/**
 * Code-editor domain types — shared by CodeEditorPane and its helpers.
 *
 * The pane addresses files via TWO routes (matching FileViewerPane):
 *   1. fileId  — a row in Canopy.Files. Resolved through GET /api/v1/files/:id.
 *      Save still flows through the workspace-scoped endpoint because the
 *      `/files/:id` PATCH endpoint only accepts tag updates today.
 *   2. workspaceSlug + path — a path-based file inside a workspace, fetched
 *      and saved via /api/v1/workspaces/:slug/files/*path.
 *
 * NO new fetcher is introduced — this file only declares contracts.
 */

import type { ViewerType } from '$lib/domain/file-viewer/types.js';

/**
 * The set of languages CodeEditorPane will syntax-highlight when CodeMirror
 * lands. Until then, the textarea fallback uses Shiki for read-only
 * highlighting (already present in the repo at ^4.0.2).
 */
export type CodeLanguage =
  | 'javascript'
  | 'typescript'
  | 'tsx'
  | 'jsx'
  | 'elixir'
  | 'rust'
  | 'python'
  | 'json'
  | 'markdown'
  | 'svelte'
  | 'yaml'
  | 'go'
  | 'html'
  | 'css'
  | 'bash'
  | 'sql'
  | 'toml'
  | 'text';

/** Pane configuration — at least one of {fileId, (workspaceSlug + path)} must be set. */
export interface CodeEditorPaneConfig {
  /** Canopy.Files row id (preferred when available — gives full metadata). */
  fileId?: string;
  /** Workspace slug — required when addressing by path or for save. */
  workspaceSlug?: string;
  /** Path inside the workspace — required when addressing by path. */
  path?: string;
}

/**
 * Manifest entry consumed by PaneContent.svelte's dispatcher and PanePicker.
 * Keep `paneType` + `icon` in sync with mosaic-layout.svelte.ts and the
 * PanePicker catalog.
 */
export interface CodeEditorPaneManifest {
  paneType: 'code_editor';
  label: 'Code Editor';
  /** Lucide icon name — caller imports the actual component. */
  icon: 'Code';
  defaultConfig: CodeEditorPaneConfig;
  configSchema: {
    fileId: { type: 'string'; required: false };
    workspaceSlug: { type: 'string'; required: false };
    path: { type: 'string'; required: false };
  };
}

/** Hard cap on payload size we'll fetch into the editor (5 MB — bigger files use the FileViewer hex preview). */
export const EDIT_SIZE_CAP_BYTES = 5 * 1024 * 1024;

/**
 * Map a file extension to a CodeLanguage. Used by the Shiki overlay and (when
 * CodeMirror lands) by the language-pack switcher in extensions.ts.
 */
export function languageFromExtension(extension: string | null): CodeLanguage {
  if (!extension) return 'text';
  const ext = extension.toLowerCase();
  const map: Record<string, CodeLanguage> = {
    ts: 'typescript',
    tsx: 'tsx',
    js: 'javascript',
    jsx: 'jsx',
    mjs: 'javascript',
    cjs: 'javascript',
    ex: 'elixir',
    exs: 'elixir',
    eex: 'elixir',
    rs: 'rust',
    py: 'python',
    json: 'json',
    md: 'markdown',
    mdx: 'markdown',
    svelte: 'svelte',
    yaml: 'yaml',
    yml: 'yaml',
    go: 'go',
    html: 'html',
    htm: 'html',
    css: 'css',
    scss: 'css',
    sh: 'bash',
    bash: 'bash',
    zsh: 'bash',
    sql: 'sql',
    toml: 'toml',
  };
  return map[ext] ?? 'text';
}

/** Convenience for the FileViewer's detect-type bridge — code editor is only relevant for "code". */
export function isCodeViewerType(viewer: ViewerType): boolean {
  return viewer === 'code' || viewer === 'json' || viewer === 'yaml';
}

/** Body for our save-content mutation — singular `content` matches the backend contract. */
export interface CodeEditorSaveBody {
  /** Singular `content` — matches `params["content"]` in WorkspaceFilesController. */
  content: string;
}

/** Result of a save round-trip — surfaces enough for the UI to roll back on error. */
export interface CodeEditorSaveResult {
  path: string;
  written: true;
  /** Content that was just successfully saved — used as the new "last saved" baseline. */
  savedContent: string;
}
