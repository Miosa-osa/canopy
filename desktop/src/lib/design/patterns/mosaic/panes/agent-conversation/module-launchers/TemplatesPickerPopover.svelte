<script lang="ts" module>
import type { Template } from '$lib/domain/templates/types.js';

export function filterTemplates(templates: readonly Template[], query: string): Template[] {
  const q = query.trim().toLowerCase();
  if (!q) return [...templates];
  return templates.filter(
    (t) =>
      t.name.toLowerCase().includes(q) ||
      t.slug.toLowerCase().includes(q) ||
      (t.description ?? '').toLowerCase().includes(q)
  );
}
</script>

<script lang="ts">
  /**
   * TemplatesPickerPopover — pick a template to instantiate. Fires
   * `instantiate_template` upward via `onPick` so the dispatcher (or a
   * sibling navigation handler) can take the user to the slug-detail
   * page or run an instantiation directly.
   *
   * READ-ONLY view — no new endpoints. Reuses `templatesQuery()`.
   *
   * CSS prefix: ml-pop-
   */
  import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
  import { LayoutTemplate, Search } from 'lucide-svelte';
  import { onMount, tick, untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import { templatesQuery } from '$lib/api/queries/templates.js';
  import type { TemplateKind } from '$lib/domain/templates/types.js';

  interface Props {
    /** Restrict to a kind. Defaults to all kinds — filter client-side. */
    kind?: TemplateKind;
    onPick: (template: Template) => void;
    onClose: () => void;
  }

  let { kind, onPick, onClose }: Props = $props();

  let query = $state('');
  let popoverEl = $state<HTMLDivElement | null>(null);
  let inputEl = $state<HTMLInputElement | null>(null);

  const optsStore = writable(
    untrack(() =>
      templatesQuery({ kind, limit: 200 }) as CreateQueryOptions<Template[]>,
    ),
  );
  $effect(() => {
    optsStore.set(
      templatesQuery({ kind, limit: 200 }) as CreateQueryOptions<Template[]>,
    );
  });
  const listQ = createQuery<Template[]>(optsStore);

  const templates = $derived<Template[]>(
    filterTemplates($listQ.data ?? [], query),
  );

  onMount(() => {
    void tick().then(() => inputEl?.focus());
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

  function handlePick(t: Template): void {
    onPick(t);
    onClose();
  }
</script>

<div
  class="ml-pop"
  role="dialog"
  aria-label="Pick a template"
  bind:this={popoverEl}
>
  <div class="ml-pop__head">
    <Search size={11} aria-hidden="true" />
    <input
      type="search"
      class="ml-pop__input"
      placeholder="Search templates…"
      bind:value={query}
      bind:this={inputEl}
      aria-label="Filter templates"
    />
  </div>

  <ul class="ml-pop__list" role="listbox">
    {#if $listQ.isLoading}
      <li role="none" class="ml-pop__status">Loading…</li>
    {:else if $listQ.isError}
      <li role="none" class="ml-pop__status ml-pop__status--err">
        Could not load templates
      </li>
    {:else if templates.length === 0}
      <li role="none" class="ml-pop__status">No templates available</li>
    {:else}
      {#each templates as t (t.slug)}
        <li role="none">
          <button
            type="button"
            class="ml-pop__row"
            role="option"
            aria-selected="false"
            onclick={() => handlePick(t)}
            title={t.description ?? t.slug}
          >
            <LayoutTemplate size={11} aria-hidden="true" />
            <span class="ml-pop__row-name">{t.name}</span>
            <span class="ml-pop__row-kind">{t.kind}</span>
          </button>
        </li>
      {/each}
    {/if}
  </ul>
</div>

<style>
  .ml-pop {
    display: flex; flex-direction: column; width: 320px; max-height: 360px;
    border: 1px solid var(--border, rgba(255, 255, 255, 0.12));
    border-radius: 8px; background: var(--bg-elev, var(--bg));
    box-shadow: 0 10px 32px rgba(0, 0, 0, 0.45);
    overflow: hidden; color: var(--fg);
  }
  .ml-pop__head {
    display: flex; align-items: center; gap: 6px;
    padding: 6px 10px;
    border-bottom: 1px solid var(--border, rgba(255, 255, 255, 0.08));
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    color: var(--fg-subtle);
  }
  .ml-pop__input {
    flex: 1; border: none; outline: none;
    background: transparent; color: var(--fg);
    font-family: var(--font-sans); font-size: 12px;
  }
  .ml-pop__input::placeholder { color: var(--fg-subtle); }
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
