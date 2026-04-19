<script lang="ts">
/**
 * /files — Bucket-style file browser (Track #108).
 *
 * Layout:
 *   Left pane (≤260px): BUCKETS list = workspaces, quota display, + New Bucket
 *   Right pane (flex): breadcrumb + actions + search + file table + empty/drop zone
 *
 * Architecture notes:
 *   - Workspace = Bucket (no schema change — workspace_id scopes all files).
 *   - Folders are implicit: a file's `path` encodes its folder hierarchy.
 *   - Folder creation = upload a zero-byte Blob at {folderName}/.gitkeep.
 *   - Quota: used = sum(sizeBytes) for workspace; limit = 1 GB constant.
 *     TODO: wire per-workspace quota from backend when quota column lands.
 *
 * CSS prefix: fb- (FileBucket)
 * LOC target: ≤ 450
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from "@tanstack/svelte-query";
import { FileSearch, FolderOpen, RefreshCw } from "lucide-svelte";
import { untrack } from "svelte";
import { writable } from "svelte/store";
import { goto } from "$app/navigation";
import {
  filesQuery,
  fileIcon,
  formatBytes,
  scanWorkspaceMutation,
  searchFilesQuery,
  uploadFileMutation,
} from "$lib/api/queries/files.js";
import { workspacesQuery } from "$lib/api/queries/workspaces.js";
import EmptyState from "$lib/design/patterns/EmptyState.svelte";
import SkeletonList from "$lib/design/patterns/SkeletonList.svelte";
import { Table, TableHeader } from "$lib/design/foundation/table/index.js";
import type { FileRecord } from "$lib/domain/files/types.js";
import type { Workspace } from "$lib/domain/workspaces/types.js";
import { ui } from "$lib/stores/ui.svelte.js";

const QUOTA_BYTES = 1_073_741_824; // 1 GB — TODO: wire from backend quota column
const queryClient = useQueryClient();

// ── Workspaces (buckets) ─────────────────────────────────────────────────────

const workspacesOptsStore = writable(
  untrack(() => workspacesQuery() as CreateQueryOptions<Workspace[]>),
);
const workspacesQ = createQuery<Workspace[]>(workspacesOptsStore);
const workspaces = $derived(($workspacesQ.data ?? []) as Workspace[]);

const currentSlug = $derived(ui.currentWorkspaceSlug ?? "");
const currentWorkspace = $derived(workspaces.find((w) => w.slug === currentSlug) ?? null);

// ── Files for current workspace (all — used for quota + folder nav) ──────────

const allFilesOptsStore = writable(
  untrack(
    () =>
      filesQuery({ workspace: currentSlug || undefined }) as CreateQueryOptions<FileRecord[]>,
  ),
);
$effect(() => {
  allFilesOptsStore.set(
    filesQuery({ workspace: currentSlug || undefined }) as CreateQueryOptions<FileRecord[]>,
  );
});
const allFilesQ = createQuery<FileRecord[]>(allFilesOptsStore);
const allFiles = $derived(($allFilesQ.data ?? []) as FileRecord[]);

// Per-workspace used bytes (client-side sum for quota display)
const usedBytes = $derived(allFiles.reduce((acc, f) => acc + f.sizeBytes, 0));

// Per-workspace file counts for left-pane display
// Map<slug, { count, bytes }> — built from currently-loaded data only
const workspaceStats = $derived(() => {
  const map = new Map<string, { count: number; bytes: number }>();
  for (const f of allFiles) {
    const slug = workspaces.find((w) => w.id === f.workspaceId)?.slug ?? "";
    if (!slug) continue;
    const existing = map.get(slug) ?? { count: 0, bytes: 0 };
    map.set(slug, { count: existing.count + 1, bytes: existing.bytes + f.sizeBytes });
  }
  return map;
});

// ── Path navigation ───────────────────────────────────────────────────────────

let currentPath = $state(""); // "" = root

function pathSegments(p: string): { label: string; path: string }[] {
  if (!p) return [];
  const parts = p.split("/").filter(Boolean);
  return parts.map((label, i) => ({
    label,
    path: parts.slice(0, i + 1).join("/"),
  }));
}

// Files visible in current path (one level only — not recursive)
const visibleFiles = $derived(() => {
  if (isSearching) return searchedFiles;
  const prefix = currentPath ? `${currentPath}/` : "";
  return allFiles.filter((f) => {
    if (!f.path.startsWith(prefix)) return false;
    const remainder = f.path.slice(prefix.length);
    // exclude .gitkeep sentinel files from display
    if (remainder === ".gitkeep") return false;
    // only show direct children (no nested slash in remainder)
    return !remainder.slice(0, -1).includes("/") || remainder.endsWith("/.gitkeep");
  });
});

// Derive unique subfolder names at current level
const subfolders = $derived(() => {
  const prefix = currentPath ? `${currentPath}/` : "";
  const seen = new Set<string>();
  for (const f of allFiles) {
    if (!f.path.startsWith(prefix)) continue;
    const remainder = f.path.slice(prefix.length);
    const slash = remainder.indexOf("/");
    if (slash !== -1) {
      const folder = remainder.slice(0, slash);
      seen.add(folder);
    }
  }
  return Array.from(seen).sort();
});

// ── Search ────────────────────────────────────────────────────────────────────

let rawSearch = $state("");
let searchQ = $state("");
let searchTimer: ReturnType<typeof setTimeout> | undefined;

function onSearchInput(e: Event): void {
  rawSearch = (e.currentTarget as HTMLInputElement).value;
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    searchQ = rawSearch;
  }, 300);
}

const isSearching = $derived(searchQ.trim().length > 0);

const searchOptsStore = writable(
  untrack(
    () =>
      searchFilesQuery(currentSlug, searchQ) as CreateQueryOptions<FileRecord[]>,
  ),
);
$effect(() => {
  searchOptsStore.set(
    searchFilesQuery(currentSlug, searchQ) as CreateQueryOptions<FileRecord[]>,
  );
});
const searchResultQ = createQuery<FileRecord[]>(searchOptsStore);
const searchedFiles = $derived(($searchResultQ.data ?? []) as FileRecord[]);

// ── Upload (single file) ──────────────────────────────────────────────────────

let uploadOpen = $state(false);
let uploadFile = $state<File | null>(null);
let uploadPath = $state("");
let uploadError = $state<string | null>(null);

const uploadMut = createMutation<FileRecord, Error, { workspaceSlug: string; path: string; file: File }>(
  uploadFileMutation() as CreateMutationOptions<FileRecord, Error, { workspaceSlug: string; path: string; file: File }>,
);

function handleFileInput(e: Event): void {
  const input = e.currentTarget as HTMLInputElement;
  uploadFile = input.files?.[0] ?? null;
  if (uploadFile && !uploadPath) {
    uploadPath = currentPath ? `${currentPath}/${uploadFile.name}` : uploadFile.name;
  }
}

function handleUploadSubmit(e: Event): void {
  e.preventDefault();
  if (!uploadFile || !currentSlug) return;
  uploadError = null;
  $uploadMut.mutate(
    { workspaceSlug: currentSlug, path: uploadPath || uploadFile.name, file: uploadFile },
    {
      onSuccess: () => {
        uploadFile = null;
        uploadPath = "";
        uploadOpen = false;
        queryClient.invalidateQueries({ queryKey: ["files"] });
      },
      onError: (err) => {
        uploadError = err.message;
      },
    },
  );
}

// ── Upload folder (webkitdirectory) ──────────────────────────────────────────

let folderUploadProgress = $state<{ done: number; total: number } | null>(null);
let folderInputEl = $state<HTMLInputElement | null>(null);

async function handleFolderUpload(e: Event): Promise<void> {
  const input = e.currentTarget as HTMLInputElement;
  const fileList = Array.from(input.files ?? []);
  if (!fileList.length || !currentSlug) return;

  folderUploadProgress = { done: 0, total: fileList.length };

  for (const file of fileList) {
    const relativePath = (file as File & { webkitRelativePath: string }).webkitRelativePath;
    const targetPath = currentPath
      ? `${currentPath}/${relativePath}`
      : relativePath;

    await new Promise<void>((resolve) => {
      $uploadMut.mutate(
        { workspaceSlug: currentSlug, path: targetPath, file },
        {
          onSuccess: () => {
            folderUploadProgress = {
              done: (folderUploadProgress?.done ?? 0) + 1,
              total: folderUploadProgress?.total ?? fileList.length,
            };
            resolve();
          },
          onError: () => {
            folderUploadProgress = {
              done: (folderUploadProgress?.done ?? 0) + 1,
              total: folderUploadProgress?.total ?? fileList.length,
            };
            resolve();
          },
        },
      );
    });
  }

  queryClient.invalidateQueries({ queryKey: ["files"] });
  folderUploadProgress = null;
  // Reset the input so the same folder can be re-selected
  if (folderInputEl) folderInputEl.value = "";
}

// ── Folder creation ───────────────────────────────────────────────────────────

let newFolderOpen = $state(false);
let newFolderName = $state("");
let folderError = $state<string | null>(null);
let folderInputEl2 = $state<HTMLInputElement | null>(null);

$effect(() => {
  if (newFolderOpen) {
    setTimeout(() => folderInputEl2?.focus(), 0);
  }
});

async function handleCreateFolder(): Promise<void> {
  const name = newFolderName.trim();
  if (!name || !currentSlug) return;
  folderError = null;

  const sentinelPath = currentPath
    ? `${currentPath}/${name}/.gitkeep`
    : `${name}/.gitkeep`;

  const emptyBlob = new File([""], ".gitkeep", { type: "application/octet-stream" });

  await new Promise<void>((resolve) => {
    $uploadMut.mutate(
      { workspaceSlug: currentSlug, path: sentinelPath, file: emptyBlob },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: ["files"] });
          newFolderName = "";
          newFolderOpen = false;
          resolve();
        },
        onError: (err) => {
          folderError = err.message;
          resolve();
        },
      },
    );
  });
}

// ── Scan mutation ─────────────────────────────────────────────────────────────

const scanMut = createMutation<void, Error, string>(
  scanWorkspaceMutation() as CreateMutationOptions<void, Error, string>,
);

function handleScan(): void {
  if (!currentSlug) return;
  $scanMut.mutate(currentSlug, {
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["files"] });
    },
  });
}

// ── Drag-and-drop ─────────────────────────────────────────────────────────────

let isDragOver = $state(false);

function handleDragOver(e: DragEvent): void {
  e.preventDefault();
  isDragOver = true;
}

function handleDragLeave(): void {
  isDragOver = false;
}

function handleDrop(e: DragEvent): void {
  e.preventDefault();
  isDragOver = false;
  if (!currentSlug) return;
  const droppedFiles = Array.from(e.dataTransfer?.files ?? []);
  if (!droppedFiles.length) return;

  let done = 0;
  folderUploadProgress = { done: 0, total: droppedFiles.length };

  for (const file of droppedFiles) {
    const targetPath = currentPath ? `${currentPath}/${file.name}` : file.name;
    $uploadMut.mutate(
      { workspaceSlug: currentSlug, path: targetPath, file },
      {
        onSuccess: () => {
          done++;
          folderUploadProgress = { done, total: droppedFiles.length };
          if (done === droppedFiles.length) {
            queryClient.invalidateQueries({ queryKey: ["files"] });
            folderUploadProgress = null;
          }
        },
        onError: () => {
          done++;
          folderUploadProgress = { done, total: droppedFiles.length };
          if (done === droppedFiles.length) {
            queryClient.invalidateQueries({ queryKey: ["files"] });
            folderUploadProgress = null;
          }
        },
      },
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function formatDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

function fileName(f: FileRecord): string {
  const parts = f.path.split("/");
  return parts[parts.length - 1] ?? f.name;
}
</script>

<div class="fb-layout">
  <!-- ── Left pane: Buckets ───────────────────────────────────────────────── -->
  <aside class="fb-sidebar" aria-label="Buckets">
    <div class="fb-sidebar-header">
      <span class="fb-label">BUCKETS</span>
    </div>

    <div class="fb-bucket-list" role="listbox" aria-label="Workspace buckets">
      {#if $workspacesQ.isLoading}
        <div class="fb-sidebar-skeleton">
          <SkeletonList count={4} height="2.25rem" gap="2px" />
        </div>
      {:else if workspaces.length === 0}
        <p class="fb-sidebar-empty">No workspaces yet.</p>
      {:else}
        {#each workspaces as ws (ws.slug)}
          {@const stats = workspaceStats().get(ws.slug)}
          <button
            class="fb-bucket-row"
            class:fb-bucket-row--active={ws.slug === currentSlug}
            role="option"
            aria-selected={ws.slug === currentSlug}
            onclick={() => {
              ui.setCurrentWorkspace(ws.slug);
              currentPath = "";
              rawSearch = "";
              searchQ = "";
            }}
          >
            <span class="fb-bucket-icon" aria-hidden="true">
              <FolderOpen size={13} />
            </span>
            <span class="fb-bucket-meta">
              <span class="fb-bucket-name">{ws.name}</span>
              <span class="fb-bucket-stat">
                {stats ? `${stats.count} file${stats.count !== 1 ? "s" : ""}` : "—"}
                ·
                <!-- TODO: wire per-workspace quota from backend when quota column lands -->
                {stats ? formatBytes(stats.bytes) : "0 B"} / {formatBytes(QUOTA_BYTES)}
              </span>
            </span>
          </button>
        {/each}
      {/if}
    </div>

    <div class="fb-sidebar-footer">
      <button
        class="fb-new-bucket btn-compact btn-compact-ghost"
        onclick={() => goto("/workspaces")}
        aria-label="Create new workspace bucket"
      >
        + New Bucket
      </button>
    </div>
  </aside>

  <!-- ── Right pane: File browser ─────────────────────────────────────────── -->
  <main class="fb-main">
    {#if !currentSlug}
      <!-- No workspace selected -->
      <div class="fb-no-bucket">
        <EmptyState
          icon={FolderOpen as never}
          title="Select a bucket"
          body="Choose a workspace from the left to browse its files."
        />
      </div>
    {:else}
      <!-- Top bar: breadcrumb + actions -->
      <div class="fb-topbar">
        <!-- Breadcrumb -->
        <nav class="fb-breadcrumb" aria-label="File path">
          <button
            class="fb-crumb fb-crumb-root"
            class:fb-crumb--active={currentPath === ""}
            onclick={() => { currentPath = ""; }}
          >
            {currentWorkspace?.name ?? "Root"}
          </button>
          {#each pathSegments(currentPath) as seg (seg.path)}
            <span class="fb-crumb-sep" aria-hidden="true">/</span>
            <button
              class="fb-crumb"
              class:fb-crumb--active={seg.path === currentPath}
              onclick={() => { currentPath = seg.path; }}
            >
              {seg.label}
            </button>
          {/each}
        </nav>

        <!-- Action buttons -->
        <div class="fb-actions">
          {#if folderUploadProgress}
            <span class="fb-progress-label" aria-live="polite">
              Uploading {folderUploadProgress.done} of {folderUploadProgress.total}…
            </span>
          {/if}

          <!-- + Folder -->
          {#if !newFolderOpen}
            <button
              class="btn-pill btn-pill-ghost btn-pill-sm"
              onclick={() => { newFolderOpen = true; newFolderName = ""; folderError = null; }}
              aria-label="Create new folder"
            >
              + Folder
            </button>
          {:else}
            <div class="fb-inline-folder" role="group" aria-label="New folder name">
              <input
                bind:this={folderInputEl2}
                class="fb-inline-input"
                type="text"
                placeholder="folder-name"
                bind:value={newFolderName}
                aria-label="New folder name"
                onkeydown={(e) => {
                  if (e.key === "Enter") handleCreateFolder();
                  if (e.key === "Escape") { newFolderOpen = false; folderError = null; }
                }}
              />
              <button
                class="btn-compact btn-compact-ghost"
                onclick={handleCreateFolder}
                disabled={!newFolderName.trim() || $uploadMut.isPending}
                aria-label="Confirm folder creation"
              >
                OK
              </button>
              <button
                class="btn-compact btn-compact-ghost"
                onclick={() => { newFolderOpen = false; folderError = null; }}
                aria-label="Cancel folder creation"
              >
                ✕
              </button>
              {#if folderError}
                <span class="fb-inline-error" role="alert">{folderError}</span>
              {/if}
            </div>
          {/if}

          <!-- + Upload -->
          <button
            class="btn-pill btn-pill-primary btn-pill-sm"
            onclick={() => { uploadOpen = !uploadOpen; }}
            aria-expanded={uploadOpen}
            aria-label="Upload file"
          >
            + Upload
          </button>

          <!-- + Upload Folder (hidden native input) -->
          <button
            class="btn-pill btn-pill-ghost btn-pill-sm"
            onclick={() => folderInputEl?.click()}
            disabled={$uploadMut.isPending}
            aria-label="Upload an entire folder"
          >
            + Upload Folder
          </button>
          <input
            bind:this={folderInputEl}
            type="file"
            class="fb-hidden-input"
            multiple
            webkitdirectory
            aria-hidden="true"
            tabindex="-1"
            onchange={handleFolderUpload}
          />

          <!-- Scan -->
          <button
            class="fb-scan btn-compact btn-compact-ghost"
            onclick={handleScan}
            disabled={$scanMut.isPending}
            aria-label="Re-index workspace files"
            title="Scan workspace"
          >
            <span class:fb-spin={$scanMut.isPending}>
              <RefreshCw size={11} aria-hidden="true" />
            </span>
          </button>
        </div>
      </div>

      <!-- Inline upload form -->
      {#if uploadOpen}
        <form
          class="fb-upload-form glass-panel"
          onsubmit={handleUploadSubmit}
          novalidate
        >
          <label class="fb-upload-label">
            <span class="fb-hint">File</span>
            <input
              class="fb-upload-file-input"
              type="file"
              onchange={handleFileInput}
              aria-label="Choose file to upload"
              required
            />
          </label>
          <label class="fb-upload-label">
            <span class="fb-hint">Path in workspace</span>
            <input
              class="fb-upload-path"
              type="text"
              placeholder={currentPath ? `${currentPath}/filename.ext` : "filename.ext"}
              bind:value={uploadPath}
              aria-label="Destination path within workspace"
            />
          </label>
          <div class="fb-upload-actions">
            {#if uploadError}
              <span class="fb-upload-error" role="alert">{uploadError}</span>
            {/if}
            <button
              class="btn-pill btn-pill-primary btn-pill-sm"
              type="submit"
              disabled={$uploadMut.isPending || !uploadFile || !currentSlug}
            >
              {$uploadMut.isPending ? "Uploading…" : "Upload"}
            </button>
            <button
              class="btn-compact btn-compact-ghost"
              type="button"
              onclick={() => { uploadOpen = false; uploadError = null; }}
            >
              Cancel
            </button>
          </div>
        </form>
      {/if}

      <!-- Search row -->
      <div class="fb-search-row">
        <input
          class="fb-search"
          type="search"
          placeholder="Search files in this workspace…"
          value={rawSearch}
          oninput={onSearchInput}
          aria-label="Search files"
          spellcheck={false}
          autocomplete="off"
        />
        <!-- Quota badge for selected workspace -->
        <span class="fb-quota" title="Storage used / quota">
          {formatBytes(usedBytes)} / {formatBytes(QUOTA_BYTES)}
        </span>
      </div>

      <!-- File content area -->
      {#if $allFilesQ.isError}
        <EmptyState
          icon={FileSearch as never}
          title="Couldn't load files"
          body={($allFilesQ.error as Error).message || "Check your connection and try again."}
          action="Retry"
          onAction={() => $allFilesQ.refetch()}
        />
      {:else if $allFilesQ.isLoading}
        <div class="fb-skeleton-wrap">
          <SkeletonList count={8} height="2.25rem" gap="2px" />
        </div>
      {:else}
        {@const displayedFiles = visibleFiles()}
        {@const displayedFolders = isSearching ? [] : subfolders()}

        {#if displayedFiles.length === 0 && displayedFolders.length === 0}
          <!-- Empty state / drop zone -->
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <div
            class="fb-dropzone"
            class:fb-dropzone--active={isDragOver}
            ondragover={handleDragOver}
            ondragleave={handleDragLeave}
            ondrop={handleDrop}
            aria-label="Drop files here to upload"
          >
            <FileSearch size={32} aria-hidden="true" class="fb-dz-icon" />
            <p class="fb-dz-title">
              {isSearching ? `No files matching "${searchQ}"` : "Drop files here to upload"}
            </p>
            <p class="fb-dz-body">
              {#if isSearching}
                Try a different term or clear the search.
              {:else if isDragOver}
                Drop to upload to /{currentPath || (currentWorkspace?.name ?? "root")}
              {:else}
                Drag files here or use + Upload above.
              {/if}
            </p>
            {#if isSearching}
              <button
                class="btn-pill btn-pill-ghost btn-pill-sm"
                onclick={() => { rawSearch = ""; searchQ = ""; }}
              >
                Clear search
              </button>
            {/if}
          </div>
        {:else}
          <!-- File table — rows sit on page bg, no card wrapper -->
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <div
            class="fb-table-wrap"
            ondragover={handleDragOver}
            ondragleave={handleDragLeave}
            ondrop={handleDrop}
            class:fb-table-wrap--dragover={isDragOver}
          >
            {#if isDragOver}
              <div class="fb-drag-overlay" aria-hidden="true">
                Drop to upload to /{currentPath || (currentWorkspace?.name ?? "root")}
              </div>
            {/if}

            <Table hoverable>
              <TableHeader>
                <tr>
                  <th class="fb-th fb-th-icon"></th>
                  <th class="fb-th">Name</th>
                  <th class="fb-th">Size</th>
                  <th class="fb-th">Tags</th>
                  <th class="fb-th">Last indexed</th>
                </tr>
              </TableHeader>
              <tbody>
                <!-- Subfolder rows -->
                {#each displayedFolders as folder (folder)}
                  <!-- svelte-ignore a11y_interactive_supports_focus -->
                  <tr
                    class="fb-row bos-table-row"
                    role="button"
                    onclick={() => {
                      currentPath = currentPath ? `${currentPath}/${folder}` : folder;
                    }}
                    onkeydown={(e) => {
                      if (e.key === "Enter") {
                        currentPath = currentPath ? `${currentPath}/${folder}` : folder;
                      }
                    }}
                  >
                    <td class="bos-table-cell fb-td-icon" aria-hidden="true">📁</td>
                    <td class="bos-table-cell fb-td-name fb-td-folder">{folder}/</td>
                    <td class="bos-table-cell fb-mono">—</td>
                    <td class="bos-table-cell">—</td>
                    <td class="bos-table-cell fb-mono">—</td>
                  </tr>
                {/each}

                <!-- File rows -->
                {#each displayedFiles as file (file.id)}
                  <!-- svelte-ignore a11y_interactive_supports_focus -->
                  <tr
                    class="fb-row bos-table-row"
                    role="button"
                    onclick={() => goto(`/files/${file.id}`)}
                    onkeydown={(e) => e.key === "Enter" && goto(`/files/${file.id}`)}
                  >
                    <td class="bos-table-cell fb-td-icon" aria-hidden="true">
                      {fileIcon(file.extension)}
                    </td>
                    <td class="bos-table-cell fb-td-name">
                      {fileName(file)}
                    </td>
                    <td class="bos-table-cell fb-mono">
                      {formatBytes(file.sizeBytes)}
                    </td>
                    <td class="bos-table-cell fb-td-tags">
                      {#each file.tags as tag (tag)}
                        <span class="fb-tag-badge">{tag}</span>
                      {/each}
                    </td>
                    <td class="bos-table-cell fb-mono">
                      {formatDate(file.lastIndexedAt)}
                    </td>
                  </tr>
                {/each}
              </tbody>
            </Table>
          </div>
        {/if}
      {/if}
    {/if}
  </main>
</div>

<style>
  /* ── Layout ── */
  .fb-layout {
    display: flex;
    height: 100%;
    overflow: hidden;
  }

  /* ── Left pane ── */
  .fb-sidebar {
    width: 240px;
    min-width: 200px;
    max-width: 260px;
    display: flex;
    flex-direction: column;
    border-right: 1px solid var(--border);
    flex-shrink: 0;
    overflow: hidden;
  }

  .fb-sidebar-header {
    padding: var(--space-4) var(--space-3) var(--space-2);
    flex-shrink: 0;
  }

  .fb-label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    letter-spacing: 0.1em;
    text-transform: uppercase;
  }

  .fb-bucket-list {
    flex: 1;
    overflow-y: auto;
    padding: 0 var(--space-1);
  }

  .fb-sidebar-skeleton {
    padding: var(--space-2);
  }

  .fb-sidebar-empty {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    padding: var(--space-3) var(--space-2);
    margin: 0;
  }

  .fb-bucket-row {
    display: flex;
    align-items: flex-start;
    gap: var(--space-2);
    width: 100%;
    padding: var(--space-1) var(--space-2);
    background: transparent;
    border: none;
    border-left: 1px solid transparent;
    border-radius: 0;
    cursor: pointer;
    text-align: left;
    transition:
      background var(--dur-instant) var(--ease-out),
      border-color var(--dur-instant) var(--ease-out);
    min-height: 40px;
  }

  .fb-bucket-row:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  .fb-bucket-row--active {
    border-left-color: var(--cnp-accent);
    background: var(--bg-inset);
  }

  .fb-bucket-icon {
    flex-shrink: 0;
    color: var(--fg-subtle);
    margin-top: 2px;
  }

  .fb-bucket-meta {
    display: flex;
    flex-direction: column;
    gap: 1px;
    min-width: 0;
    flex: 1;
  }

  .fb-bucket-name {
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--fg-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    font-weight: 450;
  }

  .fb-bucket-row--active .fb-bucket-name {
    color: var(--fg);
    font-weight: 500;
  }

  .fb-bucket-stat {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-subtle);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .fb-sidebar-footer {
    border-top: 1px solid var(--border);
    padding: var(--space-1);
    flex-shrink: 0;
  }

  .fb-new-bucket {
    width: 100%;
    text-align: left;
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    padding: var(--space-1) var(--space-2);
    min-height: 28px;
  }

  .fb-new-bucket:hover {
    color: var(--fg-muted);
  }

  /* ── Right pane ── */
  .fb-main {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    min-width: 0;
  }

  .fb-no-bucket {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  /* ── Top bar ── */
  .fb-topbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-4);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    flex-wrap: wrap;
  }

  .fb-breadcrumb {
    display: flex;
    align-items: center;
    gap: 2px;
    flex: 1;
    min-width: 0;
    overflow: hidden;
  }

  .fb-crumb {
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--fg-muted);
    background: transparent;
    border: none;
    cursor: pointer;
    padding: 2px var(--space-1);
    border-radius: var(--radius-sm);
    white-space: nowrap;
    transition: color var(--dur-instant) var(--ease-out);
  }

  .fb-crumb:hover {
    color: var(--fg);
  }

  .fb-crumb--active {
    color: var(--fg);
    font-weight: 500;
    cursor: default;
  }

  .fb-crumb-sep {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-subtle);
    user-select: none;
  }

  .fb-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
    flex-wrap: wrap;
  }

  .fb-progress-label {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-muted);
  }

  .fb-inline-folder {
    display: flex;
    align-items: center;
    gap: var(--space-1);
  }

  .fb-inline-input {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 2px var(--space-2);
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--fg);
    outline: none;
    width: 160px;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .fb-inline-input:focus {
    border-color: var(--border-strong);
  }

  .fb-inline-input::placeholder {
    color: var(--fg-subtle);
  }

  .fb-inline-error {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--signal-error);
  }

  .fb-scan {
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--fg-muted);
    min-width: 28px;
  }

  .fb-scan:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  :global(.fb-spin) {
    display: flex;
    animation: fb-rotate 1s linear infinite;
  }

  @keyframes fb-rotate {
    from { transform: rotate(0deg); }
    to   { transform: rotate(360deg); }
  }

  /* ── Upload form ── */
  .fb-upload-form {
    display: flex;
    flex-wrap: wrap;
    align-items: flex-end;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-4);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .fb-upload-label {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .fb-hint {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .fb-upload-file-input,
  .fb-upload-path {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: var(--space-1) var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
  }

  .fb-upload-path {
    width: 240px;
  }

  .fb-upload-path::placeholder {
    color: var(--fg-subtle);
  }

  .fb-upload-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    margin-left: auto;
  }

  .fb-upload-error {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--signal-error);
  }

  /* ── Search row ── */
  .fb-search-row {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-2) var(--space-4);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .fb-search {
    flex: 1;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: var(--space-1) var(--space-3);
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--fg);
    outline: none;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .fb-search:focus {
    border-color: var(--border-strong);
  }

  .fb-search::placeholder {
    color: var(--fg-subtle);
  }

  .fb-quota {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-subtle);
    white-space: nowrap;
    flex-shrink: 0;
  }

  /* ── Skeleton ── */
  .fb-skeleton-wrap {
    flex: 1;
    padding: var(--space-3) var(--space-4);
    overflow: hidden;
  }

  /* ── Drop zone (empty state) ── */
  .fb-dropzone {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--space-3);
    padding: var(--space-12) var(--space-8);
    text-align: center;
    border: 2px dashed transparent;
    transition: border-color var(--dur-instant) var(--ease-out);
    margin: var(--space-4);
    border-radius: var(--radius-sm);
  }

  .fb-dropzone--active {
    border-color: var(--cnp-accent);
  }

  :global(.fb-dz-icon) {
    color: var(--fg-subtle);
    opacity: 0.5;
  }

  .fb-dz-title {
    font-family: var(--font-sans);
    font-size: var(--text-base);
    font-weight: 500;
    color: var(--fg-muted);
    margin: 0;
  }

  .fb-dz-body {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    margin: 0;
    max-width: 320px;
    line-height: 1.6;
  }

  /* ── Table ── */
  .fb-table-wrap {
    flex: 1;
    overflow: auto;
    position: relative;
  }

  .fb-table-wrap--dragover {
    outline: 2px dashed var(--cnp-accent);
    outline-offset: -2px;
  }

  .fb-drag-overlay {
    position: absolute;
    inset: 0;
    background: color-mix(in oklch, var(--cnp-accent) 6%, transparent 94%);
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    z-index: 10;
    pointer-events: none;
  }

  .fb-th {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    color: var(--fg-muted);
    padding: var(--space-2) var(--space-3);
    text-align: left;
    border-bottom: 1px solid var(--border);
    letter-spacing: 0.06em;
    text-transform: uppercase;
    white-space: nowrap;
  }

  .fb-th-icon {
    width: 32px;
    padding-right: 0;
  }

  :global(.fb-row) {
    cursor: pointer;
    border-bottom: 1px solid var(--border);
  }

  :global(.fb-row:last-child) {
    border-bottom: none;
  }

  :global(.fb-row:hover) {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  :global(.fb-td-icon) {
    width: 32px !important;
    padding-right: 0 !important;
    font-size: 15px;
    line-height: 1;
  }

  :global(.fb-td-name) {
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--fg);
    font-weight: 450;
    max-width: 300px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  :global(.fb-td-folder) {
    color: var(--fg-muted);
    font-weight: 500;
  }

  .fb-mono {
    font-family: var(--font-mono);
    font-size: 12px;
    color: var(--fg-muted);
  }

  :global(.fb-td-tags) {
    white-space: nowrap;
  }

  .fb-tag-badge {
    display: inline-block;
    padding: 0 var(--space-1);
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-muted);
    margin-right: 3px;
    line-height: 1.6;
  }

  .fb-hidden-input {
    position: absolute;
    width: 1px;
    height: 1px;
    opacity: 0;
    pointer-events: none;
  }
</style>
