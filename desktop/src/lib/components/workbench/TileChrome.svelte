<script lang="ts">
  import { GripHorizontal, Minus } from "lucide-svelte";
  import type { Snippet } from "svelte";
  import type { WorkbenchTile } from "$lib/types/workbench";

  interface Props {
    tile: WorkbenchTile;
    active?: boolean;
    dragging?: boolean;
    children?: Snippet;
    onDragStart?: (tile: WorkbenchTile, event: PointerEvent) => void;
    onToggleMinimized?: (tileId: string) => void;
  }

  let {
    tile,
    active = false,
    dragging = false,
    children,
    onDragStart,
    onToggleMinimized,
  }: Props = $props();
</script>

<section
  class="wtile"
  class:wtile--active={active}
  class:wtile--dragging={dragging}
  class:wtile--minimized={tile.minimized}
  style:left={`${tile.x}px`}
  style:top={`${tile.y}px`}
  style:width={`${tile.width}px`}
  style:height={tile.minimized ? "42px" : `${tile.height}px`}
  style:z-index={String(tile.zIndex)}
  aria-label={tile.title}
>
  <header
    class="wtile-header"
    role="group"
    aria-label={`${tile.title} tile controls`}
    onpointerdown={(event) => onDragStart?.(tile, event)}
  >
    <GripHorizontal size={14} aria-hidden="true" />
    <h2 class="wtile-title">{tile.title}</h2>
    <button
      class="wtile-icon-btn"
      type="button"
      aria-label={tile.minimized ? `Restore ${tile.title}` : `Minimize ${tile.title}`}
      title={tile.minimized ? "Restore" : "Minimize"}
      onclick={(event) => {
        event.stopPropagation();
        onToggleMinimized?.(tile.id);
      }}
    >
      <Minus size={14} aria-hidden="true" />
    </button>
  </header>

  {#if !tile.minimized}
    <div class="wtile-body">
      {#if children}{@render children()}{/if}
    </div>
  {/if}
</section>

<style>
  .wtile {
    position: absolute;
    display: flex;
    flex-direction: column;
    min-width: 280px;
    min-height: 42px;
    background: var(--bg-primary);
    border: 1px solid var(--border-default);
    border-radius: 8px;
    overflow: hidden;
    box-shadow: 0 12px 32px rgba(0, 0, 0, 0.22);
    transition:
      border-color 120ms ease,
      box-shadow 120ms ease,
      height 120ms ease;
  }

  .wtile--active {
    border-color: color-mix(in srgb, var(--accent-primary) 58%, var(--border-hover));
    box-shadow:
      0 16px 42px rgba(0, 0, 0, 0.32),
      0 0 0 1px color-mix(in srgb, var(--accent-primary) 18%, transparent);
  }

  .wtile--dragging {
    user-select: none;
    transition: none;
  }

  .wtile-header {
    display: flex;
    align-items: center;
    gap: 8px;
    height: 42px;
    padding: 0 10px;
    border-bottom: 1px solid var(--border-default);
    background: var(--bg-elevated);
    color: var(--text-secondary);
    cursor: grab;
    flex-shrink: 0;
    touch-action: none;
  }

  .wtile--dragging .wtile-header {
    cursor: grabbing;
  }

  .wtile--minimized .wtile-header {
    border-bottom: 0;
  }

  .wtile-title {
    min-width: 0;
    flex: 1;
    margin: 0;
    overflow: hidden;
    color: var(--text-primary);
    font-size: 12px;
    font-weight: 600;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .wtile-icon-btn {
    display: inline-flex;
    width: 26px;
    height: 26px;
    align-items: center;
    justify-content: center;
    border: 1px solid transparent;
    border-radius: 6px;
    background: transparent;
    color: var(--text-tertiary);
    cursor: pointer;
  }

  .wtile-icon-btn:hover {
    border-color: var(--border-default);
    background: var(--bg-surface);
    color: var(--text-primary);
  }

  .wtile-body {
    flex: 1;
    min-height: 0;
    overflow: hidden;
  }
</style>
