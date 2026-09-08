<script lang="ts">
/**
 * DocxViewer — REUSE-WRAPPER for the existing DOCX render in FilePreview.svelte.
 * CSS prefix: docxvw- (Docx Viewer Wrapper).
 *
 * Mounts the inline Phase 5 viewer (docx-preview's renderAsync). When the
 * inline impl is extracted into its own file, swap this one import.
 */
import FilePreview from '$lib/design/patterns/FilePreview.svelte';
import type { FileRecord } from '$lib/domain/files/types.js';

interface Props {
  file: FileRecord;
  workspaceSlug: string;
}

let { file, workspaceSlug }: Props = $props();
</script>

<div class="docxvw-root">
  <FilePreview {file} {workspaceSlug} />
</div>

<style>
  .docxvw-root {
    height: 100%;
    overflow: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }
</style>
