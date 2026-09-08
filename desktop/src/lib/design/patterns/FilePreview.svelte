<script lang="ts">
/**
 * FilePreview — unified file preview dispatcher.
 * CSS prefix: fp- (FilePreview)
 *
 * Routes by MIME type (then extension fallback) to the appropriate inline viewer:
 *   PDF    → pdfjs-dist canvas render (first page)
 *   DOCX   → docx-preview renderAsync
 *   XLSX   → SheetJS sheet_to_html with sheet tabs
 *   PPTX   → unsupported message
 *   video  → <video controls>
 *   audio  → <audio controls>
 *   image  → <img>
 *   text/* + common code/config exts → fetch + plain <pre> or renderMarkdown
 *   else   → "preview not available" fallback
 *
 * Size cap: files > 50MB are not fetched — fallback shown immediately.
 * All dynamic imports are inside onMount to avoid SSR issues.
 */
import { onMount } from 'svelte';
import { API_BASE } from '$lib/api/client.js';
import type { FileRecord } from '$lib/domain/files/types.js';
import { renderMarkdown } from '$lib/utils/markdown.js';

interface Props {
  file: FileRecord;
  workspaceSlug: string;
}

let { file }: Props = $props();

// ── Constants ────────────────────────────────────────────────────────────────

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

// ── Viewer type ──────────────────────────────────────────────────────────────

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

export function resolveViewer(mime: string | null, name: string, sizeBytes: number): ViewerKind {
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

// ── State ────────────────────────────────────────────────────────────────────

const contentUrl = $derived(`${API_BASE}/files/${file.id}/content`);
const viewer = $derived(resolveViewer(file.mimeType, file.name, file.sizeBytes));

let loading = $state(false);
let errorMsg = $state<string | null>(null);

// PDF state
let pdfCanvas = $state<HTMLCanvasElement | null>(null);
let pdfTotalPages = $state(0);
let pdfCurrentPage = $state(1);
// eslint-disable-next-line @typescript-eslint/no-explicit-any
let pdfDoc = $state<any>(null);

// DOCX state
let docxContainer = $state<HTMLDivElement | null>(null);

// XLSX state
let xlsxSheets = $state<string[]>([]);
let xlsxActiveSheet = $state('');
let xlsxHtmlMap = $state<Record<string, string>>({});

// Text state
let textContent = $state('');
let isMarkdown = $state(false);

// Blob URL for media (video / audio / image)
let blobUrl = $state<string | null>(null);

// Collapse/expand
let expanded = $state(true);

// ── Mount: load content based on viewer type ─────────────────────────────────

onMount(() => {
  if (viewer === 'too-large' || viewer === 'unsupported' || viewer === 'pptx') return;

  loadContent();

  return () => {
    if (blobUrl) URL.revokeObjectURL(blobUrl);
  };
});

async function loadContent(): Promise<void> {
  loading = true;
  errorMsg = null;

  try {
    if (viewer === 'pdf') {
      await loadPdf();
    } else if (viewer === 'docx') {
      await loadDocx();
    } else if (viewer === 'xlsx') {
      await loadXlsx();
    } else if (viewer === 'text') {
      await loadText();
    } else if (viewer === 'video' || viewer === 'audio' || viewer === 'image') {
      await loadMedia();
    }
  } catch (err) {
    errorMsg = err instanceof Error ? err.message : 'Unknown error';
  } finally {
    loading = false;
  }
}

// ── PDF loader ───────────────────────────────────────────────────────────────

async function loadPdf(): Promise<void> {
  const pdfjs = await import('pdfjs-dist');
  const workerMod = await import('pdfjs-dist/build/pdf.worker.mjs?url');
  pdfjs.GlobalWorkerOptions.workerSrc = workerMod.default as string;

  const res = await fetch(contentUrl, { credentials: 'include' });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const buffer = await res.arrayBuffer();

  const doc = await pdfjs.getDocument({ data: buffer }).promise;
  pdfDoc = doc;
  pdfTotalPages = doc.numPages;
  pdfCurrentPage = 1;

  await renderPdfPage(doc, 1);
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function renderPdfPage(doc: any, pageNum: number): Promise<void> {
  if (!pdfCanvas) return;
  const page = await doc.getPage(pageNum);
  const container = pdfCanvas.parentElement;
  const maxWidth = Math.min(container?.clientWidth ?? 800, 800);
  const viewport = page.getViewport({ scale: 1 });
  const scale = maxWidth / viewport.width;
  const scaled = page.getViewport({ scale });

  pdfCanvas.width = scaled.width;
  pdfCanvas.height = scaled.height;

  const ctx = pdfCanvas.getContext('2d');
  if (!ctx) return;
  await page.render({ canvasContext: ctx, viewport: scaled }).promise;
}

async function pdfPrevPage(): Promise<void> {
  if (!pdfDoc || pdfCurrentPage <= 1) return;
  pdfCurrentPage--;
  await renderPdfPage(pdfDoc, pdfCurrentPage);
}

async function pdfNextPage(): Promise<void> {
  if (!pdfDoc || pdfCurrentPage >= pdfTotalPages) return;
  pdfCurrentPage++;
  await renderPdfPage(pdfDoc, pdfCurrentPage);
}

// ── DOCX loader ──────────────────────────────────────────────────────────────

async function loadDocx(): Promise<void> {
  const { renderAsync } = await import('docx-preview');
  const res = await fetch(contentUrl, { credentials: 'include' });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const buffer = await res.arrayBuffer();

  if (!docxContainer) throw new Error('DOCX container not ready');
  await renderAsync(buffer, docxContainer, undefined, {
    inWrapper: true,
    ignoreWidth: false,
    ignoreHeight: false,
    breakPages: true,
    renderHeaders: true,
    renderFooters: true,
    renderFootnotes: true,
    renderEndnotes: true,
  });
}

// ── XLSX loader ──────────────────────────────────────────────────────────────

const XLSX_MAX_ROWS = 200;
const XLSX_MAX_COLS = 50;

async function loadXlsx(): Promise<void> {
  const XLSX = await import('xlsx');
  const res = await fetch(contentUrl, { credentials: 'include' });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const buffer = await res.arrayBuffer();

  const wb = XLSX.read(buffer, { type: 'array' });
  xlsxSheets = wb.SheetNames;
  xlsxActiveSheet = wb.SheetNames[0] ?? '';

  const htmlMap: Record<string, string> = {};
  for (const name of wb.SheetNames) {
    const ws = wb.Sheets[name];
    // Clip to first XLSX_MAX_ROWS × XLSX_MAX_COLS
    const ref = ws['!ref'];
    if (ref) {
      const range = XLSX.utils.decode_range(ref);
      range.e.r = Math.min(range.e.r, XLSX_MAX_ROWS - 1);
      range.e.c = Math.min(range.e.c, XLSX_MAX_COLS - 1);
      ws['!ref'] = XLSX.utils.encode_range(range);
    }
    htmlMap[name] = XLSX.utils.sheet_to_html(ws);
  }
  xlsxHtmlMap = htmlMap;
}

// ── Text loader ──────────────────────────────────────────────────────────────

async function loadText(): Promise<void> {
  const res = await fetch(contentUrl, { credentials: 'include' });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  textContent = await res.text();
  isMarkdown = extOf(file.name) === 'md' || extOf(file.name) === 'markdown';
}

// ── Media loader (video / audio / image) ────────────────────────────────────

async function loadMedia(): Promise<void> {
  const res = await fetch(contentUrl, { credentials: 'include' });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const blob = await res.blob();
  blobUrl = URL.createObjectURL(blob);
}
</script>

<!-- ── Markup ──────────────────────────────────────────────────────────────── -->

<div class="fp-root">
  <!-- Toggle header -->
  <button
    class="fp-toggle"
    onclick={() => { expanded = !expanded; }}
    aria-expanded={expanded}
    aria-controls="fp-body"
  >
    <span class="fp-toggle-label">Preview</span>
    <span class="fp-toggle-chevron" class:fp-chevron-collapsed={!expanded}>
      &#8964;
    </span>
  </button>

  {#if expanded}
    <div id="fp-body" class="fp-body">

      <!-- Too large -->
      {#if viewer === 'too-large'}
        <div class="fp-fallback" role="status">
          <span class="fp-fallback-msg">File too large to preview (max 50 MB)</span>
          <a class="fp-dl-link" href={contentUrl} download={file.name}>Download</a>
        </div>

      <!-- Unsupported -->
      {:else if viewer === 'unsupported'}
        <div class="fp-fallback" role="status">
          <span class="fp-fallback-msg">Preview not available for this file type</span>
          <a class="fp-dl-link" href={contentUrl} download={file.name}>Download</a>
        </div>

      <!-- PPTX -->
      {:else if viewer === 'pptx'}
        <div class="fp-fallback" role="status">
          <span class="fp-fallback-msg">
            PowerPoint preview is not supported — open in Keynote or PowerPoint
          </span>
          <a class="fp-dl-link" href={contentUrl} download={file.name}>Download</a>
        </div>

      <!-- Error state -->
      {:else if errorMsg}
        <div class="fp-fallback fp-fallback-error" role="alert">
          <span class="fp-fallback-msg">Couldn't load preview: {errorMsg}</span>
          <a class="fp-dl-link" href={contentUrl} download={file.name}>Download</a>
        </div>

      <!-- Loading state -->
      {:else if loading}
        <div class="fp-loading" role="status" aria-label="Loading preview">
          <div class="fp-skeleton-bar fp-skeleton-bar-w60"></div>
          <div class="fp-skeleton-bar fp-skeleton-bar-w80"></div>
          <div class="fp-skeleton-bar fp-skeleton-bar-w40"></div>
          <span class="fp-loading-label">Loading preview…</span>
        </div>

      <!-- PDF viewer -->
      {:else if viewer === 'pdf'}
        <section class="fp-block fp-block-pdf" aria-label="PDF preview">
          <div class="fp-pdf-canvas-wrap">
            <canvas bind:this={pdfCanvas} class="fp-pdf-canvas" aria-label="PDF page"></canvas>
          </div>
          {#if pdfTotalPages > 1}
            <div class="fp-pdf-nav" role="navigation" aria-label="PDF page navigation">
              <button
                class="fp-nav-btn"
                onclick={pdfPrevPage}
                disabled={pdfCurrentPage <= 1}
                aria-label="Previous page"
              >&#8592;</button>
              <span class="fp-pdf-counter" aria-live="polite">
                {pdfCurrentPage} / {pdfTotalPages}
              </span>
              <button
                class="fp-nav-btn"
                onclick={pdfNextPage}
                disabled={pdfCurrentPage >= pdfTotalPages}
                aria-label="Next page"
              >&#8594;</button>
            </div>
          {/if}
        </section>

      <!-- DOCX viewer -->
      {:else if viewer === 'docx'}
        <section class="fp-block fp-block-docx" aria-label="Document preview">
          <div bind:this={docxContainer} class="fp-docx-container"></div>
        </section>

      <!-- XLSX viewer -->
      {:else if viewer === 'xlsx'}
        <section class="fp-block fp-block-xlsx" aria-label="Spreadsheet preview">
          {#if xlsxSheets.length > 1}
            <div class="fp-xlsx-tabs" role="tablist" aria-label="Sheets">
              {#each xlsxSheets as sheet (sheet)}
                <button
                  class="fp-xlsx-tab"
                  class:fp-xlsx-tab-active={sheet === xlsxActiveSheet}
                  role="tab"
                  aria-selected={sheet === xlsxActiveSheet}
                  onclick={() => { xlsxActiveSheet = sheet; }}
                >
                  {sheet}
                </button>
              {/each}
            </div>
          {/if}
          <div class="fp-xlsx-table-wrap">
            {#if xlsxHtmlMap[xlsxActiveSheet]}
              {@html xlsxHtmlMap[xlsxActiveSheet]}
            {/if}
          </div>
        </section>

      <!-- Video viewer -->
      {:else if viewer === 'video'}
        <section class="fp-block fp-block-media" aria-label="Video preview">
          {#if blobUrl}
            <!-- svelte-ignore a11y_media_has_caption -->
            <video class="fp-video" controls src={blobUrl} aria-label={file.name}></video>
          {/if}
        </section>

      <!-- Audio viewer -->
      {:else if viewer === 'audio'}
        <section class="fp-block fp-block-media" aria-label="Audio preview">
          {#if blobUrl}
            <audio class="fp-audio" controls src={blobUrl} aria-label={file.name}></audio>
          {/if}
        </section>

      <!-- Image viewer -->
      {:else if viewer === 'image'}
        <section class="fp-block fp-block-media" aria-label="Image preview">
          {#if blobUrl}
            <img class="fp-image" src={blobUrl} alt={file.name} />
          {/if}
        </section>

      <!-- Text / Markdown viewer -->
      {:else if viewer === 'text'}
        <section class="fp-block fp-block-text" aria-label="Text preview">
          {#if isMarkdown}
            <div class="fp-markdown">
              {@html renderMarkdown(textContent)}
            </div>
          {:else}
            <pre class="fp-pre"><code>{textContent}</code></pre>
          {/if}
        </section>
      {/if}

    </div>
  {/if}
</div>

<style>
  /* ── Root ─────────────────────────────────────────────────────────────────── */
  .fp-root {
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow: hidden;
    background: var(--bg);
  }

  /* ── Toggle header ────────────────────────────────────────────────────────── */
  .fp-toggle {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    padding: var(--space-2) var(--space-4);
    background: transparent;
    border: none;
    border-bottom: 1px solid var(--border);
    cursor: pointer;
    color: var(--fg-subtle);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .fp-toggle:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  .fp-toggle:focus-visible {
    outline: 2px solid var(--cnp-accent, var(--fg));
    outline-offset: -2px;
  }

  .fp-toggle-chevron {
    font-size: 1.1em;
    transition: transform var(--dur-instant) var(--ease-out);
    display: inline-block;
  }

  .fp-chevron-collapsed {
    transform: rotate(-90deg);
  }

  /* ── Body ─────────────────────────────────────────────────────────────────── */
  .fp-body {
    max-height: 600px;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  /* ── Fallback / loading states ────────────────────────────────────────────── */
  .fp-fallback {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-4) var(--space-5);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
  }

  .fp-fallback-error {
    color: var(--signal-error, #e03);
  }

  .fp-fallback-msg {
    flex: 1;
  }

  .fp-dl-link {
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg);
    text-decoration: none;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 2px var(--space-2);
    flex-shrink: 0;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .fp-dl-link:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
  }

  .fp-loading {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-5);
  }

  .fp-skeleton-bar {
    height: 12px;
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    animation: fp-pulse 1.4s ease-in-out infinite;
  }

  .fp-skeleton-bar-w60 { width: 60%; }
  .fp-skeleton-bar-w80 { width: 80%; }
  .fp-skeleton-bar-w40 { width: 40%; }

  @keyframes fp-pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.4; }
  }

  .fp-loading-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    margin-top: var(--space-1);
  }

  /* ── Block container ──────────────────────────────────────────────────────── */
  .fp-block {
    padding: var(--space-4);
  }

  /* ── PDF ──────────────────────────────────────────────────────────────────── */
  .fp-block-pdf {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-3);
  }

  .fp-pdf-canvas-wrap {
    width: 100%;
    max-width: 800px;
    overflow: hidden;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
  }

  .fp-pdf-canvas {
    display: block;
    width: 100%;
    height: auto;
  }

  .fp-pdf-nav {
    display: flex;
    align-items: center;
    gap: var(--space-3);
  }

  .fp-nav-btn {
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    color: var(--fg);
    font-size: var(--text-sm);
    padding: 2px var(--space-2);
    cursor: pointer;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .fp-nav-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
  }

  .fp-nav-btn:disabled {
    color: var(--fg-subtle);
    cursor: default;
  }

  .fp-nav-btn:focus-visible {
    outline: 2px solid var(--cnp-accent, var(--fg));
    outline-offset: 2px;
  }

  .fp-pdf-counter {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  /* ── DOCX ─────────────────────────────────────────────────────────────────── */
  .fp-block-docx {
    padding: var(--space-2);
  }

  .fp-docx-container {
    color: var(--fg);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    /* Override docx-preview print margins */
    --docx-padding: var(--space-4);
  }

  /* Strip docx-preview wrapper margin artifacts */
  .fp-docx-container :global(.docx-wrapper) {
    padding: 0;
    background: transparent;
  }

  .fp-docx-container :global(.docx) {
    margin: 0 auto;
    padding: var(--space-4);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    box-shadow: none;
    color: var(--fg);
  }

  .fp-docx-container :global(table) {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    border-collapse: collapse;
    width: 100%;
  }

  .fp-docx-container :global(td),
  .fp-docx-container :global(th) {
    border: 1px solid var(--border);
    padding: 2px var(--space-2);
  }

  /* ── XLSX ─────────────────────────────────────────────────────────────────── */
  .fp-block-xlsx {
    padding: var(--space-3);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .fp-xlsx-tabs {
    display: flex;
    gap: var(--space-1);
    flex-wrap: wrap;
  }

  .fp-xlsx-tab {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    padding: 2px var(--space-2);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: transparent;
    color: var(--fg-muted);
    cursor: pointer;
    transition: background var(--dur-instant) var(--ease-out), color var(--dur-instant) var(--ease-out);
  }

  .fp-xlsx-tab:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .fp-xlsx-tab-active {
    background: color-mix(in oklch, var(--cnp-accent, var(--fg)) 12%, transparent 88%);
    border-color: var(--cnp-accent, var(--fg));
    color: var(--fg);
  }

  .fp-xlsx-tab:focus-visible {
    outline: 2px solid var(--cnp-accent, var(--fg));
    outline-offset: 2px;
  }

  .fp-xlsx-table-wrap {
    overflow-x: auto;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .fp-xlsx-table-wrap :global(table) {
    border-collapse: collapse;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg);
    min-width: 100%;
  }

  .fp-xlsx-table-wrap :global(td),
  .fp-xlsx-table-wrap :global(th) {
    border: 1px solid var(--border);
    padding: 2px var(--space-2);
    white-space: nowrap;
  }

  .fp-xlsx-table-wrap :global(tr:nth-child(even)) {
    background: color-mix(in oklch, var(--fg) 3%, transparent 97%);
  }

  /* ── Media: video / audio / image ─────────────────────────────────────────── */
  .fp-block-media {
    display: flex;
    justify-content: center;
    align-items: flex-start;
  }

  .fp-video {
    width: 100%;
    max-width: 800px;
    border-radius: var(--radius-sm);
    background: #000;
  }

  .fp-audio {
    width: 100%;
    max-width: 600px;
  }

  .fp-image {
    width: 100%;
    max-width: 800px;
    display: block;
    border-radius: var(--radius-sm);
    object-fit: contain;
  }

  /* ── Text / Markdown ──────────────────────────────────────────────────────── */
  .fp-block-text {
    padding: var(--space-4);
  }

  .fp-pre {
    margin: 0;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg);
    white-space: pre-wrap;
    word-break: break-word;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: var(--space-3);
    overflow-x: auto;
  }

  .fp-markdown {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    line-height: 1.6;
  }

  /* Markdown element styles (matching fv- tokens from FileViewer) */
  .fp-markdown :global(h1),
  .fp-markdown :global(.fv-h1) {
    font-size: var(--text-xl);
    font-weight: 700;
    margin: var(--space-3) 0 var(--space-2);
    color: var(--fg);
  }

  .fp-markdown :global(h2),
  .fp-markdown :global(.fv-h2) {
    font-size: var(--text-lg);
    font-weight: 600;
    margin: var(--space-3) 0 var(--space-2);
    color: var(--fg);
  }

  .fp-markdown :global(h3),
  .fp-markdown :global(.fv-h3) {
    font-size: var(--text-base);
    font-weight: 600;
    margin: var(--space-2) 0 var(--space-1);
    color: var(--fg);
  }

  .fp-markdown :global(p),
  .fp-markdown :global(.fv-p) {
    margin: 0 0 var(--space-2);
  }

  .fp-markdown :global(pre),
  .fp-markdown :global(.fv-code-block) {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: var(--space-2) var(--space-3);
    overflow-x: auto;
    margin: var(--space-2) 0;
  }

  .fp-markdown :global(code),
  .fp-markdown :global(.fv-inline-code) {
    font-family: var(--font-mono);
    font-size: 0.9em;
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    padding: 1px 4px;
    border-radius: 3px;
  }

  .fp-markdown :global(a),
  .fp-markdown :global(.fv-link) {
    color: var(--cnp-accent, var(--fg));
    text-decoration: underline;
  }

  .fp-markdown :global(ul),
  .fp-markdown :global(.fv-ul) {
    padding-left: var(--space-4);
    margin: var(--space-1) 0;
  }

  .fp-markdown :global(ol),
  .fp-markdown :global(.fv-ol) {
    padding-left: var(--space-4);
    margin: var(--space-1) 0;
  }
</style>
