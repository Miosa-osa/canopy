<script lang="ts">
/** /routines/[short_id] — routine detail / edit. */
import { createMutation, createQuery, useQueryClient } from '@tanstack/svelte-query';
import { Flame, Repeat, Trash2 } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import { page } from '$app/state';
import {
  deleteRoutineMutation,
  disableRoutineMutation,
  enableRoutineMutation,
  fireRoutineMutation,
  routineQuery,
  updateRoutineMutation,
} from '$lib/api/queries/routines.js';
import type { Routine } from '$lib/domain/routines/types.js';

const queryClient = useQueryClient();
const shortId = $derived(page.params.short_id ?? '');
const optsStore = writable(untrack(() => routineQuery(shortId)));
$effect(() => {
  optsStore.set(routineQuery(shortId));
});
const routineQ = createQuery<Routine>(optsStore);
const r = $derived($routineQ.data as Routine | undefined);

let name = $state('');
let description = $state('');
let cron = $state('');
let promptTemplate = $state('');
let enabled = $state(true);

let loaded = false;
$effect(() => {
  if (r && !loaded) {
    name = r.name;
    description = r.description ?? '';
    cron = r.cron ?? '';
    promptTemplate = r.promptTemplate ?? '';
    enabled = r.enabled;
    loaded = true;
  }
});

const updateMut = createMutation(updateRoutineMutation());
const fireMut = createMutation(fireRoutineMutation());
const enableMut = createMutation(enableRoutineMutation());
const disableMut = createMutation(disableRoutineMutation());
const deleteMut = createMutation(deleteRoutineMutation());

function invalidate(): void {
  queryClient.invalidateQueries({ queryKey: ['routines'] });
}

function save(): void {
  $updateMut.mutate(
    { shortId, body: { name, description, cron, promptTemplate, enabled } },
    { onSuccess: invalidate }
  );
}

function fire(): void {
  $fireMut.mutate(shortId, { onSuccess: invalidate });
}

function toggle(): void {
  if (enabled) $disableMut.mutate(shortId, { onSuccess: invalidate });
  else $enableMut.mutate(shortId, { onSuccess: invalidate });
}

function removeRoutine(): void {
  if (!confirm('Delete this routine?')) return;
  $deleteMut.mutate(shortId, {
    onSuccess: () => {
      invalidate();
      goto('/routines');
    },
  });
}

function decodeCron(c: string): string {
  const map: Record<string, string> = {
    '0 9 * * 1': 'Every Monday at 9:00',
    '0 9 * * *': 'Every day at 9:00',
    '0 0 * * *': 'Every day at midnight',
    '*/15 * * * *': 'Every 15 minutes',
    '0 * * * *': 'Every hour',
  };
  return map[c] ?? c;
}
</script>

<div class="rd-page">
  {#if $routineQ.isLoading}
    <div class="rd-skel">Loading…</div>
  {:else if !r}
    <div class="rd-empty">Routine not found.</div>
  {:else}
    <header class="rd-head">
      <div class="rd-title-row">
        <Repeat size={18} aria-hidden="true" />
        <h1 class="rd-title">{r.name}</h1>
        <span class="rd-short">{r.shortId}</span>
        <span class="rd-pill" class:rd-pill--off={!r.enabled}>{r.enabled ? "enabled" : "disabled"}</span>
      </div>
      <div class="rd-actions">
        <button class="rd-btn" onclick={fire}>
          <Flame size={14} aria-hidden="true" /> Fire now
        </button>
        <button class="rd-btn" onclick={toggle}>
          {r.enabled ? "Disable" : "Enable"}
        </button>
        <button class="rd-btn rd-btn--danger" onclick={removeRoutine} aria-label="Delete">
          <Trash2 size={14} aria-hidden="true" />
        </button>
      </div>
    </header>

    <section class="rd-form">
      <label class="rd-field">
        <span>Name</span>
        <input type="text" bind:value={name} />
      </label>
      <label class="rd-field">
        <span>Description</span>
        <textarea rows="2" bind:value={description}></textarea>
      </label>
      <label class="rd-field">
        <span>Cron <em>{cron ? decodeCron(cron) : ""}</em></span>
        <input type="text" bind:value={cron} placeholder="0 9 * * 1" class="rd-mono" />
      </label>
      <label class="rd-field">
        <span>Prompt template</span>
        <textarea rows="6" bind:value={promptTemplate} class="rd-mono" placeholder="Use &#123;&#123;date&#125;&#125; and &#123;&#123;workspace&#125;&#125; placeholders..."></textarea>
      </label>
      <label class="rd-checkbox">
        <input type="checkbox" bind:checked={enabled} />
        <span>Enabled</span>
      </label>
      <div class="rd-submit">
        <button class="rd-btn rd-btn--primary" onclick={save}>Save changes</button>
      </div>
    </section>

    <aside class="rd-meta">
      <dl>
        <dt>Creates</dt><dd>{r.creates}</dd>
        <dt>Target agent</dt><dd>{r.targetAgentSlug ?? "—"}</dd>
        <dt>Last run</dt><dd>{r.lastRunAt ? new Date(r.lastRunAt).toLocaleString() : "never"}</dd>
        <dt>Next run</dt><dd>{r.nextRunAt ? new Date(r.nextRunAt).toLocaleString() : "—"}</dd>
        <dt>Run count</dt><dd>{r.runCount}</dd>
      </dl>
    </aside>
  {/if}
</div>

<style>
  .rd-page { padding: var(--space-4); display: grid; grid-template-columns: 1fr 280px; grid-template-rows: auto 1fr; gap: var(--space-4); }
  .rd-head { grid-column: 1 / -1; display: flex; justify-content: space-between; align-items: flex-start; gap: var(--space-3); }
  .rd-title-row { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
  .rd-title { font-size: var(--text-xl); font-weight: 600; margin: 0; }
  .rd-short { font-family: var(--font-mono); font-size: 11px; color: var(--fg-subtle); }
  .rd-pill { padding: 2px 8px; border-radius: 9999px; font-size: 11px; background: color-mix(in oklch, var(--cnp-accent) 20%, transparent); color: var(--cnp-accent); }
  .rd-pill--off { background: var(--bg-subtle); color: var(--fg-subtle); }
  .rd-actions { display: flex; gap: 6px; }
  .rd-btn { display: inline-flex; align-items: center; gap: 6px; padding: 6px 10px; border-radius: var(--radius-md); border: 1px solid var(--border); background: var(--bg-subtle); color: var(--fg); font-size: var(--text-sm); cursor: pointer; }
  .rd-btn:hover { background: var(--bg); }
  .rd-btn--primary { background: var(--cnp-accent); color: var(--cnp-accent-foreground); border-color: var(--cnp-accent); }
  .rd-btn--danger:hover { color: var(--destructive); border-color: var(--destructive); }
  .rd-form { display: flex; flex-direction: column; gap: var(--space-3); }
  .rd-field { display: flex; flex-direction: column; gap: 4px; font-size: var(--text-sm); }
  .rd-field span { color: var(--fg-subtle); font-size: 11px; text-transform: uppercase; letter-spacing: 0.04em; }
  .rd-field em { font-style: normal; color: var(--cnp-accent); text-transform: none; letter-spacing: 0; margin-left: 8px; }
  .rd-field input, .rd-field textarea { padding: 8px 10px; border: 1px solid var(--border); border-radius: var(--radius-md); background: var(--bg); color: var(--fg); font-family: var(--font-sans); font-size: var(--text-sm); }
  .rd-mono { font-family: var(--font-mono) !important; }
  .rd-checkbox { display: flex; align-items: center; gap: 8px; font-size: var(--text-sm); }
  .rd-submit { display: flex; justify-content: flex-end; }
  .rd-meta { border-left: 1px solid var(--border); padding-left: var(--space-4); }
  .rd-meta dl { display: grid; grid-template-columns: 1fr 1fr; gap: 8px 12px; font-size: var(--text-sm); }
  .rd-meta dt { color: var(--fg-subtle); text-transform: uppercase; font-size: 10px; letter-spacing: 0.04em; }
  .rd-meta dd { color: var(--fg); margin: 0; }
  .rd-empty, .rd-skel { padding: var(--space-8); text-align: center; color: var(--fg-subtle); grid-column: 1 / -1; }
</style>
