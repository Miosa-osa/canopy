<script lang="ts">
/**
 * PdfViewer — REUSE-WRAPPER for the existing PDF render in FilePreview.svelte.
 * CSS prefix: pdfvw- (Pdf Viewer Wrapper).
 *
 * The Phase 5 PDF viewer is currently inline inside
 * `desktop/src/lib/design/patterns/FilePreview.svelte` (resolveViewer →
 * 'pdf' branch). We do NOT reimplement pdfjs-dist here — we mount that
 * component directly. When the inline impl is extracted into its own
 * file, swap this one import; nothing else changes.
 */
import FilePreview from '$lib/design/patterns/FilePreview.svelte';
import type { FileRecord } from '$lib/domain/files/types.js';

interface Props {
  file: FileRecord;
  workspaceSlug: string;
}

let { file, workspaceSlug }: Props = $props();
</script>

<div class="pdfvw-root">
  <FilePreview {file} {workspaceSlug} />
</div>

<style>
  .pdfvw-root {
    height: 100%;
    overflow: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }
</style>
