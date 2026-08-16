<script lang="ts" module>
  /**
   * Build the human-readable label for a given runtime type.
   * Exported so tests / parents can render the same string.
   */
  export function notificationChipLabel(runtimeType: string, on: boolean): string {
    const product =
      runtimeType === 'claude-local'
        ? 'Claude Code'
        : runtimeType === 'codex-local'
        ? 'Codex'
        : runtimeType === 'gemini-local'
        ? 'Gemini'
        : runtimeType;
    return on
      ? `${product} notifications on`
      : `Enable ${product} notifications`;
  }
</script>

<script lang="ts">
  /**
   * RuntimeNotificationChip — per-runtime notification toggle.
   *
   * Backend gap: there is no runtime-level notification setter today.
   * The chip is wired to local pane state and a `onToggle` callback;
   * the parent should persist the value into pane.config and (when
   * the backend ships) call e.g. Canopy.Runtimes.Claude.set_notifications.
   *
   * See wiring/embedded-runtime-wiring.md → "Backend gaps".
   *
   * CSS prefix: rnc-
   */
  import { Bell, BellOff } from 'lucide-svelte';

  interface Props {
    runtimeType: string;
    on: boolean;
    onToggle?: () => void;
  }

  let { runtimeType, on, onToggle }: Props = $props();

  const label = $derived(notificationChipLabel(runtimeType, on));
</script>

<button
  type="button"
  class="rnc-chip"
  class:rnc-chip--on={on}
  onclick={onToggle}
  aria-pressed={on}
  aria-label={label}
  title={label}
>
  {#if on}
    <Bell size={11} aria-hidden="true" />
  {:else}
    <BellOff size={11} aria-hidden="true" />
  {/if}
  <span class="rnc-label">{label}</span>
</button>

<style>
  .rnc-chip {
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
  .rnc-chip:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg);
    border-color: color-mix(in oklch, var(--fg) 18%, transparent);
  }
  .rnc-chip--on {
    color: var(--cnp-accent, oklch(0.72 0.18 145));
    border-color: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 40%, transparent);
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 12%, transparent);
  }

  .rnc-label {
    white-space: nowrap;
    max-width: 200px;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>
