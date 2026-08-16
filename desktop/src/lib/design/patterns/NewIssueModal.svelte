<script lang="ts">
  /**
   * NewIssueModal — create-issue dialog with Cmd/Ctrl+Enter submit.
   * CSS prefix: nim- (NewIssueModal)
   * LOC target: ≤ 200.
   */
  import type { CreateIssueBody, IssuePriority, IssueStatus } from '$lib/domain/issues/types.js';

  interface Props {
    isPending?: boolean;
    onSubmit: (body: CreateIssueBody) => void;
    onClose: () => void;
  }

  let { isPending = false, onSubmit, onClose }: Props = $props();

  let title = $state('');
  let description = $state('');
  let priority = $state<IssuePriority>(0);
  let status = $state<IssueStatus>('open');
  let assigneeType = $state<'human' | 'agent' | ''>('');
  let assigneeId = $state('');
  let labelsRaw = $state('');
  let createError = $state<string | null>(null);

  function handleSubmit(e: SubmitEvent): void {
    e.preventDefault();
    if (!title.trim()) return;
    createError = null;

    const body: CreateIssueBody = {
      title: title.trim(),
      status,
      priority,
    };

    if (description.trim()) body.description = description.trim();
    if (assigneeType && assigneeId.trim()) {
      body.assigneeType = assigneeType;
      body.assigneeId = assigneeId.trim();
    }
    if (labelsRaw.trim()) {
      body.labels = labelsRaw
        .split(',')
        .map((l) => l.trim())
        .filter(Boolean);
    }

    onSubmit(body);
  }

  function handleKeydown(e: KeyboardEvent): void {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault();
      if (title.trim() && !isPending) {
        handleSubmit(new SubmitEvent('submit', { bubbles: true, cancelable: true }));
      }
    }
    if (e.key === 'Escape') onClose();
  }

  function handleBackdropClick(e: MouseEvent): void {
    if ((e.target as HTMLElement).classList.contains('nim-backdrop')) onClose();
  }
</script>

<svelte:window onkeydown={handleKeydown} />

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="nim-backdrop" onclick={handleBackdropClick} aria-label="New issue backdrop">
  <div class="nim-modal glass-panel" role="dialog" aria-modal="true" aria-label="New issue" tabindex="-1">
    <header class="nim-header">
      <h2 class="nim-title">New issue</h2>
      <button class="nim-close btn-compact btn-compact-ghost" onclick={onClose} aria-label="Close">
        &times;
      </button>
    </header>

    <form class="nim-form" onsubmit={handleSubmit}>
      <!-- Title (required) -->
      <div class="nim-field nim-field--full">
        <label class="nim-label" for="nim-title">Title <span aria-hidden="true">*</span></label>
        <input
          id="nim-title"
          class="nim-input"
          type="text"
          bind:value={title}
          placeholder="Issue title"
          required
          autocomplete="off"
          autofocus
        />
      </div>

      <!-- Description -->
      <div class="nim-field nim-field--full">
        <label class="nim-label" for="nim-desc">Description</label>
        <textarea
          id="nim-desc"
          class="nim-input nim-textarea"
          bind:value={description}
          placeholder="Optional description"
          rows={3}
        ></textarea>
      </div>

      <!-- Grid: Status + Priority + Assignee -->
      <div class="nim-grid">
        <div class="nim-field">
          <label class="nim-label" for="nim-status">Status</label>
          <select id="nim-status" class="nim-select" bind:value={status}>
            <option value="backlog">Backlog</option>
            <option value="open">Open</option>
            <option value="in_progress">In Progress</option>
            <option value="in_review">In Review</option>
            <option value="closed">Closed</option>
          </select>
        </div>

        <div class="nim-field">
          <label class="nim-label" for="nim-priority">Priority</label>
          <select id="nim-priority" class="nim-select" bind:value={priority}>
            <option value={0}>None</option>
            <option value={1}>Low</option>
            <option value={2}>Medium</option>
            <option value={3}>High</option>
          </select>
        </div>

        <div class="nim-field">
          <label class="nim-label" for="nim-assignee-type">Assignee type</label>
          <select id="nim-assignee-type" class="nim-select" bind:value={assigneeType}>
            <option value="">Unassigned</option>
            <option value="human">Human</option>
            <option value="agent">Agent</option>
          </select>
        </div>

        {#if assigneeType}
          <div class="nim-field">
            <label class="nim-label" for="nim-assignee-id">Assignee ID / slug</label>
            <input
              id="nim-assignee-id"
              class="nim-input"
              type="text"
              bind:value={assigneeId}
              placeholder="ID or slug"
              autocomplete="off"
            />
          </div>
        {/if}

        <div class="nim-field">
          <label class="nim-label" for="nim-labels">Labels</label>
          <input
            id="nim-labels"
            class="nim-input"
            type="text"
            bind:value={labelsRaw}
            placeholder="bug, feature, …"
            autocomplete="off"
          />
        </div>
      </div>

      {#if createError}
        <p class="nim-error" role="alert">{createError}</p>
      {/if}

      <footer class="nim-footer">
        <span class="nim-hint">⌘↵ to submit</span>
        <button
          type="button"
          class="btn-pill btn-pill-secondary btn-pill-sm"
          onclick={onClose}
          disabled={isPending}
        >
          Cancel
        </button>
        <button
          type="submit"
          class="btn-pill btn-pill-primary btn-pill-sm"
          disabled={isPending || !title.trim()}
          aria-busy={isPending}
        >
          {isPending ? 'Creating…' : 'Create issue'}
        </button>
      </footer>
    </form>
  </div>
</div>

<style>
  .nim-backdrop {
    position: fixed;
    inset: 0;
    background: color-mix(in oklch, var(--bg) 40%, transparent);
    backdrop-filter: blur(4px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 900;
    padding: var(--space-4);
  }

  .nim-modal {
    width: 100%;
    max-width: 520px;
    border-radius: var(--radius-xl, 16px);
    display: flex;
    flex-direction: column;
    gap: 0;
    overflow: hidden;
    box-shadow: 0 24px 80px color-mix(in oklch, var(--bg) 0%, black 30%);
  }

  .nim-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-4) var(--space-5) var(--space-3);
    border-bottom: 1px solid var(--border);
  }

  .nim-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-base);
    font-weight: 600;
    color: var(--fg);
  }

  .nim-close {
    font-size: 18px;
    line-height: 1;
    color: var(--fg-muted);
    cursor: pointer;
  }

  .nim-form {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-4) var(--space-5);
  }

  .nim-field {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .nim-field--full { width: 100%; }

  .nim-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .nim-input,
  .nim-select {
    padding: 6px 10px;
    border-radius: var(--radius-md);
    border: 1px solid var(--border);
    background: var(--bg-inset);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    transition: border-color 0.12s ease;
    width: 100%;
  }

  .nim-input:focus,
  .nim-select:focus {
    border-color: color-mix(in oklch, var(--fg) 40%, transparent);
  }

  .nim-textarea {
    resize: vertical;
    min-height: 64px;
  }

  .nim-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
    gap: var(--space-3);
  }

  .nim-error {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--signal-error, red);
  }

  .nim-footer {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: var(--space-2);
    padding: var(--space-3) var(--space-5) var(--space-4);
    border-top: 1px solid var(--border);
  }

  .nim-hint {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    margin-right: auto;
  }
</style>
