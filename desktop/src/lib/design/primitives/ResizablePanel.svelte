<script lang="ts">
/**
 * ResizablePanel — drag-to-resize two-pane layout primitive.
 * CSS prefix: rp-
 * Orientation: 'horizontal' (left|right) | 'vertical' (top|bottom).
 * Uses pointer events — no library deps.
 * LOC target: ≤ 180.
 */

import type { Snippet } from 'svelte';

interface Props {
  orientation?: 'horizontal' | 'vertical';
  defaultSize?: number;
  minSize?: number;
  maxSize?: number;
  persistKey?: string;
  left?: Snippet;
  right?: Snippet;
  top?: Snippet;
  bottom?: Snippet;
}

let {
  orientation = 'horizontal',
  defaultSize = 280,
  minSize = 200,
  maxSize = 600,
  persistKey,
  left,
  right,
  top,
  bottom,
}: Props = $props();

// ── Size state ──────────────────────────────────────────────────────────────

function readPersisted(): number {
  if (!persistKey || typeof localStorage === 'undefined') return defaultSize;
  const stored = localStorage.getItem(persistKey);
  const n = stored !== null ? Number(stored) : NaN;
  return isNaN(n) ? defaultSize : Math.min(maxSize, Math.max(minSize, n));
}

let size = $state(readPersisted());

function persistSize(n: number): void {
  if (persistKey && typeof localStorage !== 'undefined') {
    localStorage.setItem(persistKey, String(n));
  }
}

// ── Drag logic ──────────────────────────────────────────────────────────────

let dragging = $state(false);
let dividerEl = $state<HTMLButtonElement | undefined>();
let containerEl = $state<HTMLDivElement | undefined>();
let dragStartPos = $state(0);
let dragStartSize = $state(0);

function onPointerDown(e: PointerEvent): void {
  e.preventDefault();
  (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  dragging = true;
  dragStartPos = orientation === 'horizontal' ? e.clientX : e.clientY;
  dragStartSize = size;
}

function onPointerMove(e: PointerEvent): void {
  if (!dragging) return;
  const delta =
    orientation === 'horizontal'
      ? dragStartPos - e.clientX // right panel shrinks when dragging left
      : dragStartPos - e.clientY;
  const next = Math.min(maxSize, Math.max(minSize, dragStartSize + delta));
  size = next;
}

function onPointerUp(): void {
  if (!dragging) return;
  dragging = false;
  persistSize(size);
}

// ── Keyboard accessibility ──────────────────────────────────────────────────

function onKeyDown(e: KeyboardEvent): void {
  const step = 20;
  if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
    e.preventDefault();
    size = Math.min(maxSize, size + step);
    persistSize(size);
  } else if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
    e.preventDefault();
    size = Math.max(minSize, size - step);
    persistSize(size);
  }
}

// ── Derived CSS ─────────────────────────────────────────────────────────────

const isHorizontal = $derived(orientation === 'horizontal');
const containerStyle = $derived(isHorizontal ? 'flex-direction: row;' : 'flex-direction: column;');
const secondStyle = $derived(
  isHorizontal ? `width: ${size}px; flex-shrink: 0;` : `height: ${size}px; flex-shrink: 0;`
);
</script>

<div
  class="rp-container"
  class:rp-container--h={isHorizontal}
  class:rp-container--v={!isHorizontal}
  class:rp-dragging={dragging}
  style={containerStyle}
  bind:this={containerEl}
>
  <!-- First pane (left / top) -->
  <div class="rp-pane rp-pane--first">
    {#if isHorizontal && left}
      {@render left()}
    {:else if !isHorizontal && top}
      {@render top()}
    {/if}
  </div>

  <!-- Divider — button so it's interactive and keyboard-focusable -->
  <button
    class="rp-divider"
    class:rp-divider--h={isHorizontal}
    class:rp-divider--v={!isHorizontal}
    aria-label="Drag to resize panel. Use arrow keys to resize by 20px."
    bind:this={dividerEl}
    onpointerdown={onPointerDown}
    onpointermove={onPointerMove}
    onpointerup={onPointerUp}
    onkeydown={onKeyDown}
  ></button>

  <!-- Second pane (right / bottom) — sized panel -->
  <div class="rp-pane rp-pane--second" style={secondStyle}>
    {#if isHorizontal && right}
      {@render right()}
    {:else if !isHorizontal && bottom}
      {@render bottom()}
    {/if}
  </div>
</div>

<style>
  .rp-container {
    display: flex;
    width: 100%;
    height: 100%;
    overflow: hidden;
    min-height: 0;
  }

  .rp-dragging { user-select: none; }
  .rp-dragging.rp-container--h { cursor: col-resize; }
  .rp-dragging.rp-container--v { cursor: row-resize; }

  .rp-pane--first {
    flex: 1;
    min-width: 0;
    min-height: 0;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .rp-pane--second {
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  /* Divider */
  .rp-divider {
    flex-shrink: 0;
    background: var(--border);
    position: relative;
    transition: background 0.12s ease;
    outline: none;
    border: none;
    padding: 0;
    margin: 0;
    appearance: none;
  }

  .rp-divider--h {
    width: 4px;
    cursor: col-resize;
  }

  .rp-divider--v {
    height: 4px;
    cursor: row-resize;
  }

  .rp-divider::after {
    content: '';
    position: absolute;
    inset: 0;
    background: var(--cnp-accent, oklch(0.72 0.18 145));
    opacity: 0;
    transition: opacity 0.15s ease;
  }

  .rp-divider:hover::after,
  .rp-divider:focus-visible::after {
    opacity: 0.2;
  }

  .rp-divider:focus-visible {
    outline: 2px solid var(--cnp-accent, oklch(0.72 0.18 145));
    outline-offset: 1px;
  }
</style>
