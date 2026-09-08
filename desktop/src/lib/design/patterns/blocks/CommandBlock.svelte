<script lang="ts">
/**
 * CommandBlock — kind='command' renderer.
 * Shows the input as a `$ ...` line and the (ANSI-stripped) output below.
 *
 * Thin component — no fetching, no state. Receives the Block prop and
 * renders. ANSI stripping happens here because raw stdout often arrives
 * with terminal escape codes that the foundation primitives cannot
 * style on their own.
 *
 * CSS prefix: cmdblk-
 */

import type { Block } from '$lib/domain/blocks/types.js';

interface Props {
  block: Block;
}

let { block }: Props = $props();

/** Strip ANSI CSI / OSC escape sequences for plain-text rendering. */
function stripAnsi(text: string): string {
  // CSI: \x1b[ ... m and similar
  // OSC: \x1b] ... \x07 or \x1b\\
  // Plus a few other common control runs.
  // biome-ignore lint/suspicious/noControlCharactersInRegex: ANSI stripping requires terminal control characters.
  const csi = /\x1b\[[0-9;?]*[ -/]*[@-~]/g;
  // biome-ignore lint/suspicious/noControlCharactersInRegex: ANSI stripping requires terminal control characters.
  const osc = /\x1b\][^\x07]*(\x07|\x1b\\)/g;
  return text.replace(csi, '').replace(osc, '');
}

const cleanOutput = $derived(block.outputText ? stripAnsi(block.outputText) : '');
</script>

<div class="cmdblk-root">
  {#if block.inputText}
    <pre class="cmdblk-input"><span class="cmdblk-prompt" aria-hidden="true">$ </span>{block.inputText}</pre>
  {/if}
  {#if cleanOutput}
    <pre class="cmdblk-output" class:cmdblk-output--err={block.status === 'failed'}>{cleanOutput}</pre>
  {:else if block.status === 'running'}
    <p class="cmdblk-empty">running…</p>
  {/if}
</div>

<style>
  .cmdblk-root {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
    min-width: 0;
  }

  .cmdblk-input {
    margin: 0;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    line-height: 1.6;
    color: var(--fg);
    white-space: pre-wrap;
    word-break: break-all;
  }

  .cmdblk-prompt {
    color: var(--signal-thinking, var(--fg-muted));
    font-weight: 600;
    user-select: none;
  }

  .cmdblk-output {
    margin: 0;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    line-height: 1.6;
    color: var(--fg-muted);
    white-space: pre-wrap;
    word-break: break-all;
    max-height: 320px;
    overflow-y: auto;
  }

  .cmdblk-output--err {
    color: var(--signal-error, oklch(0.55 0.22 25));
  }

  .cmdblk-empty {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-style: italic;
    color: var(--fg-subtle);
  }
</style>
