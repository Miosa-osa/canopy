<script lang="ts" module>
  import type { SandboxStateRow } from '$lib/domain/sandboxes_ng/types.js';

  /** Active sandboxes — anything not in `archived` / `failed`. */
  export function activeSandboxes(
    rows: readonly SandboxStateRow[],
  ): SandboxStateRow[] {
    return rows.filter((r) => r.state !== 'archived' && r.state !== 'failed');
  }
</script>

<script lang="ts">
  /**
   * SandboxQuickActions — chip-anchored popover that lists the user's
   * active sandboxes with a "+ New sandbox" affordance.
   *
   * REUSE — pulls state from `sandboxStatesQuery()` in
   * `$lib/api/queries/sandboxes_ng.js`. Picking an active sandbox emits
   * `onPickSandbox(sandboxId)` so the parent (ComposerChips) can decide
   * what to do — e.g. embed it in the active pane or insert a reference.
   *
   * "+ New sandbox" emits `onNewSandbox()` — the parent navigates to the
   * sandboxes section or opens a creation dialog. We stay read-only here.
   *
   * CSS prefix: ml-pop-
   */
  import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
  import { Box, Plus } from 'lucide-svelte';
  import { onMount, untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import { sandboxStatesQuery } from '$lib/api/queries/sandboxes_ng.js';
  import type { SandboxStateRow } from '$lib/domain/sandboxes_ng/types.js';

  interface Props {
    workspaceSlug?: string;
    onPickSandbox: (sandboxId: string) => void;
    onNewSandbox: () => void;
    onClose: () => void;
  }

  let { workspaceSlug, onPickSandbox, onNewSandbox, onClose }: Props = $props();

  let popoverEl = $state<HTMLDivElement | null>(null);

  const optsStore = writable(
    untrack(() =>
      sandboxStatesQuery({ workspaceSlug }) as CreateQueryOptions<SandboxStateRow[]>,
    ),
  );
  $effect(() => {
    optsStore.set(
      sandboxStatesQuery({ workspaceSlug }) as CreateQueryOptions<SandboxStateRow[]>,
    );
  });
  const listQ = createQuery<SandboxStateRow[]>(optsStore);

  const sandboxes = $derived<SandboxStateRow[]>(
    activeSandboxes($listQ.data ?? []),
  );

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

  function handlePick(id: string): void {
    onPickSandbox(id);
    onClose();
  }

  function handleNew(): void {
    onNewSandbox();
    onClose();
  }
</script>

<div
  class="ml-pop"
  role="dialog"
  aria-label="Sandboxes"
  bind:this={popoverEl}
>
  <div class="ml-pop__head">
    <span class="ml-pop__head-label">SANDBOXES</span>
    <button
      type="button"
      class="ml-pop__head-action"
      onclick={handleNew}
      aria-label="New sandbox"
    >
      <Plus size={11} aria-hidden="true" />
      <span>New</span>
    </button>
  </div>

  <ul class="ml-pop__list" role="listbox">
    {#if $listQ.isLoading}
      <li role="none" class="ml-pop__status">Loading…</li>
    {:else if $listQ.isError}
      <li role="none" class="ml-pop__status ml-pop__status--err">
        Could not load sandboxes
      </li>
    {:else if sandboxes.length === 0}
      <li role="none" class="ml-pop__status">No active sandboxes</li>
    {:else}
      {#each sandboxes as sb (sb.sandboxId)}
        <li role="none">
          <button
            type="button"
            class="ml-pop__row"
            role="option"
            aria-selected="false"
            onclick={() => handlePick(sb.sandboxId)}
            title={sb.sandboxId}
          >
            <Box size={11} aria-hidden="true" />
            <span class="ml-pop__row-name">{sb.sandboxId}</span>
            <span class="ml-pop__row-kind">{sb.state}</span>
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
    display: flex; align-items: center; justify-content: space-between;
    padding: 6px 10px;
    border-bottom: 1px solid var(--border, rgba(255, 255, 255, 0.08));
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    color: var(--fg-subtle);
  }
  .ml-pop__head-label {
    font-family: var(--font-sans);
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }
  .ml-pop__head-action {
    display: inline-flex; align-items: center; gap: 4px;
    padding: 2px 8px; border: 1px solid var(--border, rgba(255, 255, 255, 0.12));
    border-radius: 6px; background: transparent; color: var(--fg);
    font-family: var(--font-sans); font-size: 10.5px; cursor: pointer;
    transition: background 80ms ease-out, color 80ms ease-out;
  }
  .ml-pop__head-action:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
  }
  .ml-pop__list {
    list-style: none; margin: 0; padding: 4px 0;
    overflow-y: auto; flex: 1; min-height: 0;
  }
  .ml-pop__row {
    display: grid; grid-template-columns: 14px 1fr auto;
    align-items: center; gap: 8px; width: 100%;
    padding: 5px 12px; border: none; background: transparent;
    color: var(--fg-muted); font-family: var(--font-mono);
    font-size: 11px; cursor: pointer; text-align: left;
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
