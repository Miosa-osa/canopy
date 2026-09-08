<script lang="ts">
/**
 * Hunk — action toolbar for a single hunk.
 *
 * Pure UI: renders the hunk header label and Keep / Discard / Stage buttons.
 * Mutations (discardHunk / stageFile) are wired by the parent — this stays
 * dumb so it can be reused for either session-worktree or future ref-mode diffs.
 *
 * Line-by-line rendering is delegated to the upstream DiffViewer. This file
 * only owns the action bar; it does not duplicate hunk parsing or rendering.
 *
 * CSS prefix: hk-
 * LOC target: ≤ 180.
 */
import type { DiffHunk } from '$lib/domain/diff/types.js';
import { changedLineCount } from './parse-hunks.js';

interface Props {
  hunk: DiffHunk;
  /** When true, Discard is disabled and shows a spinner. */
  isDiscarding?: boolean;
  /** When true, Stage is disabled and shows a spinner. */
  isStaging?: boolean;
  /** When true, this hunk is "kept" (UI hint). */
  isKept?: boolean;
  /** Hide Stage button when not in a context that supports per-file staging. */
  showStage?: boolean;
  onKeep: (hunk: DiffHunk) => void;
  onDiscard: (hunk: DiffHunk) => void;
  onStage: (hunk: DiffHunk) => void;
}

let {
  hunk,
  isDiscarding = false,
  isStaging = false,
  isKept = false,
  showStage = true,
  onKeep,
  onDiscard,
  onStage,
}: Props = $props();

const lineCount = $derived(changedLineCount(hunk));
</script>

<div class="hk-bar" class:hk-bar--kept={isKept}>
  <div class="hk-meta">
    <span class="hk-header" title={hunk.header}>{hunk.header}</span>
    <span class="hk-count">{lineCount} change{lineCount === 1 ? "" : "s"}</span>
  </div>

  <div class="hk-actions" role="group" aria-label="Hunk actions">
    <button
      class="hk-btn hk-btn--keep"
      class:hk-btn--active={isKept}
      onclick={() => onKeep(hunk)}
      aria-label="Keep this hunk"
      aria-pressed={isKept}
      title="Keep hunk"
    >
      Keep
    </button>
    <button
      class="hk-btn hk-btn--discard"
      onclick={() => onDiscard(hunk)}
      disabled={isDiscarding}
      aria-label="Discard this hunk"
      title="Reverts the hunk in the working tree"
    >
      {isDiscarding ? "Discarding…" : "Discard"}
    </button>
    {#if showStage}
      <button
        class="hk-btn hk-btn--stage"
        onclick={() => onStage(hunk)}
        disabled={isStaging}
        aria-label="Stage this hunk"
        title="git add for the file containing this hunk"
      >
        {isStaging ? "Staging…" : "Stage"}
      </button>
    {/if}
  </div>
</div>

<style>
  .hk-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-2);
    padding: 4px var(--space-3);
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    border-top: 1px solid var(--border);
    border-bottom: 1px solid var(--border);
    min-height: 26px;
  }

  .hk-bar--kept {
    background: color-mix(in oklch, var(--success, oklch(0.72 0.18 145)) 8%, transparent);
  }

  .hk-meta {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex: 1;
    min-width: 0;
  }

  .hk-header {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .hk-count {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  .hk-actions {
    display: flex;
    gap: 4px;
    flex-shrink: 0;
  }

  .hk-btn {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 500;
    color: var(--fg-muted);
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 2px 8px;
    cursor: pointer;
    transition: color 0.1s ease, background 0.1s ease, border-color 0.1s ease;
  }
  .hk-btn:hover:not(:disabled) {
    color: var(--fg);
    border-color: var(--fg-subtle);
  }
  .hk-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }
  .hk-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .hk-btn--keep.hk-btn--active {
    color: var(--success, oklch(0.72 0.18 145));
    border-color: color-mix(in oklch, var(--success, oklch(0.72 0.18 145)) 50%, transparent);
    background: color-mix(in oklch, var(--success, oklch(0.72 0.18 145)) 10%, transparent);
  }

  .hk-btn--discard:hover:not(:disabled) {
    color: var(--destructive, oklch(0.65 0.22 25));
    border-color: color-mix(in oklch, var(--destructive, oklch(0.65 0.22 25)) 50%, transparent);
  }

  .hk-btn--stage:hover:not(:disabled) {
    color: var(--cnp-accent, oklch(0.78 0.18 145));
    border-color: color-mix(in oklch, var(--cnp-accent, oklch(0.78 0.18 145)) 50%, transparent);
  }
</style>
