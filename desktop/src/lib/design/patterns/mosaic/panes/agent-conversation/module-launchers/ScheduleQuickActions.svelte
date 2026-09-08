<script lang="ts" module>
import type { Spec } from '$lib/domain/schedule/types.js';

/** Active specs only — pause/archive states are noise here. */
export function activeSpecs(specs: readonly Spec[]): Spec[] {
  return specs.filter((s) => s.status === 'active');
}
</script>

<script lang="ts">
  /**
   * ScheduleQuickActions — chip-anchored popover with two affordances:
   *
   *   1. "Schedule this conversation" — emits `onScheduleConversation()` so
   *      the parent can navigate to /schedule/specs/new with conversation
   *      context preloaded.
   *   2. Recent active specs — picking one fires `onPickSpec(slug)`; the
   *      parent typically navigates to /schedule/specs/[slug].
   *
   * REUSE — uses the existing `specsQuery()` factory.
   *
   * CSS prefix: ml-pop-
   */
  import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
  import { Calendar, Plus } from 'lucide-svelte';
  import { onMount, untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import { specsQuery } from '$lib/api/queries/schedule.js';


  interface Props {
    workspaceSlug?: string;
    onScheduleConversation: () => void;
    onPickSpec: (slug: string) => void;
    onClose: () => void;
  }

  let {
    workspaceSlug,
    onScheduleConversation,
    onPickSpec,
    onClose,
  }: Props = $props();

  let popoverEl = $state<HTMLDivElement | null>(null);

  const optsStore = writable(
    untrack(() =>
      specsQuery({ workspaceSlug, status: 'active', limit: 20 }) as CreateQueryOptions<Spec[]>,
    ),
  );
  $effect(() => {
    optsStore.set(
      specsQuery({ workspaceSlug, status: 'active', limit: 20 }) as CreateQueryOptions<Spec[]>,
    );
  });
  const listQ = createQuery<Spec[]>(optsStore);

  const specs = $derived<Spec[]>(activeSpecs($listQ.data ?? []));

  onMount(() => {
    const onDocPointer = (ev: PointerEvent): void => {
      const target = ev.target as Node | null;
      if (!target || !popoverEl) return;
      if (!popoverEl.contains(target)) onClose();
    };
    const onKey = (e: KeyboardEvent): void => {
      if (e.key === 'Escape') {
        e.preventDefault();
        onClose();
      }
    };
    document.addEventListener('pointerdown', onDocPointer, true);
    document.addEventListener('keydown', onKey, true);
    return () => {
      document.removeEventListener('pointerdown', onDocPointer, true);
      document.removeEventListener('keydown', onKey, true);
    };
  });

  function handleSchedule(): void {
    onScheduleConversation();
    onClose();
  }

  function handlePick(slug: string): void {
    onPickSpec(slug);
    onClose();
  }
</script>

<div class="ml-pop" role="dialog" aria-label="Schedule" bind:this={popoverEl}>
  <button
    type="button"
    class="ml-pop__cta"
    onclick={handleSchedule}
    aria-label="Schedule this conversation"
  >
    <Plus size={11} aria-hidden="true" />
    <span>Schedule this conversation</span>
  </button>

  <div class="ml-pop__head ml-pop__head--bordered">
    <span class="ml-pop__head-label">RECENT SPECS</span>
  </div>

  <ul class="ml-pop__list" role="listbox">
    {#if $listQ.isLoading}
      <li role="none" class="ml-pop__status">Loading…</li>
    {:else if $listQ.isError}
      <li role="none" class="ml-pop__status ml-pop__status--err">
        Could not load schedule
      </li>
    {:else if specs.length === 0}
      <li role="none" class="ml-pop__status">No active specs</li>
    {:else}
      {#each specs as spec (spec.slug)}
        <li role="none">
          <button
            type="button"
            class="ml-pop__row"
            role="option"
            aria-selected="false"
            onclick={() => handlePick(spec.slug)}
            title={spec.slug}
          >
            <Calendar size={11} aria-hidden="true" />
            <span class="ml-pop__row-name">{spec.name}</span>
            <span class="ml-pop__row-kind">{spec.status}</span>
          </button>
        </li>
      {/each}
    {/if}
  </ul>
</div>

<style>
  .ml-pop {
    display: flex; flex-direction: column; width: 320px; max-height: 380px;
    border: 1px solid var(--border, rgba(255, 255, 255, 0.12));
    border-radius: 8px; background: var(--bg-elev, var(--bg));
    box-shadow: 0 10px 32px rgba(0, 0, 0, 0.45);
    overflow: hidden; color: var(--fg);
  }
  .ml-pop__cta {
    display: flex; align-items: center; gap: 6px;
    padding: 8px 12px; border: none; background: transparent;
    color: var(--fg); font-family: var(--font-sans);
    font-size: 12px; cursor: pointer; text-align: left;
    transition: background 80ms ease-out;
  }
  .ml-pop__cta:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
  }
  .ml-pop__head {
    padding: 6px 10px;
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    color: var(--fg-subtle);
  }
  .ml-pop__head--bordered {
    border-top: 1px solid var(--border, rgba(255, 255, 255, 0.08));
    border-bottom: 1px solid var(--border, rgba(255, 255, 255, 0.08));
  }
  .ml-pop__head-label {
    font-family: var(--font-sans);
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }
  .ml-pop__list {
    list-style: none; margin: 0; padding: 4px 0;
    overflow-y: auto; flex: 1; min-height: 0;
  }
  .ml-pop__row {
    display: grid; grid-template-columns: 14px 1fr auto;
    align-items: center; gap: 8px; width: 100%;
    padding: 5px 12px; border: none; background: transparent;
    color: var(--fg-muted); font-family: var(--font-sans);
    font-size: 11.5px; cursor: pointer; text-align: left;
    transition: background 80ms ease-out, color 80ms ease-out;
  }
  .ml-pop__row:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg);
  }
  .ml-pop__row-name { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .ml-pop__row-kind {
    font-family: var(--font-mono); font-size: 9.5px;
    color: var(--fg-subtle); text-transform: uppercase; letter-spacing: 0.04em;
  }
  .ml-pop__status {
    padding: 8px 12px; font-family: var(--font-sans);
    font-size: 11px; color: var(--fg-subtle);
  }
  .ml-pop__status--err { color: var(--signal-error, oklch(0.62 0.22 25)); }
</style>
