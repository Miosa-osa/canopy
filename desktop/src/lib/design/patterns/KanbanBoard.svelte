<script lang="ts">
  /**
   * KanbanBoard — 4-column drag-and-drop task board.
   * CSS prefix: kb- (KanbanBoard)
   *
   * Reuses tasksQuery() + updateTaskMutation() from $lib/api/queries/tasks.
   * Uses svelte-dnd-action for drag-and-drop with keyboard support.
   * Optimistic status updates with rollback on error.
   */
  import {
    type CreateMutationOptions,
    type CreateQueryOptions,
    createMutation,
    createQuery,
    useQueryClient,
  } from '@tanstack/svelte-query';
  import { SHADOW_PLACEHOLDER_ITEM_ID, dndzone } from 'svelte-dnd-action';
  import type { DndEvent } from 'svelte-dnd-action';
  import { goto } from '$app/navigation';
  import { tasksQuery, updateTaskMutation } from '$lib/api/queries/tasks.js';
  import { toasts } from '$lib/stores/toasts.svelte.js';
  import type { Task, TaskFilters, TaskStatus, UpdateTaskBody } from '$lib/domain/tasks/types.js';
  import { writable } from 'svelte/store';
  import { untrack } from 'svelte';

  // ── Props ──────────────────────────────────────────────────────────────────

  interface Props {
    filters?: TaskFilters;
  }

  let { filters = {} }: Props = $props();

  // ── Query ──────────────────────────────────────────────────────────────────

  const queryOptsStore = writable(
    untrack(() => tasksQuery(filters) as CreateQueryOptions<Task[]>),
  );

  $effect(() => {
    queryOptsStore.set(tasksQuery(filters) as CreateQueryOptions<Task[]>);
  });

  const query = createQuery<Task[]>(queryOptsStore);
  const queryClient = useQueryClient();

  // ── Mutation ───────────────────────────────────────────────────────────────

  const updateMut = createMutation<Task, Error, { shortId: string; body: UpdateTaskBody }>(
    updateTaskMutation() as CreateMutationOptions<Task, Error, { shortId: string; body: UpdateTaskBody }>,
  );

  // ── Column config ──────────────────────────────────────────────────────────

  const COLUMNS: { status: TaskStatus; label: string; colorClass: string }[] = [
    { status: 'todo',        label: 'Todo',        colorClass: 'kb-col--todo' },
    { status: 'in_progress', label: 'In Progress', colorClass: 'kb-col--inprogress' },
    { status: 'done',        label: 'Done',         colorClass: 'kb-col--done' },
    { status: 'cancelled',   label: 'Cancelled',    colorClass: 'kb-col--cancelled' },
  ];

  // ── Column state ───────────────────────────────────────────────────────────

  /**
   * Each column holds its own Task[] for dndzone.
   * dndzone requires items to be an array passed directly via use:dndzone.
   */
  type Columns = Record<TaskStatus, Task[]>;

  function buildColumns(tasks: Task[]): Columns {
    return {
      todo:        tasks.filter((t) => t.status === 'todo'),
      in_progress: tasks.filter((t) => t.status === 'in_progress'),
      done:        tasks.filter((t) => t.status === 'done'),
      cancelled:   tasks.filter((t) => t.status === 'cancelled'),
    };
  }

  // Reactive columns — rebuilt from server data, patched during drag.
  let columns = $state<Columns>({
    todo: [],
    in_progress: [],
    done: [],
    cancelled: [],
  });

  // Track whether a drag is in flight to avoid overwriting columns mid-drag.
  let dragging = $state(false);

  $effect(() => {
    const tasks = ($query.data ?? []) as Task[];
    if (!dragging) {
      columns = buildColumns(tasks);
    }
  });

  // ── DnD handlers ──────────────────────────────────────────────────────────

  /**
   * consider: called during drag hover — update local columns optimistically.
   */
  function handleConsider(status: TaskStatus, e: CustomEvent<DndEvent<Task>>) {
    dragging = true;
    columns = { ...columns, [status]: e.detail.items };
  }

  /**
   * finalize: drag dropped — if status changed, call mutation; rollback on error.
   */
  function handleFinalize(status: TaskStatus, e: CustomEvent<DndEvent<Task>>) {
    dragging = false;
    const newItems = e.detail.items;
    columns = { ...columns, [status]: newItems };

    // Find the task that landed here with a different status.
    const moved = newItems.find(
      (t) => t.id !== SHADOW_PLACEHOLDER_ITEM_ID && t.status !== status,
    );

    if (!moved) return;

    // Snapshot for rollback.
    const prevColumns = { ...columns };
    // Apply optimistic update immediately.
    const updatedItems = newItems.map((t) =>
      t.id === moved.id ? { ...t, status } : t,
    );
    columns = { ...columns, [status]: updatedItems };

    $updateMut.mutate(
      { shortId: moved.shortId, body: { status } },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: ['tasks'] });
        },
        onError: () => {
          // Rollback: restore pre-drag columns from server data.
          const tasks = ($query.data ?? []) as Task[];
          columns = buildColumns(tasks);
          toasts.error('Failed to update task status');
          // Also roll back the optimistic columns snapshot.
          void prevColumns; // consumed by rollback above
        },
      },
    );
  }

  // ── Display helpers ────────────────────────────────────────────────────────

  const PRIORITY_COLORS: Record<number, string> = {
    0: 'var(--fg-subtle)',
    1: 'oklch(0.72 0.09 145)',
    2: 'oklch(0.75 0.15 60)',
    3: 'oklch(0.65 0.20 25)',
  };

  function priorityColor(p: number): string {
    return PRIORITY_COLORS[p] ?? PRIORITY_COLORS[0];
  }

  function formatRelativeDue(iso: string | null): string | null {
    if (!iso) return null;
    const diff = new Date(iso).getTime() - Date.now();
    const days = Math.ceil(diff / 86_400_000);
    if (days < 0) return `${Math.abs(days)}d overdue`;
    if (days === 0) return 'Today';
    if (days === 1) return 'Tomorrow';
    if (days < 7) return `${days}d`;
    return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
  }

  const FLIP_MS = 200;
</script>

<div class="kb-board" role="region" aria-label="Kanban board">
  {#each COLUMNS as col (col.status)}
    {@const items = columns[col.status]}
    <div class="kb-col {col.colorClass}">
      <!-- Column header -->
      <header class="kb-col__header">
        <span class="kb-col__label">{col.label}</span>
        <span class="kb-col__count" aria-label="{items.filter((t) => t.id !== SHADOW_PLACEHOLDER_ITEM_ID).length} tasks">
          {items.filter((t) => t.id !== SHADOW_PLACEHOLDER_ITEM_ID).length}
        </span>
      </header>

      <!-- Drop zone -->
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div
        class="kb-col__dropzone"
        use:dndzone={{
          items,
          flipDurationMs: FLIP_MS,
          dragDisabled: false,
          dropTargetClasses: ['kb-col__dropzone--over'],
          type: 'kanban-task',
        }}
        onconsider={(e) => handleConsider(col.status, e)}
        onfinalize={(e) => handleFinalize(col.status, e)}
      >
        {#each items as task (task.id)}
          {#if task.id === SHADOW_PLACEHOLDER_ITEM_ID}
            <!-- Drag ghost placeholder -->
            <div class="kb-card kb-card--ghost" aria-hidden="true"></div>
          {:else}
            <!-- Task card -->
            <button
              class="kb-card"
              onclick={() => goto(`/tasks/${task.shortId}`)}
              aria-label="Open task {task.shortId}: {task.title}"
            >
              <!-- ID chip -->
              <p class="kb-card__id">{task.shortId}</p>

              <!-- Title -->
              <p class="kb-card__title">{task.title}</p>

              <!-- Footer -->
              <div class="kb-card__footer">
                <!-- Priority dot -->
                <span
                  class="kb-card__priority-dot"
                  style="background: {priorityColor(task.priority)};"
                  aria-label="Priority {task.priority}"
                ></span>

                <!-- Assignee pill -->
                {#if task.assigneeType && task.assigneeId}
                  <span class="kb-card__assignee" title="{task.assigneeType}: {task.assigneeId}">
                    {task.assigneeType === 'agent' ? '🤖' : '👤'}
                  </span>
                {/if}

                <!-- Due date -->
                {#if task.dueAt}
                  {@const rel = formatRelativeDue(task.dueAt)}
                  {#if rel}
                    <span
                      class="kb-card__due"
                      class:kb-card__due--overdue={rel.endsWith('overdue')}
                    >{rel}</span>
                  {/if}
                {/if}
              </div>
            </button>
          {/if}
        {:else}
          <p class="kb-col__empty">No tasks</p>
        {/each}
      </div>
    </div>
  {/each}
</div>

<style>
  /* ── Board layout ─────────────────────────────────────────────────────── */
  .kb-board {
    display: flex;
    gap: var(--space-3, 0.75rem);
    padding: var(--space-4, 1rem) var(--space-6, 1.5rem);
    overflow-x: auto;
    height: 100%;
    align-items: flex-start;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  /* ── Column ───────────────────────────────────────────────────────────── */
  .kb-col {
    display: flex;
    flex-direction: column;
    width: 272px;
    flex-shrink: 0;
    border-radius: var(--radius-xl, 12px);
    overflow: hidden;
    background: var(--glass-bg, rgba(255, 255, 255, 0.06));
    backdrop-filter: var(--glass-blur, blur(20px) saturate(180%));
    -webkit-backdrop-filter: var(--glass-blur, blur(20px) saturate(180%));
    border: 1px solid var(--glass-border, rgba(255, 255, 255, 0.1));
    box-shadow: var(--glass-shadow, 0 8px 32px 0 rgba(0, 0, 0, 0.2));
    max-height: calc(100vh - 10rem);
  }

  /* Subtle status accent — left border stripe only */
  .kb-col--todo        { border-left: 2px solid oklch(0.75 0.15 60 / 0.6); }
  .kb-col--inprogress  { border-left: 2px solid oklch(0.78 0.18 145 / 0.6); }
  .kb-col--done        { border-left: 2px solid oklch(0.72 0.09 145 / 0.5); }
  .kb-col--cancelled   { border-left: 2px solid oklch(0.65 0.20 25 / 0.4); }

  .kb-col__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-2, 0.5rem) var(--space-3, 0.75rem);
    border-bottom: 1px solid var(--border, rgba(255, 255, 255, 0.08));
    flex-shrink: 0;
  }

  .kb-col__label {
    font-family: var(--font-sans);
    font-size: var(--text-xs, 0.75rem);
    font-weight: 600;
    color: var(--fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .kb-col__count {
    font-family: var(--font-mono);
    font-size: var(--text-xs, 0.75rem);
    color: var(--fg-subtle);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    border-radius: 9999px;
    padding: 1px 7px;
    min-width: 20px;
    text-align: center;
  }

  /* ── Drop zone ────────────────────────────────────────────────────────── */
  .kb-col__dropzone {
    display: flex;
    flex-direction: column;
    gap: var(--space-2, 0.5rem);
    padding: var(--space-2, 0.5rem);
    flex: 1;
    overflow-y: auto;
    min-height: 160px;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
    transition: outline 120ms ease;
    border-radius: 0 0 var(--radius-xl, 12px) var(--radius-xl, 12px);
    outline: 2px solid transparent;
    outline-offset: -2px;
  }

  /* svelte-dnd-action adds this class when dragging over */
  :global(.kb-col__dropzone--over) {
    outline: 2px solid color-mix(in oklch, var(--cnp-accent, oklch(0.78 0.18 145)) 70%, transparent) !important;
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.78 0.18 145)) 5%, transparent) !important;
  }

  .kb-col__empty {
    font-family: var(--font-sans);
    font-size: var(--text-xs, 0.75rem);
    color: var(--fg-subtle);
    text-align: center;
    padding: var(--space-8, 2rem) 0;
    margin: 0;
  }

  /* ── Card ─────────────────────────────────────────────────────────────── */
  .kb-card {
    display: flex;
    flex-direction: column;
    gap: var(--space-1, 0.25rem);
    padding: var(--space-2, 0.5rem) var(--space-3, 0.75rem);
    background: var(--bg-elevated, rgba(255, 255, 255, 0.04));
    border: 1px solid var(--border, rgba(255, 255, 255, 0.08));
    border-radius: var(--radius-lg, 8px);
    box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.06);
    cursor: grab;
    text-align: left;
    width: 100%;
    transition:
      box-shadow var(--dur-fast, 160ms) var(--ease-out, cubic-bezier(0.16, 1, 0.3, 1)),
      transform var(--dur-fast, 160ms) var(--ease-out, cubic-bezier(0.16, 1, 0.3, 1));
    font-family: var(--font-sans);
  }

  .kb-card:hover {
    box-shadow: 0 3px 10px 0 rgba(0, 0, 0, 0.12);
    transform: translateY(-1px);
    border-color: color-mix(in oklch, var(--fg) 20%, transparent);
  }

  .kb-card:focus-visible {
    outline: 2px solid var(--cnp-accent, oklch(0.78 0.18 145));
    outline-offset: 2px;
  }

  .kb-card:active {
    cursor: grabbing;
  }

  /* Ghost placeholder shown during drag */
  .kb-card--ghost {
    opacity: 0.35;
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.78 0.18 145)) 15%, transparent);
    border: 1.5px dashed color-mix(in oklch, var(--cnp-accent, oklch(0.78 0.18 145)) 50%, transparent);
    min-height: 60px;
    pointer-events: none;
  }

  .kb-card__id {
    margin: 0;
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    letter-spacing: 0.02em;
  }

  .kb-card__title {
    margin: 0;
    font-size: var(--text-sm, 0.875rem);
    font-weight: 500;
    color: var(--fg);
    line-height: 1.35;
    /* 2-line clamp */
    display: -webkit-box;
    -webkit-box-orient: vertical;
    -webkit-line-clamp: 2;
    overflow: hidden;
  }

  .kb-card__footer {
    display: flex;
    align-items: center;
    gap: var(--space-2, 0.5rem);
    margin-top: var(--space-1, 0.25rem);
  }

  .kb-card__priority-dot {
    width: 7px;
    height: 7px;
    border-radius: 9999px;
    flex-shrink: 0;
  }

  .kb-card__assignee {
    font-size: 12px;
    line-height: 1;
    flex-shrink: 0;
  }

  .kb-card__due {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-muted);
    margin-left: auto;
    white-space: nowrap;
  }

  .kb-card__due--overdue {
    color: var(--signal-error, oklch(0.65 0.20 25));
  }
</style>
