# CodeSurf Steal Report — 2026-04-30

## What It Is

CodeSurf (internally "Contex") is an Electron desktop app that puts terminals, AI chat tiles, code editors, browsers, notes, kanban boards, and extension-contributed tiles on an infinite 2D spatial canvas. Agents connect via a local MCP HTTP server and a file-based relay messaging system. Multiple AI providers (Claude, Codex, OpenCode, OpenClaw, Hermes) stream into chat tiles side by side. The canvas engine lives in a single ~1700 LOC React component (App.tsx) handling pan/zoom/drag/resize/snap/groups/undo. Persistence is file-based JSON per workspace — no cloud, no database for user state (SQLite is used only for derived indexes on jobs/threads). Extensions follow a manifest-driven plugin system with `safe` (UI only) and `power` (Node.js `activate()` with bus + MCP + IPC access) tiers.

## Tech Stack

- **Shell**: Electron 40.8.2 (Chromium)
- **UI**: React 19.2.4 + TypeScript 5.9.3
- **Build**: Vite 7.3.1 / electron-vite 5.0.0
- **Styling**: Tailwind CSS 4.0 + inline CSSProperties (no CSS-in-JS lib)
- **Terminal**: xterm.js 6.0 + node-pty 1.1 + WebGL addon
- **Editor**: Monaco Editor (via @monaco-editor/react)
- **AI SDKs**: @anthropic-ai/claude-agent-sdk 0.2.79, @opencode-ai/sdk 1.2.27
- **DB**: better-sqlite3 (derived indexes only — canonical data is JSON/JSONL on disk)
- **FS watch**: chokidar 5.0
- **Layout**: elkjs 0.11.1 (auto-layout for canvas tiles)
- **Image processing**: sharp 0.34.5
- **License**: AGPL-3.0-only

## Features Worth Stealing

| Feature | What They Do | How We'd Adapt | Effort | Maps To |
|---------|-------------|---------------|--------|---------|
| **Spatial canvas engine** | Infinite 2D pan/zoom/drag/resize/snap/groups with undo (50-snapshot ring). All in one component. World-coord math, nested group recursion, snap-to-grid. | Canopy uses a mosaic tiled layout, not a canvas. **Not a lift** — but the minimap component and group-nesting logic could inform a future "canvas view mode" toggle alongside mosaic. | L | Build (future) |
| **Multi-provider chat** | 5 built-in providers (Claude, Codex, OpenCode, OpenClaw, Hermes) each with their own model list, mode list, and thinking-budget selector. Extension-contributed providers via `ExtensionChatProviderConfig`. | Canopy already has embedded runtimes (Claude Code, Codex, Gemini). Steal the **provider/mode/thinking config pattern** — a single `providers.ts` config file that declares models, modes, thinking budgets per provider. Clean abstraction. | S | Build / Sessions |
| **Event bus (main process)** | Wildcard pub/sub (`tile:*`, `*`), ring-buffer history (500/channel), read cursors per subscriber. Cross-process via IPC bridge to renderer. Extensions publish/subscribe via `ctx.bus`. | Canopy has Phoenix PubSub on the backend. Steal the **client-side event bus pattern with wildcard routing + ring buffer** for the Tauri side — useful for cross-pane communication without round-tripping to Phoenix. | M | Build / Agents |
| **Extension system (manifest + tiers)** | `extension.json` manifest declares tiles, chat surfaces, MCP tools, context menu items, settings, actions. Two tiers: `safe` (iframe UI only) and `power` (Node.js with activate/deactivate lifecycle, bus access, IPC registration, MCP tool registration). Gallery with enable/disable per extension. | Canopy has Skills + Drive as the extensibility surface. Steal the **manifest schema** for a future "Extensions" module — the `contributes` pattern (tiles, tools, settings, context menus) is well-structured and VS Code-proven. Don't steal the loader (Electron-specific `require()`). | L | Skills / Drive / Extensions (future) |
| **Relay messaging (agent-to-agent)** | File-based mailbox system: each agent tile has inbox/sent/memory/bin. Messages have protocol headers (`contex-relay/v1`), thread IDs, priority, scope (direct/channel/broadcast). Channels with bridges (Slack, WhatsApp, webhook). Participants have kind/status/work-context. Central mailbox for audit trail. | Canopy's Agents module needs inter-agent communication. Steal the **relay data model** — participant registry, message schema with threadId + scope + priority, mailbox routing. Adapt to Phoenix channels + Ecto persistence instead of filesystem. The `RelayWorkContext` (summary, branch, worktree, files, topics, blockers, impacts) is excellent agent state modeling. | M | Agents |
| **Tool permission system** | Per-tool allow/deny with scopes: once, session, today, forever, never. Grants stored per workspace. Visual permission card in chat UI. | Canopy has governance/approvals. Steal the **scope taxonomy** (once/session/today/forever/never) — cleaner than binary approve/reject. The `ToolPermissionGrant` schema with expiration is production-ready. | S | Build / Governance |
| **Chrome cookie sync** | Reads Chrome profile cookies, bookmarks, history. Browser tiles use real Chrome session. | Interesting but **niche**. Canopy's browser pane (if we build one) could use this. Low priority. | M | Build (stretch) |
| **Kanban tile with agent activity feed** | Kanban columns (Backlog/Running/Done) per agent. Cards auto-created from agent tool calls. Activity feed polls terminal output and normalizes ANSI. Real-time task status via MCP `complete_task` / `update_task` tools. | Canopy already has `AgentKanbanPane`. Steal the **activity polling pattern** — terminal output -> ANSI strip -> task log normalization. Also steal the MCP tool surface for kanban (agents call `complete_task` to move their own cards). | S | Build / Agents |
| **Minimap** | Canvas minimap rendering all tiles as colored rectangles on a 160x100 canvas element. Click-to-navigate. Color-coded by tile type. | Not useful for mosaic layout. **Skip.** | — | — |
| **Tile context sharing** | `TileContextEntry` with key/value/updatedAt/source. Extensions declare `produces` and `consumes` context keys. Tiles share state without direct coupling. | Steal the **context declaration pattern** for cross-pane data sharing. A pane declares what context it produces; other panes subscribe to consume. Better than ad-hoc store coupling. | S | Build / Mosaic |
| **Job/timeline indexer** | JSONL timeline files per job. SQLite FTS5 for search. Incremental scan via mtime/size diff. Roll-up counters. Tombstoning for deleted jobs. | Canopy uses Ecto + Postgres. Steal the **timeline-as-JSONL pattern** for agent session recording — append-only log per session, indexed into searchable tables. The incremental mtime scan is Electron-specific (skip). | S | Sessions |
| **Collab state (per-tile)** | `.collab/{tileId}/state.json` — tasks, paused flag. `.collab/{tileId}/skills.json` — enabled/disabled skill lists. | Steal the **per-pane collab state** concept for Canopy's agent panes — each pane tracks its own task list and skill selection independently. Maps directly to pane.config. | S | Build / Agents |
| **Font token system** | 3 semantic tokens (primary/secondary/mono) with full FontToken shape (family, size, lineHeight, weight, letterSpacing). Legacy migration from 20+ granular tokens. System font stacks with Nerd Font support. | Canopy uses Tailwind theme tokens. Steal the **3-token simplification** as a design system reference. The migration pattern (old granular -> new simplified) is a useful playbook for when Canopy's own token system evolves. | S | Design System |
| **Layout templates** | `LayoutTemplate` with recursive `LayoutTemplateNode` (leaf with slots, or split with direction/children/sizes). Users save and restore canvas arrangements. | Canopy has `mosaic/PanePicker` and layout concepts. Steal the **recursive layout tree model** — it's cleaner than Canopy's current flat tile list. Could power "save this mosaic layout as template" feature. | M | Build / Mosaic |

## Features to REJECT

- **Spatial canvas as primary UX** — CodeSurf's entire UX is canvas-based (infinite 2D with pan/zoom). Canopy's mosaic tiled layout is intentionally different and better for productivity workflows. The 1700-LOC App.tsx is a maintenance liability they acknowledge. Don't import this paradigm.
- **File-based persistence for everything** — No database for user state, just JSON files in `~/.contex/workspaces/`. Canopy has Ecto + Postgres + Phoenix. Their approach doesn't scale to multi-device or team features.
- **Electron runtime** — Canopy is Tauri + Rust. Electron's process model, IPC patterns, and native module rebuilds (node-pty, better-sqlite3, sharp) don't translate.
- **Chrome cookie injection into browser tiles** — Security risk, privacy concern, platform-specific. If Canopy needs an embedded browser, use a sandboxed webview without session theft.
- **AGPL license** — Cannot lift code directly. Ideas and patterns only.
- **`any` in older chat.ts sections** — Their own CLAUDE.md acknowledges TypeScript discipline is inconsistent. Not a model.
- **Single-file canvas engine (App.tsx ~1700 LOC)** — They flag this as a problem themselves. Counter-example of Canopy's "one responsibility per file" rule.

## Recommended Lifts (prioritized)

1. **[S/HIGH] Provider config pattern** — Create a single `providers.ts` config file that declares models, modes, and thinking budgets per runtime provider. CodeSurf's `src/renderer/src/config/providers.ts` is a clean reference. Maps to Build/Sessions. Adapt for Canopy's runtime adapters.

2. **[S/HIGH] Tool permission scopes** — Adopt the 5-scope taxonomy (once/session/today/forever/never) for Canopy's governance approvals. The `ToolPermissionGrant` schema with expiration timestamps is production-ready. Maps to Governance settings.

3. **[S/HIGH] Tile context declaration** — Extensions/panes declare `produces: string[]` and `consumes: string[]` context keys. Decouple cross-pane data sharing from direct store imports. Straightforward addition to Canopy's pane config type.

4. **[M/HIGH] Relay message schema for agent-to-agent** — Adapt `RelayParticipant` (kind/status/work-context), `RelayMessage` (threadId/scope/priority/mailbox), and `RelayChannel` (members/bridges) into Ecto schemas. The `RelayWorkContext` shape (summary, branch, files, topics, blockers, impacts) is the best agent-state model I've seen in an open-source tool. Maps to Agents module.

5. **[M/HIGH] Client-side event bus with wildcards** — Port the wildcard pub/sub + ring-buffer pattern to Canopy's Tauri frontend. Enables cross-pane communication without Phoenix round-trips. Useful for agent activity feeds, real-time status updates, and extension hooks.

6. **[S/MED] Kanban MCP tool surface** — Add MCP tools (`complete_task`, `update_task`, `add_note`) that agents call to update their own kanban cards. CodeSurf's pattern: agent finishes work -> calls MCP -> kanban tile updates via event bus. Maps to Build/Agents kanban.

7. **[M/MED] Recursive layout template model** — Adopt the `LayoutTemplateNode` tree (leaf | split with direction/children/sizes) for a "save mosaic layout as template" feature. Maps to Build/Mosaic templates.

8. **[L/MED] Extension manifest schema** — When Canopy builds an extensions system, use CodeSurf's `ExtensionManifest` as the starting template. The `contributes` pattern (tiles, chat surfaces, MCP tools, context menu, settings, actions) is VS Code-proven and well-typed. Maps to future Extensions module.

9. **[S/LOW] Font token simplification** — Reference the 3-token model (primary/secondary/mono) as a validation of Canopy's design system direction. Low effort to align naming.

## Cross-Reference to Canopy Inventory

| CodeSurf Feature | Canopy Status (from warp-parity-audit) | Gap? |
|-----------------|---------------------------------------|------|
| Multi-provider chat | HAVE — Embedded runtimes (Claude Code, Codex, Gemini) | Config pattern is cleaner in CodeSurf |
| Kanban | HAVE — `AgentKanbanPane` | Missing MCP tool surface for agent self-reporting |
| Terminal | HAVE — `TerminalSession.svelte` | Parity |
| Code editor | HAVE — `CodeEditorPane.svelte` | Parity |
| Blocks | HAVE — 8 block kinds | CodeSurf has no equivalent; Canopy is ahead here |
| Slash commands | HAVE — `SlashCommands.svelte` | Parity |
| Extension system | MISSING | CodeSurf is far ahead; Canopy has Skills/Drive instead |
| Agent-to-agent messaging | MISSING | CodeSurf relay is the reference implementation |
| Spatial canvas | N/A — different paradigm | Canopy's mosaic is intentionally different |
| Browser tile | MISSING | CodeSurf has it with Chrome sync; low priority for Canopy |
| Permission scopes | PARTIAL — governance/approvals exist | CodeSurf's 5-scope model is more granular |
| Event bus (client-side) | MISSING | Phoenix PubSub covers server-side; client gap exists |
| Layout templates | MISSING | Hit-list item in warp-parity-audit |
