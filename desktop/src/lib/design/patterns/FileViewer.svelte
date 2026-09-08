<script lang="ts">
/**
 * FileViewer — read/edit files from a workspace.
 * Three rendering modes: markdown (split view), code (mono + line numbers), binary fallback.
 * Props: workspaceSlug, path.
 * CSS prefix: fv- (FileViewer)
 * LOC target: ≤ 350.
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { beforeNavigate } from '$app/navigation';
import { workspaceFileQuery, writeFileMutation } from '$lib/api/queries/workspaces.js';
import DirtyGuardModal from '$lib/design/patterns/DirtyGuardModal.svelte';
import type { FileReadResponse } from '$lib/domain/workspaces/types.js';
import { toasts } from '$lib/stores/toasts.svelte.js';
import { renderMarkdown } from '$lib/utils/markdown.js';

interface Props {
  workspaceSlug: string;
  path: string;
}

let { workspaceSlug, path }: Props = $props();

const queryClient = useQueryClient();

// ── Query (writable+untrack bridge for reactive props) ──────────────────────

const fileOptsStore = writable(
  untrack(() => workspaceFileQuery(workspaceSlug, path) as CreateQueryOptions<FileReadResponse>)
);

$effect(() => {
  fileOptsStore.set(
    workspaceFileQuery(workspaceSlug, path) as CreateQueryOptions<FileReadResponse>
  );
});

const fileQ = createQuery<FileReadResponse>(fileOptsStore);

// ── Mutation ────────────────────────────────────────────────────────────────

// Capture slug at construction time — mutation factory doesn't need reactivity.
const _slug = untrack(() => workspaceSlug);
const writeMut = createMutation<FileReadResponse, Error, { path: string; contents: string }>(
  writeFileMutation(_slug) as CreateMutationOptions<
    FileReadResponse,
    Error,
    { path: string; contents: string }
  >
);

// ── Edit state ──────────────────────────────────────────────────────────────

let editMode = $state(false);
let editedContents = $state('');

// Sync editedContents when query data arrives (and whenever path changes)
$effect(() => {
  const data = $fileQ.data;
  if (data) {
    editedContents = untrack(() => editedContents) || data.contents;
  }
});

// Reset edit state on path change
$effect(() => {
  // reactive on path
  void path;
  editMode = false;
  editedContents = '';
});

const isDirty = $derived(
  editedContents !== '' && $fileQ.data != null && editedContents !== $fileQ.data.contents
);

// ── File classification ─────────────────────────────────────────────────────

const CODE_EXTS = new Set([
  'ts',
  'js',
  'tsx',
  'jsx',
  'ex',
  'exs',
  'rs',
  'go',
  'py',
  'json',
  'yaml',
  'yml',
  'sh',
  'svelte',
  'css',
]);

const MARKDOWN_EXTS = new Set(['md', 'markdown']);

function extOf(p: string): string {
  const dot = p.lastIndexOf('.');
  return dot === -1 ? '' : p.slice(dot + 1).toLowerCase();
}

type FileMode = 'markdown' | 'code' | 'binary';

function classifyFile(p: string, contents: string): FileMode {
  const ext = extOf(p);
  if (MARKDOWN_EXTS.has(ext)) return 'markdown';
  if (CODE_EXTS.has(ext)) return 'code';
  // Heuristic: if file has no extension but looks textual, treat as code
  if (ext === '' && !hasBinaryChars(contents)) return 'code';
  if (CODE_EXTS.has(ext)) return 'code';
  return 'binary';
}

function hasBinaryChars(text: string): boolean {
  // Null bytes are the canonical binary signal
  return text.includes('\x00');
}

const fileMode = $derived<FileMode>(
  $fileQ.data ? classifyFile(path, $fileQ.data.contents) : 'code'
);

// ── Breadcrumb ──────────────────────────────────────────────────────────────

const breadcrumbs = $derived(path.split('/').filter((s) => s.length > 0));

// ── Formatted metadata ──────────────────────────────────────────────────────

function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function formatDate(iso: string | null): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleString(undefined, {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

// ── Line numbers for code view ──────────────────────────────────────────────

const codeLines = $derived((editMode ? editedContents : ($fileQ.data?.contents ?? '')).split('\n'));

// ── Markdown preview ────────────────────────────────────────────────────────

const markdownHtml = $derived(
  renderMarkdown(editMode ? editedContents : ($fileQ.data?.contents ?? ''))
);

// ── Save ────────────────────────────────────────────────────────────────────

function save(): void {
  if (!isDirty || $writeMut.isPending) return;
  $writeMut.mutate(
    { path, contents: editedContents },
    {
      onSuccess: () => {
        toasts.success('Saved');
        queryClient.invalidateQueries({ queryKey: ['workspaces', workspaceSlug, 'file', path] });
        queryClient.invalidateQueries({ queryKey: ['workspaces', workspaceSlug, 'tree'] });
        editMode = false;
      },
      onError: (err) => {
        toasts.error(`Save failed: ${err.message}`);
      },
    }
  );
}

// ── Keyboard shortcut (⌘S / Ctrl+S) ─────────────────────────────────────────

function handleKeydown(e: KeyboardEvent): void {
  if ((e.metaKey || e.ctrlKey) && e.key === 's') {
    e.preventDefault();
    save();
  }
}

// ── Unsaved-changes guard ───────────────────────────────────────────────────

let guardOpen = $state(false);
let bypassGuard = $state(false);
let pendingNavigation: (() => void) | null = null;

beforeNavigate(({ cancel, to }) => {
  if (isDirty && !bypassGuard) {
    cancel();
    pendingNavigation = () => {
      bypassGuard = true;
      if (to?.url) window.location.assign(to.url.href);
    };
    guardOpen = true;
  }
});

// beforeunload for hard reload / window close
$effect(() => {
  function handleBeforeUnload(e: BeforeUnloadEvent): string | undefined {
    if (isDirty) {
      e.preventDefault();
      return '';
    }
  }
  window.addEventListener('beforeunload', handleBeforeUnload);
  return () => window.removeEventListener('beforeunload', handleBeforeUnload);
});

// ── Toggle edit mode ────────────────────────────────────────────────────────

function toggleEdit(): void {
  if (!editMode) {
    editedContents = $fileQ.data?.contents ?? '';
  }
  editMode = !editMode;
}
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="fv-root" onkeydown={handleKeydown}>

  <!-- ── Header bar ──────────────────────────────────────────────────────── -->
  <header class="fv-header">
    <nav class="fv-breadcrumb" aria-label="File path">
      {#each breadcrumbs as crumb, idx (idx)}
        <span class="fv-crumb" aria-current={idx === breadcrumbs.length - 1 ? 'page' : undefined}>
          {crumb}
        </span>
        {#if idx < breadcrumbs.length - 1}
          <span class="fv-crumb-sep" aria-hidden="true">/</span>
        {/if}
      {/each}
    </nav>

    <div class="fv-meta">
      {#if $fileQ.data}
        <span class="fv-meta-item">{formatSize($fileQ.data.size)}</span>
        <span class="fv-meta-sep" aria-hidden="true">·</span>
        <span class="fv-meta-item">{formatDate($fileQ.data.modified)}</span>
      {/if}
    </div>

    <div class="fv-actions">
      {#if fileMode !== 'binary' && $fileQ.data}
        <button
          class="btn-rounded btn-rounded-secondary fv-btn-edit"
          onclick={toggleEdit}
          aria-pressed={editMode}
          aria-label={editMode ? 'Switch to preview' : 'Edit file'}
        >
          {editMode ? 'Preview' : 'Edit'}
        </button>
      {/if}
      <button
        class="btn-pill btn-pill-primary btn-pill-sm fv-btn-save"
        onclick={save}
        disabled={!isDirty || $writeMut.isPending}
        aria-label="Save file"
      >
        {$writeMut.isPending ? 'Saving…' : 'Save'}
      </button>
    </div>
  </header>

  <!-- ── Body ───────────────────────────────────────────────────────────── -->
  <div class="fv-body">

    {#if $fileQ.isPending}
      <!-- Loading skeleton -->
      <div class="fv-skeleton" role="status" aria-label="Loading file" aria-busy="true">
        {#each { length: 12 } as _, i (i)}
          <div
            class="fv-skeleton-line canopy-shim"
            style="width: {70 + ((i * 37) % 30)}%; animation-delay: {i * 40}ms;"
            aria-hidden="true"
          ></div>
        {/each}
      </div>

    {:else if $fileQ.isError}
      <div class="fv-error" role="alert">
        <span class="fv-error-icon" aria-hidden="true">✕</span>
        <span class="fv-error-msg">
          Failed to load file: {($fileQ.error as Error).message}
        </span>
        <button
          class="btn-pill btn-pill-sm btn-pill-secondary"
          onclick={() => $fileQ.refetch()}
        >
          Retry
        </button>
      </div>

    {:else if $fileQ.data}
      {#if fileMode === 'binary'}
        <!-- Binary fallback -->
        <div class="fv-binary" role="status">
          Cannot display — binary file ({formatSize($fileQ.data.size)})
        </div>

      {:else if fileMode === 'markdown'}
        <!-- Markdown: split view -->
        <div class="fv-markdown-split">
          <div class="fv-markdown-editor" aria-label="Markdown source">
            <textarea
              class="fv-textarea"
              bind:value={editedContents}
              readonly={!editMode}
              aria-label="Edit markdown source"
              spellcheck="false"
              onkeydown={handleKeydown}
            ></textarea>
          </div>
          <div class="fv-markdown-divider" aria-hidden="true"></div>
          <div
            class="fv-markdown-preview"
            role="region"
            aria-label="Markdown preview"
          >
            <!-- eslint-disable-next-line svelte/no-at-html-tags -->
            {@html markdownHtml}
          </div>
        </div>

      {:else}
        <!-- Code: line-numbered read view or textarea edit -->
        {#if editMode}
          <textarea
            class="fv-textarea fv-textarea--code"
            bind:value={editedContents}
            aria-label="Edit file"
            spellcheck="false"
            onkeydown={handleKeydown}
          ></textarea>
        {:else}
          <div class="fv-code-view" role="region" aria-label="File contents">
            <div class="fv-line-numbers" aria-hidden="true">
              {#each codeLines as _, idx (idx)}
                <span class="fv-ln">{idx + 1}</span>
              {/each}
            </div>
            <pre class="fv-code-pre"><code>{codeLines.join('\n')}</code></pre>
          </div>
        {/if}
      {/if}
    {/if}

  </div><!-- /fv-body -->
</div><!-- /fv-root -->

<DirtyGuardModal
  open={guardOpen}
  onCancel={() => { guardOpen = false; pendingNavigation = null; }}
  onDiscard={() => { guardOpen = false; pendingNavigation?.(); pendingNavigation = null; }}
/>

<style>
  /* ── Root layout ─────────────────────────────────────────────────────────── */
  .fv-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: var(--bg);
    overflow: hidden;
    font-family: var(--font-sans);
  }

  /* ── Header ──────────────────────────────────────────────────────────────── */
  .fv-header {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    padding: 0 var(--space-4);
    height: 40px;
    flex-shrink: 0;
    border-bottom: 1px solid var(--border);
    background: var(--bg-elevated);
  }

  .fv-breadcrumb {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    flex: 1;
    min-width: 0;
    overflow: hidden;
  }

  .fv-crumb {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .fv-crumb[aria-current='page'] {
    color: var(--fg);
    font-weight: 500;
  }

  .fv-crumb-sep {
    color: var(--fg-subtle);
    font-size: var(--text-xs);
    flex-shrink: 0;
  }

  .fv-meta {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
  }

  .fv-meta-item {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  .fv-meta-sep {
    color: var(--fg-subtle);
    font-size: var(--text-xs);
  }

  .fv-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
  }

  .fv-btn-edit {
    font-size: var(--text-xs);
    height: 26px;
    padding: 0 var(--space-3);
  }

  .fv-btn-save:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  /* ── Body ────────────────────────────────────────────────────────────────── */
  .fv-body {
    flex: 1;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  /* ── Skeleton ────────────────────────────────────────────────────────────── */
  .fv-skeleton {
    padding: var(--space-5);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .fv-skeleton-line {
    height: 13px;
    border-radius: 4px;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
  }

  /* ── Error ───────────────────────────────────────────────────────────────── */
  .fv-error {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-5);
    color: var(--signal-error);
    font-size: var(--text-sm);
  }

  .fv-error-icon {
    flex-shrink: 0;
  }

  .fv-error-msg {
    flex: 1;
    color: var(--fg-muted);
  }

  /* ── Binary ──────────────────────────────────────────────────────────────── */
  .fv-binary {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100%;
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    font-style: italic;
  }

  /* ── Markdown split ──────────────────────────────────────────────────────── */
  .fv-markdown-split {
    display: flex;
    height: 100%;
    overflow: hidden;
  }

  .fv-markdown-editor {
    flex: 1;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .fv-markdown-divider {
    width: 1px;
    background: var(--border);
    flex-shrink: 0;
  }

  .fv-markdown-preview {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-5);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
    font-size: var(--text-base);
    line-height: 1.7;
    color: var(--fg);
  }

  /* ── Textarea (shared for markdown + code edit) ──────────────────────────── */
  .fv-textarea {
    width: 100%;
    height: 100%;
    resize: none;
    border: none;
    outline: none;
    background: var(--bg-inset);
    color: var(--fg);
    font-family: var(--font-mono);
    font-size: 13px;
    line-height: 1.6;
    padding: var(--space-5);
    box-sizing: border-box;
    tab-size: 2;
  }

  .fv-textarea:read-only {
    background: var(--bg-inset);
    cursor: default;
  }

  .fv-textarea--code {
    flex: 1;
  }

  /* ── Code read view ──────────────────────────────────────────────────────── */
  .fv-code-view {
    display: flex;
    height: 100%;
    overflow: auto;
    background: var(--bg-inset);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .fv-line-numbers {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    padding: var(--space-5) var(--space-3) var(--space-5) var(--space-4);
    background: var(--bg-inset);
    border-right: 1px solid var(--border);
    user-select: none;
    flex-shrink: 0;
    min-width: 3rem;
  }

  .fv-ln {
    font-family: var(--font-mono);
    font-size: 12px;
    line-height: 1.6;
    color: var(--fg-subtle);
    display: block;
  }

  .fv-code-pre {
    margin: 0;
    padding: var(--space-5);
    font-family: var(--font-mono);
    font-size: 13px;
    line-height: 1.6;
    color: var(--fg);
    white-space: pre;
    overflow: visible;
    flex: 1;
  }

  .fv-code-pre code {
    font: inherit;
  }

  /* ── Markdown rendered styles ────────────────────────────────────────────── */
  :global(.fv-h1) {
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    margin: var(--space-5) 0 var(--space-3);
    line-height: 1.25;
    letter-spacing: -0.025em;
  }

  :global(.fv-h2) {
    font-family: var(--font-sans);
    font-size: var(--text-xl);
    font-weight: 600;
    color: var(--fg);
    margin: var(--space-4) 0 var(--space-2);
    line-height: 1.3;
  }

  :global(.fv-h3) {
    font-family: var(--font-sans);
    font-size: var(--text-lg);
    font-weight: 600;
    color: var(--fg);
    margin: var(--space-3) 0 var(--space-2);
  }

  :global(.fv-p) {
    margin: var(--space-2) 0;
    color: var(--fg-muted);
  }

  :global(.fv-ul),
  :global(.fv-ol) {
    margin: var(--space-2) 0;
    padding-left: var(--space-5);
    color: var(--fg-muted);
  }

  :global(.fv-ul li),
  :global(.fv-ol li) {
    margin: var(--space-1) 0;
  }

  :global(.fv-inline-code) {
    font-family: var(--font-mono);
    font-size: 0.88em;
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    border: 1px solid var(--border);
    border-radius: 4px;
    padding: 1px 5px;
    color: var(--fg);
  }

  :global(.fv-code-block) {
    margin: var(--space-3) 0;
    padding: var(--space-4);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow-x: auto;
    font-family: var(--font-mono);
    font-size: 13px;
    line-height: 1.6;
    color: var(--fg);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  :global(.fv-link) {
    color: var(--cnp-accent);
    text-decoration: underline;
    text-underline-offset: 2px;
    text-decoration-color: color-mix(in oklch, var(--cnp-accent) 50%, transparent 50%);
  }

  :global(.fv-link:hover) {
    text-decoration-color: var(--cnp-accent);
  }
</style>
