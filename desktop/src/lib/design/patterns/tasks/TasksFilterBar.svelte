<script lang="ts">
  /**
   * TasksFilterBar — status chip filter + search input for the tasks page.
   * CSS prefix: tl- (shared with /tasks page).
   */
  import type { TaskStatus } from '$lib/domain/tasks/types.js';

  type StatusChip = 'all' | TaskStatus;

  interface Props {
    statusChip: StatusChip;
    searchText: string;
    onStatusChange: (chip: StatusChip) => void;
    onSearchChange: (text: string) => void;
  }

  let { statusChip, searchText, onStatusChange, onSearchChange }: Props = $props();

  const STATUS_CHIPS: { value: StatusChip; label: string }[] = [
    { value: 'all', label: 'All' },
    { value: 'todo', label: 'Todo' },
    { value: 'in_progress', label: 'In Progress' },
    { value: 'done', label: 'Done' },
    { value: 'cancelled', label: 'Cancelled' },
  ];
</script>

<div class="tl-filters" role="search" aria-label="Filter tasks">
  <div class="tl-chips" role="group" aria-label="Status filter">
    {#each STATUS_CHIPS as chip (chip.value)}
      <button
        class="tl-chip"
        class:tl-chip--active={statusChip === chip.value}
        onclick={() => onStatusChange(chip.value)}
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
    value={searchText}
    oninput={(e) => onSearchChange((e.currentTarget as HTMLInputElement).value)}
    aria-label="Search tasks"
  />
</div>

<style>
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
</style>
