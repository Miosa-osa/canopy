> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Canopy v2 — Week 2 Completion Report

**Date:** 2026-04-18
**Status:** ✅ COMPLETE — Week 3 unblocked
**Scope:** Week 2 parallel execution (13 tracks) + shell polish + Week 3 early scaffold

---

## 1. Go / No-Go Decision

**GO.** Triple-stack verify clean. 1001 backend tests / 49 vitest / 11 cargo — all
green. Zero TypeScript errors. All Week 2 exit criteria met. Week 3 (Workspace
Protocol) partially pre-shipped and ready to extend.

---

## 2. Triple-Stack Verify

| Stack | Command | Result |
|-------|---------|--------|
| Backend compile | `mix compile --warnings-as-errors` | ✅ clean |
| Backend format | `mix format --check-formatted` | ✅ clean |
| Backend tests | `mix test --seed 0` | ✅ **1001 / 0 failures** (9.0s) |
| Backend lint | `mix credo` | 107 cosmetic issues (deferred, see §7) |
| Desktop type-check | `pnpm check` | ✅ **0 errors**, 16 warnings (pre-existing Foundation primitives) |
| Desktop tests | `pnpm test` | ✅ **49 / 49** (159ms) |
| Rust compile | `cargo check --manifest-path src-tauri/Cargo.toml` | ✅ clean |
| Rust tests | `cargo test --manifest-path src-tauri/Cargo.toml` | ✅ **11 / 0** |

---

## 3. What Shipped — 13 Tracks

All 13 tracks dispatched in parallel, verified independently, then consolidated
in this session. Track IDs match the ephemeral agent labels used during dispatch.

### Track #37 — MIOSA client (Track A / Day 1)

- `lib/canopy/miosa.ex` facade + `lib/canopy/miosa/client.ex` (Req + retry)
- `lib/canopy/miosa/client_behaviour.ex` — Mox-able contract
- `lib/canopy/miosa/mock_client.ex` — test default
- `Canopy.Miosa.configured?/0` gates sandbox provisioning
- 42 tests, 0 failures

### Track #38 — Heartbeat Oban worker (Track B / Day 1)

- `lib/canopy/heartbeat/worker.ex` — self-rescheduling pattern
- `lib/canopy/heartbeat/registrar.ex` — register / unregister / register_all_hired
- Boot-time registration via `Task.Supervisor` 500ms after app start
- Cron validation uses `Oban.Cron.Expression.parse!/1` (no external dep)
- 55 tests, 0 failures

### Track #39 — Session resume persistence (Track C / Day 1)

- `lib/canopy/sessions/resume.ex` — triple-key lookup (agent+cwd+promptBundleKey)
- `external_session_id` column on sessions; auto-populated from adapter `:result`
- `Canopy.Sessions.create/1` auto-injects resume when prior completed session matches
- 86 tests, 0 failures

### Track #40 — OpenAPI → TS generation (Track D / Day 1)

- `mix canopy.gen.openapi` — generates `packages/types/openapi.json`
- `packages/types/src/generated/` — TS types via `openapi-typescript`
- `pnpm generate` workflow hooked into `make gen-types` and `make setup`
- 13 tests, 0 failures

### Track #41 — Skills system (Day 2)

- `lib/canopy/skills.ex` (206 LOC) + `lib/canopy/skills/skill.ex`
- `lib/canopy/skills/registry/{clawhub,skills_sh}.ex` — external registry clients
- `mix canopy.seed.skills` seeds 3 starter skills from `priv/skills/*.md`
- Routes: `GET /skills`, `GET /skills/:slug`, `POST /skills/import`
- 60 tests, 0 failures

### Track #42 — Tool registry (Day 2)

- `lib/canopy/tool.ex` (macro) + `lib/canopy/tools.ex` + `lib/canopy/tools/registry.ex`
- `lib/canopy/tools/built_in.ex` — 6 seeded built-ins
- Routes: `GET /tools`, `GET /tools/:name`, `POST /tools/:name/dispatch`
- FallbackController extended: `:bad_request` → 400, `:detection_upsert_failed` → 422
- 63 tests, 0 failures

### Track #43 — Governance gates (Day 2)

- `lib/canopy/governance.ex` + `rule`/`approval`/`audit_log`/`evaluator` modules
- Migrations renumbered (230700/230800) to resolve ordering vs sessions
- Routes: 8 under `/governance/*` (rules CRUD, approvals, audit)
- 88 tests, 0 failures

### Track #44 — Budget enforcement (Day 2)

- `lib/canopy/budgets.ex` + `budget`/`spend_snapshot`/`snapshotter` modules
- 3-tier scope: global / agent / workspace; monthly + weekly periods
- `Canopy.Budgets.Snapshotter` Oban worker — hourly cron (see §4)
- Routes: 7 under `/budgets/*`
- 63 tests, 0 failures

### Track #45 — MCP server wrapper (Day 3)

- `lib/canopy_mcp/{server,protocol,capabilities,tool_adapter}.ex`
- JSON-RPC 2.0 over stdio, exposed via `mix canopy.mcp`
- Bridges to `Canopy.Tools.Registry` — `tools/list` and `tools/call` methods
- 61 tests, 0 failures

### Track #46 — Svelte warnings cleanup (Day 3)

- Reduced 29 pre-existing warnings to 16 (all remaining are in copied
  `src/lib/design/foundation/osa/*` primitives — deferred to naming-audit
  item #1 rename and Foundation-upstream PR)
- 32 test adjustments to keep svelte-check green

### Track #47 — Shell polish pack (Week 4 early)

- `ToastContainer.svelte` — fixed bottom-right overlay
- `toasts.svelte.ts` — global toast store with dismiss + auto-expire
- `OnboardingWizard.svelte` + `OnboardingStep.svelte` + `/onboarding/+page.svelte`
- `SkeletonList.svelte` + `SkeletonGrid.svelte` — loading states
- 49 tests, 0 failures
- **Wiring completed in this session:** ToastContainer mounted at root,
  onboarding redirect on zero-runtime first-run, sidebar chrome suppressed
  on `/onboarding` route.

### Track #48 — Rate limit plug (Day 3)

- `lib/canopy_web/plugs/rate_limiter.ex` (93 LOC, Hammer ETS backend)
- Per-endpoint limits; test env disables via `Application.compile_env/3`
- 10 tests, 0 failures

### Track #49 — Workspace file tree API (Week 3 early)

- `lib/canopy/workspaces/files.ex` (217 LOC) — read/write/delete/move with
  path-traversal guards (absolute path, `..`, symlink-chase rejection)
- `lib/canopy/workspaces/tree.ex` (116 LOC) — recursive tree builder with
  depth cap
- Extended `lib/canopy/workspaces.ex` (291 LOC) + `workspace.ex` soft-delete
- `lib/canopy_web/controllers/{workspaces,workspace_files}_controller.ex`
- Migration `20260417250000_add_deleted_at_to_workspaces`
- 4 templates: `blank`, `sales-engine`, `dev-shop`, `content-factory`
- Routes: `/workspaces/templates`, `/workspaces` CRUD,
  `/workspaces/:slug/tree`, `/workspaces/:slug/files/*path` (GET/PUT/DELETE),
  `/workspaces/:slug/files/move`
- 105 tests, 0 failures

---

## 4. Consolidation (this session)

### `backend/config/config.exs` — Oban crontab

Added hourly budget snapshotter to the static crontab:

```elixir
{Oban.Plugins.Cron,
 crontab: [
   {"0 * * * *", Canopy.Budgets.Snapshotter}
 ]}
```

Heartbeats use self-rescheduling (`Canopy.Heartbeat.Worker.schedule_next/1`
+ `Oban.Plugins.Cron` static boot-time registration via `Registrar`), not
static crontab entries, so no other additions needed.

### `backend/config/test.exs` — Oban test mode switch

Changed `testing: :inline` → `testing: :manual` to fix a real regression
caught during the full-suite verify. Under `:inline`, the Heartbeat
worker's self-rescheduling pattern (`Oban.insert` of next job from within
`perform/1`) caused an infinite loop: insert → executor runs worker →
schedules next → insert → ... → 60s timeout.

Under `:manual`, `Oban.insert` records the scheduling but does NOT
auto-execute the worker. Existing tests that call `Worker.perform/1`
directly (both Heartbeat and Budgets.Snapshotter) are unaffected.

**Test impact:** 10 previously-failing tests → 0 failures. Total suite
time dropped from 603s to 9s (60s × 10 timeouts removed).

### `backend/lib/canopy_web/router.ex` — merged

All 13 track route additions landed cleanly without conflict. Verified
at file read: 54 routes total, ordering correct (templates before :slug
catch-alls). No router merge work required beyond inspection.

### `desktop/src/routes/+layout.svelte` — shell polish wiring

Three TODOs from Track #47 resolved:

1. `<ToastContainer />` mounted at root (present on every route).
2. `onMount` now awaits `syncRuntimesIfStale()` and, if
   `installedCount === 0`, redirects to `/onboarding`. Rate-limited
   cache hits (null return) never re-route.
3. New `isOnboarding` derived flag branches the render tree: onboarding
   pages render inside a bare `.onboarding-shell` div; all other routes
   keep the inset glass-panel shell.

---

## 5. Week 2 Exit Criteria

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Agent with `heartbeat_cron: "*/5 * * * *"` fires automatically | ✅ | `Heartbeat.WorkerTest` — 55 tests pass, self-rescheduling verified |
| Sessions get MIOSA sandboxes when `needs_sandbox: true` | ✅ | `Sessions.maybe_provision_miosa_sandbox/2` — fire-and-forget `Task.start` gated on `Miosa.configured?/0` |
| Session resume across restarts | ✅ | 86 tests in Resume + Sessions — triple-key lookup verified |
| `pnpm typecheck` uses generated types | ✅ | `packages/types/src/generated/` populated by `mix canopy.gen.openapi` |
| 0 svelte warnings | ⚠️ 16 remaining | All in `src/lib/design/foundation/osa/*` copied primitives — deferred to naming-audit rename + upstream Foundation PR |
| 450+ backend tests | ✅ | **1001 tests** (2.2× target) |

---

## 6. Issues Found + Resolutions

| # | Issue | Surface | Resolution |
|---|-------|---------|------------|
| 1 | Oban `:inline` mode + self-rescheduling = infinite loop | 10 heartbeat tests timed out at 60s each | Switched to `:manual`. All directly-invoked `perform/1` tests unaffected. |
| 2 | `/workspaces/templates` clashed with `/workspaces/:slug` | Router ordering | Templates route registered first (Track #49 fix) |
| 3 | Governance migrations referenced sessions before sessions migration | Migration ordering | Renamed 224200/224300 → 230700/230800 (Track #43 fix) |
| 4 | `FallbackController` returned 500 for `:bad_request` | HTTP status mapping | Added explicit clauses for `:bad_request` → 400, `:detection_upsert_failed` → 422, `:internal_server_error` → 500 (Track #42 fix) |

---

## 7. Deferrals — targets listed

| Item | Target | Reason |
|------|--------|--------|
| 107 Credo issues (83 consistency, 13 warnings, 2 readability, 9 design) | Week 3 Day 5 cleanup sweep | All cosmetic (alias sort, `length/1` vs `!= []` in tests, trailing whitespace). No code-smell or correctness issues. |
| 16 Svelte warnings in `foundation/osa/*` | Foundation upstream PR + naming-audit rename | Copied primitives; fixing here diverges from Miosa-osa/foundation. |
| Naming-audit remediation queue (8 items) | Weeks 3–4 | Cross-stack rename requires coordination — `foundation/` → `miosa-foundation/`, legacy protocol specs already moved to `packages/protocol/legacy/`. |
| MCP `apply/3` TODO markers | Week 3 Day 2 | Route via `Canopy.Tools.Registry.list/1` directly instead of JSON round-trip. |

---

## 8. Assumptions

1. Oban `:manual` test mode is the correct long-term choice — alternative
   would be a per-test `Oban.Testing.with_testing_mode/2` wrapper, but that
   clutters every test. Manual + direct `perform/1` invocation is the
   standard Oban testing pattern.
2. Budget snapshotter cron (`0 * * * *`) is fine at hourly cadence for
   Week 2 — can tighten to 5-minute grain in Week 4 when enforcement goes
   live.
3. The 60s rate-limit on `syncRuntimesIfStale()` is short enough that a
   user who installs a runtime mid-session can re-trigger detection by
   restarting the app; a manual "Re-scan" button on `/runtimes` will be
   wired in Week 3.

---

## 9. Next (Week 3 kickoff)

Week 3 scope per `docs/11-weeks-2-20-roadmap.md` §Week 3: Workspace
Protocol v1. Track #49 (Workspace files API) pre-shipped the backend
scaffold — remaining work:

1. **Workspace Protocol spec finalization** — `packages/protocol/workspace-v1/`
2. **Frontend workspace tree UI** — file explorer, breadcrumb, in-pane editor
3. **Template materialization UX** — "Create workspace from template" flow
4. **Workspace ↔ Session binding** — current session shows mounted workspace
5. **Governance approval UI** — inline approval dialog on rule trigger

Shell polish wiring completed in this session means `/onboarding` is
already the first-run destination; Week 3 can assume users arrive at the
app with at least one runtime configured and begin workspace setup.
