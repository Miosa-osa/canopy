<script lang="ts">
/**
 * MosaicNode — recursive renderer for Split | Tile nodes.
 * Uses svelte:self for recursion on split children.
 * CSS prefix: mn-
 * LOC target: ≤ 100.
 */
import ResizablePanel from '$lib/design/primitives/ResizablePanel.svelte';
import type { Node, Split, Tile } from '$lib/stores/mosaic-layout.svelte.js';
import MosaicTile from './MosaicTile.svelte';

interface Props {
  node: Node;
}

let { node }: Props = $props();

function isSplit(n: Node): n is Split {
  return n.type === 'split';
}

// ResizablePanel sizes the *second* pane. ratio is for the first child.
const VIEWPORT_REF = 1200;

function ratioToSecondPx(ratio: number): number {
  return Math.round((1 - ratio) * VIEWPORT_REF);
}

// Narrowed reactive refs so template snippets close over typed values.
const splitNode = $derived(isSplit(node) ? node : null);
const tileNode = $derived(!isSplit(node) ? (node as Tile) : null);
</script>

{#if splitNode !== null}
  <div class="mn-split mn-split--{splitNode.orientation}">
    {#if splitNode.orientation === 'vertical'}
      <ResizablePanel
        orientation="horizontal"
        defaultSize={ratioToSecondPx(splitNode.ratio)}
        minSize={200}
        maxSize={900}
      >
        {#snippet left()}
          <svelte:self node={splitNode.a} />
        {/snippet}
        {#snippet right()}
          <svelte:self node={splitNode.b} />
        {/snippet}
      </ResizablePanel>
    {:else}
      <ResizablePanel
        orientation="vertical"
        defaultSize={ratioToSecondPx(splitNode.ratio)}
        minSize={160}
        maxSize={900}
      >
        {#snippet top()}
          <svelte:self node={splitNode.a} />
        {/snippet}
        {#snippet bottom()}
          <svelte:self node={splitNode.b} />
        {/snippet}
      </ResizablePanel>
    {/if}
  </div>
{:else if tileNode !== null}
  <MosaicTile tile={tileNode} />
{/if}

<style>
  .mn-split {
    display: flex;
    width: 100%;
    height: 100%;
    min-height: 0;
    overflow: hidden;
  }

  .mn-split--horizontal {
    flex-direction: column;
  }

  .mn-split--vertical {
    flex-direction: row;
  }
</style>
