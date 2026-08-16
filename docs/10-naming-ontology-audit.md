# Canopy v2 — Naming, Topology, Ontology & Foundation Audit

**Date:** 2026-04-17
**Purpose:** Single audit of how names, categories, layers, and boundaries were chosen across backend, frontend, Rust sidecar, protocols, and docs. Flags inconsistencies with proposed fixes.

---

## 1. Naming — How Names Were Chosen

### 1.1 Backend (Elixir) — Pattern Rules Applied

| Rule | Example | Source of convention |
|------|---------|---------------------|
| **Plural context modules** for public APIs | `Canopy.Runtimes`, `Canopy.Sessions`, `Canopy.Agents` | Phoenix idiomatic — context boundary |
| **Singular schemas** | `Canopy.Runtimes.Runtime`, `Canopy.Sessions.Session` | Ecto idiomatic |
| **Role suffix** for infrastructural modules | `RegistryServer`, `ProcessRunner`, `Supervisor`, `Controller`, `Schema`, `Client` | Makes the module's shape visible from the name |
| **Concrete-thing-with-descriptor** for adapters | `ClaudeLocal`, `CodexLocal`, `GeminiLocal` | `Local` reserves space for future `ClaudeApi`, `ClaudeMcp` variants |
| **Underscored module-file mapping** | `CanopyWeb.Schemas.RuntimeSchema` → `runtime_schema.ex` | Mix convention |
| **PubSub topics namespaced** | `"session:<id>"` | Phoenix PubSub convention |

### 1.2 Frontend (TypeScript/Svelte) — Pattern Rules Applied

| Rule | Example |
|------|---------|
| **Layered directory taxonomy** | `lib/design/{tokens, foundation, patterns}`, `lib/domain/{runtimes, sessions, agents, workspaces}`, `lib/api/{client, realtime, queries}`, `lib/stores/`, `lib/tauri/` |
| **Module-per-pattern** for UI | `RuntimeCard.svelte`, `TranscriptView.svelte`, `ActorAvatar.svelte` — every reusable composition is one file |
| **Hyphenated CSS classes** with prefix | `.rtd-tab-content` (runtime-detail), `.sl-row` (sessions-list), `.agent-detail__name` (BEM-flavored) |
| **TanStack Query factories** live in `lib/api/queries/<resource>.ts` | `runtimesQuery()`, `sessionsQuery()`, `agentsQuery()` |
| **SvelteKit filesystem routing** | `routes/runtimes/[type]/+page.svelte` maps to `/runtimes/:type` |

### 1.3 Database — Conventions

- **Snake case table names** (plural): `runtimes`, `sessions`, `session_messages`, `agents`, `workspaces`
- **Primary key is `id`** — always `binary_id` (UUID)
- **Foreign key columns suffixed `_id`**: `session_id`, `runtime_id`, `parent_session_id`
- **Timestamps via `timestamps/0`**: `inserted_at`, `updated_at` (except `session_messages` which is append-only: `inserted_at` only)

### 1.4 Protocol Specs (markdown)

- **Kebab-case filenames**: `workspace-protocol.md`, `agent-format.md`, `signal-theory.md`
- **YAML frontmatter** required on agent files, optional on architecture docs
- **Canonical location**: `canopy/packages/protocol/` (v2) — ported verbatim from `canopy-legacy/protocol/`

### 1.5 Rust Sidecar (Tauri)

- **One module per domain**: `commands/{vault,runtimes,pty,filesystem}.rs`
- **Shared error type**: `CanopyError` (single enum with `thiserror`)
- **State carried via Tauri `.manage`**: `AppState`
- **Permissions file** at `permissions/canopy.toml` — Tauri v2 ACL convention

### 1.6 Known Inconsistencies Found

| # | Inconsistency | Impact | Proposed fix |
|---|---------------|--------|-------------|
| 1 | `Canopy.Miosa` vs brand "MIOSA" (acronym) | Low — Elixir idiom wins | Keep `Miosa`; add comment noting it's the MIOSA acronym, Elixir lowercases non-prefix capitals |
| 2 | **`docs/01-foundation.md`** (platform foundation) vs **`desktop/src/lib/design/foundation/`** (MIOSA Foundation primitives) | Medium — "foundation" overloaded | Rename doc to `01-platform.md` or rename dir to `design/miosa-foundation/`. Recommend the dir rename (cheaper, clearer) |
| 3 | `runtime_type` (column name is `type`) used ambiguously in app code + API | Medium — `POST /sessions { runtime: "..." }` vs `runtime_type:` in DB | Pick one canonical outward name (`runtime`) and internal alias (`runtime_type` in schema). Document in `04-platform-breakdown.md` |
| 4 | Legacy protocol specs reference `Company/Division/Department/Team` hierarchy that v2 explicitly DROPPED | High — stale docs misleading | Move to `packages/protocol/legacy/` or mark `DEPRECATED` in their headers |
| 5 | `TranscriptEntry` (runtime struct) vs `SessionMessage` (DB row) — two names for "what the agent said" | Low — but reviewers have asked | This is **intentional**: TranscriptEntry is the wire contract, SessionMessage is the persistence shape. Add a one-paragraph note in `docs/10-naming-ontology-audit.md` (this doc) |
| 6 | Module file names: mostly snake_case but `canopy/desktop/src/lib/design/foundation/osa/RoundedInput.svelte` is PascalCase | Low — Svelte+Foundation convention — OK | Leave. Document that component files are PascalCase when the file represents a single component class |
| 7 | `agent-format.md` protocol vs `Canopy.Agents.Agent` Ecto schema — two definitions of "agent shape" | Medium | Reconcile: the schema is what we persist; the markdown is what we seed from. Document the mapping in seeder's `@moduledoc` (already done) |
| 8 | Routes: `/runtimes/[type]` but SvelteKit default naming would be `/runtimes/[id]` — we used `type` as param name | Low — deliberate, `type` IS the primary key | Fine as-is, called out in 02-frontend-design.md |

---

## 2. Topology — Physical + Logical Structure

### 2.1 Physical Topology (what runs where)

```
┌───────────────────────── DESKTOP PROCESS (single Tauri binary) ─────────────────────────┐
│                                                                                          │
│  ┌─ Tauri webview ──────────────────────────────┐    ┌─ Rust sidecar ─────────────────┐  │
│  │  SvelteKit SPA (adapter-static)              │    │  commands:                     │  │
│  │  - port :5280 (vite dev only)                │    │  - vault (keyring)             │  │
│  │  - loads at tauri://localhost in production  │◄──►│  - runtime_detect ($PATH)      │  │
│  │  - 27 Foundation primitives + 14 patterns    │    │  - pty (portable-pty)          │  │
│  │  - TanStack Query + EventSource for SSE      │    │  - filesystem (guarded)        │  │
│  └──────────────────────────────────────────────┘    │  - app_state (PTY registry)    │  │
│                         │                            └────────────────────────────────┘  │
│                         │ HTTP / SSE                                                     │
│                         │ (CORS: tauri://localhost)                                      │
└─────────────────────────┼────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────── BACKEND PROCESS (BEAM / Phoenix / single node) ─────────────────┐
│                                                                                         │
│  port :9190  ─  Phoenix.Endpoint                                                        │
│    │                                                                                    │
│    ├── Router                                                                           │
│    │    ├── /api/v1/health, /api/v1/health/ready                                        │
│    │    ├── /api/v1/runtimes   (index/show/detect/test/models)                          │
│    │    ├── /api/v1/sessions   (index/show/create/delete/chain/messages)                │
│    │    ├── /api/v1/sessions/:id/events   (SSE)                                         │
│    │    └── /api/v1/openapi + /api/v1/docs (dev)                                        │
│    │                                                                                    │
│  Application supervisor (one_for_one):                                                  │
│    1. Telemetry                                                                         │
│    2. Repo (Postgres pool)                                                              │
│    3. DNSCluster                                                                        │
│    4. Phoenix.PubSub      ──► topic "session:<id>" for SSE                              │
│    5. Finch (Req HTTP pool)                                                             │
│    6. Oban (job queue, cron plugin)                                                     │
│    7. Canopy.Runtimes.RegistryServer (ETS — auto-registers 3 adapters on init)          │
│    8. Canopy.Sessions.Supervisor (DynamicSupervisor; 1 child per running session)       │
│    9. CanopyWeb.Endpoint                                                                │
│                                                                                         │
│  Per-session child = Canopy.Runtimes.ProcessRunner GenServer owning a Port to:          │
│    claude | codex | gemini | cursor | opencode | aider | windsurf | pi | hermes         │
│                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
                          │
                          ▼
                  PostgreSQL 14+ / pgvector
                  ├─ runtimes, runtime_models
                  ├─ sessions, session_messages
                  ├─ agents, workspaces
                  └─ oban_jobs

                  ┌──────────────────────────────┐
                  │  MIOSA API  (external, TBD)  │  ← POST /v1/sandboxes (future)
                  └──────────────────────────────┘
```

### 2.2 Logical Topology (dependency direction)

```
             User keyboard/mouse
                       ▼
        ┌──────────────────────────────┐
        │  L3  routes/ (pages)         │  depends on patterns + domain + api
        └──────────────────────────────┘
                       ▼
        ┌──────────────────────────────┐
        │  L2  design/patterns/        │  depends on foundation + domain types
        │  lib/domain/                 │  depends on nothing (pure types)
        │  lib/api/                    │  depends on domain types + client
        └──────────────────────────────┘
                       ▼
        ┌──────────────────────────────┐
        │  L1  design/foundation/      │  MIOSA primitives (external lift)
        │  lib/stores/                 │  global runes; depends on nothing
        └──────────────────────────────┘
                       ▼
        ┌──────────────────────────────┐
        │  L0  design/tokens/          │  CSS vars — pure data
        │  app.css                     │  imports tokens + tailwind
        └──────────────────────────────┘
```

**Invariant:** an L-N module can ONLY import from L-M where M ≤ N. Violations are caught by code review; no automated enforcement yet (Week 2 TODO: add `dependency-cruiser` or similar for JS; `mix xref` for Elixir).

### 2.3 Ownership Topology (who writes what)

| Agent | Owns | Excluded from |
|-------|------|---------------|
| `backend-elixir` | `backend/` | `desktop/`, `src-tauri/` |
| `frontend-svelte` / `osa-frontend-design` | `desktop/` (and sometimes `+layout.svelte` as shared) | `backend/`, `src-tauri/` |
| `devops-engineer` | root Makefile, `.github/`, `docs/`, `packages/` (meta) | `backend/lib/`, `desktop/src/`, `src-tauri/src/` |
| Rust/general-purpose | `src-tauri/` | Everything else |

Ownership boundaries are enforced **via prompt**, not via code. Violations in practice (schemas agent touching ClaudeLocal's parser during earlier Day 1 work) resolved by convention + on-review.

---

## 3. Ontology — The Conceptual Taxonomy

The things Canopy models. Each is defined in one place; all references resolve here.

### 3.1 Core Entities

| Entity | Definition | Identity | Persisted as | Code type |
|--------|------------|----------|--------------|-----------|
| **Runtime** | An AI execution engine installed locally or accessible via API | `type` (string) | `runtimes` row | `Canopy.Runtimes.Runtime` |
| **Adapter** | The Elixir module that wraps a Runtime and implements the `Canopy.Runtimes.Adapter` behaviour | Module name | Not persisted (in-memory via `RegistryServer`) | `Canopy.Runtimes.Adapter` behaviour |
| **Session** | One execution of a prompt by an agent on a runtime | UUID | `sessions` row | `Canopy.Sessions.Session` |
| **TranscriptEntry** | A single event emitted by an adapter during a session (assistant, thinking, tool_call, tool_result, diff, stdout, stderr, system, init, result) | `{session_id, sequence}` | `session_messages` row | `Canopy.Runtimes.TranscriptEntry` (runtime struct) / `Canopy.Sessions.SessionMessage` (DB shape) |
| **Agent** | A behavioral template (persona markdown + YAML frontmatter) a user can hire | `slug` | `agents` row | `Canopy.Agents.Agent` |
| **Workspace** | A folder of markdown representing a project context | `slug` | `workspaces` row | `Canopy.Workspaces.Workspace` |
| **Skill** | A markdown instruction block injected into an agent's system prompt | SHA256 content hash | Stored in DB (Week 2) | `Canopy.Skills` — stub |
| **Tool** | A function callable by an agent via MCP or embedded system prompt instructions | name (string) | Stored in DB + registered in tool registry (Week 2) | `Canopy.Tools` — stub |
| **Sandbox** | A MIOSA-provisioned VM where an agent executes with real compute | sandbox_id (MIOSA-assigned) | Not persisted in Canopy (referenced from Session) | `Canopy.Miosa.Sandbox` — Week 2 |
| **Budget** | Spending ceiling per agent/project/goal with alert thresholds | `(scope_type, scope_id)` | `budgets` row (Week 2) | `Canopy.Budgets` — stub |
| **Governance gate** | An approval rule that blocks session execution | Rule ID | `governance_rules` row (Week 2) | `Canopy.Governance` — stub |

### 3.2 Relationships (cardinality)

```
Runtime 1 ─── N  RuntimeModel       (Claude Code has 3 models)
Runtime 1 ─── N  Session            (sessions executed via this runtime)
Agent   1 ─── N  Session            (sessions this agent ran)
Agent   1 ──── 1 Runtime (default)  (agent's default_runtime FK)
Workspace 1 ── N  Session
Workspace 1 ── N  Agent             (agents hired into this workspace)
Session 1 ─── N  SessionMessage     (transcript entries)
Session 1 ─── 1  Session (parent)   (chain — self-referential)
Session 0 ─── 1  Sandbox            (optional MIOSA VM)
Skill   N ─── M  Agent              (Week 2 — skill library membership)
```

### 3.3 Human vs Agent — The No-Polymorphism Rule

Per Roberto's feedback memory (`feedback_no_human_adapter.md`):
> "People are NOT agents. AI only in agents/. People in team/. No `adapter:human`. Ever."

**Applied in Canopy v2:**
- `agents` table and `users` table (Week 2) are **separate entities**, not a polymorphic `actors` table.
- UI unifies presentation via `ActorAvatar` component — same rendering surface, different data sources.
- Any backend join that today would do `(actor_type, actor_id)` polymorphism instead joins explicitly to `agents` or `users`.
- We explicitly **rejected** the `author_type IN ('member', 'agent')` polymorphic pattern.

### 3.4 Session → Message: Why Two Names

- **`TranscriptEntry`** = the wire/runtime contract. Emitted by `Canopy.Runtimes.ProcessRunner`, broadcast over PubSub, streamed to SSE, rendered by `TranscriptView.svelte`. Discriminated union on `kind`.
- **`SessionMessage`** = the DB persistence shape. One row per TranscriptEntry. Append-only. Has DB-specific fields (id, sequence, inserted_at).

The two exist because the runtime shape and the DB shape have different invariants. TranscriptEntry has no `id` until persisted; SessionMessage does. The persister (`Canopy.Sessions.add_message/2`) is the conversion boundary.

---

## 4. Platform Breakdown (19 Modules)

Per `docs/04-platform-breakdown.md`. Current implementation status in parentheses.

### Group A — Cockpit (6 modules — agent runtime management)

| # | Module | Route | UI status | Backend status |
|---|--------|-------|-----------|----------------|
| 1 | Home | `/` | ✅ shipped | N/A (composes queries) |
| 2 | Runtimes | `/runtimes` (+ detail, test, models, detect) | ✅ shipped | ✅ shipped (5 endpoints) |
| 3 | Sessions | `/sessions` + `/sessions/[id]` live SSE | ✅ shipped | ✅ shipped (6 endpoints including SSE) |
| 4 | Agents | `/agents` + `/agents/[slug]` | ✅ shipped | ⚠️ partial (schema + seeder, controller is Week 2) |
| 5 | Workspaces | `/workspaces` | 🟡 coming-soon placeholder | ⚠️ schema only |
| 6 | Sandboxes | `/sandboxes` | 🟡 coming-soon placeholder | ⚠️ Week 2 (depends on MIOSA API) |

### Group B — Productivity (8 modules)

| # | Module | Route | Status |
|---|--------|-------|--------|
| 7 | Inbox | `/inbox` | 🟡 coming-soon |
| 8 | Schedule | `/schedule` | 🟡 coming-soon |
| 9 | Chat | `/chat` | 🟡 coming-soon |
| 10 | Channels | `/channels` | 🟡 coming-soon |
| 11 | Files | `/files` | 🟡 coming-soon |
| 12 | Docs | `/docs` | 🟡 coming-soon |
| 13 | Tasks | `/tasks` | 🟡 coming-soon |
| 14 | Command Center | `/dashboard` | 🟡 coming-soon |

### Group C — System (5 modules)

| # | Module | Route | Status |
|---|--------|-------|--------|
| 15 | Skills | `/skills` | 🟡 coming-soon |
| 16 | Templates | `/templates` | 🟡 coming-soon |
| 17 | Analytics | `/analytics` | 🟡 coming-soon |
| 18 | Governance | `/governance` | 🟡 coming-soon |
| 19 | Settings (6 subpages) | `/settings/*` | 🟡 coming-soon |

**Current reality:** 6 of 19 modules live (31.6%). Of those, Sessions is the most feature-complete; Workspaces and Sandboxes are route placeholders only.

---

## 5. Architecture Foundation — The Layer Stack

The invariants every new file must respect.

### 5.1 Six-Layer Stack (bottom-up)

```
┌─ L5 — Application surfaces ─────────────────────────────┐
│  Desktop routes (SvelteKit)  ·  Phoenix controllers      │
│  Tauri window title + menu   ·  CI workflows             │
└──────────────────────────────────────────────────────────┘
                         ▲
┌─ L4 — Domain logic ─────────────────────────────────────┐
│  Canopy.Runtimes, Sessions, Agents, Workspaces, Skills   │
│  desktop lib/domain, desktop lib/api/queries             │
│  Tauri commands (domain-aware: vault, pty, runtime_detect) │
└──────────────────────────────────────────────────────────┘
                         ▲
┌─ L3 — Infrastructure ───────────────────────────────────┐
│  Ecto + Postgres + pgvector                              │
│  Oban (job queue)     ·  Phoenix.PubSub (fan-out)        │
│  Corsica (CORS)       ·  OpenAPISpex (contracts)         │
│  Guardian (JWT)       ·  Finch (HTTP)                    │
│  Svelte 5 runes (reactivity)  ·  TanStack Query (cache)  │
│  Tauri 2 (shell)      ·  portable-pty, keyring            │
└──────────────────────────────────────────────────────────┘
                         ▲
┌─ L2 — Protocol contracts ───────────────────────────────┐
│  RuntimeAdapter behaviour                                │
│  TranscriptEntry discriminated union                     │
│  Workspace Protocol (markdown-as-org)                    │
│  Canopy epilogue block (```canopy``` in agent output)     │
│  OpenAPI 3.1 via OpenAPISpex                             │
└──────────────────────────────────────────────────────────┘
                         ▲
┌─ L1 — Language + runtime primitives ────────────────────┐
│  Elixir 1.19.5 / OTP 28 (BEAM)                           │
│  SvelteKit 2 + Svelte 5 + Tailwind 4                     │
│  Rust 1.94 + Tokio + Tauri 2                             │
│  Node 24 + pnpm 9                                         │
└──────────────────────────────────────────────────────────┘
                         ▲
┌─ L0 — External dependencies ────────────────────────────┐
│  Foundation component library (Miosa-osa/foundation)     │
│  MIOSA API (external service, Week 2)                    │
│  9 AI runtime binaries (Claude Code, Codex, Gemini, ...) │
│  PostgreSQL daemon                                        │
└──────────────────────────────────────────────────────────┘
```

### 5.2 Rules Cascading From This Stack

1. **L2 protocols are immutable mid-week.** `RuntimeAdapter` signatures, `TranscriptEntry` shape, OpenAPI spec — any change requires a minor version bump + migration plan.
2. **L4 domain modules are pure where possible.** Side effects live in `canopy/sessions/supervisor.ex`, controller actions, or Tauri commands.
3. **L5 surfaces compose L4 primitives, never inline business logic.** A route that reaches into `Canopy.Repo.query!` directly is a code smell.
4. **L0 external deps are pinned.** No lockfile drift tolerated. `make doctor` enforces runtime versions; `mix.lock`, `pnpm-lock.yaml`, `Cargo.lock` pin dep versions.
5. **File size rules are architectural, not style:**
   - Elixir `.ex`: ≤150 LOC (GenServer exception up to 250)
   - Svelte `.svelte`: ≤150 LOC (hero pages exception up to 250 with justification in header comment)
   - TypeScript `.ts`: ≤200 LOC
   - Rust `.rs`: ≤100 LOC (PTY-style GenServer-equivalent up to 200)

### 5.3 Testing Contract

Every layer has an expected test type:

| Layer | Test type | Runner |
|-------|-----------|--------|
| L4 domain | Unit — pure function, 80%+ coverage | ExUnit + Vitest + `cargo test` |
| L5 surfaces | Integration — hit real HTTP, render real Svelte | ExUnit ConnCase + Playwright E2E |
| L2 protocols | Contract — schema validation, fake adapter fixtures | `fake_claude.sh`, `fake_codex.sh`, `fake_gemini.sh` |
| L0 externals | Smoke — is the binary on `$PATH`? Does the DB accept connections? | `make doctor`, readiness probe |

### 5.4 Current Gaps in the Foundation (honest)

1. **No automated layer-boundary enforcement.** L5 could import from L2 directly today; nothing stops it.
2. **L2 contracts aren't schema-checked at build time.** OpenAPI spec is generated, but frontend doesn't consume it for type checking yet (Week 2 task).
3. **Cross-cutting concerns** (logging, tracing, metrics) live in L3 Phoenix Telemetry, but there's no equivalent on the frontend side. Week 2+.
4. **Agent ↔ User polymorphism** is solved by `ActorAvatar` UI component alone. The data model respects "no adapter:human" but nothing PREVENTS a future migration from adding such a column. Documentation is the only guardrail.
5. **19 modules / 6 shipped** — the foundation supports them all, but 13 are placeholder routes. Nothing prevents the foundation from holding that scale; it's just work.

---

## 6. Remediation Queue (concrete, numbered, small)

Ordered by ratio of (impact × frequency-of-use) ÷ effort:

1. **[M, 1h]** Rename `desktop/src/lib/design/foundation/` → `desktop/src/lib/design/miosa-foundation/` to resolve the "foundation" name collision (inconsistency #2). Update biome.json + imports.
2. **[M, 30min]** Move obsolete org-hierarchy protocol specs (`company-format.md`, `division-format.md`, `department-format.md`, `team-format.md`) to `packages/protocol/legacy/` with a DEPRECATED header (inconsistency #4).
3. **[L, 15min]** Add `@moduledoc` note to `Canopy.Sessions.SessionMessage` explaining the TranscriptEntry↔SessionMessage distinction (inconsistency #5).
4. **[M, 1-2h]** Decide + document canonical outward name for runtime identifier (`runtime` in APIs; `runtime_type` as internal column alias) (inconsistency #3). Update OpenAPI spec.
5. **[L, 20min]** Add `@moduledoc` to `Canopy.Miosa` noting the Elixir casing convention (inconsistency #1).
6. **[H, 4-8h]** Add dep-cruiser config for the desktop to enforce L0–L5 import rules (gap #1). `mix xref` for backend.
7. **[H, 2-4h]** Generate TS types from OpenAPI spec — auto-consumed by frontend TanStack queries — closing gap #2.
8. **[L, 30min]** Update `docs/04-platform-breakdown.md` §9 module counts to match the 6/19 reality (currently claims aspirationally).

Items 1–5 are the cheap wins and take < 4 hours total. Items 6–7 are multi-day and belong in Week 2.

---

## 7. Naming Decisions Made During This Session

For reference, the notable per-entity decisions:

| Name | Considered alternatives | Chosen because |
|------|-------------------------|----------------|
| `Canopy.Runtimes.Adapter` (behaviour) | `AdapterBehaviour`, `RuntimeModule`, `ServerAdapterModule` | Shortest valid Elixir-idiomatic name that signals its role |
| `RegistryServer` (GenServer name) | `Registry`, `AdapterRegistry`, `AdapterStore` | Avoids conflict with Elixir's `Registry` module; `Server` suffix signals it's a process |
| `ProcessRunner` (shared GenServer base) | `AdapterRunner`, `SubprocessSupervisor`, `Spawner`, `Runner` | `Runner` was too generic (three already exist); `ProcessRunner` is specific enough to grep |
| `TranscriptEntry` | `StreamEvent`, `AgentOutput`, `Message` | Message is ambiguous (DB vs wire); "transcript" matches the UI component name |
| `claude-local` / `codex-local` (runtime types) | `claude`, `claude-cli`, `claude-code-local` | `-local` reserves `-api`, `-mcp`, `-hosted` suffixes for future variants |
| `.canopy` code block (agent epilogue) | `.canopy-epilogue`, `.end-of-response` | Matches the brand; keeps tribal knowledge low |
| `/health/ready` (readiness probe) | `/ready`, `/healthz`, `/livez` | Kubernetes convention + distinct from `/health` liveness |
| `POST /runtimes/detect` (Tauri sync) | `PUT /runtimes`, `POST /runtimes/sync` | `detect` is a verb matching what the frontend is actually doing (running detection) |
| `sessions` PubSub topic `"session:<id>"` | `"runs:<id>"`, `"transcript:<id>"` | Matches the Ecto schema name; easy to recall |
| Frontend routes: `/runtimes/[type]` | `/runtimes/[id]`, `/runtimes/[slug]` | `type` IS the primary-key column name; no second identifier needed |

---

## 8. Summary — What Feels Right, What Feels Off

**Right:**
- Elixir context-plural, schema-singular is paying off; every `Canopy.X` module does one thing clearly
- Design tokens → foundation → patterns → routes is the cleanest Svelte layering I've shipped
- Markdown-first protocol specs survived rewriting the entire platform — validates the instinct
- The RuntimeAdapter behaviour + ProcessRunner base captures 90% of what 9 runtimes need
- Canopy Workspace Protocol + markdown agents = zero lock-in claim we can actually defend

**Off:**
- Two overloaded "foundation" names are the biggest paper cut today (fix soon, item 1)
- 19-module scope promise vs 6-module reality needs honest re-statement in breakdown doc (item 8)
- No enforcement of L-stack boundaries — will bite us in 3 months if not fixed (item 6)
- `Canopy.Miosa` casing looks wrong even though it's technically correct Elixir — cheap doc-level fix (item 5)
- Legacy org-hierarchy protocol files still linger in `packages/protocol/`, even though the schema dropped them (item 2)

The architecture is defensible. The naming is 90% consistent. The 10% is fixable in an afternoon. Nothing here is structural — no "we need to rename everything" moments.
