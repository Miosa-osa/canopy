<script lang="ts">
/**
 * WidgetShell — drag handle + size toggle + header bar wrapper for dashboard widgets.
 * CSS prefix: ws- (WidgetShell)
 * Size: compact | normal | wide
 */
import { GripVertical, Maximize2, Minimize2, Square } from 'lucide-svelte';
import type { Snippet } from 'svelte';

type WidgetSize = 'compact' | 'normal' | 'wide';

interface Props {
  id: string;
  label: string;
  size: WidgetSize;
  onSizeChange?: (id: string, size: WidgetSize) => void;
  children: Snippet;
}

let { id, label, size, onSizeChange, children }: Props = $props();

const SIZE_CYCLE: WidgetSize[] = ['compact', 'normal', 'wide'];

function cycleSize() {
  const idx = SIZE_CYCLE.indexOf(size);
  const next = SIZE_CYCLE[(idx + 1) % SIZE_CYCLE.length];
  onSizeChange?.(id, next);
}
</script>

<div class="ws-shell ws-shell--{size}" aria-label={label}>
  <!-- Drag handle + header -->
  <div class="ws-header">
    <span class="ws-handle" aria-hidden="true" title="Drag to reorder">
      <GripVertical size={12} />
    </span>
    <span class="ws-label">{label}</span>
    <button
      class="ws-size-btn"
      onclick={cycleSize}
      aria-label="Cycle size: {size}"
      title="Size: {size}"
    >
      {#if size === 'compact'}
        <Minimize2 size={10} />
      {:else if size === 'normal'}
        <Square size={10} />
      {:else}
        <Maximize2 size={10} />
      {/if}
    </button>
  </div>

  <!-- Widget content -->
  <div class="ws-body">
    {@render children()}
  </div>
</div>

<style>
  .ws-shell {
    display: flex;
    flex-direction: column;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow: hidden;
    transition: box-shadow var(--dur-fast, 160ms) ease;
    height: 100%;
  }

  .ws-shell:hover {
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  }

  /* ── Header ── */
  .ws-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    cursor: grab;
    background: color-mix(in oklch, var(--fg) 3%, transparent);
    user-select: none;
  }

  .ws-header:active {
    cursor: grabbing;
  }

  .ws-handle {
    color: var(--fg-subtle);
    display: flex;
    align-items: center;
    flex-shrink: 0;
  }

  .ws-label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    flex: 1;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ws-size-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 3px;
    border: none;
    background: transparent;
    cursor: pointer;
    color: var(--fg-subtle);
    border-radius: var(--radius-sm);
    flex-shrink: 0;
    transition: color var(--dur-instant) ease, background var(--dur-instant) ease;
  }

  .ws-size-btn:hover {
    color: var(--fg-muted);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
  }

  .ws-size-btn:focus-visible {
    outline: 2px solid var(--fg-muted);
    outline-offset: 1px;
  }

  /* ── Body ── */
  .ws-body {
    flex: 1;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  /* ── Size variants (height only — column span handled by grid) ── */
  .ws-shell--compact .ws-body {
    max-height: 120px;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .ws-shell--normal .ws-body {
    max-height: 280px;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .ws-shell--wide .ws-body {
    max-height: 480px;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }
</style>
