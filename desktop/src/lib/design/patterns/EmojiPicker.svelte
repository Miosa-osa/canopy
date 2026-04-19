<script lang="ts">
/**
 * EmojiPicker — wraps `emoji-picker-element` web component.
 *
 * Props:
 *   onSelect(emoji: string)  — called with the unicode emoji on selection
 *   onClose()                — called on outside-click or Escape
 *
 * Positioning: fixed, anchored via CSS variables --ep-top / --ep-left
 * set on the host element by the caller (see channel +page.svelte).
 *
 * Dark mode: adds class="dark" when document root has data-theme="dark".
 * The web component respects this out of the box.
 */
import { onMount } from 'svelte';

interface Props {
  onSelect: (emoji: string) => void;
  onClose: () => void;
  /** Pixel distance from viewport top — applied as CSS var --ep-top */
  top?: number;
  /** Pixel distance from viewport left — applied as CSS var --ep-left */
  left?: number;
}

let { onSelect, onClose, top = 0, left = 0 }: Props = $props();

let containerEl = $state<HTMLDivElement | null>(null);
let pickerEl = $state<HTMLElement | null>(null);

onMount(() => {
  // Dynamic import — ~80KB picker chunk only loads when picker is opened
  void import('emoji-picker-element').then(() => {
    if (!containerEl) return;

    const picker = document.createElement('emoji-picker');

    // Dark mode alignment
    if (document.documentElement.getAttribute('data-theme') === 'dark') {
      picker.classList.add('dark');
    }

    picker.addEventListener('emoji-click', (evt: Event) => {
      const detail = (evt as CustomEvent<{ unicode: string }>).detail;
      if (detail?.unicode) {
        onSelect(detail.unicode);
        onClose();
      }
    });

    containerEl.appendChild(picker);
    pickerEl = picker;
  });

  // Outside-click to close
  function handlePointerDown(evt: PointerEvent): void {
    if (containerEl && !containerEl.contains(evt.target as Node)) {
      onClose();
    }
  }

  // Escape to close
  function handleKeyDown(evt: KeyboardEvent): void {
    if (evt.key === 'Escape') {
      evt.stopPropagation();
      onClose();
    }
  }

  document.addEventListener('pointerdown', handlePointerDown, { capture: true });
  document.addEventListener('keydown', handleKeyDown, { capture: true });

  return () => {
    document.removeEventListener('pointerdown', handlePointerDown, { capture: true });
    document.removeEventListener('keydown', handleKeyDown, { capture: true });
  };
});
</script>

<div
  class="ep-host"
  bind:this={containerEl}
  role="dialog"
  aria-label="Emoji picker"
  aria-modal="true"
  style="--ep-top: {top}px; --ep-left: {left}px;"
></div>

<style>
  .ep-host {
    position: fixed;
    top: var(--ep-top, 0px);
    left: var(--ep-left, 0px);
    z-index: 200;
  }

  /* Alias Canopy design tokens to emoji-picker-element CSS custom properties */
  .ep-host :global(emoji-picker) {
    --background:           var(--bg-inset);
    --border-color:         var(--border);
    --border-size:          1px;
    --border-radius:        var(--radius-md);
    --input-border-radius:  var(--radius-sm);
    --indicator-color:      var(--cnp-accent);
    --outline-color:        var(--cnp-accent);
    --text-color:           var(--fg);
    --input-font-color:     var(--fg);
    --placeholder-color:    var(--fg-subtle);
    --category-font-color:  var(--fg-muted);
    --num-columns:          8;
    width:  320px;
    height: 360px;
    font-family: var(--font-sans);
  }
</style>
