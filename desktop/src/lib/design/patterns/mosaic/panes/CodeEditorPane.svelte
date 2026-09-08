<script lang="ts">
/**
 * CodeEditorPane — Code editor pane content for Mosaic.
 *
 * Today: textarea + Shiki overlay (read-only highlight) with ⌘S save and
 *        ⌘F find/replace. Lightweight, uses ONLY primitives that already
 *        exist in the repo (Shiki ^4.0.2, foundation/Button, foundation/Input).
 *
 * Future: swap the textarea for a CodeMirror 6 EditorView once
 *        @codemirror/* packages land (see wiring/code-editor-wiring.md).
 *        The save/dirty/state plumbing is identical either way — only the
 *        rendering layer changes.
 *
 * REUSES (no new fetcher / store / primitive created):
 *   - workspaceFileQuery / saveCodeFileMutation (queries/code-editor.ts)
 *   - fileQuery (queries/files.ts)
 *   - toasts (stores/toasts.svelte.ts)
 *   - foundation Button, Input, Textarea
 *   - Shiki dynamic-import pattern (matches DiffViewer.svelte)
 *
 * CSS prefix: cep- (Code Editor Pane).
 * LOC target: ≤ 360.
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { Save, Search, X } from 'lucide-svelte';
import { onMount, untrack } from 'svelte';
import { writable } from 'svelte/store';
import {
  codeEditorContentQuery,
  codeEditorMetadataQuery,
  isSaveable,
  saveCodeFileMutation,
} from '$lib/api/queries/code-editor.js';
import {
  type CodeEditorPaneConfig,
  type CodeEditorSaveResult,
  languageFromExtension,
} from '$lib/domain/code-editor/types.js';
import type { FileRecord } from '$lib/domain/files/types.js';
import type { FileReadResponse } from '$lib/domain/workspaces/types.js';
import { toasts } from '$lib/stores/toasts.svelte.js';
import {
  SHIKI_LANGUAGES_TO_PRELOAD,
  SHIKI_THEME,
  shikiLanguageFromExtension,
} from './code-editor/extensions.js';
import { CodeEditorSaveState } from './code-editor/save-state.svelte.js';

interface Props {
  fileId?: string;
  path?: string;
  workspaceSlug: string;
  /** Optional callback so MosaicTile can reflect dirty state in the pane title. */
  onDirtyChange?: (isDirty: boolean) => void;
}

let { fileId, path, workspaceSlug, onDirtyChange }: Props = $props();

const config = $derived<CodeEditorPaneConfig>({
  fileId,
  workspaceSlug,
  path,
});

// ── Resolve metadata (when addressed by fileId) ─────────────────────────────

const metaOptsStore = writable(
  untrack(() =>
    fileId
      ? (codeEditorMetadataQuery(fileId) as CreateQueryOptions<FileRecord>)
      : ({
          queryKey: ['code-editor', 'no-file'],
          queryFn: async () => null,
          enabled: false,
        } as unknown as CreateQueryOptions<FileRecord>)
  )
);
$effect(() => {
  if (fileId) {
    metaOptsStore.set(codeEditorMetadataQuery(fileId) as CreateQueryOptions<FileRecord>);
  }
});
const metaQ = createQuery<FileRecord>(metaOptsStore);
const fileMeta = $derived($metaQ.data as FileRecord | undefined);

// ── Resolve text content via the workspace-scoped read endpoint ────────────

const resolvedSlug = $derived(workspaceSlug);
const resolvedPath = $derived(path ?? fileMeta?.path ?? '');

const contentOptsStore = writable(
  untrack(() =>
    resolvedSlug && resolvedPath
      ? (codeEditorContentQuery(resolvedSlug, resolvedPath) as CreateQueryOptions<FileReadResponse>)
      : ({
          queryKey: ['code-editor', 'no-content'],
          queryFn: async () => null,
          enabled: false,
        } as unknown as CreateQueryOptions<FileReadResponse>)
  )
);
$effect(() => {
  if (resolvedSlug && resolvedPath) {
    contentOptsStore.set(
      codeEditorContentQuery(resolvedSlug, resolvedPath) as CreateQueryOptions<FileReadResponse>
    );
  }
});
const contentQ = createQuery<FileReadResponse>(contentOptsStore);

// The backend returns `{path, content}` (singular); the workspaces TS layer
// declares `contents` (plural). Read both defensively until they reconcile.
const remoteContent = $derived(
  (() => {
    const data = $contentQ.data as (FileReadResponse & { content?: string }) | undefined;
    if (!data) return null;
    if (typeof data.contents === 'string') return data.contents;
    if (typeof data.content === 'string') return data.content;
    return '';
  })()
);

// ── Save state (dirty tracking + last-saved baseline) ──────────────────────

const saveState = new CodeEditorSaveState('');

$effect(() => {
  if (remoteContent !== null) {
    // Reset baseline + draft when freshly fetched content arrives.
    saveState.loadFromRemote(remoteContent);
  }
});

$effect(() => {
  onDirtyChange?.(saveState.isDirty);
});

// ── Save mutation ──────────────────────────────────────────────────────────

const queryClient = useQueryClient();
const saveMut = createMutation<CodeEditorSaveResult, Error, { path: string; content: string }>(
  saveCodeFileMutation(workspaceSlug) as CreateMutationOptions<
    CodeEditorSaveResult,
    Error,
    { path: string; content: string }
  >
);

function triggerSave(): void {
  if (!isSaveable(config)) {
    toasts.error('Cannot save — pane is missing workspace + path.');
    return;
  }
  if (!saveState.isDirty) return;

  const sentContent = saveState.draft;
  const targetPath = resolvedPath;

  // Optimistic baseline update — flip clean immediately so the UI reflects
  // the user's intent. Roll back if the network call fails.
  const previousBaseline = saveState.baseline;
  saveState.markSaved(sentContent);

  $saveMut.mutate(
    { path: targetPath, content: sentContent },
    {
      onSuccess: () => {
        // Invalidate the read cache so next mount shows the latest content.
        queryClient.invalidateQueries({
          queryKey: ['workspaces', workspaceSlug, 'file', targetPath],
        });
        toasts.success(`Saved ${targetPath}`);
      },
      onError: (err: Error) => {
        // Rollback the baseline so the dirty indicator + warning come back.
        saveState.baseline = previousBaseline;
        toasts.error(`Save failed: ${err.message}`);
      },
    }
  );
}

// ── Keyboard handling: ⌘S save, ⌘F find ───────────────────────────────────

let findOpen = $state(false);
let findQuery = $state('');
let replaceWith = $state('');
let editorRef = $state<HTMLTextAreaElement | undefined>();

function handleKeydown(e: KeyboardEvent): void {
  const mod = e.metaKey || e.ctrlKey;
  if (!mod) return;
  if (e.key === 's' || e.key === 'S') {
    e.preventDefault();
    triggerSave();
  } else if (e.key === 'f' || e.key === 'F') {
    e.preventDefault();
    findOpen = true;
  }
}

function closeFind(): void {
  findOpen = false;
  findQuery = '';
  replaceWith = '';
  editorRef?.focus();
}

function findNext(): void {
  if (!editorRef || !findQuery) return;
  const text = saveState.draft;
  const startFrom = editorRef.selectionEnd ?? 0;
  const nextIdx = text.indexOf(findQuery, startFrom);
  const idx = nextIdx >= 0 ? nextIdx : text.indexOf(findQuery);
  if (idx < 0) {
    toasts.info(`No match for "${findQuery}"`);
    return;
  }
  editorRef.focus();
  editorRef.setSelectionRange(idx, idx + findQuery.length);
}

function replaceAll(): void {
  if (!findQuery) return;
  const before = saveState.draft;
  if (!before.includes(findQuery)) {
    toasts.info(`No match for "${findQuery}"`);
    return;
  }
  saveState.setDraft(before.split(findQuery).join(replaceWith));
  toasts.success(`Replaced all occurrences of "${findQuery}"`);
}

// ── Shiki overlay (read-only highlight on top of textarea) ─────────────────

let highlightedHtml = $state('');
let shikiReady = $state(false);
let highlighter: {
  codeToHtml: (s: string, opts: { lang: string; theme: string }) => string;
} | null = null;

const language = $derived(
  languageFromExtension(fileMeta?.extension ?? extensionFromPath(resolvedPath))
);
const shikiLang = $derived(
  shikiLanguageFromExtension(fileMeta?.extension ?? extensionFromPath(resolvedPath))
);

function extensionFromPath(p: string | undefined): string | null {
  if (!p) return null;
  const dot = p.lastIndexOf('.');
  if (dot < 0 || dot === p.length - 1) return null;
  return p.slice(dot + 1);
}

onMount(async () => {
  try {
    const { createHighlighter } = await import('shiki');
    highlighter = await createHighlighter({
      themes: [SHIKI_THEME],
      langs: SHIKI_LANGUAGES_TO_PRELOAD,
    });
    shikiReady = true;
  } catch {
    // Shiki failed — overlay stays empty, textarea still usable.
  }
});

$effect(() => {
  if (!shikiReady || !highlighter) return;
  const draft = saveState.draft;
  try {
    const html = highlighter.codeToHtml(draft, { lang: shikiLang, theme: SHIKI_THEME });
    // Strip the outer <pre><code> so we can layer it visually under the textarea.
    highlightedHtml = html.replace(/^<pre[^>]*><code[^>]*>([\s\S]*)<\/code><\/pre>$/, '$1');
  } catch {
    highlightedHtml = '';
  }
});

// ── Loading + error states ─────────────────────────────────────────────────

const isLoading = $derived(($contentQ.isLoading || (fileId && $metaQ.isLoading)) as boolean);
const loadError = $derived(
  ($contentQ.error?.message ?? $metaQ.error?.message ?? null) as string | null
);

// ── Pane title for the host (MosaicTile reads onDirtyChange separately) ───

const titlePath = $derived(resolvedPath || (fileId ? `file:${fileId}` : 'Untitled'));
</script>

<svelte:window onkeydown={(e) => {
  // Only respond when our editor or its toolbar has focus inside this pane.
  if (!(e.target instanceof Element)) return;
  if (!e.target.closest('.cep-root')) return;
  handleKeydown(e);
}} />

<div class="cep-root" role="region" aria-label="Code editor for {titlePath}">
  <!-- Toolbar -->
  <div class="cep-toolbar">
    <span class="cep-path" title={titlePath}>
      {#if saveState.isDirty}<span class="cep-dirty" aria-label="Unsaved changes">•</span>{/if}
      {titlePath}
    </span>
    <span class="cep-lang">{language}</span>
    <button
      type="button"
      class="cep-toolbtn"
      onclick={() => { findOpen = !findOpen; }}
      aria-label="Toggle find bar (⌘F)"
      aria-pressed={findOpen}
    >
      <Search size={14} aria-hidden="true" />
    </button>
    <button
      type="button"
      class="cep-toolbtn cep-toolbtn--primary"
      onclick={triggerSave}
      disabled={!saveState.isDirty || $saveMut.isPending}
      aria-label="Save (⌘S)"
    >
      <Save size={14} aria-hidden="true" />
      <span>{$saveMut.isPending ? 'Saving…' : 'Save'}</span>
    </button>
  </div>

  <!-- Find/replace bar -->
  {#if findOpen}
    <div class="cep-findbar" role="search">
      <input
        class="cep-findinput"
        type="text"
        placeholder="Find"
        bind:value={findQuery}
        onkeydown={(e) => { if (e.key === 'Enter') { e.preventDefault(); findNext(); } if (e.key === 'Escape') { e.preventDefault(); closeFind(); } }}
        aria-label="Find"
      />
      <input
        class="cep-findinput"
        type="text"
        placeholder="Replace with"
        bind:value={replaceWith}
        aria-label="Replace with"
      />
      <button type="button" class="cep-toolbtn" onclick={findNext} aria-label="Find next">Next</button>
      <button type="button" class="cep-toolbtn" onclick={replaceAll} aria-label="Replace all">Replace all</button>
      <button type="button" class="cep-toolbtn cep-toolbtn--icon" onclick={closeFind} aria-label="Close find">
        <X size={14} aria-hidden="true" />
      </button>
    </div>
  {/if}

  <!-- Body -->
  {#if isLoading}
    <div class="cep-status" role="status" aria-live="polite">Loading…</div>
  {:else if loadError}
    <div class="cep-status cep-status--error" role="alert">Failed to load: {loadError}</div>
  {:else}
    <div class="cep-editor-frame">
      <!-- Read-only Shiki overlay (visual layer; pointer-events: none) -->
      <pre class="cep-highlight" aria-hidden="true">{@html highlightedHtml}</pre>
      <!-- Editable textarea (TODO: replace with CodeMirror EditorView once @codemirror/* is installed) -->
      <textarea
        bind:this={editorRef}
        class="cep-textarea"
        value={saveState.draft}
        oninput={(e) => saveState.setDraft((e.currentTarget as HTMLTextAreaElement).value)}
        spellcheck="false"
        autocapitalize="off"
        wrap="off"
        aria-label="Code editor"
        data-language={language}
      ></textarea>
    </div>
  {/if}
</div>

<style>
  .cep-root {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-height: 0;
    height: 100%;
    background: var(--bg, oklch(0.18 0.01 250));
    font-family: var(--font-mono);
    color: var(--fg);
  }

  .cep-toolbar {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 10px;
    border-bottom: 1px solid var(--border);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    flex-shrink: 0;
  }

  .cep-path {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    color: var(--fg-muted);
  }

  .cep-dirty {
    color: var(--cnp-accent, oklch(0.72 0.18 145));
    font-weight: 700;
    margin-right: 4px;
  }

  .cep-lang {
    text-transform: uppercase;
    letter-spacing: 0.04em;
    font-size: 10px;
    color: var(--fg-subtle);
    padding: 2px 6px;
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, var(--fg) 6%, transparent);
  }

  .cep-toolbtn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 4px 10px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    cursor: pointer;
    transition: background 0.1s ease, color 0.1s ease;
  }
  .cep-toolbtn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg);
  }
  .cep-toolbtn:disabled { opacity: 0.5; cursor: not-allowed; }

  .cep-toolbtn--primary {
    background: var(--cnp-accent, oklch(0.72 0.18 145));
    color: oklch(100% 0 0);
    border-color: transparent;
  }
  .cep-toolbtn--primary:hover:not(:disabled) {
    background: color-mix(in oklch, var(--cnp-accent) 85%, oklch(0% 0 0) 15%);
    color: oklch(100% 0 0);
  }
  .cep-toolbtn--icon { padding: 4px; }

  .cep-findbar {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 10px;
    border-bottom: 1px solid var(--border);
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    flex-shrink: 0;
  }

  .cep-findinput {
    flex: 1;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 4px 8px;
    font-size: var(--text-xs);
    font-family: var(--font-mono);
    color: var(--fg);
    outline: none;
  }
  .cep-findinput:focus {
    border-color: var(--cnp-accent, oklch(0.72 0.18 145));
  }

  .cep-status {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: var(--space-6, 24px);
    color: var(--fg-subtle);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
  }
  .cep-status--error { color: oklch(0.65 0.22 25); }

  /* Editor frame — Shiki layer + textarea, perfectly aligned. */
  .cep-editor-frame {
    position: relative;
    flex: 1;
    min-height: 0;
    overflow: hidden;
  }

  .cep-highlight,
  .cep-textarea {
    position: absolute;
    inset: 0;
    margin: 0;
    padding: 12px 16px;
    font-family: var(--font-mono, ui-monospace, SFMono-Regular, monospace);
    font-size: 13px;
    line-height: 1.55;
    tab-size: 2;
    white-space: pre;
    word-wrap: normal;
    overflow: auto;
    border: none;
    box-sizing: border-box;
  }

  .cep-highlight {
    pointer-events: none;
    color: var(--fg);
    z-index: 1;
  }

  .cep-textarea {
    background: transparent;
    color: transparent;
    caret-color: var(--cnp-accent, oklch(0.72 0.18 145));
    z-index: 2;
    resize: none;
    outline: none;
  }
  .cep-textarea::selection {
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 35%, transparent);
  }

  /* Fallback when Shiki isn't ready yet — show actual text in the textarea. */
  .cep-highlight:empty + .cep-textarea {
    color: var(--fg);
  }
</style>
