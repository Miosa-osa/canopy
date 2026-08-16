# Warp Parity Verification Checklist — 2026-04-30

> Verification pass against actual source files. Every claim backed by file:line evidence.
> VERIFIED = real implementation code. STUB = placeholder/no-op/hardcoded. MISSING = file absent.

---

## Pane System

- [x] PaneKind union — `mosaic-layout.svelte.ts:29-43` — VERIFIED — 14 kinds: session, issue, task, doc, file, terminal, changes, knowledge, agent_conversation, agent_kanban, block_stream, workflow, notebook, history. All present in the union.
- [x] PaneContent dispatch — `PaneContent.svelte:94-222` — VERIFIED — All 14 PaneKind values have a dispatch branch. `issue`, `task`, `doc`, `file`, `knowledge` branches render real (if minimal) UI; none say "coming soon". `block_stream`, `workflow`, `notebook`, `history` all do real lazy imports and pass props.
- [x] PanePicker live queries — `PanePicker.svelte:31-73` — VERIFIED — Uses `createQuery(sessionsQuery)` and `createQuery(issuesQuery)` live; merges live sessions + issues into catalog alongside static quick actions. Not hardcoded.
- [x] MosaicTile KIND_ICONS — `MosaicTile.svelte:125-140` — VERIFIED — All 14 PaneKinds have icon entries. Right-click context menu exists (`openContextMenu` at line 60). `pinPane` called from context menu at line 92. Metadata badges implemented via `metaBadgeValue` at line 159. Tab auto-scroll-into-view wired via `$effect` at line 109.
- [x] MosaicSettings — `MosaicSettings.svelte:50-120` — VERIFIED — All 5 prefs wired and bound to `mosaicPrefs` store: View mode (Panes/Tabs), Density (compact/comfortable/roomy), Pane title format (command/working_directory/branch), Additional metadata fields (branch/working_directory/agent/runtime/model), Show details on hover toggle.

---

## Conversation Surface

- [x] AgentConversationPane — `AgentConversationPane.svelte:1-75` — VERIFIED — Imports and composes `BlockStream`, `EmbeddedRuntime`, `ConversationComposer`, `ConversationIntroCard`, and `AgentStatusBar`. All three content modes (BlockStream / EmbeddedRuntime / IntroCard) are present.
- [x] ConversationComposer — `ConversationComposer.svelte:1-40` — VERIFIED — Wraps `Composer.svelte`, adds `ComposerChips` (cwd/model/remote/rich-input/files/mic chips), `ShellCommandHint` above the input, ⌘| mode override. Ghost-text is NOT present (no inline suggestion rendered). Rich input toggle via `richInputOn` prop hides composer body.
- [ ] ConversationComposer ghost-text — `ConversationComposer.svelte` — MISSING — No ghost-text / Tab-to-accept inline suggestion. `looksLikeShellCommand` is imported and drives the `ShellCommandHint` hint banner only; no completion rendered at end-of-line.
- [x] AgentStatusBar — `agent-conversation/AgentStatusBar.svelte:1-197` — VERIFIED — Fully implemented. Derives status from last block in session; handles thinking/tool_call/approval/error states with animations. Imported and used in `AgentConversationPane.svelte:42`.
- [x] Block actions onCopy/onRerun/onPin/onDelete — `BlockStream.svelte:92-150` — VERIFIED — All four handlers are wired with real logic: `handleCopy` writes to clipboard via `navigator.clipboard`, `handleRerun` POSTs to `/sessions/:id/messages`, `handlePin` persists to localStorage, `handleDelete` optimistically removes and calls `apiDelete`. Not just prop definitions — all called at line 262-273 inside the `{#each}` render loop.
- [x] Block keyboard nav — `BlockStream.svelte:172-215` — VERIFIED — `handleKeydown` handles ArrowDown/ArrowUp (move focus), Escape (deselect), `c` (copy focused block), `r` (rerun focused block), Enter (toggle collapse). Focus model uses `focusedBlockIndex` state and `blockEls` refs array.

---

## Build Rail

- [x] BuildSideRail 5 sections — `BuildSideRail.svelte:39-58` — VERIFIED — All 5 sections imported and wired: `AgentConversationsSection`, `TabsSection`, `ProjectExplorerSection`, `SearchSection`, `DriveSection`. ⌘1-5 shortcuts and Esc collapse documented in JSDoc.
- [x] SearchSection type-filter chips — `SearchSection.svelte:43-52` — VERIFIED — 5 filter chips defined: All / Files / Sessions / Blocks / Drive. `activeFilter` state drives query filtering.
- [x] ProjectExplorerSection folder picker — `ProjectExplorerSection.svelte:50-60+` — VERIFIED — `pickFolder()` calls Tauri dialog `openDialog({ directory: true })`. `needsFolderPick` derived state gates between "Pick folder" empty state and the live `FileTree`. Switch folder (via `updateWorkspaceMutation`) is also wired.
- [x] AgentConversationsSection rename — `AgentConversationsSection.svelte:251-277` — VERIFIED — `startRename`, `cancelRename`, `commitRename` all implemented. Context menu includes "Rename" item at line 301. `renameConvo` mutation calls `updateSessionMutation` with `{ id, title }`. Inline rename input rendered when `renamingId` matches session id.

---

## Pane Types

- [x] WorkflowPane — `mosaic/panes/WorkflowPane.svelte:1-415` — VERIFIED — Fetches Drive entry + Routine via real TanStack queries. Parses `{{param}}` placeholders via regex. Renders parameter form inputs. `runWorkflow()` at line 106 opens an `agent_conversation` pane with the interpolated prompt. No "coming soon" text.
- [x] NotebookPane — `mosaic/panes/NotebookPane.svelte:1-80+` — VERIFIED — Parses Drive entry markdown into markdown/command cells by splitting on fenced code blocks. Command cells are executable via `apiPost`. Markdown cells rendered via `renderMarkdown`. Not a stub.
- [x] HistoryPane — `mosaic/panes/HistoryPane.svelte:1-80+` — VERIFIED — Fetches 5 most recent sessions via `listSessions`, then fetches blocks for each via `listBlocks`. Merges and sorts cross-session. Frecency scoring via localStorage click tracking. Search + kind filter. Not a stub.
- [x] AgentKanbanPane — `mosaic/panes/AgentKanbanPane.svelte:1-60+` — VERIFIED — 4 columns (Backlog/Claimed/In Progress/Done) via `KANBAN_COLUMNS`. Uses `svelte-dnd-action` for drag. Claim/release/complete mutations wired. Auto-refetches every 15s.

---

## Stores & Utilities

- [x] keybindings.svelte.ts — `desktop/src/lib/stores/keybindings.svelte.ts` — VERIFIED — 29 binding `id:` entries covering Global (5), Navigation (5), Mosaic (10+), Build, Block categories. Exceeds the 20+ threshold.
- [x] theme-registry.svelte.ts — `desktop/src/lib/stores/theme-registry.svelte.ts` — VERIFIED — 6 themes defined: Canopy Dark, Canopy Light, Tokyo Night, Dracula, Solarized Dark, Solarized Light. Each with full `colors` + `terminal` (xterm palette). `applyToDOM` sets CSS vars + `data-theme` attribute.
- [x] event-bus.svelte.ts — `desktop/src/lib/stores/event-bus.svelte.ts` — VERIFIED — `on(pattern, handler)` with wildcard support, `emit(channel, type, payload)`, `history(channel, limit)` ring-buffer (200 entries). Full singleton export.
- [x] pane-context.svelte.ts — `desktop/src/lib/stores/pane-context.svelte.ts` — VERIFIED — `produce(paneId, key, value)`, `consume(key)`, `watch(key, handler)`, `removePaneContext(paneId)`. Map-backed reactive store.
- [x] spatial-layouts.ts — `desktop/src/lib/utils/spatial-layouts.ts` — VERIFIED — `gridLayout`, `bentoLayout`, `scatterLayout` all exported as real functions with geometry logic. No stubs.
- [x] providers.ts — `desktop/src/lib/domain/runtimes/providers.ts` — VERIFIED — 3 providers: `claudeLocal` (Claude Code, 3 models), `codexCli` (Codex, 2 models), `geminiCli` (Gemini). All with models, modes, capabilities arrays.

---

## Backend

- [x] Router total routes — `backend/lib/canopy_web/router.ex` — VERIFIED — 348 route lines counted. All required route groups present:
  - Agent Kanban: lines 196-200 (`/agent-kanban/board`, `/idle-agents`, `/claim`, `/release/:task_id`, `/complete/:task_id`)
  - Relay: lines 478-488 (`/relay/participants`, `/relay/inbox/:agent_slug`, `/relay/messages`, `/relay/threads`, `/relay/channels`)
  - Governance permissions: lines 143-146 (`GET /governance/permissions`, `POST /governance/permissions`, `DELETE /governance/permissions/:id`, `POST /governance/permissions/check`)
  - Workspace PATCH: line 157 (`patch "/workspaces/:slug"`)
- [x] application.ex tool registrations — `backend/lib/canopy/application.ex:139-141` — VERIFIED — `Canopy.Tools.Kanban`, `Canopy.Tools.Relay`, `Canopy.Tools.Workspace` all registered via `register_module/1` in the boot Task at lines 139, 140, 141.

---

## Summary

**26/27 verified, 0 stubs remaining, 1 missing.**

| Status | Count | Items |
|--------|-------|-------|
| VERIFIED | 26 | All pane system, all block actions, all rail sections, all pane types, all stores, backend |
| STUB | 0 | — |
| MISSING | 1 | Ghost-text inline completion in ConversationComposer |

### Notable findings

1. **Ghost-text missing** — `ConversationComposer.svelte` has `looksLikeShellCommand` import and `ShellCommandHint` banner but no inline Tab-to-accept suggestion. This is item #7 on the Hit List (M/HIGH effort).
2. **PanePicker was fixed** — The audit doc marked it PARTIAL (hardcoded catalog). The actual file now uses live `sessionsQuery` + `issuesQuery` with static fallbacks. Verify this matches the current sprint.
3. **AgentConversationsSection rename was added** — The audit doc did not show rename in the context menu. The actual file has full `startRename` / `commitRename` / `renameConvo` mutation. Already shipped.
4. **Block actions fully wired** — The audit doc marked copy/rerun/pin/delete as PARTIAL. All four are implemented with real logic in `BlockStream.svelte`, not just prop pass-throughs.
5. **All new PaneKinds dispatched** — `block_stream`, `workflow`, `notebook`, `history` all have dispatch branches in `PaneContent.svelte` and real pane components. The audit doc listed these as MISSING.
