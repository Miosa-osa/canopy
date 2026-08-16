<script lang="ts">
  /**
   * TasksWidget — Kanban snapshot: task counts per status column.
   * CSS prefix: tw- (TasksWidget)
   */
  import { createQuery } from '@tanstack/svelte-query';
  import { writable } from 'svelte/store';
  import { untrack } from 'svelte';
  import { goto } from '$app/navigation';
  import { tasksQuery } from '$lib/api/queries/tasks.js';
  import type { Task, TaskStatus } from '$lib/domain/tasks/types.js';
  import type { CreateQueryOptions } from '@tanstack/svelte-query';

  const optsStore = writable(
    untrack(() => tasksQuery() as CreateQueryOptions<Task[]>),
  );
  const query = createQuery<Task[]>(optsStore);

  const STATUSES: { status: TaskStatus; label: string }[] = [
    { status: 'todo', label: 'Todo' },
    { status: 'in_progress', label: 'In Progress' },
    { status: 'done', label: 'Done' },
    { status: 'cancelled', label: 'Cancelled' },
  ];

  const allTasks = $derived(($query.data ?? []) as Task[]);

  const counts = $derived<Record<TaskStatus, number>>({
    todo: allTasks.filter((t) => t.status === 'todo').length,
    in_progress: allTasks.filter((t) => t.status === 'in_progress').length,
    done: allTasks.filter((t) => t.status === 'done').length,
    cancelled: allTasks.filter((t) => t.status === 'cancelled').length,
  });
</script>

<div class="tw-widget">
  {#if $query.isLoading}
    <p class="tw-empty">Loading…</p>
  {:else if $query.isError}
    <p class="tw-error">Failed to load tasks</p>
  {:else}
    <div class="tw-cols" aria-label="Task counts by status">
      {#each STATUSES as col (col.status)}
        <button
          class="tw-col tw-col--{col.status}"
          onclick={() => goto(`/tasks?status=${col.status}`)}
          aria-label="{counts[col.status]} {col.label} tasks"
        >
          <span class="tw-col-count">{counts[col.status]}</span>
          <span class="tw-col-label">{col.label}</span>
        </button>
      {/each}
    </div>
  {/if}
</div>

<style>
  .tw-widget {
    padding: var(--space-3);
    display: flex;
    flex-direction: column;
  }

  .tw-cols {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: var(--space-2);
  }

  .tw-col {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-1);
    padding: var(--space-3) var(--space-2);
    border-radius: var(--radius-md);
    border: 1px solid var(--border);
    background: color-mix(in oklch, var(--fg) 3%, transparent);
    cursor: pointer;
    transition: background var(--dur-instant) ease, border-color var(--dur-instant) ease;
    font-family: inherit;
  }

  .tw-col:hover {
    background: color-mix(in oklch, var(--fg) 7%, transparent);
    border-color: color-mix(in oklch, var(--fg) 20%, transparent);
  }

  .tw-col:focus-visible {
    outline: 2px solid var(--fg-muted);
    outline-offset: 2px;
  }

  /* Subtle left accent per status */
  .tw-col--todo        { border-left: 2px solid oklch(0.75 0.15 60 / 0.6); }
  .tw-col--in_progress { border-left: 2px solid oklch(0.78 0.18 145 / 0.6); }
  .tw-col--done        { border-left: 2px solid oklch(0.72 0.09 145 / 0.5); }
  .tw-col--cancelled   { border-left: 2px solid oklch(0.65 0.20 25 / 0.4); }

  .tw-col-count {
    font-family: var(--font-mono);
    font-size: 22px;
    font-weight: 700;
    color: var(--fg);
    line-height: 1;
    letter-spacing: -0.02em;
  }

  .tw-col-label {
    font-family: var(--font-sans);
    font-size: 9px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    text-align: center;
    line-height: 1.2;
  }

  .tw-empty,
  .tw-error {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
  }

  .tw-empty { color: var(--fg-subtle); }
  .tw-error { color: var(--signal-error, oklch(0.65 0.20 25)); }
</style>
