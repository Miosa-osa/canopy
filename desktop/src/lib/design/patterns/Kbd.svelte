<script lang="ts">
/**
 * Kbd — styled <kbd> for displaying keyboard shortcuts.
 * Usage: <Kbd>⌘K</Kbd> or <Kbd keys={['⌘', 'K']} />
 * LOC target: ≤ 30.
 */
import type { Snippet } from 'svelte';

interface Props {
  /** Inline chord string e.g. "⌘↵" — used if no children provided. */
  chord?: string;
  children?: Snippet;
  class?: string;
}

let { chord, children, class: className = '' }: Props = $props();
</script>

<kbd class="cnp-kbd {className}" aria-label={chord}>
  {#if children}
    {@render children()}
  {:else}
    {chord}
  {/if}
</kbd>

<style>
  .cnp-kbd {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 2px;
    padding: 1px 5px;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    line-height: 1.5;
    color: var(--fg-subtle);
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-bottom-width: 2px;
    border-radius: var(--radius-sm);
    white-space: nowrap;
    user-select: none;
  }
</style>
