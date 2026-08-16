# Canopy v2 — Master Platform Synthesis

**Date:** 2026-04-17
**Status:** Comprehensive plan. Awaiting Roberto's approval before any code.
**Supersedes:** Previous FOUNDATION.md draft

---

## 0. One-Sentence Thesis

> **Canopy v2 is a desktop platform that manages every AI agent runtime on your machine — Claude Code, Codex, Gemini, Cursor, OpenCode, Aider, Windsurf, Pi, Hermes — with MIOSA-provisioned compute sandboxes, credential vault, session history, workspace protocol, and governance. The runtimes are the product.**

Not a chat app. Not a notebook. Not a knowledge base. **A cockpit for agent execution.**

---

## 1. Where We Are Now (Baseline)

### Current Stack

| Layer | What's There | Status |
|-------|-------------|--------|
| Backend | Elixir 1.15 + Phoenix 1.8.5, 54 controllers, 56 schemas, 67 migrations, 151 routes | Works; undertested; adapter dispatch crufty |
| Frontend | SvelteKit 2 + Svelte 5 + Tauri 2, 56 pages, 20 component groups, 48 stores | Unpolished; state sprawl; no design system rigor |
| Rust sidecar | `src-tauri/` with filesystem.rs | Minimal |
| Design | No token system, no component primitives, inconsistent spacing/color | The visible gap |

### Scope vs Polish

**Scope:** markdown KB + agents + cron + terminal + kanban + 9 runtimes + email/cal/chat/files + VM-isolated agents + org chart + heartbeats + skills + governance + 5-layer org + 330 agents.

**Polish:** LOW. We have all the surfaces, but no design system rigor.

### The Diagnosis

**We're not behind on features. We're far ahead on scope.** The gap is polish, design system, UX craftsmanship.

The fix is: **proper foundation, polished UI, wire to our superior backend.**

---

## 2. Where We're Going (Target State)

### Product Shape

Canopy v2 is a Tauri desktop app. You launch it and see:

1. **Runtime Dashboard** — every AI runtime on your machine as a card: status, version, monthly spend, quota windows, launch button.
2. **Composer** — pick agent + runtime, type prompt, `@` mention KB pages, submit.
3. **Live Session** — xterm terminal streams PTY output; `TranscriptEntry` union parsed and rendered (thinking, tool calls, diffs, stdout/stderr, assistant text).
4. **Workspace Browser** — file tree, markdown editor, agent artifacts.
5. **Sandbox Panel** — MIOSA-provisioned VMs the current agent is operating in, with embedded terminal to each.
6. **Sessions History** — full chain view, compaction points, resume-from-any-point.
7. **Agents Library** — browse 330+ agent personas, hire with one click, edit persona markdown inline.
8. **Settings** — credential vault (macOS Keychain), runtime configs (declarative forms from adapter `getConfigSchema()`), budget rules, governance gates.

### The Differentiator

**Canopy v2** = 9+ runtimes + MIOSA sandboxes + desktop-first + markdown workspace protocol + heartbeat governance + plugin adapters.

Nobody else combines runtime management with provisioned compute. That's the moat.

---

## 3. Pattern Inventory — What Lands Where

Full mapping of patterns, sized by effort.

### Design system + composer UX

| Pattern | Canopy v2 destination | Effort |
|---------|----------------------|--------|
| OKLCh-only token system | `desktop/src/lib/design/tokens/oklch.css` | S |
| `color-mix(in oklch, ...)` ANSI terminal colors | `desktop/src/lib/design/tokens/terminal.css` | S |
| Radius scale via `calc()` multipliers | `oklch.css` | S |
| Editorial typography (15px, 1.65 lh, -0.025em tracking) | `typography.css` | S |
| Composer card pattern (rounded-2xl, no focus ring) | `desktop/src/lib/design/patterns/Composer.svelte` | M |
| Running-agent green glow pulse keyframe | `motion.css` | S |
| `@mention` → page content injection | `Composer.svelte` + backend endpoint | M |
| sessionStorage session reconnect | `domain/sessions/reconnect.ts` | S |
| Structured epilogue block (` ```canopy ` with SUMMARY/CONTEXT/ARTIFACT) | `protocol/agent-epilogue.md` + backend parser | M |

### Data model + realtime

| Pattern | Canopy v2 destination | Effort |
|---------|----------------------|--------|
| `ActorAvatar` shared component for humans + agents in UI | `desktop/src/lib/design/patterns/ActorAvatar.svelte` | S |
| **IMPORTANT:** humans and agents stay in SEPARATE tables (no `actor_type` polymorphism) — UI unifies presentation only, data model stays clean per Roberto's no-human-adapter rule | data model | — |
| WS-as-invalidation with 100ms debounce → query cache | `desktop/src/lib/api/realtime.ts` | M |
| Skills as markdown in Postgres, injected per-provider | `backend/lib/canopy/skills/` + `protocol/skills.md` | L |

### Shell + module architecture

| Pattern | Canopy v2 destination | Effort |
|---------|----------------------|--------|
| Inset card shell (sidebar bg shows through gap) | `desktop/src/routes/+layout.svelte` | S |
| Module lazy loading (each route its own bundle) | SvelteKit dynamic imports | S |
| Push-panel pattern (sibling to main, not overlay) | `desktop/src/lib/design/patterns/PushPanel.svelte` | M |
| Svelte 5 runes + module-local stores, NOT global sprawl | discipline rule | — |

### Sandbox / runtime hardening (Phase 2)

| Pattern | Canopy v2 destination | Effort | Phase |
|---------|----------------------|--------|-------|
| Auth gateway (dummy key + localhost proxy) | `src-tauri/src/auth_gateway.rs` | L | Phase 2 |
| JSONL event bus inside sandbox | `src-tauri/src/agent_events.rs` | M | Phase 2 |
| Checkpoint-resume boot for sandbox VMs | MIOSA's problem, not ours | — | N/A |
| Lazy diff-on-expand + Keep/Discard commit review | `desktop/src/lib/design/patterns/DiffReview.svelte` | M | Phase 2 |

### Voice (Phase 3)

| Pattern | Canopy v2 destination | Phase |
|---------|----------------------|-------|
| Pipecat voice pipeline | future `desktop/src/lib/domain/voice/` | Phase 3 |
| Fire-and-forget tools with `request_id` correlation | needed for any voice tool | Phase 3 |
| `LLMServiceConfig` abstraction | applies to our `RuntimeAdapter.listModels` | reference |

### Adapter contract (PRIMARY)

| Pattern | Canopy v2 destination | Effort |
|---------|----------------------|--------|
| `ServerAdapterModule` interface → `RuntimeAdapter` | `desktop/src/lib/domain/runtimes/types.ts` | M |
| Mutable dual registry with pause/resume hot-swap | `backend/lib/canopy/runtimes/registry.ex` + `desktop/src/lib/domain/runtimes/registry.ts` | M |
| Session resume triple-key (sessionId + cwd + promptBundleKey SHA256) | `src-tauri/src/pty.rs` + `backend/lib/canopy/sessions/` | M |
| `testEnvironment()` preflight with info/warn/error | per-adapter module | S |
| `getQuotaWindows()` live quota display | runtime cards | M |
| `getConfigSchema()` declarative credential forms | `desktop/src/lib/design/patterns/RuntimeConfigForm.svelte` | M |
| `TranscriptEntry` discriminated union | `desktop/src/lib/domain/sessions/transcript.ts` | S |
| Wake context via env vars (`CANOPY_*`) | `backend/lib/canopy/heartbeat/launch_context.ex` | S |
| Skip `--append-system-prompt-file` on resume | runtime adapter code | S |
| Content-addressed prompt bundles (SHA256) | `backend/lib/canopy/prompts/bundle.ex` | M |
| `capabilities: Set<Capability>` NOT boolean flag proliferation | designed in from start | — |

---

## 4. Tech Stack — Final, Justified

### Backend

| Concern | Pick | Why | Not this |
|---------|------|-----|----------|
| Language | Elixir 1.17 | BEAM supervisors are literally designed for agent heartbeats; 1M+ concurrent processes; let-it-crash reliability | Go (manual goroutine mgmt), Node (PM2 fragility), Python (GIL) |
| Framework | Phoenix 1.8 | Batteries included, Ecto is best ORM, PubSub for realtime, LiveView escape hatch | Rails (no BEAM), Express (bare) |
| DB | PostgreSQL 14+ | pgvector for semantic search, JSONB for agent metadata, proven (verified local is 14.22) | SQLite (single-user limits), Mongo (no joins) |
| Migrations | Ecto migrations | Native | — |
| Job queue | Oban | Postgres-backed (no Redis), observable, cron + unique jobs + retries | Quantum (less observable), Redis-based (ops burden) |
| Realtime | Phoenix PubSub + SSE | SSE simpler than WS for one-way; use WS only when bidirectional | Socket.io, gorilla/websocket |
| API spec | OpenAPISpex | Auto-generates OpenAPI 3.1 from controllers → TS types in frontend for free | Hand-writing |
| HTTP client | Req | Modern, built-in retry + cache | HTTPoison (older), Tesla (middleware-heavy) |
| Auth | Guardian + JWT | Already in canopy-legacy, works | — |
| Validation | Ecto changesets + Norm | Native | — |
| MIOSA client | Thin Req wrapper, optional generated from MIOSA OpenAPI | — | — |

### Desktop

| Concern | Pick | Why | Not this |
|---------|------|-----|----------|
| Shell | Tauri 2 | 600KB bundle, native webview, Rust sidecar for PTY | Electron (100MB+, Chromium bloat) |
| Framework | SvelteKit 2 + Svelte 5 | Runes = cleanest reactivity model shipped; less code than React; native Tauri support | React (verbose hooks), Vue (ecosystem fragmented) |
| Component primitives | shadcn-svelte (Bits UI) | Headless + fully customizable; shadcn patterns you know | Skeleton (opinionated), Melt raw (boilerplate) |
| Styling | Tailwind 4 + OKLCh tokens | CSS var-based tokens, Tailwind 4 is faster + native nesting | Tailwind 3 (slower), CSS-in-JS (runtime cost) |
| State (local) | Svelte 5 runes | Zero library overhead | Zustand (not needed), Redux (never) |
| State (server) | TanStack Query Svelte | Cache + SSE invalidation | Custom fetch + stores (duplicates truth) |
| Router | SvelteKit file-based | Native | — |
| Terminal | xterm.js + xterm addons | Industry standard | — |
| Markdown editor | Tiptap | Extension-rich, broad ecosystem | ProseMirror direct (too low), Milkdown (smaller community) |
| Icons | Lucide Svelte | Consistent, tree-shakeable | — |
| 3D (virtual office, optional) | Threlte v8 | Svelte-native Three.js | — |

### Rust Sidecar (Tauri)

| Concern | Pick | Why |
|---------|------|-----|
| Runtime | Tokio | Standard async |
| HTTP | reqwest | Standard |
| PTY | portable-pty | Cross-platform (Mac/Linux/Windows), unlike node-pty (Node-only) |
| Keychain | keyring crate via tauri-plugin-keyring | OS-native secret storage |
| Serialization | serde + serde_json | Standard |
| Filesystem watch | notify | Cross-platform FS events |

### Tooling

| Concern | Pick | Why |
|---------|------|-----|
| Package manager | pnpm | Fast, strict, good for monorepo |
| Build | Vite (via SvelteKit) | Native |
| Lint + format | Biome | Replaces ESLint + Prettier with one tool, 10× faster |
| TS | strict mode, branded types for IDs | No `any` anywhere |
| Frontend test | Vitest + Playwright | Unit + E2E |
| Backend test | ExUnit + Mox | Native + mocks. 80%+ coverage target |
| CI | GitHub Actions | ExUnit + Vitest + Playwright + cargo test + Tauri build matrix |
| Docs | Docusaurus or vitepress | Public-facing docs site |
| Observability | Telemetry + LiveDashboard in dev, OpenTelemetry for prod | — |

---

## 5. Platform Tree — Complete Directory Structure

```
canopy/                                    # v2 — monorepo, one codebase
├── CLAUDE.md                              # Agent operating protocol (loaded first)
├── FOUNDATION.md                          # this doc, canonical after approval
├── README.md                              # human-facing
├── LICENSE
├── Makefile                               # make dev, make test, make build
├── pnpm-workspace.yaml                    # pnpm monorepo config
├── package.json                           # root, devDeps only
├── .github/workflows/
│   ├── ci.yml                             # ExUnit + Vitest + Playwright + cargo test
│   └── release.yml                        # Tauri build + notarize + DMG
│
├── backend/                               # L0 — Elixir + Phoenix
│   ├── config/
│   ├── lib/
│   │   ├── canopy/                        # domain logic
│   │   │   ├── runtimes/                  # RuntimeAdapter registry + behaviour
│   │   │   │   ├── registry.ex            # GenServer, hot-swappable
│   │   │   │   ├── adapter.ex             # behaviour (Elixir interface)
│   │   │   │   ├── claude_local.ex
│   │   │   │   ├── codex_local.ex
│   │   │   │   ├── gemini_local.ex
│   │   │   │   ├── cursor_local.ex
│   │   │   │   ├── opencode_local.ex
│   │   │   │   ├── aider_local.ex
│   │   │   │   ├── windsurf_local.ex
│   │   │   │   ├── pi_local.ex
│   │   │   │   └── hermes_local.ex
│   │   │   ├── sessions/                  # session chains, compaction, resume
│   │   │   │   ├── session.ex             # schema
│   │   │   │   ├── chain.ex
│   │   │   │   ├── compactor.ex
│   │   │   │   └── resume.ex              # triple-key pattern
│   │   │   ├── agents/                    # agent personas, hiring, heartbeat
│   │   │   │   ├── agent.ex
│   │   │   │   ├── persona.ex             # markdown frontmatter parsing
│   │   │   │   ├── heartbeat.ex           # 9-step GenServer cycle (ported)
│   │   │   │   └── library.ex             # 330+ agent browse
│   │   │   ├── workspaces/                # markdown-as-org
│   │   │   │   ├── workspace.ex
│   │   │   │   ├── protocol.ex            # Workspace Protocol
│   │   │   │   └── filesystem.ex
│   │   │   ├── skills/                    # markdown skills with SHA256 bundles
│   │   │   │   ├── skill.ex
│   │   │   │   └── bundle.ex              # content-addressed
│   │   │   ├── governance/                # approval gates, audit log
│   │   │   ├── budgets/                   # 3-tier enforcement
│   │   │   ├── vault/                     # credential references (values in Keychain)
│   │   │   ├── miosa/                     # external API client
│   │   │   │   ├── client.ex              # Req wrapper
│   │   │   │   ├── sandbox.ex             # provisioning
│   │   │   │   └── types.ex
│   │   │   └── dispatch/                  # content-based adapter routing
│   │   ├── canopy_web/                    # Phoenix web layer
│   │   │   ├── controllers/               # REST endpoints
│   │   │   ├── channels/                  # Phoenix channels if needed
│   │   │   ├── plugs/
│   │   │   ├── schemas/                   # OpenAPISpex schemas
│   │   │   └── endpoint.ex
│   │   └── canopy_application.ex          # supervisor tree
│   ├── priv/
│   │   ├── repo/migrations/               # Ecto migrations
│   │   └── agents/                        # seed agent library (330+)
│   ├── test/
│   │   ├── canopy/                        # unit tests per module
│   │   ├── canopy_web/                    # controller tests
│   │   └── integration/                   # multi-runtime contract tests
│   ├── mix.exs
│   └── mix.lock
│
├── desktop/                               # L0 — SvelteKit + Svelte 5
│   ├── src/
│   │   ├── app.html
│   │   ├── app.css                        # imports tokens + resets
│   │   │
│   │   ├── routes/                        # L3 — pages
│   │   │   ├── +layout.svelte             # shell: sidebar + inset main
│   │   │   ├── +page.svelte               # home: composer + recent sessions
│   │   │   ├── runtimes/                  # runtime dashboard (the hero view)
│   │   │   │   ├── +page.svelte
│   │   │   │   └── [slug]/+page.svelte    # per-runtime detail
│   │   │   ├── sessions/
│   │   │   │   ├── +page.svelte           # history
│   │   │   │   └── [id]/+page.svelte      # live session view (xterm + transcript)
│   │   │   ├── agents/
│   │   │   │   ├── +page.svelte           # library browse
│   │   │   │   └── [slug]/+page.svelte    # persona editor
│   │   │   ├── workspaces/
│   │   │   │   ├── +page.svelte
│   │   │   │   └── [slug]/+page.svelte    # file tree + editor + terminal
│   │   │   ├── sandboxes/                 # MIOSA-provisioned VMs
│   │   │   │   └── [id]/+page.svelte      # embedded terminal to sandbox
│   │   │   └── settings/
│   │   │       ├── +page.svelte
│   │   │       ├── runtimes/              # credential vault per runtime
│   │   │       ├── budgets/
│   │   │       └── governance/
│   │   │
│   │   ├── lib/
│   │   │   ├── design/                    # L1 — design system
│   │   │   │   ├── tokens/
│   │   │   │   │   ├── oklch.css          # color tokens
│   │   │   │   │   ├── radius.css         # calc() scale
│   │   │   │   │   ├── typography.css
│   │   │   │   │   ├── motion.css         # keyframes + transitions
│   │   │   │   │   └── terminal.css       # color-mix ANSI palette
│   │   │   │   ├── primitives/            # shadcn-svelte components
│   │   │   │   │   ├── Button.svelte
│   │   │   │   │   ├── Input.svelte
│   │   │   │   │   ├── Dialog.svelte
│   │   │   │   │   ├── DropdownMenu.svelte
│   │   │   │   │   ├── Tabs.svelte
│   │   │   │   │   └── ...
│   │   │   │   └── patterns/              # composed patterns
│   │   │   │       ├── Composer.svelte           # prompt input
│   │   │   │       ├── ActorAvatar.svelte        # unified avatar
│   │   │   │       ├── LiveTerminal.svelte       # xterm + glow
│   │   │   │       ├── PushPanel.svelte          # right-side sibling panel
│   │   │   │       ├── DiffReview.svelte         # diff Keep/Discard (deferred)
│   │   │   │       ├── RuntimeCard.svelte        # runtime display card
│   │   │   │       ├── RuntimeConfigForm.svelte  # schema-driven form
│   │   │   │       ├── TranscriptView.svelte     # TranscriptEntry renderer
│   │   │   │       └── CommandPalette.svelte     # ⌘K overlay
│   │   │   │
│   │   │   ├── domain/                    # L2 — business logic (TS)
│   │   │   │   ├── runtimes/
│   │   │   │   │   ├── types.ts           # RuntimeAdapter interface
│   │   │   │   │   ├── registry.ts        # client-side registry
│   │   │   │   │   ├── detect.ts          # calls Tauri to scan PATH
│   │   │   │   │   └── adapters/          # per-runtime TS adapters if needed
│   │   │   │   ├── agents/
│   │   │   │   │   ├── types.ts
│   │   │   │   │   └── persona.ts
│   │   │   │   ├── sessions/
│   │   │   │   │   ├── types.ts           # Session, TranscriptEntry
│   │   │   │   │   ├── reconnect.ts       # sessionStorage pattern
│   │   │   │   │   └── epilogue.ts        # parse ```canopy block
│   │   │   │   ├── workspaces/
│   │   │   │   ├── miosa/                 # optional frontend MIOSA calls
│   │   │   │   └── vault/                 # Keychain via Tauri
│   │   │   │
│   │   │   ├── api/                       # L1 — API clients
│   │   │   │   ├── client.ts              # HTTP client to Phoenix backend
│   │   │   │   ├── realtime.ts            # SSE → TanStack Query invalidation
│   │   │   │   └── queries/               # one file per resource
│   │   │   │       ├── runtimes.ts
│   │   │   │       ├── sessions.ts
│   │   │   │       ├── agents.ts
│   │   │   │       └── ...
│   │   │   │
│   │   │   ├── stores/                    # L0 — global state (≤ 4)
│   │   │   │   ├── auth.ts
│   │   │   │   ├── workspace.ts
│   │   │   │   ├── currentSession.ts
│   │   │   │   └── ui.ts
│   │   │   │
│   │   │   └── tauri/                     # Tauri command bindings
│   │   │       ├── pty.ts
│   │   │       ├── runtimes.ts
│   │   │       ├── filesystem.ts
│   │   │       └── vault.ts
│   │   │
│   │   └── static/
│   ├── tests/
│   │   ├── unit/                          # Vitest
│   │   └── e2e/                           # Playwright
│   ├── package.json
│   ├── svelte.config.js
│   ├── vite.config.ts
│   ├── tsconfig.json
│   └── biome.json
│
├── src-tauri/                             # L0 — Rust sidecar
│   ├── src/
│   │   ├── main.rs
│   │   ├── lib.rs
│   │   ├── commands/                      # Tauri commands
│   │   │   ├── pty.rs                     # portable-pty sessions
│   │   │   ├── runtimes.rs                # detect binaries on PATH
│   │   │   ├── filesystem.rs              # workspace FS ops
│   │   │   ├── vault.rs                   # keyring wrapper
│   │   │   └── miosa.rs                   # optional MIOSA proxy from Rust
│   │   └── auth_gateway.rs                # (Phase 2)
│   ├── capabilities/
│   ├── icons/
│   ├── Cargo.toml
│   └── tauri.conf.json
│
├── packages/                              # shared across backend + desktop
│   ├── types/                             # TS types generated from OpenAPISpex
│   │   ├── package.json
│   │   └── src/
│   │       └── api.ts                     # `pnpm gen:types` from backend OpenAPI
│   └── protocol/                          # markdown specs (Canopy Workspace Protocol)
│       ├── agent-format.md
│       ├── skills-format.md
│       ├── workspace-format.md
│       └── epilogue-format.md             # ```canopy block spec
│
├── docs/                                  # Docusaurus or VitePress site
│   ├── getting-started/
│   ├── runtimes/                          # one doc per adapter
│   ├── protocol/                          # workspace protocol
│   └── api/                               # generated from OpenAPI
│
└── canopy-legacy/                         # IF we rename old canopy/ to this
    └── (read-only reference)
```

### Layer semantics (OpenViking-aligned: L0 at TOP)

| Layer | What | Where | Loads |
|-------|------|-------|-------|
| **L0** | Always-on roots | `CLAUDE.md`, `FOUNDATION.md`, `app.css`, `app.html`, `lib/stores/` | First |
| **L1** | Shared infra | `lib/design/tokens`, `lib/design/primitives`, `lib/api` | On app boot |
| **L2** | Domain logic | `lib/domain/*`, backend `lib/canopy/*` | On feature use |
| **L3** | Routes/pages | `routes/*`, backend controllers | Lazy per route |

---

## 6. Build Order — 6 Weeks

### Week 0: Scaffolding (3 days)

- Create `canopy/` monorepo, pnpm workspaces, CI boilerplate
- Scaffold Phoenix backend (`mix phx.new --no-html --no-assets`)
- Scaffold SvelteKit frontend (`pnpm create svelte@latest`)
- Scaffold Tauri (`pnpm tauri init`)
- Wire Biome, Vitest, Playwright, ExUnit
- GitHub Actions: PR checks run all test suites
- Decide `canopy-legacy/` vs `canopy-v2/` naming (Roberto's call)

**Exit:** `pnpm dev` boots empty app in Tauri window, `mix test` runs, CI is green.

### Week 1: Backend — Runtimes + Adapter Contract

- Ecto schemas: `runtimes`, `sessions`, `session_messages`, `agents`, `workspaces`, `credentials_ref`
- `Canopy.Runtimes.Adapter` behaviour (`ServerAdapterModule`-style contract)
- `Canopy.Runtimes.Registry` GenServer with pause/resume
- Implement 3 adapters first: `ClaudeLocal`, `CodexLocal`, `GeminiLocal`
- OpenAPISpex schemas for all runtime endpoints
- Unit tests per adapter, contract test suite

**Exit:** `POST /api/sessions` with `runtime: "claude-local"` spawns a Claude subprocess, streams transcript entries to SSE. 80%+ coverage.

### Week 2: Backend — MIOSA + Sessions + Skills

- MIOSA client module with typed `sandbox/2`, `exec/3`, `destroy/1`
- Sandbox lifecycle: provision on session start (if agent needs one), inject `CANOPY_MIOSA_SANDBOX_URL` env var
- Session chain + compaction + triple-key resume
- Skills as markdown + SHA256 content-addressed bundles
- Remaining 6 adapters: Cursor, OpenCode, Aider, Windsurf, Pi, Hermes

**Exit:** Integration test: create session → agent gets MIOSA sandbox → runs command inside → streams back → session compacts → resume works.

### Week 3: Backend — Realtime + Governance + Budgets

- Phoenix PubSub + SSE endpoint `/api/stream` for all transcript events
- Governance approval gates (blocks agent until human approves)
- Budget enforcement (visibility / soft alert @ 80% / hard ceiling)
- Heartbeat GenServer cycle ported from canopy-legacy
- Oban jobs for cron heartbeats
- **80% backend test coverage gate enforced in CI**

**Exit:** All 9 runtimes behind unified API. SSE works. Governance blocks work. Oban schedules work. Backend is frozen for frontend consumption.

### Week 4: Frontend — Shell + Tokens + Runtime Dashboard

- OKLCh token system
- shadcn-svelte primitives installed + themed
- Inset shell layout
- Runtime Dashboard page: cards with status, version, quota, launch button
- `RuntimeConfigForm.svelte` driven by `getConfigSchema()` from backend
- Dark/light toggle works, tokens consistent

**Exit:** You can open the app, see all 9 runtime cards, click settings, paste API key (stored in Keychain), click "verify" to run `testEnvironment()`.

### Week 5: Frontend — Composer + Sessions + Workspaces

- Composer card with agent picker, runtime picker, `@mention`
- `LiveTerminal.svelte` with xterm + glow pulse + TranscriptEntry renderer
- Session history page + session chain view
- Workspace file tree + markdown editor (Tiptap)
- Agent library browse + hire flow
- sessionStorage reconnect glue

**Exit:** You can pick agent, pick runtime, type prompt, hit submit, watch live PTY stream, get structured transcript, refresh page mid-session and terminal reconnects.

### Week 6: Polish + Installer + Ship v0.1

- Empty states, loading states, error states
- Onboarding flow (first-run detect runtimes, prompt for MIOSA key)
- Motion polish (hover states, transitions)
- DMG + Windows installer + Linux AppImage
- Auto-update via Tauri updater
- Internal dogfooding

**Exit:** `canopy-0.1.0-arm64.dmg` shippable. Team installs, uses for real work.

---

## 7. Migration from canopy-legacy

### Port immediately (Week 0–1)

- `architecture/*.md` — architecture specs (thinking is sound)
- `protocol/*.md` — workspace protocol specs
- `operations/*` — workspace templates (sales-engine, dev-shop, etc.)
- `library/*` — 330+ agent library (markdown personas)
- `src-tauri/src/filesystem.rs` — works, no reason to rewrite

### Port with rewrite (Week 1–3, as needed)

- Ecto schemas — review each, port if clean, rewrite if crufty
- Heartbeat GenServer — port with tests
- Session chains + compaction — port with tests
- Adapter dispatch → rewrite as `RuntimeAdapter` behaviour
- Controllers → rewrite with OpenAPISpex
- Auth (Guardian + JWT) — port as-is
- Quantum scheduler → replace with Oban

### Do not port

- `canopy/desktop/src/*` — all frontend code (restart fresh against new design system)
- `canopy/desktop/src 2/` — abandoned experiment
- All Zustand stores → use Svelte 5 runes + TanStack Query
- Virtual pixel-art office — defer, rebuild as standalone page later if wanted

---

## 8. Decisions Roberto Needs to Make

Only 4. Not 15.

1. **Approve this synthesis?** (or redline specific sections)
2. **Folder naming:** rename `canopy/` → `canopy-legacy/` and create fresh `canopy/`? OR keep old + sibling `canopy-v2/`?
3. **Implementation strategy:** clean-room re-implementation of the adapter contract (no third-party code). **Confirm?**
4. **Who builds:** you solo (Svelte-heavy, will take the full 6 weeks), or parallel with Pedro/Abdul/Nejd (faster, but needs delegation docs for each person)?

---

## 9. Open Questions (non-blocking)

- **Virtual pixel-art office** — keep, drop, or defer to Phase 2?
- **Multi-workspace** — one-at-a-time or switcher?
- **330+ agent library** — port all, or curate down to top 50 for v0.1?
- **Skills marketplace** — needed for v0.1 or later?
- **Community plugin registry for adapters** — v0.1 or later?
- **Telemetry / analytics** — opt-in from v0.1 or defer?

Answer any time; not required to unblock Week 0.
