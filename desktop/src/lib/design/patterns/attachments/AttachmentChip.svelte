<script lang="ts">
import { FileCode, FileText, X } from 'lucide-svelte';
import type { AttachedFile } from './types.js';

interface Props {
  file: AttachedFile;
  onRemove: (id: string) => void;
}

let { file, onRemove }: Props = $props();

const CODE_EXTS = new Set(['ts', 'tsx', 'js', 'jsx', 'svelte', 'py', 'go', 'ex', 'exs', 'json']);

const ext = $derived(file.name.split('.').pop()?.toLowerCase() ?? '');
const isImage = $derived(file.mimeType.startsWith('image/'));
const isCode = $derived(CODE_EXTS.has(ext));

const displayName = $derived(file.name.length > 20 ? file.name.slice(0, 18) + '…' : file.name);

function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes}B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)}KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)}MB`;
}
</script>

<div class="ach-chip" role="listitem">
  {#if isImage && file.preview}
    <img src={file.preview} alt={file.name} class="ach-thumb" />
  {:else}
    <span class="ach-icon" aria-hidden="true">
      {#if isCode}
        <FileCode size={13} />
      {:else}
        <FileText size={13} />
      {/if}
    </span>
  {/if}

  <span class="ach-name" title={file.name}>{displayName}</span>

  {#if !isImage}
    <span class="ach-size">{formatSize(file.size)}</span>
  {/if}

  <button
    class="ach-remove"
    onclick={() => onRemove(file.id)}
    aria-label="Remove {file.name}"
  >
    <X size={11} aria-hidden="true" />
  </button>
</div>

<style>
  .ach-chip {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 3px 6px 3px 5px;
    background: color-mix(in oklch, var(--fg, #e8e8e8) 6%, transparent);
    border: 1px solid var(--border, rgba(255,255,255,0.1));
    border-radius: var(--radius-sm, 6px);
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-muted, #a0a0a0);
    max-width: 200px;
    transition: background 100ms;
  }

  .ach-chip:hover {
    background: color-mix(in oklch, var(--fg, #e8e8e8) 9%, transparent);
  }

  .ach-thumb {
    width: 22px;
    height: 22px;
    border-radius: 3px;
    object-fit: cover;
    flex-shrink: 0;
  }

  .ach-icon {
    display: inline-flex;
    align-items: center;
    flex-shrink: 0;
    color: var(--fg-subtle, #6b7280);
  }

  .ach-name {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex: 1;
    min-width: 0;
    color: var(--fg-muted, #a0a0a0);
  }

  .ach-size {
    font-family: var(--font-mono);
    font-size: 9px;
    color: var(--fg-subtle, #6b7280);
    flex-shrink: 0;
  }

  .ach-remove {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 15px;
    height: 15px;
    border: none;
    background: none;
    color: var(--fg-subtle, #6b7280);
    cursor: pointer;
    border-radius: 50%;
    padding: 0;
    flex-shrink: 0;
    transition: color 80ms, background 80ms;
    opacity: 0.6;
  }

  .ach-chip:hover .ach-remove {
    opacity: 1;
  }

  .ach-remove:hover {
    color: var(--fg, #e8e8e8);
    background: color-mix(in oklch, var(--fg, #e8e8e8) 12%, transparent);
  }
</style>
