<script lang="ts">
/**
 * FileViewerPane — universal read-only file viewer for the Mosaic.
 * CSS prefix: fvp- (File Viewer Pane).
 *
 * Dispatches on the detected viewer type (see ./file-viewer/detect-type.ts):
 *   markdown / code / json / yaml / csv / tsv / image / video / audio /
 *   pdf / docx / xlsx / log / text / hex / too-large / unsupported.
 *
 * Addresses files via either { fileId } or { workspaceSlug, path }. Resolves
 * metadata via the existing fileQuery() (files.ts) and content via either
 * the /files/:id/content URL OR workspaceFileQuery() (workspaces.ts).
 * NO new fetch logic; consolidates the reads behind one pane interface.
 *
 * Read-only by design. Editing belongs to a CodeEditorPane (separate dispatch).
 */
import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
import { onDestroy, untrack } from 'svelte';
import { writable } from 'svelte/store';

import {
  fetchFileBytes,
  fetchFileText,
  fileContentUrl,
  fileMetadataQuery,
  isResolvable,
  workspaceFileContentsQuery,
} from '$lib/api/queries/file-viewer.js';
import { type FileViewerPaneConfig, HEX_PREVIEW_BYTES } from '$lib/domain/file-viewer/types.js';
import type { FileRecord } from '$lib/domain/files/types.js';
import type { FileReadResponse } from '$lib/domain/workspaces/types.js';
import CodeViewer from './file-viewer/CodeViewer.svelte';
import CsvTableViewer from './file-viewer/CsvTableViewer.svelte';
import DocxViewer from './file-viewer/DocxViewer.svelte';
import { detectType } from './file-viewer/detect-type.js';
import HexPreview from './file-viewer/HexPreview.svelte';
import ImageViewer from './file-viewer/ImageViewer.svelte';
import JsonTreeViewer from './file-viewer/JsonTreeViewer.svelte';
import LogViewer from './file-viewer/LogViewer.svelte';
import MarkdownViewer from './file-viewer/MarkdownViewer.svelte';
import MediaViewer from './file-viewer/MediaViewer.svelte';
import PdfViewer from './file-viewer/PdfViewer.svelte';
import XlsxViewer from './file-viewer/XlsxViewer.svelte';

// ── Props ───────────────────────────────────────────────────────────────────

interface Props {
  config: FileViewerPaneConfig;
}

let { config }: Props = $props();

// ── Resolve metadata when addressing by fileId ──────────────────────────────

const metaOptsStore = writable(
  untrack(() => fileMetadataQuery(config.fileId ?? '') as CreateQueryOptions<FileRecord>)
);
$effect(() => {
  metaOptsStore.set(fileMetadataQuery(config.fileId ?? '') as CreateQueryOptions<FileRecord>);
});
const metaQ = createQuery<FileRecord>(metaOptsStore);
const fileRecord = $derived($metaQ.data ?? null);

// ── Resolve text contents when addressing by workspace + path ───────────────

const wsOptsStore = writable(
  untrack(
    () =>
      workspaceFileContentsQuery(
        config.workspaceSlug ?? '',
        config.path ?? ''
      ) as CreateQueryOptions<FileReadResponse>
  )
);
$effect(() => {
  wsOptsStore.set(
    workspaceFileContentsQuery(
      config.workspaceSlug ?? '',
      config.path ?? ''
    ) as CreateQueryOptions<FileReadResponse>
  );
});
const wsQ = createQuery<FileReadResponse>(wsOptsStore);
const wsResponse = $derived($wsQ.data ?? null);

// ── Detected viewer type ────────────────────────────────────────────────────

/** Display name (filename or last segment of path). */
const displayName = $derived(
  fileRecord?.name ?? config.path?.split('/').filter(Boolean).pop() ?? ''
);
const displayMime = $derived(fileRecord?.mimeType ?? null);
const displaySize = $derived(fileRecord?.sizeBytes ?? wsResponse?.size ?? 0);

const detected = $derived(detectType(displayName, displayMime, displaySize));

// ── Lazy text fetch when needed (markdown / code / json / yaml / csv / log) ─

/** Cached text content. Cleared on config change. */
let fetchedText = $state<string | null>(null);
let textErr = $state<string | null>(null);
let abort: AbortController | null = null;

$effect(() => {
  // Re-fetch whenever the addressing changes.
  void config.fileId;
  void config.path;
  void config.workspaceSlug;
  void detected.viewer;

  fetchedText = null;
  textErr = null;
  abort?.abort();
  abort = null;

  const v = detected.viewer;
  const needsText =
    v === 'markdown' ||
    v === 'code' ||
    v === 'json' ||
    v === 'yaml' ||
    v === 'csv' ||
    v === 'tsv' ||
    v === 'log' ||
    v === 'text';
  if (!needsText) return;

  // Path-based: use the workspace query response.
  if (wsResponse) {
    fetchedText = wsResponse.contents;
    return;
  }

  // FileId-based: do a one-shot fetch.
  if (config.fileId) {
    abort = new AbortController();
    const ac = abort;
    fetchFileText(config.fileId, ac.signal)
      .then((t) => {
        if (!ac.signal.aborted) fetchedText = t;
      })
      .catch((err: Error) => {
        if (!ac.signal.aborted) textErr = err.message;
      });
  }
});

// ── Lazy bytes fetch for HexPreview ─────────────────────────────────────────

let hexBytes = $state<Uint8Array | null>(null);
let hexAbort: AbortController | null = null;

$effect(() => {
  void config.fileId;
  void detected.viewer;
  hexBytes = null;
  hexAbort?.abort();
  hexAbort = null;
  if (detected.viewer !== 'hex' || !config.fileId) return;
  hexAbort = new AbortController();
  const ac = hexAbort;
  fetchFileBytes(config.fileId, HEX_PREVIEW_BYTES, ac.signal)
    .then((b) => {
      if (!ac.signal.aborted) hexBytes = b;
    })
    .catch(() => {
      // Swallow — hex viewer will show "Loading…" in this rare path.
    });
});

// ── Blob URL for image / video / audio when needed ──────────────────────────

/** Direct URL for media — uses the /files/:id/content endpoint when fileId
 * is set; otherwise no media playback (path-based playback would need a
 * separate workspace media endpoint, which is out of scope here). */
const mediaUrl = $derived(config.fileId ? fileContentUrl(config.fileId) : null);

onDestroy(() => {
  abort?.abort();
  hexAbort?.abort();
});

// ── Render guards ───────────────────────────────────────────────────────────

const resolvable = $derived(isResolvable(config));

/** Whether we need a FileRecord for the chosen viewer (the three Phase 5 wrappers). */
function needsFileRecord(viewer: string): boolean {
  return viewer === 'pdf' || viewer === 'docx' || viewer === 'xlsx';
}
</script>

<div class="fvp-root">
  {#if !resolvable}
    <div class="fvp-empty">
      <p class="fvp-empty-title">No file selected</p>
      <p class="fvp-empty-hint">
        Open a file from the file tree, or pass <code>fileId</code> /
        <code>workspaceSlug + path</code> to this pane.
      </p>
    </div>

  {:else if detected.viewer === "too-large"}
    <div class="fvp-empty">
      <p class="fvp-empty-title">File too large</p>
      <p class="fvp-empty-hint">
        Preview disabled for files over 50 MB. Download to inspect locally.
      </p>
    </div>

  {:else if detected.viewer === "unsupported"}
    <div class="fvp-empty">
      <p class="fvp-empty-title">Unsupported file type</p>
      <p class="fvp-empty-hint">No preview is available for this format.</p>
    </div>

  {:else if needsFileRecord(detected.viewer) && !fileRecord}
    {#if $metaQ.isLoading}
      <div class="fvp-loading">Loading file metadata…</div>
    {:else if $metaQ.isError}
      <div class="fvp-error" role="alert">
        Failed to load file: {($metaQ.error as Error).message}
      </div>
    {:else}
      <div class="fvp-empty">
        <p class="fvp-empty-hint">
          This viewer requires a fileId — open by id, not by path.
        </p>
      </div>
    {/if}

  {:else if textErr}
    <div class="fvp-error" role="alert">{textErr}</div>

  {:else if detected.viewer === "markdown"}
    {#if fetchedText !== null}
      <MarkdownViewer content={fetchedText} />
    {:else}
      <div class="fvp-loading">Loading…</div>
    {/if}

  {:else if detected.viewer === "code"}
    {#if fetchedText !== null}
      <CodeViewer content={fetchedText} language={detected.language ?? "text"} />
    {:else}
      <div class="fvp-loading">Loading…</div>
    {/if}

  {:else if detected.viewer === "json" || detected.viewer === "yaml"}
    {#if fetchedText !== null}
      <JsonTreeViewer content={fetchedText} format={detected.viewer === "yaml" ? "yaml" : "json"} />
    {:else}
      <div class="fvp-loading">Loading…</div>
    {/if}

  {:else if detected.viewer === "csv" || detected.viewer === "tsv"}
    {#if fetchedText !== null}
      <CsvTableViewer content={fetchedText} delimiter={detected.viewer === "tsv" ? "\t" : ","} />
    {:else}
      <div class="fvp-loading">Loading…</div>
    {/if}

  {:else if detected.viewer === "log" || detected.viewer === "text"}
    {#if fetchedText !== null}
      <LogViewer content={fetchedText} initialFollow={detected.viewer === "log"} />
    {:else}
      <div class="fvp-loading">Loading…</div>
    {/if}

  {:else if detected.viewer === "image"}
    {#if mediaUrl}
      <ImageViewer src={mediaUrl} alt={displayName} />
    {:else}
      <div class="fvp-empty fvp-empty-hint">
        Image preview requires a fileId.
      </div>
    {/if}

  {:else if detected.viewer === "video" || detected.viewer === "audio"}
    {#if mediaUrl}
      <MediaViewer src={mediaUrl} kind={detected.viewer} label={displayName} />
    {:else}
      <div class="fvp-empty fvp-empty-hint">
        Media preview requires a fileId.
      </div>
    {/if}

  {:else if detected.viewer === "pdf" && fileRecord}
    <PdfViewer file={fileRecord} workspaceSlug={fileRecord.workspaceId} />

  {:else if detected.viewer === "docx" && fileRecord}
    <DocxViewer file={fileRecord} workspaceSlug={fileRecord.workspaceId} />

  {:else if detected.viewer === "xlsx" && fileRecord}
    <XlsxViewer file={fileRecord} workspaceSlug={fileRecord.workspaceId} />

  {:else if detected.viewer === "hex"}
    <HexPreview file={fileRecord} bytes={hexBytes} />
  {/if}
</div>

<style>
  .fvp-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 0;
    background: var(--bg);
    overflow: hidden;
  }

  .fvp-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100%;
    padding: var(--space-6);
    text-align: center;
    gap: var(--space-2);
  }

  .fvp-empty-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
  }

  .fvp-empty-hint {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  .fvp-loading {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100%;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    font-style: italic;
  }

  .fvp-error {
    padding: var(--space-4);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--signal-error, oklch(0.65 0.22 25));
  }
</style>
