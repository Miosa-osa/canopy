<!-- src/lib/components/issues/IssueCard.svelte -->
<!-- Compact issue card for kanban/list with HTML5 drag-and-drop -->
<script lang="ts">
  import type { Issue } from '$api/types';
  import { resolveAssigneeName } from '$lib/stores/issues.svelte';
  import TimeAgo from '$lib/components/shared/TimeAgo.svelte';

  interface Props {
    issue: Issue;
    ondragstart?: (e: DragEvent) => void;
    ondragend?: (e: DragEvent) => void;
  }

  let { issue, ondragstart }: Props = $props();

  const PRIORITY_COLORS: Record<string, string> = {
    low:      '#3b82f6',
    medium:   '#f59e0b',
    high:     '#f97316',
    critical: '#ef4444',
  };

  const PRIORITY_LABELS: Record<string, string> = {
    low: 'Low', medium: 'Medium', high: 'High', critical: 'Critical',
  };

  const LABEL_COLORS = [
    '#3b82f6', '#8b5cf6', 'rgba(34,197,94,0.7)', '#f59e0b', '#ec4899', '#06b6d4',
  ];

  function labelColor(label: string): string {
    let hash = 0;
    for (let i = 0; i < label.length; i++) hash = (hash * 31 + label.charCodeAt(i)) | 0;
    return LABEL_COLORS[Math.abs(hash) % LABEL_COLORS.length];
  }

  let priorityColor = $derived(PRIORITY_COLORS[issue.priority] ?? '#666');
  let assigneeName = $derived(resolveAssigneeName(issue));
</script>

<article
  class="ic-card"
  style="--priority-color: {priorityColor}"
  draggable="true"
  {ondragstart}
  aria-label="Issue: {issue.title}, priority {PRIORITY_LABELS[issue.priority]}, status {issue.status}"
  role="listitem"
>
  <header class="ic-header">
    <span class="ic-title">{issue.title}</span>
  </header>

  {#if issue.labels.length > 0}
    <div class="ic-labels" aria-label="Labels">
      {#each issue.labels.slice(0, 4) as label (label)}
        <span
          class="ic-label"
          style="background: {labelColor(label)}22; color: {labelColor(label)}; border-color: {labelColor(label)}44"
        >{label}</span>
      {/each}
      {#if issue.labels.length > 4}
        <span class="ic-label ic-label--more">+{issue.labels.length - 4}</span>
      {/if}
    </div>
  {/if}

  <footer class="ic-footer">
    {#if issue.assignee_id}
      <span class="ic-assignee" aria-label="Assigned to {assigneeName}">
        <span class="ic-avatar" aria-hidden="true">{assigneeName[0].toUpperCase()}</span>
        <span class="ic-assignee-name">{assigneeName}</span>
      </span>
    {:else}
      <span class="ic-unassigned" aria-label="Unassigned">Unassigned</span>
    {/if}

    <div class="ic-meta">
      {#if issue.comments_count > 0}
        <span class="ic-comments" aria-label="{issue.comments_count} comments">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/>
          </svg>
          {issue.comments_count}
        </span>
      {/if}
      <TimeAgo date={issue.updated_at} />
    </div>
  </footer>
</article>

<style>
  .ic-card {
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-left: 3px solid var(--priority-color);
    border-radius: var(--radius-sm);
    padding: 10px 12px;
    cursor: grab;
    transition: background 150ms ease, box-shadow 150ms ease, transform 150ms ease;
    display: flex;
    flex-direction: column;
    gap: 6px;
    user-select: none;
  }

  .ic-card:hover {
    background: rgba(255,255,255,0.05);
    box-shadow: 0 2px 8px rgba(0,0,0,0.3);
  }

  .ic-card:active {
    cursor: grabbing;
    transform: scale(0.98);
  }

  .ic-header {
    display: flex;
    align-items: flex-start;
    gap: 6px;
  }

  .ic-title {
    font-size: 13px;
    font-weight: 500;
    color: var(--text-primary);
    line-height: 1.4;
    overflow: hidden;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    flex: 1;
  }

  .ic-labels {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
  }

  .ic-label {
    font-size: 10px;
    font-weight: 500;
    padding: 1px 6px;
    border-radius: 9999px;
    border: 1px solid transparent;
    white-space: nowrap;
    max-width: 80px;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ic-label--more {
    background: rgba(255,255,255,0.06);
    color: var(--text-tertiary);
    border-color: var(--border-default);
  }

  .ic-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    margin-top: 2px;
  }

  .ic-assignee {
    display: flex;
    align-items: center;
    gap: 5px;
    min-width: 0;
    flex-shrink: 1;
  }

  .ic-avatar {
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

  .ic-assignee-name {
    font-size: 11px;
    color: var(--text-tertiary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 80px;
  }

  .ic-unassigned {
    font-size: 11px;
    color: var(--text-muted);
  }

  .ic-meta {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-shrink: 0;
  }

  .ic-comments {
    display: flex;
    align-items: center;
    gap: 3px;
    font-size: 11px;
    color: var(--text-tertiary);
  }
</style>
