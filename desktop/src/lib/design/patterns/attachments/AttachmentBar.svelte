<script lang="ts">
  import type { AttachedFile } from './types.js';
  import AttachmentChip from './AttachmentChip.svelte';

  interface Props {
    files: AttachedFile[];
    onRemove: (id: string) => void;
  }

  let { files, onRemove }: Props = $props();

  const totalSize = $derived(files.reduce((sum, f) => sum + f.size, 0));

  function formatTotalSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }

  const summary = $derived(
    `${files.length} file${files.length !== 1 ? 's' : ''} (${formatTotalSize(totalSize)})`
  );
</script>

{#if files.length > 0}
  <div class="abar-root" role="list" aria-label="Attached files">
    <div class="abar-chips">
      {#each files as file (file.id)}
        <AttachmentChip {file} {onRemove} />
      {/each}
    </div>
    <span class="abar-summary" aria-live="polite">{summary}</span>
  </div>
{/if}

<style>
  .abar-root {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0 12px 8px;
    overflow: hidden;
  }

  .abar-chips {
    display: flex;
    align-items: center;
    gap: 5px;
    overflow-x: auto;
    flex: 1;
    min-width: 0;
    scrollbar-width: none;
  }

  .abar-chips::-webkit-scrollbar {
    display: none;
  }

  .abar-summary {
    font-family: var(--font-mono);
    font-size: 9px;
    color: var(--fg-subtle, #6b7280);
    white-space: nowrap;
    flex-shrink: 0;
  }
</style>
