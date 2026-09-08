<script lang="ts">
/**
 * ConversationIntroCard — empty-state intro shown above the composer
 * when an Agent Conversation pane has no messages yet.
 *
 * Title + subtitle + a list of keyboard shortcuts the user can run
 * right now. When the input starts with `/` the parent pane swaps the
 * card out for the existing SlashCommands palette — this card itself
 * is purely informational.
 *
 * CSS prefix: cic-
 */
import { Bot } from 'lucide-svelte';

interface Props {
  /** Working directory shown in the subtitle. */
  cwd?: string;
}

let { cwd = '~' }: Props = $props();

interface Shortcut {
  keys: string;
  label: string;
}

const shortcuts: Shortcut[] = [
  { keys: '⌘↵', label: 'start a new agent conversation' },
  { keys: '⌥⌘↵', label: 'start a new cloud conversation' },
  { keys: '/model', label: 'switch model' },
  { keys: 'esc', label: 'go back to terminal' },
];
</script>

<div class="cic-card" role="region" aria-label="New conversation">
  <header class="cic-header">
    <span class="cic-icon" aria-hidden="true">
      <Bot size={14} />
    </span>
    <h2 class="cic-title">New conversation</h2>
  </header>

  <p class="cic-subtitle">
    Send a prompt below to start a new conversation in
    <code class="cic-cwd">{cwd}</code>
  </p>

  <ul class="cic-shortcuts" role="list">
    {#each shortcuts as s (s.keys)}
      <li class="cic-shortcut">
        <kbd class="cic-kbd">{s.keys}</kbd>
        <span class="cic-shortcut__label">{s.label}</span>
      </li>
    {/each}
  </ul>
</div>

<style>
  .cic-card {
    margin: 32px auto;
    max-width: 520px;
    padding: 18px 20px;
    border: 1px solid var(--border, rgba(255, 255, 255, 0.08));
    border-radius: var(--radius-lg, 10px);
    background: color-mix(in oklch, var(--fg) 3%, transparent);
    font-family: var(--font-sans);
  }

  .cic-header {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 6px;
  }

  .cic-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    border-radius: 6px;
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 18%, transparent);
    color: var(--cnp-accent, oklch(0.72 0.18 145));
  }

  .cic-title {
    margin: 0;
    font-size: 13px;
    font-weight: 600;
    color: var(--fg);
  }

  .cic-subtitle {
    margin: 0 0 14px;
    font-size: 12px;
    color: var(--fg-muted);
    line-height: 1.5;
  }

  .cic-cwd {
    font-family: var(--font-mono, ui-monospace, monospace);
    font-size: 11.5px;
    padding: 1px 5px;
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    border-radius: 4px;
    color: var(--fg);
  }

  .cic-shortcuts {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .cic-shortcut {
    display: grid;
    grid-template-columns: 64px 1fr;
    gap: 12px;
    align-items: center;
    padding: 4px 0;
    font-size: 12px;
    color: var(--fg-muted);
  }

  .cic-shortcut__label {
    color: var(--fg);
  }

  .cic-kbd {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 1px 6px;
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    border: 1px solid var(--border, rgba(255, 255, 255, 0.10));
    border-radius: 4px;
    font-family: var(--font-mono, ui-monospace, monospace);
    font-size: 10.5px;
    color: var(--fg);
    min-width: 28px;
    text-align: center;
  }
</style>
