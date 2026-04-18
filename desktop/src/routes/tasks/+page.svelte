<script lang="ts">
  /**
   * /tasks — Task list with status filter chips + text search + inline create form.
   * CSS prefix: tl- (TaskList)
   */
  import {
    type CreateMutationOptions,
    type CreateQueryOptions,
    createMutation,
    createQuery,
    useQueryClient,
  } from '@tanstack/svelte-query';
  import { ClipboardList } from 'lucide-svelte';
  import { untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import { goto } from '$app/navigation';
  import { createTaskMutation, tasksQuery } from '$lib/api/queries/tasks.js';
  import EmptyState from '$lib/design/patterns/EmptyState.svelte';
  import SkeletonList from '$lib/design/patterns/SkeletonList.svelte';
  import StatusDot from '$lib/design/patterns/StatusDot.svelte';
  import type { CreateTaskBody, Task, TaskFilters, TaskStatus } from '$lib/domain/tasks/types.js';
  import { toasts } from '$lib/stores/toasts.svelte.js';

  const queryClient = useQueryClient();

  // ── Filter state ─────────────────────────────────────────────────────────────

  type StatusChip = 'all' | TaskStatus;
  const STATUS_CHIPS: { value: StatusChip; label: string }[] = [
    { value: 'all', label: 'All' },
    { value: 'todo', label: 'Todo' },
    { value: 'in_progress', label: 'In Progress' },
    { value: 'done', label: 'Done' },
    { value: 'cancelled', label: 'Cancelled' },
  ];

  let statusChip = $state<StatusChip>('all');
  let searchText = $state('');

  const filters = $derived<TaskFilters>({
    status: statusChip !== 'all' ? statusChip : undefined,
    q: searchText.trim() || undefined,
  });

  const queryOptsStore = writable(
    untrack(() => tasksQuery(filters) as CreateQueryOptions<Task[]>),
  );

  $effect(() => {
    queryOptsStore.set(tasksQuery(filters) as CreateQueryOptions<Task[]>);
  });

  const query = createQuery<Task[]>(queryOptsStore);
  const tasks = $derived(($query.data ?? []) as Task[]);

  // ── Create form ───────────────────────────────────────────────────────────────

  let createOpen = $state(false);
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

  function openCreate() {
    createOpen = true;
    createError = null;
  }

  function closeCreate() {
    createOpen = false;
    newTitle = '';
    newDescription = '';
    newStatus = 'todo';
    newPriority = 0;
    newDueAt = '';
    newLabels = '';
    newParentId = '';
    createError = null;
  }

  function submitCreate(e: SubmitEvent) {
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
        closeCreate();
      },
      onError: (err: Error) => {
        createError = err.message ?? 'Create failed';
      },
    });
  }

  // ── Display helpers ───────────────────────────────────────────────────────────

  function statusDotColor(s: TaskStatus): 'green' | 'amber' | 'grey' | 'red' {
    switch (s) {
      case 'in_progress': return 'green';
      case 'todo': return 'amber';
      case 'done': return 'grey';
      case 'cancelled': return 'red';
    }
  }

  function statusLabel(s: TaskStatus): string {
    switch (s) {
      case 'in_progress': return 'In Progress';
      case 'todo': return 'Todo';
      case 'done': return 'Done';
      case 'cancelled': return 'Cancelled';
    }
  }

  function priorityDots(p: number): string {
    return '●'.repeat(Math.max(0, Math.min(p, 3))) || '○';
  }

  function formatDueAt(iso: string | null): string {
    if (!iso) return '—';
    return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
  }
</script>

<div class="tl-page">
  <!-- Header -->
  <header class="tl-header">
    <h1 class="tl-title">Tasks</h1>
    <button
      class="btn-pill btn-pill-primary btn-pill-sm"
      onclick={openCreate}
      aria-label="Create new task"
    >
      + New task
    </button>
  </header>

  <!-- Filter bar -->
  <div class="tl-filters" role="search" aria-label="Filter tasks">
    <div class="tl-chips" role="group" aria-label="Status filter">
      {#each STATUS_CHIPS as chip (chip.value)}
        <button
          class="tl-chip"
          class:tl-chip--active={statusChip === chip.value}
          onclick={() => (statusChip = chip.value)}
          aria-pressed={statusChip === chip.value}
        >
          {chip.label}
        </button>
      {/each}
    </div>
    <input
      class="tl-search"
      type="search"
      placeholder="Search tasks…"
      bind:value={searchText}
      aria-label="Search tasks"
    />
  </div>

  <!-- Inline create form -->
  {#if createOpen}
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
          onclick={closeCreate}
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
  {/if}

  <!-- List / states -->
  {#if $query.isError}
    <EmptyState
      title="Couldn't load tasks"
      body={($query.error as Error).message || 'Check your connection and try again.'}
      action="Retry"
      onAction={() => $query.refetch()}
    />
  {:else if $query.isLoading}
    <div class="tl-skeleton-wrap">
      <SkeletonList count={8} height="2.5rem" gap="0.375rem" />
    </div>
  {:else if tasks.length === 0}
    <EmptyState
      icon={ClipboardList as never}
      title="No tasks"
      body={statusChip !== 'all' || searchText ? 'No tasks match your filters.' : 'Create your first task to get started.'}
      action="+ New task"
      onAction={openCreate}
    />
  {:else}
    <div class="tl-table-wrap">
      <table class="tl-table" aria-label="Task list">
        <thead>
          <tr>
            <th class="tl-th tl-th-id">ID</th>
            <th class="tl-th tl-th-title">Title</th>
            <th class="tl-th tl-th-status">Status</th>
            <th class="tl-th tl-th-assignee">Assignee</th>
            <th class="tl-th tl-th-due">Due</th>
            <th class="tl-th tl-th-priority">Priority</th>
          </tr>
        </thead>
        <tbody>
          {#each tasks as task (task.id)}
            <!-- svelte-ignore a11y_interactive_supports_focus -->
            <tr
              class="tl-row bos-table-row"
              role="button"
              onclick={() => goto(`/tasks/${task.shortId}`)}
              onkeydown={(e) => e.key === 'Enter' && goto(`/tasks/${task.shortId}`)}
            >
              <td class="tl-td tl-mono tl-td-id">{task.shortId}</td>
              <td class="tl-td tl-td-title">{task.title}</td>
              <td class="tl-td tl-td-status">
                <StatusDot color={statusDotColor(task.status)} label={statusLabel(task.status)} />
              </td>
              <td class="tl-td tl-mono tl-td-assignee">
                {#if task.assigneeType && task.assigneeId}
                  {task.assigneeType === 'agent' ? '🤖' : '👤'} {task.assigneeId}
                {:else}
                  —
                {/if}
              </td>
              <td class="tl-td tl-mono tl-td-due">{formatDueAt(task.dueAt)}</td>
              <td class="tl-td tl-mono tl-td-priority" aria-label="Priority {task.priority}">
                {priorityDots(task.priority)}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>

<style>
  .tl-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-6);
    overflow-y: auto;
    height: 100%;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .tl-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: var(--space-3);
  }

  .tl-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: var(--tracking-2xl);
    line-height: var(--lh-2xl);
  }

  /* Filter bar */
  .tl-filters {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    flex-wrap: wrap;
  }

  .tl-chips {
    display: flex;
    gap: var(--space-1);
    flex-wrap: wrap;
  }

  .tl-chip {
    padding: 4px 12px;
    border-radius: var(--radius-full, 9999px);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    background: transparent;
    border: 1px solid var(--border);
    cursor: pointer;
    transition: background 0.12s ease, color 0.12s ease, border-color 0.12s ease;
    white-space: nowrap;
  }

  .tl-chip:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg);
  }

  .tl-chip--active {
    background: color-mix(in oklch, var(--fg) 12%, transparent);
    color: var(--fg);
    border-color: color-mix(in oklch, var(--fg) 30%, transparent);
  }

  .tl-chip:focus-visible {
    outline: 2px solid var(--fg);
    outline-offset: 2px;
  }

  .tl-search {
    flex: 1;
    min-width: 160px;
    max-width: 280px;
    padding: 5px 10px;
    border-radius: var(--radius-md);
    border: 1px solid var(--border);
    background: var(--bg-inset);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    transition: border-color 0.12s ease;
  }

  .tl-search:focus {
    border-color: color-mix(in oklch, var(--fg) 40%, transparent);
  }

  .tl-search::placeholder {
    color: var(--fg-subtle);
  }

  /* Create form */
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

  /* Table */
  .tl-skeleton-wrap {
    flex: 1;
  }

  .tl-table-wrap {
    overflow-x: auto;
    border-radius: var(--radius-lg);
    border: 1px solid var(--border);
  }

  .tl-table {
    width: 100%;
    border-collapse: collapse;
  }

  .tl-th {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-muted);
    padding: var(--space-2) var(--space-3);
    text-align: left;
    border-bottom: 1px solid var(--border);
    letter-spacing: var(--tracking-xs);
    text-transform: uppercase;
    white-space: nowrap;
  }

  .tl-th-id { width: 100px; }
  .tl-th-status { width: 120px; }
  .tl-th-assignee { width: 150px; }
  .tl-th-due { width: 80px; }
  .tl-th-priority { width: 72px; }

  :global(.tl-row) {
    cursor: pointer;
  }

  :global(.tl-row:hover) {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  .tl-td {
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    border-bottom: 1px solid var(--border);
    white-space: nowrap;
  }

  :global(.tl-row:last-child .tl-td) {
    border-bottom: none;
  }

  .tl-td-title {
    max-width: 360px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-weight: 500;
  }

  .tl-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }
</style>
