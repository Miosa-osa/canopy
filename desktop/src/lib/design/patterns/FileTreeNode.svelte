<script lang="ts">
/**
 * FileTreeNode — recursive node in the FileTree component.
 * Renders one FileTreeNode and its children (if expanded).
 * LOC target: ≤ 100. CSS prefix: ft-.
 */

import { File, Folder, FolderOpen } from 'lucide-svelte';
import type { FileTreeNode as FileTreeNodeData } from '$lib/domain/workspaces/types.js';
import FileTreeNode from './FileTreeNode.svelte';

interface Props {
  node: FileTreeNodeData;
  depth: number;
  selectedPath: string | undefined;
  focusedPath: string | undefined;
  onSelect: (path: string) => void;
  onToggle: (path: string) => void;
  /** Expanded dir paths — passed down so toggling works from parent state. */
  expandedPaths: Set<string>;
}

let { node, depth, selectedPath, focusedPath, onSelect, onToggle, expandedPaths }: Props = $props();

const isExpanded = $derived(expandedPaths.has(node.path));
const isSelected = $derived(selectedPath === node.path);
const isFocused = $derived(focusedPath === node.path);
const indent = $derived(depth * 12);
</script>

<li class="ft-node" role="none">
  <!-- Row button -->
  <button
    class="ft-row"
    class:ft-row--selected={isSelected}
    class:ft-row--focused={isFocused}
    style="padding-left: calc(var(--space-2) + {indent}px);"
    onclick={() => {
      if (node.isDir) {
        onToggle(node.path);
      } else {
        onSelect(node.path);
      }
    }}
    aria-expanded={node.isDir ? isExpanded : undefined}
    aria-current={!node.isDir && isSelected ? 'true' : undefined}
    data-path={node.path}
    title={node.path}
  >
    <span class="ft-icon" aria-hidden="true">
      {#if node.isDir}
        {#if isExpanded}
          <!-- svelte-ignore svelte_component_deprecated -->
          <svelte:component this={FolderOpen as unknown as typeof import('svelte').SvelteComponent} size={14} />
        {:else}
          <!-- svelte-ignore svelte_component_deprecated -->
          <svelte:component this={Folder as unknown as typeof import('svelte').SvelteComponent} size={14} />
        {/if}
      {:else}
        <!-- svelte-ignore svelte_component_deprecated -->
        <svelte:component this={File as unknown as typeof import('svelte').SvelteComponent} size={14} />
      {/if}
    </span>
    <span class="ft-name">{node.name}</span>
  </button>

  <!-- Children (only rendered when expanded) -->
  {#if node.isDir && isExpanded && node.children.length > 0}
    <ul class="ft-children" role="group">
      {#each node.children as child (child.path)}
        <FileTreeNode
          node={child}
          depth={depth + 1}
          {selectedPath}
          {focusedPath}
          {onSelect}
          {onToggle}
          {expandedPaths}
        />
      {/each}
    </ul>
  {/if}
</li>

<style>
  .ft-node {
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .ft-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    width: 100%;
    min-height: 26px;
    padding-right: var(--space-3);
    border: none;
    background: transparent;
    border-radius: var(--radius-sm);
    cursor: pointer;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    text-align: left;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
    white-space: nowrap;
    overflow: hidden;
  }

  .ft-row:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .ft-row--selected {
    background: color-mix(in oklch, var(--fg) 10%, transparent 90%);
    color: var(--fg);
  }

  .ft-row--focused:not(.ft-row--selected) {
    outline: 1px solid var(--border-strong);
    outline-offset: -1px;
  }

  .ft-icon {
    display: flex;
    align-items: center;
    flex-shrink: 0;
    color: var(--fg-subtle);
  }

  .ft-row--selected .ft-icon,
  .ft-row:hover .ft-icon {
    color: var(--fg-muted);
  }

  .ft-name {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ft-children {
    list-style: none;
    margin: 0;
    padding: 0;
  }
</style>
