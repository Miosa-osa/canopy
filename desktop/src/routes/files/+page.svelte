<script lang="ts">
/**
 * /files — File index list page (Track #89).
 *
 * Layout:
 *   - Header: WorkspaceSwitcher + debounced search + "+ Upload" pill + "Scan" compact
 *   - Filter bar: tag chips (derived client-side) + extension dropdown
 *   - Upload form: inline, native inputs, builds FormData → uploadFileMutation
 *   - Table: icon | name | path | size | tags | owner | last_indexed_at
 *   - Empty / loading / error states per docs/02-frontend-design.md §9
 *
 * CSS prefix: fi- (FileIndex)
 * LOC target: ≤ 300
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from "@tanstack/svelte-query";
import { FileSearch, RefreshCw } from "lucide-svelte";
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
import Select from "$lib/design/foundation/select/Select.svelte";
import { Table, TableHeader } from "$lib/design/foundation/table/index.js";
import EmptyState from "$lib/design/patterns/EmptyState.svelte";
import SkeletonList from "$lib/design/patterns/SkeletonList.svelte";
import WorkspaceSwitcher from "$lib/design/patterns/WorkspaceSwitcher.svelte";
import type { FileRecord } from "$lib/domain/files/types.js";
import type { Workspace } from "$lib/domain/workspaces/types.js";
import { ui } from "$lib/stores/ui.svelte.js";

const queryClient = useQueryClient();

// ── Workspace + filter state ─────────────────────────────────────────────────

const workspacesOptsStore = writable(
  untrack(() => workspacesQuery() as CreateQueryOptions<Workspace[]>),
);
const workspacesQ = createQuery<Workspace[]>(workspacesOptsStore);
const workspaces = $derived(($workspacesQ.data ?? []) as Workspace[]);

const currentSlug = $derived(ui.currentWorkspaceSlug ?? "");

let rawSearch = $state("");
let searchQ = $state("");
let tagFilter = $state("");
let extFilter = $state("all");
let uploadOpen = $state(false);

// Debounce search input — update searchQ 300 ms after last keystroke
let searchTimer: ReturnType<typeof setTimeout> | undefined;
function onSearchInput(e: Event): void {
  rawSearch = (e.currentTarget as HTMLInputElement).value;
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    searchQ = rawSearch;
  }, 300);
}

// ── Files query — switches to search query when searchQ is non-empty ─────────

const listFilters = $derived({
  workspace: currentSlug || undefined,
  tag: tagFilter || undefined,
  extension: extFilter !== "all" ? extFilter : undefined,
});

const listOptsStore = writable(
  untrack(() => filesQuery(listFilters) as CreateQueryOptions<FileRecord[]>),
);
$effect(() => {
  listOptsStore.set(filesQuery(listFilters) as CreateQueryOptions<FileRecord[]>);
});
const listQ = createQuery<FileRecord[]>(listOptsStore);

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
const searchResult = createQuery<FileRecord[]>(searchOptsStore);

const isSearching = $derived(searchQ.trim().length > 0);
const activeQ = $derived(isSearching ? searchResult : listQ);
const files = $derived(($activeQ.data ?? []) as FileRecord[]);

// ── Derived tag/extension options from list results ──────────────────────────

const allTags = $derived(
  Array.from(new Set(($listQ.data ?? []).flatMap((f) => f.tags))).sort(),
);

const allExtensions = $derived(
  Array.from(
    new Set(
      ($listQ.data ?? [])
        .map((f) => f.extension)
        .filter((e): e is string => Boolean(e)),
    ),
  ).sort(),
);

const extOptions = $derived([
  { value: "all", label: "All types" },
  ...allExtensions.map((e) => ({ value: e, label: `.${e}` })),
]);

// ── Upload form state ────────────────────────────────────────────────────────

let uploadFile = $state<File | null>(null);
let uploadPath = $state("");
let uploadError = $state<string | null>(null);

const uploadMut = createMutation<FileRecord, Error, { workspaceSlug: string; path: string; file: File }>(
  uploadFileMutation() as CreateMutationOptions<
    FileRecord,
    Error,
    { workspaceSlug: string; path: string; file: File }
  >,
);

function handleFileInput(e: Event): void {
  const input = e.currentTarget as HTMLInputElement;
  uploadFile = input.files?.[0] ?? null;
  if (uploadFile && !uploadPath) {
    uploadPath = uploadFile.name;
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

// ── Scan mutation ────────────────────────────────────────────────────────────

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

// ── Helpers ──────────────────────────────────────────────────────────────────

function formatDate(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}
</script>

<div class="fi-page">
  <!-- Header -->
  <header class="fi-header">
    <div class="fi-header-top">
      <div class="fi-workspace-row">
        <WorkspaceSwitcher />
      </div>
      <div class="fi-actions">
        <input
          class="fi-search"
          type="search"
          placeholder="Search files…"
          value={rawSearch}
          oninput={onSearchInput}
          aria-label="Search files"
          spellcheck={false}
          autocomplete="off"
        />
        <button
          class="btn-pill btn-pill-primary btn-pill-sm"
          onclick={() => { uploadOpen = !uploadOpen; }}
          aria-expanded={uploadOpen}
          aria-label="Upload file"
        >
          + Upload
        </button>
        <button
          class="fi-scan btn-compact btn-compact-ghost"
          onclick={handleScan}
          disabled={$scanMut.isPending || !currentSlug}
          aria-label="Scan workspace to re-index files"
          title="Scan workspace"
        >
          <span class="fi-icon" class:fi-spin={$scanMut.isPending}>
            <RefreshCw size={12} aria-hidden="true" />
          </span>
          Scan
        </button>
      </div>
    </div>

    <!-- Upload form (inline, collapsible) -->
    {#if uploadOpen}
      <form class="fi-upload-form glass-panel" onsubmit={handleUploadSubmit} novalidate>
        <label class="fi-upload-label">
          <span class="fi-upload-hint">File</span>
          <input
            class="fi-upload-file-input"
            type="file"
            onchange={handleFileInput}
            aria-label="Choose file to upload"
            required
          />
        </label>
        <label class="fi-upload-label">
          <span class="fi-upload-hint">Path in workspace</span>
          <input
            class="fi-upload-path"
            type="text"
            placeholder="e.g. docs/report.md"
            bind:value={uploadPath}
            aria-label="Destination path within workspace"
          />
        </label>
        <div class="fi-upload-actions">
          {#if uploadError}
            <span class="fi-upload-error" role="alert">{uploadError}</span>
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
  </header>

  <!-- Filter bar -->
  <div class="fi-filters" role="search" aria-label="Filter files">
    <!-- Tag chips -->
    {#if allTags.length > 0}
      <div class="fi-tag-chips" role="group" aria-label="Filter by tag">
        <button
          class="fi-tag-chip"
          class:fi-tag-chip--active={tagFilter === ""}
          onclick={() => { tagFilter = ""; }}
        >
          All
        </button>
        {#each allTags as tag (tag)}
          <button
            class="fi-tag-chip"
            class:fi-tag-chip--active={tagFilter === tag}
            onclick={() => { tagFilter = tagFilter === tag ? "" : tag; }}
          >
            {tag}
          </button>
        {/each}
      </div>
    {/if}

    <Select
      options={extOptions}
      bind:value={extFilter}
      placeholder="All types"
    />
  </div>

  <!-- Content area -->
  {#if $activeQ.isError}
    <EmptyState
      icon={FileSearch as never}
      title="Couldn't load files"
      body={($activeQ.error as Error).message || "Check your connection and try again."}
      action="Retry"
      onAction={() => $activeQ.refetch()}
    />
  {:else if $activeQ.isLoading}
    <div class="fi-skeleton-wrap">
      <SkeletonList count={8} height="2.5rem" gap="0.375rem" />
    </div>
  {:else if files.length === 0}
    <EmptyState
      icon={FileSearch as never}
      title={isSearching ? `No files matching "${searchQ}"` : "No files indexed"}
      body={isSearching
        ? "Try a different search term or clear the filter."
        : "Upload a file or scan the workspace to index files."}
      action={isSearching ? "Clear search" : "Scan workspace"}
      onAction={isSearching ? () => { rawSearch = ""; searchQ = ""; } : handleScan}
    />
  {:else}
    <div class="fi-table-wrap">
      <Table hoverable>
        <TableHeader>
          <tr>
            <th class="fi-th fi-th-icon"></th>
            <th class="fi-th">Name</th>
            <th class="fi-th">Path</th>
            <th class="fi-th">Size</th>
            <th class="fi-th">Tags</th>
            <th class="fi-th">Owner</th>
            <th class="fi-th">Last indexed</th>
          </tr>
        </TableHeader>
        <tbody>
          {#each files as file (file.id)}
            <!-- svelte-ignore a11y_interactive_supports_focus -->
            <tr
              class="fi-row bos-table-row"
              role="button"
              onclick={() => goto(`/files/${file.id}`)}
              onkeydown={(e) => e.key === "Enter" && goto(`/files/${file.id}`)}
            >
              <td class="bos-table-cell fi-td-icon" aria-hidden="true">
                {fileIcon(file.extension)}
              </td>
              <td class="bos-table-cell fi-td-name">
                {file.name}
              </td>
              <td class="bos-table-cell fi-mono fi-td-path" title={file.path}>
                {file.path}
              </td>
              <td class="bos-table-cell fi-mono">
                {formatBytes(file.sizeBytes)}
              </td>
              <td class="bos-table-cell fi-td-tags">
                {#each file.tags as tag (tag)}
                  <span class="fi-tag-badge">{tag}</span>
                {/each}
              </td>
              <td class="bos-table-cell fi-mono fi-td-owner">
                {file.ownerId ?? file.ownerType}
              </td>
              <td class="bos-table-cell fi-mono">
                {formatDate(file.lastIndexedAt)}
              </td>
            </tr>
          {/each}
        </tbody>
      </Table>
    </div>
  {/if}
</div>

<style>
  .fi-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  /* ── Header ── */
  .fi-header {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-5) var(--space-6) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .fi-header-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
  }

  .fi-workspace-row {
    position: relative;
    min-width: 180px;
    max-width: 260px;
  }

  .fi-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-wrap: wrap;
  }

  .fi-search {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-1) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    width: 220px;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .fi-search:focus {
    border-color: var(--border-strong);
  }

  .fi-search::placeholder {
    color: var(--fg-subtle);
  }

  .fi-scan {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  .fi-scan:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  :global(.fi-spin) {
    animation: fi-rotate 1s linear infinite;
  }

  @keyframes fi-rotate {
    from { transform: rotate(0deg); }
    to   { transform: rotate(360deg); }
  }

  /* ── Upload form ── */
  .fi-upload-form {
    display: flex;
    flex-wrap: wrap;
    align-items: flex-end;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-4);
    border-radius: var(--radius-lg);
  }

  .fi-upload-label {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .fi-upload-hint {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .fi-upload-file-input,
  .fi-upload-path {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-1) var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
  }

  .fi-upload-path {
    width: 240px;
  }

  .fi-upload-path::placeholder {
    color: var(--fg-subtle);
  }

  .fi-upload-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    margin-left: auto;
  }

  .fi-upload-error {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--signal-error);
  }

  /* ── Filter bar ── */
  .fi-filters {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-6);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    flex-wrap: wrap;
  }

  .fi-filters :global(.bos-select) {
    min-width: 120px;
    width: auto;
  }

  .fi-tag-chips {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    flex-wrap: wrap;
  }

  .fi-tag-chip {
    padding: 2px var(--space-2);
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out),
      border-color var(--dur-instant) var(--ease-out);
    line-height: 1.6;
  }

  .fi-tag-chip:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg-muted);
  }

  .fi-tag-chip--active {
    background: color-mix(in oklch, var(--accent) 12%, transparent 88%);
    border-color: color-mix(in oklch, var(--accent) 40%, transparent 60%);
    color: var(--fg);
  }

  /* ── Table ── */
  .fi-skeleton-wrap {
    flex: 1;
    padding: var(--space-5) var(--space-6);
  }

  .fi-table-wrap {
    flex: 1;
    overflow: auto;
    margin: var(--space-5) var(--space-6);
    border-radius: var(--radius-lg);
    border: 1px solid var(--border);
  }

  .fi-th {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-muted);
    padding: var(--space-2) var(--space-3);
    text-align: left;
    border-bottom: 1px solid var(--border);
    letter-spacing: 0.06em;
    text-transform: uppercase;
    white-space: nowrap;
  }

  .fi-th-icon {
    width: 32px;
    padding-right: 0;
  }

  :global(.fi-row) {
    cursor: pointer;
  }

  :global(.fi-td-icon) {
    width: 32px !important;
    padding-right: 0 !important;
    font-size: 16px;
    line-height: 1;
  }

  :global(.fi-td-name) {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    font-weight: 500;
    max-width: 200px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .fi-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  :global(.fi-td-path) {
    max-width: 260px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  :global(.fi-td-tags) {
    white-space: nowrap;
  }

  :global(.fi-td-owner) {
    max-width: 120px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .fi-tag-badge {
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
</style>
