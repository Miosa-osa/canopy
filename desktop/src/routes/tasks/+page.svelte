<script lang="ts">
/**
 * /tasks — Task list with multi-board Kanban support.
 * CSS prefix: tl- (TaskList)
 */
import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { page } from '$app/state';
import { tasksQuery } from '$lib/api/queries/tasks.js';
import KanbanBoard from '$lib/design/patterns/KanbanBoard.svelte';
import BoardEditor from '$lib/design/patterns/kanban/BoardEditor.svelte';
import BoardPicker from '$lib/design/patterns/kanban/BoardPicker.svelte';
import TaskCreateForm from '$lib/design/patterns/tasks/TaskCreateForm.svelte';
import TasksFilterBar from '$lib/design/patterns/tasks/TasksFilterBar.svelte';
import TasksListView from '$lib/design/patterns/tasks/TasksListView.svelte';
import type { ViewState } from '$lib/design/primitives/ViewPicker.svelte';
import ViewPicker from '$lib/design/primitives/ViewPicker.svelte';
import type { Task, TaskFilters, TaskStatus } from '$lib/domain/tasks/types.js';
import { type BoardConfig, kanbanBoards } from '$lib/stores/kanban-boards.svelte.js';

// ── Deep-link: ?board=<id> ────────────────────────────────────────────────────

$effect(() => {
  const boardId = page.url.searchParams.get('board');
  if (boardId && kanbanBoards.boards.some((b) => b.id === boardId)) {
    kanbanBoards.setActive(boardId);
  }
});

// ── Board editor modal ────────────────────────────────────────────────────────

let editorOpen = $state(false);
let editorTarget = $state<BoardConfig | null>(null);

function openNew(): void {
  editorTarget = null;
  editorOpen = true;
}

function openEdit(): void {
  editorTarget = kanbanBoards.activeBoard ?? null;
  editorOpen = true;
}

function closeEditor(): void {
  editorOpen = false;
  editorTarget = null;
}

// ── View state (via ViewPicker) ───────────────────────────────────────────────

let view = $state<ViewState>({ layout: 'list', density: 'comfortable', sort: 'recent' });

// Derive viewMode from ViewPicker layout for existing KanbanBoard/TasksListView
const viewMode = $derived<'list' | 'board'>(view.layout === 'board' ? 'board' : 'list');

// ── Board-scoped filters ──────────────────────────────────────────────────────

const boardFilters = $derived<TaskFilters>(
  (() => {
    const scope = kanbanBoards.activeBoard?.scope;
    if (!scope) return {};
    switch (scope.type) {
      case 'agent':
        return { assigneeType: 'agent', assigneeId: scope.agentId };
      case 'assignee_type':
        return { assigneeType: scope.value };
      case 'workspace':
      default:
        return {};
    }
  })()
);

// ── Status filter + search ────────────────────────────────────────────────────

type StatusChip = 'all' | TaskStatus;

let statusChip = $state<StatusChip>('all');
let searchText = $state('');

const filters = $derived<TaskFilters>({
  ...boardFilters,
  status: statusChip !== 'all' ? statusChip : undefined,
  q: searchText.trim() || undefined,
});

// ── Whether active board has non-default columns ──────────────────────────────

const hasCustomColumns = $derived(
  (() => {
    const cols = kanbanBoards.activeBoard?.columns;
    if (!cols) return false;
    const defaultStatuses = ['todo', 'in_progress', 'done', 'cancelled'];
    const activeStatuses = cols.map((c) => c.status);
    return (
      activeStatuses.length !== defaultStatuses.length ||
      activeStatuses.some((s, i) => s !== defaultStatuses[i])
    );
  })()
);

// ── Query (list view) ─────────────────────────────────────────────────────────

const queryOptsStore = writable(untrack(() => tasksQuery(filters) as CreateQueryOptions<Task[]>));

$effect(() => {
  queryOptsStore.set(tasksQuery(filters) as CreateQueryOptions<Task[]>);
});

const query = createQuery<Task[]>(queryOptsStore);
const tasks = $derived(($query.data ?? []) as Task[]);

// ── Create form ───────────────────────────────────────────────────────────────

let createOpen = $state(false);
</script>

<div class="tl-page">
  <!-- Header -->
  <header class="tl-header">
    <h1 class="tl-title">Tasks</h1>

    <!-- Board picker (board view only) -->
    {#if viewMode === 'board'}
      <BoardPicker onNew={openNew} onEdit={openEdit} />
    {/if}

    <!-- ViewPicker (replaces manual list/board toggle) -->
    <ViewPicker routeSlug="tasks" bind:view boardEnabled={true} />

    <button
      class="btn-pill btn-pill-primary btn-pill-sm"
      onclick={() => { createOpen = true; }}
      aria-label="Create new task"
    >
      + New task
    </button>
  </header>

  <!-- Filter bar -->
  <TasksFilterBar
    {statusChip}
    {searchText}
    onStatusChange={(chip) => { statusChip = chip; }}
    onSearchChange={(text) => { searchText = text; }}
  />

  <!-- Custom-columns degradation banner (board view only) -->
  {#if viewMode === 'board' && hasCustomColumns}
    <p class="tl-custom-col-banner" role="status">
      Custom columns support coming — using default lanes.
    </p>
  {/if}

  <!-- Inline create form -->
  {#if createOpen}
    <TaskCreateForm onClose={() => { createOpen = false; }} />
  {/if}

  <!-- Board view -->
  {#if viewMode === 'board'}
    <KanbanBoard filters={filters} />
  {:else}
    <TasksListView
      {tasks}
      isLoading={$query.isLoading}
      isError={$query.isError}
      errorMessage={($query.error as Error)?.message || 'Check your connection and try again.'}
      statusChip={statusChip}
      searchText={searchText}
      onRetry={() => $query.refetch()}
      onNewTask={() => { createOpen = true; }}
    />
  {/if}
</div>

<!-- Board editor modal (portal-style: outside tl-page) -->
{#if editorOpen}
  <BoardEditor board={editorTarget} onClose={closeEditor} />
{/if}

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

  /* Custom columns degradation banner */
  .tl-custom-col-banner {
    margin: 0;
    padding: 6px 12px;
    border-radius: var(--radius-md);
    border: 1px solid var(--border);
    background: var(--bg-inset);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }
</style>
