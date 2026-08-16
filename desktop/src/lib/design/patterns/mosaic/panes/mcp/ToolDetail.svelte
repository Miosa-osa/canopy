<script lang="ts">
  /**
   * ToolDetail — header card for a selected tool.
   *
   * Renders name, description, capability requirements, MCP/prompt exposure,
   * and a collapsible parameters JSON-Schema block. Test invocation is
   * delegated to ToolInvoker — this component is purely descriptive.
   *
   * CSS prefix: td-
   */
  import { ChevronDown, ChevronRight, Play } from 'lucide-svelte';
  import Button from '$lib/design/foundation/button/Button.svelte';
  import type { RegisteredTool } from '$lib/domain/mcp/types.js';

  interface Props {
    tool: RegisteredTool;
    onTest: () => void;
  }

  let { tool, onTest }: Props = $props();

  let schemaOpen = $state(false);

  const schemaJson = $derived(
    tool.parameters ? JSON.stringify(tool.parameters, null, 2) : null,
  );
</script>

<section class="td-root" aria-labelledby="td-name">
  <header class="td-header">
    <div class="td-header__line">
      <h2 id="td-name" class="td-name">{tool.name}</h2>
      <Button variant="primary" size="default" onclick={onTest}>
        {#snippet prefix()}<Play size={12} aria-hidden="true" />{/snippet}
        Test invocation
      </Button>
    </div>

    {#if tool.description}
      <p class="td-desc">{tool.description}</p>
    {/if}

    <div class="td-meta">
      {#if tool.requires.length > 0}
        <span class="td-meta__group" aria-label="Required capabilities">
          <span class="td-meta__label">Requires:</span>
          {#each tool.requires as cap (cap)}
            <span class="td-chip">{cap}</span>
          {/each}
        </span>
      {/if}

      <span class="td-meta__group">
        <span class="td-chip" data-state={tool.mcpExposed ? 'on' : 'off'}>
          {tool.mcpExposed ? 'MCP exposed' : 'MCP hidden'}
        </span>
        <span class="td-chip" data-state={tool.promptExposed ? 'on' : 'off'}>
          {tool.promptExposed ? 'Prompt exposed' : 'Prompt hidden'}
        </span>
      </span>
    </div>
  </header>

  {#if schemaJson}
    <button
      class="td-schema__toggle"
      type="button"
      onclick={() => (schemaOpen = !schemaOpen)}
      aria-expanded={schemaOpen}
      aria-controls="td-schema-body"
    >
      {#if schemaOpen}
        <ChevronDown size={12} aria-hidden="true" />
      {:else}
        <ChevronRight size={12} aria-hidden="true" />
      {/if}
      Parameters schema
    </button>

    {#if schemaOpen}
      <pre id="td-schema-body" class="td-schema__body"><code>{schemaJson}</code></pre>
    {/if}
  {:else}
    <p class="td-no-schema">No parameters declared.</p>
  {/if}
</section>

<style>
  .td-root {
    display: flex;
    flex-direction: column;
    gap: 12px;
    padding: 16px;
    border-bottom: 1px solid var(--border);
    font-family: var(--font-sans);
  }

  .td-header { display: flex; flex-direction: column; gap: 8px; }

  .td-header__line {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
  }

  .td-name {
    margin: 0;
    font-size: var(--text-base);
    font-weight: 600;
    font-family: var(--font-mono, ui-monospace, monospace);
    color: var(--fg);
    overflow-wrap: anywhere;
  }

  .td-desc {
    margin: 0;
    font-size: var(--text-sm);
    color: var(--fg-muted);
    line-height: 1.45;
    white-space: pre-wrap;
  }

  .td-meta {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
    align-items: center;
    font-size: 11px;
  }

  .td-meta__group {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    flex-wrap: wrap;
  }

  .td-meta__label {
    color: var(--fg-subtle);
    font-weight: 500;
  }

  .td-chip {
    display: inline-flex;
    align-items: center;
    height: 18px;
    padding: 0 6px;
    border-radius: 9999px;
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg-muted);
    font-size: 10px;
    font-weight: 500;
    letter-spacing: 0.02em;
  }
  .td-chip[data-state='on'] {
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 18%, transparent);
    color: var(--fg);
  }
  .td-chip[data-state='off'] {
    background: color-mix(in oklch, var(--fg) 5%, transparent);
    color: var(--fg-subtle);
  }

  .td-schema__toggle {
    align-self: flex-start;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    border: none;
    background: transparent;
    color: var(--fg-muted);
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    cursor: pointer;
    padding: 4px 0;
  }
  .td-schema__toggle:hover { color: var(--fg); }

  .td-schema__body {
    margin: 0;
    padding: 10px 12px;
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    border-radius: var(--radius-sm);
    font-family: var(--font-mono, ui-monospace, monospace);
    font-size: 11px;
    line-height: 1.45;
    color: var(--fg);
    overflow: auto;
    max-height: 240px;
    white-space: pre;
  }

  .td-no-schema {
    margin: 0;
    color: var(--fg-subtle);
    font-size: 11px;
    font-style: italic;
  }
</style>
