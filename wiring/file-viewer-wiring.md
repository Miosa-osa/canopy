> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# File Viewer pane — wiring instructions

These changes are required in shared files that the File Viewer module is forbidden from editing directly. Apply by hand (or via a follow-up agent that owns the shared files).

## 1. Pane manifest

Register the new pane type in the Mosaic catalog. The manifest object:

```ts
{
  paneType: "file_viewer",
  label: "File Viewer",
  icon: "FileText",            // lucide-svelte
  defaultConfig: {
    fileId: undefined,         // FileRecord id (preferred)
    path: undefined,           // workspace-relative path
    workspaceSlug: "default",  // required when addressing by path
  },
}
```

`paneType` must be `"file_viewer"` to avoid collision with the legacy `kind: "file"` pane that maps to `FilePreview` directly.

## 2. mosaic-layout store — add the new PaneKind

In `desktop/src/lib/stores/mosaic-layout.svelte.ts`, extend the `PaneKind` union:

```ts
export type PaneKind =
  | "session"
  | "issue"
  | "task"
  | "doc"
  | "file"          // ← legacy, kept for back-compat
  | "file_viewer"   // ← NEW: universal read-only viewer
  | "terminal"
  | "changes"
  | "knowledge";
```

The `Pane.ref` field carries the addressing payload. For `file_viewer`, encode `ref` as either:
- A bare `fileId` string, OR
- `"path:<slug>:<path>"` when addressing by workspace path.

The dispatcher in PaneContent (below) parses this.

## 3. PaneContent.svelte — switch case

In `desktop/src/lib/design/patterns/mosaic/PaneContent.svelte`, add the new branch (replace the existing legacy `kind === "file"` stub if desired, or keep both):

```svelte
{:else if pane.kind === 'file_viewer'}
  {#await import('$lib/design/patterns/mosaic/panes/FileViewerPane.svelte')}
    <div class="pc-stub pc-stub--loading">Loading file viewer…</div>
  {:then { default: FileViewerPane }}
    <FileViewerPane config={parseFileViewerRef(pane.ref)} />
  {:catch}
    <div class="pc-stub">File viewer not available.</div>
  {/await}
```

And add this helper to the script block:

```ts
import type { FileViewerPaneConfig } from '$lib/domain/file-viewer/types.js';

function parseFileViewerRef(ref: string): FileViewerPaneConfig {
  if (ref.startsWith('path:')) {
    const [, slug, ...rest] = ref.split(':');
    return { workspaceSlug: slug, path: rest.join(':') };
  }
  return { fileId: ref };
}
```

## 4. PanePicker.svelte — add picker entry

In `desktop/src/lib/design/patterns/mosaic/PanePicker.svelte`:

1. Extend `KIND_LABELS` to include the new kind:

   ```ts
   const KIND_LABELS: Record<PaneKind, string> = {
     session: 'Session', issue: 'Issue', task: 'Task', doc: 'Doc',
     file: 'File', file_viewer: 'File Viewer',
     terminal: 'Terminal', changes: 'Changes', knowledge: 'Knowledge',
   };
   ```

2. Add a stub catalog entry (or replace the existing `file` row):

   ```ts
   { id: 'fv1', kind: 'file_viewer', ref: 'src/main.ts',
     title: 'File Viewer: src/main.ts',
     description: 'Universal file viewer' },
   ```

   For path-based opens, set `ref: 'path:default:src/main.ts'`.

## 5. Existing viewers consolidated behind FileViewerPane

The pane wraps these existing viewers — none are reimplemented:

| Viewer subcomponent | Existing impl reused | Path |
|---|---|---|
| `MarkdownViewer.svelte` | `renderMarkdown()` | `desktop/src/lib/utils/markdown.ts` |
| `CodeViewer.svelte` | Shiki dynamic-import pattern (mirrors DiffViewer) | `desktop/src/lib/design/patterns/diff/DiffViewer.svelte` (reference) |
| `JsonTreeViewer.svelte` | Pure DOM (no library); optional `js-yaml` for YAML parse | — |
| `CsvTableViewer.svelte` | Inline RFC-4180 parser; pure DOM | — |
| `ImageViewer.svelte` | Native `<img>` + zoom/pan | — |
| `MediaViewer.svelte` | Native `<video>` / `<audio>` | (mirrors `FilePreview.svelte` audio/video branches) |
| `LogViewer.svelte` | Pure DOM, follow-tail effect | — |
| `HexPreview.svelte` | Pure DOM, ASCII gutter | — |
| `PdfViewer.svelte` | **REUSE-WRAPPER** around the inline PDF render | `desktop/src/lib/design/patterns/FilePreview.svelte` (`viewer === 'pdf'` branch — pdfjs-dist) |
| `DocxViewer.svelte` | **REUSE-WRAPPER** around the inline DOCX render | `desktop/src/lib/design/patterns/FilePreview.svelte` (`viewer === 'docx'` branch — docx-preview) |
| `XlsxViewer.svelte` | **REUSE-WRAPPER** around the inline XLSX render | `desktop/src/lib/design/patterns/FilePreview.svelte` (`viewer === 'xlsx'` branch — SheetJS) |

When the inline `FilePreview` impls are extracted into their own files, swap the `import FilePreview` line in the three wrappers.

## 6. Optional dependency: js-yaml

`JsonTreeViewer.svelte` supports YAML through an optional dynamic import:

```ts
const yaml = await import('js-yaml');
```

If `js-yaml` is not installed, YAML files render an inline error message ("YAML parser not installed — install js-yaml to enable tree view.") inside the tree viewer. The build does not fail.

To enable: `pnpm add js-yaml @types/js-yaml --filter desktop`.

## 7. Shiki — already available

`shiki@^4.0.2` is already a dependency of the desktop package (used by `DiffViewer.svelte`). `CodeViewer.svelte` reuses the same dynamic-import + `github-dark-dimmed` theme pattern. No new dep required.

If Shiki ever fails to load (offline, sandboxed), `CodeViewer` falls back to a plain line-numbered `<pre>`. Build never breaks.

## 8. API endpoints — already available

The pane uses:
- `GET /api/v1/files/:id` (metadata) via existing `fileQuery()` in `desktop/src/lib/api/queries/files.ts`
- `GET /api/v1/files/:id/content` (bytes/text) via the `API_BASE` URL
- `GET /api/v1/workspaces/:slug/files/*path` (text) via existing `workspaceFileQuery()` in `desktop/src/lib/api/queries/workspaces.ts`

No new endpoints required.

## 9. Files added by this module (read-only summary)

```
desktop/src/lib/domain/file-viewer/types.ts
desktop/src/lib/api/queries/file-viewer.ts
desktop/src/lib/design/patterns/mosaic/panes/FileViewerPane.svelte
desktop/src/lib/design/patterns/mosaic/panes/file-viewer/detect-type.ts
desktop/src/lib/design/patterns/mosaic/panes/file-viewer/detect-type.test.ts
desktop/src/lib/design/patterns/mosaic/panes/file-viewer/MarkdownViewer.svelte
desktop/src/lib/design/patterns/mosaic/panes/file-viewer/CodeViewer.svelte
desktop/src/lib/design/patterns/mosaic/panes/file-viewer/JsonTreeViewer.svelte
desktop/src/lib/design/patterns/mosaic/panes/file-viewer/CsvTableViewer.svelte
desktop/src/lib/design/patterns/mosaic/panes/file-viewer/ImageViewer.svelte
desktop/src/lib/design/patterns/mosaic/panes/file-viewer/MediaViewer.svelte
desktop/src/lib/design/patterns/mosaic/panes/file-viewer/LogViewer.svelte
desktop/src/lib/design/patterns/mosaic/panes/file-viewer/HexPreview.svelte
desktop/src/lib/design/patterns/mosaic/panes/file-viewer/PdfViewer.svelte
desktop/src/lib/design/patterns/mosaic/panes/file-viewer/DocxViewer.svelte
desktop/src/lib/design/patterns/mosaic/panes/file-viewer/XlsxViewer.svelte
```

No shared files were modified during this build. Wiring above is required for the pane to be reachable from the Mosaic UI.
