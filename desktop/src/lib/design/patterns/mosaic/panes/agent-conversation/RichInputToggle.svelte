<script lang="ts" module>
  /**
   * Pure helper: did this keyboard event request a Rich Input toggle?
   * Exported for tests so we don't need a runes-aware test runner.
   */
  export function isRichInputToggleEvent(e: KeyboardEvent): boolean {
    // ⌃G (control+g) on every platform — never `metaKey`. Letting metaKey
    // through would steal ⌘G ("Find Next") from the OS.
    return e.ctrlKey && !e.metaKey && !e.altKey && (e.key === 'g' || e.key === 'G');
  }
</script>

<script lang="ts">
  /**
   * RichInputToggle — pill-shaped chip that flips between
   * "Rich Input" and "Hide Rich Input". Bound to ⌃G.
   *
   * Stateless presentation — parent owns the boolean and persists it
   * onto pane.config.embeddedRuntime.richInputOn so it survives reloads.
   *
   * The keyboard listener is mounted at window scope so the shortcut
   * also works while the embedded terminal has focus.
   *
   * CSS prefix: rit-
   */
  import { Sparkles } from 'lucide-svelte';
  import { onMount } from 'svelte';

  interface Props {
    /** True = composer visible. False = raw passthrough to runtime. */
    on: boolean;
    /** Fires whenever the user toggles (button click OR ⌃G). */
    onToggle?: () => void;
    /** When false, the keyboard shortcut is ignored — the chip still
     *  renders but clicks do nothing. Used while the embedded runtime
     *  is missing (no transport to hand keys to). */
    enabled?: boolean;
  }

  let { on, onToggle, enabled = true }: Props = $props();

  function handleClick(): void {
    if (!enabled) return;
    onToggle?.();
  }

  // Global ⌃G handler — capture-phase so it beats the embedded
  // terminal's keystroke pipeline.
  onMount(() => {
    const handler = (e: KeyboardEvent): void => {
      if (!enabled) return;
      if (!isRichInputToggleEvent(e)) return;
      // Don't fire while the user is in a code-editor dialog/modal etc.
      // (Modals call stopPropagation; if we got here we're in the pane.)
      e.preventDefault();
      e.stopPropagation();
      onToggle?.();
    };
    window.addEventListener('keydown', handler, { capture: true });
    return () => window.removeEventListener('keydown', handler, { capture: true });
  });
</script>

<button
  type="button"
  class="rit-chip"
  class:rit-chip--on={on}
  onclick={handleClick}
  aria-pressed={on}
  aria-label={on ? 'Hide Rich Input — keystrokes go to the runtime' : 'Show Rich Input — composer above runtime'}
  title={on ? 'Hide Rich Input  ⌃G' : 'Rich Input  ⌃G'}
>
  <Sparkles size={11} aria-hidden="true" />
  <span class="rit-label">{on ? 'Hide Rich Input' : 'Rich Input'}</span>
  <kbd class="rit-kbd" aria-hidden="true">⌃G</kbd>
</button>

<style>
  .rit-chip {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 3px 8px;
    height: 22px;
    border: 1px solid var(--border, rgba(255, 255, 255, 0.10));
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    border-radius: 999px;
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: 11px;
    cursor: pointer;
    transition: background 80ms ease-out, color 80ms ease-out, border-color 80ms ease-out;
  }

  .rit-chip:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg);
    border-color: color-mix(in oklch, var(--fg) 18%, transparent);
  }

  .rit-chip--on {
    color: var(--cnp-accent, oklch(0.72 0.18 145));
    border-color: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 40%, transparent);
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 12%, transparent);
  }

  .rit-label {
    white-space: nowrap;
  }

  .rit-kbd {
    font-family: var(--font-mono);
    font-size: 9.5px;
    padding: 1px 4px;
    border-radius: 3px;
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    color: var(--fg-subtle);
    line-height: 1;
  }
</style>
