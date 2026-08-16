/**
 * File-viewer domain types — shared by the FileViewerPane dispatcher and
 * its sub-viewers (Markdown, Code, Csv, Json, Image, Media, Log, Hex, etc.).
 *
 * The pane is universally addressable via TWO routes:
 *   1. fileId  — a row in Canopy.Files (FileRecord). Resolved through
 *      GET /api/v1/files/:id + /api/v1/files/:id/content.
 *   2. workspaceSlug + path — a path-based file inside a workspace, fetched
 *      through the existing readFile() helper at workspaceFileQuery().
 *
 * The pane manifest below is consumed by Mosaic's PaneContent dispatcher.
 */

/**
 * The 14 viewer types supported by FileViewerPane. Add to this union when a
 * new sub-viewer is introduced — the detector and the dispatcher both rely on it.
 */
export type ViewerType =
  | "markdown"
  | "code"
  | "json"
  | "yaml"
  | "csv"
  | "tsv"
  | "image"
  | "video"
  | "audio"
  | "pdf"
  | "docx"
  | "xlsx"
  | "log"
  | "text"
  | "hex"
  | "too-large"
  | "unsupported";

/**
 * Pane configuration — at least one of {fileId, (workspaceSlug + path)} must
 * be supplied. fileId takes precedence when both are present.
 */
export interface FileViewerPaneConfig {
  /** Canopy.Files row id (preferred when available — gives full metadata). */
  fileId?: string;
  /** Workspace slug — required when addressing by path. */
  workspaceSlug?: string;
  /** Path inside the workspace — required when addressing by path. */
  path?: string;
}

/**
 * Manifest entry consumed by PaneContent.svelte's dispatch and by PanePicker
 * when listing available pane types. Keep in sync with PaneKind in
 * mosaic-layout.svelte.ts.
 */
export interface FileViewerPaneManifest {
  paneType: "file_viewer";
  label: "File Viewer";
  /** Lucide icon name — caller imports the actual component. */
  icon: "FileText";
  defaultConfig: FileViewerPaneConfig;
}

/**
 * Result of detect-type resolution. Includes a hint about whether the file
 * needs a remote fetch or can be rendered from the existing FileRecord.
 */
export interface DetectedType {
  viewer: ViewerType;
  /** Best-guess Shiki language id ("typescript", "json", "elixir", ...) — undefined for non-code. */
  language?: string;
}

/** Hard cap on payload size we'll fetch for in-pane preview (50 MB). */
export const PREVIEW_SIZE_CAP_BYTES = 50 * 1024 * 1024;

/** Soft cap above which we render a hex preview rather than full content (4 KB shown). */
export const HEX_PREVIEW_BYTES = 4 * 1024;
