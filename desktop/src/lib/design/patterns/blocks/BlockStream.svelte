<script lang="ts">
  /**
   * BlockStream — vertical list of Block components for one session.
   *
   * Reads via TanStack Query (`blocksListQuery`) and renders each row
   * through `<Block />`. Auto-scrolls to bottom unless the user has
   * scrolled up >40px (matches TranscriptView's heuristic).
   *
   * No virtualization is applied directly here — the list is rendered as
   * plain DOM since `@tanstack/svelte-virtual` is not yet a project dep.
   * If/when added, swap the inner `{#each}` for a virtual-list variant
   * without touching consumers of this component.
   *
   * Thin component — owns scroll heuristic + delegate-to-`<Block />`.
   * State (data) lives in TanStack; mutations bubble via callback props.
   *
   * Keyboard navigation: ↑/↓ move focus, Escape deselects, c=copy,
   * r=rerun, Enter=toggle-collapse on the focused block.
   *
   * CSS prefix: blkst-
   */

  import { tick } from 'svelte';
  import { type CreateQueryOptions, createQuery, useQueryClient } from '@tanstack/svelte-query';

  import { apiDelete, apiPost } from '$lib/api/client.js';
  import { blocksListQuery } from '$lib/api/queries/blocks.js';
  import type { Block as BlockType, BlockListQuery } from '$lib/domain/blocks/types.js';
  import { toasts } from '$lib/stores/toasts.svelte.js';

  import Block from './Block.svelte';

  interface Props {
    sessionId: string;
    /** Optional filters passed through to the list query. */
    filter?: BlockListQuery;
    /** When true, applies a "running" affordance to the container. */
    isStreaming?: boolean;
    /** Per-block callbacks bubbled from `<Block />` components. */
    onCopy?: (block: BlockType) => void;
    onRerun?: (block: BlockType) => void;
    onShare?: (block: BlockType) => void;
    onPin?: (block: BlockType) => void;
    onDelete?: (block: BlockType) => void;
  }

  let {
    sessionId,
    filter = {},
    isStreaming = false,
    onCopy: externalOnCopy,
    onRerun: externalOnRerun,
    onShare: externalOnShare,
    onPin: externalOnPin,
    onDelete: externalOnDelete,
  }: Props = $props();

  const queryClient = useQueryClient();

  const query = createQuery<BlockType[]>(
    blocksListQuery(sessionId, filter) as CreateQueryOptions<BlockType[]>,
  );

  const blocks = $derived<BlockType[]>(($query.data ?? []) as BlockType[]);

  // ── Pinned blocks (local set, persisted to localStorage) ─────────────────

  const PINNED_KEY = $derived(`canopy:pinned-blocks:${sessionId}`);

  function loadPinned(): Set<string> {
    try {
      const raw = localStorage.getItem(PINNED_KEY);
      if (raw) return new Set<string>(JSON.parse(raw) as string[]);
    } catch {
      // ignore parse errors
    }
    return new Set<string>();
  }

  let pinnedBlocks = $state<Set<string>>(loadPinned());

  function savePinned() {
    try {
      localStorage.setItem(PINNED_KEY, JSON.stringify([...pinnedBlocks]));
    } catch {
      // ignore quota errors
    }
  }

  // ── Block action handlers ─────────────────────────────────────────────────

  function handleCopy(block: BlockType) {
    const text =
      block.inputText ??
      block.outputText ??
      JSON.stringify(block);
    navigator.clipboard.writeText(text).then(
      () => toasts.success('Copied to clipboard'),
      () => toasts.error('Failed to copy'),
    );
    externalOnCopy?.(block);
  }

  function handleRerun(block: BlockType) {
    if (block.kind !== 'command') {
      toasts.info('Only commands can be rerun');
      externalOnRerun?.(block);
      return;
    }
    const command = block.inputText ?? '';
    apiPost(`/sessions/${sessionId}/messages`, { content: command }).catch(() => {
      toasts.error('Failed to rerun command');
    });
    externalOnRerun?.(block);
  }

  function handleShare(block: BlockType) {
    const link = `canopy://blocks/${block.id}`;
    navigator.clipboard.writeText(link).then(
      () => toasts.success('Block link copied'),
      () => toasts.error('Failed to copy link'),
    );
    externalOnShare?.(block);
  }

  function handlePin(block: BlockType) {
    const next = new Set(pinnedBlocks);
    if (next.has(block.id)) {
      next.delete(block.id);
    } else {
      next.add(block.id);
    }
    pinnedBlocks = next;
    savePinned();
    externalOnPin?.(block);
  }

  function handleDelete(block: BlockType) {
    // Optimistically remove from local cache first
    const listKey = ['blocks', sessionId, 'list', filter] as const;
    queryClient.setQueryData<BlockType[]>(listKey, (old) =>
      (old ?? []).filter((b) => b.id !== block.id),
    );
    // Best-effort server delete; restore on failure
    apiDelete(`/sessions/${sessionId}/blocks/${block.id}`).catch(() => {
      queryClient.invalidateQueries({ queryKey: ['blocks', sessionId] });
      toasts.error('Failed to delete block');
    });
    externalOnDelete?.(block);
  }

  // ── Keyboard navigation ───────────────────────────────────────────────────

  let focusedBlockIndex = $state(-1);

  /** Refs to each rendered block article element, indexed by blocks array order. */
  let blockEls: (HTMLElement | undefined)[] = $state([]);

  $effect(() => {
    // Resize the refs array whenever blocks changes
    blockEls = Array(blocks.length).fill(undefined);
  });

  $effect(() => {
    if (focusedBlockIndex < 0) return;
    const el = blockEls[focusedBlockIndex];
    if (el) {
      el.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    }
  });

  function handleKeydown(e: KeyboardEvent) {
    // Only handle bare key presses (no Ctrl/Cmd/Alt modifier)
    if (e.ctrlKey || e.metaKey || e.altKey) return;

    const len = blocks.length;
    if (len === 0) return;

    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        focusedBlockIndex = Math.min(focusedBlockIndex + 1, len - 1);
        if (focusedBlockIndex < 0) focusedBlockIndex = 0;
        break;
      case 'ArrowUp':
        e.preventDefault();
        focusedBlockIndex = Math.max(focusedBlockIndex - 1, 0);
        break;
      case 'Escape':
        focusedBlockIndex = -1;
        break;
      case 'c':
        if (focusedBlockIndex >= 0) {
          e.preventDefault();
          handleCopy(blocks[focusedBlockIndex]);
        }
        break;
      case 'r':
        if (focusedBlockIndex >= 0) {
          e.preventDefault();
          handleRerun(blocks[focusedBlockIndex]);
        }
        break;
      case 'Enter':
        // Toggle collapse is handled inside Block.svelte via its own toggle button;
        // we programmatically click the toggle button of the focused block's article.
        if (focusedBlockIndex >= 0) {
          e.preventDefault();
          const el = blockEls[focusedBlockIndex];
          const toggle = el?.querySelector<HTMLButtonElement>('.blk-toggle');
          toggle?.click();
        }
        break;
    }
  }

  // ── Auto-scroll heuristic (mirrors TranscriptView) ────────────────────────

  let scrollEl: HTMLDivElement | undefined = $state();
  let userScrolledUp = $state(false);

  function handleScroll() {
    if (!scrollEl) return;
    const { scrollTop, clientHeight, scrollHeight } = scrollEl;
    userScrolledUp = scrollTop + clientHeight < scrollHeight - 40;
  }

  async function scrollToBottom() {
    await tick();
    if (!scrollEl || userScrolledUp) return;
    scrollEl.scrollTop = scrollEl.scrollHeight;
  }

  $effect(() => {
    void blocks.length;
    void scrollToBottom();
  });
</script>

<div
  class="blkst-root"
  class:blkst-root--streaming={isStreaming}
  bind:this={scrollEl}
  onscroll={handleScroll}
  onkeydown={handleKeydown}
  role="list"
  tabindex="0"
  aria-label="Session block stream"
>
  {#if $query.isLoading}
    <p class="blkst-status">Loading blocks…</p>
  {:else if $query.isError}
    <p class="blkst-status blkst-status--err">
      Failed to load blocks: {$query.error?.message ?? 'unknown error'}
    </p>
  {:else if blocks.length === 0}
    <p class="blkst-status">No blocks yet.</p>
  {:else}
    {#each blocks as block, i (block.id)}
      <div
        role="listitem"
        bind:this={blockEls[i]}
        class:blkst-block--focused={focusedBlockIndex === i}
      >
        <Block
          {block}
          isFocused={focusedBlockIndex === i}
          onCopy={handleCopy}
          onRerun={handleRerun}
          onShare={handleShare}
          onPin={handlePin}
          onDelete={handleDelete}
        />
      </div>
    {/each}
  {/if}
</div>

<style>
  .blkst-root {
    flex: 1;
    overflow-y: auto;
    overscroll-behavior: contain;
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-3);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
    outline: none;
  }

  .blkst-block--focused {
    /* Focus ring is rendered on the inner .blk-focused — wrapper is layout-only */
  }

  .blkst-root--streaming {
    /* Subtle affordance when the session is live. Style hook only — no
       layout change here. */
  }

  .blkst-status {
    margin: 0;
    padding: var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    font-style: italic;
    text-align: center;
  }

  .blkst-status--err {
    color: var(--signal-error, oklch(0.55 0.22 25));
    font-style: normal;
  }
</style>
