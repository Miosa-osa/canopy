<script lang="ts">
  import { onDestroy } from "svelte";
  import TileChrome from "./TileChrome.svelte";
  import TerminalWorkbenchTile from "./TerminalWorkbenchTile.svelte";
  import TmuxIdeWorkbenchTile from "./TmuxIdeWorkbenchTile.svelte";
  import ChatWorkbenchTile from "./ChatWorkbenchTile.svelte";
  import SessionsWorkbenchTile from "./SessionsWorkbenchTile.svelte";
  import FilesWorkbenchTile from "./FilesWorkbenchTile.svelte";
  import { workbenchStore } from "$lib/stores/workbench.svelte";
  import type { WorkbenchTile } from "$lib/types/workbench";

  type DragState = {
    tileId: string;
    pointerId: number;
    startX: number;
    startY: number;
    tileX: number;
    tileY: number;
  };

  type PanState = {
    pointerId: number;
    startX: number;
    startY: number;
    viewportX: number;
    viewportY: number;
  };

  let drag = $state<DragState | null>(null);
  let pan = $state<PanState | null>(null);

  function startDrag(tile: WorkbenchTile, event: PointerEvent): void {
    if (event.button !== 0) return;
    const target = event.target as HTMLElement;
    if (target.closest("button")) return;

    drag = {
      tileId: tile.id,
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      tileX: tile.x,
      tileY: tile.y,
    };
    workbenchStore.focusTile(tile.id);
    (event.currentTarget as HTMLElement).setPointerCapture(event.pointerId);
  }

  function handlePointerMove(event: PointerEvent): void {
    if (!drag || event.pointerId !== drag.pointerId) return;
    const scale = workbenchStore.layout.viewport.scale;
    const nextX = drag.tileX + (event.clientX - drag.startX) / scale;
    const nextY = drag.tileY + (event.clientY - drag.startY) / scale;
    workbenchStore.moveTile(drag.tileId, nextX, nextY);
  }

  function startPan(event: PointerEvent): void {
    if (event.button !== 0 || workbenchStore.layout.mode !== "canvas") return;
    if ((event.target as HTMLElement).closest(".wtile")) return;
    pan = {
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      viewportX: workbenchStore.layout.viewport.x,
      viewportY: workbenchStore.layout.viewport.y,
    };
    (event.currentTarget as HTMLElement).setPointerCapture(event.pointerId);
  }

  function handlePanMove(event: PointerEvent): void {
    if (!pan || event.pointerId !== pan.pointerId) return;
    workbenchStore.setViewport({
      ...workbenchStore.layout.viewport,
      x: pan.viewportX + event.clientX - pan.startX,
      y: pan.viewportY + event.clientY - pan.startY,
    });
  }

  function stopDrag(event?: PointerEvent): void {
    if (!drag) return;
    if (event && event.pointerId !== drag.pointerId) return;
    drag = null;
    workbenchStore.commitPosition();
  }

  function stopPan(event?: PointerEvent): void {
    if (!pan) return;
    if (event && event.pointerId !== pan.pointerId) return;
    pan = null;
    workbenchStore.commitViewport();
  }

  function handleWheel(event: WheelEvent): void {
    if (workbenchStore.layout.mode !== "canvas") return;
    if (!event.metaKey && !event.ctrlKey) return;
    event.preventDefault();
    const viewport = workbenchStore.layout.viewport;
    const nextScale = Math.min(1.5, Math.max(0.45, viewport.scale - event.deltaY * 0.001));
    const rect = (event.currentTarget as HTMLElement).getBoundingClientRect();
    const cursorX = event.clientX - rect.left;
    const cursorY = event.clientY - rect.top;
    const worldX = (cursorX - viewport.x) / viewport.scale;
    const worldY = (cursorY - viewport.y) / viewport.scale;
    workbenchStore.setViewport({
      x: Math.round(cursorX - worldX * nextScale),
      y: Math.round(cursorY - worldY * nextScale),
      scale: Number(nextScale.toFixed(2)),
    });
    workbenchStore.commitViewport();
  }

  function handleWindowPointerMove(event: PointerEvent): void {
    handlePointerMove(event);
    handlePanMove(event);
  }

  function handleWindowPointerUp(event: PointerEvent): void {
    stopDrag(event);
    stopPan(event);
  }

  function handleWindowPointerCancel(event: PointerEvent): void {
    stopDrag(event);
    stopPan(event);
  }

  onDestroy(() => {
    stopDrag();
    stopPan();
  });
</script>

<svelte:window
  onpointermove={handleWindowPointerMove}
  onpointerup={handleWindowPointerUp}
  onpointercancel={handleWindowPointerCancel}
/>

<div class="wb-shell" class:wb-shell--split={workbenchStore.layout.mode === "split"}>
  <div
    class="wb-surface"
    class:wb-surface--panning={!!pan}
    aria-label="Workbench canvas"
    onpointerdown={startPan}
    onwheel={handleWheel}
  >
    <div
      class="wb-world"
      style:transform={`translate(${workbenchStore.layout.viewport.x}px, ${workbenchStore.layout.viewport.y}px) scale(${workbenchStore.layout.viewport.scale})`}
    >
    {#each workbenchStore.tiles as tile (tile.id)}
      <TileChrome
        {tile}
        active={workbenchStore.layout.activeTileId === tile.id}
        dragging={drag?.tileId === tile.id}
        onDragStart={startDrag}
        onToggleMinimized={(tileId) => workbenchStore.toggleMinimized(tileId)}
      >
        {#if tile.type === "terminal"}
          <TerminalWorkbenchTile />
        {:else if tile.type === "tmux"}
          <TmuxIdeWorkbenchTile />
        {:else if tile.type === "chat"}
          <ChatWorkbenchTile />
        {:else if tile.type === "sessions"}
          <SessionsWorkbenchTile />
        {:else if tile.type === "files"}
          <FilesWorkbenchTile />
        {/if}
      </TileChrome>
    {/each}
    </div>
  </div>
  {#if workbenchStore.layout.mode === "canvas"}
    <div class="wb-viewport-hud" aria-label="Canvas viewport">
      <span>{Math.round(workbenchStore.layout.viewport.scale * 100)}%</span>
      <button type="button" onclick={() => workbenchStore.resetViewport()}>Center</button>
    </div>
  {/if}
</div>

<style>
  .wb-shell {
    position: relative;
    height: 100%;
    min-height: 0;
    overflow: hidden;
    background:
      linear-gradient(var(--border-default) 1px, transparent 1px),
      linear-gradient(90deg, var(--border-default) 1px, transparent 1px),
      var(--bg-secondary);
    background-size: 48px 48px;
    background-position: -1px -1px;
  }

  .wb-shell--split {
    background: var(--bg-secondary);
  }

  .wb-surface {
    position: relative;
    width: 100%;
    height: 100%;
    cursor: grab;
    touch-action: none;
  }

  .wb-surface--panning {
    cursor: grabbing;
  }

  .wb-world {
    position: absolute;
    inset: 0 auto auto 0;
    width: 5200px;
    height: 3200px;
    transform-origin: 0 0;
  }

  .wb-shell--split .wb-surface {
    display: grid;
    width: 100%;
    height: 100%;
    grid-template-columns: minmax(420px, 1.35fr) minmax(360px, 1fr);
    grid-auto-rows: minmax(260px, 1fr);
    gap: 10px;
    padding: 10px;
  }

  .wb-shell--split .wb-world {
    display: contents;
    transform: none !important;
  }

  :global(.wb-shell--split .wtile) {
    position: relative;
    top: auto !important;
    left: auto !important;
    width: auto !important;
    height: auto !important;
    min-height: 260px;
  }

  .wb-viewport-hud {
    position: absolute;
    right: 12px;
    bottom: 12px;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 8px;
    border: 1px solid var(--border-default);
    border-radius: 7px;
    background: color-mix(in srgb, var(--bg-primary) 86%, transparent);
    color: var(--text-tertiary);
    font-size: 11px;
    box-shadow: 0 10px 28px rgba(0, 0, 0, 0.22);
  }

  .wb-viewport-hud button {
    height: 22px;
    border: 1px solid var(--border-default);
    border-radius: 5px;
    background: var(--bg-elevated);
    color: var(--text-secondary);
    cursor: pointer;
    font: inherit;
  }

  .wb-viewport-hud button:hover {
    color: var(--text-primary);
    border-color: var(--border-hover);
  }
</style>
