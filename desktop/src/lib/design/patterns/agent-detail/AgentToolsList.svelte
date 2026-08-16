<script lang="ts">
  /**
   * AgentToolsList — read-only list of tools this agent can dispatch.
   * Filtered by capabilities where logical (exec_shell → shell tools, etc.).
   * CSS prefix: atl- (AgentToolsList)
   */
  import type { Tool } from '$lib/domain/tools/types.js';
  import type { Capability } from '$lib/domain/agents/config.js';

  interface Props {
    tools: Tool[];
    isLoading: boolean;
    capabilities: Capability[];
  }

  let { tools, isLoading, capabilities }: Props = $props();

  // Simple relevance filter: if no exec_shell capability, dim shell-related tools
  const shellToolKeywords = ['exec', 'shell', 'bash', 'run', 'command', 'terminal'];
  const hasExec = $derived(capabilities.includes('exec_shell'));

  function isShellTool(t: Tool): boolean {
    const name = t.name.toLowerCase();
    return shellToolKeywords.some((kw) => name.includes(kw));
  }
</script>

<div class="atl-root">
  {#if isLoading}
    <p class="atl-hint">Loading tools…</p>
  {:else if tools.length === 0}
    <p class="atl-hint">No tools registered. Tools are registered via the backend at startup.</p>
  {:else}
    <p class="atl-sub">
      {tools.length} tool{tools.length === 1 ? '' : 's'} available. Dimmed tools require capabilities
      not currently enabled.
    </p>
    <div class="atl-list" role="list">
      {#each tools as tool (tool.name)}
        {@const dimmed = isShellTool(tool) && !hasExec}
        <div class="atl-row" class:atl-row--dimmed={dimmed} role="listitem">
          <code class="atl-name">{tool.name}</code>
          {#if tool.description}
            <span class="atl-desc">{tool.description}</span>
          {/if}
          {#if dimmed}
            <span class="atl-cap-warn">Requires exec_shell</span>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .atl-root {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-6);
  }

  .atl-hint,
  .atl-sub {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  .atl-list {
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .atl-row {
    display: flex;
    align-items: baseline;
    gap: var(--space-3);
    padding: var(--space-2) var(--space-2);
    border-radius: var(--radius-sm);
    transition: background 0.1s, opacity 0.1s;
  }

  .atl-row:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  .atl-row--dimmed {
    opacity: 0.4;
  }

  .atl-name {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 1px 6px;
    flex-shrink: 0;
  }

  .atl-desc {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    line-height: 1.5;
    flex: 1;
    min-width: 0;
  }

  .atl-cap-warn {
    font-family: var(--font-mono);
    font-size: 10px;
    color: oklch(0.75 0.12 85);
    flex-shrink: 0;
  }
</style>
