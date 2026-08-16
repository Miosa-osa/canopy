<script lang="ts">
  /**
   * TaskCreateForm — inline new-task form (open/close driven by parent).
   * CSS prefix: tl- (shared with /tasks page).
   */
  import type { Task, CreateTaskBody, TaskStatus } from '$lib/domain/tasks/types.js';
  import {
    type CreateMutationOptions,
    createMutation,
    useQueryClient,
  } from '@tanstack/svelte-query';
  import { createTaskMutation } from '$lib/api/queries/tasks.js';
  import { toasts } from '$lib/stores/toasts.svelte.js';

  interface Props {
    onClose: () => void;
  }

  let { onClose }: Props = $props();

  const queryClient = useQueryClient();

  let newTitle = $state('');
  let newDescription = $state('');
  let newStatus = $state<TaskStatus>('todo');
  let newPriority = $state(0);
  let newDueAt = $state('');
  let newLabels = $state('');
  let newParentId = $state('');
  let createError = $state<string | null>(null);

  const createMut = createMutation<Task, Error, CreateTaskBody>(
    createTaskMutation() as CreateMutationOptions<Task, Error, CreateTaskBody>,
  );

  function reset(): void {
    newTitle = '';
    newDescription = '';
    newStatus = 'todo';
    newPriority = 0;
    newDueAt = '';
    newLabels = '';
    newParentId = '';
    createError = null;
  }

  function handleCancel(): void {
    reset();
    onClose();
  }

  function submitCreate(e: SubmitEvent): void {
    e.preventDefault();
    if (!newTitle.trim()) return;
    createError = null;

    const body: CreateTaskBody = {
      title: newTitle.trim(),
      status: newStatus,
      priority: newPriority as 0 | 1 | 2 | 3,
    };
    if (newDescription.trim()) body.description = newDescription.trim();
    if (newDueAt) body.dueAt = new Date(newDueAt).toISOString();
    if (newLabels.trim()) body.labels = newLabels.split(',').map((l) => l.trim()).filter(Boolean);
    if (newParentId.trim()) body.parentId = newParentId.trim();

    $createMut.mutate(body, {
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: ['tasks'] });
        toasts.success('Task created');
        reset();
        onClose();
      },
      onError: (err: Error) => {
        createError = err.message ?? 'Create failed';
      },
    });
  }
</script>

<form class="tl-create-form glass-panel" onsubmit={submitCreate} aria-label="New task form">
  <div class="tl-create-row tl-create-row--full">
    <label class="tl-label" for="tl-new-title">Title <span aria-hidden="true">*</span></label>
    <input
      id="tl-new-title"
      class="tl-input"
      type="text"
      bind:value={newTitle}
      placeholder="Task title"
      required
      autocomplete="off"
    />
  </div>
  <div class="tl-create-row tl-create-row--full">
    <label class="tl-label" for="tl-new-desc">Description</label>
    <textarea
      id="tl-new-desc"
      class="tl-input tl-textarea"
      bind:value={newDescription}
      placeholder="Optional description"
      rows={2}
    ></textarea>
  </div>
  <div class="tl-create-grid">
    <div class="tl-create-field">
      <label class="tl-label" for="tl-new-status">Status</label>
      <select id="tl-new-status" class="tl-select" bind:value={newStatus}>
        <option value="todo">Todo</option>
        <option value="in_progress">In Progress</option>
        <option value="done">Done</option>
        <option value="cancelled">Cancelled</option>
      </select>
    </div>
    <div class="tl-create-field">
      <label class="tl-label" for="tl-new-priority">Priority</label>
      <select id="tl-new-priority" class="tl-select" bind:value={newPriority}>
        <option value={0}>None</option>
        <option value={1}>Low</option>
        <option value={2}>Medium</option>
        <option value={3}>High</option>
      </select>
    </div>
    <div class="tl-create-field">
      <label class="tl-label" for="tl-new-due">Due date</label>
      <input id="tl-new-due" class="tl-input" type="date" bind:value={newDueAt} />
    </div>
    <div class="tl-create-field">
      <label class="tl-label" for="tl-new-labels">Labels</label>
      <input
        id="tl-new-labels"
        class="tl-input"
        type="text"
        bind:value={newLabels}
        placeholder="bug, feature, …"
        autocomplete="off"
      />
    </div>
    <div class="tl-create-field">
      <label class="tl-label" for="tl-new-parent">Parent task ID</label>
      <input
        id="tl-new-parent"
        class="tl-input"
        type="text"
        bind:value={newParentId}
        placeholder="T-12345678"
        autocomplete="off"
      />
    </div>
  </div>
  {#if createError}
    <p class="tl-create-error" role="alert">{createError}</p>
  {/if}
  <div class="tl-create-actions">
    <button
      type="button"
      class="btn-pill btn-pill-secondary btn-pill-sm"
      onclick={handleCancel}
      disabled={$createMut.isPending}
    >
      Cancel
    </button>
    <button
      type="submit"
      class="btn-pill btn-pill-primary btn-pill-sm"
      disabled={$createMut.isPending || !newTitle.trim()}
      aria-busy={$createMut.isPending}
    >
      {$createMut.isPending ? 'Creating…' : 'Create task'}
    </button>
  </div>
</form>

<style>
  .tl-create-form {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-4);
    border-radius: var(--radius-lg);
  }

  .tl-create-row {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .tl-create-row--full {
    width: 100%;
  }

  .tl-create-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
    gap: var(--space-3);
  }

  .tl-create-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .tl-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    text-transform: uppercase;
    letter-spacing: var(--tracking-xs);
  }

  .tl-input,
  .tl-select {
    padding: 5px 8px;
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

  .tl-input:focus,
  .tl-select:focus {
    border-color: color-mix(in oklch, var(--fg) 40%, transparent);
  }

  .tl-textarea {
    resize: vertical;
    min-height: 56px;
  }

  .tl-create-error {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--signal-error, red);
  }

  .tl-create-actions {
    display: flex;
    justify-content: flex-end;
    gap: var(--space-2);
  }
</style>
