# Stacks Steal Report — 2026-04-30

> Source: https://github.com/jasonkneen/stacks (v0.2.9, MIT license)
> Auditor: OSA Agent | Cross-ref: `wiring/warp-parity-audit.md`

## What It Is

Stacks is an AI-powered infinite canvas workspace built on Electron + React. Users
place sticky notes, rich-text notes, images, videos, folders, browser windows, and
terminal sessions on a zoomable 2D canvas. An MCP server exposes the canvas as tools
so any AI agent can create/move/connect items programmatically. It supports multi-provider
AI (Anthropic, OpenAI, Google) via Vercel AI SDK, and includes image generation, vision
analysis, and auto-layout (grid, bento, scatter) via the ELK engine. Think "Miro meets
AI agent IDE" for a single user.

## Tech Stack

- **Runtime**: Electron 39 + Vite 6 + React 19 + TypeScript 5.8
- **Styling**: Tailwind CSS 4 + custom glassmorphic/backdrop-blur theme
- **AI**: Vercel AI SDK v6 (`ai` package) + `@ai-sdk/anthropic` + `@ai-sdk/openai` + `@ai-sdk/google`
- **MCP**: `@modelcontextprotocol/sdk` v1.25 — stdio MCP server + WebSocket proxy
- **Terminal**: `ghostty-web` (WebGL terminal) + `node-pty` (Electron PTY server)
- **Storage**: `better-sqlite3` (server-side via MCP) + IndexedDB (client-side media)
- **Layout**: `elkjs` (ELK graph layout engine) + custom grid/bento/scatter algorithms
- **Media**: EXIF extraction, AI vision analysis, image generation (Gemini native)
- **Shaders**: `@paper-design/shaders-react` (animated backgrounds — 20+ shader presets)
- **Icons**: `lucide-react`

## Features Worth Stealing

| Feature | What They Do | How We'd Adapt | Effort | Maps To |
|---------|-------------|----------------|--------|---------|
| **Infinite canvas** | Zoomable pan/zoom 2D workspace; items at (x,y,w,h) with z-index + rotation; camera state persisted per space | Could power a visual agent workspace / knowledge map pane in Build mosaic. Render sessions, files, agents as spatial nodes instead of linear list. | L | Build (new `canvas` PaneKind) |
| **MCP server as canvas API** | Full MCP server (`mcp/server.ts`) with 12 tools: CRUD items, connections, spaces, organize. Any MCP client can manipulate the canvas. Resources + prompts (brainstorm, summarize, layout). | Canopy already has MCP integration. The pattern of exposing workspace state as MCP tools is directly portable — let agents read/write to Drive, sessions, or a canvas pane via MCP. | M | Drive, Agents, MCP settings |
| **Multi-provider AI via AI SDK** | Unified `aiProvider.ts` wraps Anthropic/OpenAI/Google behind Vercel AI SDK. Streaming + tool calling. Provider/model selection persisted in localStorage. | Canopy uses embedded runtimes (Claude Code / Codex / Gemini) — different pattern. But the unified provider switcher UI pattern is worth lifting for any direct-API features (summarize, generate, analyze). Settings modal pattern maps to our existing `routes/settings/runtimes/`. | S | Settings > Runtimes |
| **Auto-arrange layouts** | 4 layout modes: grid (snapped), bento (variable-size tiles), scatter (seeded random), free. Sort by date/name/type. Spacing: compact/comfortable/spacious. Fit-to-view camera. | Directly useful for Agent Kanban pane, or a future canvas pane. The `layouts.ts` algorithms (grid, bento, scatter) are clean and self-contained (~300 LOC). Bento layout especially interesting for dashboard-style views. | S | Build > AgentKanbanPane, future canvas pane |
| **Item connections (visual graph)** | Items can be connected with edges (from/to). Connections survive item moves. ELK used for hierarchical auto-layout. | Maps to knowledge graph visualization. Could augment Drive or a new "graph" pane to show relationships between sessions, files, agents. | M | Drive, new `graph` PaneKind |
| **Spaces (nested folders)** | Hierarchical spaces: root space + child spaces. Folders link to sub-spaces. Navigate in/out. Breadcrumb-style back nav. | Canopy has workspace scoping but no nested spatial grouping. The "space as folder" metaphor could apply to project-level organization within Drive. | M | Drive |
| **Search across all spaces** | `SearchModal.tsx`: fuzzy text search across all items in all spaces. Filter by type (note/image/video/folder). Keyboard nav. 20-result limit. | Pattern matches our `KeywordSearchDialog`. Their cross-space search is simpler but the type-filter chips are a clean UI pattern we could add to our Build search. | S | Build > SearchSection |
| **Ghostty terminal on canvas** | Terminal sessions rendered as canvas items using `ghostty-web` (WebGL). WebSocket to `node-pty`. Resize, maximize, theme matching. | We already have `TerminalSession.svelte` with xterm.js over Phoenix WS. The "terminal as a draggable card on a canvas" is novel but not needed in v1. The theme-matching approach (syncing terminal palette with app theme) is a good detail to lift. | S | Build > TerminalSession |
| **AI chat with structured output** | `AIChat.tsx` uses a format system prompt to get structured responses: `[STICKY:color]`, `[NOTE:title]`, `[IMAGE]`. Parses responses into typed objects, then materializes them as canvas items. | The structured-output-to-UI pattern is interesting. Canopy's agent responses are blocks; we could use a similar approach to let agent output create Drive entries, tasks, or canvas nodes — not just text blocks. | M | Agents, Build |
| **Quick Generate (image/video/audio)** | Modal with tabs for image gen (Gemini native), video gen, audio transcription. Direct media creation from prompt. | Out of scope for Canopy v1. Media generation is not our use case. | -- | REJECT |
| **MCP proxy (WebSocket bridge)** | `mcp/proxy.ts`: WebSocket server on :3099 that bridges browser to stdio MCP servers. Manages server lifecycle, multiplexes tool calls across servers. | Canopy's MCP runs server-side in Elixir. The proxy pattern is irrelevant — we don't need a browser-to-stdio bridge because our backend handles MCP natively. | -- | REJECT |
| **Shader backgrounds** | 20+ animated shader presets (mesh gradient, perlin noise, voronoi, liquid metal, etc.) via `@paper-design/shaders-react`. | Pure eye candy. Could be interesting for empty-state backgrounds or loading screens but adds bundle weight. Low priority cosmetic lift. | S | Design system (cosmetic) |
| **Content zoom (independent of canvas zoom)** | Separate zoom level for item content (text size) vs. canvas camera zoom. `useContentZoom` hook. | Nice UX detail. Could apply to our mosaic panes — zoom text within a pane independently of the pane's tile size. | S | Build > MosaicTile |

## Features to REJECT

- **Electron shell** — Canopy is Tauri-native. Electron patterns (vite dev server spawning, node-pty in main process) don't transfer.
- **React 19** — Canopy is SvelteKit 5. Component patterns are informational only; no code lift possible.
- **LocalStorage for API keys** — Insecure. Canopy uses macOS Keychain via Tauri plugin-keyring. Never copy this pattern.
- **MCP WebSocket proxy** — Redundant. Canopy's Phoenix backend handles MCP server-side.
- **Image/video/audio generation** — Not Canopy's use case. We're a dev/agent workspace, not a creative canvas.
- **IndexedDB media storage** — Canopy uses server-side storage. Client-side blob management adds complexity without benefit.
- **better-sqlite3 in MCP server** — Canopy uses Ecto/Postgres. The SQLite-per-user pattern is fine for a toy but doesn't scale.
- **Shader backgrounds** — Fun but unjustifiable bundle cost for a dev tool. Possible as an opt-in easter egg only.
- **EXIF extraction** — Irrelevant to code/agent workflows.

## Recommended Lifts (prioritized)

1. **[S/HIGH] Auto-arrange layout algorithms** — Port the grid/bento/scatter layout logic from `utils/layouts.ts` (~300 LOC, pure math, no React dependency) to a `$lib/utils/spatial-layouts.ts`. Use for Agent Kanban card arrangement, and reserve for a future canvas pane. The bento algorithm is particularly clean — variable-size tiles packed into a grid with gap control. Effort: 2-3 hours to port + adapt types.

2. **[S/HIGH] Type-filter chips on search** — Their `SearchModal` has a pill-bar of type filters (Notes, Images, Videos, Stacks). Adapt this pattern for `build/sections/SearchSection.svelte`: add filter chips for result type (file, session, block, drive_entry). Pure UI lift, no backend change. Effort: 1-2 hours.

3. **[M/HIGH] MCP-as-workspace-API pattern** — Stacks exposes its entire canvas state as MCP tools (add_item, update_item, create_connection, organize_items, etc.) plus MCP resources (canvas://spaces) and prompts (brainstorm, summarize). Canopy should expose workspace state the same way: let agents CRUD Drive entries, read session history, and query workspace files via MCP tools registered on our backend. This turns every Canopy workspace into an agent-accessible knowledge base. File: new MCP tool definitions in `backend/lib/canopy/mcp/workspace_tools.ex`. Effort: 3-5 days (backend).

4. **[M/MED] Structured AI output to UI objects** — Their `AIChat.tsx` parses tagged output (`[STICKY:yellow]`, `[NOTE:title]`) into typed UI objects that become canvas items. Adapt this for Canopy: let agent block output contain structured markers that auto-create Drive entries, tasks, or file snippets. Requires a block post-processor in `AgentConversationPane`. Effort: 2-3 days.

5. **[M/MED] Canvas pane kind (stretch)** — A spatial, zoomable pane kind (`canvas`) in the Build mosaic that renders items at (x,y) with connections. Not a full Miro clone — just enough to visualize agent tasks, file relationships, or knowledge graphs spatially. Reuses layout algorithms from lift #1. Effort: 5-8 days. Defer to post-v1 unless Roberto prioritizes.

6. **[S/LOW] Terminal theme sync** — Their `GhosttyComponent` defines a full 16-color terminal palette that matches the app theme. Port this approach to `TerminalSession.svelte`: when the app theme changes, push matching ANSI colors to the xterm instance. Effort: 1-2 hours.

7. **[S/LOW] Content zoom (independent of tile size)** — `useContentZoom` hook controls text size within canvas items independently of camera zoom. Adapt as a per-pane font-size control in MosaicTile settings. Effort: 1-2 hours.

## Architecture Observations

**What they got right:**
- Clean separation: hooks (`useSpaces`, `useAutoSave`, `useMCPClient`, `useAIWithTools`, `useContentZoom`) encapsulate all state logic. Components are pure renderers.
- MCP server is a standalone process with its own SQLite — zero coupling to the UI.
- Layout algorithms are pure functions (items in, items out) — trivially portable.

**What they got wrong:**
- Monolith `App.tsx` is ~2000 lines. God component with 40+ state variables.
- API keys in localStorage with no encryption.
- No tests anywhere in the repo.
- No CI/CD pipeline.
- Single-user only — no workspace sharing, no multi-user, no auth.
- React 19 in Electron is a weight penalty vs. Svelte 5 in Tauri.

## Cross-references

- `wiring/warp-parity-audit.md` — existing Canopy Build inventory
- `wiring/drive-wiring.md` — Drive super-module (where MCP workspace tools would land)
- `wiring/agent-kanban-wiring.md` — kanban pane (where layout algorithms apply)
- `wiring/mcp-wiring.md` — existing MCP integration plan
- `wiring/search-wiring.md` — search section (where type-filter chips apply)
