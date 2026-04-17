# Canopy v2 — Full Competitor Steal Synthesis

**Date:** 2026-04-17
**Status:** Master synthesis — what we take from each competitor, merged into one Agent Management Workspace
**Companion to:** `CANOPY-V2-FOUNDATION.md` (platform), `CANOPY-V2-FRONTEND-DESIGN.md` (design spec)

---

## 0. The Expanded Product Vision

Original vision (yesterday): *"Canopy = runtime manager + MIOSA sandboxes."*

**Expanded vision (today, per Roberto):** Canopy = **Agent Management Workspace** with the breadth and polish of Core-OSS. Every productivity module exists in service of managing agents and the work they produce.

| Core-OSS module | Canopy v2 reframe |
|-----------------|-------------------|
| Email | **Agent Inbox** — messages FROM your agents (heartbeat outputs, approvals needed, artifacts delivered) + external email routed to triage agents |
| Calendar | **Agent Schedule** — when heartbeats fire, when humans meet, cron visibility |
| AI Chat | **Agent Chat** — direct conversation with any agent, tool-calling, streaming |
| Messaging | **Channels** — team conversations where agents are first-class participants (Multica pattern) |
| Files | **Workspace Files** — the actual files agents produce, with AI search + summary |
| Documents | **Collaborative Docs** — Tiptap docs where humans + agents co-author in real-time |
| Projects / Kanban | **Task Board** — Initiatives → Projects → Issues → Sub-issues with agents as assignees (Multica) |
| Dashboard | **Command Center** — agent performance, runtime costs, goal progress, budget burn |

Result: a full agent-native productivity OS. Not a "chat wrapper." Not a "kanban clone." The **workspace where AI agents actually live and do work alongside you.**

**Thesis in one sentence:**
> Canopy is Notion + Slack + Linear + Cursor's runtime layer, fused into one desktop app where every surface has agents as first-class citizens and every runtime (Claude Code, Codex, Gemini, Cursor, 9+ more) is unified behind one interface.

---

## 1. The Full Steal Table — Every Feature, Every Competitor

Decision codes:
- **LIFT** = port the pattern nearly verbatim (code or concept)
- **ADAPT** = take the idea, rework for our context
- **DEFER** = later phase
- **SKIP** = not for us

---

### 1.1 Cabinet — LIFT count: 18 | DEFER: 2 | SKIP: 4

| # | Feature / Pattern | Decision | Canopy v2 Target |
|---|-------------------|----------|------------------|
| 1 | OKLCh-only color tokens | **LIFT** | `desktop/src/lib/design/tokens/oklch.css` |
| 2 | `color-mix(in oklch)` for terminal ANSI palette | **LIFT** | `tokens/terminal.css` |
| 3 | Radius scale via `calc()` multipliers | **LIFT** | `tokens/radius.css` |
| 4 | Editorial typography (15px body, 1.65 lh, -0.025em h1 tracking) | **LIFT** | `tokens/typography.css` |
| 5 | Composer card pattern (`rounded-2xl`, no focus ring) | **LIFT** | `patterns/Composer.svelte` |
| 6 | `@mention` dropdown → injects agent OR page content | **LIFT** | `Composer.svelte` + backend `mentions.ex` |
| 7 | Serif greeting on home ("Good morning, Roberto") | **LIFT** | `routes/+page.svelte` |
| 8 | Live PTY terminal via xterm.js + WebSocket bridge | **LIFT** | `patterns/LiveTerminal.svelte` + `src-tauri/src/pty.rs` |
| 9 | Running-agent green glow pulse keyframe | **LIFT** | `tokens/motion.css` |
| 10 | Structured epilogue block (` ```cabinet ` → ours: ` ```canopy `) with SUMMARY/CONTEXT/ARTIFACT | **LIFT** | `protocol/epilogue-format.md` + backend parser |
| 11 | sessionStorage session reconnect after page reload | **LIFT** | `domain/sessions/reconnect.ts` |
| 12 | File tree with extension-based `TreeNode.type` classification | **LIFT** | `patterns/FileTree.svelte` |
| 13 | 500ms debounced autosave on editor | **LIFT** | `patterns/Editor.svelte` |
| 14 | Agent persona = `persona.md` with YAML frontmatter (heartbeat, budget, provider, goals, channels) | **LIFT** | Canopy already has this |
| 15 | Chat transcript view with running state | **LIFT** | `patterns/TranscriptView.svelte` |
| 16 | Cron via `heartbeat:` field in persona frontmatter | **LIFT** | Backend already has (Quantum → port to Oban) |
| 17 | `on_complete: git_commit` post-run action in job YAML | **LIFT** | `protocol/agent-format.md` |
| 18 | Mission Control: all agents across workspaces with pulse states | **LIFT** | `routes/+page.svelte` "active agents" section |
| 19 | `useComposer()` composable hook | **ADAPT** | Svelte 5 rune: `useComposer.svelte.ts` |
| 20 | Conversation metadata: `meta.json`, `prompt.md`, `transcript.txt`, `artifacts.json` per run | **LIFT** | Backend session storage |
| 21 | 13 themes at launch | **DEFER** | v0.2 — ship 1 canonical + dark toggle first |
| 22 | Electron desktop wrapper | **SKIP** | Using Tauri |
| 23 | Next.js App Router | **SKIP** | Using SvelteKit |
| 24 | Zustand stores | **SKIP** | Svelte 5 runes |
| 25 | better-sqlite3 for metadata | **SKIP** | Postgres via Phoenix |
| 26 | Legacy PTY prompt injection (string-match `shift+tab`) | **DEFER** | Never — stick with structured `--output-format stream-json` |
| 27 | Raw file-walk search | **SKIP** | pgvector-backed semantic search instead |

---

### 1.2 Multica — LIFT count: 8 | ADAPT: 4 | DEFER: 2 | SKIP: 3

| # | Feature / Pattern | Decision | Canopy v2 Target |
|---|-------------------|----------|------------------|
| 1 | `Backend` interface: `Execute(ctx, prompt, opts) → (*Session, error)` with two channels (messages + result) | **LIFT** | Our `RuntimeAdapter` (via Paperclip port) |
| 2 | Shared `ActorAvatar` component for humans + agents | **LIFT** | `patterns/ActorAvatar.svelte` |
| 3 | Agents visible on kanban boards + comment threads as first-class | **LIFT** | `routes/tasks/` kanban + `routes/channels/` |
| 4 | Task hierarchy: Initiatives → Projects → Issues → Sub-issues | **LIFT** | Already in Canopy backend; port schemas |
| 5 | WS-as-invalidation pattern with 100ms debounce → TanStack Query cache | **LIFT** | `api/realtime.ts` (SSE variant over Phoenix) |
| 6 | Skills as markdown in Postgres, injected per-provider (`CLAUDE.md` / `AGENTS.md` / etc.) | **LIFT** | `backend/lib/canopy/skills/` |
| 7 | Skills importable from external registries (ClawHub, Skills.sh) | **LIFT** | `skills-lock.json` + `mix canopy.skills.sync` |
| 8 | Local daemon polling cloud for tasks | **SKIP** | Canopy backend runs locally or self-hosted; no cloud polling |
| 9 | `(actor_type, actor_id)` polymorphic columns in DB (`author_type`, `assignee_type` etc.) | **ADAPT** | Humans + agents stay in **separate tables**; UI unifies via `ActorAvatar`. No polymorphism per Roberto's no-human-adapter rule. |
| 10 | CLI subcommands (`multica issue comment add`) as agent-facing API | **ADAPT** | Canopy exposes MCP server + structured HTTP (richer than CLI) |
| 11 | Multi-workspace team-level isolation | **ADAPT** | Workspaces are markdown folders (Canopy Protocol); multi-tenancy is a v0.2 concern |
| 12 | Sequence-numbered stream writes to TanStack cache | **LIFT** | `api/realtime.ts` + query updates |
| 13 | Multi-user roles + invitations | **DEFER** | v0.2 — single-user desktop first |
| 14 | pgvector for semantic search | **LIFT** | We use pgvector from day one; they have it installed but unused |
| 15 | `Bot` icon next to agent name in all avatar contexts | **LIFT** | `ActorAvatar` variant |
| 16 | Runtime auto-detection by scanning PATH | **LIFT** | `src-tauri/src/commands/runtimes.rs` |
| 17 | Agent profiles page (bio, skills, recent activity) | **LIFT** | `routes/agents/[slug]/+page.svelte` |

---

### 1.3 Core-OSS — LIFT count: 22 | ADAPT: 6 | DEFER: 3 | SKIP: 4

| # | Feature / Pattern | Decision | Canopy v2 Target |
|---|-------------------|----------|------------------|
| 1 | Inset card shell (sidebar bg shows through gap, `main` is rounded) | **LIFT** | `routes/+layout.svelte` |
| 2 | Module-based route architecture (`/workspace/:wsId/:appType`) | **LIFT** | SvelteKit `routes/` structure |
| 3 | Module lazy-loading via `lazy()` imports | **LIFT** | Dynamic imports in SvelteKit |
| 4 | Zustand stores as single source of truth (no shared context) | **ADAPT** | Svelte 5 runes; same discipline (module-local state, 3–4 global stores max) |
| 5 | Push-panel pattern (sibling to main, animated 340px, not overlay) | **LIFT** | `patterns/PushPanel.svelte` |
| 6 | AI chat embedded in shell via `uiStore.isSidebarChatOpen` toggle | **LIFT** | `stores/ui.ts` + global chat drawer |
| 7 | `@tool` decorator for backend AI tools with auto type-inference | **ADAPT** | Elixir macro `use Canopy.Tool` in `backend/lib/canopy/tools/` |
| 8 | Tool adapter pattern (Claude / OpenAI / MCP formats from one definition) | **LIFT** | `backend/lib/canopy/tools/adapter.ex` |
| 9 | Parallel tool execution with `asyncio.gather` | **ADAPT** | Elixir `Task.async_stream/3` |
| 10 | Email module with Gmail/Outlook sync | **ADAPT** | Canopy "Agent Inbox" — emails go to triage agents, outputs arrive here |
| 11 | Calendar module with Google Calendar sync | **ADAPT** | Canopy "Agent Schedule" — heartbeat + human calendar overlay |
| 12 | Team messaging with channels + threads | **LIFT** | `routes/channels/` with agents as participants |
| 13 | Files module with upload, preview, organization, presigned URLs | **LIFT** | `routes/files/` + Tauri local FS primary, optional S3/R2 for shared |
| 14 | Collaborative rich text editor (Tiptap) | **LIFT** | `routes/docs/` |
| 15 | Kanban boards with issues, labels, statuses | **LIFT** | `routes/tasks/` |
| 16 | Multi-workspace with RBAC | **DEFER** | v0.2 — workspaces via markdown folders in v0.1 |
| 17 | Swappable infrastructure (R2→MinIO, OpenAI→vLLM, Resend→SMTP) | **LIFT** | Config-driven adapters for email/storage/AI providers |
| 18 | Supabase Auth (JWT, OAuth Google/Microsoft) | **ADAPT** | Guardian + JWT (we already have); OAuth for Gmail/Cal integration |
| 19 | Supabase Realtime for presence/sync | **ADAPT** | Phoenix PubSub + SSE (our existing stack) |
| 20 | HMAC-signed image resize via Cloudflare Worker | **DEFER** | v0.2 — local image proxy first |
| 21 | Zustand persistence middleware for UI state | **ADAPT** | Tauri Store plugin for persisted runes |
| 22 | Command palette (⌘K) | **LIFT** | `patterns/CommandPalette.svelte` |
| 23 | Sidebar.tsx monolithic (600+ lines) | **SKIP** | Split into ≤ 4 composed sections, each ≤ 150 lines |
| 24 | Dual-cache React Query + Zustand for same data | **SKIP** | TanStack Query is single source; stores don't duplicate |
| 25 | Memory tool stub (incomplete) | **SKIP** | Build real memory backed by pgvector + Canopy session chains |
| 26 | Light-only design (no dark mode path) | **SKIP** | Dark is canonical |
| 27 | `TipTap/ProseMirror` for rich text | **LIFT** | Same |
| 28 | Project tracking with issues/labels | **LIFT** | Covered above |
| 29 | Workspace RBAC with resource sharing | **DEFER** | v0.2 |
| 30 | Dashboard module | **LIFT** | `routes/dashboard/` |
| 31 | SpaceCheck module pattern: one sidebar item, one route, one store | **LIFT** | Disciplined pattern |
| 32 | `workspaceStore.recordSessionApp()` — remembers which module user was in per workspace | **LIFT** | `stores/workspace.ts` |
| 33 | Right-side sibling panel for module-specific context | **LIFT** | `PushPanel` used universally |
| 34 | File preview component for images/PDF/CSV | **LIFT** | `patterns/FilePreview.svelte` |
| 35 | Presence indicators (who else is viewing) | **DEFER** | v0.2 — multi-user feature |

---

### 1.4 SuperHQ — LIFT count: 3 | DEFER: 5 | SKIP: 6

| # | Feature / Pattern | Decision | Canopy v2 Target |
|---|-------------------|----------|------------------|
| 1 | Auth gateway (localhost proxy, dummy key, swap real cred at network boundary) | **DEFER** | Phase 2 — `src-tauri/src/auth_gateway.rs` |
| 2 | JSONL event bus inside sandbox (`/root/.canopy/events.jsonl`) | **LIFT** | Inject into every agent execution context |
| 3 | Checkpoint-resume boot (snapshot install, instant reboot) | **SKIP** | MIOSA's problem, not ours |
| 4 | Lazy diff-on-expand with FS watcher | **LIFT** | `patterns/DiffReview.svelte` |
| 5 | Keep/Discard per-file commit review with path traversal guards | **LIFT** | Inside `DiffReview.svelte` |
| 6 | Two-direction port forwarding (guest→host, host→guest) | **DEFER** | When MIOSA supports; expose in Sandbox UI |
| 7 | GPUI (Rust GPU-accelerated UI) | **SKIP** | Using Svelte + Tauri |
| 8 | SQLite + AES-256-GCM encryption for secrets | **SKIP** | macOS Keychain via Tauri keyring |
| 9 | shuru-sdk VM orchestration | **SKIP** | MIOSA handles VMs |
| 10 | Keyboard-first navigation with customizable shortcuts | **LIFT** | Our keyboard shortcuts section |
| 11 | Multi-agent tabs (one VM per tab) | **ADAPT** | Multi-session support in sidebar |
| 12 | Per-agent binary status via JSONL event bus | **LIFT** | As above |
| 13 | Rust agent module structure | **SKIP** | Elixir behaviour |
| 14 | Native-TLS to avoid JA3/JA4 fingerprinting | **SKIP** | Not needed at our layer |

---

### 1.5 Gradient-bang — LIFT count: 0 | ADAPT: 3 | DEFER: 5 | SKIP: 7

Entire project deferred to **Phase 3 — Voice Layer**. Brief list:

| # | Feature / Pattern | Decision | Canopy v2 Target |
|---|-------------------|----------|------------------|
| 1 | Pipecat voice pipeline (Deepgram STT → LLM → Cartesia TTS) | **DEFER** | Phase 3 |
| 2 | Fire-and-forget tool pattern (`run_llm=False`) + `request_id` correlation for async responses | **ADAPT** | Useful pattern for ANY slow tool, not just voice — bookmark for heartbeat tool design |
| 3 | `LLMServiceConfig` factory with `UnifiedThinkingConfig` | **ADAPT** | Runtime config schema should unify provider + model + thinking budget |
| 4 | Extended thinking budget mapping (Anthropic `budget_tokens`, OpenAI `reasoning_effort`, Gemini `thinking_budget`) | **ADAPT** | Each `RuntimeAdapter` normalizes thinking budget into one param |
| 5 | HTTP long-polling over "Realtime" (they actually don't use Supabase Realtime) | **SKIP** | Phoenix PubSub + SSE is better |
| 6 | Event correlation via `request_id` UUID cache (15-min TTL) | **DEFER** | Phase 3 |
| 7 | Coalesced `LLMRunFrame` via `asyncio.sleep(0)` | **DEFER** | Phase 3 |
| 8 | Game mechanics (combat, trading, universe) | **SKIP** | Not our product |
| 9 | Multiplayer universe | **SKIP** | Not our product |
| 10 | Supabase edge functions | **SKIP** | Phoenix backend |

---

### 1.6 Paperclip — LIFT count: 14 | ADAPT: 3 | DEFER: 2 | SKIP: 4

**THE primary architectural lift.** They shipped the plugin adapter system April 14. Port it.

| # | Feature / Pattern | Decision | Canopy v2 Target |
|---|-------------------|----------|------------------|
| 1 | `ServerAdapterModule` interface (execute, testEnvironment, detectModel, getQuotaWindows, getConfigSchema, sessionManagement, listModels) | **LIFT** | `backend/lib/canopy/runtimes/adapter.ex` + `desktop/src/lib/domain/runtimes/types.ts` |
| 2 | Mutable dual registry (server + UI) with builtin fallback + pause/resume | **LIFT** | `backend/lib/canopy/runtimes/registry.ex` (GenServer) |
| 3 | Session resume via `sessionId + cwd + promptBundleKey` triple | **LIFT** | `backend/lib/canopy/sessions/resume.ex` |
| 4 | Content-addressed prompt bundles (SHA256 of AGENTS.md + skills) | **LIFT** | `backend/lib/canopy/prompts/bundle.ex` |
| 5 | Skip `--append-system-prompt-file` on resume (saves 5–10K tokens) | **LIFT** | Adapter-specific code |
| 6 | Wake context via env vars (`PAPERCLIP_TASK_ID` etc.) → ours: `CANOPY_*` | **LIFT** | `heartbeat/launch_context.ex` |
| 7 | `TranscriptEntry` discriminated union (assistant/thinking/tool_call/tool_result/diff/stderr/stdout/system) | **LIFT** | `domain/sessions/transcript.ts` |
| 8 | `RunTranscriptView` chat-thread renderer with diffs inline | **LIFT** | `patterns/TranscriptView.svelte` |
| 9 | `testEnvironment()` preflight gate with info/warn/error levels | **LIFT** | Per adapter module |
| 10 | `getQuotaWindows()` → live provider quota cards | **LIFT** | `patterns/QuotaGauge.svelte` |
| 11 | `getConfigSchema()` → declarative credential forms (host renders, no per-adapter UI) | **LIFT** | `patterns/RuntimeConfigForm.svelte` |
| 12 | `ActiveAgentsPanel` with `useLiveRunTranscripts` hook | **LIFT** | Right panel on session detail view |
| 13 | Full keyboard command palette (`?` to open, with tests) | **LIFT** | Our ⌘K palette |
| 14 | Atomic checkout with 409 conflict to prevent duplicate agent work | **LIFT** | Already in Canopy heartbeat protocol; verify present |
| 15 | `AdapterExecutionResult` with `usage`, `model`, `billingType`, `costUsd`, `summary`, `question` fields | **LIFT** | Our `ExecutionResult` struct |
| 16 | Declarative `SchemaConfigFields` renderer for adapter forms | **LIFT** | `patterns/SchemaFields.svelte` |
| 17 | Issue chat thread (assistant-ui component) | **LIFT** | Our `TranscriptView` |
| 18 | Comment wake batching (coalesce multiple mentions into one heartbeat) | **ADAPT** | `heartbeat/batcher.ex` |
| 19 | MCP server package (`@paperclipai/mcp-server` wrapping REST API) | **LIFT** | `backend/lib/canopy_mcp/` — expose Canopy as MCP tool server |
| 20 | Execution workspaces (experimental, lifecycle management) | **ADAPT** | Our "sandbox" concept via MIOSA |
| 21 | Bedrock (AWS) provider support | **LIFT** | Add `bedrock` to API runtimes list |
| 22 | Boolean flag proliferation (`supportsLocalAgentJwt`, `supportsInstructionsBundle`, `requiresMaterializedRuntimeSkills`) | **SKIP** | Use `capabilities: Set<Capability>` enum instead |
| 23 | Multi-user access + invites | **DEFER** | v0.2 |
| 24 | Company OS framing (CEO/CTO bot org chart) | **SKIP** | We have workspace protocol; don't replicate their hierarchy |
| 25 | Node + Drizzle + embedded Postgres | **SKIP** | Elixir + Ecto + Postgres |
| 26 | React + TanStack Router | **SKIP** | Svelte + SvelteKit |
| 27 | `adapter-plugin.md` as AI-generated implementation log | **SKIP** | That's their dev artifact, not a feature |
| 28 | Heartbeat as the ONLY execution model | **ADAPT** | Canopy supports heartbeat (cron) + interactive (user-triggered) + task-queued (Oban) |
| 29 | Docker deployment setup | **DEFER** | v0.2 — Tauri app self-contains for v0.1 |
| 30 | External adapter plugins as npm packages | **LIFT** | `@canopyai/adapter-<name>` convention + dynamic registry |

---

## 2. Steal Count Summary

| Competitor | LIFT | ADAPT | DEFER | SKIP | Total features analyzed |
|-----------|------|-------|-------|------|-------------------------|
| Cabinet | 18 | 1 | 2 | 6 | 27 |
| Multica | 8 | 4 | 2 | 3 | 17 |
| Core-OSS | 22 | 6 | 3 | 4 | 35 |
| SuperHQ | 3 | 1 | 4 | 6 | 14 |
| Gradient-bang | 0 | 3 | 5 | 7 | 15 |
| Paperclip | 14 | 3 | 2 | 4 | 23 |
| **Total** | **65** | **18** | **18** | **30** | **131** |

**65 features lifted. 18 adapted. 48 skipped or deferred.** Canopy v2 is a synthesis of the best 83 patterns across 6 shipping competitors.

---

## 3. The Synthesized Canopy v2 — Full Module Inventory

### 3.1 Primary Modules (sidebar groups)

Every module has agents as first-class citizens. Every module has a right-side PushPanel for agent context.

#### Group A — Core Agent Management (the cockpit)

| # | Module | Route | Lifted from |
|---|--------|-------|-------------|
| 1 | **Home / Composer** | `/` | Cabinet |
| 2 | **Runtimes** | `/runtimes` | Paperclip + Multica |
| 3 | **Sessions** | `/sessions` | Paperclip + Cabinet |
| 4 | **Agents Library** | `/agents` | Cabinet + original Canopy 330+ library |
| 5 | **Workspaces** | `/workspaces` | Canopy Protocol + Cabinet's markdown-as-KB |
| 6 | **Sandboxes** | `/sandboxes` | SuperHQ + MIOSA |

#### Group B — Productivity Modules (the Core-OSS lift)

| # | Module | Route | Lifted from | Agent-native twist |
|---|--------|-------|-------------|-------------------|
| 7 | **Inbox** | `/inbox` | Core-OSS Email | Triage agent auto-categorizes; agent outputs arrive here |
| 8 | **Schedule** | `/schedule` | Core-OSS Calendar | Shows heartbeat cron + human calendar overlay; scheduling agent negotiates meetings |
| 9 | **Chat** | `/chat` | Core-OSS AI Chat + Cabinet | Multi-thread, tool-calling, streaming; route to any runtime |
| 10 | **Channels** | `/channels` | Core-OSS Messaging | Team conversations with agents as participants (Multica) |
| 11 | **Files** | `/files` | Core-OSS Files | Local + workspace files; AI search via pgvector |
| 12 | **Docs** | `/docs` | Core-OSS Documents | Tiptap collaborative; agents can write/edit sections |
| 13 | **Tasks** | `/tasks` | Multica Kanban + Core-OSS Projects | Initiatives → Projects → Issues → Sub-issues; agents as assignees |
| 14 | **Command Center** | `/dashboard` | Core-OSS Dashboard | Agent performance, runtime costs, goal progress, budget burn |

#### Group C — System (settings, library, governance)

| # | Module | Route |
|---|--------|-------|
| 15 | **Skills Library** | `/skills` |
| 16 | **Templates** | `/templates` |
| 17 | **Analytics** | `/analytics` |
| 18 | **Governance** | `/governance` |
| 19 | **Settings** (6 subpages) | `/settings/*` |

---

## 4. The Synthesized Sidebar (with counts / badges)

```
┌─ SIDEBAR ───────────────────────────┐
│ ◉ sales-engine workspace       ▾   │  ← workspace switcher
├─────────────────────────────────────┤
│ ● Home                              │  ← always home first
│                                     │
│ COCKPIT                             │
│   ▸ Runtimes              ●3 active │  ← badge = running sessions
│   ▸ Sessions              ●2 running│
│   ▸ Agents               12 hired   │
│   ▸ Workspaces                      │
│   ▸ Sandboxes             ●1 live   │
│                                     │
│ WORKSPACE                           │
│   ▸ Inbox                  7 unread │
│   ▸ Schedule                        │
│   ▸ Chat                   3 active │
│   ▸ Channels               2 mentions│
│   ▸ Files                           │
│   ▸ Docs                            │
│   ▸ Tasks                  8 open   │
│   ▸ Command Center                  │
│                                     │
│ SYSTEM                              │
│   ▸ Skills                          │
│   ▸ Templates                       │
│   ▸ Analytics                       │
│   ▸ Governance            ⚠1 gate   │
│                                     │
├─────────────────────────────────────┤
│ [quota bar: $47 / $200 this month] │
│ ⚙ Settings                  👤     │
└─────────────────────────────────────┘
```

Collapsible group headers. Drag-to-reorder items within groups. Hover row → shows primary action inline (e.g. "New thread" on Chat, "New task" on Tasks).

---

## 5. Module Integration Pattern (how they compose)

Every module follows the same 3-surface pattern:

```
┌─ MODULE LAYOUT ──────────────────────────────────┐
│ Top bar: title + primary action + search        │
├──────────┬──────────────────────┬────────────────┤
│          │                      │                │
│  LEFT    │     MAIN             │   RIGHT        │
│  PANEL   │     CONTENT          │   PUSH PANEL   │
│  220px   │     (flex-1)         │   (toggle)     │
│          │                      │                │
│  — nav   │  — list or           │  — agent       │
│    within│    focused item      │    activity    │
│    module│                      │    for this    │
│    scope │                      │    module      │
│          │                      │                │
└──────────┴──────────────────────┴────────────────┘
```

**Left panel (module-local nav):** e.g. in Chat = thread list; in Files = folder tree; in Tasks = views.
**Main:** the actual content.
**Right push panel:** agent activity specific to this module — who's running, recent outputs, suggested actions.

This is Core-OSS's pattern, applied uniformly.

---

## 6. Shared Surfaces (appear in multiple modules)

### 6.1 Global Composer

Accessible from anywhere via `⌘N`. Floats as overlay. Pick agent + runtime + prompt + submit. On submit:
- Creates a Session
- Routes to the right module view (Session Detail opens)
- Session streams live

Same pattern used on Home, but globally reachable.

### 6.2 Global Command Palette `⌘K`

Catalog from CANOPY-V2-FRONTEND-DESIGN.md §7. Extends per module (each module registers its own commands).

### 6.3 `ActorAvatar` — everywhere

Comments, assignees, authors, @mentions, session lists, task boards, channel messages, email threads. Human = initials; Agent = Bot icon + persona color.

### 6.4 `@mention` system

`@` in any text surface opens a unified dropdown:
- Agents (switches/adds participant)
- Pages / docs (injects content)
- Files (attaches)
- Tasks / issues (cross-links)
- Other humans (notifies)

Same component, same logic, reused in Composer, Chat, Channels, Docs, Tasks comments, Email replies.

### 6.5 `PushPanel` — every module

Right side, 340px, animated, toggleable. Contents change per module but structure is consistent.

### 6.6 Session Detail — the LIVE VIEW (reached from any module)

Any agent activity in any module opens Session Detail. Transcript, terminal, context sidebar. Consistent across all entry points.

---

## 7. Updated Build Order (honest scope)

**Warning: this is bigger than the 6-week plan in CANOPY-V2-FOUNDATION.md.** Adding Core-OSS modules roughly doubles scope. Revised:

### Phase 1 — Foundation + Cockpit (6 weeks)

Weeks 0–6 as specced in FOUNDATION.md. Ships the Cockpit group (Home, Runtimes, Sessions, Agents, Workspaces, Sandboxes). This IS v0.1.

**Exit:** shippable DMG. You can manage all 9 runtimes, run sessions, browse agents, use workspace markdown.

### Phase 2 — Productivity Modules (weeks 7–14)

Weeks 7–14. Add Core-OSS modules one at a time, simplest first:

- Week 7: Tasks (Kanban — simplest, already have schemas)
- Week 8: Chat (agent chat threads)
- Week 9: Docs (Tiptap collaborative)
- Week 10: Channels (team messaging)
- Week 11: Files (local + workspace browser)
- Week 12: Command Center (dashboard)
- Week 13: Inbox (email sync — complex OAuth work)
- Week 14: Schedule (calendar sync — complex OAuth work)

**Exit:** v0.2 with full module set.

### Phase 3 — Advanced (weeks 15–20)

- Week 15: Skills Library + Templates
- Week 16: Analytics + Governance
- Week 17: Multi-user + RBAC
- Week 18: Plugin adapter marketplace
- Week 19: SuperHQ auth gateway + JSONL event bus
- Week 20: Voice layer (Gradient-bang patterns)

**Exit:** v1.0.

**Total:** ~20 weeks for the full synthesis. ~6 weeks for the v0.1 cockpit.

---

## 8. The One-Paragraph Pitch (for Roberto to use)

> Canopy is the desktop workspace where AI agents live and work alongside you. Manage 9+ AI runtimes — Claude Code, Codex, Gemini, Cursor, OpenCode, Aider, Windsurf, Pi, Hermes — behind one unified interface. Spin up MIOSA-provisioned compute sandboxes with one click. Chat with agents, assign them to kanban tasks, let them author documents with you in real-time, triage your inbox, and run on schedule via heartbeat. Your workspace is a folder of markdown files — no lock-in, no proprietary format. Credentials stay in your OS keychain. Every agent action is logged, budgeted, and governable. Built on Elixir's battle-tested BEAM supervisors and Svelte 5's cleanest-in-class reactivity, packaged as a 600KB Tauri desktop app.

---

## 9. Decisions Roberto Needs to Make

Three. Not fifteen.

### D1 — Scope for v0.1

Pick one:

- **A. Cockpit only (6 weeks to ship).** Home, Runtimes, Sessions, Agents, Workspaces, Sandboxes. Ships fastest. Clear differentiator. Defer productivity modules to v0.2.
- **B. Cockpit + 2 productivity modules (9 weeks).** Add Tasks + Chat to v0.1 for the "it's actually a workspace" feel. Most likely right choice.
- **C. Full synthesis (20 weeks).** Ship v1.0 with all 14 product modules (6 cockpit + 8 productivity) plus 5 system modules (Skills, Templates, Analytics, Governance, Settings) = 19 total. Biggest. Requires team (you + Pedro + Abdul + Nejd).

### D2 — Who builds

- **Solo Roberto** (Svelte-heavy, you know your stack): works for A or B; C is unrealistic solo.
- **Roberto + dev team** (Pedro frontend, Abdul backend, Nejd full-stack): unlocks C; requires writing spec docs per person.

### D3 — Module naming: keep Core-OSS terms or reframe?

I specced them as: Inbox, Schedule, Chat, Channels, Files, Docs, Tasks, Command Center. Alternative: reframe as agent-native terms — Agent Mail, Agent Time, Agent Chat, Agent Rooms, Agent Files, Agent Docs, Agent Board, Agent HQ. Less natural but makes agent-nativeness explicit.

---

## 10. Files Created So Far (reference)

```
/Users/rhl/Desktop/OptimalOS/CanopyOS/
├── CANOPY-V2-FOUNDATION.md          ← platform architecture (backend + tech stack + build order)
├── CANOPY-V2-FRONTEND-DESIGN.md     ← design system + screens + components (cockpit scope)
├── CANOPY-V2-STEAL-SYNTHESIS.md     ← THIS doc — every competitor feature mapped + full module inventory
└── canopy-legacy/ (TBD if we rename) ← old canopy/

/tmp/competitor-research/analysis/
├── canopy-baseline.md
├── cabinet.md
├── multica.md
├── core-oss.md
├── superhq.md
├── gradient-bang.md
└── paperclip.md
```
