# Diff pane — wiring

This file describes the surgical edits the main agent must apply to shared
files to bring the **Diff pane** online inside the Mosaic. All module-local
files (DiffPane + sub-components, queries, types, tests, backend WorktreeManager
extensions) have been created.

## Files already created (no shared edits)

### Frontend
| Path | Role |
|------|------|
| `desktop/src/lib/design/patterns/mosaic/panes/DiffPane.svelte` | Pane entry point — session-mode + ref-mode |
| `desktop/src/lib/design/patterns/mosaic/panes/diff/FileList.svelte` | Thin wrapper over Phase-5 ChangesFileList |
| `desktop/src/lib/design/patterns/mosaic/panes/diff/FileDiff.svelte` | Per-file renderer — wraps DiffViewer + Hunk action strip |
| `desktop/src/lib/design/patterns/mosaic/panes/diff/Hunk.svelte` | Per-hunk Keep / Discard / Stage toolbar |
| `desktop/src/lib/design/patterns/mosaic/panes/diff/CommitComposer.svelte` | Thin wrapper over Phase-5 CommitModal |
| `desktop/src/lib/design/patterns/mosaic/panes/diff/parse-hunks.ts` | DiffHunk → patch-body rebuilder for discard endpoint |
| `desktop/src/lib/design/patterns/mosaic/panes/diff/parse-hunks.test.ts` | Vitest coverage for buildHunkContent / changedLineCount |
| `desktop/src/lib/api/queries/diff.ts` | TanStack queries + commit/discard/stage mutations |
| `desktop/src/lib/domain/diff/types.ts` | Re-exports parse-diff types + backend contracts |

### Backend
| Path | Role |
|------|------|
| `backend/lib/canopy/sessions/worktree_manager.ex` | Added `stage/2` and `discard_hunk/4` (validates path traversal, reverse-applies via `git apply --unidiff-zero`) |
| `backend/lib/canopy_web/schemas/worktree_schema.ex` | Added StageRequest/Result + DiscardHunkRequest/Result OpenAPI schemas |
| `backend/lib/canopy_web/controllers/sessions_controller.ex` | Added `worktree_stage/2` and `worktree_discard_hunk/2` actions |
| `backend/lib/canopy_web/router.ex` | Added 2 new routes (see below) |
| `backend/test/canopy/sessions/worktree_manager_test.exs` | Appended `stage/2` + `discard_hunk/4` describe blocks (7 new tests) |

## Existing diff components reused (no duplication)

Per Roberto's no-duplicate-modules directive, the diff pane WRAPS the Phase-5
primitives instead of reimplementing them:

| Phase-5 file | Reused via |
|--------------|------------|
| `desktop/src/lib/design/patterns/diff/DiffViewer.svelte` | Imported by `FileDiff.svelte` — line rendering, hunk collapse, side-by-side toggle, shiki highlighting all unchanged |
| `desktop/src/lib/design/patterns/diff/ChangesFileList.svelte` | Imported by `FileList.svelte` (thin pane-side wrapper) |
| `desktop/src/lib/design/patterns/diff/CommitModal.svelte` | Imported by `CommitComposer.svelte` (thin pane-side wrapper) |
| `desktop/src/lib/utils/parse-diff.ts` | Re-exported from `domain/diff/types.ts`; used directly in `DiffPane.svelte` |
| `desktop/src/lib/api/queries/sessions.ts` (`worktreeStatusQuery`, `worktreeDiffQuery`, `getWorktreeDiff`) | Re-exported from `queries/diff.ts` as `useWorktreeStatus` / `useWorktreeDiff` |
| `desktop/src/lib/design/patterns/diff/ChangesPanel.svelte` | NOT replaced — DiffPane is the new mosaic-side composer; ChangesPanel remains for non-mosaic callers (session detail page) |

The `DiffViewer` was NOT modified. Hunk action toolbars are rendered by
`FileDiff` as a separate strip above DiffViewer, so DiffViewer stays untouched.

## Backend routes added

In `backend/lib/canopy_web/router.ex`, immediately after
`POST /sessions/:id/worktree/commit`:

```elixir
post "/sessions/:id/worktree/stage", SessionsController, :worktree_stage
post "/sessions/:id/worktree/discard-hunk", SessionsController, :worktree_discard_hunk
```

### Contracts

```
POST /api/v1/sessions/:id/worktree/stage
body: { "files": ["path/relative/to/worktree.ex", ...] }
→ 200 { "ok": true, "staged": [...] }
→ 422 { "error": "invalid_path" | "no_worktree" | "stage_failed" }

POST /api/v1/sessions/:id/worktree/discard-hunk
body: {
  "file_path":   "path/relative/to/worktree.ex",
  "hunk_header": "@@ -10,5 +10,7 @@",
  "hunk_content": " ctx\n-old\n+new\n ctx\n"
}
→ 200 { "ok": true }
→ 422 { "error": "invalid_path" | "invalid_hunk_header" | "no_worktree" | "discard_failed" }
```

Both endpoints validate that `file_path` is relative, contains no `..`, and
delegate the actual git work to `Canopy.Sessions.WorktreeManager` — controllers
never shell out to `git` directly.

## Pane manifest

```ts
{
  paneType: "diff",
  label: "Diff",
  icon: "GitCommit", // lucide-svelte
  defaultConfig: {
    sessionId: undefined,    // session-mode when set
    fromRef: undefined,      // ref-mode (read-only) when both set
    toRef: undefined,
    workspaceSlug: "default",
  },
}
```

## Shared file edits required

### 1. `desktop/src/lib/stores/mosaic-layout.svelte.ts` — add `"diff"` to `PaneKind`

The existing `PaneKind` type already includes `"changes"` (Phase-5 worktree
diff via ChangesPanel). The new `"diff"` kind is the mosaic-grade pane that
adds hunk-level Keep / Discard / Stage and ref-mode support.

Both kinds can coexist — `"changes"` is used by the legacy session-detail
page and `"diff"` is used by the mosaic.

```ts
export type PaneKind =
  | "session"
  | "issue"
  | "task"
  | "doc"
  | "file"
  | "terminal"
  | "changes"
  | "diff"        // ← ADD
  | "knowledge";
```

### 2. `desktop/src/lib/design/patterns/mosaic/PaneContent.svelte` — dispatch to DiffPane

Add the following branch alongside the existing `pane.kind === 'changes'`
clause:

```svelte
{:else if pane.kind === 'diff'}
  {#await import('$lib/design/patterns/mosaic/panes/DiffPane.svelte')}
    <div class="pc-stub pc-stub--loading">Loading diff pane…</div>
  {:then { default: DiffPane }}
    <DiffPane sessionId={pane.ref} workspaceSlug="default" />
  {:catch}
    <div class="pc-stub">Diff pane not ready.</div>
  {/await}
```

### 3. `desktop/src/lib/design/patterns/mosaic/PanePicker.svelte` — add catalog entry + label

Append to the `catalog` array:

```ts
{ id: 'p11', kind: 'diff', ref: 'session-abc', title: 'Diff: session-abc', description: 'Diff pane' },
```

Append to `KIND_LABELS`:

```ts
const KIND_LABELS: Record<PaneKind, string> = {
  session: 'Session', issue: 'Issue', task: 'Task', doc: 'Doc',
  file: 'File', terminal: 'Terminal', changes: 'Changes',
  diff: 'Diff',                 // ← ADD
  knowledge: 'Knowledge',
};
```

### 4. (Optional) `desktop/src/lib/api/queries/sessions.ts`

Already exports `worktreeStatusQuery`, `worktreeDiffQuery`, `getWorktreeDiff`,
`WorktreeStatus`. The new `queries/diff.ts` re-exports these — no changes
required to `sessions.ts`.

## Test plan

- `pnpm vitest run desktop/src/lib/design/patterns/mosaic/panes/diff/parse-hunks.test.ts` (8 cases)
- `mix test backend/test/canopy/sessions/worktree_manager_test.exs` (existing + 7 new)
- Manual: open a Mosaic tile, pick "Diff" from PanePicker, verify file list,
  side-by-side toggle, whitespace toggle, per-hunk Keep / Discard / Stage,
  Commit-all flow.
