<script lang="ts">
/**
 * ToolCallBlock — kind='tool_call' (and 'tool_result') renderer.
 *
 * Shows the tool name + a one-line args summary collapsed by default;
 * expands to the full JSON payload on click. For `tool_result`, shows
 * the result content instead of args.
 *
 * Thin component — receives the Block prop, owns only local UI state
 * (open/closed). Args / metadata read from `block.metadata`.
 *
 * CSS prefix: tcblk-
 */

import { ChevronRight } from 'lucide-svelte';
import type { Block } from '$lib/domain/blocks/types.js';

interface Props {
  block: Block;
}

let { block }: Props = $props();
let open = $state(false);

/** Strip MCP namespace prefix: mcp__ns__tool_name → tool_name. */
function cleanToolName(name: string): string {
  const m = name.match(/^mcp__[^_]+__(.+)$/);
  return m ? m[1] : name;
}

const toolName = $derived(
  typeof block.metadata?.tool_name === 'string'
    ? cleanToolName(block.metadata.tool_name as string)
    : block.kind === 'tool_result'
      ? 'result'
      : 'tool'
);

const args = $derived(block.metadata?.args ?? null);

const argsPreview = $derived(buildPreview(args));
const fullJson = $derived(stringify(args ?? block.metadata ?? {}));

function buildPreview(value: unknown): string {
  if (value == null) return '';
  if (typeof value === 'string') return value.length > 80 ? `${value.slice(0, 80)}…` : value;
  try {
    const json = JSON.stringify(value);
    return json.length > 80 ? `${json.slice(0, 80)}…` : json;
  } catch {
    return '';
  }
}

function stringify(value: unknown): string {
  try {
    return JSON.stringify(value, null, 2);
  } catch {
    return String(value);
  }
}

function toggle() {
  open = !open;
}
</script>

<div class="tcblk-root">
  <button
    class="tcblk-summary"
    onclick={toggle}
    aria-expanded={open}
    aria-label="Toggle tool call body"
  >
    <span class="tcblk-chevron" class:tcblk-chevron--open={open} aria-hidden="true">
      <ChevronRight size={10} />
    </span>
    <span class="tcblk-name">{toolName}</span>
    {#if argsPreview}
      <span class="tcblk-sep" aria-hidden="true">›</span>
      <span class="tcblk-preview">{argsPreview}</span>
    {/if}
  </button>

  {#if open}
    {#if block.kind === 'tool_result' && block.outputText}
      <pre class="tcblk-body" class:tcblk-body--err={block.status === 'failed'}>{block.outputText}</pre>
    {:else}
      <pre class="tcblk-body">{fullJson}</pre>
    {/if}
  {/if}
</div>

<style>
  .tcblk-root {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }

  .tcblk-summary {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: 4px 0;
    background: transparent;
    border: none;
    cursor: pointer;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    text-align: left;
    min-width: 0;
  }

  .tcblk-chevron {
    display: inline-flex;
    align-items: center;
    color: var(--fg-subtle);
    transition: transform 0.15s var(--ease-out, cubic-bezier(0.16, 1, 0.3, 1));
    flex-shrink: 0;
  }

  .tcblk-chevron--open {
    transform: rotate(90deg);
  }

  .tcblk-name {
    color: var(--signal-thinking, var(--fg));
    font-weight: 600;
    flex-shrink: 0;
  }

  .tcblk-sep {
    color: color-mix(in oklch, var(--fg-subtle) 40%, transparent 60%);
    flex-shrink: 0;
  }

  .tcblk-preview {
    color: var(--fg-subtle);
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
  }

  .tcblk-body {
    margin: var(--space-1) 0 0 0;
    padding: var(--space-2);
    border: 1px solid color-mix(in oklch, var(--border) 60%, transparent 40%);
    border-radius: var(--radius-md);
    background: color-mix(in oklch, var(--bg-inset, var(--bg)) 60%, transparent 40%);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    line-height: 1.6;
    color: var(--fg-muted);
    white-space: pre-wrap;
    word-break: break-all;
    max-height: 320px;
    overflow-y: auto;
  }

  .tcblk-body--err {
    color: var(--signal-error, oklch(0.55 0.22 25));
  }
</style>
