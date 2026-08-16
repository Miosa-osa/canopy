<script lang="ts" module>
  /**
   * Pure helpers — extracted so vitest can test them in a Node project.
   */
  import type { DriveEntry } from '$lib/api/queries/drive.js';

  /**
   * Filter Drive entries to commandable kinds (workflow, prompt, notebook,
   * mcp_server) and apply a substring match on `name + slug`. Folder /
   * env_vars / rule are excluded — they don't render usefully as a picker
   * row.
   */
  export function filterDriveEntries(
    entries: readonly DriveEntry[],
    query: string,
  ): DriveEntry[] {
    const COMMANDABLE = new Set([
      'workflow',
      'prompt',
      'notebook',
      'mcp_server',
    ]);
    const filtered = entries.filter((e) => COMMANDABLE.has(e.kind));
    const q = query.trim().toLowerCase();
    if (!q) return filtered;
    return filtered.filter(
      (e) =>
        (e.name ?? '').toLowerCase().includes(q) ||
        e.slug.toLowerCase().includes(q),
    );
  }
</script>

<script lang="ts">
  /**
   * DrivePickerPopover — chip-anchored popover that lists Drive entries the
   * user can drop into the composer as a reference.
   *
   * REUSE — talks to `driveListQuery()` (no new fetcher). The pickers in
   * this folder are READ-ONLY views.
   *
   * Closes on Esc, outside click, or selection. Focus returns to the
   * trigger via the parent's `onClose` handler.
   *
   * CSS prefix: ml-pop-
   */
  import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
  import {
    BookOpen,
    FileText,
    GitCommit,
    Plug,
    Search,
    type Icon as LucideIcon,
  } from 'lucide-svelte';
  import { onMount, tick, untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import { driveListQuery } from '$lib/api/queries/drive.js';
  import type { DriveEntry } from '$lib/api/queries/drive.js';

  interface Props {
    /** Personal | team — defaults to personal. */
    scope?: 'personal' | 'team';
    /** Fires when the user picks an entry. The string is what to insert
     *  into the composer (e.g. `"@drive:squash-commits "`). */
    onPick: (reference: string, entry: DriveEntry) => void;
    /** Outside click / Esc → close. */
    onClose: () => void;
  }

  let { scope = 'personal', onPick, onClose }: Props = $props();

  let query = $state('');
  let popoverEl = $state<HTMLDivElement | null>(null);
  let inputEl = $state<HTMLInputElement | null>(null);

  // ── Drive listing ──────────────────────────────────────────────────────────
  const optsStore = writable(
    untrack(() =>
      driveListQuery({ scope, archived: false, limit: 200 }) as CreateQueryOptions<DriveEntry[]>,
    ),
  );
  $effect(() => {
    optsStore.set(
      driveListQuery({ scope, archived: false, limit: 200 }) as CreateQueryOptions<DriveEntry[]>,
    );
  });
  const listQ = createQuery<DriveEntry[]>(optsStore);

  const entries = $derived<DriveEntry[]>(
    filterDriveEntries($listQ.data ?? [], query),
  );

  // ── Focus + outside click + Esc ────────────────────────────────────────────
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

  function handlePick(entry: DriveEntry): void {
    onPick(`@drive:${entry.slug} `, entry);
    onClose();
  }

  function iconFor(kind: string): typeof LucideIcon {
    switch (kind) {
      case 'workflow':
        return GitCommit;
      case 'prompt':
        return FileText;
      case 'notebook':
        return BookOpen;
      case 'mcp_server':
        return Plug;
      default:
        return FileText;
    }
  }
</script>

<div
  class="ml-pop"
  role="dialog"
  aria-label="Pick a Drive entry"
  bind:this={popoverEl}
>
  <div class="ml-pop__head">
    <Search size={11} aria-hidden="true" />
    <input
      type="search"
      class="ml-pop__input"
      placeholder="Search Drive…"
      bind:value={query}
      bind:this={inputEl}
      aria-label="Filter Drive entries"
    />
  </div>

  <ul class="ml-pop__list" role="listbox">
    {#if $listQ.isLoading}
      <li role="none" class="ml-pop__status">Loading…</li>
    {:else if $listQ.isError}
      <li role="none" class="ml-pop__status ml-pop__status--err">
        Could not load Drive entries
      </li>
    {:else if entries.length === 0}
      <li role="none" class="ml-pop__status">No matching entries</li>
    {:else}
      {#each entries as entry (entry.id)}
        {@const ActiveIcon = iconFor(entry.kind)}
        <li role="none">
          <button
            type="button"
            class="ml-pop__row"
            role="option"
            aria-selected="false"
            onclick={() => handlePick(entry)}
            title={entry.slug}
          >
            <ActiveIcon size={11} aria-hidden="true" />
            <span class="ml-pop__row-name">{entry.name || entry.slug}</span>
            <span class="ml-pop__row-kind">{entry.kind}</span>
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
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 10px;
    border-bottom: 1px solid var(--border, rgba(255, 255, 255, 0.08));
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    color: var(--fg-subtle);
  }

  .ml-pop__input {
    flex: 1;
    border: none;
    outline: none;
    background: transparent;
    color: var(--fg);
    font-family: var(--font-sans);
    font-size: 12px;
  }
  .ml-pop__input::placeholder { color: var(--fg-subtle); }

  .ml-pop__list {
    list-style: none;
    margin: 0;
    padding: 4px 0;
    overflow-y: auto;
    flex: 1;
    min-height: 0;
  }

  .ml-pop__row {
    display: grid;
    grid-template-columns: 14px 1fr auto;
    align-items: center;
    gap: 8px;
    width: 100%;
    padding: 5px 12px;
    border: none;
    background: transparent;
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: 11.5px;
    cursor: pointer;
    text-align: left;
    transition: background 80ms ease-out, color 80ms ease-out;
  }

  .ml-pop__row:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg);
  }

  .ml-pop__row-name {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .ml-pop__row-kind {
    font-family: var(--font-mono);
    font-size: 9.5px;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .ml-pop__status {
    padding: 8px 12px;
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
  }

  .ml-pop__status--err { color: var(--signal-error, oklch(0.62 0.22 25)); }
</style>
