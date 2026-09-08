<script lang="ts">
/**
 * McpPane — Mosaic pane for inspecting registered tools and live invocations.
 *
 * Layout (3 zones):
 *   ┌──────────┬──────────────────────────┐
 *   │  Tool    │  Tool detail             │
 *   │  list    │  + Test invocation       │
 *   │  (left)  │  (top-right)             │
 *   │          ├──────────────────────────┤
 *   │          │  Invocation log          │
 *   │          │  (bottom-right, polled)  │
 *   │          ├──────────────────────────┤
 *   │          │  MCP servers (stub)      │
 *   └──────────┴──────────────────────────┘
 *
 * Reuses (no parallel implementation):
 *   - Canopy.Tools.Registry  via /api/v1/tools
 *   - AgentToolsController   via POST /api/v1/agents/tools/:tool_name
 *   - Canopy.Agents.ToolCalls via GET /api/v1/agents/tool-calls (added)
 *
 * CSS prefix: mp-
 */
import { createQuery } from '@tanstack/svelte-query';
import { registeredToolsQuery } from '$lib/api/queries/mcp.js';
import type { RegisteredTool } from '$lib/domain/mcp/types.js';
import InvocationLog from './mcp/InvocationLog.svelte';
import McpServerList from './mcp/McpServerList.svelte';
import ToolDetail from './mcp/ToolDetail.svelte';
import ToolInvoker from './mcp/ToolInvoker.svelte';
import ToolList from './mcp/ToolList.svelte';

const tools = createQuery(registeredToolsQuery());

let selectedName = $state<string | null>(null);
let invokerOpen = $state(false);

const toolList = $derived<RegisteredTool[]>($tools.data ?? []);

const selected = $derived<RegisteredTool | null>(
  selectedName ? (toolList.find((t) => t.name === selectedName) ?? null) : null
);

$effect(() => {
  // Auto-select first tool once data lands.
  if (!selectedName && toolList.length > 0) {
    selectedName = toolList[0]!.name;
  }
});

function handleSelect(name: string): void {
  selectedName = name;
  invokerOpen = false;
}
</script>

<div class="mp-root">
  <aside class="mp-left">
    {#if $tools.isLoading}
      <p class="mp-empty">Loading tools…</p>
    {:else if $tools.isError}
      <p class="mp-empty mp-empty--err">
        Failed to load registry: {$tools.error?.message ?? 'unknown'}
      </p>
    {:else}
      <ToolList
        tools={toolList}
        selectedName={selectedName}
        onSelect={handleSelect}
      />
    {/if}
  </aside>

  <main class="mp-right">
    <div class="mp-detail">
      {#if selected}
        <ToolDetail tool={selected} onTest={() => (invokerOpen = true)} />
        {#if invokerOpen}
          <ToolInvoker tool={selected} onClose={() => (invokerOpen = false)} />
        {/if}
      {:else}
        <p class="mp-empty">
          {toolList.length === 0
            ? 'Registry has no tools.'
            : 'Pick a tool from the left.'}
        </p>
      {/if}
    </div>

    <div class="mp-log">
      <InvocationLog filterTool={selected?.name ?? null} />
    </div>

    <div class="mp-servers">
      <McpServerList />
    </div>
  </main>
</div>

<style>
  .mp-root {
    display: grid;
    grid-template-columns: minmax(220px, 280px) 1fr;
    height: 100%;
    min-height: 0;
    overflow: hidden;
    font-family: var(--font-sans);
    background: var(--bg);
  }

  .mp-left {
    border-right: 1px solid var(--border);
    display: flex;
    flex-direction: column;
    min-height: 0;
    overflow: hidden;
  }

  .mp-right {
    display: grid;
    grid-template-rows: minmax(0, 1fr) minmax(160px, 240px) auto;
    min-height: 0;
    overflow: hidden;
  }

  .mp-detail {
    overflow-y: auto;
    min-height: 0;
    display: flex;
    flex-direction: column;
  }

  .mp-log {
    border-top: 1px solid var(--border);
    min-height: 0;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .mp-servers {
    min-height: 0;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .mp-empty {
    margin: 0;
    padding: 24px;
    text-align: center;
    color: var(--fg-subtle);
    font-size: var(--text-sm);
  }
  .mp-empty--err { color: oklch(0.6 0.18 25); }
</style>
