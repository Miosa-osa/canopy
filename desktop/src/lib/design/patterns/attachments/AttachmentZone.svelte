<script lang="ts">
import { Upload } from 'lucide-svelte';
import type { Snippet } from 'svelte';
import type { AttachedFile } from './types.js';

interface Props {
  children: Snippet;
  onAttach: (files: AttachedFile[]) => void;
  disabled?: boolean;
}

let { children, onAttach, disabled = false }: Props = $props();

const MAX_SIZE = 10 * 1024 * 1024; // 10 MB

const ACCEPTED_MIME = new Set([
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
  'image/svg+xml',
  'image/avif',
  'text/plain',
  'text/markdown',
  'text/csv',
  'text/x-python',
  'text/x-typescript',
  'text/javascript',
  'text/x-go',
  'application/json',
  'application/pdf',
]);

const ACCEPTED_EXT = new Set([
  'txt',
  'md',
  'json',
  'csv',
  'pdf',
  'py',
  'ts',
  'tsx',
  'js',
  'jsx',
  'svelte',
  'ex',
  'exs',
  'go',
]);

let dragCounter = $state(0);
let isDragging = $derived(dragCounter > 0);

function isAccepted(file: File): boolean {
  if (file.type.startsWith('image/')) return true;
  if (ACCEPTED_MIME.has(file.type)) return true;
  const ext = file.name.split('.').pop()?.toLowerCase() ?? '';
  return ACCEPTED_EXT.has(ext);
}

function showError(msg: string): void {
  // Use native toast if available; fall back to console
  console.warn('[AttachmentZone]', msg);
}

function readPreview(file: File): Promise<string | null> {
  if (!file.type.startsWith('image/')) return Promise.resolve(null);
  return new Promise((resolve) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = () => resolve(null);
    reader.readAsDataURL(file);
  });
}

async function processFiles(raw: File[]): Promise<void> {
  const valid: AttachedFile[] = [];
  for (const file of raw) {
    if (file.size > MAX_SIZE) {
      showError(`"${file.name}" exceeds 10 MB limit and was skipped.`);
      continue;
    }
    if (!isAccepted(file)) {
      showError(`"${file.name}" is not a supported file type and was skipped.`);
      continue;
    }
    const preview = await readPreview(file);
    valid.push({
      id: crypto.randomUUID(),
      name: file.name,
      size: file.size,
      mimeType: file.type,
      preview,
      file,
    });
  }
  if (valid.length > 0) onAttach(valid);
}

function ondragenter(e: DragEvent): void {
  e.preventDefault();
  if (disabled) return;
  dragCounter++;
}

function ondragover(e: DragEvent): void {
  e.preventDefault();
}

function ondragleave(e: DragEvent): void {
  e.preventDefault();
  if (disabled) return;
  dragCounter--;
  if (dragCounter < 0) dragCounter = 0;
}

function ondrop(e: DragEvent): void {
  e.preventDefault();
  dragCounter = 0;
  if (disabled) return;
  const files = Array.from(e.dataTransfer?.files ?? []);
  if (files.length > 0) void processFiles(files);
}

function onpaste(e: ClipboardEvent): void {
  if (disabled) return;
  const items = e.clipboardData?.items ?? [];
  const files: File[] = [];
  for (const item of items) {
    if (item.kind === 'file') {
      const f = item.getAsFile();
      if (f) files.push(f);
    }
  }
  if (files.length > 0) {
    e.preventDefault();
    void processFiles(files);
  }
}
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="az-root"
  class:az-root--dragging={isDragging}
  {ondragenter}
  {ondragover}
  {ondragleave}
  {ondrop}
  {onpaste}
>
  {@render children()}
  {#if isDragging}
    <div class="az-overlay" aria-hidden="true">
      <Upload size={22} aria-hidden="true" />
      <span>Drop files here</span>
    </div>
  {/if}
</div>

<style>
  .az-root {
    position: relative;
  }

  .az-root--dragging {
    outline: 2px dashed color-mix(in oklch, var(--cnp-accent, #6366f1) 70%, transparent);
    outline-offset: -2px;
    border-radius: var(--radius-lg, 12px);
  }

  .az-overlay {
    position: absolute;
    inset: 0;
    z-index: 20;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    background: color-mix(in oklch, var(--bg, #0a0a0a) 88%, var(--cnp-accent, #6366f1));
    border-radius: var(--radius-lg, 12px);
    font-family: var(--font-sans);
    font-size: 13px;
    font-weight: 500;
    color: var(--cnp-accent, #6366f1);
    pointer-events: none;
    opacity: 1;
    transition: opacity 150ms ease-out;
  }
</style>
