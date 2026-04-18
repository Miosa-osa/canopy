<script lang="ts">
/**
 * /docs — Document list with folder tree sidebar.
 *
 * Layout: two-pane
 *   Left (≤280px): workspace selector + folder tree
 *   Right: document list with search + "+ New doc"
 *
 * FolderTree: built here (not reusing FileTree) because FileTree is
 * tightly coupled to workspaceTreeQuery / FileTreeNode from the
 * workspace domain and uses path-based identity. Doc folders use
 * id-based identity and have a flat-recursive shape from the backend.
 * A thin inline FolderTree avoids a cross-domain coupling violation.
 *
 * CSS prefix: dl- (docs list)
 */

import {
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from "@tanstack/svelte-query";
import { FileText, FolderOpen, Search } from "lucide-svelte";
import { untrack } from "svelte";
import { writable } from "svelte/store";
import { goto } from "$app/navigation";
import {
  bodyJsonFromText,
  createDocumentMutation,
  documentsQuery,
  folderTreeQuery,
  searchDocumentsQuery,
} from "$lib/api/queries/docs.js";
import { workspacesQuery } from "$lib/api/queries/workspaces.js";
import EmptyState from "$lib/design/patterns/EmptyState.svelte";
import SkeletonList from "$lib/design/patterns/SkeletonList.svelte";
import type {
  CreateDocumentBody,
  DocFilters,
  Document,
  FolderTreeNode,
} from "$lib/domain/docs/types.js";
import type { Workspace } from "$lib/domain/workspaces/types.js";
import { ui } from "$lib/stores/ui.svelte.js";
import { toasts } from "$lib/stores/toasts.svelte.js";

const queryClient = useQueryClient();

// ── Workspace selector ────────────────────────────────────────────────────────

const wsOptsStore = writable(
  untrack(() => workspacesQuery() as CreateQueryOptions<Workspace[]>),
);
const wsQuery = createQuery<Workspace[]>(wsOptsStore);
const workspaces = $derived(($wsQuery.data ?? []) as Workspace[]);

let selectedWorkspace = $state(ui.currentWorkspaceSlug ?? "");

$effect(() => {
  if (!selectedWorkspace && workspaces.length > 0) {
    selectedWorkspace = workspaces[0].slug;
  }
});

// ── Folder tree ───────────────────────────────────────────────────────────────

const treeOptsStore = writable(
  untrack(() => folderTreeQuery(selectedWorkspace) as CreateQueryOptions<FolderTreeNode[]>),
);
$effect(() => {
  treeOptsStore.set(folderTreeQuery(selectedWorkspace) as CreateQueryOptions<FolderTreeNode[]>);
});
const treeQ = createQuery<FolderTreeNode[]>(treeOptsStore);

let selectedFolderId = $state<string | null>(null);
let expandedFolders = $state(new Set<string>());

function toggleFolder(id: string): void {
  const next = new Set(expandedFolders);
  next.has(id) ? next.delete(id) : next.add(id);
  expandedFolders = next;
}

// ── Search ────────────────────────────────────────────────────────────────────

let rawSearch = $state("");
let searchDebounced = $state("");
let debounceTimer = $state<ReturnType<typeof setTimeout> | null>(null);

$effect(() => {
  const val = rawSearch;
  if (debounceTimer !== null) clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => {
    searchDebounced = val;
  }, 300);
});

const isSearching = $derived(searchDebounced.trim().length > 0);

const searchOptsStore = writable(
  untrack(
    () =>
      searchDocumentsQuery(selectedWorkspace, searchDebounced) as CreateQueryOptions<Document[]>,
  ),
);
$effect(() => {
  searchOptsStore.set(
    searchDocumentsQuery(selectedWorkspace, searchDebounced) as CreateQueryOptions<Document[]>,
  );
});
const searchQ = createQuery<Document[]>(searchOptsStore);

// ── Document list ─────────────────────────────────────────────────────────────

const filters = $derived<DocFilters>({
  workspace: selectedWorkspace || undefined,
  folderId: selectedFolderId ?? undefined,
});

const docsOptsStore = writable(
  untrack(() => documentsQuery(filters) as CreateQueryOptions<Document[]>),
);
$effect(() => {
  docsOptsStore.set(documentsQuery(filters) as CreateQueryOptions<Document[]>);
});
const docsQ = createQuery<Document[]>(docsOptsStore);

const docs = $derived(
  isSearching
    ? (($searchQ.data ?? []) as Document[])
    : (($docsQ.data ?? []) as Document[]),
);
const isLoading = $derived(isSearching ? $searchQ.isLoading : $docsQ.isLoading);
const isError = $derived(isSearching ? $searchQ.isError : $docsQ.isError);

// ── Create document ───────────────────────────────────────────────────────────

const createMut = createMutation<Document, Error, CreateDocumentBody>({
  ...createDocumentMutation(),
  onSuccess: (doc) => {
    queryClient.invalidateQueries({ queryKey: ["docs"] });
    goto(`/docs/${doc.id}`);
  },
  onError: (err) => {
    toasts.error(`Failed to create document: ${err.message}`);
  },
});

function handleNewDoc(): void {
  if (!selectedWorkspace) {
    toasts.error("Select a workspace first.");
    return;
  }
  $createMut.mutate({
    workspaceSlug: selectedWorkspace,
    title: "Untitled",
    bodyJson: bodyJsonFromText(""),
    bodyText: "",
    folderId: selectedFolderId ?? null,
    tags: [],
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });
}
</script>

<div class="dl-shell">
  <!-- Left pane: workspace selector + folder tree -->
  <aside class="dl-sidebar" aria-label="Docs navigation">
    <!-- Workspace selector -->
    <div class="dl-ws-wrap">
      <label class="dl-ws-label" for="dl-ws-select">Workspace</label>
      <select
        id="dl-ws-select"
        class="dl-ws-select"
        bind:value={selectedWorkspace}
        aria-label="Select workspace"
      >
        {#each workspaces as ws (ws.slug)}
          <option value={ws.slug}>{ws.name}</option>
        {/each}
      </select>
    </div>

    <!-- Folder tree -->
    <div class="dl-tree-header">
      <span class="dl-tree-label">Folders</span>
    </div>

    <nav class="dl-tree" aria-label="Document folders">
      <!-- All docs shortcut -->
      <button
        class="dl-folder-row"
        class:dl-folder-row--active={selectedFolderId === null}
        onclick={() => { selectedFolderId = null; }}
        aria-pressed={selectedFolderId === null}
      >
        <FolderOpen size={13} aria-hidden="true" />
        <span class="dl-folder-name">All documents</span>
      </button>

      {#if $treeQ.isLoading}
        <div class="dl-tree-skeleton">
          {#each { length: 4 } as _, i (i)}
            <div class="dl-sk" style="width: {55 + (i % 3) * 15}%"></div>
          {/each}
        </div>
      {:else if $treeQ.data}
        {#each $treeQ.data as folder (folder.id)}
          {@render folderNode(folder, 0)}
        {/each}
      {/if}
    </nav>
  </aside>

  <!-- Right pane: document list -->
  <main class="dl-main">
    <!-- Top bar -->
    <header class="dl-topbar">
      <div class="dl-search-wrap">
        <Search size={13} class="dl-search-icon" aria-hidden="true" />
        <input
          class="dl-search"
          type="search"
          placeholder="Search docs…"
          bind:value={rawSearch}
          aria-label="Search documents"
          autocomplete="off"
          spellcheck={false}
        />
      </div>
      <button
        class="btn-pill btn-pill-primary btn-pill-sm dl-new-btn"
        onclick={handleNewDoc}
        disabled={!selectedWorkspace || $createMut.isPending}
        aria-label="Create new document"
      >
        + New doc
      </button>
    </header>

    <!-- Doc list -->
    {#if isError}
      <EmptyState
        title="Couldn't load documents"
        body="Check your connection and try again."
        action="Retry"
        onAction={() => isSearching ? $searchQ.refetch() : $docsQ.refetch()}
      />
    {:else if isLoading}
      <div class="dl-skeleton-wrap">
        <SkeletonList count={6} height="3.5rem" gap="0.375rem" />
      </div>
    {:else if docs.length === 0}
      <EmptyState
        icon={FileText as never}
        title={isSearching ? "No results" : "No documents yet"}
        body={isSearching ? `Nothing matched "${searchDebounced}".` : "Create your first document above."}
      />
    {:else}
      <ul class="dl-list" role="list">
        {#each docs as doc (doc.id)}
          <li class="dl-item">
            <!-- svelte-ignore a11y_interactive_supports_focus -->
            <button
              class="dl-doc-row"
              role="button"
              onclick={() => goto(`/docs/${doc.id}`)}
              aria-label="Open {doc.title}"
            >
              <div class="dl-doc-main">
                <span class="dl-doc-title">{doc.title || "Untitled"}</span>
                {#if doc.tags.length > 0}
                  <div class="dl-tags" aria-label="Tags">
                    {#each doc.tags as tag (tag)}
                      <span class="dl-tag">{tag}</span>
                    {/each}
                  </div>
                {/if}
              </div>
              <div class="dl-doc-meta">
                <span class="dl-doc-author">{doc.authorId}</span>
                <time class="dl-doc-date" datetime={doc.updatedAt}>{formatDate(doc.updatedAt)}</time>
                {#if doc.published}
                  <span class="dl-badge dl-badge--pub">Published</span>
                {:else}
                  <span class="dl-badge dl-badge--draft">Draft</span>
                {/if}
              </div>
            </button>
          </li>
        {/each}
      </ul>
    {/if}
  </main>
</div>

{#snippet folderNode(folder: FolderTreeNode, depth: number)}
  <div class="dl-folder-group" style="--depth: {depth}">
    <button
      class="dl-folder-row"
      class:dl-folder-row--active={selectedFolderId === folder.id}
      onclick={() => {
        selectedFolderId = folder.id;
        if (folder.children.length > 0) toggleFolder(folder.id);
      }}
      aria-pressed={selectedFolderId === folder.id}
      aria-expanded={folder.children.length > 0 ? expandedFolders.has(folder.id) : undefined}
    >
      <FolderOpen size={13} aria-hidden="true" />
      <span class="dl-folder-name">{folder.name}</span>
      {#if folder.children.length > 0}
        <span class="dl-folder-chevron" class:dl-folder-chevron--open={expandedFolders.has(folder.id)} aria-hidden="true">›</span>
      {/if}
    </button>
    {#if expandedFolders.has(folder.id)}
      {#each folder.children as child (child.id)}
        {@render folderNode(child, depth + 1)}
      {/each}
    {/if}
  </div>
{/snippet}

<style>
  .dl-shell {
    display: flex;
    height: 100%;
    overflow: hidden;
  }

  /* ── Sidebar ── */
  .dl-sidebar {
    width: 260px;
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    border-right: 1px solid var(--border);
    background: var(--bg-inset);
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .dl-ws-wrap {
    padding: var(--space-3);
    border-bottom: 1px solid var(--border);
  }

  .dl-ws-label {
    display: block;
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--fg-subtle);
    margin-bottom: var(--space-1);
  }

  .dl-ws-select {
    width: 100%;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-1) var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    cursor: pointer;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .dl-ws-select:focus {
    border-color: var(--border-strong);
  }

  .dl-tree-header {
    padding: var(--space-3) var(--space-3) var(--space-1);
  }

  .dl-tree-label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--fg-subtle);
  }

  .dl-tree {
    flex: 1;
    padding: var(--space-1) var(--space-2) var(--space-3);
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .dl-folder-group {
    display: flex;
    flex-direction: column;
    gap: 1px;
    padding-left: calc(var(--depth, 0) * 12px);
  }

  .dl-folder-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    width: 100%;
    padding: var(--space-1) var(--space-2);
    background: transparent;
    border: none;
    border-radius: var(--radius-sm);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    text-align: left;
    min-height: 28px;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .dl-folder-row:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .dl-folder-row--active {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
    font-weight: 500;
  }

  .dl-folder-name {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .dl-folder-chevron {
    font-size: 14px;
    color: var(--fg-subtle);
    transition: transform var(--dur-instant) var(--ease-out);
    display: inline-block;
  }

  .dl-folder-chevron--open {
    transform: rotate(90deg);
  }

  .dl-tree-skeleton {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-2);
  }

  .dl-sk {
    height: 12px;
    background: var(--border);
    border-radius: var(--radius-sm);
    animation: dl-pulse 1.5s ease-in-out infinite;
  }

  @keyframes dl-pulse {
    0%,
    100% {
      opacity: 0.3;
    }
    50% {
      opacity: 0.6;
    }
  }

  /* ── Main pane ── */
  .dl-main {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .dl-topbar {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-4);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .dl-search-wrap {
    flex: 1;
    position: relative;
    display: flex;
    align-items: center;
  }

  :global(.dl-search-icon) {
    position: absolute;
    left: var(--space-2);
    color: var(--fg-subtle);
    pointer-events: none;
  }

  .dl-search {
    width: 100%;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-1) var(--space-2) var(--space-1) calc(var(--space-2) + 20px);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .dl-search:focus {
    border-color: var(--border-strong);
  }

  .dl-search::placeholder {
    color: var(--fg-subtle);
  }

  .dl-new-btn {
    flex-shrink: 0;
  }

  .dl-skeleton-wrap {
    padding: var(--space-4);
    flex: 1;
  }

  /* ── Doc list ── */
  .dl-list {
    list-style: none;
    margin: 0;
    padding: var(--space-2) var(--space-2);
    flex: 1;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .dl-item {
    display: contents;
  }

  .dl-doc-row {
    display: flex;
    align-items: center;
    gap: var(--space-4);
    width: 100%;
    padding: var(--space-2) var(--space-3);
    background: transparent;
    border: none;
    border-radius: var(--radius-md);
    cursor: pointer;
    text-align: left;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .dl-doc-row:hover {
    background: color-mix(in oklch, var(--fg) 5%, transparent 95%);
  }

  .dl-doc-main {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .dl-doc-title {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .dl-tags {
    display: flex;
    gap: var(--space-1);
    flex-wrap: wrap;
  }

  .dl-tag {
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 1px 5px;
  }

  .dl-doc-meta {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    flex-shrink: 0;
  }

  .dl-doc-author,
  .dl-doc-date {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    white-space: nowrap;
  }

  .dl-badge {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 500;
    padding: 1px 6px;
    border-radius: var(--radius-sm);
    white-space: nowrap;
  }

  .dl-badge--pub {
    background: color-mix(in oklch, green 20%, transparent 80%);
    color: color-mix(in oklch, green 80%, var(--fg) 20%);
    border: 1px solid color-mix(in oklch, green 30%, transparent 70%);
  }

  .dl-badge--draft {
    background: var(--bg-inset);
    color: var(--fg-subtle);
    border: 1px solid var(--border);
  }
</style>
