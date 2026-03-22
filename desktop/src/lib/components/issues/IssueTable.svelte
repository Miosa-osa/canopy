<!-- src/lib/components/issues/IssueTable.svelte -->
<!-- Sortable data table view for issues -->
<script lang="ts">
  import type { Issue } from '$api/types';
  import { issuesStore, resolveAssigneeName } from '$lib/stores/issues.svelte';
  import TimeAgo from '$lib/components/shared/TimeAgo.svelte';

  let dispatching = $state<Record<string, boolean>>({});

  function canDispatch(issue: Issue): boolean {
    return (
      issue.assignee_id !== null &&
      (issue.status === 'backlog' || issue.status === 'todo')
    );
  }

  async function handleDispatch(e: MouseEvent, issue: Issue) {
    e.stopPropagation();
    dispatching[issue.id] = true;
    await issuesStore.dispatch(issue.id);
    dispatching[issue.id] = false;
  }

  interface Props {
    issues: Issue[];
  }

  let { issues }: Props = $props();

  type SortField = 'priority' | 'title' | 'status' | 'updated_at' | 'comments_count';

  let sortField = $state<SortField>('updated_at');
  let sortAsc = $state(false);

  function toggleSort(field: SortField) {
    if (sortField === field) {
      sortAsc = !sortAsc;
    } else {
      sortField = field;
      sortAsc = field === 'title';
    }
  }

  const PRIORITY_ORDER: Record<string, number> = { critical: 0, high: 1, medium: 2, low: 3 };
  const STATUS_ORDER: Record<string, number> = { todo: 0, in_progress: 1, in_review: 2, backlog: 3, done: 4 };

  let sorted = $derived.by(() => {
    return [...issues].sort((a, b) => {
      let cmp = 0;
      if (sortField === 'priority') cmp = PRIORITY_ORDER[a.priority] - PRIORITY_ORDER[b.priority];
      else if (sortField === 'title') cmp = a.title.localeCompare(b.title);
      else if (sortField === 'status') cmp = STATUS_ORDER[a.status] - STATUS_ORDER[b.status];
      else if (sortField === 'updated_at') cmp = new Date(a.updated_at).getTime() - new Date(b.updated_at).getTime();
      else if (sortField === 'comments_count') cmp = a.comments_count - b.comments_count;
      return sortAsc ? cmp : -cmp;
    });
  });

  const PRIORITY_COLORS: Record<string, string> = {
    low: '#3b82f6', medium: '#f59e0b', high: '#f97316', critical: '#ef4444',
  };

  const STATUS_LABELS: Record<string, string> = {
    backlog: 'Backlog', todo: 'Todo', in_progress: 'In Progress', in_review: 'In Review', done: 'Done',
  };

  const LABEL_COLORS = ['#3b82f6','#8b5cf6','rgba(34,197,94,0.7)','#f59e0b','#ec4899','#06b6d4'];
  function labelColor(label: string): string {
    let hash = 0;
    for (let i = 0; i < label.length; i++) hash = (hash * 31 + label.charCodeAt(i)) | 0;
    return LABEL_COLORS[Math.abs(hash) % LABEL_COLORS.length];
  }

  function sortIcon(field: SortField): string {
    if (sortField !== field) return 'M8 9l4-4 4 4M16 15l-4 4-4-4';
    return sortAsc ? 'M5 15l7-7 7 7' : 'M19 9l-7 7-7-7';
  }
</script>

<div class="it-wrap" role="region" aria-label="Issues table">
  {#if sorted.length === 0}
    <div class="it-empty" role="status">No issues match your filters.</div>
  {:else}
    <table class="it-table" aria-label="Issues">
      <thead>
        <tr>
          <th class="it-th it-th--priority" scope="col">
            <button class="it-sort-btn" onclick={() => toggleSort('priority')} aria-label="Sort by priority">
              Priority
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                <path d={sortIcon('priority')} />
              </svg>
            </button>
          </th>
          <th class="it-th it-th--title" scope="col">
            <button class="it-sort-btn" onclick={() => toggleSort('title')} aria-label="Sort by title">
              Title
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                <path d={sortIcon('title')} />
              </svg>
            </button>
          </th>
          <th class="it-th" scope="col">
            <button class="it-sort-btn" onclick={() => toggleSort('status')} aria-label="Sort by status">
              Status
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                <path d={sortIcon('status')} />
              </svg>
            </button>
          </th>
          <th class="it-th" scope="col">Assignee</th>
          <th class="it-th" scope="col">Labels</th>
          <th class="it-th it-th--num" scope="col">
            <button class="it-sort-btn" onclick={() => toggleSort('comments_count')} aria-label="Sort by comments">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                <path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/>
              </svg>
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                <path d={sortIcon('comments_count')} />
              </svg>
            </button>
          </th>
          <th class="it-th it-th--date" scope="col">
            <button class="it-sort-btn" onclick={() => toggleSort('updated_at')} aria-label="Sort by updated date">
              Updated
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                <path d={sortIcon('updated_at')} />
              </svg>
            </button>
          </th>
          <th class="it-th it-th--dispatch" scope="col">Dispatch</th>
        </tr>
      </thead>
      <tbody>
        {#each sorted as issue (issue.id)}
          {@const assigneeName = resolveAssigneeName(issue)}
          <tr
            class="it-row"
            class:it-row--selected={issuesStore.selected?.id === issue.id}
            onclick={() => issuesStore.selectIssue(issue)}
            tabindex="0"
            role="button"
            aria-label="Issue: {issue.title}"
            onkeydown={(e) => e.key === 'Enter' && issuesStore.selectIssue(issue)}
          >
            <td class="it-td">
              <span
                class="it-priority-dot"
                style="background: {PRIORITY_COLORS[issue.priority] ?? '#666'}"
                aria-label="Priority: {issue.priority}"
              ></span>
              <span class="it-priority-label">{issue.priority}</span>
            </td>
            <td class="it-td it-td--title">
              <span class="it-title">{issue.title}</span>
            </td>
            <td class="it-td">
              <span class="it-status-text">{STATUS_LABELS[issue.status] ?? issue.status}</span>
            </td>
            <td class="it-td">
              {#if issue.assignee_id}
                <div class="it-assignee">
                  <span class="it-avatar" aria-hidden="true">{assigneeName[0].toUpperCase()}</span>
                  <span class="it-assignee-name">{assigneeName}</span>
                </div>
              {:else}
                <span class="it-none">—</span>
              {/if}
            </td>
            <td class="it-td">
              <div class="it-labels">
                {#each issue.labels.slice(0, 2) as label (label)}
                  <span
                    class="it-label"
                    style="background: {labelColor(label)}22; color: {labelColor(label)}; border-color: {labelColor(label)}44"
                  >{label}</span>
                {/each}
                {#if issue.labels.length > 2}
                  <span class="it-label-more">+{issue.labels.length - 2}</span>
                {/if}
              </div>
            </td>
            <td class="it-td it-td--num">
              {issue.comments_count > 0 ? issue.comments_count : ''}
            </td>
            <td class="it-td it-td--date">
              <TimeAgo date={issue.updated_at} />
            </td>
            <td class="it-td it-td--dispatch">
              {#if canDispatch(issue)}
                <button
                  class="it-dispatch-btn"
                  class:it-dispatch-btn--loading={dispatching[issue.id]}
                  onclick={(e) => handleDispatch(e, issue)}
                  disabled={dispatching[issue.id]}
                  aria-label="Dispatch issue to {assigneeName}"
                  type="button"
                >
                  {#if dispatching[issue.id]}
                    <span class="it-dispatch-spinner" aria-hidden="true"></span>
                  {:else}
                    <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true">
                      <path d="M22 2L11 13M22 2l-7 20-4-9-9-4 20-7z" />
                    </svg>
                    <span class="it-dispatch-agent">{assigneeName}</span>
                  {/if}
                </button>
              {/if}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
</div>

<style>
  .it-wrap {
    width: 100%;
    overflow-x: auto;
  }

  .it-empty {
    padding: 40px 16px;
    text-align: center;
    color: var(--text-tertiary);
    font-size: 13px;
  }

  .it-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
  }

  .it-th {
    padding: 8px 12px;
    text-align: left;
    font-size: 11px;
    font-weight: 600;
    color: var(--text-tertiary);
    text-transform: uppercase;
    letter-spacing: 0.04em;
    border-bottom: 1px solid var(--border-default);
    white-space: nowrap;
  }

  .it-th--priority { width: 100px; }
  .it-th--title    { min-width: 200px; }
  .it-th--num      { width: 48px; text-align: center; }
  .it-th--date     { width: 80px; text-align: right; }
  .it-th--dispatch { width: 120px; text-align: right; }

  .it-sort-btn {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    background: none;
    border: none;
    color: inherit;
    font: inherit;
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    cursor: pointer;
    padding: 0;
  }

  .it-sort-btn:hover { color: var(--text-secondary); }
  .it-sort-btn:focus-visible {
    outline: 2px solid var(--accent-primary);
    border-radius: 2px;
  }

  .it-row {
    border-bottom: 1px solid var(--border-default);
    cursor: pointer;
    transition: background 100ms ease;
  }

  .it-row:hover { background: rgba(255,255,255,0.03); }
  .it-row--selected { background: rgba(59,130,246,0.07); }
  .it-row:focus-visible {
    outline: 2px solid var(--accent-primary);
    outline-offset: -2px;
  }

  .it-td {
    padding: 0 12px;
    height: 40px;
    vertical-align: middle;
    white-space: nowrap;
    color: var(--text-secondary);
  }

  .it-td--title    { max-width: 300px; }
  .it-td--num      { text-align: center; color: var(--text-tertiary); }
  .it-td--date     { text-align: right; }
  .it-td--dispatch { text-align: right; }

  .it-priority-dot {
    display: inline-block;
    width: 8px;
    height: 8px;
    border-radius: 50%;
    margin-right: 6px;
    vertical-align: middle;
    flex-shrink: 0;
  }

  .it-priority-label {
    font-size: 12px;
    color: var(--text-secondary);
    text-transform: capitalize;
  }

  .it-title {
    font-size: 13px;
    font-weight: 500;
    color: var(--text-primary);
    overflow: hidden;
    text-overflow: ellipsis;
    display: block;
  }

  .it-status-text {
    font-size: 12px;
    color: var(--text-secondary);
  }

  .it-assignee {
    display: flex;
    align-items: center;
    gap: 5px;
  }

  .it-avatar {
    width: 18px;
    height: 18px;
    border-radius: 50%;
    background: var(--accent-primary);
    color: #fff;
    font-size: 10px;
    font-weight: 600;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .it-assignee-name {
    font-size: 12px;
    color: var(--text-secondary);
  }

  .it-none { color: var(--text-muted); }

  .it-labels {
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .it-label {
    font-size: 10px;
    font-weight: 500;
    padding: 1px 6px;
    border-radius: 9999px;
    border: 1px solid transparent;
  }

  .it-label-more {
    font-size: 10px;
    color: var(--text-tertiary);
    padding: 1px 4px;
  }

  .it-dispatch-btn {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    height: 22px;
    padding: 0 8px;
    background: transparent;
    border: 1px solid var(--border-default);
    border-radius: var(--radius-xs);
    color: var(--text-tertiary);
    font-size: 11px;
    font-weight: 500;
    font-family: inherit;
    cursor: pointer;
    white-space: nowrap;
    transition: background 150ms ease, color 150ms ease, border-color 150ms ease;
  }

  .it-dispatch-btn:hover:not(:disabled) {
    background: rgba(34, 197, 94, 0.08);
    border-color: rgba(34, 197, 94, 0.3);
    color: rgba(34, 197, 94, 0.8);
  }

  .it-dispatch-btn:focus-visible {
    outline: 2px solid var(--accent-primary);
    outline-offset: 2px;
  }

  .it-dispatch-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .it-dispatch-btn--loading {
    min-width: 50px;
    justify-content: center;
  }

  .it-dispatch-agent {
    max-width: 80px;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .it-dispatch-spinner {
    width: 10px;
    height: 10px;
    border: 1.5px solid currentColor;
    border-top-color: transparent;
    border-radius: 50%;
    animation: it-spin 0.7s linear infinite;
    flex-shrink: 0;
  }

  @keyframes it-spin {
    to { transform: rotate(360deg); }
  }
</style>
