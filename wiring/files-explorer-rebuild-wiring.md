> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Files Explorer Rebuild — Wiring

**Status:** Frontend rebuild delivered. Backend untouched (existing
`/api/v1/workspaces/:slug/files` is sufficient).
**Owner:** main agent (integrates), frontend agent (this dispatch authored
the new primitives + page rewrite).

The `/files` route was previously a cloud-bucket upload UI (BUCKETS panel +
"Drop files here to upload" empty state). It has been rebuilt as a **project
explorer** that mirrors the active workspace's `root_path` filesystem — the
correct UX for Canopy's local-first, workspace-centric model.

---

## 1. Files added

### 1a. Foundation primitive — single source of truth for tree rendering

| Path | Role |
|------|------|
| `desktop/src/lib/design/foundation/file-tree/FileTree.svelte` | Top-level tree primitive. Owns expansion + selection state. Lazy-fetches root entries via `directoryListingQuery(slug, "")`. |
| `desktop/src/lib/design/foundation/file-tree/FileTreeNode.svelte` | Recursive row primitive. Lazy-fetches children when expanded. |
| `desktop/src/lib/design/foundation/file-tree/index.ts` | Barrel export. |
| `desktop/src/lib/design/foundation/file-tree/FileTree.test.ts` | Vitest covering: lazy load, selection, file-select callback, hidden-file toggle. |

### 1b. /files page module-local primitives

| Path | Role |
|------|------|
| `desktop/src/lib/design/patterns/files/FilesWorkspacePicker.svelte` | Left-pane workspace list. Calls `activeWorkspace.setActive(slug)` on click and mirrors to `ui.setCurrentWorkspace` for legacy components. |
| `desktop/src/lib/design/patterns/files/FileSearchBar.svelte` | Top-bar search; on Enter calls `ui.openKeywordSearch()` to invoke the existing `KeywordSearchDialog` overlay. |

## 2. Files edited

| Path | Edit |
|------|------|
| `desktop/src/routes/files/+page.svelte` | **Full rewrite.** Was 1,300+ LOC of bucket-upload UI; now a 350-LOC project explorer that composes `FilesWorkspacePicker` + `FileTree` + `FileViewerPane`. |
| `desktop/src/lib/design/patterns/build/sections/ProjectExplorerSection.svelte` | Surgical rewrite — replaced the inline tree code with `import FileTree from "$lib/design/foundation/file-tree/FileTree.svelte"`. The Build rail and the /files page now share the same renderer. |

## 3. Reused primitives — NO duplicates

| Need | Reused module |
|------|---------------|
| File-tree rendering | `desktop/src/lib/design/foundation/file-tree` (the new shared primitive). Both /files and the Build rail's `ProjectExplorerSection` import from it. |
| Active workspace state | `desktop/src/lib/stores/active-workspace.svelte.ts` (existing singleton). `slug` / `name` / `rootPath` reactive. |
| Workspace list | `workspacesQuery()` from `$lib/api/queries/workspaces.js`. |
| Per-folder lazy listing | `directoryListingQuery(slug, path)` from `$lib/api/queries/file-tree.ts`. **Not** `getFileTree()` — keeps the cache one-key-per-folder. |
| File preview rendering | `FileViewerPane.svelte` from `$lib/design/patterns/mosaic/panes` (with all sub-viewers: MarkdownViewer, CodeViewer, JsonTreeViewer, CsvTableViewer, ImageViewer, MediaViewer, LogViewer, HexPreview, PdfViewer, DocxViewer, XlsxViewer). |
| Workspace search overlay | `KeywordSearchDialog.svelte` (existing) via `ui.openKeywordSearch()`. |
| Per-workspace persisted state | `useWorkspaceState<T>(key, default)` from `$lib/api/queries/workspace-states.js`. |
| Toast notifications | `toast.info(...)` from `$lib/design/foundation/toast/toast.js`. |
| Icons | `lucide-svelte` (`FolderOpen`, `Folder`, `File`, `ChevronRight`, `Plus`, `RefreshCw`, `Search`). |

## 4. Backend

**No changes.** All file listings flow through the existing endpoint:

```
GET /api/v1/workspaces/:slug/files?path=<dir>
→ Canopy.Workspaces.Files.list_directory/2
→ DirEntry[]
```

File contents flow through:

```
GET /api/v1/workspaces/:slug/files/*path
→ Canopy.Workspaces.Files.read_file/2
→ FileReadResponse
```

## 5. Persistence — expanded-paths memory

The /files page persists which folders are expanded across reloads via:

```ts
const expanded = useWorkspaceState<string[]>("files.expandedPaths", []);
```

Storage key: `files.expandedPaths` in the existing `workspace_states` table
(see `wiring/active-workspace-wiring.md`). One row per workspace. On
`onFolderToggle` the page debounces a PUT (500 ms via the hook's built-in
debounce) so rapid open/close doesn't flood the backend.

## 6. FileTree primitive — public contract

Other modules that need a workspace file tree should import from
`$lib/design/foundation/file-tree`:

```svelte
<script lang="ts">
  import FileTree from "$lib/design/foundation/file-tree/FileTree.svelte";
  import type { DirEntry } from "$lib/domain/workspaces/types.js";

  let treeRef = $state<FileTree | null>(null);

  function handleSelect(e: DirEntry): void { /* … */ }
  function handleToggle(path: string, expanded: boolean): void { /* … */ }
</script>

<FileTree
  bind:this={treeRef}
  workspaceSlug={slug}
  onFileSelect={handleSelect}
  onFolderToggle={handleToggle}
  initialExpanded={["src", "src/lib"]}
  initialSelected={null}
  hideHidden={true}
  onDragStart={(entry, ev) => { /* serialize whatever payload you need */ }}
/>
```

Imperative API (via `bind:this`):

| Method | Behaviour |
|--------|-----------|
| `refresh()` | Re-fetch root listing. Children re-fetch when their queries are re-enabled. |
| `clearSelection()` | Clears the highlighted row. |

Other consumers identified for the same primitive:

1. **Build rail's `ProjectExplorerSection`** — already migrated as part of
   this dispatch.
2. **AgentConversationPane's file-picker chip** — when the chip wants to
   surface the workspace tree, it should mount this primitive in a popover
   rather than reimplementing a tree. (Not migrated here — owned by the
   agent-conversation agent.)

## 7. Old code — archive note (NOT deleted)

The old bucket-style `/files` page was a full rewrite, so the bucket UI
code is gone from `+page.svelte`. The supporting query factories that
powered it still exist and are still used by other surfaces:

| Module | Status | Used by |
|--------|--------|---------|
| `desktop/src/lib/api/queries/files.ts` (`filesQuery`, `uploadFileMutation`, `searchFilesQuery`, `scanWorkspaceMutation`, `fileIcon`, `formatBytes`) | KEEP | `/files/[id]` (file detail), KeywordSearchDialog, FilePreview, future re-introduction of upload UI in a different surface. The new tree imports `fileIcon` from this module. |
| Bucket-style CSS prefix `fb-` | REMOVED | Lived only inside the old `/files/+page.svelte`. |
| `EmptyState`, `SkeletonList`, `Table` patterns | KEEP | Used elsewhere across the app. |

**Follow-up cleanup flagged:** when upload functionality is reintroduced
(it is intentionally absent in the project-explorer model — Canopy is
local-first, files arrive on disk), rebuild it as a separate surface
(e.g. `/files/upload` or a drag-target inside FileTree) rather than
restoring the bucket layout.

## 8. TODOs / follow-ups

| Item | Why deferred |
|------|--------------|
| **Virtualization for >10k entries** | Out of scope for v1. Current FileTree shows a hint when a directory exceeds 500 entries; large directories scroll natively. Wire `@tanstack/svelte-virtual` when this becomes a real bottleneck. |
| **Hidden-file toggle UI** | Prop is wired (`hideHidden`); UI surface (a toggle next to the search bar) is deferred. Default is `true`. |
| **New file inline creation** | `handleNewFile` shows a toast pointing to CodeEditorPane. Real inline-create needs a backend write-file endpoint flow + name-input affordance — separate dispatch. |
| **FS error → toast + retry** | Implemented at the tree-root level (Retry button on root error) and via the FileTreeNode's per-folder error message. A finer-grained "permission denied → toast" wrapper around `listDir()` is a follow-up. |
| **AgentConversationPane file-picker chip migration** | Owned by another agent; this dispatch only documented the contract. |

## 9. Constraints honoured

- Did not touch `AgentConversationPane.svelte`, `ConversationComposer.svelte`,
  `ComposerChips.svelte`, or `panes/agent-conversation/*`.
- Did not modify the backend.
- No new dependencies.
- No competitor brand names anywhere in code or docs.
- Svelte 5 runes everywhere; TanStack Query for all fetches; foundation
  primitives reused, not duplicated.
