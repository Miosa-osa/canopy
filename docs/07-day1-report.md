# Canopy v2 — Day 1 Completion Report

**Date:** 2026-04-17
**Status:** ✅ COMPLETE — Week 1 unblocked
**Scope:** Week 0 scaffold + Day-1 hardening pass

---

## 1. Go / No-Go Decision

**GO.** All automated checks green. All architecture audits passed. All hardening
defaults in place. No known blockers for Week 1 (backend runtime adapter work).

---

## 2. What Shipped

### Monorepo root — 15 files

```
canopy/
├── README.md              quickstart + stack summary
├── NOTICE.md              First-party component provenance
├── LICENSE                Apache 2.0
├── Makefile               8 targets (doctor / setup / dev / test / lint / format / build / clean)
├── .gitignore             Elixir + Node + Rust + Tauri + OS + env
├── .editorconfig          tab Makefile, 2sp rest
├── .tool-versions         elixir 1.19.5-otp-28, erlang 28.0, nodejs 24.14.1, rust 1.94.1
├── pnpm-workspace.yaml    desktop + packages/*
├── package.json           @canopyai/root (private, dev-deps only)
├── CLAUDE.md              agent operating protocol (ownership, rules)
├── CONTRIBUTING.md        PR workflow + doc pointers
├── .github/workflows/
│   └── ci.yml             3 parallel jobs (backend + desktop + rust)
├── docs/                  7 canonical docs (see §5 below)
└── packages/types/        generated-types placeholder
```

### Backend — Phoenix app

```
backend/
├── mix.exs                deps: Phoenix, Ecto, Oban, Req, OpenAPISpex,
│                                 Guardian, Bcrypt, pgvector, Corsica, nanoid,
│                                 mox, ex_machina, credo, dialyxir
├── config/                config, dev, test, runtime
├── lib/
│   ├── canopy/
│   │   ├── application.ex         supervisor tree (9 children, correct order)
│   │   ├── runtimes.ex            public API
│   │   ├── runtimes/
│   │   │   ├── adapter.ex         behaviour
│   │   │   └── registry.ex        GenServer wrapper
│   │   ├── sessions.ex            public API stub
│   │   ├── sessions/
│   │   │   ├── session.ex         Ecto schema (binary_id, chain fields)
│   │   │   └── supervisor.ex      DynamicSupervisor
│   │   ├── agents.ex              stub
│   │   ├── workspaces.ex          stub
│   │   ├── skills.ex              stub
│   │   ├── tools.ex               stub
│   │   ├── governance.ex          stub
│   │   ├── budgets.ex             stub
│   │   ├── vault.ex               stub (Keychain-backed, backend only holds refs)
│   │   ├── miosa.ex               stub public API
│   │   └── miosa/client.ex        Req scaffold
│   ├── canopy_web/
│   │   ├── router.ex              /api/v1 scope + openapi + CORS plug
│   │   ├── api_spec.ex            OpenAPISpex
│   │   ├── endpoint.ex            stock + session
│   │   └── controllers/
│   │       ├── health_controller.ex
│   │       └── fallback_controller.ex
│   ├── canopy_web.ex
│   └── canopy.ex
├── priv/repo/migrations/
│   ├── 20260417211347_enable_pgvector.exs
│   └── 20260417211929_add_oban_jobs_table.exs
└── test/
    ├── canopy/runtimes_test.exs
    └── canopy_web/controllers/health_controller_test.exs
```

**Verification:** `mix compile --warnings-as-errors` + `mix test` (4/4) +
`mix format --check-formatted` + `mix credo --strict` all green.

**Live endpoint:** `GET http://localhost:9190/api/v1/health` →
`{"status":"ok","version":"0.1.0"}`.

### Desktop — SvelteKit + Svelte 5

```
desktop/
├── package.json           SvelteKit 2, Svelte 5, Tailwind 4, shadcn-svelte,
│                          TanStack Query, xterm.js, Tiptap 3, Bits UI, Biome,
│                          Vitest, Playwright, Tauri plugins
├── biome.json             override: .svelte excluded from noUnusedImports
│                          (Biome doesn't parse Svelte templates)
├── svelte.config.js       adapter-static + SPA fallback
├── vite.config.ts         Tailwind v4 plugin
├── src/
│   ├── app.html, app.css
│   ├── routes/
│   │   ├── +layout.svelte        139 LOC, inset shell pattern
│   │   ├── +layout.ts            prerender = true
│   │   └── +page.svelte          "Canopy is ready." placeholder
│   └── lib/
│       ├── design/
│       │   ├── tokens/           oklch + radius + typography + motion +
│       │   │                     terminal + spacing (all 6 files per spec §1–3)
│       │   └── primitives/
│       │       ├── button.svelte         (shadcn-svelte)
│       │       ├── input.svelte
│       │       ├── dialog.svelte
│       │       ├── separator.svelte
│       │       ├── tooltip.svelte
│       │       ├── badge.svelte
│       │       └── ThemeToggle.svelte    (extracted from +layout during audit)
│       ├── stores/
│       │   ├── ui.svelte.ts              runes-based global UI store
│       │   └── theme-persistence.ts      (extracted from +layout during audit)
│       ├── utils/
│       │   └── keyboard.ts               (extracted from +layout during audit)
│       ├── api/
│       │   ├── client.ts                 stub pointing to :9190
│       │   └── realtime.ts               stub for SSE invalidation
│       ├── tauri/index.ts                isTauri() + plugin re-exports
│       └── utils.ts                      cn() (shadcn-svelte helper)
└── tests/
    ├── unit/utils.test.ts
    └── e2e/shell.spec.ts
```

**Verification:** `pnpm check` + `pnpm lint` + `pnpm test` (4/4) +
`pnpm build` all green.

### Rust sidecar

```
src-tauri/
├── Cargo.toml                     portable-pty, keyring, notify, reqwest,
│                                  tokio, serde, thiserror, tauri-*
├── tauri.conf.json                window 1280×800, CSP tightened to :9190 + ipc,
│                                  minimal bundle
├── capabilities/default.json      deny-by-default: no shell:default, no process
└── src/
    ├── main.rs                    5-line bootstrap
    ├── lib.rs                     builder + plugin registration + commands
    ├── error.rs                   CanopyError (#[allow(dead_code)] — stubs)
    └── commands/
        ├── mod.rs
        ├── pty.rs                 stubs (Week 1 — portable-pty wired later)
        ├── runtimes.rs            stub
        ├── vault.rs               stub (Keychain via keyring)
        └── filesystem.rs          stub
```

**Verification:** `cargo check` + `cargo clippy -- -D warnings` +
`cargo fmt --check` all green.

### Docs — 7 canonical documents

```
docs/
├── README.md             index (updated to cover all 7)
├── 01-foundation.md      platform architecture, stack, build order
├── 02-frontend-design.md design system, 12 screens, components, flows
├── 03-steal-synthesis.md every lift decision per competitor
├── 04-platform-breakdown.md full feature inventory with provenance
├── 05-operations.md      runbook (setup, dev, troubleshooting, ports, secrets)
├── 06-audit.md           hardening checklist (reusable for future gates)
└── 07-day1-report.md     this file
```

---

## 3. Exit Criteria — Evidence Table

| Check | Result |
|-------|--------|
| `make doctor` | ✅ elixir 1.19.5, erlang 28, nodejs 24.14.1, rust 1.94.1, pnpm 9.15.0 |
| `mix compile --warnings-as-errors` | ✅ 0 warnings, 26 files compiled |
| `mix test` | ✅ 4 tests, 0 failures |
| `mix format --check-formatted` | ✅ clean |
| `mix credo --strict` | ✅ 96 mods/funs, no issues |
| `GET /api/v1/health` | ✅ `{"status":"ok","version":"0.1.0"}` |
| `GET /api/v1/openapi` | ✅ 200, valid OpenAPI 3.1 |
| `pnpm check` (svelte-check) | ✅ 757 files, 0 errors, 0 warnings |
| `pnpm lint` (Biome) | ✅ 23 files, no fixes applied |
| `pnpm test` (Vitest) | ✅ 2 files, 4 tests passed |
| `pnpm build` (SvelteKit static) | ✅ built with SPA fallback |
| `cargo check` | ✅ clean |
| `cargo clippy -- -D warnings` | ✅ clean (dead_code allowed on stub enum variants) |
| `cargo fmt --check` | ✅ clean |
| `pnpm -r ls` | ✅ resolves @canopyai/root + desktop + @canopyai/types |

### Architecture audit

| Rule | Status |
|------|--------|
| Elixir files ≤ 150 LOC | ✅ max is adapter.ex at 126 |
| Svelte files ≤ 150 LOC | ✅ +layout.svelte refactored 254→139 |
| TS files ≤ 200 LOC | ✅ all clear |
| Rust files ≤ 100 LOC (lib.rs up to 150) | ✅ all clear |
| No `.unwrap()` outside main.rs | ✅ clean |
| No `panic!` outside main.rs | ✅ clean |
| No `: any` in TS | ✅ clean |
| No legacy Svelte `writable()` stores | ✅ clean (runes only) |
| Domain → web boundary | ✅ (Application.ex exception documented — standard Phoenix pattern) |
| Supervisor tree order | ✅ 9 children correct |
| Config 4-tier complete | ✅ config + dev + test + runtime |
| `@moduledoc` on every module | ✅ |

### Hardening

| Check | Status |
|-------|--------|
| No secrets committed | ✅ grep clean |
| Tauri capabilities minimal | ✅ removed `shell:default` + `process:default`; `shell:allow-open` only |
| CSP correct port | ✅ fixed :4000 → :9190, tightened script-src (removed 'unsafe-inline') |
| CSP includes ipc + asset protocols | ✅ |
| Backend CORS plug installed | ✅ Corsica in :api pipeline, origins from config |
| TLS defaults preserved | ✅ no `verify: :verify_none` |
| DB connection SSL-ready | ✅ DATABASE_URL-driven via runtime.exs |
| Secret key env-driven in prod | ✅ crashes loudly if missing |

### Cross-doc consistency

| Claim | Status |
|-------|--------|
| Elixir version (1.19.5) across docs + .tool-versions + mix.exs | ✅ unified (mix.exs bumped from `~> 1.17` to `~> 1.19`) |
| Node version (24.14.1) | ✅ |
| PostgreSQL version | ✅ unified to "14+" across 01-foundation, 04-breakdown, 06-audit; pg15 running locally |
| Tauri version (2.6) | ✅ |
| Module count (19 total = 14 product + 5 system) | ✅ |
| No-human-adapter rule | ✅ no `(actor_type, actor_id)` polymorphism present |

---

## 4. Issues Found + Resolutions (in-band fixes)

| # | Issue | Category | Resolution |
|---|-------|----------|------------|
| 1 | `svelte.config.js` used double quotes, Biome wants single | Trivial (formatter) | Wrote with single quotes; `lint:fix` applied |
| 2 | `CanopyError` enum variants flagged dead_code by clippy | Trivial (lint rule) | Added `#[allow(dead_code)]` with reason comment |
| 3 | `+layout.svelte` was 254 LOC (violates ≤150 rule) | **Structural** | Refactored: extracted `theme-persistence.ts`, `keyboard.ts`, `ThemeToggle.svelte`. Result: 139 LOC |
| 4 | Biome flagged `handleGlobalShortcut` + `ThemeToggle` as unused in +layout | Trivial (Biome limitation — doesn't parse Svelte templates) | Added `noUnusedImports: off` to .svelte override in biome.json |
| 5 | CSP in `tauri.conf.json` referenced port 4000 (Phoenix default) but backend runs on 9190 | **Hardening** | Fixed CSP to :9190 + added `ipc:` and `asset:` protocols |
| 6 | CSP allowed `script-src 'unsafe-inline'` | **Hardening** | Removed (SvelteKit production build doesn't need inline scripts) |
| 7 | Tauri capabilities included `shell:default` + `process:default` (unused and overly permissive) | **Hardening** | Dropped both; kept `shell:allow-open` only |
| 8 | No CORS plug in backend | **Hardening** | Added Corsica with env-configurable origins |
| 9 | `04-platform-breakdown.md` still said "PostgreSQL 17" | Consistency | Patched to "PostgreSQL 14+" |
| 10 | `03-steal-synthesis.md` said "14 modules" but README said "19" | Consistency | Clarified: 14 product + 5 system = 19 total |
| 11 | `mix.exs` required `elixir: "~> 1.17"` but we document 1.19.5 | Consistency | Bumped to `~> 1.19` |
| 12 | Orphan `CanopyOS/src-tauri/` (pre-rename leftover) | Hygiene | Moved to `canopy-legacy/src-tauri-root/` |
| 13 | `CANOPY-V2-DAY1-AUDIT.md` at repo root (not in docs/) | Hygiene | Moved to `canopy/docs/06-audit.md` |
| 14 | Stale `.git/index.lock` (6 days old) blocked git ops | Environmental | Verified empty + no git process, removed |

**Zero catastrophic issues. All fixes were trivial or structural, resolved in-band.**

---

## 5. Deferred (with target)

| Deferral | Why | Target |
|----------|-----|--------|
| API rate limiting (Hammer plug) | Desktop-only access for now; near-zero attack surface. Correct solution scales with external API exposure. | Week 1 when routes become real |
| `mix canopy.gen.openapi` task | Needs real schemas first | Week 1 after 3 runtime adapters have schemas |
| `packages/types/` TS generation wire-up | Same — waiting on OpenAPI | Week 1 |
| `oban_web` dev dashboard | Pulls LiveView + Phoenix HTML, would add compile warnings in `--no-html` project | Week 1 behind `dev_routes` guard |
| `packages/protocol/` directory | Will hold ported markdown specs from canopy-legacy | Week 0 porting (next) |
| Release CI workflow (DMG + notarize) | Not needed until shipping | Week 6 |
| Font files (Geist, EB Garamond, JetBrains Mono) | Tokens use system fallbacks for now | Week 4 when design polish kicks in |
| Playwright E2E against real Tauri | Not gated in CI (needs display) | Week 6 |

---

## 6. Assumptions Made

| # | Assumption | Rationale | Override |
|---|------------|-----------|----------|
| 1 | `PGUSER=rhl` (not `postgres`) as local default | Agent detected local PG uses system user; convention varies | Set `PGUSER=postgres` in shell |
| 2 | PostgreSQL 14+ required (pg15 running locally) | Homebrew pg15 is the running instance; pgvector built from source | Upgrade to pg17+ → Homebrew pgvector formula works directly |
| 3 | pnpm 9.15.0 via Corepack packageManager field | Matches what scaffold + lockfile were tested with; 10.x has breaking changes | Bump `packageManager` to 10.x when ready to retest |
| 4 | Apache 2.0 license | Sensible default for open-source platform; Roberto can change | Change `LICENSE` file |
| 5 | App identifier `ai.canopy.desktop` | Needs to be stable before first signed build | Change if branding moves |
| 6 | concurrently in devDeps but unused | Makefile uses `&` not JS orchestration; kept as optional alt | Remove if you want cleaner deps |

---

## 7. Session Artifact Audit

```
CanopyOS/
├── canopy/              ✅ new monorepo
├── canopy-legacy/       ✅ old canopy/ renamed here
│   └── src-tauri-root/  ✅ orphan consolidated here
└── docs/                (CanopyOS-level, unrelated to Canopy v2)
```

Root no longer contains:
- `CANOPY-V2-*.md` master docs (moved into `canopy/docs/01-04-*.md`)
- `CANOPY-V2-DAY1-AUDIT.md` (moved to `canopy/docs/06-audit.md`)
- stale `src-tauri/` orphan (moved to `canopy-legacy/`)

---

## 8. Handoff to Week 1

**First action:** port canopy-legacy markdown protocol specs into
`canopy/packages/protocol/` (per manifest-driven selection from
`/tmp/competitor-research/analysis/canopy-legacy-port-manifest.md`).

**Week 1 work starts on:** `backend/lib/canopy/runtimes/adapter.ex` —
fleshing out the three lead adapters:
1. `Canopy.Runtimes.ClaudeLocal` (stream-json subprocess pattern)
2. `Canopy.Runtimes.CodexLocal`
3. `Canopy.Runtimes.GeminiLocal`

With real Ecto schemas (`sessions`, `session_messages`, `runtime_models`),
contract tests in `test/canopy/runtimes/`, and OpenAPI schemas for the
corresponding controllers.

**Exit criterion for Week 1:** `POST /api/v1/sessions { runtime: "claude-local",
prompt: "..." }` spawns a Claude subprocess, streams `TranscriptEntry` SSE
events, persists session + messages, returns cost. Contract tests for all 3
adapters pass.

**Gate procedure before Week 1 starts:** this report (`07-day1-report.md`) +
audit procedure (`06-audit.md`) sufficient. No further pre-flight needed.

---

## 9. Stats

- **Total files created:** 106 (per agent reports + my hardening edits)
- **Lines of code:** ~2,400 (excluding deps, lock files, generated)
- **Max file size:** 126 LOC (adapter.ex behaviour) — within ≤150 rule
- **Tests:** backend 4/4, desktop 4/4, rust 0 failures
- **Time elapsed:** scaffold 15+30+20 min parallel → 30 min wall clock; audit + fixes 25 min; docs 15 min → **~70 min wall clock for Day 1**
- **Issues fixed in-band:** 14 (0 deferred as unresolved)
- **Agents dispatched this session:** 7 (5 competitor analyses + 1 port inventory + 3 scaffolds parallel)

---

**Day 1: Signed off. Week 1: Go.**
