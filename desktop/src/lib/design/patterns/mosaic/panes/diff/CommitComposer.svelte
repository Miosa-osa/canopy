<script lang="ts">
  /**
   * CommitComposer — modal/inline composer for the commit message.
   *
   * Wraps the Phase-5 `CommitModal` so the Diff pane has a stable import
   * path under `mosaic/panes/diff/`. The underlying CommitModal already does
   * exactly what the spec requires: title/body textarea, file summary,
   * Cmd+Enter submit, error display, and a POST to
   * /api/v1/sessions/:id/worktree/commit (which routes to
   * Canopy.Sessions.WorktreeManager.commit/3).
   *
   * Kept as a separate component so future pane-specific composer features
   * (e.g. inline-mode below the file list, AI-suggested messages) can be
   * added here without touching the shared CommitModal.
   *
   * CSS prefix: (none — delegates entirely)
   * LOC target: ≤ 60.
   */
  import CommitModal from "$lib/design/patterns/diff/CommitModal.svelte";
  import type { DiffFile } from "$lib/domain/diff/types.js";

  interface Props {
    open: boolean;
    files: DiffFile[];
    sessionId: string;
    onClose: () => void;
    onSuccess: () => void;
  }

  let { open, files, sessionId, onClose, onSuccess }: Props = $props();
</script>

<CommitModal {open} {files} {sessionId} {onClose} {onSuccess} />
