<script lang="ts">
  /**
   * ProjectExplorerSection — workspace file tree with lazy-loaded children.
   * CSS prefix: brl-explorer-.
   *
   * Source: GET /api/v1/workspaces/:slug/files (top level) + per-folder
   * lazy listing on expand. Renders the shared FileTree foundation primitive.
   *
   * Double-click on a file → opens a FileViewerPane in the active Mosaic tile
   * (delegates to mosaicLayout.openPane). Drag a file → emits a drag payload
   * that consumers (e.g. mosaic tiles) can drop to open.
   *
   * NOTE: tree rendering is now sourced from
   * `$lib/design/foundation/file-tree`. The /files page uses the same
   * primitive — single source of truth.
   *
   * LOC target: ≤ 200.
   */
  import { createMutation, useQueryClient } from "@tanstack/svelte-query";
  import { FolderEdit } from "lucide-svelte";
  import FileTree from "$lib/design/foundation/file-tree/FileTree.svelte";
  import { updateWorkspaceMutation } from "$lib/api/queries/workspaces.js";
  import type { DirEntry } from "$lib/domain/workspaces/types.js";
  import { mosaicLayout, type Pane } from "$lib/stores/mosaic-layout.svelte.js";
  import { activeWorkspace } from "$lib/stores/active-workspace.svelte.js";
  import { toasts } from "$lib/stores/toasts.svelte.js";
  import { getTauriDialog } from "$lib/tauri/index.js";

  interface Props {
    workspaceSlug: string;
  }

  let { workspaceSlug }: Props = $props();

  const queryClient = useQueryClient();

  // Detect a "not_found" or missing root_path that needs user action.
  const needsFolderPick = $derived(
    !activeWorkspace.rootPath ||
      activeWorkspace.rootPath === "not_found" ||
      activeWorkspace.slug !== workspaceSlug,
  );

  // ── Folder picker mutation ─────────────────────────────────────────────────
  const updateMut = createMutation(updateWorkspaceMutation());

  let isPicking = $state(false);
  let pickError = $state<string | null>(null);

  async function pickFolder(): Promise<void> {
    pickError = null;
    isPicking = true;
    try {
      const { open: openDialog } = await getTauriDialog();
      const result = await openDialog({
        directory: true,
        multiple: false,
        title: "Choose workspace folder",
      });

      if (typeof result === "string" && result.length > 0) {
        await $updateMut.mutateAsync({
          slug: workspaceSlug,
          body: { rootPath: result },
        });

        // Refresh the store's rootPath so the tree renders immediately.
        activeWorkspace.rootPath = result;

        // Invalidate directory listing so FileTree refetches from new root.
        await queryClient.invalidateQueries({
          queryKey: ["build-rail", "directory", workspaceSlug],
        });

        toasts.success(`Workspace folder set to ${result}`);
      }
    } catch (err) {
      pickError =
        err instanceof Error ? err.message : "Could not set workspace folder.";
    } finally {
      isPicking = false;
    }
  }

  // ── Open a file in a Mosaic pane ───────────────────────────────────────────
  function openFile(entry: DirEntry): void {
    if (entry.isDir) return;
    const pane: Pane = {
      id: Math.random().toString(36).slice(2, 9),
      kind: "file",
      // Encode workspace + path so a "file_viewer"-aware dispatcher can parse.
      ref: `path:${workspaceSlug}:${entry.path}`,
      title: entry.name,
    };
    mosaicLayout.openPane(pane);
  }

  // ── Drag start: serialize a payload that drop targets can decode ───────────
  function handleDragStart(entry: DirEntry, ev: DragEvent): void {
    if (!ev.dataTransfer) return;
    const payload = {
      kind: "build-rail/file",
      workspaceSlug,
      path: entry.path,
      name: entry.name,
    };
    ev.dataTransfer.setData("application/x-canopy-rail", JSON.stringify(payload));
    ev.dataTransfer.setData("text/plain", entry.path);
    ev.dataTransfer.effectAllowed = "copyMove";
  }
</script>

<div class="brl-explorer">
  <header class="brl-explorer__header">
    <span class="brl-explorer__title">Project</span>
    <span class="brl-explorer__slug" title={workspaceSlug}>{workspaceSlug}</span>
    <button
      type="button"
      class="brl-explorer__switch-btn"
      aria-label="Switch workspace folder"
      title="Switch folder"
      onclick={pickFolder}
      disabled={isPicking}
    >
      <FolderEdit size={12} aria-hidden="true" />
    </button>
  </header>

  <div class="brl-explorer__body">
    {#if needsFolderPick}
      <div class="brl-explorer__empty-state" role="status">
        <span class="brl-explorer__empty-msg">No folder linked to this workspace.</span>
        <button
          type="button"
          class="brl-explorer__pick-btn"
          onclick={pickFolder}
          disabled={isPicking}
        >
          {isPicking ? "Opening…" : "Pick folder"}
        </button>
        {#if pickError}
          <span class="brl-explorer__error" role="alert">{pickError}</span>
        {/if}
      </div>
    {:else}
      {#if pickError}
        <span class="brl-explorer__error" role="alert">{pickError}</span>
      {/if}
      <FileTree
        {workspaceSlug}
        onFileSelect={openFile}
        onDragStart={handleDragStart}
        hideHidden={true}
      />
    {/if}
  </div>
</div>

<style>
  .brl-explorer {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  .brl-explorer__header {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: var(--space-2);
    padding: 10px var(--space-3) 6px;
    border-bottom: 1px solid var(--border, rgba(0, 0, 0, 0.08));
  }

  .brl-explorer__title {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    color: var(--fg-muted);
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }

  .brl-explorer__slug {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-subtle);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex: 1;
    max-width: 60%;
  }

  .brl-explorer__switch-btn {
    flex-shrink: 0;
    background: transparent;
    border: none;
    color: var(--fg-subtle);
    cursor: pointer;
    padding: 2px;
    border-radius: var(--radius-sm, 3px);
    display: flex;
    align-items: center;
    line-height: 1;
  }

  .brl-explorer__switch-btn:hover:not(:disabled) {
    color: var(--fg-muted);
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
  }

  .brl-explorer__switch-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .brl-explorer__body {
    flex: 1;
    min-height: 0;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .brl-explorer__empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-6);
    text-align: center;
  }

  .brl-explorer__empty-msg {
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--fg-subtle);
  }

  .brl-explorer__pick-btn {
    font-family: var(--font-sans);
    font-size: 12px;
    padding: 4px 12px;
    border-radius: var(--radius-md, 5px);
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-muted);
    cursor: pointer;
  }

  .brl-explorer__pick-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .brl-explorer__pick-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .brl-explorer__error {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--signal-error, #eb4335);
    text-align: center;
    padding: 0 var(--space-3);
  }
</style>
