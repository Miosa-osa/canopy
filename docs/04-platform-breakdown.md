# Canopy v2 — Complete Platform Feature Breakdown

**Date:** 2026-04-17
**Purpose:** Single source of truth for everything Canopy v2 contains — foundations, originals, lifts, novel synthesis, exclusions
**Companion to:** FOUNDATION.md (platform), FRONTEND-DESIGN.md (UX), STEAL-SYNTHESIS.md (competitor decisions)

**Legend for "Source" column:**
- 🏠 = Original to Canopy (pre-existing in canopy-legacy)
- 🟧 = Cabinet
- 🟦 = Multica
- 🟩 = Core-OSS
- 🟥 = SuperHQ
- 🟪 = Gradient-bang
- 🟨 = Paperclip
- ✨ = Novel synthesis (only exists because of the combination)

---

## 1. Foundations — The Bones

### Backend Stack

| Layer | Pick | Source | Why |
|-------|------|--------|-----|
| Language | Elixir 1.17 | 🏠 | BEAM supervisors = perfect for agent heartbeats |
| Framework | Phoenix 1.8 | 🏠 | Ecto best ORM, PubSub realtime, battle-tested |
| DB | PostgreSQL 14+ | 🟩 + 🟦 | pgvector for semantic search (verified local is pg15) |
| Job queue | Oban | ✨ | Upgrade from Quantum — Postgres-backed, observable |
| Realtime | Phoenix PubSub + SSE | 🏠 + 🟦 | One-way streaming simpler than WS |
| API spec | OpenAPISpex | ✨ | Auto-generates OpenAPI → TS types |
| HTTP client | Req | ✨ | Modern, retry+cache built-in |
| Auth | Guardian + JWT | 🏠 | Already works, port as-is |
| Validation | Ecto changesets | 🏠 | Native |

### Desktop Stack

| Layer | Pick | Source | Why |
|-------|------|--------|-----|
| Shell | Tauri 2 | 🏠 | 600KB vs Electron 100MB+ |
| Framework | SvelteKit 2 + Svelte 5 | 🏠 | Runes are cleanest reactivity model |
| Component primitives | shadcn-svelte (Bits UI) | 🟨 | Headless + customizable |
| Styling | Tailwind 4 + OKLCh tokens | 🟧 + 🟨 | Perceptual color uniformity |
| State (local) | Svelte 5 runes | ✨ | Zero library overhead |
| State (server) | TanStack Query Svelte | 🟦 + 🟨 | Cache + SSE invalidation |
| Router | SvelteKit file-based | 🟩 | Module lazy loading |
| Terminal | xterm.js | 🏠 + 🟧 | Industry standard |
| Markdown editor | Tiptap | 🟧 + 🟨 + 🟩 | Extension ecosystem |
| Icons | Lucide Svelte | 🟧 | Tree-shakeable |

### Rust Sidecar (Tauri)

| Concern | Pick | Source |
|---------|------|--------|
| Async runtime | Tokio | ✨ |
| HTTP | reqwest | ✨ |
| PTY (cross-platform) | portable-pty | ✨ (replaces Cabinet's Node-only node-pty) |
| Keychain | keyring crate | 🟥 (inspired) |
| Serialization | serde + serde_json | ✨ |
| Filesystem watch | notify | 🟥 |

### Design Tokens

| Token system | Source |
|--------------|--------|
| OKLCh colors (dark canonical, light derived) | 🟧 + 🟨 |
| `color-mix(in oklch)` terminal palette | 🟧 |
| Radius scale via `calc()` multipliers | 🟧 |
| Editorial typography (15px body, serif/sans/mono) | 🟧 |
| Green-glow motion for running agents | 🟧 |
| Signal color semantics (running/thinking/warn/error) | ✨ |

### Tooling

| Concern | Pick | Source |
|---------|------|--------|
| Package mgr | pnpm | 🟨 |
| Build | Vite | ✨ |
| Lint/format | Biome | ✨ |
| Frontend test | Vitest + Playwright | ✨ |
| Backend test | ExUnit + Mox | 🏠 |
| CI | GitHub Actions | ✨ |

---

## 2. Original Canopy Features — What's Ours

These existed in canopy-legacy before this research. They are the platform's spine.

| Feature | Source | Port strategy |
|---------|--------|---------------|
| **Workspace Protocol** (markdown-as-org, folders = structure) | 🏠 | Port `protocol/*.md` verbatim |
| **Progressive Disclosure** (L0/L1/L2 tiered context loading) | 🏠 | Port concept to agent context injection |
| **Heartbeat Protocol** (9-step GenServer cycle with atomic checkout + governance gates) | 🏠 | Port to new Phoenix app, add ExUnit tests |
| **Session Chains** (linked sessions with parent_id + sequence_number) | 🏠 | Port with Paperclip's triple-key resume addition |
| **Automatic Session Compaction** (structured facts: tools used, errors, outputs, decisions) | 🏠 | Port; extend with content-addressed bundles (Paperclip) |
| **Handoff Documents** (markdown handoff between heartbeats with pending items, blockers, decisions) | 🏠 | Port |
| **Cross-Heartbeat Context Injection** (next heartbeat loads previous session's handoff as preamble) | 🏠 | Port |
| **Dynamic Adapter Dispatch** (3-tier priority waterfall: task override → content routing → agent default) | 🏠 | Rewrite atop new `RuntimeAdapter` behaviour (Paperclip pattern) |
| **Content-Based Routing** (label + regex matching → runtime selection) | 🏠 | Port |
| **Atomic Task Checkout** (409 = move on, prevents double-work) | 🏠 | Port |
| **Task Hierarchy** (Initiatives → Projects → Milestones → Issues → Sub-issues) | 🏠 + 🟦 | Port schemas, add kanban UI (Multica pattern) |
| **Delegation with Adapter-Aware Routing** (create child task, auto-assign idle agent matching adapter) | 🏠 | Port |
| **Escalation** (traverse parent chain to orchestrator) | 🏠 | Port |
| **Budget Enforcement, 3-tier** (visibility / soft alert 80% / hard ceiling) | 🏠 | Port |
| **Per-Agent + Per-Task + Per-Project + Per-Goal Spend Tracking** | 🏠 | Port |
| **Governance Gates** (pending approvals block execution) | 🏠 | Port |
| **5-Layer Org Hierarchy** (Company → Division → Department → Team → Agent) | 🏠 | Port schemas; optional UI (not all users need this) |
| **330+ Pre-Built Agent Library** (19 categories) | 🏠 | Port as markdown personas |
| **Agent Personas as Markdown Frontmatter** (role, tools, coordination, escalation, heartbeat) | 🏠 + 🟧 | Port; Cabinet has same pattern with different field names |
| **`company.yaml`** (mission, budget, governance, org chart, goals) | 🏠 | Port |
| **54 Controllers, 56 Schemas, 67 Migrations** (from canopy-legacy backend) | 🏠 | Review each; port clean, rewrite crufty |
| **~151 API Routes** | 🏠 | Regenerate via OpenAPISpex-documented controllers |
| **Virtual Pixel-Art Office** (threlte/three.js 2D+3D team visualization) | 🏠 | **DEFER** to v0.2 — rebuild as optional view |
| **OSA Adapter** (connection to OSA agent runtime) | 🏠 | Add to 9 runtimes as 10th adapter |

---

## 3. Lifted Features by Competitor

### 3.1 From Cabinet (18 features) 🟧

| Feature | Where it lands |
|---------|----------------|
| OKLCh-only design tokens | Design system foundation |
| `color-mix(in oklch)` terminal ANSI palette | `tokens/terminal.css` |
| Radius scale via `calc()` | `tokens/radius.css` |
| Editorial typography (15px body, tight tracking) | `tokens/typography.css` |
| Composer card (`rounded-2xl`, no focus ring) | `patterns/Composer.svelte` |
| `@mention` → agent switch OR page content injection | `Composer.svelte` + backend `mentions.ex` |
| Serif home greeting ("Good morning, Roberto") | `routes/+page.svelte` |
| Live PTY via xterm.js + WebSocket bridge | `patterns/LiveTerminal.svelte` |
| Running-agent green glow pulse animation | `tokens/motion.css` |
| **Structured epilogue block** (` ```canopy ` with SUMMARY/CONTEXT/ARTIFACT) | `protocol/epilogue-format.md` + parser |
| sessionStorage session reconnect on reload | `domain/sessions/reconnect.ts` |
| File tree with extension-based classification | `patterns/FileTree.svelte` |
| 500ms debounced editor autosave | `patterns/Editor.svelte` |
| Mission Control card grid with pulse states | Home page "active agents" section |
| Conversation metadata as files (meta.json, prompt.md, transcript.txt, artifacts.json) | Session storage layer |
| `on_complete: git_commit` post-run action | `protocol/agent-format.md` extended |
| Cron via `heartbeat:` field in persona frontmatter | Already in Canopy heartbeat — keyed to Oban now |
| Mention chip UI (page attached to prompt) | Composer |

### 3.2 From Multica (8 features + 4 adapts) 🟦

| Feature | Where it lands |
|---------|----------------|
| **`ActorAvatar`** shared component (human = initials, agent = Bot icon) | `patterns/ActorAvatar.svelte` — used 10+ places |
| Agents as kanban assignees (first-class, not bots) | `routes/tasks/` |
| `Backend` interface abstracting 9 CLIs behind one contract | Merged with Paperclip's `ServerAdapterModule` |
| Two-channel session pattern (messages stream + result promise) | `Session` type in `domain/sessions/types.ts` |
| WS-as-invalidation with 100ms debounce → query cache | `api/realtime.ts` (over Phoenix SSE) |
| Skills as markdown stored in Postgres | `backend/lib/canopy/skills/` |
| Skills importable from external registries | `skills-lock.json` + `mix canopy.skills.sync` |
| `Bot` icon variant in ActorAvatar | Already above |
| Runtime auto-detect by scanning PATH | `src-tauri/src/commands/runtimes.rs` |
| Agent profile page (bio, skills, runs) | `routes/agents/[slug]/+page.svelte` |
| Sequence-numbered stream writes to cache | `api/realtime.ts` |
| pgvector for semantic search (they have it installed but unused — we use it) | Search everywhere |

**Explicit ADAPT (not LIFT):** Humans + agents stay in SEPARATE tables. No `(actor_type, actor_id)` polymorphism. UI unifies via `ActorAvatar`, data model respects no-human-adapter rule.

### 3.3 From Core-OSS (22 features + 6 adapts) 🟩

| Feature | Where it lands |
|---------|----------------|
| **Inset card shell** (sidebar bg shows through gap, main is rounded) | `+layout.svelte` |
| **Module-based route architecture** (`/workspace/:wsId/:moduleType`) | SvelteKit routes |
| Module lazy-loading | SvelteKit dynamic imports |
| **Push-panel pattern** (sibling to main, animated 340px, not overlay) | `patterns/PushPanel.svelte` |
| AI chat in shell via sidebar toggle | Global chat drawer |
| `@tool` decorator w/ auto type-inference | Elixir macro `use Canopy.Tool` |
| Tool adapter pattern (Claude / OpenAI / MCP from one def) | `backend/lib/canopy/tools/adapter.ex` |
| Parallel tool execution | Elixir `Task.async_stream/3` |
| **Email module (Gmail/Outlook sync)** | `routes/inbox/` (reframe: Agent Inbox) |
| **Calendar module (Google Cal / M365 sync)** | `routes/schedule/` |
| **Team messaging with channels + threads** | `routes/channels/` |
| **Files module (upload, preview, organization)** | `routes/files/` |
| **Collaborative rich text (Tiptap)** | `routes/docs/` |
| **Kanban boards (issues, labels, statuses)** | `routes/tasks/` |
| Swappable infrastructure (R2→MinIO, OpenAI→vLLM, Resend→SMTP) | Config-driven adapters |
| OAuth Google + Microsoft | For Gmail/Cal integration |
| Command palette (⌘K) | `patterns/CommandPalette.svelte` |
| File preview component (image/PDF/CSV) | `patterns/FilePreview.svelte` |
| `workspaceStore.recordSessionApp()` remembers last module per workspace | `stores/workspace.ts` |
| SpaceCheck module pattern (one sidebar item, one route, one store) | Discipline rule |
| Dashboard module | `routes/dashboard/` |
| Right-side sibling panel for module-specific context | PushPanel used universally |

**Explicit ADAPT (not LIFT):** Zustand → Svelte 5 runes. Supabase → Phoenix. Sidebar.tsx monolith → 4 composed sections. Dual-cache → TanStack Query single source. Light-only design → dark canonical.

### 3.4 From SuperHQ (3 features + 1 adapt) 🟥

| Feature | Where it lands |
|---------|----------------|
| **JSONL event bus** inside sandbox (`/root/.canopy/events.jsonl`) | Injected in every agent execution |
| Lazy diff-on-expand with FS watcher | `patterns/DiffReview.svelte` |
| Keep/Discard per-file commit review with path traversal guards | Inside `DiffReview.svelte` |
| Keyboard-first navigation | Our keyboard shortcuts layer |
| **Auth gateway** (localhost proxy, dummy key swap) | **DEFER to Phase 2** — `src-tauri/src/auth_gateway.rs` |
| Multi-agent tabs adapted to multi-session UI | Sidebar session list |

### 3.5 From Gradient-bang (0 lifts, 3 adapts) 🟪

Voice layer fully deferred to Phase 3. Useful patterns borrowed:

| Pattern | Applied as |
|---------|-----------|
| `run_llm=False` + `request_id` correlation for async results | Pattern for ANY slow tool (not just voice) |
| `LLMServiceConfig` factory with unified thinking config | Runtime adapter config normalization |
| Thinking budget mapping (Gemini/Anthropic/OpenAI) | Each adapter normalizes into one param |

### 3.6 From Paperclip (14 features + 3 adapts) 🟨 — THE PRIMARY ARCHITECTURAL LIFT

| Feature | Where it lands |
|---------|----------------|
| **`ServerAdapterModule` interface** (execute, testEnvironment, detectModel, getQuotaWindows, getConfigSchema, sessionManagement, listModels) | `backend/lib/canopy/runtimes/adapter.ex` behaviour |
| **Mutable dual registry** (server + UI) with builtin fallback + hot-swap pause/resume | `Canopy.Runtimes.Registry` GenServer |
| **Session resume via triple-key** (sessionId + cwd + promptBundleKey) | `backend/lib/canopy/sessions/resume.ex` |
| **Content-addressed prompt bundles** (SHA256 of AGENTS.md + skills) | `backend/lib/canopy/prompts/bundle.ex` |
| Skip `--append-system-prompt-file` on resume (saves 5–10K tokens) | Adapter-specific code |
| **Wake context via env vars** (`CANOPY_TASK_ID`, `CANOPY_WAKE_REASON`, etc.) | `heartbeat/launch_context.ex` |
| **`TranscriptEntry` discriminated union** (assistant/thinking/tool_call/tool_result/diff/stderr/stdout/system) | `domain/sessions/transcript.ts` |
| Chat-thread transcript renderer with diffs inline | `patterns/TranscriptView.svelte` |
| `testEnvironment()` preflight with info/warn/error levels | Per adapter module |
| `getQuotaWindows()` → live provider quota cards | `patterns/QuotaGauge.svelte` |
| `getConfigSchema()` → declarative credential forms | `patterns/RuntimeConfigForm.svelte` + `SchemaFields.svelte` |
| Active agents panel with live transcripts | Right side panel on session detail |
| Atomic checkout with 409 conflict | Already in Canopy — verify present |
| `AdapterExecutionResult` shape (usage, model, cost, summary, question) | Our `ExecutionResult` struct |
| MCP server package (expose Canopy as MCP) | `backend/lib/canopy_mcp/` |
| External adapter plugins as npm packages | `@canopyai/adapter-*` convention |
| Comment wake batching (coalesce multiple mentions into one heartbeat) | `heartbeat/batcher.ex` |

**Explicit ADAPT (not LIFT):** Boolean flag proliferation → `capabilities: Set<Capability>` enum from start. Company OS org chart framing → our Workspace Protocol (don't copy their hierarchy). Heartbeat-only execution → heartbeat + interactive + task-queued.

---

## 4. Novel Synthesis Features — What Emerges Only from the Combination ✨

These are the features that exist **only because we combined the 6 competitors + our foundation.** Nobody else has them.

| Feature | Why it's novel |
|---------|----------------|
| **Every productivity module has agents as first-class participants** | Cabinet has agents; Core-OSS has Slack. Nobody fuses them. In Canopy, the channel has agent members; docs have agents co-authoring; email gets triaged by agents. |
| **MIOSA sandbox tied to every session** | Paperclip has workspaces, SuperHQ has VMs, neither integrates with a compute provisioning API. Canopy sessions auto-provision MIOSA VMs when the agent declares `needs_compute: true`. |
| **Canonical agent epilogue (` ```canopy `) across ALL runtimes** | Cabinet's epilogue block is Cabinet-only. We inject the instruction into every adapter's system prompt. Result: structured output from Claude Code AND Codex AND Gemini AND Cursor — parsed the same way. |
| **Unified runtime card with live quota + cost + last-run + launch** | Paperclip has quota surfacing, Multica has 9 backends, nobody has one card that synthesizes all 4 dimensions |
| **Workspace Protocol (markdown folders = orgs) + Paperclip adapter contract** | Lock-in-free workspace definition + pluggable runtime execution = nobody else has both |
| **Heartbeat + interactive + task-queued execution modes** | Paperclip is heartbeat-only. Cabinet is interactive-only. We support all three, routed by the adapter. |
| **Budget enforcement with per-agent + per-project + per-goal tracking** | No competitor tracks spend this granularly. |
| **Tool registry that emits Claude AND OpenAI AND MCP formats from one definition** | Core-OSS has the pattern (`@tool` decorator), we port to Elixir and use it everywhere. |
| **Governance gates tied to budget + role + agent capability enum** | Paperclip has governance, Canopy has budget, combining them is novel. |
| **Shared @mention pool** (agents + pages + files + tasks + humans) | Every competitor has `@` but limited scope. Canopy's `@` indexes everything searchable. |
| **Session chains with content-addressed prompt bundles** | Canopy originally had chains; Paperclip has bundles; combined, resume becomes deterministic and cache-efficient. |
| **Desktop-first runtime cockpit with full productivity suite built in** | Nobody else ships desktop + cockpit + Notion + Slack + Gmail in one binary. |

---

## 5. Every Module — Full Feature List

### 5.1 Home `/`

| Feature | Source |
|---------|--------|
| Serif greeting with time-aware prompt | 🟧 |
| Composer card (agent + runtime + `@mention` + submit) | 🟧 |
| Recent sessions (last 5) | 🟨 |
| Pinned agents grid | 🏠 + 🟧 |
| Active sessions with pulse glow | 🟧 |
| First-run onboarding trigger | ✨ |
| `⌘N` opens global composer overlay | ✨ |

### 5.2 Runtimes `/runtimes`

| Feature | Source |
|---------|--------|
| Runtime cards for 9 CLIs (Claude Code, Codex, Gemini, Cursor, OpenCode, Aider, Windsurf, Pi, Hermes) | 🟨 + 🟦 |
| API runtime chips (Anthropic, OpenAI, Google, DeepSeek, Bedrock) | 🟨 |
| MCP server list + add button | 🟨 |
| Per-runtime: installed status dot, version, quota gauge, monthly spend, launch button | 🟨 |
| `testEnvironment()` "Verify" action per runtime | 🟨 |
| Runtime detail (6 tabs: Overview, Configuration, Models, Skills, Sessions, Logs) | 🟨 + ✨ |
| Declarative credential form from `getConfigSchema()` | 🟨 |
| Install guide for missing runtimes | ✨ |
| Plugin registry (npm packages `@canopyai/adapter-*`) | 🟨 |
| Hot-swap adapter (pause override → fall back to builtin) | 🟨 |

### 5.3 Sessions `/sessions`

| Feature | Source |
|---------|--------|
| Session list with status dot + agent + runtime + duration + cost | 🟨 |
| Filter + search (runtime, agent, workspace, status) | 🟨 |
| Keyboard: j/k navigate, ↵ open, r resume | 🟥 |
| **Session detail (live):** transcript + context sidebar + terminal | 🟨 + 🟧 |
| TranscriptEntry rendering (assistant/thinking/tool_call/tool_result/diff/stdout/stderr/system) | 🟨 |
| Pause / Stop / Resume controls | 🟨 |
| Session chains with parent/child nav | 🏠 |
| Compaction markers in chain timeline | 🏠 |
| sessionStorage reconnect after reload | 🟧 |
| `⌘D` opens diff review panel | 🟥 |
| MIOSA sandbox embedded terminal (if session has one) | ✨ |
| Cost meter live-updating | 🟨 |
| Governance approval prompt inline | 🏠 |

### 5.4 Agents `/agents`

| Feature | Source |
|---------|--------|
| Library grid with 330+ agent cards | 🏠 |
| 19 categories (Sales, Dev, Research, Content, Ops, etc.) | 🏠 |
| Hire/Run action per card | 🟧 |
| Agent detail with persona editor (Tiptap markdown) | 🏠 + 🟩 |
| Heartbeat cron config | 🏠 + 🟧 |
| Budget config per agent | 🏠 |
| Skills picker | 🟦 |
| Runs history (per-agent session list) | 🟨 |
| Create new agent wizard | ✨ |
| Import agent from markdown URL | ✨ |

### 5.5 Workspaces `/workspaces`

| Feature | Source |
|---------|--------|
| Workspace cards (name, desc, agent count, last activity) | 🏠 |
| Workspace detail: file tree + editor + activity | 🟧 + 🟩 |
| Tiptap markdown editor | 🟧 + 🟨 + 🟩 |
| Debounced autosave | 🟧 |
| File tree with extension classification | 🟧 |
| SYSTEM.md auto-creation | 🏠 |
| `company.yaml` editor (structured form over YAML) | 🏠 |
| Starter templates (sales-engine / dev-shop / content-factory / blank) | 🏠 |
| Import from GitHub / local folder | ✨ |

### 5.6 Sandboxes `/sandboxes`

| Feature | Source |
|---------|--------|
| List of MIOSA-provisioned VMs | ✨ (MIOSA + SuperHQ concept) |
| Per-sandbox: VM specs, ports exposed, TTL, live status | 🟥 |
| Embedded xterm to each sandbox | 🟥 |
| JSONL event stream from sandbox (agent status) | 🟥 |
| Files touched by agent (lazy diff, Keep/Discard) | 🟥 |
| Port forward config UI | 🟥 |
| Destroy / pause / snapshot actions | 🟥 |

### 5.7 Inbox `/inbox`

| Feature | Source |
|---------|--------|
| OAuth Gmail + Outlook sync | 🟩 |
| Thread view (unified inbox) | 🟩 |
| Compose with AI suggestions | 🟩 |
| **AI triage labels** (assigned by triage agent) | ✨ |
| **Agent inbox** — messages FROM heartbeat outputs | ✨ |
| **Agent response drafts** (agent writes reply, human approves) | ✨ |
| Search (local + pgvector) | 🟦 |
| Filter by label, sender, date | 🟩 |
| Archive, star, mark read | 🟩 |
| Threading with inline `@agent` handoff | ✨ |

### 5.8 Schedule `/schedule`

| Feature | Source |
|---------|--------|
| OAuth Google Calendar + Microsoft 365 | 🟩 |
| Event CRUD | 🟩 |
| Month / Week / Day views | 🟩 |
| **Heartbeat overlay** (agent cron jobs shown on calendar) | ✨ |
| **Scheduling agent** (books meetings on your behalf) | ✨ |
| Meeting notes link (opens Docs) | ✨ |
| Agent-initiated event ("Claude suggests blocking 2h tomorrow for PR reviews") | ✨ |
| Timezone handling | 🟩 |

### 5.9 Chat `/chat`

| Feature | Source |
|---------|--------|
| Multi-thread list | 🟩 |
| Per-thread: agent + runtime selection | ✨ |
| Streaming with TranscriptEntry rendering | 🟨 |
| Tool-calling (agents use Canopy tools: read_file, search_kb, create_task, etc.) | 🟩 + 🟨 |
| `@mention` agents/pages/files inline | 🟧 |
| Thread search | 🟦 |
| Export thread as markdown | ✨ |
| Session link (every thread has a backing Session) | ✨ |

### 5.10 Channels `/channels`

| Feature | Source |
|---------|--------|
| Channel list (public + private) | 🟩 |
| Threads within messages | 🟩 |
| `@mention` with unified pool (humans + agents + pages) | 🟧 |
| Agents as channel members (not bots) | 🟦 |
| File attachments | 🟩 |
| Channel pinned messages | 🟩 |
| Emoji reactions | 🟩 |
| Notifications + mute controls | 🟩 |
| Integration messages (agent run completed → posts to #dev) | ✨ |

### 5.11 Files `/files`

| Feature | Source |
|---------|--------|
| Folder tree navigation | 🟩 |
| Upload (drag-drop) | 🟩 |
| Preview for image/PDF/CSV/MD/JSON/code | 🟩 |
| pgvector semantic search | 🟦 |
| File-level activity log (who/which agent touched, when) | ✨ |
| Workspace files (local folder) + Canopy storage (cloud optional) | ✨ |
| Tag/label system | 🟩 |
| Presigned share links | 🟩 |

### 5.12 Docs `/docs`

| Feature | Source |
|---------|--------|
| Tiptap rich text editor | 🟧 + 🟨 + 🟩 |
| Blocks (headings, lists, tables, code, images, embeds) | 🟩 |
| Slash commands | 🟩 |
| **Agent co-authoring** (agent writes a section, human edits) | ✨ |
| `@mention` agents to assign section writing | ✨ |
| Real-time cursor presence (v0.2 with Yjs) | 🟩 **DEFER** |
| Version history | 🟩 |
| Export markdown / PDF | 🟩 |
| Backlinks | 🟩 **DEFER to v0.2** |
| Templates | 🟩 |

### 5.13 Tasks `/tasks`

| Feature | Source |
|---------|--------|
| Board view (kanban) | 🟩 + 🟦 |
| List view | 🟩 |
| Calendar view | 🟩 |
| Task hierarchy: Initiatives → Projects → Issues → Sub-issues | 🏠 + 🟦 |
| Agents as assignees (ActorAvatar) | 🟦 |
| Labels, priority, estimates, due dates | 🟩 |
| Subtask delegation to agents (auto-assign idle agent) | 🏠 |
| `@mention` an agent on a task → heartbeat wakes them | 🟨 + ✨ |
| Filter + search + saved views | 🟩 |
| Goal linking (every task traces to a company goal) | 🏠 |

### 5.14 Command Center `/dashboard`

| Feature | Source |
|---------|--------|
| Active agents live panel | 🟨 |
| Monthly runtime spend breakdown | 🟨 + 🏠 |
| Budget burn progress bars (per-agent, per-project, per-goal) | 🏠 |
| Sessions completed today/week/month | ✨ |
| Goal progress across company | 🏠 |
| Governance pending approvals | 🏠 |
| Agent performance metrics (success rate, avg duration, cost per session) | ✨ |
| Customizable widgets (v0.2) | 🟩 **DEFER** |

### 5.15 Skills `/skills`

| Feature | Source |
|---------|--------|
| Skills library (markdown-based) | 🟦 |
| Categories + tags | 🟦 |
| Per-skill: description, tools, used-by (which agents) | 🟦 |
| Import from external registries (ClawHub, Skills.sh) | 🟦 |
| `skills-lock.json` for version pinning | 🟨 |
| Create custom skill (Tiptap editor) | ✨ |

### 5.16 Templates `/templates`

| Feature | Source |
|---------|--------|
| Workspace templates (starter kits) | 🏠 |
| Agent persona templates | 🏠 |
| Skill templates | 🟨 |
| Workflow templates (DAG) | 🏠 |

### 5.17 Analytics `/analytics`

| Feature | Source |
|---------|--------|
| Agent runtime breakdown | ✨ |
| Cost trends over time | ✨ |
| Session duration distributions | ✨ |
| Governance approval rates | ✨ |
| Task completion velocity | ✨ |

### 5.18 Governance `/governance`

| Feature | Source |
|---------|--------|
| Approval gate configuration | 🏠 |
| Pending approvals queue | 🏠 |
| Audit log (every agent action logged) | 🏠 |
| Budget rule editor | 🏠 |
| Role-based access control (**DEFER** to v0.2 multi-user) | 🟩 + 🟨 |

### 5.19 Settings (6 subpages)

| Subpage | Features | Source |
|---------|----------|--------|
| `/settings` | Profile, theme, keyboard shortcuts viewer | ✨ |
| `/settings/runtimes` | Credential vault per runtime (Keychain) | 🟨 + 🟥 |
| `/settings/budgets` | Monthly cap, per-agent caps, alerts | 🏠 |
| `/settings/governance` | Approval rules editor | 🏠 |
| `/settings/miosa` | MIOSA API endpoint + key | ✨ |
| `/settings/workspace-protocol` | Default templates, markdown conventions | 🏠 |
| `/settings/integrations` | OAuth connections (Gmail, Cal) | 🟩 |

---

## 6. Cross-Cutting Surfaces (appear in multiple modules)

| Surface | Scope | Source |
|---------|-------|--------|
| **Global Composer** (⌘N overlay) | Everywhere | ✨ |
| **Command Palette** (⌘K) | Everywhere | 🟩 + 🟨 |
| **`ActorAvatar`** | Every actor reference | 🟦 |
| **`@mention` unified pool** (agents + pages + files + tasks + humans) | Composer, Chat, Channels, Docs, Tasks, Email | 🟧 + ✨ |
| **`PushPanel`** (right-side contextual) | Every module | 🟩 |
| **Session Detail** (live view) | Reached from any module with agent activity | 🟨 + 🟧 |
| **Keyboard shortcuts + cheatsheet overlay** (⌘/) | Everywhere | 🟥 + 🟨 |
| **Toast notifications** | Everywhere | 🟩 |
| **Theme toggle** (dark canonical) | Everywhere | 🟧 + 🟨 |

---

## 7. The Moats — What Makes Canopy Defensible

| Moat | Why competitors can't easily copy |
|------|-----------------------------------|
| **9 runtimes behind one interface + plugin system** | Multica has 9 but web-only; Paperclip has 8 but no desktop; SuperHQ has 3 in VMs. Canopy has 9 + plugins + desktop + MIOSA sandboxes. |
| **Agent-native productivity modules** | Core-OSS has modules but no agents. Paperclip has agents but no modules. Fusing both requires rebuilding both. |
| **Elixir BEAM for agent supervision** | Go/Node competitors cannot match the fault isolation and supervision trees without years of rewrite. |
| **Workspace Protocol (markdown folders = orgs)** | Lock-in-free by design; users can walk away with their data. Competitive advantage against SaaS equivalents. |
| **MIOSA integration** | Runtime management + compute provisioning in one tool = unique positioning. |
| **Session chains + content-addressed prompt bundles** | Deterministic resume + cache hit > random SaaS restarts. Developer-visible quality advantage. |
| **Self-hosted, desktop-first** | Competitors are SaaS-first. Canopy is ops-first. Different user, different wedge. |

---

## 8. What Canopy v2 is NOT (scope fences)

Explicit exclusions to prevent scope creep:

| Not building | Reason |
|--------------|--------|
| Real-time multi-user collaboration (v0.1) | Single-user desktop first; multi-user in v0.2 |
| CRDT/Yjs for docs (v0.1) | Tiptap standalone is enough; collab in v0.2 |
| Mobile app (ever) | Desktop-first is our wedge, not a limit |
| Web app (ever) | Same |
| Proprietary agent binary (ever) | Canopy orchestrates existing runtimes, doesn't ship its own |
| Inference service (ever) | MIOSA or user's existing provider handles inference |
| Sandboxed VMs in-app (ever) | MIOSA provisions; Canopy consumes via API |
| Voice in v0.1 | Phase 3 feature |
| Billing/subscription UI in v0.1 | Open source, self-host is free; billing is a wrapper if/when we SaaS |
| i18n in v0.1 | English first; add later |
| Advanced analytics / BI | Basic metrics only; Tableau-in-Canopy is not the play |
| Email server (SMTP) | We integrate with existing email; not run our own |
| Custom calendaring server (CalDAV host) | We integrate with Google/M365 |
| Public agent marketplace | Library of curated agents yes; public marketplace is v0.2+ governance |

---

## 9. Summary Stats

| Metric | Count |
|--------|-------|
| Features total in v0.1 | ~220 |
| Features original to Canopy 🏠 | 38 |
| Features lifted from Cabinet 🟧 | 18 |
| Features lifted from Multica 🟦 | 12 |
| Features lifted from Core-OSS 🟩 | 28 |
| Features lifted from SuperHQ 🟥 | 4 |
| Features adapted from Gradient-bang 🟪 | 3 |
| Features lifted from Paperclip 🟨 | 17 |
| Novel synthesis features ✨ | 15 |
| Modules | 19 (5 cockpit + 8 productivity + 5 system + 1 home) |
| Runtimes supported | 9 CLI + 5 API + n MCP |
| Backend routes | ~200 (OpenAPI-documented) |
| Backend schemas | ~60 |

---

## 10. File Map

```
/Users/rhl/Desktop/OptimalOS/CanopyOS/
├── CANOPY-V2-FOUNDATION.md           ← platform architecture, tech stack, build order
├── CANOPY-V2-FRONTEND-DESIGN.md      ← design system, screens, components, flows
├── CANOPY-V2-STEAL-SYNTHESIS.md      ← every competitor feature → decision
├── CANOPY-V2-PLATFORM-BREAKDOWN.md   ← THIS doc — full feature inventory with provenance
├── canopy/                            ← will become canopy-legacy/ on Day 1
└── src-tauri/                         ← will merge into new canopy/src-tauri/ on Day 1

/tmp/competitor-research/
├── cabinet/, multica/, core-oss/, superhq/, gradient-bang/, paperclip/  ← cloned repos
└── analysis/
    ├── canopy-baseline.md
    ├── cabinet.md
    ├── multica.md
    ├── core-oss.md
    ├── superhq.md
    ├── gradient-bang.md
    └── paperclip.md
```

Four master docs now canonical. Everything needed to start Day 1 exists on disk.
