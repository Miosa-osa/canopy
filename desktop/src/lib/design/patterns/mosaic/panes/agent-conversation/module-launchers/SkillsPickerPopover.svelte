<script lang="ts" module>
  import type { Skill } from '$lib/domain/skills/types.js';

  /**
   * Filter to enabled skills with substring match on name + slug + tags.
   */
  export function filterSkills(
    skills: readonly Skill[],
    query: string,
  ): Skill[] {
    const enabled = skills.filter((s) => s.enabled !== false);
    const q = query.trim().toLowerCase();
    if (!q) return enabled;
    return enabled.filter(
      (s) =>
        s.name.toLowerCase().includes(q) ||
        s.slug.toLowerCase().includes(q) ||
        (s.tags ?? []).some((t) => t.toLowerCase().includes(q)),
    );
  }
</script>

<script lang="ts">
  /**
   * SkillsPickerPopover — pick an enabled skill to apply to the active
   * conversation. Fires `apply_skill` upward via `onPick` so the dispatcher
   * can attach the skill to the current session.
   *
   * REUSE — uses the existing `skillsQuery()` factory.
   *
   * CSS prefix: ml-pop- (shared with DrivePickerPopover).
   */
  import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
  import { Search, Zap } from 'lucide-svelte';
  import { onMount, tick, untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import { skillsQuery } from '$lib/api/queries/skills.js';
  import type { Skill } from '$lib/domain/skills/types.js';

  interface Props {
    onPick: (skill: Skill) => void;
    onClose: () => void;
  }

  let { onPick, onClose }: Props = $props();

  let query = $state('');
  let popoverEl = $state<HTMLDivElement | null>(null);
  let inputEl = $state<HTMLInputElement | null>(null);

  const optsStore = writable(
    untrack(() => skillsQuery({ enabled: true }) as CreateQueryOptions<Skill[]>),
  );
  const listQ = createQuery<Skill[]>(optsStore);

  const skills = $derived<Skill[]>(filterSkills($listQ.data ?? [], query));

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

  function handlePick(skill: Skill): void {
    onPick(skill);
    onClose();
  }
</script>

<div
  class="ml-pop"
  role="dialog"
  aria-label="Pick a skill to apply"
  bind:this={popoverEl}
>
  <div class="ml-pop__head">
    <Search size={11} aria-hidden="true" />
    <input
      type="search"
      class="ml-pop__input"
      placeholder="Search skills…"
      bind:value={query}
      bind:this={inputEl}
      aria-label="Filter skills"
    />
  </div>

  <ul class="ml-pop__list" role="listbox">
    {#if $listQ.isLoading}
      <li role="none" class="ml-pop__status">Loading…</li>
    {:else if $listQ.isError}
      <li role="none" class="ml-pop__status ml-pop__status--err">
        Could not load skills
      </li>
    {:else if skills.length === 0}
      <li role="none" class="ml-pop__status">No skills available</li>
    {:else}
      {#each skills as skill (skill.slug)}
        <li role="none">
          <button
            type="button"
            class="ml-pop__row"
            role="option"
            aria-selected="false"
            onclick={() => handlePick(skill)}
            title={skill.description ?? skill.slug}
          >
            <Zap size={11} aria-hidden="true" />
            <span class="ml-pop__row-name">{skill.name}</span>
            <span class="ml-pop__row-kind">{skill.kind}</span>
          </button>
        </li>
      {/each}
    {/if}
  </ul>
</div>

<style>
  .ml-pop {
    display: flex;
    flex-direction: column;
    width: 320px;
    max-height: 360px;
    border: 1px solid var(--border, rgba(255, 255, 255, 0.12));
    border-radius: 8px;
    background: var(--bg-elev, var(--bg));
    box-shadow: 0 10px 32px rgba(0, 0, 0, 0.45);
    overflow: hidden;
    color: var(--fg);
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
