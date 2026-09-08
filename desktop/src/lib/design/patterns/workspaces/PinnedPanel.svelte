<script lang="ts">
/**
 * PinnedPanel — sidebar panel showing pinned items for a workspace.
 * Drag-to-reorder via svelte-dnd-action.
 * CSS prefix: pp-
 *
 * Props:
 *   workspaceSlug — the workspace to show/manage pins for
 */
import { createMutation, createQuery, useQueryClient } from '@tanstack/svelte-query';
import { GripVertical, Pin, X } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { type DndEvent, dndzone } from 'svelte-dnd-action';
import { apiDelete, apiGet, apiPost, apiPut } from '$lib/api/client.js';

interface PinnedItem {
  id: string;
  workspaceSlug: string;
  itemType: string;
  itemRef: string;
  position: number;
}

interface Props {
  workspaceSlug: string;
}

let { workspaceSlug }: Props = $props();

// ── Query ─────────────────────────────────────────────────────────────────

const FLIP_MS = 160;

function pinsQueryKey(slug: string) {
  return ['workspaces', slug, 'pins'] as const;
}

const queryOptsStore = writable(
  untrack(() => ({
    queryKey: pinsQueryKey(workspaceSlug),
    queryFn: () =>
      apiGet<{ data: PinnedItem[] }>(`/workspaces/${workspaceSlug}/pins`).then((r) => r.data),
  }))
);

$effect(() => {
  queryOptsStore.set({
    queryKey: pinsQueryKey(workspaceSlug),
    queryFn: () =>
      apiGet<{ data: PinnedItem[] }>(`/workspaces/${workspaceSlug}/pins`).then((r) => r.data),
  });
});

const pinsQ = createQuery<PinnedItem[]>(queryOptsStore);
const queryClient = useQueryClient();

// Local optimistic copy — frozen during drag so remote refetches don't reorder DOM mid-gesture.
let localPins = $state<PinnedItem[]>([]);
let isDragging = false;

$effect(() => {
  if (!isDragging) localPins = $pinsQ.data ?? [];
});

// ── Delete mutation ────────────────────────────────────────────────────────

const deleteMut = createMutation({
  mutationFn: ({ type, ref }: { type: string; ref: string }) =>
    apiDelete(
      `/workspaces/${workspaceSlug}/pins/${encodeURIComponent(type)}/${encodeURIComponent(ref)}`
    ),
  onSuccess: () => {
    void queryClient.invalidateQueries({ queryKey: pinsQueryKey(workspaceSlug) });
  },
});

// ── Reorder mutation ───────────────────────────────────────────────────────

const reorderMut = createMutation({
  mutationFn: (items: PinnedItem[]) =>
    apiPut(`/workspaces/${workspaceSlug}/pins/reorder`, {
      items: items.map((p) => ({ id: p.id })),
    }),
});

// ── DnD handlers ──────────────────────────────────────────────────────────

function handleConsider(e: CustomEvent<DndEvent<PinnedItem>>) {
  isDragging = true;
  localPins = e.detail.items;
}

function handleFinalize(e: CustomEvent<DndEvent<PinnedItem>>) {
  isDragging = false;
  localPins = e.detail.items;
  $reorderMut.mutate(localPins);
}

// ── Label helper ──────────────────────────────────────────────────────────

function itemLabel(pin: PinnedItem): string {
  return `${pin.itemType}:${pin.itemRef}`;
}
</script>

<aside class="pp-panel" aria-label="Pinned items">
  <header class="pp-header">
    <Pin size={11} aria-hidden="true" class="pp-header-icon" />
    <span class="pp-header-label">Pinned</span>
    <span class="pp-count" aria-label="{localPins.length} pinned items">
      {localPins.length > 0 ? localPins.length : ''}
    </span>
  </header>

  {#if $pinsQ.isLoading}
    <div class="pp-empty">Loading…</div>
  {:else if localPins.length === 0}
    <div class="pp-empty">No pinned items yet</div>
  {:else}
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <ul
      class="pp-list"
      use:dndzone={{ items: localPins, flipDurationMs: FLIP_MS, type: 'pinned-items' }}
      onconsider={handleConsider}
      onfinalize={handleFinalize}
      role="list"
      aria-label="Pinned items — drag to reorder"
    >
      {#each localPins as pin (pin.id)}
        <li class="pp-item" role="listitem">
          <span class="pp-drag-handle" aria-hidden="true" title="Drag to reorder">
            <GripVertical size={10} />
          </span>
          <span class="pp-item-type" aria-hidden="true">{pin.itemType}</span>
          <span class="pp-item-ref" title={itemLabel(pin)}>{pin.itemRef}</span>
          <button
            class="pp-unpin"
            onclick={() => $deleteMut.mutate({ type: pin.itemType, ref: pin.itemRef })}
            aria-label="Unpin {itemLabel(pin)}"
            title="Unpin"
          >
            <X size={10} />
          </button>
        </li>
      {/each}
    </ul>
  {/if}
</aside>

<style>
  .pp-panel {
    display: flex;
    flex-direction: column;
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    background: var(--bg-inset);
    overflow: hidden;
    min-width: 0;
  }

  .pp-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    border-bottom: 1px solid var(--border);
    background: color-mix(in oklch, var(--fg) 3%, transparent);
    flex-shrink: 0;
  }

  :global(.pp-header-icon) {
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  .pp-header-label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--fg-subtle);
    flex: 1;
  }

  .pp-count {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .pp-list {
    list-style: none;
    margin: 0;
    padding: var(--space-1) 0;
    display: flex;
    flex-direction: column;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
    max-height: 240px;
  }

  .pp-item {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    padding: var(--space-1) var(--space-3);
    min-height: 28px;
    transition: background var(--dur-instant) ease;
  }

  .pp-item:hover {
    background: color-mix(in oklch, var(--fg) 5%, transparent);
  }

  .pp-drag-handle {
    color: var(--fg-subtle);
    cursor: grab;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    opacity: 0;
    transition: opacity var(--dur-instant) ease;
  }

  .pp-item:hover .pp-drag-handle {
    opacity: 1;
  }

  .pp-drag-handle:active {
    cursor: grabbing;
  }

  .pp-item-type {
    font-family: var(--font-mono);
    font-size: 9px;
    color: var(--fg-subtle);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    padding: 1px 4px;
    border-radius: var(--radius-sm);
    flex-shrink: 0;
    text-transform: lowercase;
  }

  .pp-item-ref {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .pp-unpin {
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 18px;
    height: 18px;
    border: none;
    background: transparent;
    color: var(--fg-subtle);
    cursor: pointer;
    border-radius: var(--radius-sm);
    opacity: 0;
    transition: opacity var(--dur-instant) ease, color var(--dur-instant) ease,
      background var(--dur-instant) ease;
  }

  .pp-item:hover .pp-unpin {
    opacity: 1;
  }

  .pp-unpin:hover {
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 10%, transparent);
  }

  .pp-unpin:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
    opacity: 1;
  }

  .pp-empty {
    padding: var(--space-3) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
  }
</style>
