<script lang="ts">
  /**
   * CommitModal — inline dialog to commit worktree changes.
   * CSS prefix: cm-
   * LOC target: ≤ 140.
   */
  import type { DiffFile } from '$lib/utils/parse-diff.js';
  import { fileStatusIcon } from '$lib/utils/parse-diff.js';

  interface Props {
    open: boolean;
    files: DiffFile[];
    sessionId: string;
    onClose: () => void;
    onSuccess: () => void;
  }

  let { open, files, sessionId, onClose, onSuccess }: Props = $props();

  let message = $state('');
  let isPending = $state(false);
  let error = $state<string | null>(null);

  function handleKeydown(e: KeyboardEvent): void {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault();
      void handleCommit();
    }
    if (e.key === 'Escape') onClose();
  }

  async function handleCommit(): Promise<void> {
    if (!message.trim() || isPending) return;
    isPending = true;
    error = null;
    try {
      const res = await fetch(`http://localhost:9190/api/v1/sessions/${sessionId}/worktree/commit`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: message.trim() }),
      });
      if (!res.ok) {
        const body = (await res.json().catch(() => ({}))) as { error?: string };
        throw new Error(body.error ?? `HTTP ${res.status}`);
      }
      message = '';
      onSuccess();
      onClose();
    } catch (err) {
      error = err instanceof Error ? err.message : 'Commit failed';
    } finally {
      isPending = false;
    }
  }

  // Reset on open
  $effect(() => {
    if (!open) { message = ''; error = null; }
  });
</script>

<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
{#if open}
  <!-- Backdrop -->
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div class="cm-backdrop" onclick={onClose} role="presentation" aria-hidden="true"></div>

  <div
    class="cm-modal glass-panel"
    role="dialog"
    aria-modal="true"
    aria-label="Commit changes"
    tabindex="-1"
    onkeydown={handleKeydown}
  >
    <header class="cm-header">
      <span class="cm-title">Commit changes</span>
      <button class="cm-close" onclick={onClose} aria-label="Close">✕</button>
    </header>

    <!-- File summary (read-only) -->
    <div class="cm-files">
      {#each files as f (f.path)}
        <div class="cm-file-row">
          <span class="cm-file-icon" aria-hidden="true">{fileStatusIcon(f.status)}</span>
          <span class="cm-file-path">{f.path}</span>
          {#if !f.binary}
            <span class="cm-file-counts">
              {#if f.additions > 0}<span class="cm-add">+{f.additions}</span>{/if}
              {#if f.deletions > 0}<span class="cm-del">−{f.deletions}</span>{/if}
            </span>
          {/if}
        </div>
      {/each}
    </div>

    <!-- Message textarea -->
    <textarea
      class="cm-input"
      rows={3}
      bind:value={message}
      placeholder="feat: add login page  (Cmd+Enter to commit)"
      aria-label="Commit message"
      disabled={isPending}
    ></textarea>

    {#if error}
      <p class="cm-error" role="alert">{error}</p>
    {/if}

    <footer class="cm-footer">
      <button class="cm-cancel" onclick={onClose} disabled={isPending}>Cancel</button>
      <button
        class="cm-submit"
        onclick={() => void handleCommit()}
        disabled={isPending || !message.trim()}
        aria-label="Submit commit"
      >
        {isPending ? 'Committing…' : 'Commit'}
      </button>
    </footer>
  </div>
{/if}

<style>
  .cm-backdrop {
    position: fixed;
    inset: 0;
    background: color-mix(in oklch, var(--bg) 60%, transparent);
    z-index: 49;
  }

  .cm-modal {
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    z-index: 50;
    width: min(480px, 90vw);
    display: flex;
    flex-direction: column;
    gap: 0;
    padding: 0;
    border-radius: var(--radius-lg);
    border: 1px solid var(--border);
    background: var(--bg-elevated);
    box-shadow: 0 8px 40px color-mix(in oklch, var(--bg) 20%, transparent);
    overflow: hidden;
  }

  .cm-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-3) var(--space-4);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .cm-title {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
  }

  .cm-close {
    background: transparent;
    border: none;
    cursor: pointer;
    color: var(--fg-subtle);
    font-size: var(--text-xs);
    padding: 2px 4px;
    border-radius: var(--radius-sm);
    transition: color 0.1s ease;
  }
  .cm-close:hover { color: var(--fg); }

  .cm-files {
    max-height: 140px;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
    padding: var(--space-2) var(--space-4);
    border-bottom: 1px solid var(--border);
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .cm-file-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    min-width: 0;
  }

  .cm-file-icon {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    flex-shrink: 0;
    width: 10px;
    text-align: center;
  }

  .cm-file-path {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .cm-file-counts {
    display: flex;
    gap: 4px;
    flex-shrink: 0;
  }

  .cm-add { font-family: var(--font-mono); font-size: 10px; color: var(--success, oklch(0.72 0.18 145)); }
  .cm-del { font-family: var(--font-mono); font-size: 10px; color: var(--destructive, oklch(0.65 0.22 25)); }

  .cm-input {
    margin: var(--space-3) var(--space-4);
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    color: var(--fg);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    resize: vertical;
    outline: none;
    transition: border-color 0.1s ease;
  }
  .cm-input:focus { border-color: var(--cnp-accent, oklch(0.78 0.18 145)); }
  .cm-input:disabled { opacity: 0.5; }
  .cm-input::placeholder { color: var(--fg-subtle); }

  .cm-error {
    margin: 0 var(--space-4);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--destructive, oklch(0.65 0.22 25));
  }

  .cm-footer {
    display: flex;
    justify-content: flex-end;
    gap: var(--space-2);
    padding: var(--space-3) var(--space-4);
    border-top: 1px solid var(--border);
    flex-shrink: 0;
  }

  .cm-cancel {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-1) var(--space-3);
    cursor: pointer;
    transition: color 0.1s ease, border-color 0.1s ease;
  }
  .cm-cancel:hover:not(:disabled) { color: var(--fg); border-color: var(--fg-subtle); }
  .cm-cancel:disabled { opacity: 0.4; cursor: not-allowed; }

  .cm-submit {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--bg);
    background: var(--fg);
    border: 1px solid transparent;
    border-radius: var(--radius-md);
    padding: var(--space-1) var(--space-3);
    cursor: pointer;
    transition: opacity 0.1s ease;
  }
  .cm-submit:hover:not(:disabled) { opacity: 0.85; }
  .cm-submit:disabled { opacity: 0.35; cursor: not-allowed; }
  .cm-submit:focus-visible { outline: 2px solid var(--cnp-accent); outline-offset: 2px; }
</style>
