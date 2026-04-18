<script lang="ts">
  /**
   * /tasks/[short_id] — Task detail: inline title edit + description + metadata panel.
   * CSS prefix: td- (TaskDetail)
   */
  import {
    type CreateMutationOptions,
    type CreateQueryOptions,
    createMutation,
    createQuery,
    useQueryClient,
  } from '@tanstack/svelte-query';
  import { page } from '$app/state';
  import { Trash2 } from 'lucide-svelte';
  import { untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import { beforeNavigate, goto } from '$app/navigation';
  import {
    assignTaskMutation,
    completeTaskMutation,
    deleteTaskMutation,
    reopenTaskMutation,
    taskQuery,
    updateTaskMutation,
  } from '$lib/api/queries/tasks.js';
  import DirtyGuardModal from '$lib/design/patterns/DirtyGuardModal.svelte';
  import PushPanel from '$lib/design/patterns/PushPanel.svelte';
  import SkeletonList from '$lib/design/patterns/SkeletonList.svelte';
  import StatusDot from '$lib/design/patterns/StatusDot.svelte';
  import type { AssignBody, Task, TaskStatus, UpdateTaskBody } from '$lib/domain/tasks/types.js';
  import { toasts } from '$lib/stores/toasts.svelte.js';

  const shortId = $derived(page.params.short_id ?? '');
  const queryClient = useQueryClient();

  // ── Query ────────────────────────────────────────────────────────────────────

  const queryOptsStore = writable(
    untrack(() => taskQuery(shortId) as CreateQueryOptions<Task>),
  );
  $effect(() => {
    queryOptsStore.set(taskQuery(shortId) as CreateQueryOptions<Task>);
  });
  const query = createQuery<Task>(queryOptsStore);
  const task = $derived($query.data as Task | undefined);

  // ── Local edit state ─────────────────────────────────────────────────────────

  let localTitle = $state('');
  let localDesc = $state('');
  let titleDirty = $state(false);
  let descDirty = $state(false);
  let panelOpen = $state(true);

  // Seed local state once task loads (only seed if not dirty)
  $effect(() => {
    if (task && !titleDirty && !descDirty) {
      localTitle = task.title;
      localDesc = task.description ?? '';
    }
  });

  const isDirty = $derived(titleDirty || descDirty);

  // ── Guard modal ──────────────────────────────────────────────────────────────

  let guardOpen = $state(false);
  let pendingUrl = $state('');
  let allowNavigation = $state(false);

  beforeNavigate(({ to, cancel }) => {
    if (isDirty && !allowNavigation) {
      cancel();
      pendingUrl = to?.url.pathname ?? '/tasks';
      guardOpen = true;
    }
  });

  function handleGuardCancel(): void {
    guardOpen = false;
    pendingUrl = '';
  }

  function handleGuardDiscard(): void {
    allowNavigation = true;
    guardOpen = false;
    goto(pendingUrl || '/tasks');
  }

  // ── Mutations ────────────────────────────────────────────────────────────────

  const updateMut = createMutation<Task, Error, { shortId: string; body: UpdateTaskBody }>(
    updateTaskMutation() as CreateMutationOptions<Task, Error, { shortId: string; body: UpdateTaskBody }>,
  );

  const completeMut = createMutation<Task, Error, string>(
    completeTaskMutation() as CreateMutationOptions<Task, Error, string>,
  );

  const reopenMut = createMutation<Task, Error, string>(
    reopenTaskMutation() as CreateMutationOptions<Task, Error, string>,
  );

  const assignMut = createMutation<Task, Error, { shortId: string; body: AssignBody }>(
    assignTaskMutation() as CreateMutationOptions<Task, Error, { shortId: string; body: AssignBody }>,
  );

  const deleteMut = createMutation<void, Error, string>(
    deleteTaskMutation() as CreateMutationOptions<void, Error, string>,
  );

  function invalidate(): void {
    queryClient.invalidateQueries({ queryKey: ['tasks', shortId] });
    queryClient.invalidateQueries({ queryKey: ['tasks'] });
  }

  function saveDescription(): void {
    if (!task || !descDirty) return;
    $updateMut.mutate(
      { shortId, body: { description: localDesc } },
      {
        onSuccess: () => {
          descDirty = false;
          invalidate();
          toasts.success('Description saved');
        },
        onError: (err: Error) => {
          toasts.error(`Save failed: ${err.message}`);
        },
      },
    );
  }

  function saveTitle(): void {
    if (!task || !titleDirty || !localTitle.trim()) return;
    $updateMut.mutate(
      { shortId, body: { title: localTitle.trim() } },
      {
        onSuccess: () => {
          titleDirty = false;
          invalidate();
          toasts.success('Title saved');
        },
        onError: (err: Error) => {
          toasts.error(`Save failed: ${err.message}`);
        },
      },
    );
  }

  function handleTitleKeydown(e: KeyboardEvent): void {
    if (e.key === 'Enter') {
      e.preventDefault();
      saveTitle();
    }
    if ((e.metaKey || e.ctrlKey) && e.key === 's') {
      e.preventDefault();
      saveTitle();
    }
  }

  function handleDescKeydown(e: KeyboardEvent): void {
    if ((e.metaKey || e.ctrlKey) && e.key === 's') {
      e.preventDefault();
      saveDescription();
    }
  }

  function handleComplete(): void {
    if (!task) return;
    $completeMut.mutate(shortId, { onSuccess: () => { invalidate(); toasts.success('Task completed'); } });
  }

  function handleReopen(): void {
    if (!task) return;
    $reopenMut.mutate(shortId, { onSuccess: () => { invalidate(); toasts.success('Task reopened'); } });
  }

  // ── Assign form ──────────────────────────────────────────────────────────────

  let assignType = $state('agent');
  let assignId = $state('');

  function handleAssign(e: SubmitEvent): void {
    e.preventDefault();
    if (!assignId.trim()) return;
    $assignMut.mutate(
      { shortId, body: { assigneeType: assignType, assigneeId: assignId.trim() } },
      {
        onSuccess: () => {
          assignId = '';
          invalidate();
          toasts.success('Task assigned');
        },
        onError: (err: Error) => {
          toasts.error(`Assign failed: ${err.message}`);
        },
      },
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────────

  let deleteConfirm = $state(false);

  function handleDelete(): void {
    $deleteMut.mutate(shortId, {
      onSuccess: () => {
        allowNavigation = true;
        toasts.success('Task deleted');
        goto('/tasks');
      },
      onError: (err: Error) => {
        toasts.error(`Delete failed: ${err.message}`);
        deleteConfirm = false;
      },
    });
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  function statusDotColor(s: TaskStatus): 'green' | 'amber' | 'grey' | 'red' {
    switch (s) {
      case 'in_progress': return 'green';
      case 'todo': return 'amber';
      case 'done': return 'grey';
      case 'cancelled': return 'red';
    }
  }

  function priorityLabel(p: number): string {
    return ['None', 'Low', 'Medium', 'High'][Math.max(0, Math.min(p, 3))];
  }

  function formatDate(iso: string | null): string {
    if (!iso) return '—';
    return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
  }
</script>

<svelte:window
  onkeydown={(e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 's') {
      e.preventDefault();
      if (descDirty) saveDescription();
      if (titleDirty) saveTitle();
    }
  }}
/>

<DirtyGuardModal open={guardOpen} onCancel={handleGuardCancel} onDiscard={handleGuardDiscard} />

<div class="td-shell">
  <!-- Header -->
  <header class="td-header">
    <nav class="td-breadcrumb" aria-label="Breadcrumb">
      <a class="td-breadcrumb-link" href="/tasks">Tasks</a>
      <span class="td-breadcrumb-sep" aria-hidden="true">/</span>
      <span class="td-breadcrumb-current" aria-current="page">{shortId}</span>
    </nav>

    {#if task}
      <div class="td-pill-actions">
        <StatusDot color={statusDotColor(task.status)} label={task.status} />
        {#if task.status === 'done' || task.status === 'cancelled'}
          <button
            class="btn-pill btn-pill-secondary btn-pill-sm"
            onclick={handleReopen}
            disabled={$reopenMut.isPending}
            aria-label="Reopen task"
          >
            {$reopenMut.isPending ? 'Reopening…' : 'Reopen'}
          </button>
        {:else}
          <button
            class="btn-pill btn-pill-primary btn-pill-sm"
            onclick={handleComplete}
            disabled={$completeMut.isPending}
            aria-label="Mark task complete"
          >
            {$completeMut.isPending ? 'Completing…' : 'Complete'}
          </button>
        {/if}
        {#if !deleteConfirm}
          <button
            class="btn-compact btn-compact-ghost td-delete-btn"
            onclick={() => { deleteConfirm = true; }}
            aria-label="Delete task"
          >
            <Trash2 size={13} aria-hidden="true" />
          </button>
        {:else}
          <button
            class="btn-pill btn-pill-sm td-confirm-delete"
            onclick={handleDelete}
            disabled={$deleteMut.isPending}
            aria-label="Confirm delete"
          >
            {$deleteMut.isPending ? 'Deleting…' : 'Confirm delete'}
          </button>
          <button
            class="btn-compact btn-compact-ghost"
            onclick={() => { deleteConfirm = false; }}
            aria-label="Cancel delete"
          >
            Cancel
          </button>
        {/if}
        <button
          class="btn-compact btn-compact-secondary"
          onclick={() => { panelOpen = !panelOpen; }}
          aria-label="Toggle metadata panel"
          aria-expanded={panelOpen}
        >
          Details
        </button>
      </div>
    {/if}
  </header>

  <!-- Body -->
  <div class="td-body">
    <main class="td-main">
      {#if $query.isLoading}
        <div class="td-skeleton">
          <SkeletonList count={5} height="1.5rem" gap="0.5rem" />
        </div>
      {:else if $query.isError}
        <p class="td-error" role="alert">
          {($query.error as Error).message ?? 'Failed to load task.'}
        </p>
      {:else if task}
        <!-- Inline title edit -->
        <div class="td-title-wrap">
          <input
            class="td-title-input"
            type="text"
            bind:value={localTitle}
            oninput={() => { titleDirty = true; }}
            onblur={saveTitle}
            onkeydown={handleTitleKeydown}
            aria-label="Task title"
            autocomplete="off"
          />
          {#if titleDirty}
            <button
              class="btn-pill btn-pill-primary btn-pill-sm td-save-btn"
              onclick={saveTitle}
              disabled={$updateMut.isPending}
              aria-label="Save title"
            >
              Save
            </button>
          {/if}
        </div>

        <!-- Description textarea -->
        <label class="td-label" for="td-desc">Description</label>
        <textarea
          id="td-desc"
          class="td-desc"
          bind:value={localDesc}
          oninput={() => { descDirty = true; }}
          onkeydown={handleDescKeydown}
          placeholder="Add a description…"
          rows={8}
          aria-label="Task description"
        ></textarea>

        {#if descDirty}
          <div class="td-desc-actions">
            <button
              class="btn-pill btn-pill-primary btn-pill-sm"
              onclick={saveDescription}
              disabled={$updateMut.isPending}
              aria-label="Save description"
            >
              {$updateMut.isPending ? 'Saving…' : 'Save'}
            </button>
            <button
              class="btn-compact btn-compact-ghost"
              onclick={() => { localDesc = task.description ?? ''; descDirty = false; }}
              aria-label="Discard description changes"
            >
              Discard
            </button>
            <span class="td-hint">or ⌘S</span>
          </div>
        {/if}
      {/if}
    </main>

    <!-- Metadata PushPanel -->
    <PushPanel open={panelOpen} title="Metadata" onClose={() => { panelOpen = false; }}>
      {#if task}
        <dl class="td-meta-list">
          <dt class="td-meta-key">Assignee</dt>
          <dd class="td-meta-val">
            {#if task.assigneeType && task.assigneeId}
              <span class="td-mono">{task.assigneeType === 'agent' ? '🤖' : '👤'} {task.assigneeId}</span>
            {:else}
              —
            {/if}
          </dd>

          <dt class="td-meta-key">Priority</dt>
          <dd class="td-meta-val">{priorityLabel(task.priority)}</dd>

          <dt class="td-meta-key">Status</dt>
          <dd class="td-meta-val">{task.status}</dd>

          <dt class="td-meta-key">Due</dt>
          <dd class="td-meta-val">{formatDate(task.dueAt)}</dd>

          <dt class="td-meta-key">Labels</dt>
          <dd class="td-meta-val">
            {#if task.labels.length > 0}
              <div class="td-tags">
                {#each task.labels as label (label)}
                  <span class="td-tag">{label}</span>
                {/each}
              </div>
            {:else}
              —
            {/if}
          </dd>

          <dt class="td-meta-key">Project</dt>
          <dd class="td-meta-val td-mono">{task.projectSlug ?? '—'}</dd>

          <dt class="td-meta-key">Workspace</dt>
          <dd class="td-meta-val td-mono">{task.workspaceSlug ?? '—'}</dd>

          <dt class="td-meta-key">Parent</dt>
          <dd class="td-meta-val td-mono">{task.parentId ?? '—'}</dd>

          <dt class="td-meta-key">Created</dt>
          <dd class="td-meta-val td-mono">{formatDate(task.insertedAt)}</dd>

          <dt class="td-meta-key">Updated</dt>
          <dd class="td-meta-val td-mono">{formatDate(task.updatedAt)}</dd>
        </dl>

        <!-- Assign form -->
        <form class="td-assign-form" onsubmit={handleAssign} aria-label="Assign task">
          <p class="td-panel-section-label">Assign to</p>
          <select
            class="td-panel-select"
            bind:value={assignType}
            aria-label="Assignee type"
          >
            <option value="agent">Agent</option>
            <option value="user">User</option>
          </select>
          <input
            class="td-panel-input"
            type="text"
            placeholder="ID or slug"
            bind:value={assignId}
            aria-label="Assignee ID"
            autocomplete="off"
          />
          <button
            class="btn-pill btn-pill-primary btn-pill-sm"
            type="submit"
            disabled={!assignId.trim() || $assignMut.isPending}
            aria-label="Assign"
          >
            {$assignMut.isPending ? 'Assigning…' : 'Assign'}
          </button>
        </form>
      {/if}
    </PushPanel>
  </div>
</div>

<style>
  .td-shell {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  /* Header */
  .td-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-5);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    flex-wrap: wrap;
  }

  .td-breadcrumb {
    display: flex;
    align-items: center;
    gap: var(--space-1);
  }

  .td-breadcrumb-link {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    text-decoration: none;
    transition: color var(--dur-instant) var(--ease-out);
  }

  .td-breadcrumb-link:hover {
    color: var(--fg);
  }

  .td-breadcrumb-sep {
    font-size: var(--text-sm);
    color: var(--fg-subtle);
  }

  .td-breadcrumb-current {
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    color: var(--fg);
  }

  .td-pill-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-wrap: wrap;
  }

  .td-delete-btn {
    color: var(--signal-error, red);
  }

  .td-confirm-delete {
    background: color-mix(in oklch, red 80%, transparent 20%);
    color: white;
    border: none;
    border-radius: var(--radius-full, 9999px);
    padding: 4px 12px;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    cursor: pointer;
  }

  /* Body */
  .td-body {
    flex: 1;
    display: flex;
    overflow: hidden;
    gap: var(--space-2);
    padding: 0 var(--space-2) var(--space-2);
  }

  .td-main {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    overflow-y: auto;
    padding: var(--space-5);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .td-skeleton {
    width: 100%;
  }

  .td-error {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--signal-error, red);
  }

  /* Title */
  .td-title-wrap {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .td-title-input {
    flex: 1;
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    background: transparent;
    border: none;
    outline: none;
    border-bottom: 2px solid transparent;
    padding: var(--space-1) 0;
    transition: border-color var(--dur-instant) var(--ease-out);
    letter-spacing: var(--tracking-2xl);
  }

  .td-title-input:focus {
    border-bottom-color: color-mix(in oklch, var(--fg) 30%, transparent);
  }

  .td-save-btn {
    flex-shrink: 0;
  }

  /* Description */
  .td-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .td-desc {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-3);
    resize: vertical;
    outline: none;
    line-height: 1.6;
    min-height: 160px;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .td-desc:focus {
    border-color: color-mix(in oklch, var(--fg) 40%, transparent);
  }

  .td-desc-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .td-hint {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  /* Panel metadata */
  .td-meta-list {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: var(--space-2) var(--space-3);
    margin: 0 0 var(--space-5);
  }

  .td-meta-key {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    align-self: start;
    padding-top: 1px;
  }

  .td-meta-val {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    word-break: break-word;
  }

  .td-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  .td-tags {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-1);
  }

  .td-tag {
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 1px 5px;
  }

  /* Assign form */
  .td-panel-section-label {
    margin: 0 0 var(--space-2);
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .td-assign-form {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    border-top: 1px solid var(--border);
    padding-top: var(--space-4);
  }

  .td-panel-select,
  .td-panel-input {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-2) var(--space-3);
    outline: none;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .td-panel-input:focus {
    border-color: color-mix(in oklch, var(--fg) 40%, transparent);
  }
</style>
