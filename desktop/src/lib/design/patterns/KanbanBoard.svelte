<script lang="ts">
  /**
   * KanbanBoard — 4-column drag-and-drop task board.
   * CSS prefix: kb- (KanbanBoard)
   *
   * Upgrades (v2):
   * - Inline title edit on double-click (Enter saves, Esc cancels)
   * - Card hover menu: Edit, Delete, Dispatch to agent
   * - Agent chip: shows assigned_agent_id initial → goto /agents/:slug
   * - Session link: task.session_id terminal icon → goto /sessions/:id
   * - Column WIP limits with amber warning on overflow
   * - Dispatch → POST /tasks/:id/dispatch (expect 404 → toast)
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
  import {
    tasksQuery,
    updateTaskMutation,
    deleteTaskMutation,
    transitionTask,
  } from '$lib/api/queries/tasks.js';
  import { toasts } from '$lib/stores/toasts.svelte.js';
  import type { Task, TaskFilters, TaskStatus, UpdateTaskBody } from '$lib/domain/tasks/types.js';
  import { inferVerb, type TransitionVerb } from '$lib/stores/kanban-boards.svelte.js';
  import { writable } from 'svelte/store';
  import { untrack } from 'svelte';
  import { apiPost } from '$lib/api/client.js';
  import KanbanCard from '$lib/design/patterns/kanban/KanbanCard.svelte';

  // ── Props ──────────────────────────────────────────────────────────────────

  interface Props {
    filters?: TaskFilters;
    /** Per-column verb override map — keyed by TaskStatus. Falls back to inferVerb(). */
    columnVerbs?: Partial<Record<TaskStatus, TransitionVerb>>;
  }

  let { filters = {}, columnVerbs = {} }: Props = $props();

  // ── Query ──────────────────────────────────────────────────────────────────

  const queryOptsStore = writable(
    untrack(() => tasksQuery(filters) as CreateQueryOptions<Task[]>),
  );

  $effect(() => {
    queryOptsStore.set(tasksQuery(filters) as CreateQueryOptions<Task[]>);
  });

  const query = createQuery<Task[]>(queryOptsStore);
  const queryClient = useQueryClient();

  // ── Mutations ─────────────────────────────────────────────────────────────

  const updateMut = createMutation<Task, Error, { shortId: string; body: UpdateTaskBody }>(
    updateTaskMutation() as CreateMutationOptions<Task, Error, { shortId: string; body: UpdateTaskBody }>,
  );

  const deleteMut = createMutation<void, Error, string>(
    deleteTaskMutation() as CreateMutationOptions<void, Error, string>,
  );

  // ── Column config ──────────────────────────────────────────────────────────

  const WIP_LIMITS: Record<TaskStatus, number> = {
    todo: 999,
    in_progress: 5,
    done: 999,
    cancelled: 999,
  };

  const COLUMNS: { status: TaskStatus; label: string; colorClass: string }[] = [
    { status: 'todo',        label: 'Todo',        colorClass: 'kb-col--todo' },
    { status: 'in_progress', label: 'In Progress', colorClass: 'kb-col--inprogress' },
    { status: 'done',        label: 'Done',         colorClass: 'kb-col--done' },
    { status: 'cancelled',   label: 'Cancelled',    colorClass: 'kb-col--cancelled' },
  ];

  // ── Column state ───────────────────────────────────────────────────────────

  type Columns = Record<TaskStatus, Task[]>;

  function buildColumns(tasks: Task[]): Columns {
    return {
      todo:        tasks.filter((t) => t.status === 'todo'),
      in_progress: tasks.filter((t) => t.status === 'in_progress'),
      done:        tasks.filter((t) => t.status === 'done'),
      cancelled:   tasks.filter((t) => t.status === 'cancelled'),
    };
  }

  let columns = $state<Columns>({
    todo: [],
    in_progress: [],
    done: [],
    cancelled: [],
  });

  let dragging = $state(false);

  $effect(() => {
    const tasks = ($query.data ?? []) as Task[];
    if (!dragging) {
      columns = buildColumns(tasks);
    }
  });

  // ── DnD handlers ──────────────────────────────────────────────────────────

  function handleConsider(status: TaskStatus, e: CustomEvent<DndEvent<Task>>) {
    dragging = true;
    columns = { ...columns, [status]: e.detail.items };
  }

  function handleFinalize(status: TaskStatus, e: CustomEvent<DndEvent<Task>>) {
    dragging = false;
    const newItems = e.detail.items;
    columns = { ...columns, [status]: newItems };

    const moved = newItems.find(
      (t) => t.id !== SHADOW_PLACEHOLDER_ITEM_ID && t.status !== status,
    );

    if (!moved) return;

    // Snapshot for revert on error
    const prevColumns = buildColumns(($query.data ?? []) as Task[]);

    // Optimistic update
    const updatedItems = newItems.map((t) =>
      t.id === moved.id ? { ...t, status } : t,
    );
    columns = { ...columns, [status]: updatedItems };

    // Resolve verb: prop override → inference from status
    const verb: TransitionVerb = columnVerbs[status] ?? inferVerb(status);

    void (async () => {
      try {
        const result = await transitionTask(moved.shortId, status, verb);
        queryClient.invalidateQueries({ queryKey: ['tasks'] });

        if (verb === 'start' || verb === 'build') {
          const sessionId = (result as Task & { sessionId?: string }).sessionId;
          if (sessionId) {
            toasts.success('Dispatched');
            goto(`/sessions/${sessionId}`);
          } else {
            toasts.success('Dispatched');
          }
        } else if (verb === 'pause') {
          toasts.success('Paused — terminal stays alive');
        } else if (verb === 'stop') {
          toasts.info('Stopped');
        } else if (verb === 'done') {
          toasts.success('Completed');
        } else {
          toasts.success('Status updated');
        }
      } catch (err) {
        const isNotFound =
          err instanceof Error &&
          (err.message.includes('404') || err.message.includes('HTTP 404'));
        if (isNotFound) {
          // Endpoint not deployed yet — fall back to PATCH status-only
          $updateMut.mutate(
            { shortId: moved.shortId, body: { status } },
            {
              onSuccess: () => {
                queryClient.invalidateQueries({ queryKey: ['tasks'] });
                toasts.info('Status updated (terminal untouched)');
              },
              onError: () => {
                columns = prevColumns;
                toasts.error('Failed to update task status');
              },
            },
          );
        } else {
          // 422 or other — revert and surface the server message
          columns = prevColumns;
          const message = err instanceof Error ? err.message : 'Transition failed';
          toasts.error(message);
        }
      }
    })();
  }

  // ── Inline edit state ─────────────────────────────────────────────────────

  let editingId = $state<string | null>(null);
  let editingTitle = $state('');

  function startEdit(task: Task) {
    editingId = task.id;
    editingTitle = task.title;
  }

  function cancelEdit() {
    editingId = null;
    editingTitle = '';
  }

  function commitEdit(task: Task) {
    const newTitle = editingTitle.trim();
    if (!newTitle || newTitle === task.title) {
      cancelEdit();
      return;
    }
    $updateMut.mutate(
      { shortId: task.shortId, body: { title: newTitle } },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: ['tasks'] });
          toasts.success('Task updated');
        },
        onError: () => {
          toasts.error('Failed to update task');
        },
      },
    );
    cancelEdit();
  }

  function handleEditKeydown(e: KeyboardEvent, task: Task) {
    if (e.key === 'Enter') {
      e.preventDefault();
      commitEdit(task);
    } else if (e.key === 'Escape') {
      cancelEdit();
    }
  }

  // ── Card menu state ───────────────────────────────────────────────────────

  let menuOpenId = $state<string | null>(null);

  function toggleMenu(id: string) {
    menuOpenId = menuOpenId === id ? null : id;
  }

  function closeMenu() {
    menuOpenId = null;
  }

  function handleDelete(task: Task) {
    closeMenu();
    $deleteMut.mutate(task.shortId, {
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: ['tasks'] });
        toasts.success('Task deleted');
      },
      onError: () => {
        toasts.error('Failed to delete task');
      },
    });
  }

  async function handleDispatch(task: Task) {
    closeMenu();
    try {
      // TODO: subscribe to PubSub task:dispatched events to replace the refetch after dispatch.
      // Backend broadcasts {:task_dispatched, %{task_id, session_id, status}} on
      // `tasks:workspace:<workspace_slug>` via Phoenix.PubSub when dispatch succeeds.
      const result = await apiPost<{ session_id: string; task: unknown }>(
        `/tasks/${task.shortId}/dispatch`,
        {},
      );
      toasts.success('Task dispatched');
      if (result?.session_id) {
        goto(`/sessions/${result.session_id}`);
      }
    } catch {
      toasts.error('Dispatch failed — set an agent assignee first.');
    }
  }

  function visibleCount(items: Task[]): number {
    return items.filter((t) => t.id !== SHADOW_PLACEHOLDER_ITEM_ID).length;
  }

  const FLIP_MS = 200;
</script>

<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
<div class="kb-board" role="region" aria-label="Kanban board" onclick={() => { menuOpenId = null; }}>
  {#each COLUMNS as col (col.status)}
    {@const items = columns[col.status]}
    {@const count = visibleCount(items)}
    {@const wip = WIP_LIMITS[col.status]}
    {@const overWip = wip < 999 && count > wip}
    <div class="kb-col {col.colorClass}">
      <!-- Column header -->
      <header class="kb-col__header" class:kb-col__header--over={overWip}>
        <span class="kb-col__label">{col.label}</span>
        <span
          class="kb-col__count"
          class:kb-col__count--over={overWip}
          aria-label="{count} tasks{wip < 999 ? `, limit ${wip}` : ''}"
        >
          {count}{wip < 999 ? ` / ${wip}` : ''}
        </span>
      </header>

      <!-- Drop zone -->
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div
        class="kb-col__dropzone"
        use:dndzone={{
          items,
          flipDurationMs: FLIP_MS,
          dragDisabled: editingId !== null,
          dropTargetClasses: ['kb-col__dropzone--over'],
          type: 'kanban-task',
        }}
        onconsider={(e) => handleConsider(col.status, e)}
        onfinalize={(e) => handleFinalize(col.status, e)}
      >
        {#each items as task (task.id)}
          {#if task.id === SHADOW_PLACEHOLDER_ITEM_ID}
            <div class="kb-card--ghost" aria-hidden="true"></div>
          {:else}
            <KanbanCard
              {task}
              isEditing={editingId === task.id}
              editingTitle={editingId === task.id ? editingTitle : ''}
              menuOpen={menuOpenId === task.id}
              onStartEdit={startEdit}
              onCommitEdit={commitEdit}
              onCancelEdit={cancelEdit}
              onEditKeydown={handleEditKeydown}
              onEditTitleChange={(v) => { editingTitle = v; }}
              onToggleMenu={toggleMenu}
              onDelete={handleDelete}
              onDispatch={handleDispatch}
            />
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

  .kb-col--todo        { border-left: 2px solid color-mix(in oklch, var(--priority) 60%, transparent); }
  .kb-col--inprogress  { border-left: 2px solid color-mix(in oklch, var(--success) 60%, transparent); }
  .kb-col--done        { border-left: 2px solid color-mix(in oklch, var(--success) 50%, transparent); }
  .kb-col--cancelled   { border-left: 2px solid color-mix(in oklch, var(--destructive) 40%, transparent); }

  .kb-col__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-2, 0.5rem) var(--space-3, 0.75rem);
    border-bottom: 1px solid var(--border, rgba(255, 255, 255, 0.08));
    flex-shrink: 0;
    transition: background var(--dur-instant) ease;
  }

  .kb-col__header--over {
    background: color-mix(in oklch, var(--priority) 10%, transparent);
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
    transition: color var(--dur-instant) ease, background var(--dur-instant) ease;
  }

  .kb-col__count--over {
    color: var(--priority);
    background: color-mix(in oklch, var(--priority) 15%, transparent);
    font-weight: 600;
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

  /* Ghost card (DnD placeholder) */
  .kb-card--ghost {
    opacity: 0.35;
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.78 0.18 145)) 15%, transparent);
    border: 1.5px dashed color-mix(in oklch, var(--cnp-accent, oklch(0.78 0.18 145)) 50%, transparent);
    border-radius: var(--radius-lg, 8px);
    min-height: 60px;
    pointer-events: none;
  }
</style>
