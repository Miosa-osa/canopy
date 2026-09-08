> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Build Side Rail — wiring instructions

Mounts the 4-section left rail (Tabs / Project Explorer / Search / Drive) inside the `/build` route. Apply by hand in the indicated shared files — the rail module is forbidden from editing them directly.

## 1. `/build/+page.svelte` — mount the rail at the slot

The Build page is being built in parallel and exposes a slot at `id="build-side-rail-slot"`. Replace that slot wiring with a real mount:

```svelte
<script lang="ts">
  import BuildSideRail from "$lib/design/patterns/build/BuildSideRail.svelte";

  // Resolve the active workspace however the Build page already does
  // (e.g. via $page.url query, a workspace store, or a route param).
  let workspaceSlug = $state("default");
</script>

<div class="build-page">
  <BuildSideRail {workspaceSlug} />

  <main class="build-main">
    <!-- Mosaic / tile content owned by the Build dispatch -->
  </main>
</div>

<style>
  .build-page {
    display: flex;
    height: 100%;
    min-height: 0;
  }

  .build-main {
    flex: 1;
    min-width: 0;
    overflow: hidden;
  }
</style>
```

The rail handles its own width:

- Collapsed: 40px (icon column only).
- Expanded: 320px total (40px column + 280px panel).

It manages collapse/expand state internally via `$lib/stores/build-rail.svelte.ts` (persisted to `localStorage["canopy.build.sideRail.section"]`).

## 2. Backend endpoints required

The rail consumes 1 endpoint that already exists and 2 that the parallel dispatches are responsible for delivering.

### 2.1 EXISTS — Workspace files

Used by `ProjectExplorerSection` (lazy directory listing per folder).

```
GET /api/v1/workspaces/:slug/files?path=<dir>
→ DirEntry[]
```

Already shipped via `Canopy.Workspaces.Files.list_directory/2`. No backend changes needed.

### 2.2 NEW — Cross-file ripgrep search

Consumed by `SearchSection`. Until this lands the section shows `Search backend pending` and the regex / case toggles + input still work.

```
GET /api/v1/search?q=<term>
                  &workspace_slug=<slug>
                  &regex=true|false
                  &case_sensitive=true|false
                  &limit=<n>

→ Phoenix envelope: { data: SearchHit[] }
  SearchHit = {
    file_path: string         # workspace-relative
    line_number: integer      # 1-indexed
    line_text: string         # full line
    match_start: integer      # 0-indexed byte offset within line_text
    match_end: integer        # exclusive end offset
  }
```

Notes:
- 404 is treated as "backend pending" — the rail degrades gracefully.
- Other non-2xx errors propagate to TanStack Query and show `Search failed`.
- Recommend backing this with `rg --json --line-number --column` parsed server-side and capped by `limit` (default 100).
- `Canopy.Search.BlockSearch` is a candidate implementation point per the Block primitive plan.

### 2.3 NEW — Drive tree (owned by Drive dispatch)

Consumed by `DriveSection`.

```
GET /api/v1/drive/tree?scope=personal|team

→ Phoenix envelope: { data: DriveTreeNode[] }
  DriveTreeNode = {
    entry: DriveEntry
    children: DriveTreeNode[]
  }
```

`DriveEntry` and `DriveTreeNode` already typed in `desktop/src/lib/domain/drive/types.ts`. 404 → `Drive backend pending` empty state.

The Drive dispatch is responsible for shipping the endpoint plus the `/drive` route — the rail is a read-only consumer.

## 3. Keyboard shortcuts (already wired inside the component)

The rail attaches a global `keydown` listener via `<svelte:window>` for these chords:

| Key   | Action                          |
|-------|---------------------------------|
| `Esc` | Collapse (when expanded)        |
| `⌘1`  | Open / focus Tabs section       |
| `⌘2`  | Open / focus Project Explorer   |
| `⌘3`  | Open / focus Search             |
| `⌘4`  | Open / focus Drive              |

If the host page already binds `⌘1..⌘4` for higher-level navigation, lift the listener to the page and call `buildRail.open(section)` / `buildRail.collapse()` directly:

```ts
import { buildRail } from "$lib/stores/build-rail.svelte.js";
// then: buildRail.open("explorer"); buildRail.collapse();
```

## 4. Drag-and-drop integration

The rail emits drag payloads via `dataTransfer.setData("application/x-canopy-rail", JSON.stringify(payload))`.

Two payload shapes:

```ts
// From Project Explorer (a file):
{
  kind: "build-rail/file",
  workspaceSlug: string,
  path: string,
  name: string,
}

// From Drive section (an entry):
{
  kind: "build-rail/drive-entry",
  driveKind: DriveKind,
  entryId: string,
  slug: string,
  name: string,
  scope: DriveScope,
}
```

For Mosaic tiles to accept these drops, add a `dragover` / `drop` handler to `MosaicTile.svelte` (or a thin wrapper) that:

1. Reads `event.dataTransfer.getData("application/x-canopy-rail")`.
2. Parses the JSON.
3. Dispatches based on `kind`:
   - `build-rail/file` → `mosaicLayout.openPane({ kind: "file", ref: "path:<slug>:<path>", ... }, tileId)`.
   - `build-rail/drive-entry` with `driveKind === "workflow"` → open a Terminal pane and queue the workflow's commands (requires a Terminal pane primitive that accepts an init command list — out of scope for this rail).
   - Other Drive kinds → open a Doc / Prompt / Notebook pane per the existing PaneContent dispatcher.

Until the Mosaic side accepts these payloads, drags from the rail are no-ops at the drop site (no error — `dataTransfer.setData` is harmless on its own).

## 5. Pane-kind extension (optional, future)

`SearchSection` opens hits as `kind: "file"` panes with refs encoded as `path:<slug>:<path>#L<line>`. A line-aware `FileViewerPane` requires extending `PaneContent.svelte` to parse the `#L<n>` suffix and pass it through to `FileViewerPane` as a `line` config field. Coordinate this with the existing File Viewer wiring (`wiring/file-viewer-wiring.md`).

## 6. No competitor / shared-file edits

The rail is fully self-contained inside `desktop/src/lib/design/patterns/build/` plus the new store + 2 query factories. No changes to `Sidebar.svelte`, `MosaicTile.svelte`, or any other shared file have been made — all integration points are listed above and must be applied by the parallel dispatches that own those files.
