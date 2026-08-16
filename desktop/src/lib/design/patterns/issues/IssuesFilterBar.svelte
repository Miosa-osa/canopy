<script lang="ts">
  /**
   * IssuesFilterBar — status tabs + assignee select for the issues page.
   * CSS prefix: il- (shared with /issues page).
   */
  import type { IssueStatus } from '$lib/domain/issues/types.js';

  type StatusTab = 'all' | IssueStatus;
  type AssigneeFilter = 'all' | 'human' | 'agent';

  interface Props {
    statusTab: StatusTab;
    assigneeFilter: AssigneeFilter;
    onStatusChange: (tab: StatusTab) => void;
    onAssigneeChange: (filter: AssigneeFilter) => void;
  }

  let { statusTab, assigneeFilter, onStatusChange, onAssigneeChange }: Props = $props();

  const STATUS_TABS: { value: StatusTab; label: string }[] = [
    { value: 'all', label: 'All' },
    { value: 'open', label: 'Open' },
    { value: 'in_progress', label: 'In Progress' },
    { value: 'in_review', label: 'In Review' },
    { value: 'closed', label: 'Closed' },
  ];
</script>

<div class="il-tabs" role="tablist" aria-label="Filter by status">
  {#each STATUS_TABS as tab (tab.value)}
    <button
      class="il-tab"
      class:il-tab--active={statusTab === tab.value}
      role="tab"
      aria-selected={statusTab === tab.value}
      onclick={() => onStatusChange(tab.value)}
    >
      {tab.label}
    </button>
  {/each}

  <div class="il-tabs-spacer"></div>

  <select
    class="il-assignee-select"
    value={assigneeFilter}
    onchange={(e) => onAssigneeChange((e.currentTarget as HTMLSelectElement).value as AssigneeFilter)}
    aria-label="Filter by assignee type"
  >
    <option value="all">All assignees</option>
    <option value="human">Human</option>
    <option value="agent">Agent</option>
  </select>
</div>

<style>
  .il-tabs {
    display: flex;
    align-items: center;
    gap: 0;
    padding: 0 var(--space-6);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    overflow-x: auto;
    scrollbar-width: none;
  }

  .il-tabs::-webkit-scrollbar { display: none; }

  .il-tab {
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg-muted);
    background: transparent;
    border: none;
    border-bottom: 2px solid transparent;
    cursor: pointer;
    white-space: nowrap;
    transition: color 0.12s ease, border-color 0.12s ease;
    margin-bottom: -1px;
  }

  .il-tab:hover { color: var(--fg); }

  .il-tab--active {
    color: var(--fg);
    border-bottom-color: var(--cnp-accent, var(--fg));
  }

  .il-tabs-spacer { flex: 1; }

  .il-assignee-select {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    background: transparent;
    border: none;
    cursor: pointer;
    outline: none;
    padding: var(--space-1) 0;
  }
</style>
