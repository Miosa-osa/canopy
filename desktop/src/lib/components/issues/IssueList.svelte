<!-- src/lib/components/issues/IssueList.svelte -->
<!-- Flat list view of issues with compact 40px rows -->
<script lang="ts">
  import type { Issue } from '$api/types';
  import { issuesStore, resolveAssigneeName } from '$lib/stores/issues.svelte';
  import TimeAgo from '$lib/components/shared/TimeAgo.svelte';

  interface Props {
    issues: Issue[];
  }

  let { issues }: Props = $props();

  // Track per-issue dispatch loading state
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

  const PRIORITY_ICONS: Record<string, { path: string; color: string }> = {
    low:      { path: 'M5 15l7-7 7 7', color: '#3b82f6' },
    medium:   { path: 'M8 12h8', color: '#f59e0b' },
    high:     { path: 'M5 9l7 7 7-7', color: '#f97316' },
    critical: { path: 'M12 9v4m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z', color: '#ef4444' },
  };

  const STATUS_LABELS: Record<string, { label: string; variant: string }> = {
    backlog:     { label: 'Backlog',     variant: 'default' },
    todo:        { label: 'Todo',        variant: 'info'    },
    in_progress: { label: 'In Progress', variant: 'warning' },
    in_review:   { label: 'In Review',   variant: 'accent'  },
    done:        { label: 'Done',        variant: 'success' },
  };

  const STATUS_COLORS: Record<string, string> = {
    default: 'rgba(255,255,255,0.08)',
    info:    'rgba(59,130,246,0.15)',
    warning: 'rgba(245,158,11,0.15)',
    accent:  'rgba(139,92,246,0.15)',
    success: 'rgba(34,197,94,0.15)',
  };

  const STATUS_TEXT: Record<string, string> = {
    default: 'var(--text-secondary)',
    info:    '#93c5fd',
    warning: '#fde047',
    accent:  '#c4b5fd',
    success: 'rgba(34, 197, 94, 0.7)',
  };

  const LABEL_COLORS = ['#3b82f6','#8b5cf6','rgba(34,197,94,0.7)','#f59e0b','#ec4899','#06b6d4'];
  function labelColor(label: string): string {
    let hash = 0;
    for (let i = 0; i < label.length; i++) hash = (hash * 31 + label.charCodeAt(i)) | 0;
    return LABEL_COLORS[Math.abs(hash) % LABEL_COLORS.length];
  }
</script>

<div class="il-list" role="list" aria-label="Issues list">
  {#if issues.length === 0}
    <div class="il-empty" role="status">No issues match your filters.</div>
  {:else}
    {#each issues as issue (issue.id)}
      {@const priority = PRIORITY_ICONS[issue.priority]}
      {@const statusInfo = STATUS_LABELS[issue.status]}
      {@const assigneeName = resolveAssigneeName(issue)}
      <button
        class="il-row"
        class:il-row--selected={issuesStore.selected?.id === issue.id}
        onclick={() => issuesStore.selectIssue(issue)}
        aria-label="Issue: {issue.title}"
        aria-pressed={issuesStore.selected?.id === issue.id}
        type="button"
      >
        <!-- Priority icon -->
        <span class="il-priority" aria-label="Priority: {issue.priority}" style="color: {priority?.color ?? '#666'}">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true">
            <path d={priority?.path ?? 'M8 12h8'} />
          </svg>
        </span>

        <!-- Title -->
        <span class="il-title">{issue.title}</span>

        <!-- Labels -->
        <div class="il-labels" aria-label="Labels">
          {#each issue.labels.slice(0, 3) as label (label)}
            <span
              class="il-label"
              style="background: {labelColor(label)}22; color: {labelColor(label)}; border-color: {labelColor(label)}44"
            >{label}</span>
          {/each}
        </div>

        <!-- Status badge -->
        <span
          class="il-status"
          style="background: {STATUS_COLORS[statusInfo?.variant ?? 'default']}; color: {STATUS_TEXT[statusInfo?.variant ?? 'default']}"
          aria-label="Status: {statusInfo?.label}"
        >
          {statusInfo?.label ?? issue.status}
        </span>

        <!-- Assignee -->
        <span class="il-assignee" aria-label={issue.assignee_id ? 'Assigned to ' + assigneeName : 'Unassigned'}>
          {#if issue.assignee_id}
            <span class="il-avatar" aria-hidden="true">{assigneeName[0].toUpperCase()}</span>
            <span class="il-assignee-name">{assigneeName}</span>
          {:else}
            <span class="il-no-assignee">—</span>
          {/if}
        </span>

        <!-- Comments -->
        <span class="il-comments" aria-label="{issue.comments_count} comments">
          {#if issue.comments_count > 0}
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
              <path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/>
            </svg>
            {issue.comments_count}
          {/if}
        </span>

        <!-- Updated -->
        <span class="il-updated">
          <TimeAgo date={issue.updated_at} />
        </span>

        <!-- Dispatch -->
        <span class="il-dispatch-cell">
          {#if canDispatch(issue)}
            <button
              class="il-dispatch-btn"
              class:il-dispatch-btn--loading={dispatching[issue.id]}
              onclick={(e) => handleDispatch(e, issue)}
              disabled={dispatching[issue.id]}
              aria-label="Dispatch issue to {assigneeName}"
              type="button"
            >
              {#if dispatching[issue.id]}
                <span class="il-dispatch-spinner" aria-hidden="true"></span>
              {:else}
                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true">
                  <path d="M22 2L11 13M22 2l-7 20-4-9-9-4 20-7z" />
                </svg>
                <span class="il-dispatch-agent">{assigneeName}</span>
              {/if}
            </button>
          {:else}
            <span></span>
          {/if}
        </span>
      </button>
    {/each}
  {/if}
</div>

<style>
  .il-list {
    display: flex;
    flex-direction: column;
    width: 100%;
  }

  .il-empty {
    padding: 40px 16px;
    text-align: center;
    color: var(--text-tertiary);
    font-size: 13px;
  }

  .il-row {
    display: grid;
    grid-template-columns: 20px 1fr auto auto auto auto auto auto;
    align-items: center;
    gap: 10px;
    height: 40px;
    padding: 0 12px;
    border: none;
    border-bottom: 1px solid var(--border-default);
    background: transparent;
    cursor: pointer;
    text-align: left;
    color: inherit;
    font: inherit;
    width: 100%;
    transition: background 100ms ease;
  }

  .il-row:hover {
    background: rgba(255,255,255,0.04);
  }

  .il-row--selected {
    background: rgba(59,130,246,0.08);
    border-color: rgba(59,130,246,0.2);
  }

  .il-row:focus-visible {
    outline: 2px solid var(--accent-primary);
    outline-offset: -2px;
  }

  .il-priority {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .il-title {
    font-size: 13px;
    font-weight: 500;
    color: var(--text-primary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .il-labels {
    display: flex;
    align-items: center;
    gap: 4px;
    flex-shrink: 0;
  }

  .il-label {
    font-size: 10px;
    font-weight: 500;
    padding: 1px 6px;
    border-radius: 9999px;
    border: 1px solid transparent;
    white-space: nowrap;
  }

  .il-status {
    font-size: 11px;
    font-weight: 500;
    padding: 2px 8px;
    border-radius: 9999px;
    white-space: nowrap;
    flex-shrink: 0;
  }

  .il-assignee {
    display: flex;
    align-items: center;
    gap: 5px;
    flex-shrink: 0;
  }

  .il-avatar {
    width: 18px;
    height: 18px;
    border-radius: 50%;
    background: var(--accent-primary);
    color: #fff;
    font-size: 10px;
    font-weight: 600;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .il-assignee-name {
    font-size: 12px;
    color: var(--text-secondary);
    max-width: 80px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .il-no-assignee {
    font-size: 12px;
    color: var(--text-muted);
  }

  .il-comments {
    display: flex;
    align-items: center;
    gap: 3px;
    font-size: 11px;
    color: var(--text-tertiary);
    flex-shrink: 0;
    min-width: 24px;
  }

  .il-updated {
    flex-shrink: 0;
    text-align: right;
  }

  .il-dispatch-cell {
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: flex-end;
  }

  .il-dispatch-btn {
    display: flex;
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

  .il-dispatch-btn:hover:not(:disabled) {
    background: rgba(34, 197, 94, 0.08);
    border-color: rgba(34, 197, 94, 0.3);
    color: rgba(34, 197, 94, 0.8);
  }

  .il-dispatch-btn:focus-visible {
    outline: 2px solid var(--accent-primary);
    outline-offset: 2px;
  }

  .il-dispatch-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .il-dispatch-btn--loading {
    min-width: 50px;
    justify-content: center;
  }

  .il-dispatch-agent {
    max-width: 80px;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .il-dispatch-spinner {
    width: 10px;
    height: 10px;
    border: 1.5px solid currentColor;
    border-top-color: transparent;
    border-radius: 50%;
    animation: il-spin 0.7s linear infinite;
    flex-shrink: 0;
  }

  @keyframes il-spin {
    to { transform: rotate(360deg); }
  }
</style>
