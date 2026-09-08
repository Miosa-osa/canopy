> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Build Warp-Parity Audit — 2026-04-30

> Scope: Audit `/build` super-module against Warp Terminal's surface area
> (https://github.com/warpdotdev/warp + Roberto's stated priorities). Identify
> what's HAVE / PARTIAL / MISSING and produce a prioritized hit list.
>
> Brand rule: this doc references Warp for cross-reference only. Suggested
> Canopy file paths use neutral terms (`rich-input`, `blocks`, `workflow`,
> `notebook`, `palette`) — never `warp-*`.

## Inventory

### Build rail + sections

| File | What it does | Status |
|------|--------------|--------|
| `desktop/src/routes/build/+page.svelte` | `/build` cockpit shell. Topbar + 5-section side rail + MosaicRoot. Seeds an empty agent_conversation pane on first mount; honours `?pane=` deep links. | DONE |
| `desktop/src/lib/design/patterns/build/BuildSideRail.svelte` | 5-icon column + expandable 280px panel. Sections: Conversations, Tabs, Project Explorer, Search, Drive. ⌘1–5 to switch, Esc to collapse. | DONE |
| `build/sections/AgentConversationsSection.svelte` | Search + grouped (ACTIVE / RECENT) conversation list, context menu (fork pane / fork tab / delete), "+ New conversation". | DONE |
| `build/sections/TabsSection.svelte` | Tab list across all mosaic tiles. Filter, focus, drag-reorder, context menu. | DONE |
| `build/sections/ProjectExplorerSection.svelte` | Workspace file tree (lazy-load); double-click → open file pane; drag → mosaic drop. | DONE |
| `build/sections/SearchSection.svelte` | Cross-file ripgrep; regex/case toggles; results grouped by file; click → open at line. Backend `/search` endpoint is stubbed (`available: false` empty state). | PARTIAL (backend pending) |
| `build/sections/DriveSection.svelte` | Personal/Team scope toggle; tree of Drive entries (workflow/prompt/notebook/env_vars/mcp_server/rule); drag → drop into pane. Backend `/drive/tree` endpoint stubbed. | PARTIAL (backend pending) |
| `build/sections/FileTreeNode.svelte` | Lazy per-folder file tree leaf. | DONE |
| `build/SlashCommands.svelte` | Inline `/`-triggered command palette. Sources: builtin / runtimes / drive_workflow / drive_prompt / template / skill. Keyboard nav, fallback built-ins. | DONE |

### Mosaic layout

| File | What it does | Status |
|------|--------------|--------|
| `mosaic/MosaicRoot.svelte` | Top-level mosaic host. Loads layout, ⌘\\ split, ⌘W close, ⌘T pane picker, ⌘1-9 activate, ⌘⇧← / ⌘⇧→ tile focus. Hosts the gear icon + MosaicSettings popover. | DONE |
| `mosaic/MosaicNode.svelte` | Recursive tree: tile vs split. | DONE |
| `mosaic/MosaicTile.svelte` | Tab strip + drop overlays + edge-drop split + intra-tile reorder + hover card + density variants + panes-vs-tabs view modes. | DONE (panes-view stub for full grid) |
| `mosaic/MosaicSettings.svelte` | Gear-icon popover. View as (Panes/Tabs), Density (compact/comfortable/roomy), Pane title format, Additional metadata, Show details on hover. | DONE |
| `mosaic/PaneContent.svelte` | Pane-kind dispatcher. Handles: session, terminal, changes, issue, task, doc, file, knowledge, agent_conversation, agent_kanban. | DONE (some kinds are stubs) |
| `mosaic/PanePicker.svelte` | ⌘T modal with **hardcoded static catalog** of 12 items. No live search across sessions/files/issues. | PARTIAL (hardcoded catalog) |
| `mosaic/TabHoverCard.svelte` | Tab-hover detail card with metadata (branch, cwd, agent, runtime, model). | DONE |
| `mosaic/panes/AgentConversationPane.svelte` | Per-pane conversation surface. BlockStream OR EmbeddedRuntime OR ConversationIntroCard, plus composer. Owns sessionId / embeddedRuntime config. | DONE |
| `mosaic/panes/AgentKanbanPane.svelte` | Agent task kanban. | DONE (separate dispatch) |
| `mosaic/panes/CodeEditorPane.svelte` / `DiffPane.svelte` / `FileViewerPane.svelte` / `McpPane.svelte` | Other pane kinds (not yet routed via PaneContent dispatch). | EXISTS — not all wired |

### Agent conversation pane internals

| File | What it does | Status |
|------|--------------|--------|
| `agent-conversation/ConversationComposer.svelte` | Wraps `Composer.svelte` + ShellCommandHint + ChipRow. ⌘\| toggles agent/shell mode. Hides composer when richInputOn=false. | DONE |
| `agent-conversation/ComposerChips.svelte` | cwd / model / remote / Rich Input / Files / runtime-notif / Drive / Skills / Templates / Sandboxes / Schedule / mic / +. | DONE |
| `agent-conversation/ConversationIntroCard.svelte` | Empty-state card with shortcut hints. | DONE |
| `agent-conversation/CwdPickerPopover.svelte` | Search-directories popover anchored to cwd chip. | DONE |
| `agent-conversation/EmbeddedRuntime.svelte` | Embeds a runtime session (Claude Code / Codex / Gemini) into the pane via TerminalSession. Status pill + End runtime. | DONE |
| `agent-conversation/FileExplorerChip.svelte` | Chip + popover file picker; emits `onPickFile(path)`. | DONE |
| `agent-conversation/RichInputToggle.svelte` | Pill chip + global ⌃G handler. Stateless; parent persists via pane.config. | DONE |
| `agent-conversation/RuntimeNotificationChip.svelte` | Per-runtime notification toggle (visual; no backend yet). | PARTIAL (visual-only) |
| `agent-conversation/ShellCommandHint.svelte` + `shell-detect.ts` | "Looks like a shell command — switch?" hint above composer. | DONE |
| `agent-conversation/module-launchers/DrivePickerPopover.svelte` | Drive entry picker. | DONE |
| `agent-conversation/module-launchers/SkillsPickerPopover.svelte` | Skills picker → `apply_skill`. | DONE |
| `agent-conversation/module-launchers/TemplatesPickerPopover.svelte` | Templates picker → `instantiate_template`. | DONE |
| `agent-conversation/module-launchers/SandboxQuickActions.svelte` | Sandbox picker + new sandbox. | DONE |
| `agent-conversation/module-launchers/ScheduleQuickActions.svelte` | Schedule conversation / pick spec. | DONE |

### Terminal + blocks

| File | What it does | Status |
|------|--------------|--------|
| `TerminalSession.svelte` | xterm.js terminal over Phoenix v2 raw WS channel `terminal:session:<id>`. input / resize / output / exit. Static imports, retry on error. | DONE |
| `blocks/Block.svelte` | Single block renderer — header (icon, status, duration, cost), collapsible body, footer (copy, rerun, share, pin, delete). Discriminates 8 kinds: command, agent_message, tool_call, tool_result, approval, diff, system_event, error. | DONE |
| `blocks/BlockStream.svelte` | Vertical scroll list. | DONE |
| `blocks/CommandBlock.svelte` / `AgentMessageBlock.svelte` / `ToolCallBlock.svelte` / `ApprovalBlock.svelte` / `SystemEventBlock.svelte` | Per-kind body components. Approval wired to `/governance/approvals`. | DONE |
| Block pane kind | NOT in `PaneKind` union — blocks render INSIDE AgentConversationPane via BlockStream, never as standalone panes. | MISSING (block_stream pane kind) |

### Wiring docs (planning record)

`build-wiring.md`, `build-side-rail-wiring.md`, `agent-conversation-pane-wiring.md`, `agent-conversations-section-wiring.md`, `agent-kanban-wiring.md`, `blocks-wiring.md`, `build-module-integration-wiring.md`, `embedded-runtime-wiring.md`, `code-editor-wiring.md`, `diff-wiring.md`, `drive-wiring.md`, `drive-starter-wiring.md`, `mcp-wiring.md`, `mosaic-polish-finish-wiring.md`, `files-explorer-rebuild-wiring.md`, `file-viewer-wiring.md`, `sandboxes-wiring.md`, `schedule-wiring.md`, `templates-wiring.md`, `skills-curator-wiring.md`, `search-wiring.md`, `iris-bootstrap-wiring.md`, `conductor-bootstrap-wiring.md`, `active-workspace-wiring.md`, `per-workspace-state-applied-wiring.md`. **No** `warp-*`, `workflow-*`, `notebook-*`, `theme-*`, or `triggers-*` wiring exists yet.

## Feature Matrix

| # | Feature (Warp) | Status | Location | Notes |
|---|---|---|---|---|
| 1 | **Blocks** (command + output as one navigable unit) | HAVE | `desktop/src/lib/design/patterns/blocks/*` | 8 block kinds, header chrome, collapse, action footer (copy/rerun/share/pin/delete) — but rerun/share/pin handlers are prop callbacks **not yet wired** at the BlockStream level, and shareable URL doesn't exist. |
| 1a | Block keyboard nav (↑/↓ between blocks, ⌘D select block) | MISSING | would live in `blocks/BlockStream.svelte` | No focus model; can't tab between blocks; no "current block" cursor. |
| 1b | Block as standalone pane (open one block in its own tile) | MISSING | needs `block_stream` PaneKind in `mosaic-layout.svelte.ts` + dispatch in `PaneContent.svelte` | wiring/blocks-wiring.md flags this as "main agent applies." Never applied. |
| 2 | **Rich Input toggle** (composer ↔ raw passthrough) | HAVE | `agent-conversation/RichInputToggle.svelte`, ⌃G shortcut | Persisted on `pane.config.embeddedRuntime.richInputOn`. |
| 3 | **Workflows** (saved/parameterized commands, fillable args) | PARTIAL | Drive surfaces `workflow` kind (`build/sections/DriveSection.svelte`); slash palette lists `drive_workflow`. | No workflow editor. No parameter prompt UI. No "run workflow" execution surface. Drive `/drive/tree` endpoint still stubbed. |
| 4 | **Notebooks** (annotated runbooks of commands) | PARTIAL | Drive surfaces `notebook` kind | No notebook viewer/editor pane. No notebook execution. |
| 5 | **Warp AI / Agent Mode** (NL → command suggestions inline) | HAVE | Composer agent/shell auto-detection (`shell-detect.ts`) + ⌘\| override + ShellCommandHint | Native — every conversation IS the agent. Heuristic detection works. |
| 5a | Inline AI command suggestion (ghost-text completion) | MISSING | would live in `agent-conversation/ConversationComposer.svelte` | No ghost-text. No "press Tab to accept suggestion" UX. |
| 6 | **Command palette** (⌘P / ⌘K — fuzzy nav across everything) | HAVE | `desktop/src/lib/design/patterns/CommandPalette.svelte` (global ⌘K) + `keyword-search/KeywordSearchDialog.svelte` (⌘/ Build top bar) | Two palettes — global ⌘K (commands) and Build's ⌘/ (sessions/agents/files keyword search). Both functional. |
| 7 | **Subshells** (multiple shells per pane / split inside a pane) | MISSING | would extend `mosaic/MosaicTile.svelte` | Only one terminal per pane. No nested shells. |
| 7a | **Drives** (saved bookmarks of remote/SSH targets) | PARTIAL | Drive super-module exists — but not as connection targets, only as workflow/prompt/notebook entries | Drive in Canopy means "personal/team library of artifacts," not Warp's SSH-target Drives. **Naming collision** — flag for product. |
| 7b | **SSH connections** (ssh://host as a session type) | MISSING | would live in `lib/design/patterns/ssh/` + new `ssh` PaneKind | No SSH session adapter. No remote-host browser. Out of scope until cloud sync? Likely REJECT for v1. |
| 8 | **Sessions** (resumable, named, persistent) | HAVE | `desktop/src/lib/api/queries/sessions.ts` + `AgentConversationsSection` shows ACTIVE / RECENT | Sessions persist server-side. Mosaic layout reattaches via `pane.config.sessionId`. |
| 8a | Named sessions (rename a session) | MISSING | would live in `agent-conversation/SessionTitleEditor.svelte` | Session title is auto-derived from first prompt. No rename affordance. |
| 9 | **Tabs + Splits + Panes** (rich tab strip, drag-rearrange) | HAVE | `mosaic/MosaicTile.svelte` + drag-and-drop edge zones | Edge-drop splits, intra-tile reorder, cross-tile move, ⌘T add, ⌘W close. |
| 9a | Pinned tabs | MISSING | would extend `Pane` interface with `pinned: boolean` + sort/render in MosaicTile | Block has a pin flag for individual blocks; tabs don't. |
| 9b | Tab groups (color-coded tab clusters) | MISSING | would extend `Tile` with `groupId` + render in MosaicTile chrome | Out of scope likely; flag if Roberto wants it. |
| 10 | **Themes** (custom color schemes, syntax) | PARTIAL | `lib/stores/theme.svelte.ts` + `routes/settings/appearance/+page.svelte` | Has light/dark + accent. No multi-theme registry. No theme editor. xterm uses its own palette. |
| 11 | **Keybindings** (full custom-binding support) | PARTIAL | `routes/settings/keyboard/+page.svelte` + `lib/utils/shortcuts.ts` | **Read-only** cheatsheet only. No rebinding UI. No conflict detection. No persistence layer for custom bindings. |
| 12 | **Settings panel** (real, deep) | HAVE | `routes/settings/*` — analytics, appearance, budgets, build, drive, governance, hooks, integrations, keyboard, miosa, profile, runtime-adapter, runtimes, sandboxes, schedule, sidebar, skills, templates | 18 sub-pages exist. Some are deeper than others. |
| 13 | **Triggers / shortcuts** (run command on event) | MISSING | would live in `routes/settings/triggers/+page.svelte` + `lib/stores/triggers.svelte.ts` | No trigger system. No "on session start, run X" UX. Out of scope until backend has a hook bus. |
| 14 | **History** (searchable command history per session, cloud-synced) | PARTIAL | Block search exists at `/sessions/:id/blocks/search` (per `blocks-wiring.md`) | No cross-session history view. No history pane kind. No frecency scoring. |
| 15 | **Sharing blocks** (permalink to a block) | MISSING (REJECT?) | would need backend share token endpoint + block render route | Roberto's note: "we may skip but UX matters." Flag as REJECT for v1, keep `onShare` callback in place. |
| 16 | **Multi-cursor / completion** (in the composer) | MISSING | would extend `Composer.svelte` | Composer is single-caret contenteditable. No multi-cursor. No autocomplete beyond `@mention` and `/slash`. |
| 17 | **Embedded runtimes** (Claude Code / Codex / Gemini inline) | HAVE | `agent-conversation/EmbeddedRuntime.svelte` | Beyond Warp parity — unique to Canopy. ✓ |
| 18 | **File explorer chip** (pick file inline) | HAVE | `agent-conversation/FileExplorerChip.svelte` | Roberto-named priority. ✓ |
| 19 | **Cwd picker popover** | HAVE | `agent-conversation/CwdPickerPopover.svelte` | Roberto-named priority. ✓ |
| 20 | **Mosaic prefs popover** (gear icon) | HAVE | `mosaic/MosaicSettings.svelte` | Roberto-named priority. ✓ |
| 21 | **Add-pane affordances** (`+` button + ⌘T modal) | HAVE | `MosaicTile.svelte` `+` button + `PanePicker.svelte` ⌘T | Roberto-named priority. ✓ But picker uses **hardcoded catalog** — see HIT-LIST item 1. |
| 22 | **Slash commands** (multi-source registry) | HAVE | `build/SlashCommands.svelte` + `api/queries/build-commands.ts` | Roberto-named priority. ✓ |
| 23 | **Workflow/notebook viewer pane** (open a `workflow:slug` in a tile) | MISSING | would live in `mosaic/panes/WorkflowPane.svelte` + `mosaic/panes/NotebookPane.svelte` + new PaneKinds | Drive entries can be dragged but there's no dedicated viewer. |
| 24 | **Block "rerun" wired** | PARTIAL | `Block.svelte` exposes `onRerun` callback; nobody wires it in `BlockStream` | One-line fix in BlockStream to dispatch back to the session. |
| 25 | **Block "copy" / "share" / "pin" / "delete" wired** | PARTIAL | Same — props exist, BlockStream doesn't pass handlers | Copy is the most useful; trivial to wire. |
| 26 | **Tab strip overflow / scroll-into-view** | PARTIAL | Tabs scroll horizontally (`overflow-x: auto`) but active tab doesn't auto-scroll into view when activated remotely | Adds polish; one $effect in MosaicTile. |
| 27 | **Build top-bar global search** (⌘/ from /build) | HAVE | `+page.svelte` opens `keyword-search/KeywordSearchDialog.svelte` | Functional. |
| 28 | **Cloud-synced sessions / blocks / settings** | REJECT | — | Out of scope for desktop-first. Local SQLite + Phoenix backend only. |
| 29 | **Warp account / billing / Warp Drive cloud** | REJECT | — | Canopy is BYO-runtime; we don't run a hosted plane. |
| 30 | **Tab hover detail card** | HAVE | `mosaic/TabHoverCard.svelte` | Branch, cwd, agent, runtime, model — togglable from MosaicSettings. |
| 31 | **Session title editing / "Name conversation"** | MISSING | would live in `agent-conversation/SessionTitleEditor.svelte` or inline rename in `AgentConversationsSection` | Right-click already has fork/delete; rename absent. |
| 32 | **Agent picker (which agent is driving the convo)** | HAVE | Composer reuses agent picker (mentioned in `Composer.svelte`); `MentionInput.svelte` powers `@`-mentions | Working. |
| 33 | **Status bar / "what's the agent doing right now"** | MISSING | would live in `agent-conversation/AgentStatusBar.svelte` | No persistent "agent is thinking..." line. Approval blocks render but no global busy indicator. |
| 34 | **Per-pane CWD switching pipes a `cd <path>` to embedded runtime** | HAVE | `AgentConversationPane.svelte#handleCwdChange` | Backend gap: `Canopy.Runtimes.set_cwd` doesn't exist yet — falls back to `cd` over PTY. |

## Prioritized Hit List

> Ranking: Roberto's stated priorities first, then UX visibility (HIGH/MED/LOW),
> then effort (S/M/L). Format: `[size/impact] feature — what to do (where)`.

### Tier 1 — Roberto-named gaps (do these first)

1. **[S/HIGH] Live PanePicker catalog** — replace the hardcoded 12-item static catalog in `mosaic/PanePicker.svelte` with: recent sessions (`sessionsQuery`), open issues (`issuesQuery`), recent files (workspace tree), and active runtimes. Group by kind. Add fuzzy scoring (reuse `CommandPalette.svelte` tiers — already imported in `MentionInput`). One file edit, ~80 LOC.

2. **[S/HIGH] Wire Block stream actions (copy / rerun)** — `blocks/BlockStream.svelte` accepts no callback props from its caller; pass `onCopy`, `onRerun`, `onPin` down to `Block.svelte`. `onCopy` = `navigator.clipboard.writeText(block.command || block.text)`. `onRerun` = re-POST to `/sessions/:id/messages` with the same prompt. Two files; ~30 LOC.

3. **[M/HIGH] Standalone Block pane kind** — add `block_stream` to `PaneKind` in `mosaic-layout.svelte.ts`; add dispatch branch in `PaneContent.svelte`; add picker entry. Lets the user pin/expand a session's block stream into its own tile. `wiring/blocks-wiring.md` already specifies this. ~15 LOC across 3 files.

4. **[M/HIGH] Block keyboard navigation** — in `blocks/BlockStream.svelte`, add focus model: ↑/↓ between blocks, ⌘D toggle collapse, ⌘C copy current block, ⌘R rerun. New file `blocks/useBlockFocus.svelte.ts` for the hook. Required for "agentic terminal" parity.

5. **[M/HIGH] Workflow viewer pane** — new `mosaic/panes/WorkflowPane.svelte`; new `workflow` PaneKind; renders a Drive workflow's parameterized form, fills args, dispatches to `runtime.spawn` or composer-prefill. Drag from `DriveSection` already emits the right payload. ~120 LOC.

### Tier 2 — High-impact missing features

6. **[M/HIGH] Notebook viewer pane** — symmetrical to (5). New `mosaic/panes/NotebookPane.svelte`; new `notebook` PaneKind. Renders a Drive notebook (markdown cells + executable command cells). Reuses `BlockStream` for the command cell renderer.

7. **[S/HIGH] Inline ghost-text command suggestion** — in `Composer.svelte`, when `looksLikeShellCommand(draft)` is true and the user pauses 300ms, fetch a single suggestion from the Conductor (`POST /api/v1/build/suggest-completion`) and render it greyed-out at end-of-line. Tab to accept. Backend stub: returns first matching `BuildCommand` for now. ~80 LOC + 1 endpoint.

8. **[M/HIGH] Tabs section: drag tabs to mosaic tiles** — `build/sections/TabsSection.svelte` only does intra-tile reorder. Make tab-rows draggable into MosaicTile drop zones (same `application/x-canopy-pane` payload). One file; ~30 LOC.

9. **[M/HIGH] Session rename** — add rename action to `AgentConversationsSection` context menu (currently fork/delete) + inline-rename UX in tab title. Backend already accepts a `title` field on Session. ~50 LOC across 2 files.

10. **[M/MED] Pinned tabs** — extend `Pane` with `pinned: boolean`; sort pinned-first in MosaicTile; add right-click "Pin tab" / "Unpin." 1 store + 1 component; ~40 LOC.

### Tier 3 — Settings / theming / keybindings

11. **[M/MED] Custom keybinding editor** — `routes/settings/keyboard/+page.svelte` is read-only. Replace with editable rows: click a keybinding → capture next chord → save to `lib/stores/keybindings.svelte.ts` → conflict detection. Persist to backend `/api/v1/settings/keybindings`. New store + new endpoint + page rewrite. ~250 LOC.

12. **[M/MED] Theme registry** — `routes/settings/appearance/+page.svelte` exists; extend with multi-theme selector (Tokyo Night, Dracula, Solarized, custom). Apply to xterm instance in `TerminalSession.svelte` via theme tokens. ~150 LOC.

13. **[L/MED] Triggers system** — `routes/settings/triggers/+page.svelte` (NEW) + backend `triggers` table + `Canopy.Triggers` context + event bus hooks. v1: "on session start, run X command", "on workspace open, set CWD to Y". Effort is mostly backend.

### Tier 4 — Stream / history / nav polish

14. **[S/MED] Tab auto-scroll-into-view** — when activeTileId or activePaneId changes, in `MosaicTile.svelte` add `$effect` that calls `scrollIntoView({ inline: 'nearest' })` on the active `.mt-tab`. ~10 LOC.

15. **[M/MED] Cross-session history pane** — new `mosaic/panes/HistoryPane.svelte`; new `history` PaneKind; lists all blocks across sessions with frecency + filter by kind / by session. Reuses `blocksSearchQuery`. ~150 LOC.

16. **[S/MED] Agent status bar** — `agent-conversation/AgentStatusBar.svelte` (NEW) above ConversationComposer; subscribes to BlockStream for "in-flight" tool_call/agent_message blocks; shows a thin progress strip + "Conductor is calling tool X…" text. ~60 LOC.

17. **[S/LOW] Block share permalink (UX only, REJECT cloud)** — wire `onShare` in `Block.svelte` to copy `optimal://blocks/<id>` to clipboard + toast. No actual hosted-share endpoint, but the affordance + URL scheme are in. ~15 LOC.

### Tier 5 — Stretch / explicit REJECTs

18. **[REJECT/—] Cloud-synced everything** — out of scope; Canopy stays local-first.
19. **[REJECT/—] Warp Drives as SSH targets** — naming collision with our Drive super-module; if we want SSH it goes under a separate `connections` super-module.
20. **[REJECT/—] Hosted block-sharing endpoint** — wait until v2 if at all.

## Suggested Next 3 Sprints

> Each sprint sized for one Roberto-week (3–5 days of @frontend-svelte effort).
> All items reference the numbered Hit List above.

### Sprint A (1–2 days) — wire the wires that already exist
- Items **1, 2, 3, 14**.
- Outcome: PanePicker becomes useful, Block actions work, blocks become first-class panes, tab strip feels native.
- No new files outside what wiring docs already specify.

### Sprint B (3 days) — workflow + notebook + ghost-text + nav
- Items **4, 5, 6, 7, 8**.
- Outcome: Workflows and notebooks are openable as panes; composer feels Warp-grade; tabs section is drag-aware.
- New PaneKinds: `block_stream`, `workflow`, `notebook`. New pane components in `mosaic/panes/`.

### Sprint C (3 days) — naming, pinning, settings
- Items **9, 10, 11, 12, 16**.
- Outcome: Sessions are nameable; tabs pinnable; keybindings editable; theme registry shipped; agent status visible above composer.
- Touches mostly settings routes + a new keybindings store.

### Backlog (defer)
- Items **13, 15, 17** — triggers, history pane, share permalink. Each useful but not blocking.
- Items **18–20** — REJECT / not Canopy's fight.

## Cross-references

- `wiring/build-wiring.md` — original build module dispatch
- `wiring/blocks-wiring.md` — block primitive + pending PaneKind
- `wiring/embedded-runtime-wiring.md` — Rich Input + EmbeddedRuntime contract
- `wiring/agent-conversation-pane-wiring.md` — pane composition
- `wiring/build-module-integration-wiring.md` — slash commands + module launchers
- `wiring/mosaic-polish-finish-wiring.md` — panes-view + density + hover card
- `wiring/search-wiring.md` / `wiring/drive-wiring.md` — backend status

## Notes

- Everything Roberto explicitly named (Rich Input toggle, embedded runtimes, slash commands, file explorer chip, cwd picker, prefs popover, add-pane affordances) is **HAVE** ✓.
- The biggest gaps are: live data in PanePicker, block keyboard nav + actions wiring, dedicated workflow/notebook panes, and editable keybindings.
- Search and Drive backends are the longest-pole external dependencies — both rails handle a 404 gracefully ("backend pending"), but their UX is gated on those endpoints.
- Total realistic Warp-parity work: **~3 sprints (8 days)** of @frontend-svelte effort, plus 2–3 days of backend (Tier 3 keybindings persistence + Tier 4 history endpoints + Tier 5 triggers).
