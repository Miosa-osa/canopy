<script lang="ts">
  /**
   * ToolList — grouped, collapsible list of registered tools.
   *
   * Pulls from `Canopy.Tools.Registry` via `/api/v1/tools` (no parallel
   * registry). Groups tools by their dot-prefix namespace ("analytics",
   * "sandbox", etc.) — tools without a dot land in the "core" group.
   *
   * Reuses foundation primitives — does not introduce new buttons or icons.
   *
   * CSS prefix: tl-
   */
  import { ChevronDown, ChevronRight, Search } from 'lucide-svelte';
  import Input from '$lib/design/foundation/input/Input.svelte';
  import type { RegisteredTool, ToolGroup } from '$lib/domain/mcp/types.js';

  interface Props {
    tools: RegisteredTool[];
    selectedName: string | null;
    onSelect: (name: string) => void;
  }

  let { tools, selectedName, onSelect }: Props = $props();

  let query = $state('');
  let collapsed = $state<Record<string, boolean>>({});

  /** Splits tool name on the first dot. `"analytics.foo"` → `("analytics", "foo")`. */
  function namespaceOf(name: string): string {
    const i = name.indexOf('.');
    return i === -1 ? 'core' : name.slice(0, i);
  }

  const filtered = $derived(
    query.trim() === ''
      ? tools
      : tools.filter((t) => {
          const q = query.toLowerCase();
          return (
            t.name.toLowerCase().includes(q) ||
            (t.description ?? '').toLowerCase().includes(q)
          );
        }),
  );

  const groups = $derived.by<ToolGroup[]>(() => {
    const map = new Map<string, RegisteredTool[]>();
    for (const t of filtered) {
      const ns = namespaceOf(t.name);
      const arr = map.get(ns);
      if (arr) arr.push(t);
      else map.set(ns, [t]);
    }
    return [...map.entries()]
      .map(([namespace, tools]) => ({
        namespace,
        tools: tools.toSorted((a, b) => a.name.localeCompare(b.name)),
      }))
      .toSorted((a, b) => a.namespace.localeCompare(b.namespace));
  });

  function toggle(ns: string): void {
    collapsed = { ...collapsed, [ns]: !collapsed[ns] };
  }

  function isCollapsed(ns: string): boolean {
    return collapsed[ns] ?? false;
  }
</script>

<div class="tl-root">
  <div class="tl-search">
    <Search size={12} aria-hidden="true" />
    <Input
      type="text"
      placeholder="Filter tools…"
      bind:value={query}
      aria-label="Filter tools by name or description"
    />
  </div>

  <div class="tl-meta">
    {filtered.length} of {tools.length} tools — {groups.length} namespace{groups.length === 1 ? '' : 's'}
  </div>

  <ul class="tl-groups" role="tree" aria-label="Tools by namespace">
    {#each groups as group (group.namespace)}
      {@const open = !isCollapsed(group.namespace)}
      <li class="tl-group" role="treeitem" aria-expanded={open}>
        <button
          class="tl-group__header"
          type="button"
          onclick={() => toggle(group.namespace)}
          aria-label="Toggle {group.namespace} namespace"
        >
          {#if open}
            <ChevronDown size={12} aria-hidden="true" />
          {:else}
            <ChevronRight size={12} aria-hidden="true" />
          {/if}
          <span class="tl-group__name">{group.namespace}</span>
          <span class="tl-group__count">{group.tools.length}</span>
        </button>

        {#if open}
          <ul class="tl-tools" role="group">
            {#each group.tools as tool (tool.name)}
              <li>
                <button
                  type="button"
                  class="tl-tool"
                  class:tl-tool--selected={tool.name === selectedName}
                  onclick={() => onSelect(tool.name)}
                  aria-label="Select tool {tool.name}"
                >
                  <span class="tl-tool__name">{tool.name}</span>
                  {#if tool.description}
                    <span class="tl-tool__desc">{tool.description}</span>
                  {/if}
                </button>
              </li>
            {/each}
          </ul>
        {/if}
      </li>
    {/each}

    {#if groups.length === 0}
      <li class="tl-empty">No tools match "{query}"</li>
    {/if}
  </ul>
</div>

<style>
  .tl-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 0;
    font-family: var(--font-sans);
  }

  .tl-search {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 8px 10px;
    border-bottom: 1px solid var(--border);
    color: var(--fg-subtle);
  }

  .tl-meta {
    padding: 6px 12px;
    font-size: 11px;
    color: var(--fg-subtle);
    border-bottom: 1px solid var(--border);
  }

  .tl-groups {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    list-style: none;
    margin: 0;
    padding: 4px;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .tl-group { display: flex; flex-direction: column; }

  .tl-group__header {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 8px;
    border: none;
    background: transparent;
    color: var(--fg-muted);
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    cursor: pointer;
    border-radius: var(--radius-sm);
  }
  .tl-group__header:hover {
    background: color-mix(in oklch, var(--fg) 5%, transparent);
    color: var(--fg);
  }

  .tl-group__name { flex: 1; text-align: left; }
  .tl-group__count {
    font-weight: 500;
    color: var(--fg-subtle);
    font-size: 10px;
  }

  .tl-tools {
    list-style: none;
    margin: 0;
    padding: 0 0 4px 18px;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .tl-tool {
    width: 100%;
    text-align: left;
    border: none;
    background: transparent;
    padding: 6px 8px;
    border-radius: var(--radius-sm);
    cursor: pointer;
    display: flex;
    flex-direction: column;
    gap: 2px;
    color: var(--fg);
    font-family: inherit;
  }
  .tl-tool:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent);
  }
  .tl-tool--selected {
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 14%, transparent);
  }

  .tl-tool__name {
    font-size: var(--text-xs, 12px);
    font-family: var(--font-mono, ui-monospace, monospace);
    color: var(--fg);
  }

  .tl-tool__desc {
    font-size: 11px;
    color: var(--fg-subtle);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .tl-empty {
    padding: 24px 12px;
    text-align: center;
    color: var(--fg-subtle);
    font-size: var(--text-sm);
  }
</style>
