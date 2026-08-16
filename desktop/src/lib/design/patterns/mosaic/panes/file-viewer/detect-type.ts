/**
 * detect-type — pure function: (extension, mime, sizeBytes?) → ViewerType.
 *
 * Resolution order:
 *   1. Size cap → "too-large"          (caller may downgrade further)
 *   2. MIME type prefix matches        (image/*, video/*, audio/*, application/pdf, ...)
 *   3. Extension lookup tables          (markdown, json, yaml, csv, tsv, log, code)
 *   4. Generic text/* MIME              → "text"
 *   5. Fallback                         → "hex"  (binary preview)
 *
 * Pure: no side effects, no DOM, no network. Safe to test in isolation.
 *
 * NOTE: keep this file dependency-free so the test runs without bundling Svelte.
 */

import {
  PREVIEW_SIZE_CAP_BYTES,
  type DetectedType,
  type ViewerType,
} from "$lib/domain/file-viewer/types.js";

// ── Lookup tables ───────────────────────────────────────────────────────────

/** Markdown / Tiptap render. */
const MARKDOWN_EXTS = new Set(["md", "markdown", "mdx"]);

/** JSON family — separate viewer with collapsible tree. */
const JSON_EXTS = new Set(["json", "jsonc", "json5", "geojson", "ndjson"]);

/** YAML family — also rendered through JsonTreeViewer (parsed via dynamic import). */
const YAML_EXTS = new Set(["yaml", "yml"]);

/** Tabular — sortable table viewer. */
const CSV_EXTS = new Set(["csv"]);
const TSV_EXTS = new Set(["tsv", "tab"]);

/** Tail-able text — line-numbered, mono, follow-tail toggle. */
const LOG_EXTS = new Set(["log", "out", "err"]);

/** Image — native <img>. SVG goes here too (renders as <img> without script execution). */
const IMAGE_EXTS = new Set([
  "png",
  "jpg",
  "jpeg",
  "gif",
  "webp",
  "svg",
  "bmp",
  "ico",
  "avif",
]);

/** Audio — native <audio>. */
const AUDIO_EXTS = new Set([
  "mp3",
  "wav",
  "ogg",
  "flac",
  "m4a",
  "aac",
  "opus",
  "weba",
]);

/** Video — native <video>. */
const VIDEO_EXTS = new Set(["mp4", "mov", "webm", "mkv", "avi", "m4v", "ogv"]);

/** Office docs — reuse existing PDF / DOCX / XLSX viewers from FilePreview. */
const PDF_EXTS = new Set(["pdf"]);
const DOCX_EXTS = new Set(["docx", "doc"]);
const XLSX_EXTS = new Set(["xlsx", "xls"]);

/**
 * Code → Shiki language mapping. The keys are lowercase extensions (no leading dot).
 * Languages absent from this map fall back to the "code" viewer with plain text.
 */
const CODE_LANG_MAP: Record<string, string> = {
  ts: "typescript",
  tsx: "tsx",
  mts: "typescript",
  cts: "typescript",
  js: "javascript",
  jsx: "jsx",
  mjs: "javascript",
  cjs: "javascript",
  svelte: "svelte",
  vue: "vue",
  ex: "elixir",
  exs: "elixir",
  rs: "rust",
  go: "go",
  py: "python",
  rb: "ruby",
  java: "java",
  kt: "kotlin",
  swift: "swift",
  c: "c",
  h: "c",
  cpp: "cpp",
  cc: "cpp",
  hpp: "cpp",
  cs: "csharp",
  php: "php",
  sh: "bash",
  bash: "bash",
  zsh: "bash",
  fish: "fish",
  ps1: "powershell",
  sql: "sql",
  toml: "toml",
  ini: "ini",
  env: "ini",
  dockerfile: "docker",
  html: "html",
  htm: "html",
  xml: "xml",
  css: "css",
  scss: "scss",
  less: "less",
  graphql: "graphql",
  gql: "graphql",
  proto: "proto",
  lua: "lua",
  hs: "haskell",
  clj: "clojure",
  cljs: "clojure",
  scala: "scala",
  r: "r",
  jl: "julia",
  zig: "zig",
  nix: "nix",
};

/** Plain-text-ish extensions that aren't code but should render as monospaced text. */
const TEXT_EXTS = new Set(["txt", "text", "rtf"]);

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Lowercase extension, sans dot. Returns "" when there is no extension. */
export function extractExtension(name: string): string {
  const lower = name.toLowerCase();
  // Special-case Dockerfile / Makefile (no extension, but well-known).
  if (lower === "dockerfile" || lower.endsWith("/dockerfile"))
    return "dockerfile";
  if (lower === "makefile" || lower.endsWith("/makefile")) return "makefile";
  const dot = lower.lastIndexOf(".");
  if (dot === -1) return "";
  return lower.slice(dot + 1);
}

// ── Public API ───────────────────────────────────────────────────────────────

/**
 * Detect the appropriate viewer for a file given its name, optional MIME type,
 * and optional size in bytes.
 *
 * - When size exceeds PREVIEW_SIZE_CAP_BYTES, returns viewer="too-large".
 * - MIME type takes precedence over extension when both agree on a family.
 * - Falls back to "hex" for binary content with no recognised signal.
 */
export function detectType(
  name: string,
  mime: string | null | undefined,
  sizeBytes?: number,
): DetectedType {
  if (typeof sizeBytes === "number" && sizeBytes > PREVIEW_SIZE_CAP_BYTES) {
    return { viewer: "too-large" };
  }

  const ext = extractExtension(name);
  const m = (mime ?? "").toLowerCase().trim();

  // ── 1. MIME prefix matches (most reliable when present) ────────────────────
  if (m === "application/pdf" || ext === "pdf" || PDF_EXTS.has(ext)) {
    return { viewer: "pdf" };
  }
  if (
    m ===
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" ||
    m === "application/msword" ||
    DOCX_EXTS.has(ext)
  ) {
    return { viewer: "docx" };
  }
  if (
    m === "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" ||
    m === "application/vnd.ms-excel" ||
    XLSX_EXTS.has(ext)
  ) {
    return { viewer: "xlsx" };
  }
  if (m.startsWith("video/") || VIDEO_EXTS.has(ext)) {
    return { viewer: "video" };
  }
  if (m.startsWith("audio/") || AUDIO_EXTS.has(ext)) {
    return { viewer: "audio" };
  }
  if (m.startsWith("image/") || IMAGE_EXTS.has(ext)) {
    return { viewer: "image" };
  }

  // ── 2. Extension-based text-like routes ────────────────────────────────────
  if (MARKDOWN_EXTS.has(ext)) return { viewer: "markdown" };
  if (JSON_EXTS.has(ext) || m === "application/json") {
    return { viewer: "json", language: "json" };
  }
  if (YAML_EXTS.has(ext) || m === "application/x-yaml" || m === "text/yaml") {
    return { viewer: "yaml", language: "yaml" };
  }
  if (CSV_EXTS.has(ext) || m === "text/csv") return { viewer: "csv" };
  if (TSV_EXTS.has(ext) || m === "text/tab-separated-values") {
    return { viewer: "tsv" };
  }
  if (LOG_EXTS.has(ext)) return { viewer: "log" };

  // ── 3. Code (Shiki) ────────────────────────────────────────────────────────
  if (ext in CODE_LANG_MAP) {
    return { viewer: "code", language: CODE_LANG_MAP[ext] };
  }

  // ── 4. Generic text fallbacks ──────────────────────────────────────────────
  if (TEXT_EXTS.has(ext) || m.startsWith("text/")) {
    return { viewer: "text" };
  }

  // ── 5. Binary fallback ─────────────────────────────────────────────────────
  return { viewer: "hex" };
}

/** Re-export so callers can do `import { type ViewerType } from "./detect-type.js"`. */
export type { ViewerType };
