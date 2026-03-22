<!-- src/lib/components/issues/IssueForm.svelte -->
<!-- Create/edit issue modal form -->
<script lang="ts">
  import type { Issue, IssueStatus, IssuePriority } from '$api/types';
  import { agentsStore } from '$lib/stores/agents.svelte';

  interface Props {
    issue?: Issue;
    onSubmit: (data: Partial<Issue>) => void;
    onCancel: () => void;
  }

  let { issue, onSubmit, onCancel }: Props = $props();

  let title = $state(issue?.title ?? '');
  let description = $state(issue?.description ?? '');
  let priority = $state<IssuePriority>(issue?.priority ?? 'medium');
  let status = $state<IssueStatus>(issue?.status ?? 'todo');
  let assigneeId = $state(issue?.assignee_id ?? '');
  let labelsRaw = $state(issue?.labels.join(', ') ?? '');

  let titleError = $state('');
  let submitting = $state(false);

  function validate(): boolean {
    titleError = '';
    if (!title.trim()) {
      titleError = 'Title is required.';
      return false;
    }
    if (title.length > 200) {
      titleError = 'Title must be 200 characters or less.';
      return false;
    }
    return true;
  }

  async function handleSubmit(e: SubmitEvent) {
    e.preventDefault();
    if (!validate()) return;
    submitting = true;
    const labels = labelsRaw
      .split(',')
      .map(l => l.trim())
      .filter(Boolean);
    const assignee = agentsStore.agents.find(a => a.id === assigneeId);
    const data: Partial<Issue> = {
      title: title.trim(),
      description: description.trim() || null,
      priority,
      status,
      assignee_id: assigneeId || null,
      assignee_name: assignee?.display_name ?? null,
      labels,
    };
    try {
      await onSubmit(data);
    } finally {
      submitting = false;
    }
  }

  const PRIORITIES: IssuePriority[] = ['low', 'medium', 'high', 'critical'];
  const STATUSES: { value: IssueStatus; label: string }[] = [
    { value: 'backlog',     label: 'Backlog'     },
    { value: 'todo',        label: 'Todo'        },
    { value: 'in_progress', label: 'In Progress' },
    { value: 'in_review',   label: 'In Review'   },
    { value: 'done',        label: 'Done'        },
  ];

  const PRIORITY_COLORS: Record<string, string> = {
    low: '#3b82f6', medium: '#f59e0b', high: '#f97316', critical: '#ef4444',
  };
</script>

<!-- Backdrop -->
<div
  class="if-backdrop"
  role="presentation"
  onclick={onCancel}
  onkeydown={(e) => e.key === 'Escape' && onCancel()}
  aria-hidden="true"
></div>

<!-- Modal -->
<div
  class="if-modal"
  role="dialog"
  aria-modal="true"
  aria-label={issue ? 'Edit issue' : 'Create new issue'}
>
  <header class="if-header">
    <h2 class="if-title">{issue ? 'Edit Issue' : 'New Issue'}</h2>
    <button
      class="if-close"
      onclick={onCancel}
      aria-label="Close dialog"
      type="button"
    >
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
        <path d="M18 6L6 18M6 6l12 12" />
      </svg>
    </button>
  </header>

  <form class="if-form" onsubmit={handleSubmit} novalidate>
    <!-- Title -->
    <div class="if-field">
      <label class="if-label" for="if-title">Title <span class="if-required" aria-label="required">*</span></label>
      <input
        id="if-title"
        class="if-input"
        class:if-input--error={!!titleError}
        type="text"
        placeholder="Issue title..."
        bind:value={title}
        maxlength={200}
        aria-required="true"
        aria-describedby={titleError ? 'if-title-error' : undefined}
        autocomplete="off"
      />
      {#if titleError}
        <span id="if-title-error" class="if-error" role="alert">{titleError}</span>
      {/if}
    </div>

    <!-- Description -->
    <div class="if-field">
      <label class="if-label" for="if-desc">Description</label>
      <textarea
        id="if-desc"
        class="if-textarea"
        placeholder="Describe the issue (supports markdown)..."
        bind:value={description}
        rows={5}
        maxlength={2000}
        aria-describedby="if-desc-hint"
      ></textarea>
      <span id="if-desc-hint" class="if-hint">Markdown supported · {description.length}/2000</span>
    </div>

    <!-- Priority + Status row -->
    <div class="if-row">
      <div class="if-field">
        <label class="if-label" for="if-priority">Priority</label>
        <select id="if-priority" class="if-select" bind:value={priority} aria-label="Select priority">
          {#each PRIORITIES as p (p)}
            <option value={p} style="color: {PRIORITY_COLORS[p]}">{p.charAt(0).toUpperCase() + p.slice(1)}</option>
          {/each}
        </select>
      </div>

      <div class="if-field">
        <label class="if-label" for="if-status">Status</label>
        <select id="if-status" class="if-select" bind:value={status} aria-label="Select status">
          {#each STATUSES as s (s.value)}
            <option value={s.value}>{s.label}</option>
          {/each}
        </select>
      </div>
    </div>

    <!-- Assignee -->
    <div class="if-field">
      <label class="if-label" for="if-assignee">Assignee</label>
      <select id="if-assignee" class="if-select" bind:value={assigneeId} aria-label="Select assignee">
        <option value="">Unassigned</option>
        {#each agentsStore.agents as agent (agent.id)}
          <option value={agent.id}>{agent.display_name} ({agent.name})</option>
        {/each}
      </select>
    </div>

    <!-- Labels -->
    <div class="if-field">
      <label class="if-label" for="if-labels">Labels</label>
      <input
        id="if-labels"
        class="if-input"
        type="text"
        placeholder="frontend, bug, urgent (comma-separated)"
        bind:value={labelsRaw}
        aria-describedby="if-labels-hint"
      />
      <span id="if-labels-hint" class="if-hint">Separate multiple labels with commas</span>
    </div>

    <!-- Actions -->
    <footer class="if-actions">
      <button
        class="if-btn if-btn--cancel"
        type="button"
        onclick={onCancel}
        aria-label="Cancel and close"
      >
        Cancel
      </button>
      <button
        class="if-btn if-btn--submit"
        type="submit"
        disabled={submitting}
        aria-label={issue ? 'Save changes' : 'Create issue'}
      >
        {submitting ? 'Saving…' : (issue ? 'Save Changes' : 'Create Issue')}
      </button>
    </footer>
  </form>
</div>

<style>
  .if-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.6);
    backdrop-filter: blur(4px);
    z-index: 100;
  }

  .if-modal {
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    z-index: 101;
    width: 520px;
    max-width: calc(100vw - 48px);
    max-height: calc(100vh - 80px);
    background: var(--bg-tertiary);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-lg);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    box-shadow: 0 24px 80px rgba(0,0,0,0.6);
  }

  .if-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    border-bottom: 1px solid var(--border-default);
    flex-shrink: 0;
  }

  .if-title {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
  }

  .if-close {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    border: none;
    background: transparent;
    color: var(--text-tertiary);
    cursor: pointer;
    border-radius: var(--radius-xs);
    transition: background 100ms, color 100ms;
  }
  .if-close:hover { background: rgba(255,255,255,0.07); color: var(--text-primary); }
  .if-close:focus-visible { outline: 2px solid var(--accent-primary); }

  .if-form {
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 14px;
    overflow-y: auto;
    flex: 1;
  }

  .if-form::-webkit-scrollbar { width: 6px; }
  .if-form::-webkit-scrollbar-track { background: transparent; }
  .if-form::-webkit-scrollbar-thumb { background: var(--border-default); border-radius: 3px; }

  .if-field {
    display: flex;
    flex-direction: column;
    gap: 5px;
  }

  .if-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }

  .if-label {
    font-size: 12px;
    font-weight: 500;
    color: var(--text-secondary);
  }

  .if-required { color: var(--accent-error); margin-left: 2px; }

  .if-input, .if-select, .if-textarea {
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    color: var(--text-primary);
    font-size: 13px;
    font-family: inherit;
    padding: 7px 10px;
    transition: border-color 150ms ease;
    outline: none;
  }

  .if-input:focus, .if-select:focus, .if-textarea:focus {
    border-color: var(--accent-primary);
  }

  .if-input--error { border-color: var(--accent-error) !important; }

  .if-textarea {
    resize: vertical;
    min-height: 100px;
    line-height: 1.5;
  }

  .if-error {
    font-size: 11px;
    color: var(--accent-error);
  }

  .if-hint {
    font-size: 11px;
    color: var(--text-muted);
  }

  .if-actions {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    padding-top: 4px;
  }

  .if-btn {
    height: 32px;
    padding: 0 14px;
    border-radius: var(--radius-sm);
    font-size: 13px;
    font-weight: 500;
    font-family: inherit;
    cursor: pointer;
    border: none;
    transition: opacity 150ms ease, background 150ms ease;
  }

  .if-btn--cancel {
    background: var(--bg-elevated);
    color: var(--text-secondary);
    border: 1px solid var(--border-default);
  }
  .if-btn--cancel:hover { background: rgba(255,255,255,0.07); }
  .if-btn--cancel:focus-visible { outline: 2px solid var(--accent-primary); }

  .if-btn--submit {
    background: var(--accent-primary);
    color: #fff;
  }
  .if-btn--submit:hover { opacity: 0.88; }
  .if-btn--submit:disabled { opacity: 0.5; cursor: not-allowed; }
  .if-btn--submit:focus-visible { outline: 2px solid var(--accent-primary); outline-offset: 2px; }
</style>
