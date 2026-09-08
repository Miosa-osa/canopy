<script lang="ts">
/**
 * /goals — Goal list with status filter tabs and card grid.
 * Fetches GET /api/v1/goals — shows defensive banner on 404.
 * New Goal opens inline modal.
 * CSS prefix: gl- (goals list)
 */
import { createMutation, createQuery, useQueryClient } from '@tanstack/svelte-query';
import { Plus, Target, X } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import { createGoalMutation, goalsQuery } from '$lib/api/queries/goals.js';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import type { CreateGoalBody, Goal, GoalPriority, GoalStatus } from '$lib/domain/goals/types.js';

// ── Query ──────────────────────────────────────────────────────────────────

const queryClient = useQueryClient();
const optsStore = writable(untrack(() => goalsQuery()));
const goalsQ = createQuery<Goal[]>(optsStore);
const goals = $derived(($goalsQ.data ?? []) as Goal[]);

const backendUnavailable = $derived(
  $goalsQ.isError && String(($goalsQ.error as Error)?.message ?? '').includes('404')
);

// ── Seed data (shown when backend unavailable) ─────────────────────────────

const SEED_GOALS: Goal[] = [
  {
    id: 'seed-1',
    shortId: 'G-001',
    workspaceSlug: null,
    title: 'Ship Canopy v1.0',
    description: 'Full public release with all core modules functional.',
    successCriteria: null,
    status: 'active',
    priority: 'critical',
    progress: 65,
    ownerType: null,
    ownerId: null,
    targetDate: '2026-06-30',
    achievedAt: null,
    cancelledAt: null,
    insertedAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 'seed-2',
    shortId: 'G-002',
    workspaceSlug: null,
    title: '100% test coverage on core modules',
    description: 'Achieve full coverage across agent, session, and drive modules.',
    successCriteria: null,
    status: 'active',
    priority: 'high',
    progress: 42,
    ownerType: null,
    ownerId: null,
    targetDate: '2026-07-15',
    achievedAt: null,
    cancelledAt: null,
    insertedAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 'seed-3',
    shortId: 'G-003',
    workspaceSlug: null,
    title: 'Onboard 5 team members',
    description: 'Get the full engineering team productive in the workspace.',
    successCriteria: null,
    status: 'active',
    priority: 'medium',
    progress: 80,
    ownerType: null,
    ownerId: null,
    targetDate: '2026-05-31',
    achievedAt: null,
    cancelledAt: null,
    insertedAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
];

// ── Status filter ──────────────────────────────────────────────────────────

type FilterTab = 'all' | GoalStatus;
let activeFilter = $state<FilterTab>('all');

const STATUS_TABS: { value: FilterTab; label: string }[] = [
  { value: 'all', label: 'All' },
  { value: 'proposed', label: 'Proposed' },
  { value: 'active', label: 'Active' },
  { value: 'blocked', label: 'Blocked' },
  { value: 'achieved', label: 'Achieved' },
];

const displayGoals = $derived(backendUnavailable ? SEED_GOALS : goals);

const filtered = $derived(
  activeFilter === 'all' ? displayGoals : displayGoals.filter((g) => g.status === activeFilter)
);

// ── Priority helpers ───────────────────────────────────────────────────────

const PRIORITY_DOT: Record<GoalPriority, string> = {
  low: 'var(--fg-subtle)',
  medium: 'var(--fg-muted)',
  high: 'var(--cnp-accent, var(--fg))',
  critical: '#ef4444',
};

function priorityLabel(p: GoalPriority): string {
  // Guard: p may be null/undefined at runtime if the API returns unexpected data.
  if (typeof p !== 'string' || p.length === 0) return '?';
  return p.charAt(0).toUpperCase() + p.slice(1);
}

function progressArc(pct: number): string {
  const r = 14;
  const circ = 2 * Math.PI * r;
  const dash = (pct / 100) * circ;
  return `stroke-dasharray: ${dash} ${circ}`;
}

// ── New Goal modal ─────────────────────────────────────────────────────────

let modalOpen = $state(false);
let draft = $state<CreateGoalBody>({
  title: '',
  description: '',
  priority: 'medium',
  targetDate: '',
});
let createError = $state<string | null>(null);

const createMut = createMutation(createGoalMutation());

async function submitGoal() {
  if (!draft.title.trim()) return;
  createError = null;
  try {
    const body: CreateGoalBody = {
      title: draft.title.trim(),
      priority: draft.priority,
    };
    if (draft.description?.trim()) body.description = draft.description.trim();
    if (draft.targetDate?.trim()) body.targetDate = draft.targetDate.trim();
    await $createMut.mutateAsync(body);
    await queryClient.invalidateQueries({ queryKey: ['goals'] });
    modalOpen = false;
    draft = { title: '', description: '', priority: 'medium', targetDate: '' };
  } catch (err) {
    createError = err instanceof Error ? err.message : 'Failed to create goal';
  }
}

function openModal() {
  createError = null;
  modalOpen = true;
}
</script>

<div class="gl-page">
  <!-- Header -->
  <header class="gl-header">
    <div class="gl-title-row">
      <h1 class="gl-title">Goals</h1>
      <button class="gl-new-btn" onclick={openModal} aria-label="New goal">
        <Plus size={13} aria-hidden="true" />
        New Goal
      </button>
    </div>

    <!-- Status filter tabs -->
    <div class="gl-tabs" role="tablist" aria-label="Filter by status">
      {#each STATUS_TABS as tab (tab.value)}
        <button
          class="gl-tab"
          class:gl-tab--active={activeFilter === tab.value}
          role="tab"
          aria-selected={activeFilter === tab.value}
          onclick={() => { activeFilter = tab.value; }}
        >
          {tab.label}
          {#if tab.value !== "all"}
            <span class="gl-tab__count">
              {displayGoals.filter((g) => g.status === tab.value).length}
            </span>
          {/if}
        </button>
      {/each}
    </div>
  </header>

  <!-- Backend unavailable banner -->
  {#if backendUnavailable}
    <div class="gl-banner" role="status">
      Showing example goals — connect <code>/api/v1/goals</code> to see live data.
    </div>
  {/if}

  <!-- Content -->
  <main class="gl-main">
    {#if $goalsQ.isLoading}
      <div class="gl-skeletons">
        {#each Array(6) as _, i (i)}
          <div class="gl-sk"></div>
        {/each}
      </div>
    {:else if !backendUnavailable && $goalsQ.isError}
      <EmptyState
        icon={Target as never}
        title="Failed to load goals"
        body="Check your connection and try again."
        action="Retry"
        onAction={() => $goalsQ.refetch()}
      />
    {:else if filtered.length === 0}
      <EmptyState
        icon={Target as never}
        title="No goals yet"
        body="Define a goal to track high-level objectives for your workspace."
        action="New Goal"
        onAction={openModal}
      />
    {:else}
      <div class="gl-grid">
        {#each filtered as goal (goal.id)}
          <button
            class="gl-card"
            onclick={() => goto(`/goals/${goal.shortId}`)}
            aria-label="Open {goal.title}"
          >
            <div class="gl-card__top">
              <!-- Progress ring -->
              <svg class="gl-ring" viewBox="0 0 36 36" aria-hidden="true">
                <circle class="gl-ring__bg" cx="18" cy="18" r="14" />
                <circle
                  class="gl-ring__fill"
                  cx="18"
                  cy="18"
                  r="14"
                  style={progressArc(goal.progress)}
                />
              </svg>
              <span class="gl-card__pct">{goal.progress}%</span>

              <!-- Priority dot -->
              <span
                class="gl-priority-dot"
                style="background: {PRIORITY_DOT[goal.priority]}"
                title={priorityLabel(goal.priority)}
                aria-label="Priority: {priorityLabel(goal.priority)}"
              ></span>

              <!-- Status pill -->
              <span class="gl-status gl-status--{goal.status}">{goal.status}</span>
            </div>

            <div class="gl-card__body">
              <span class="gl-card__title">{goal.title}</span>
              {#if goal.description}
                <span class="gl-card__desc">{goal.description}</span>
              {/if}
            </div>

            {#if goal.targetDate}
              <div class="gl-card__footer">
                <span class="gl-card__date">
                  Target: {new Date(goal.targetDate).toLocaleDateString()}
                </span>
              </div>
            {/if}
          </button>
        {/each}
      </div>
    {/if}
  </main>
</div>

<!-- New Goal modal -->
{#if modalOpen}
  <div class="gl-overlay" role="dialog" aria-modal="true" aria-label="New goal">
    <div class="gl-modal">
      <div class="gl-modal__head">
        <span class="gl-modal__label">New Goal</span>
        <button
          class="gl-modal__close"
          onclick={() => { modalOpen = false; }}
          aria-label="Close"
        >
          <X size={14} aria-hidden="true" />
        </button>
      </div>

      <div class="gl-modal__body">
        <label class="gl-field">
          <span class="gl-field__label">Title</span>
          <input
            class="gl-input"
            type="text"
            placeholder="What is the goal?"
            bind:value={draft.title}
            aria-required="true"
          />
        </label>

        <label class="gl-field">
          <span class="gl-field__label">Description</span>
          <textarea
            class="gl-input gl-textarea"
            placeholder="Context and motivation..."
            bind:value={draft.description}
            rows={3}
          ></textarea>
        </label>

        <div class="gl-row">
          <label class="gl-field gl-field--half">
            <span class="gl-field__label">Priority</span>
            <select class="gl-select" bind:value={draft.priority}>
              <option value="low">Low</option>
              <option value="medium">Medium</option>
              <option value="high">High</option>
              <option value="critical">Critical</option>
            </select>
          </label>

          <label class="gl-field gl-field--half">
            <span class="gl-field__label">Target date</span>
            <input class="gl-input" type="date" bind:value={draft.targetDate} />
          </label>
        </div>

        {#if createError}
          <p class="gl-error">{createError}</p>
        {/if}
      </div>

      <div class="gl-modal__foot">
        <button
          class="gl-btn gl-btn--ghost"
          onclick={() => { modalOpen = false; }}
          disabled={$createMut.isPending}
        >
          Cancel
        </button>
        <button
          class="gl-btn gl-btn--primary"
          onclick={submitGoal}
          disabled={$createMut.isPending || !draft.title.trim()}
        >
          {$createMut.isPending ? "Creating..." : "Create Goal"}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .gl-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  /* Header */
  .gl-header {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-5) var(--space-6) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .gl-title-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
  }

  .gl-title {
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
    letter-spacing: -0.025em;
  }

  .gl-new-btn {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    padding: var(--space-1) var(--space-3);
    background: color-mix(in oklch, var(--fg) 10%, transparent 90%);
    border: 1px solid var(--border-strong);
    border-radius: var(--radius-md);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    transition: background var(--dur-instant) var(--ease-out);
  }

  .gl-new-btn:hover {
    background: color-mix(in oklch, var(--fg) 16%, transparent 84%);
  }

  /* Tabs */
  .gl-tabs {
    display: flex;
    gap: 2px;
    flex-wrap: wrap;
  }

  .gl-tab {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    padding: var(--space-1) var(--space-3);
    background: transparent;
    border: 1px solid transparent;
    border-radius: var(--radius-md);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    transition: background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .gl-tab:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .gl-tab--active {
    background: color-mix(in oklch, var(--fg) 10%, transparent 90%);
    border-color: var(--border);
    color: var(--fg);
    font-weight: 500;
  }

  .gl-tab__count {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  /* Banner */
  .gl-banner {
    margin: var(--space-3) var(--space-6);
    padding: var(--space-2) var(--space-3);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    flex-shrink: 0;
  }

  .gl-banner code {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-subtle);
  }

  /* Main */
  .gl-main {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-5) var(--space-6);
  }

  /* Skeletons */
  .gl-skeletons {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--space-3);
  }

  .gl-sk {
    height: 160px;
    background: var(--border);
    border-radius: var(--radius-xl);
    animation: gl-pulse 1.5s ease-in-out infinite;
  }

  @keyframes gl-pulse {
    0%, 100% { opacity: 0.3; }
    50% { opacity: 0.6; }
  }

  /* Card grid */
  .gl-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--space-3);
  }

  @media (max-width: 1100px) {
    .gl-grid { grid-template-columns: repeat(2, 1fr); }
    .gl-skeletons { grid-template-columns: repeat(2, 1fr); }
  }

  @media (max-width: 700px) {
    .gl-grid { grid-template-columns: 1fr; }
    .gl-skeletons { grid-template-columns: 1fr; }
  }

  .gl-card {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-4);
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-xl);
    cursor: pointer;
    text-align: left;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .gl-card:hover {
    border-color: var(--border-strong);
  }

  .gl-card__top {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  /* Progress ring */
  .gl-ring {
    width: 32px;
    height: 32px;
    flex-shrink: 0;
    transform: rotate(-90deg);
  }

  .gl-ring__bg {
    fill: none;
    stroke: var(--border);
    stroke-width: 3;
  }

  .gl-ring__fill {
    fill: none;
    stroke: var(--cnp-accent, var(--fg-muted));
    stroke-width: 3;
    stroke-dashoffset: 0;
    stroke-linecap: round;
    transition: stroke-dasharray 0.3s var(--ease-out);
  }

  .gl-card__pct {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    min-width: 28px;
  }

  .gl-priority-dot {
    width: 8px;
    height: 8px;
    border-radius: 9999px;
    flex-shrink: 0;
    margin-left: auto;
  }

  /* Status pill */
  .gl-status {
    font-family: var(--font-sans);
    font-size: 9px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    padding: 2px 6px;
    border-radius: var(--radius-sm);
    background: var(--bg-inset);
    color: var(--fg-muted);
    border: 1px solid var(--border);
  }

  .gl-status--active {
    color: var(--cnp-accent, var(--fg));
    border-color: color-mix(in oklch, var(--cnp-accent, var(--fg)) 30%, transparent 70%);
    background: color-mix(in oklch, var(--cnp-accent, var(--fg)) 8%, transparent 92%);
  }

  .gl-status--achieved {
    color: #4ade80;
    border-color: #4ade8030;
    background: #4ade8010;
  }

  .gl-status--blocked {
    color: #f87171;
    border-color: #f8717130;
    background: #f8717110;
  }

  .gl-card__body {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
    flex: 1;
  }

  .gl-card__title {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    line-height: 1.4;
  }

  .gl-card__desc {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
    line-height: 1.5;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  .gl-card__footer {
    border-top: 1px solid var(--border);
    padding-top: var(--space-2);
  }

  .gl-card__date {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  /* Modal */
  .gl-overlay {
    position: fixed;
    inset: 0;
    background: color-mix(in oklch, var(--bg) 60%, transparent 40%);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 50;
    padding: var(--space-4);
  }

  .gl-modal {
    background: var(--bg-elevated);
    border: 1px solid var(--border-strong);
    border-radius: var(--radius-xl);
    width: 100%;
    max-width: 480px;
    display: flex;
    flex-direction: column;
    box-shadow: 0 20px 60px color-mix(in oklch, var(--bg) 0%, transparent 70%);
  }

  .gl-modal__head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-4) var(--space-5);
    border-bottom: 1px solid var(--border);
  }

  .gl-modal__label {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
  }

  .gl-modal__close {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    background: transparent;
    border: none;
    border-radius: var(--radius-sm);
    cursor: pointer;
    color: var(--fg-muted);
  }

  .gl-modal__close:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .gl-modal__body {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-5);
  }

  .gl-modal__foot {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: var(--space-2);
    padding: var(--space-4) var(--space-5);
    border-top: 1px solid var(--border);
  }

  /* Form */
  .gl-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .gl-field--half {
    flex: 1;
  }

  .gl-field__label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    color: var(--fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .gl-row {
    display: flex;
    gap: var(--space-3);
  }

  .gl-input,
  .gl-select {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    width: 100%;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .gl-input:focus,
  .gl-select:focus {
    border-color: var(--border-strong);
  }

  .gl-textarea {
    resize: vertical;
    min-height: 72px;
  }

  .gl-error {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: #f87171;
    margin: 0;
  }

  /* Buttons */
  .gl-btn {
    padding: var(--space-2) var(--space-4);
    border-radius: var(--radius-md);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    transition: background var(--dur-instant) var(--ease-out);
    border: 1px solid transparent;
  }

  .gl-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .gl-btn--ghost {
    background: transparent;
    color: var(--fg-muted);
    border-color: var(--border);
  }

  .gl-btn--ghost:not(:disabled):hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .gl-btn--primary {
    background: color-mix(in oklch, var(--fg) 10%, transparent 90%);
    border-color: var(--border-strong);
    color: var(--fg);
  }

  .gl-btn--primary:not(:disabled):hover {
    background: color-mix(in oklch, var(--fg) 16%, transparent 84%);
  }
</style>
