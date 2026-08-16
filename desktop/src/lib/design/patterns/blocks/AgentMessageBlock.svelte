<script lang="ts">
  /**
   * AgentMessageBlock — kind='agent_message' renderer.
   *
   * Renders the markdown body of an LLM message and an optional model
   * badge pulled from `metadata.model`. Markdown is rendered as
   * pre-wrapped plain text here (a markdown renderer can be plugged in
   * later via the foundation layer).
   *
   * Thin component — no fetching, no state. Pure render of `block` prop.
   *
   * CSS prefix: amsg-
   */

  import type { Block } from '$lib/domain/blocks/types.js';

  interface Props {
    block: Block;
  }

  let { block }: Props = $props();

  const model = $derived(
    typeof block.metadata?.model === 'string' ? (block.metadata.model as string) : null,
  );

  const body = $derived(block.outputText ?? block.inputText ?? '');
</script>

<div class="amsg-root">
  {#if model}
    <span class="amsg-badge" aria-label="model">{model}</span>
  {/if}
  {#if body}
    <p class="amsg-body">{body}</p>
  {:else}
    <p class="amsg-empty">No content.</p>
  {/if}
</div>

<style>
  .amsg-root {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    min-width: 0;
  }

  .amsg-badge {
    align-self: flex-start;
    padding: 1px 8px;
    border-radius: 999px;
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg-muted);
    font-family: var(--font-mono);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .amsg-body {
    margin: 0;
    font-family: var(--font-sans);
    font-size: 14px;
    line-height: 1.65;
    color: var(--fg);
    white-space: pre-wrap;
    word-wrap: break-word;
  }

  .amsg-empty {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-style: italic;
    color: var(--fg-subtle);
  }
</style>
