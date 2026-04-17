<script lang="ts">
/**
 * PushPanel — 340px right-side sibling panel (Core-OSS "inset" pattern).
 * Not an overlay — pushes main content. Animated slide-in.
 * LOC target: ≤ 100.
 */

import { X } from 'lucide-svelte';
import type { Snippet } from 'svelte';

interface Props {
  open: boolean;
  title?: string;
  onClose: () => void;
  children: Snippet;
  class?: string;
}

let { open, title, onClose, children, class: className = '' }: Props = $props();
</script>

<aside
  class="cnp-push-panel glass-panel {className}"
  class:cnp-push-panel--open={open}
  aria-label={title ?? 'Side panel'}
  aria-hidden={!open}
  inert={!open}
>
  <div class="cnp-push-panel__header">
    {#if title}
      <span class="cnp-push-panel__title">{title}</span>
    {/if}
    <button
      class="btn-compact btn-compact-ghost btn-compact-icon cnp-push-panel__close"
      onclick={onClose}
      aria-label="Close panel"
      tabindex={open ? 0 : -1}
    >
      <X size={14} aria-hidden="true" />
    </button>
  </div>

  <div class="cnp-push-panel__body">
    {@render children()}
  </div>
</aside>

<style>
  .cnp-push-panel {
    width: 340px;
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    border-radius: var(--radius-lg);
    transform: translateX(100%);
    opacity: 0;
    pointer-events: none;
    transition:
      transform var(--dur-normal) var(--ease-out),
      opacity var(--dur-fast) var(--ease-out),
      width var(--dur-normal) var(--ease-io);
    /* Panel lives INSIDE the main-container alongside main — not overlay */
    position: relative;
    height: 100%;
  }

  .cnp-push-panel--open {
    transform: translateX(0);
    opacity: 1;
    pointer-events: auto;
  }

  .cnp-push-panel__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-3) var(--space-4);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    min-height: 44px;
  }

  .cnp-push-panel__title {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: -0.01em;
  }

  .cnp-push-panel__close {
    margin-left: auto;
  }

  .cnp-push-panel__body {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-4);
  }
</style>
