/**
 * save-state.svelte.ts — dirty tracking for the Code Editor pane.
 *
 * Single responsibility: hold the last-saved baseline + the working draft, and
 * derive `isDirty` from their inequality. Persistence and network I/O live in
 * CodeEditorPane.svelte and queries/code-editor.ts respectively.
 *
 * Pattern: class-based Svelte 5 runes store (matches lib/stores/toasts.svelte.ts).
 *   - $state for reactive primitives
 *   - $derived for computed values
 *   - No external store contract — the pane instantiates one per pane id.
 *
 * The class is intentionally framework-light so the unit tests can run under
 * Vitest without mounting Svelte components.
 */

// ── Pure helpers (extracted so they're independently testable in Node) ──────

/**
 * Pure-function dirty check. Independent of any rune context — used both by
 * the class below and by Vitest unit tests that can't host the Svelte
 * compiler. Newline normalization is intentional: a backend-supplied "\n"
 * baseline must not be marked dirty against an editor draft that auto-LF'd
 * a CRLF user paste.
 */
export function computeDirty(baseline: string, draft: string): boolean {
  return normalizeNewlines(draft) !== normalizeNewlines(baseline);
}

/** Normalize CRLF and lone CR to LF — matches what the textarea will emit. */
export function normalizeNewlines(s: string): string {
  return s.replace(/\r\n?/g, '\n');
}

/**
 * Format a "dirty marker" prefix for the pane title — `•` when dirty, empty
 * otherwise. Pulled out as a tiny pure helper for the unit test.
 */
export function dirtyTitleMarker(isDirty: boolean): string {
  return isDirty ? '• ' : '';
}

export interface SaveStateSnapshot {
  /** The last value that was successfully persisted to the backend. */
  baseline: string;
  /** The current in-memory buffer (what the user sees). */
  draft: string;
  /** Derived — true when draft !== baseline. */
  isDirty: boolean;
  /** ISO timestamp of the last successful save (or null when never saved). */
  lastSavedAt: string | null;
}

export class CodeEditorSaveState {
  /** Last-saved content (the rollback target on failed save). */
  baseline = $state<string>('');

  /** Current editor buffer. Mutated as the user types. */
  draft = $state<string>('');

  /** ISO timestamp of last successful save — null if never saved. */
  lastSavedAt = $state<string | null>(null);

  /** Derived dirty flag — recomputes whenever baseline or draft changes. */
  isDirty = $derived(computeDirty(this.baseline, this.draft));

  constructor(initial = '') {
    this.baseline = initial;
    this.draft = initial;
  }

  /** Replace the editor buffer (e.g. user typed). Does NOT touch the baseline. */
  setDraft(next: string): void {
    this.draft = next;
  }

  /**
   * Reset the baseline AND draft to a freshly-loaded value. Use when the
   * source-of-truth changes externally (file reload, pane re-init).
   */
  loadFromRemote(content: string): void {
    this.baseline = content;
    this.draft = content;
  }

  /**
   * Mark the current draft as the new baseline — call this on a successful
   * save round-trip. After this, isDirty becomes false until the next edit.
   */
  markSaved(savedContent: string, at: Date = new Date()): void {
    this.baseline = savedContent;
    // Don't blindly overwrite draft — the user may have typed during the save.
    // If their post-save draft equals what we sent, keep the buffer; otherwise
    // they have new edits that should remain dirty against the new baseline.
    this.lastSavedAt = at.toISOString();
  }

  /**
   * Roll back the draft to the baseline. Used when a save fails and the UI
   * surfaces an explicit revert action; not called automatically because
   * losing user input on a network blip is destructive.
   */
  revertToBaseline(): void {
    this.draft = this.baseline;
  }

  /** Snapshot — useful for tests and pane-close warnings. */
  snapshot(): SaveStateSnapshot {
    return {
      baseline: this.baseline,
      draft: this.draft,
      isDirty: this.isDirty,
      lastSavedAt: this.lastSavedAt,
    };
  }
}

/**
 * Factory for ergonomic single-line construction in Svelte components.
 *   const save = createSaveState(remoteContent);
 */
export function createSaveState(initial = ''): CodeEditorSaveState {
  return new CodeEditorSaveState(initial);
}
