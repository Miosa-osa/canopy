<script lang="ts">
  /**
   * ShellCommandHint — small affordance row shown above the composer when
   * the input looks like a shell command instead of an agent prompt.
   *
   * Mirrors the reference design's "autodetected shell command, ⌘| to
   * override" inline hint. Stateless — visibility and toggling logic live
   * in ConversationComposer.
   *
   * CSS prefix: ach-
   */
  import { TerminalSquare } from 'lucide-svelte';

  interface Props {
    /** Show/hide controlled by parent. */
    visible: boolean;
    /** Set true after the user pressed ⌘| — flips the hint label. */
    overridden?: boolean;
    /** Click target — toggles between agent-prompt and shell-execute mode. */
    onToggle?: () => void;
  }

  let { visible, overridden = false, onToggle }: Props = $props();
</script>

{#if visible}
  <div class="ach-row" role="status" aria-live="polite">
    <TerminalSquare size={11} aria-hidden="true" />
    {#if overridden}
      <span class="ach-msg">running as agent prompt,</span>
      <button class="ach-toggle" type="button" onclick={onToggle} aria-label="Switch back to shell command">
        <kbd>⌘|</kbd> to run as shell
      </button>
    {:else}
      <span class="ach-msg">autodetected shell command,</span>
      <button class="ach-toggle" type="button" onclick={onToggle} aria-label="Override shell detection — send as agent prompt">
        <kbd>⌘|</kbd> to override
      </button>
    {/if}
  </div>
{/if}

<style>
  .ach-row {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 12px;
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
    border-top: 1px solid var(--border, rgba(255, 255, 255, 0.06));
    background: color-mix(in oklch, var(--fg) 3%, transparent);
  }

  .ach-msg {
    flex: 0 0 auto;
  }

  .ach-toggle {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 0;
    border: none;
    background: transparent;
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: 11px;
    cursor: pointer;
  }

  .ach-toggle:hover {
    color: var(--fg);
    text-decoration: underline;
  }

  kbd {
    display: inline-block;
    padding: 0 4px;
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    border: 1px solid var(--border);
    border-radius: 3px;
    font-family: var(--font-mono, monospace);
    font-size: 10px;
    color: var(--fg);
  }
</style>
