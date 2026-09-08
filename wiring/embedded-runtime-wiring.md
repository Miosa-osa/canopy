> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Embedded Runtime — Wiring

> Per-pane runtime UX inside `AgentConversationPane`. Companion to
> `agent-conversation-pane-wiring.md`. Keep both consistent.

## Scope

When a conversation pane LAUNCHES a runtime (Conductor calls
`runtime.spawn` OR the user types `/claude`, `/codex`, `/gemini`, …)
the pane's transcript area transitions from BlockStream to a live
runtime terminal. Composer can be hidden ("Rich Input OFF") to give
the runtime sole focus, or kept ("Rich Input ON") so the user keeps
multi-line input + slash commands + @mentions while the terminal
streams below.

## Type contract

`AgentConversationConfig` extension (lives in `pane.config`):

```ts
type AgentConversationConfig = {
  cwd?: string;
  model?: string;
  sessionId?: string;
  // NEW:
  embeddedRuntime?: {
    type: 'claude-local' | 'codex-local' | 'gemini-local' | string;
    sessionId: string;
    richInputOn: boolean;          // persisted across reloads
    notificationsOn?: boolean;     // per-runtime, visual-only today
  };
};
```

Persistence: the existing `mosaicLayout.save()` already round-trips
arbitrary JSON via `pane.config`. We copy `embeddedRuntime` straight
through. Reload restores both the embed and the rich-input toggle —
there is no separate store.

## Files in scope

NEW (this dispatch):
- `desktop/src/lib/design/patterns/mosaic/panes/agent-conversation/EmbeddedRuntime.svelte`
- `desktop/src/lib/design/patterns/mosaic/panes/agent-conversation/RichInputToggle.svelte`
- `desktop/src/lib/design/patterns/mosaic/panes/agent-conversation/CwdPickerPopover.svelte`
- `desktop/src/lib/design/patterns/mosaic/panes/agent-conversation/FileExplorerChip.svelte`
- `desktop/src/lib/design/patterns/mosaic/panes/agent-conversation/RuntimeNotificationChip.svelte`

EDITED (surgical):
- `desktop/src/lib/design/patterns/mosaic/panes/AgentConversationPane.svelte`
- `desktop/src/lib/design/patterns/mosaic/panes/agent-conversation/ConversationComposer.svelte`
- `desktop/src/lib/design/patterns/mosaic/panes/agent-conversation/ComposerChips.svelte`

NOT touched (forbidden by dispatch):
- `desktop/src/lib/design/patterns/runtime-view/RuntimeTerminalPane.svelte`
- `desktop/src/lib/design/patterns/TerminalSession.svelte`
- `src-tauri/...` (PtyBridge etc.)
- `desktop/src/lib/stores/mosaic-layout.svelte.ts`

## File-tree decision — do NOT extract a third primitive

Two file-tree implementations exist today:
- `desktop/src/lib/design/patterns/FileTree.svelte` + `FileTreeNode.svelte`
  → recursive, full-tree fetch via `workspaceTreeQuery` (eager).
- `desktop/src/lib/design/patterns/build/sections/ProjectExplorerSection.svelte`
  + `build/sections/FileTreeNode.svelte` → flat-listing root + lazy
  per-folder expansion via `directoryListingQuery`.

`FileExplorerChip` reuses the **lazy** variant
(`build/sections/FileTreeNode.svelte`) directly. Rationale:

- The chip popover wants lazy loading (workspaces can be huge).
- Extracting a third "shared FileTree" primitive would add a layer of
  indirection without removing duplication — both existing trees serve
  real, distinct shapes.
- `ProjectExplorerSection` was just shipped and is owned by another
  dispatch. Reaching in to retrofit a shared primitive risks merge
  pain. The simpler call is: import its leaf node component as-is.

Verdict: **inlined reuse, no extraction**. Revisit only if a third
consumer materialises with materially different needs.

## Runtime spawn flow

The Conductor (server-side) is the source of truth for runtime spawns.
Two entry points land an `embeddedRuntime` config on a pane:

1. **User types `/claude`, `/codex`, `/gemini` in the composer.** The
   existing `SlashCommands` palette dispatches a runtime spawn. The
   spawn handler:
   1. Creates a `Canopy.Sessions.Session` of the appropriate `runtime`.
   2. Returns the new `sessionId`.
   3. Frontend writes `pane.config.embeddedRuntime = { type, sessionId,
      richInputOn: true }` and calls `mosaicLayout.save()`.

2. **Conductor-driven spawn** (e.g. agent program escalation). The
   Conductor returns a `runtime.spawn` directive in its event stream.
   The pane component listens (already wired through `BlockStream`) and
   applies the same `pane.config` write.

Either way, the React-style render path picks it up: when
`embeddedRuntime` is non-null, `<EmbeddedRuntime/>` mounts and
`<TerminalSession/>` (the existing xterm wrapper) attaches to the PTY.

## stdin pipe (Rich Input ON ↔ OFF)

The pane captures `sendInput` via `<TerminalSession onReady>` (already
exported by the primitive — module-level `sendInput` AND a per-instance
callback). Two modes:

- **Rich Input ON**: composer submit → `sendInput(prompt + "\n")`. The
  user gets multi-line editing, slash commands, @mentions, then sends a
  single batched message to the runtime.
- **Rich Input OFF**: composer hides. The xterm instance owns key
  events directly. Chips remain visible. ⌃G flips back.

We rely on the existing transport. **No new fetcher, no new channel.**

## Backend gaps (flag, do not implement here)

| Need | Status | Stop-gap shipped |
|------|--------|------------------|
| `Canopy.Runtimes.set_cwd(session_id, path)` | NOT IMPLEMENTED | When cwd changes AND a runtime is embedded, the pane sends `cd <path>\n` over the existing PTY. Works for any shell-backed runtime. Once `set_cwd` lands, switch to it. |
| Per-runtime notification toggle (e.g. `Canopy.Runtimes.Claude.set_notifications(true)`) | NOT IMPLEMENTED | `RuntimeNotificationChip` is wired to `pane.config.embeddedRuntime.notificationsOn` only. State persists across reloads but does NOT propagate to the runtime. Replace `handleNotificationsToggle` in `AgentConversationPane.svelte` with a real call once the API exists. |
| `runtime.spawn` Conductor directive shape | partial | Conductor currently emits spawn intent in the event stream but does not write `pane.config` itself. Frontend handler needs to claim it. Tracked separately. |

When these land, the only frontend changes are inside
`AgentConversationPane.svelte` (`handleCwdChange`,
`handleNotificationsToggle`). The chip components stay untouched.

## Keyboard shortcut conflict check — ⌃G

Searched all of `desktop/src/lib` for `ctrlKey` usage:

| File | Chord | Conflict? |
|------|-------|-----------|
| `mosaic/MosaicRoot.svelte` | `Cmd/Ctrl + Tab/Number` | NO |
| `mosaic/panes/CodeEditorPane.svelte` | `Cmd/Ctrl + S` (save) | NO |
| `patterns/Composer.svelte` (and friends) | `Cmd/Ctrl + Enter` | NO |
| `patterns/FileViewer.svelte` | `Cmd/Ctrl + S` | NO |
| `patterns/TiptapEditor.svelte` | `Cmd/Ctrl + Enter`, `Cmd/Ctrl + K` | NO |
| `agent-conversation/ConversationComposer.svelte` | `Cmd/Ctrl + \|` | NO |
| `build/BuildSideRail.svelte` | `Cmd/Ctrl + (no modifier-G branch)` | NO |

`⌃G` is **free**. The handler in `RichInputToggle.svelte` listens at
`window` capture-phase, but the predicate `isRichInputToggleEvent`
explicitly rejects `metaKey` (so macOS `⌘G` "Find Next" passes through
unmolested) and rejects `altKey` (so users who remap stay safe).

## ARIA / accessibility checklist

- `RichInputToggle` — `aria-pressed`, `aria-label` swaps with state, kbd hint visible.
- `CwdPickerPopover` — `role="dialog"`, search input auto-focused, Esc + outside-click close, list rows are `role="option"` inside `role="listbox"`.
- `FileExplorerChip` — `aria-haspopup="dialog"`, `aria-expanded` mirrors state, popover has `role="dialog"`, file tree retains `role="tree" / "group"`.
- `RuntimeNotificationChip` — `aria-pressed`, `title` matches label.
- `EmbeddedRuntime` header — `role="banner"`, end button has `aria-label`.

## Test coverage

- `RichInputToggle.test.ts` — predicate behavior across modifier matrix; toggle state contract.
- `CwdPickerPopover.test.ts` — `parentDir()` invariants (never escapes workspace), `filterDirs()` (case-insensitive, dirs only), select contract.
- `FileExplorerChip.test.ts` — `filterEntries()` (case-insensitive, returns dirs+files), open/close lifecycle, file-pick closes / dir-click does not, workspace-relative path emission.

Pure-logic discipline matches the existing
`ShellCommandHint.test.ts` convention — Vitest "server" project does
NOT load runes-aware components.

## Out of scope for this dispatch

- Backend `set_cwd` and notification setters.
- Conductor → frontend `runtime.spawn` event glue (separate dispatch).
- Extracting a shared `<FileTree>` primitive (see file-tree decision).
- Adding a `sendSessionInput` REST endpoint — we use the existing
  Phoenix Channel transport via `TerminalSession`'s exported `sendInput`.
