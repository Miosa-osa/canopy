<script lang="ts">
/**
 * FileList — diff-pane file sidebar.
 *
 * Thin wrapper around the Phase-5 `ChangesFileList` so the Diff pane has a
 * stable import path under `mosaic/panes/diff/`. No new logic — same props,
 * same behavior. This keeps a single source of truth for the file list UI.
 *
 * If FileList ever needs pane-specific behavior (e.g. multi-select for
 * batch staging), add it here without touching ChangesFileList.
 *
 * CSS prefix: (none — delegates entirely)
 * LOC target: ≤ 60.
 */
import ChangesFileList from '$lib/design/patterns/diff/ChangesFileList.svelte';
import type { DiffFile } from '$lib/domain/diff/types.js';

interface Props {
  files: DiffFile[];
  activeFile: DiffFile | null;
  onSelect: (file: DiffFile) => void;
  onCommit: () => void;
}

let { files, activeFile, onSelect, onCommit }: Props = $props();
</script>

<ChangesFileList {files} {activeFile} {onSelect} {onCommit} />
