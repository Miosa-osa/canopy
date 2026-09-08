<script lang="ts">
/** /goals/[short_id] — goal detail. */
import { createMutation, createQuery, useQueryClient } from '@tanstack/svelte-query';
import { Ban, Flag, Target, Trash2 } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import { page } from '$app/state';
import {
  achieveGoalMutation,
  cancelGoalMutation,
  deleteGoalMutation,
  goalProgressMutation,
  goalQuery,
} from '$lib/api/queries/goals.js';
import type { Goal } from '$lib/domain/goals/types.js';

const queryClient = useQueryClient();
const shortId = $derived(page.params.short_id ?? '');
const optsStore = writable(untrack(() => goalQuery(shortId)));
$effect(() => {
  optsStore.set(goalQuery(shortId));
});
const goalQ = createQuery<Goal>(optsStore);
const goal = $derived($goalQ.data as Goal | undefined);

const progressMut = createMutation(goalProgressMutation());
const achieveMut = createMutation(achieveGoalMutation());
const cancelMut = createMutation(cancelGoalMutation());
const deleteMut = createMutation(deleteGoalMutation());

function invalidate(): void {
  queryClient.invalidateQueries({ queryKey: ['goals'] });
}

function setProgress(pct: number): void {
  $progressMut.mutate({ shortId, body: { progress: pct } }, { onSuccess: invalidate });
}

function achieve(): void {
  $achieveMut.mutate(shortId, { onSuccess: invalidate });
}

function cancelGoal(): void {
  if (!confirm('Cancel this goal?')) return;
  $cancelMut.mutate(shortId, { onSuccess: invalidate });
}

function removeGoal(): void {
  if (!confirm('Delete this goal? This cannot be undone.')) return;
  $deleteMut.mutate(shortId, {
    onSuccess: () => {
      invalidate();
      goto('/goals');
    },
  });
}
</script>

<div class="gd-page">
  {#if $goalQ.isLoading}
    <div class="gd-skel">Loading…</div>
  {:else if !goal}
    <div class="gd-empty">Goal not found.</div>
  {:else}
    <header class="gd-head">
      <div class="gd-title-row">
        <Target size={18} aria-hidden="true" />
        <h1 class="gd-title">{goal.title}</h1>
        <span class="gd-short">{goal.shortId}</span>
        <span class="gd-pill gd-pill--{goal.status}">{goal.status}</span>
      </div>
      <div class="gd-actions">
        {#if goal.status !== "achieved" && goal.status !== "cancelled"}
          <button class="gd-btn" onclick={achieve}>
            <Flag size={14} aria-hidden="true" /> Achieve
          </button>
          <button class="gd-btn" onclick={cancelGoal}>
            <Ban size={14} aria-hidden="true" /> Cancel
          </button>
        {/if}
        <button class="gd-btn gd-btn--danger" onclick={removeGoal} aria-label="Delete">
          <Trash2 size={14} aria-hidden="true" />
        </button>
      </div>
    </header>

    <section class="gd-body">
      <div class="gd-main">
        <p class="gd-desc">{goal.description || "No description."}</p>

        <div class="gd-progress">
          <label for="progress" class="gd-label">Progress — {goal.progress ?? 0}%</label>
          <input
            id="progress"
            type="range"
            min="0"
            max="100"
            value={goal.progress ?? 0}
            onchange={(e) => setProgress(Number((e.target as HTMLInputElement).value))}
          />
        </div>

        {#if goal.successCriteria}
          <div class="gd-criteria">
            <h3 class="gd-label">Success criteria</h3>
            <p>{goal.successCriteria}</p>
          </div>
        {/if}
      </div>

      <aside class="gd-side">
        <dl class="gd-props">
          <dt>Priority</dt><dd>{goal.priority ?? "—"}</dd>
          <dt>Owner</dt><dd>{goal.ownerId ?? "—"}</dd>
          <dt>Target date</dt><dd>{goal.targetDate ? new Date(goal.targetDate).toLocaleDateString() : "—"}</dd>
          <dt>Workspace</dt><dd>{goal.workspaceSlug}</dd>
          {#if goal.achievedAt}
            <dt>Achieved</dt><dd>{new Date(goal.achievedAt).toLocaleDateString()}</dd>
          {/if}
        </dl>
      </aside>
    </section>
  {/if}
</div>

<style>
  .gd-page { padding: var(--space-4); display: flex; flex-direction: column; gap: var(--space-4); }
  .gd-head { display: flex; justify-content: space-between; align-items: flex-start; gap: var(--space-3); }
  .gd-title-row { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
  .gd-title { font-size: var(--text-xl); font-weight: 600; margin: 0; }
  .gd-short { font-family: var(--font-mono); font-size: 11px; color: var(--fg-subtle); }
  .gd-pill { padding: 2px 8px; border-radius: 9999px; font-size: 11px; text-transform: lowercase; background: var(--bg-subtle); }
  .gd-pill--active { background: color-mix(in oklch, var(--cnp-accent) 20%, transparent); color: var(--cnp-accent); }
  .gd-pill--achieved { background: color-mix(in oklch, var(--success) 20%, transparent); color: var(--success); }
  .gd-pill--blocked, .gd-pill--cancelled { background: color-mix(in oklch, var(--destructive) 20%, transparent); color: var(--destructive); }
  .gd-actions { display: flex; gap: 6px; }
  .gd-btn { display: inline-flex; align-items: center; gap: 6px; padding: 6px 10px; border-radius: var(--radius-md); border: 1px solid var(--border); background: var(--bg-subtle); color: var(--fg); font-size: var(--text-sm); cursor: pointer; }
  .gd-btn:hover { background: var(--bg); }
  .gd-btn--danger:hover { color: var(--destructive); border-color: var(--destructive); }
  .gd-body { display: grid; grid-template-columns: 1fr 280px; gap: var(--space-4); }
  .gd-main { display: flex; flex-direction: column; gap: var(--space-4); }
  .gd-desc { color: var(--fg); line-height: 1.6; margin: 0; }
  .gd-progress { display: flex; flex-direction: column; gap: 4px; }
  .gd-progress input[type=range] { width: 100%; accent-color: var(--cnp-accent); }
  .gd-label { font-size: var(--text-xs); text-transform: uppercase; letter-spacing: 0.04em; color: var(--fg-subtle); font-weight: 600; margin: 0 0 4px; }
  .gd-criteria p { color: var(--fg-muted); font-size: var(--text-sm); line-height: 1.6; }
  .gd-side { border-left: 1px solid var(--border); padding-left: var(--space-4); }
  .gd-props { display: grid; grid-template-columns: 1fr 1fr; gap: 8px 12px; font-size: var(--text-sm); }
  .gd-props dt { color: var(--fg-subtle); text-transform: uppercase; font-size: 10px; letter-spacing: 0.04em; }
  .gd-props dd { color: var(--fg); margin: 0; }
  .gd-empty, .gd-skel { padding: var(--space-8); text-align: center; color: var(--fg-subtle); }
</style>
