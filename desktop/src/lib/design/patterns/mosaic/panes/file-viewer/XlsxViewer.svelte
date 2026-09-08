<script lang="ts">
/**
 * XlsxViewer — REUSE-WRAPPER for the existing XLSX render in FilePreview.svelte.
 * CSS prefix: xlsxvw- (Xlsx Viewer Wrapper).
 *
 * Mounts the inline Phase 5 viewer (SheetJS sheet_to_html with sheet tabs).
 * When the inline impl is extracted into its own file, swap this one import.
 */
import FilePreview from '$lib/design/patterns/FilePreview.svelte';
import type { FileRecord } from '$lib/domain/files/types.js';

interface Props {
  file: FileRecord;
  workspaceSlug: string;
}

let { file, workspaceSlug }: Props = $props();
</script>

<div class="xlsxvw-root">
  <FilePreview {file} {workspaceSlug} />
</div>

<style>
  .xlsxvw-root {
    height: 100%;
    overflow: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }
</style>
