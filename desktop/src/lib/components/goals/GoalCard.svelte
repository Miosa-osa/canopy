<!-- src/lib/components/goals/GoalCard.svelte -->
<!-- Single goal card with progress bar -->
<script lang="ts">
  import type { GoalTreeNode } from '$api/types';
  import { goalsStore } from '$lib/stores/goals.svelte';

  interface Props {
    goal: GoalTreeNode;
    onSelect?: (goal: GoalTreeNode) => void;
  }

  let { goal, onSelect }: Props = $props();

  let decomposing = $state(false);

  async function handleDecompose(e: MouseEvent) {
    e.stopPropagation();
    decomposing = true;
    await goalsStore.decompose(goal.id);
    decomposing = false;
  }

  const STATUS_STYLES: Record<string, { bg: string; text: string; label: string }> = {
    active:      { bg: 'rgba(59,130,246,0.12)',  text: '#93c5fd', label: 'Active'      },
    in_progress: { bg: 'rgba(245,158,11,0.12)',  text: '#fde047', label: 'In Progress' },
    completed:   { bg: 'rgba(34,197,94,0.08)',    text: 'rgba(34, 197, 94, 0.7)', label: 'Completed'   },
    blocked:     { bg: 'rgba(239,68,68,0.12)',   text: '#fca5a5', label: 'Blocked'     },
  };

  const PRIORITY_STYLES: Record<string, { bg: string; text: string }> = {
    low:    { bg: 'rgba(59,130,246,0.12)',  text: '#93c5fd' },
    medium: { bg: 'rgba(245,158,11,0.12)',  text: '#fde047' },
    high:   { bg: 'rgba(239,68,68,0.12)',   text: '#fca5a5' },
  };

  const PROGRESS_COLORS: Record<string, string> = {
    active:      '#3b82f6',
    in_progress: '#f59e0b',
    completed:   'rgba(34, 197, 94, 0.7)',
    blocked:     '#ef4444',
  };

  let statusStyle  = $derived(STATUS_STYLES[goal.status]  ?? STATUS_STYLES.active);
  let priorityStyle = $derived(PRIORITY_STYLES[goal.priority] ?? PRIORITY_STYLES.medium);
  let progressColor = $derived(PROGRESS_COLORS[goal.status] ?? '#3b82f6');
  let progressPct  = $derived(Math.min(100, Math.max(0, goal.progress)));
</script>

<article
  class="gc-card"
  role="article"
  aria-label="Goal: {goal.title}, {progressPct}% complete"
  onclick={() => onSelect?.(goal)}
  onkeydown={(e) => e.key === 'Enter' && onSelect?.(goal)}
  tabindex={onSelect ? 0 : undefined}
  style={onSelect ? 'cursor: pointer' : undefined}
>
  <header class="gc-header">
    <h3 class="gc-title">{goal.title}</h3>
    <div class="gc-badges">
      <span
        class="gc-badge"
        style="background: {statusStyle.bg}; color: {statusStyle.text}"
        aria-label="Status: {statusStyle.label}"
      >
        {statusStyle.label}
      </span>
      <span
        class="gc-badge"
        style="background: {priorityStyle.bg}; color: {priorityStyle.text}"
        aria-label="Priority: {goal.priority}"
      >
        {goal.priority}
      </span>
    </div>
  </header>

  <!-- Progress -->
  <div class="gc-progress-wrap" role="progressbar" aria-valuenow={progressPct} aria-valuemin={0} aria-valuemax={100} aria-label="Progress: {progressPct}%">
    <div class="gc-progress-track">
      <div
        class="gc-progress-fill"
        style="width: {progressPct}%; background: {progressColor}"
      ></div>
    </div>
    <span class="gc-progress-label">{progressPct}%</span>
  </div>

  <footer class="gc-footer">
    {#if goal.children.length > 0}
      <span class="gc-meta-item" aria-label="{goal.children.length} sub-goals">
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
          <path d="M3 3h18M3 12h9M3 21h6" />
        </svg>
        {goal.children.length} sub-goals
      </span>
    {/if}
    {#if goal.issue_count > 0}
      <span class="gc-meta-item" aria-label="{goal.issue_count} linked issues">
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
          <circle cx="12" cy="12" r="10"/><path d="M12 8v4l3 3"/>
        </svg>
        {goal.issue_count} issues
      </span>
    {/if}
    {#if goal.assignee_id}
      <span class="gc-meta-item gc-assignee" aria-label="Assigned">
        <span class="gc-avatar" aria-hidden="true">A</span>
      </span>
    {/if}

    <button
      class="gc-decompose-btn"
      class:gc-decompose-btn--loading={decomposing}
      onclick={handleDecompose}
      disabled={decomposing}
      aria-label="Decompose goal into issues"
      type="button"
    >
      {#if decomposing}
        <span class="gc-decompose-spinner" aria-hidden="true"></span>
        Decomposing…
      {:else}
        <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true">
          <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" />
        </svg>
        Decompose
      {/if}
    </button>
  </footer>
</article>

<style>
  .gc-card {
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    padding: 12px 14px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    transition: background 150ms ease, border-color 150ms ease;
  }

  .gc-card:hover {
    background: rgba(255,255,255,0.05);
    border-color: var(--border-hover);
  }

  .gc-card:focus-visible {
    outline: 2px solid var(--accent-primary);
    outline-offset: 2px;
  }

  .gc-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 8px;
  }

  .gc-title {
    font-size: 13px;
    font-weight: 500;
    color: var(--text-primary);
    line-height: 1.4;
    margin: 0;
    flex: 1;
    min-width: 0;
    overflow: hidden;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
  }

  .gc-badges {
    display: flex;
    gap: 4px;
    flex-shrink: 0;
  }

  .gc-badge {
    font-size: 10px;
    font-weight: 500;
    padding: 2px 7px;
    border-radius: 9999px;
    white-space: nowrap;
    text-transform: capitalize;
  }

  .gc-progress-wrap {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .gc-progress-track {
    flex: 1;
    height: 4px;
    background: rgba(255,255,255,0.08);
    border-radius: 9999px;
    overflow: hidden;
  }

  .gc-progress-fill {
    height: 100%;
    border-radius: 9999px;
    transition: width 400ms ease;
  }

  .gc-progress-label {
    font-size: 11px;
    color: var(--text-tertiary);
    flex-shrink: 0;
    min-width: 32px;
    text-align: right;
  }

  .gc-footer {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .gc-meta-item {
    display: flex;
    align-items: center;
    gap: 4px;
    font-size: 11px;
    color: var(--text-tertiary);
  }

  .gc-assignee { margin-left: auto; }

  .gc-avatar {
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
  }

  .gc-decompose-btn {
    display: flex;
    align-items: center;
    gap: 4px;
    margin-left: auto;
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
    flex-shrink: 0;
    transition: background 150ms ease, color 150ms ease, border-color 150ms ease;
  }

  .gc-decompose-btn:hover:not(:disabled) {
    background: rgba(139, 92, 246, 0.1);
    border-color: rgba(139, 92, 246, 0.4);
    color: #c4b5fd;
  }

  .gc-decompose-btn:focus-visible {
    outline: 2px solid var(--accent-primary);
    outline-offset: 2px;
  }

  .gc-decompose-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .gc-decompose-btn--loading {
    color: var(--text-tertiary);
  }

  .gc-decompose-spinner {
    width: 10px;
    height: 10px;
    border: 1.5px solid currentColor;
    border-top-color: transparent;
    border-radius: 50%;
    animation: gc-spin 0.7s linear infinite;
    flex-shrink: 0;
  }

  @keyframes gc-spin {
    to { transform: rotate(360deg); }
  }
</style>
