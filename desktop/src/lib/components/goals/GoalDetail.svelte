<!-- src/lib/components/goals/GoalDetail.svelte -->
<!-- Slide-out detail panel for a selected goal -->
<script lang="ts">
  import type { GoalTreeNode, Goal } from '$api/types';
  import { goalsStore } from '$lib/stores/goals.svelte';
  import GoalForm from './GoalForm.svelte';

  interface Props {
    goal: GoalTreeNode;
    onClose: () => void;
  }

  let { goal, onClose }: Props = $props();

  let editing = $state(false);

  const STATUS_STYLES: Record<string, { bg: string; text: string; label: string }> = {
    active:      { bg: 'rgba(59,130,246,0.12)',  text: '#93c5fd', label: 'Active'      },
    in_progress: { bg: 'rgba(245,158,11,0.12)',  text: '#fde047', label: 'In Progress' },
    completed:   { bg: 'rgba(34,197,94,0.08)',   text: 'rgba(34,197,94,0.7)', label: 'Completed' },
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
    completed:   'rgba(34,197,94,0.7)',
    blocked:     '#ef4444',
  };

  let statusStyle   = $derived(STATUS_STYLES[goal.status] ?? STATUS_STYLES.active);
  let priorityStyle = $derived(PRIORITY_STYLES[goal.priority] ?? PRIORITY_STYLES.medium);
  let progressColor = $derived(PROGRESS_COLORS[goal.status] ?? '#3b82f6');
  let progressPct   = $derived(Math.min(100, Math.max(0, goal.progress)));

  let deleting = $state(false);

  async function handleDelete() {
    if (!confirm('Delete this goal? This cannot be undone.')) return;
    deleting = true;
    await goalsStore.deleteGoal(goal.id);
    deleting = false;
    onClose();
  }

  async function handleEdit(data: Partial<Goal>) {
    await goalsStore.updateGoal(goal.id, data);
    editing = false;
  }
</script>

<!-- Backdrop -->
<div
  class="gd-backdrop"
  role="presentation"
  onclick={onClose}
  aria-hidden="true"
></div>

<!-- Panel -->
<aside class="gd-panel" role="dialog" aria-modal="true" aria-label="Goal details: {goal.title}">
  <header class="gd-header">
    <h2 class="gd-title">{goal.title}</h2>
    <button class="gd-close" onclick={onClose} aria-label="Close detail panel" type="button">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
        <path d="M18 6L6 18M6 6l12 12" />
      </svg>
    </button>
  </header>

  <div class="gd-body">
    <!-- Badges -->
    <div class="gd-badges">
      <span class="gd-badge" style="background: {statusStyle.bg}; color: {statusStyle.text}">
        {statusStyle.label}
      </span>
      <span class="gd-badge" style="background: {priorityStyle.bg}; color: {priorityStyle.text}">
        {goal.priority}
      </span>
    </div>

    <!-- Progress -->
    <div class="gd-section">
      <h3 class="gd-section-label">Progress</h3>
      <div class="gd-progress-wrap" role="progressbar" aria-valuenow={progressPct} aria-valuemin={0} aria-valuemax={100}>
        <div class="gd-progress-track">
          <div class="gd-progress-fill" style="width: {progressPct}%; background: {progressColor}"></div>
        </div>
        <span class="gd-progress-label">{progressPct}%</span>
      </div>
    </div>

    <!-- Description -->
    {#if goal.description}
      <div class="gd-section">
        <h3 class="gd-section-label">Description</h3>
        <p class="gd-description">{goal.description}</p>
      </div>
    {/if}

    <!-- Meta -->
    <div class="gd-section">
      <h3 class="gd-section-label">Details</h3>
      <div class="gd-meta-grid">
        <div class="gd-meta-item">
          <span class="gd-meta-key">Sub-goals</span>
          <span class="gd-meta-value">{goal.children.length}</span>
        </div>
        <div class="gd-meta-item">
          <span class="gd-meta-key">Linked issues</span>
          <span class="gd-meta-value">{goal.issue_count}</span>
        </div>
        <div class="gd-meta-item">
          <span class="gd-meta-key">Created</span>
          <span class="gd-meta-value">{new Date(goal.created_at).toLocaleDateString()}</span>
        </div>
        <div class="gd-meta-item">
          <span class="gd-meta-key">Updated</span>
          <span class="gd-meta-value">{new Date(goal.updated_at).toLocaleDateString()}</span>
        </div>
      </div>
    </div>

    <!-- Sub-goals list -->
    {#if goal.children.length > 0}
      <div class="gd-section">
        <h3 class="gd-section-label">Sub-goals</h3>
        <div class="gd-subgoals">
          {#each goal.children as child (child.id)}
            <button
              class="gd-subgoal"
              type="button"
              onclick={() => goalsStore.selectGoal(child)}
              aria-label="View sub-goal: {child.title}"
            >
              <span class="gd-subgoal-dot" style="background: {PROGRESS_COLORS[child.status] ?? '#3b82f6'}" aria-hidden="true"></span>
              <span class="gd-subgoal-title">{child.title}</span>
              <span class="gd-subgoal-pct">{child.progress}%</span>
            </button>
          {/each}
        </div>
      </div>
    {/if}
  </div>

  <!-- Actions -->
  <footer class="gd-footer">
    <button class="gd-action-btn" type="button" onclick={() => editing = true} aria-label="Edit goal">
      <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
        <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
        <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
      </svg>
      Edit
    </button>
    <button
      class="gd-action-btn gd-action-btn--danger"
      type="button"
      onclick={handleDelete}
      disabled={deleting}
      aria-label="Delete goal"
    >
      <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
        <path d="M3 6h18M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
      </svg>
      {deleting ? 'Deleting...' : 'Delete'}
    </button>
  </footer>
</aside>

{#if editing}
  <GoalForm goal={goal} onSubmit={handleEdit} onCancel={() => editing = false} />
{/if}

<style>
  .gd-backdrop {
    position: fixed; inset: 0;
    background: rgba(0,0,0,0.4);
    backdrop-filter: blur(2px);
    z-index: 90;
  }

  .gd-panel {
    position: fixed;
    top: 0; right: 0; bottom: 0;
    width: 420px;
    max-width: calc(100vw - 60px);
    background: var(--bg-tertiary);
    border-left: 1px solid var(--border-default);
    z-index: 91;
    display: flex;
    flex-direction: column;
    box-shadow: -8px 0 40px rgba(0,0,0,0.3);
    animation: gd-slide-in 180ms ease-out;
  }

  @keyframes gd-slide-in {
    from { transform: translateX(100%); }
    to   { transform: translateX(0); }
  }

  .gd-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 12px;
    padding: 20px 20px 16px;
    border-bottom: 1px solid var(--border-default);
    flex-shrink: 0;
  }

  .gd-title {
    font-size: 16px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
    line-height: 1.4;
  }

  .gd-close {
    display: flex; align-items: center; justify-content: center;
    width: 28px; height: 28px;
    border: none; background: transparent;
    color: var(--text-tertiary); cursor: pointer;
    border-radius: var(--radius-xs);
    flex-shrink: 0;
    transition: background 100ms, color 100ms;
  }
  .gd-close:hover { background: rgba(255,255,255,0.07); color: var(--text-primary); }
  .gd-close:focus-visible { outline: 2px solid var(--accent-primary); }

  .gd-body {
    flex: 1;
    overflow-y: auto;
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 20px;
  }

  .gd-badges {
    display: flex;
    gap: 6px;
  }

  .gd-badge {
    font-size: 11px;
    font-weight: 500;
    padding: 3px 9px;
    border-radius: 9999px;
    text-transform: capitalize;
  }

  .gd-section {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .gd-section-label {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: var(--text-muted);
    margin: 0;
  }

  .gd-progress-wrap {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .gd-progress-track {
    flex: 1;
    height: 6px;
    background: rgba(255,255,255,0.08);
    border-radius: 9999px;
    overflow: hidden;
  }

  .gd-progress-fill {
    height: 100%;
    border-radius: 9999px;
    transition: width 400ms ease;
  }

  .gd-progress-label {
    font-size: 13px;
    font-weight: 600;
    color: var(--text-secondary);
    min-width: 36px;
    text-align: right;
  }

  .gd-description {
    font-size: 13px;
    line-height: 1.6;
    color: var(--text-secondary);
    margin: 0;
    white-space: pre-wrap;
  }

  .gd-meta-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
  }

  .gd-meta-item {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .gd-meta-key {
    font-size: 11px;
    color: var(--text-muted);
  }

  .gd-meta-value {
    font-size: 13px;
    color: var(--text-primary);
    font-weight: 500;
  }

  .gd-subgoals {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .gd-subgoal {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 8px;
    background: transparent;
    border: none;
    border-radius: var(--radius-xs);
    cursor: pointer;
    text-align: left;
    font-family: inherit;
    transition: background 100ms;
  }

  .gd-subgoal:hover {
    background: rgba(255,255,255,0.05);
  }

  .gd-subgoal:focus-visible {
    outline: 2px solid var(--accent-primary);
  }

  .gd-subgoal-dot {
    width: 6px; height: 6px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .gd-subgoal-title {
    flex: 1;
    font-size: 13px;
    color: var(--text-secondary);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .gd-subgoal-pct {
    font-size: 11px;
    color: var(--text-muted);
    flex-shrink: 0;
  }

  .gd-footer {
    display: flex;
    gap: 8px;
    padding: 14px 20px;
    border-top: 1px solid var(--border-default);
    flex-shrink: 0;
  }

  .gd-action-btn {
    display: flex;
    align-items: center;
    gap: 5px;
    height: 30px;
    padding: 0 12px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    color: var(--text-secondary);
    font-size: 12px;
    font-weight: 500;
    font-family: inherit;
    cursor: pointer;
    transition: background 100ms, color 100ms, border-color 100ms;
  }

  .gd-action-btn:hover {
    background: rgba(255,255,255,0.07);
    color: var(--text-primary);
  }

  .gd-action-btn:focus-visible {
    outline: 2px solid var(--accent-primary);
    outline-offset: 2px;
  }

  .gd-action-btn--danger:hover {
    background: rgba(239,68,68,0.1);
    border-color: rgba(239,68,68,0.3);
    color: #fca5a5;
  }

  .gd-action-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
</style>
