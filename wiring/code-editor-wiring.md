# Code Editor pane wiring

This file describes the surgical edits the main agent (or a follow-up
PR) must apply to shared Mosaic files to bring **CodeEditorPane**
online. All module-local files are already created. Only shared edits
remain. **No new backend files** are introduced — the pane reuses the
existing files / workspace-files API surface.

## Files already created (module-local — no shared edits needed)

### Frontend
| Path | Role |
|------|------|
| `desktop/src/lib/domain/code-editor/types.ts` | Domain types: `CodeEditorPaneConfig`, `CodeEditorPaneManifest`, `CodeLanguage`, `languageFromExtension`, `EDIT_SIZE_CAP_BYTES` |
| `desktop/src/lib/api/queries/code-editor.ts` | TanStack Query factories: `codeEditorContentQuery` (re-export), `codeEditorMetadataQuery` (re-export), `saveCodeFileMutation`, `isResolvable`, `isSaveable` |
| `desktop/src/lib/design/patterns/mosaic/panes/code-editor/save-state.svelte.ts` | Svelte 5 runes class `CodeEditorSaveState` + pure helpers `computeDirty`, `normalizeNewlines`, `dirtyTitleMarker` |
| `desktop/src/lib/design/patterns/mosaic/panes/code-editor/extensions.ts` | Language detection + Shiki language map + theme + `buildExtensions()` stub for the future CodeMirror upgrade |
| `desktop/src/lib/design/patterns/mosaic/panes/CodeEditorPane.svelte` | The pane itself — textarea + Shiki overlay, ⌘S save, ⌘F find/replace, dirty indicator, optimistic UI + rollback |

### Tests
| Path | Role |
|------|------|
| `desktop/src/lib/design/patterns/mosaic/panes/code-editor/save-state.test.ts` | Vitest unit tests for `computeDirty`, `normalizeNewlines`, `dirtyTitleMarker`, and dirty-tracking lifecycle simulations |
| `desktop/src/lib/design/patterns/mosaic/panes/CodeEditorPane.test.ts` | Contract-level tests: language detection, `isResolvable` / `isSaveable`, mutation key shape, Shiki preload completeness |

### Backend
**None.** The pane uses the existing endpoints — see "Backend gap" below.

## Reused primitives (no duplicate modules introduced)

| Need | Reused module / endpoint |
|------|--------------------------|
| Read text content | `workspaceFileQuery(slug, path)` from `desktop/src/lib/api/queries/workspaces.ts` (re-exported as `codeEditorContentQuery`) |
| File metadata | `fileQuery(id)` from `desktop/src/lib/api/queries/files.ts` (re-exported as `codeEditorMetadataQuery`) |
| Read endpoint | `GET /api/v1/workspaces/:slug/files/*path` (existing) |
| Save endpoint | `PUT /api/v1/workspaces/:slug/files/*path` (existing) |
| Syntax highlighting | `shiki ^4.0.2` (already in package.json, used by `DiffViewer.svelte` + `MarkdownViewer.svelte`) |
| Toast notifications | `toasts` from `desktop/src/lib/stores/toasts.svelte.ts` |
| Foundation primitives | `lucide-svelte` icons (`Save`, `X`, `Search`) — same convention as `RuntimeTerminalPane.svelte`. No new foundation components added. |
| Layout integration | `Pane`, `PaneKind` types from `desktop/src/lib/stores/mosaic-layout.svelte.ts` |

**No new primitives created.** Foundation `Button` / `Input` were considered
but the pane's compact toolbar fits more naturally inline (matching
`DiffViewer.svelte`'s toolbar style); promoting that to a foundation
component is a separate refactor, not a Code-Editor-pane concern.

## Pane manifest

```ts
import type { CodeEditorPaneManifest } from "$lib/domain/code-editor/types.js";

export const CODE_EDITOR_MANIFEST: CodeEditorPaneManifest = {
  paneType: "code_editor",
  label: "Code Editor",
  icon: "Code",
  defaultConfig: {
    workspaceSlug: "default",
  },
  configSchema: {
    fileId:        { type: "string", required: false },
    workspaceSlug: { type: "string", required: false },
    path:          { type: "string", required: false },
  },
};
```

## Shared file edits required

### 1. `desktop/src/lib/stores/mosaic-layout.svelte.ts`

Extend the `PaneKind` union to include the new pane type. The store
itself doesn't care what's stored on `pane.ref` — only the dispatcher
does.

```diff
 export type PaneKind =
   | "session"
   | "issue"
   | "task"
   | "doc"
   | "file"
   | "terminal"
   | "changes"
-  | "knowledge";
+  | "knowledge"
+  | "code_editor";
```

The `Pane` interface today has just `{id, kind, ref, title}`. The Code
Editor pane needs both `workspaceSlug` AND `path` (or a `fileId`). Two
options:

- **Option A (minimal):** encode in `ref` as `${slug}::${path}` and
  parse inside the pane. Concise but stringly-typed.
- **Option B (recommended):** add an optional `config?: Record<string, unknown>`
  field to `Pane` so panes that need richer state (Code Editor today,
  others tomorrow) can store typed config. Existing pane kinds keep
  working unchanged. Update the persistence layer to round-trip it
  (already JSON-safe via `localStorage.setItem(JSON.stringify(...))`).

```diff
 export interface Pane {
   id: string;
   kind: PaneKind;
   /** session_id, issue short_id, doc id, etc. */
   ref: string;
   title: string;
+  /**
+   * Optional pane-kind-specific config (e.g. CodeEditor needs
+   * {workspaceSlug, path, fileId}). Free-form by design — each pane
+   * narrows it via its own type. Persisted verbatim.
+   */
+  config?: Record<string, unknown>;
 }
```

### 2. `desktop/src/lib/design/patterns/mosaic/PaneContent.svelte`

Add a dispatch arm for `pane.kind === 'code_editor'`. Mirrors the
existing `'changes'` lazy-load pattern.

```diff
   {:else if pane.kind === 'knowledge'}
     <div class="pc-knowledge">
       …
     </div>
+
+  {:else if pane.kind === 'code_editor'}
+    {#await import('$lib/design/patterns/mosaic/panes/CodeEditorPane.svelte')}
+      <div class="pc-stub pc-stub--loading">Loading editor…</div>
+    {:then { default: CodeEditorPane }}
+      <CodeEditorPane
+        fileId={pane.config?.fileId as string | undefined}
+        path={(pane.config?.path as string | undefined) ?? pane.ref}
+        workspaceSlug={(pane.config?.workspaceSlug as string | undefined) ?? mosaicLayout.layout.workspaceSlug}
+        onDirtyChange={(d) => { /* MosaicTile reads dirty for unsaved-warning */ }}
+      />
+    {:catch}
+      <div class="pc-stub">Code editor failed to load.</div>
+    {/await}
   {/if}
```

### 3. `desktop/src/lib/design/patterns/mosaic/PanePicker.svelte`

Add an entry to the static catalog so users can open the editor from the
picker. Use a real example file path so the picker is testable end-to-end.

```diff
   const catalog: PickerItem[] = [
     …
     { id: 'p7', kind: 'file',      ref: 'src/main.ts', title: 'File: src/main.ts',           description: 'File' },
+    { id: 'p11', kind: 'code_editor', ref: 'src/main.ts', title: 'Edit: src/main.ts',         description: 'Code editor' },
     …
   ];
```

Also extend the kind-label map:

```diff
   const KIND_LABELS: Record<PaneKind, string> = {
     session: 'Session', issue: 'Issue', task: 'Task', doc: 'Doc',
-    file: 'File', terminal: 'Terminal', changes: 'Changes', knowledge: 'Knowledge',
+    file: 'File', terminal: 'Terminal', changes: 'Changes', knowledge: 'Knowledge',
+    code_editor: 'Editor',
   };
```

When opening, populate `pane.config` with the workspace + path so the
dispatcher can resolve them:

```diff
   function openItem(item: PickerItem): void {
+    const isCodeEditor = item.kind === 'code_editor';
     const pane: Pane = {
       id: Math.random().toString(36).slice(2, 9),
       kind: item.kind,
       ref: item.ref,
       title: item.title,
+      config: isCodeEditor
+        ? { workspaceSlug: mosaicLayout.layout.workspaceSlug, path: item.ref }
+        : undefined,
     };
     mosaicLayout.openPane(pane, targetTileId ?? undefined);
     onClose();
   }
```

### 4. `desktop/src/lib/design/patterns/mosaic/MosaicTile.svelte` (informational)

The tile renders `pane.title` directly. The Code Editor pane itself emits
a `•` dirty marker inside its own toolbar; surfacing the dirty marker on
the **tile tab** requires the tile to listen to the
`onDirtyChange` callback. Implementation note for the follow-up:

- Add a per-pane dirty registry (`Map<paneId, boolean>`) on
  `mosaicLayout` with `setDirty(paneId, dirty)` / `isDirty(paneId)`.
- In `PaneContent.svelte`, pass `onDirtyChange={(d) => mosaicLayout.setDirty(pane.id, d)}`.
- In `MosaicTile.svelte`, prefix the tab title with `•` when
  `mosaicLayout.isDirty(pane.id)`.
- For the unsaved-warning on tile/pane close: hook into `closePane()`
  and `closeTile()` — if any contained pane has a dirty flag set, show
  a `confirm()` dialog before proceeding.

This is **not** wired in this changeset — flagged here so the next pass
picks it up consistently across all editor-style panes.

## Backend gap (no new files; flagged for upstream fix)

Two pre-existing inconsistencies in the workspace-files API that the
Code Editor pane works **around** rather than fixing here (out of scope
for this build, and they affect `writeFileMutation` users beyond the
editor):

1. **Field-name mismatch on write.**
   - `CanopyWeb.WorkspaceFilesController.write/2` reads
     `params["content"]` (singular).
   - `desktop/src/lib/api/queries/workspaces.ts → writeFileMutation`
     sends `{contents}` (plural).
   - The existing TS type `FileWriteBody` declares `contents: string`.
   - **Code Editor pane workaround:** `saveCodeFileMutation` in
     `queries/code-editor.ts` calls the endpoint directly with
     `{content}` (singular). Tests in
     `backend/test/canopy_web/controllers/workspace_files_controller_test.exs`
     confirm singular `content` is the live contract.
   - **Suggested upstream fix:** rename the TS field to `content` and
     update all 3 call sites; or accept both keys server-side
     (`params["content"] || params["contents"]`).

2. **Read response field name.**
   - Backend returns `{path, content}` (singular).
   - TS type `FileReadResponse` declares `contents` (plural).
   - **Code Editor pane workaround:** the pane reads both `data.content`
     and `data.contents` defensively in the `remoteContent` derivation.
   - **Suggested upstream fix:** align the TS type to `content` (or add
     a server-side alias).

3. **`PATCH /api/v1/files/:id` does NOT accept content updates.**
   The existing `FilesController.update/2` only patches `tags`. The Code
   Editor pane therefore saves through the workspace-scoped PUT
   (`PUT /api/v1/workspaces/:slug/files/*path`). If a future requirement
   is to save by `fileId` alone, add a new route — e.g.
   `PATCH /api/v1/files/:id/content` that resolves the file's
   `workspace_id` + `path` and delegates to `Canopy.Workspaces.Files.write_file/3`.

## pnpm packages required (NOT installed yet)

CodeMirror 6 is **not currently in `desktop/package.json`**. The pane
ships with a textarea + Shiki overlay fallback that does not require any
new packages. To upgrade to a full CodeMirror experience (multi-cursor,
gutter line numbers, code folding, native LSP hooks), install:

```bash
pnpm --filter desktop add \
  codemirror \
  @codemirror/state \
  @codemirror/view \
  @codemirror/commands \
  @codemirror/search \
  @codemirror/language \
  @codemirror/lang-javascript \
  @codemirror/lang-rust \
  @codemirror/lang-python \
  @codemirror/lang-json \
  @codemirror/lang-markdown \
  @codemirror/lang-yaml \
  @codemirror/lang-html \
  @codemirror/lang-css \
  @codemirror/lang-sql \
  @codemirror/theme-one-dark
```

Notes:
- `@codemirror/lang-elixir` does not exist on npm — Elixir would need a
  community grammar (e.g. `codemirror-lang-elixir`) or fall back to
  Shiki-only highlighting for `.ex/.exs` files. Keep using Shiki for
  Elixir until a vetted grammar is chosen.
- `@codemirror/lang-svelte` does not have an official package; community
  options exist (`@replit/codemirror-lang-svelte`). Same fallback story.
- `@codemirror/lang-typescript` is provided by `@codemirror/lang-javascript`
  via the `{typescript: true}` option, so don't install it separately.

After install, replace the `buildExtensions()` stub in
`desktop/src/lib/design/patterns/mosaic/panes/code-editor/extensions.ts`
with the real CodeMirror wiring, and swap the `<textarea>` block in
`CodeEditorPane.svelte` for an `EditorView` mount inside the
`.cep-editor-frame` container. The save-state, query, and toolbar code
are already shaped to feed CodeMirror's `updateListener`.

## LSP wiring status

**Not wired.** No `Canopy.Lsp` module exists in the backend
(`backend/lib/canopy/` shows no LSP module). The `@codemirror/lsp`
package itself isn't a real npm package; LSP-over-WebSocket is typically
implemented via `@codemirror/lsp-client` (community) or a bespoke
adapter.

Path to add LSP later (out of scope for this changeset):
1. **Backend** — add `backend/lib/canopy/lsp.ex` + Phoenix Channel
   `lsp:workspace:<slug>` that proxies JSON-RPC frames to a
   per-workspace `tsserver` / `elixir-ls` / `rust-analyzer` pool.
2. **Frontend** — add a CodeMirror extension that bridges
   `@codemirror/view` updates to LSP's `textDocument/didChange` over the
   channel, and renders diagnostics via `@codemirror/lint`.
3. **Pane** — wire the bridge into `buildExtensions({language, lspChannel})`
   inside `extensions.ts`; the rest of the pane is unchanged.

For now the pane is a clean editor without language services. That's the
intentional Phase-1 ship.

## Acceptance checklist (post-wiring)

- [ ] `PaneKind` union extended; `Pane` carries optional `config`.
- [ ] `PaneContent.svelte` dispatches `code_editor` to `CodeEditorPane.svelte`.
- [ ] `PanePicker.svelte` lists "Edit: src/main.ts" as a sample item.
- [ ] Opening the pane reads via `GET /api/v1/workspaces/default/files/<path>` and renders syntax-highlighted source.
- [ ] Typing flips the pane title's `•` indicator on (verified by `onDirtyChange` callback).
- [ ] `⌘S` triggers `PUT /api/v1/workspaces/default/files/<path>` with `{content: "<draft>"}`; toast says "Saved <path>".
- [ ] On save error, dirty indicator returns and an error toast appears (rollback verified).
- [ ] `⌘F` opens the find/replace bar; Enter advances to next match; "Replace all" rewrites the buffer (still dirty until ⌘S).
- [ ] Closing a dirty pane warns the user (depends on MosaicTile follow-up — see §4).
- [ ] Vitest passes: `save-state.test.ts` (12+ assertions on dirty logic) and `CodeEditorPane.test.ts` (language detection, resolvability, mutation key).
