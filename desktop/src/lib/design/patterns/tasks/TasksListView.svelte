<script lang="ts">
  /**
   * TasksListView — table rendering for the tasks list view.
   * CSS prefix: tl- (shared with /tasks page).
   */
  import { goto } from '$app/navigation';
  import { ClipboardList } from 'lucide-svelte';
  import EmptyState from '$lib/design/patterns/EmptyState.svelte';
  import SkeletonList from '$lib/design/patterns/SkeletonList.svelte';
  import StatusDot from '$lib/design/patterns/StatusDot.svelte';
  import type { Task, TaskStatus } from '$lib/domain/tasks/types.js';

  interface Props {
    tasks: Task[];
    isLoading: boolean;
    isError: boolean;
    errorMessage: string;
    statusChip: string;
    searchText: string;
    onRetry: () => void;
    onNewTask: () => void;
  }

  let {
    tasks,
    isLoading,
    isError,
    errorMessage,
    statusChip,
    searchText,
    onRetry,
    onNewTask,
  }: Props = $props();

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

{#if isError}
  <EmptyState
    title="Couldn't load tasks"
    body={errorMessage || 'Check your connection and try again.'}
    action="Retry"
    onAction={onRetry}
  />
{:else if isLoading}
  <div class="tl-skeleton-wrap">
    <SkeletonList count={8} height="2.5rem" gap="0.375rem" />
  </div>
{:else if tasks.length === 0}
  <EmptyState
    icon={ClipboardList as never}
    title="No tasks"
    body={statusChip !== 'all' || searchText ? 'No tasks match your filters.' : 'Create your first task to get started.'}
    action="+ New task"
    onAction={onNewTask}
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
              {#if task.reviewId}
                <a
                  class="tl-review-pill"
                  href="/reviews/{task.reviewId}"
                  aria-label="Under review — view review"
                  onclick={(e) => e.stopPropagation()}
                >Under review</a>
              {/if}
            </td>
            <td class="tl-td tl-mono tl-td-assignee">
              {#if task.assigneeType && task.assigneeId}
                {task.assigneeType === 'agent' ? '[A]' : '[H]'} {task.assigneeId}
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

<style>
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

  .tl-review-pill {
    display: inline-block;
    margin-left: var(--space-2);
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 500;
    padding: 1px 6px;
    border-radius: var(--radius-sm);
    white-space: nowrap;
    background: color-mix(in oklch, oklch(0.78 0.15 85) 20%, transparent 80%);
    color: color-mix(in oklch, oklch(0.55 0.15 85) 90%, var(--fg) 10%);
    border: 1px solid color-mix(in oklch, oklch(0.78 0.15 85) 40%, transparent 60%);
    text-decoration: none;
    cursor: pointer;
  }

  .tl-review-pill:hover {
    background: color-mix(in oklch, oklch(0.78 0.15 85) 30%, transparent 70%);
  }
</style>
