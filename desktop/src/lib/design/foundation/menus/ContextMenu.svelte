<script lang="ts" module>
  import type { Component } from "svelte";
  import type { IconProps } from "lucide-svelte";
  /**
   * ContextMenu — position-anchored menu primitive.
   * CSS prefix: cnp-ctx-
   *
   * Why this exists separately from foundation/menu (Menu/MenuItem):
   *   - `Menu` is a *trigger-anchored* dropdown (built on bits-ui DropdownMenu).
   *     It anchors to a clickable element and follows it on scroll/resize.
   *   - `ContextMenu` is a *cursor-anchored* popup. The right-click event gives
   *     us absolute (clientX, clientY); the menu mounts at that exact point.
   *
   * Reuse: TabsSection inlines a fixed-position menu today — same pattern,
   * un-extracted. Future refactor: lift TabsSection's menu onto this
   * primitive. (Out of scope for this dispatch — separate PR.)
   *
   * Behavior:
   *   - Mounts at { x, y }, clamped to the viewport.
   *   - Click outside / Esc → onclose.
   *   - Arrow keys move focus, Enter/Space activate.
   *   - First item auto-focused on mount.
   *   - role="menu" on the container, role="menuitem" per row.
   */

  /** Single row in the menu. `disabled` rows are skipped by keyboard nav. */
  export interface ContextMenuItem {
    /** Unique key for this row. */
    id: string;
    /** Visible label. */
    label: string;
    /** Invoked on click / Enter / Space. The menu auto-closes after run. */
    onSelect: () => void;
    /** Optional left-side icon (lucide or any svelte component). */
    icon?: Component<IconProps>;
    /** Visually distinguished + announced as destructive. */
    destructive?: boolean;
    /** Greyed out, not focusable. */
    disabled?: boolean;
  }

  /** Cursor anchor in viewport coordinates (e.g. event.clientX/Y). */
  export interface ContextMenuAnchor {
    x: number;
    y: number;
  }
</script>

<script lang="ts">
  import { onMount, tick } from "svelte";

  interface Props {
    /** Menu rows. Pass an empty array to render nothing. */
    items: ContextMenuItem[];
    /** Cursor anchor; menu un-mounts when this is null. */
    anchor: ContextMenuAnchor | null;
    /** Closed by outside-click, Esc, item activation, or scroll. */
    onclose: () => void;
    /** Optional accessible name (defaults to "Context menu"). */
    ariaLabel?: string;
  }

  let { items, anchor, onclose, ariaLabel = "Context menu" }: Props = $props();

  // ── Refs / focus state ─────────────────────────────────────────────────────
  let menuEl = $state<HTMLDivElement | null>(null);
  let focusedIndex = $state(0);

  /** Indexes of items that can receive focus (skip disabled rows). */
  const focusableIndexes = $derived(
    items
      .map((item, idx) => ({ item, idx }))
      .filter(({ item }) => !item.disabled)
      .map(({ idx }) => idx),
  );

  // Reset focus to first focusable item whenever the anchor changes.
  $effect(() => {
    if (anchor) {
      focusedIndex = focusableIndexes[0] ?? 0;
      void tick().then(() => {
        const el = menuEl?.querySelector<HTMLButtonElement>(
          `[data-ctx-idx="${focusedIndex}"]`,
        );
        el?.focus();
      });
    }
  });

  // ── Position clamping ──────────────────────────────────────────────────────
  /** Returns a viewport-clamped (x, y) so the menu never overflows. */
  function clampPosition(
    a: ContextMenuAnchor,
    el: HTMLDivElement | null,
  ): { x: number; y: number } {
    if (!el || typeof window === "undefined") return a;
    const rect = el.getBoundingClientRect();
    const padding = 4;
    const maxX = window.innerWidth - rect.width - padding;
    const maxY = window.innerHeight - rect.height - padding;
    return {
      x: Math.max(padding, Math.min(a.x, maxX)),
      y: Math.max(padding, Math.min(a.y, maxY)),
    };
  }

  let position = $state<{ x: number; y: number }>({ x: 0, y: 0 });
  $effect(() => {
    if (!anchor) return;
    // Two-pass: place at anchor, measure, clamp.
    position = anchor;
    void tick().then(() => {
      if (anchor) position = clampPosition(anchor, menuEl);
    });
  });

  // ── Handlers ───────────────────────────────────────────────────────────────
  function handleSelect(item: ContextMenuItem): void {
    if (item.disabled) return;
    item.onSelect();
    onclose();
  }

  function handleKeyDown(ev: KeyboardEvent): void {
    if (focusableIndexes.length === 0) return;

    if (ev.key === "Escape") {
      ev.preventDefault();
      onclose();
      return;
    }

    if (ev.key === "Tab") {
      // Trap focus inside the menu.
      ev.preventDefault();
    }

    if (ev.key === "ArrowDown" || ev.key === "ArrowUp") {
      ev.preventDefault();
      const cursor = focusableIndexes.indexOf(focusedIndex);
      const dir = ev.key === "ArrowDown" ? 1 : -1;
      const len = focusableIndexes.length;
      const nextCursor = (cursor + dir + len) % len;
      focusedIndex = focusableIndexes[nextCursor];
      const el = menuEl?.querySelector<HTMLButtonElement>(
        `[data-ctx-idx="${focusedIndex}"]`,
      );
      el?.focus();
    }
  }

  function handleOutsidePointerDown(ev: PointerEvent): void {
    if (!menuEl) return;
    if (!menuEl.contains(ev.target as Node)) {
      onclose();
    }
  }

  function handleScroll(): void {
    if (anchor) onclose();
  }

  onMount(() => {
    // Listening on `pointerdown` (not `click`) avoids racing with the same
    // click that opened the menu — the contextmenu event already finished by
    // the time onMount runs.
    window.addEventListener("pointerdown", handleOutsidePointerDown, true);
    window.addEventListener("scroll", handleScroll, true);
    return () => {
      window.removeEventListener("pointerdown", handleOutsidePointerDown, true);
      window.removeEventListener("scroll", handleScroll, true);
    };
  });
</script>

{#if anchor && items.length > 0}
  <div
    bind:this={menuEl}
    class="cnp-ctx"
    role="menu"
    aria-label={ariaLabel}
    style="left: {position.x}px; top: {position.y}px;"
    onkeydown={handleKeyDown}
    tabindex="-1"
  >
    {#each items as item, idx (item.id)}
      <button
        type="button"
        class="cnp-ctx__item"
        class:cnp-ctx__item--destructive={item.destructive}
        role="menuitem"
        data-ctx-idx={idx}
        disabled={item.disabled}
        onclick={() => handleSelect(item)}
      >
        {#if item.icon}
          <span class="cnp-ctx__icon" aria-hidden="true">
            <!-- svelte-ignore svelte_component_deprecated -->
            <svelte:component this={item.icon} size={14} />
          </span>
        {/if}
        <span class="cnp-ctx__label">{item.label}</span>
      </button>
    {/each}
  </div>
{/if}

<style>
  .cnp-ctx {
    position: fixed;
    z-index: 1100;
    min-width: 180px;
    padding: 4px;
    background: var(--bg-overlay, #fbfbfc);
    border: 1px solid var(--border, rgba(0, 0, 0, 0.08));
    border-radius: var(--radius-md, 8px);
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
    outline: none;
  }

  .cnp-ctx__item {
    display: flex;
    align-items: center;
    gap: var(--space-2, 8px);
    width: 100%;
    padding: 6px 10px;
    border: none;
    background: transparent;
    text-align: left;
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--fg);
    border-radius: var(--radius-sm, 4px);
    cursor: pointer;
  }

  .cnp-ctx__item:hover:not(:disabled),
  .cnp-ctx__item:focus-visible {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    outline: none;
  }

  .cnp-ctx__item:disabled {
    color: var(--fg-subtle);
    cursor: not-allowed;
  }

  .cnp-ctx__item--destructive {
    color: var(--signal-error, #eb4335);
  }

  .cnp-ctx__item--destructive:hover:not(:disabled),
  .cnp-ctx__item--destructive:focus-visible {
    background: color-mix(in oklch, var(--signal-error, #eb4335) 10%, transparent 90%);
  }

  .cnp-ctx__icon {
    display: inline-flex;
    flex-shrink: 0;
    color: var(--fg-muted);
  }

  .cnp-ctx__label {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  :global(.dark) .cnp-ctx {
    background: #252525;
    border-color: rgba(255, 255, 255, 0.08);
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.5);
  }
</style>
