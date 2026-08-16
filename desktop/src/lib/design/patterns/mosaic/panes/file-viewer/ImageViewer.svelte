<script lang="ts">
  /**
   * ImageViewer — read-only image with zoom + pan.
   * CSS prefix: ivw- (Image Viewer).
   *
   * Uses the existing /files/:id/content URL (or a passed blob URL). No new
   * fetch logic — the parent dispatcher resolves the URL.
   *
   * Wheel = zoom (anchored at cursor). Drag = pan. "Fit" / "1:1" reset.
   */
  import { onMount } from "svelte";

  interface Props {
    /** Direct URL or blob URL for the image. */
    src: string;
    /** Alt text for screen readers. */
    alt: string;
  }

  let { src, alt }: Props = $props();

  let scale = $state(1);
  let originX = $state(0);
  let originY = $state(0);
  let dragging = $state(false);
  let dragStartX = 0;
  let dragStartY = 0;
  let panStartX = 0;
  let panStartY = 0;

  let wrapEl = $state<HTMLDivElement | null>(null);

  function onWheel(e: WheelEvent): void {
    e.preventDefault();
    const factor = e.deltaY < 0 ? 1.1 : 1 / 1.1;
    const next = Math.min(Math.max(scale * factor, 0.1), 10);
    // Anchor zoom at cursor position relative to wrap.
    if (wrapEl) {
      const rect = wrapEl.getBoundingClientRect();
      const cx = e.clientX - rect.left;
      const cy = e.clientY - rect.top;
      const ratio = next / scale;
      originX = cx - (cx - originX) * ratio;
      originY = cy - (cy - originY) * ratio;
    }
    scale = next;
  }

  function onMouseDown(e: MouseEvent): void {
    dragging = true;
    dragStartX = e.clientX;
    dragStartY = e.clientY;
    panStartX = originX;
    panStartY = originY;
  }

  function onMouseMove(e: MouseEvent): void {
    if (!dragging) return;
    originX = panStartX + (e.clientX - dragStartX);
    originY = panStartY + (e.clientY - dragStartY);
  }

  function onMouseUp(): void {
    dragging = false;
  }

  function fit(): void {
    scale = 1;
    originX = 0;
    originY = 0;
  }

  function actualSize(): void {
    scale = 1;
    originX = 0;
    originY = 0;
  }

  onMount(() => {
    window.addEventListener("mousemove", onMouseMove);
    window.addEventListener("mouseup", onMouseUp);
    return () => {
      window.removeEventListener("mousemove", onMouseMove);
      window.removeEventListener("mouseup", onMouseUp);
    };
  });
</script>

<div class="ivw-root">
  <div class="ivw-toolbar" role="toolbar" aria-label="Image controls">
    <button class="ivw-btn" onclick={fit}>Fit</button>
    <button class="ivw-btn" onclick={actualSize}>1:1</button>
    <span class="ivw-zoom">{Math.round(scale * 100)}%</span>
  </div>

  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="ivw-canvas"
    bind:this={wrapEl}
    onwheel={onWheel}
    onmousedown={onMouseDown}
    role="img"
    aria-label={alt}
  >
    <img
      class="ivw-img"
      class:ivw-img-dragging={dragging}
      {src}
      {alt}
      style="transform: translate({originX}px, {originY}px) scale({scale});"
      draggable="false"
    />
  </div>
</div>

<style>
  .ivw-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: var(--bg-inset);
  }

  .ivw-toolbar {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-1) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    background: var(--bg-elevated, var(--bg));
  }

  .ivw-btn {
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    color: var(--fg);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    padding: 2px var(--space-2);
    cursor: pointer;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .ivw-btn:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent);
  }

  .ivw-zoom {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  .ivw-canvas {
    flex: 1;
    overflow: hidden;
    cursor: grab;
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .ivw-canvas:active {
    cursor: grabbing;
  }

  .ivw-img {
    transform-origin: 0 0;
    user-select: none;
    max-width: none;
    max-height: none;
    transition: transform 0.05s linear;
  }

  .ivw-img-dragging {
    transition: none;
  }
</style>
