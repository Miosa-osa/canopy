<script lang="ts">
/**
 * SystemEventBlock — kind='system_event', 'error', and 'diff' renderer.
 *
 * Small grey row with an icon + message. For 'diff' blocks, the inputText
 * carries the patch which is rendered in a code block. For 'error', the
 * row is tinted red. Otherwise it is muted grey.
 *
 * Thin pure-render component.
 *
 * CSS prefix: sysblk-
 */

import { AlertCircle, FileDiff, Info } from 'lucide-svelte';
import type { Block } from '$lib/domain/blocks/types.js';

interface Props {
  block: Block;
}

let { block }: Props = $props();

const Icon = $derived(
  block.kind === 'error' ? AlertCircle : block.kind === 'diff' ? FileDiff : Info
);

const message = $derived(block.outputText ?? block.inputText ?? '');
const filePath = $derived(
  typeof block.metadata?.file_path === 'string' ? (block.metadata.file_path as string) : null
);
</script>

<div class="sysblk-root" data-kind={block.kind}>
  <span class="sysblk-icon" aria-hidden="true">
    <Icon size={12} />
  </span>
  <div class="sysblk-content">
    {#if filePath}
      <span class="sysblk-path">{filePath}</span>
    {/if}
    {#if message}
      {#if block.kind === 'diff'}
        <pre class="sysblk-patch">{message}</pre>
      {:else}
        <p class="sysblk-text">{message}</p>
      {/if}
    {/if}
  </div>
</div>

<style>
  .sysblk-root {
    display: flex;
    align-items: flex-start;
    gap: var(--space-2);
    padding: var(--space-1) 0;
    color: var(--fg-subtle);
    min-width: 0;
  }

  .sysblk-root[data-kind='error'] {
    color: var(--signal-error, oklch(0.55 0.22 25));
  }

  .sysblk-icon {
    display: flex;
    align-items: center;
    flex-shrink: 0;
    margin-top: 2px;
  }

  .sysblk-content {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .sysblk-path {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .sysblk-text {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    line-height: 1.6;
  }

  .sysblk-patch {
    margin: 0;
    padding: var(--space-2);
    border: 1px solid color-mix(in oklch, var(--border) 60%, transparent 40%);
    border-radius: var(--radius-md);
    background: color-mix(in oklch, var(--bg-inset, var(--bg)) 60%, transparent 40%);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    line-height: 1.6;
    color: var(--fg-muted);
    overflow-x: auto;
    max-height: 320px;
    white-space: pre;
  }
</style>
