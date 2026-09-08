<script lang="ts">
/**
 * /files — Project explorer for the active workspace.
 *
 * Layout (2 columns):
 *
 *   ┌─────────────────┬─────────────────────────────────────┐
 *   │ Workspaces list │ breadcrumb / search / new / refresh │
 *   │ (FilesWorkspace ├─────────────────────────────────────┤
 *   │  Picker)        │ <FileTree>                          │
 *   │                 ├─────────────────────────────────────┤
 *   │                 │ <FileViewerPane> (when file picked) │
 *   └─────────────────┴─────────────────────────────────────┘
 *
 * Reuses:
 *   • FileTree foundation primitive — `$lib/design/foundation/file-tree`
 *   • FileViewerPane mosaic primitive — `$lib/design/patterns/mosaic/panes`
 *   • activeWorkspace singleton — `$lib/stores/active-workspace.svelte`
 *   • useWorkspaceState hook — persists per-workspace expanded paths
 *
 * NOT a bucket-style upload UI — that was the old /files. See
 * `wiring/files-explorer-rebuild-wiring.md`.
 *
 * CSS prefix: fexp- (Files Explorer Page)
 * LOC target: ≤ 350
 */
import { ChevronRight, FolderOpen, Plus, RefreshCw, X } from 'lucide-svelte';
import { goto } from '$app/navigation';
import { uploadFile } from '$lib/api/queries/files.js';
import { useWorkspaceState } from '$lib/api/queries/workspace-states.js';
import FileTree from '$lib/design/foundation/file-tree/FileTree.svelte';
import { toast } from '$lib/design/foundation/toast/toast.js';
import FileSearchBar from '$lib/design/patterns/files/FileSearchBar.svelte';
import FilesWorkspacePicker from '$lib/design/patterns/files/FilesWorkspacePicker.svelte';
import FileViewerPane from '$lib/design/patterns/mosaic/panes/FileViewerPane.svelte';
import type { FileViewerPaneConfig } from '$lib/domain/file-viewer/types.js';
import type { DirEntry } from '$lib/domain/workspaces/types.js';
import { activeWorkspace } from '$lib/stores/active-workspace.svelte.js';

// ── Active workspace plumbing ─────────────────────────────────────────────
const slug = $derived(activeWorkspace.slug);
const name = $derived(activeWorkspace.name);
const rootPath = $derived(activeWorkspace.rootPath);

// ── Per-workspace persisted UI state (expanded folder paths) ──────────────
// Keyed under "files.expandedPaths" so reopening /files restores the tree.
const expanded = useWorkspaceState<string[]>('files.expandedPaths', []);

function handleFolderToggle(path: string, willBeExpanded: boolean): void {
  const current = expanded.value ?? [];
  const next = willBeExpanded
    ? Array.from(new Set([...current, path]))
    : current.filter((p) => p !== path);
  expanded.set(next);
}

// ── Selected file (drives the preview pane) ───────────────────────────────
let selectedEntry = $state<DirEntry | null>(null);

const previewConfig = $derived<FileViewerPaneConfig | null>(
  selectedEntry && slug ? { workspaceSlug: slug, path: selectedEntry.path } : null
);

function handleFileSelect(entry: DirEntry): void {
  selectedEntry = entry;
}

// ── Tree refresh ──────────────────────────────────────────────────────────
// The FileTree primitive exposes `refresh()` and `clearSelection()` as
// imperative methods accessible via `bind:this`. We type as `unknown`
// and narrow at call-site so a Svelte version bump can't break this.
type TreeHandle = { refresh: () => void; clearSelection: () => void };
let treeRef = $state<TreeHandle | null>(null);

function handleRefresh(): void {
  if (treeRef) {
    treeRef.refresh();
    toast.info('Refreshed', 'File tree reloaded from disk.');
  }
}

// ── New file modal ────────────────────────────────────────────────────────
let newFileOpen = $state(false);
let newFilename = $state('');
let newFileError = $state<string | null>(null);
let isCreating = $state(false);

function handleNewFile(): void {
  newFilename = '';
  newFileError = null;
  newFileOpen = true;
}

function closeNewFileModal(): void {
  newFileOpen = false;
  newFilename = '';
  newFileError = null;
}

async function submitNewFile(): Promise<void> {
  const name = newFilename.trim();
  if (!name || !slug) return;

  isCreating = true;
  newFileError = null;

  try {
    // Build the path: if a file is currently selected, create in its parent
    // directory; otherwise create at the workspace root.
    const dir = selectedEntry ? selectedEntry.path.split('/').slice(0, -1).join('/') : '';
    const path = dir ? `${dir}/${name}` : name;

    await uploadFile({
      workspaceSlug: slug,
      path,
      file: new File([''], name),
    });

    toast.success('File created', path);
    closeNewFileModal();
    treeRef?.refresh();
  } catch (err) {
    newFileError = err instanceof Error ? err.message : 'Failed to create file';
  } finally {
    isCreating = false;
  }
}

// ── Breadcrumb segments derived from the selected entry's path ────────────
function pathSegments(p: string): { label: string; path: string }[] {
  if (!p) return [];
  const parts = p.split('/').filter(Boolean);
  return parts.map((label, i) => ({
    label,
    path: parts.slice(0, i + 1).join('/'),
  }));
}

const breadcrumb = $derived(selectedEntry ? pathSegments(selectedEntry.path) : []);
</script>

<div class="fexp">
  <!-- Left pane: workspaces -->
  <FilesWorkspacePicker />

  <!-- Right pane: project explorer -->
  <main class="fexp__main">
    {#if !slug}
      <!-- No workspace active — show a graceful empty state. -->
      <div class="fexp__no-ws">
        <FolderOpen size={32} aria-hidden="true" />
        <h2 class="fexp__no-ws-title">No workspace active</h2>
        <p class="fexp__no-ws-body">
          Pick a workspace from the left, or create a new one.
        </p>
        <button
          type="button"
          class="fexp__new-cta"
          onclick={() => goto("/workspaces?new=true")}
        >
          <Plus size={13} aria-hidden="true" />
          New workspace
        </button>
      </div>
    {:else}
      <!-- Top bar: breadcrumb + search + actions -->
      <header class="fexp__topbar">
        <nav class="fexp__crumbs" aria-label="Selected file path">
          <span class="fexp__crumb fexp__crumb--root" title={rootPath ?? ""}>
            {name ?? slug}
          </span>
          {#if rootPath}
            <span class="fexp__crumb-path" title={rootPath}>{rootPath}</span>
          {/if}
          {#each breadcrumb as seg, i (seg.path)}
            <span class="fexp__crumb-sep" aria-hidden="true">
              <ChevronRight size={12} />
            </span>
            <span
              class="fexp__crumb"
              class:fexp__crumb--active={i === breadcrumb.length - 1}
            >
              {seg.label}
            </span>
          {/each}
        </nav>

        <div class="fexp__search">
          <FileSearchBar workspaceSlug={slug} />
        </div>

        <div class="fexp__actions">
          <button
            type="button"
            class="fexp__btn"
            onclick={handleNewFile}
            aria-label="Create new file"
            title="New file"
          >
            <Plus size={12} aria-hidden="true" />
            <span>New</span>
          </button>
          <button
            type="button"
            class="fexp__btn fexp__btn--icon"
            onclick={handleRefresh}
            aria-label="Refresh file tree"
            title="Refresh tree"
          >
            <RefreshCw size={12} aria-hidden="true" />
          </button>
        </div>
      </header>

      <!-- Tree + preview (vertical split) -->
      <div class="fexp__split">
        <section class="fexp__tree" aria-label="File tree">
          {#key slug}
            <FileTree
              bind:this={treeRef}
              workspaceSlug={slug}
              onFileSelect={handleFileSelect}
              onFolderToggle={handleFolderToggle}
              initialExpanded={expanded.value ?? []}
              initialSelected={selectedEntry?.path ?? null}
              hideHidden={true}
            />
          {/key}
        </section>

        <section class="fexp__preview" aria-label="File preview">
          {#if previewConfig}
            <header class="fexp__preview-header">
              <span class="fexp__preview-name">
                {selectedEntry?.name ?? ""}
              </span>
              <span class="fexp__preview-path" title={selectedEntry?.path ?? ""}>
                {selectedEntry?.path ?? ""}
              </span>
            </header>
            <div class="fexp__preview-body">
              {#key `${slug}:${selectedEntry?.path}`}
                <FileViewerPane config={previewConfig} />
              {/key}
            </div>
          {:else}
            <div class="fexp__preview-empty">
              <p class="fexp__preview-empty-title">No file selected</p>
              <p class="fexp__preview-empty-body">
                Click a file in the tree above to preview it here.
              </p>
            </div>
          {/if}
        </section>
      </div>
    {/if}
  </main>
</div>

<!-- New file modal -->
{#if newFileOpen}
  <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
  <div
    class="fexp-overlay"
    role="dialog"
    aria-modal="true"
    aria-label="Create new file"
    onkeydown={(e) => { if (e.key === 'Escape') closeNewFileModal(); }}
  >
    <div class="fexp-modal">
      <div class="fexp-modal__head">
        <span class="fexp-modal__label">New File</span>
        <button
          class="fexp-modal__close"
          onclick={closeNewFileModal}
          aria-label="Close"
        >
          <X size={14} aria-hidden="true" />
        </button>
      </div>

      <div class="fexp-modal__body">
        <label class="fexp-field">
          <span class="fexp-field__label">Filename</span>
          <input
            class="fexp-input"
            type="text"
            placeholder="e.g. notes.md"
            bind:value={newFilename}
            aria-required="true"
            onkeydown={(e) => { if (e.key === 'Enter') submitNewFile(); }}
            autofocus
          />
        </label>

        {#if selectedEntry}
          <p class="fexp-modal__hint">
            Will be created in:
            <code>{selectedEntry.path.split("/").slice(0, -1).join("/") || "/"}</code>
          </p>
        {/if}

        {#if newFileError}
          <p class="fexp-modal__error">{newFileError}</p>
        {/if}
      </div>

      <div class="fexp-modal__foot">
        <button
          class="fexp-btn fexp-btn--ghost"
          onclick={closeNewFileModal}
          disabled={isCreating}
        >
          Cancel
        </button>
        <button
          class="fexp-btn fexp-btn--primary"
          onclick={submitNewFile}
          disabled={isCreating || !newFilename.trim()}
        >
          {isCreating ? "Creating..." : "Create"}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .fexp {
    display: flex;
    height: 100%;
    overflow: hidden;
  }

  .fexp__main {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    min-width: 0;
  }

  /* ── No workspace state ── */
  .fexp__no-ws {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--space-3);
    padding: var(--space-8);
    text-align: center;
    color: var(--fg-subtle);
  }

  .fexp__no-ws-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-base);
    color: var(--fg);
    font-weight: 500;
  }

  .fexp__no-ws-body {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    max-width: 320px;
    line-height: 1.6;
  }

  .fexp__new-cta {
    display: inline-flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    background: var(--cnp-accent, #6e8df1);
    color: white;
    border: none;
    border-radius: var(--radius-sm);
    font-family: var(--font-sans);
    font-size: 13px;
    cursor: pointer;
    transition: opacity 80ms ease-out;
  }

  .fexp__new-cta:hover {
    opacity: 0.9;
  }

  /* ── Top bar ── */
  .fexp__topbar {
    display: grid;
    grid-template-columns: 1fr minmax(0, 360px) auto;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-4);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .fexp__crumbs {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    min-width: 0;
    overflow: hidden;
  }

  .fexp__crumb {
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--fg-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 200px;
  }

  .fexp__crumb--root {
    color: var(--fg);
    font-weight: 500;
  }

  .fexp__crumb--active {
    color: var(--fg);
    font-weight: 500;
  }

  .fexp__crumb-path {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-subtle);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 360px;
    margin-left: var(--space-2);
  }

  .fexp__crumb-sep {
    display: inline-flex;
    color: var(--fg-subtle);
  }

  .fexp__search {
    min-width: 0;
  }

  .fexp__actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
  }

  .fexp__btn {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    padding: 4px var(--space-2);
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: 12px;
    cursor: pointer;
    transition: all 80ms ease-out;
  }

  .fexp__btn:hover {
    background: var(--bg-inset);
    color: var(--fg);
  }

  .fexp__btn--icon {
    padding: 4px;
  }

  /* ── Split: tree (top) + preview (bottom) ── */
  .fexp__split {
    flex: 1;
    display: flex;
    flex-direction: column;
    min-height: 0;
    overflow: hidden;
  }

  .fexp__tree {
    flex: 1 1 50%;
    min-height: 200px;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .fexp__preview {
    flex: 1 1 50%;
    min-height: 200px;
    border-top: 1px solid var(--border);
    overflow: hidden;
    display: flex;
    flex-direction: column;
    background: var(--bg);
  }

  .fexp__preview-header {
    display: flex;
    align-items: baseline;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-4);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .fexp__preview-name {
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--fg);
    font-weight: 500;
  }

  .fexp__preview-path {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-subtle);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .fexp__preview-body {
    flex: 1;
    min-height: 0;
    overflow: hidden;
  }

  .fexp__preview-empty {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--space-2);
    padding: var(--space-6);
    text-align: center;
    color: var(--fg-subtle);
  }

  .fexp__preview-empty-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg-muted);
  }

  .fexp__preview-empty-body {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    max-width: 320px;
    line-height: 1.5;
  }

  /* ── New file modal ── */
  .fexp-overlay {
    position: fixed;
    inset: 0;
    background: color-mix(in oklch, var(--bg) 60%, transparent 40%);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 50;
    padding: var(--space-4);
  }

  .fexp-modal {
    background: var(--bg-elevated);
    border: 1px solid var(--border-strong);
    border-radius: var(--radius-xl);
    width: 100%;
    max-width: 360px;
    display: flex;
    flex-direction: column;
    box-shadow: 0 20px 60px color-mix(in oklch, var(--bg) 0%, transparent 70%);
  }

  .fexp-modal__head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-4) var(--space-5);
    border-bottom: 1px solid var(--border);
  }

  .fexp-modal__label {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
  }

  .fexp-modal__close {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    background: transparent;
    border: none;
    border-radius: var(--radius-sm);
    cursor: pointer;
    color: var(--fg-muted);
  }

  .fexp-modal__close:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .fexp-modal__body {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-5);
  }

  .fexp-modal__foot {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: var(--space-2);
    padding: var(--space-4) var(--space-5);
    border-top: 1px solid var(--border);
  }

  .fexp-modal__hint {
    margin: 0;
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
  }

  .fexp-modal__hint code {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-muted);
  }

  .fexp-modal__error {
    margin: 0;
    font-family: var(--font-sans);
    font-size: 12px;
    color: #f87171;
  }

  .fexp-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .fexp-field__label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    color: var(--fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .fexp-input {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-mono);
    font-size: 13px;
    color: var(--fg);
    outline: none;
    transition: border-color 80ms ease-out;
    width: 100%;
    box-sizing: border-box;
  }

  .fexp-input:focus {
    border-color: var(--border-strong);
  }

  .fexp-btn {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    padding: var(--space-2) var(--space-3);
    border-radius: var(--radius-md);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    cursor: pointer;
    transition: background 80ms ease-out, opacity 80ms ease-out;
    border: 1px solid transparent;
  }

  .fexp-btn:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .fexp-btn--ghost {
    background: transparent;
    border-color: var(--border);
    color: var(--fg-muted);
  }

  .fexp-btn--ghost:not(:disabled):hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .fexp-btn--primary {
    background: var(--cnp-accent, #6e8df1);
    border-color: var(--cnp-accent, #6e8df1);
    color: white;
  }

  .fexp-btn--primary:not(:disabled):hover {
    opacity: 0.9;
  }
</style>
