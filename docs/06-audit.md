> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Canopy v2 — Day 1 Hardening + Audit Checklist

**Date:** 2026-04-17
**Purpose:** Quality gate between scaffold completion and Week 1 kickoff. Nothing advances until every item here is green.
**Authority:** Principal-architect-grade; the spec is not "it compiles," it's "it ships."

---

## 0. Audit Method

1. **Automated first** — run the command, capture the output. Numbers don't lie.
2. **Structural second** — inspect file sizes, module boundaries, import graphs.
3. **Semantic third** — read key files, confirm intent matches FOUNDATION.md.
4. **Cross-doc consistency** — no contradictions between the 5 master docs.
5. **Fix in-band** — if something's off, fix it now (not "in Week 1"). Day 1 must be clean.

---

## 1. Automated Checks

### Backend (`canopy/backend/`)

| Check | Command | Pass criteria |
|-------|---------|---------------|
| Compile clean | `mix compile --warnings-as-errors --force` | 0 warnings, 0 errors |
| Tests | `mix test` | 0 failures, ≥ 2 tests (health + adapter list) |
| Format | `mix format --check-formatted` | No diffs |
| Credo strict | `mix credo --strict` | No issues (or documented suppressions) |
| Dialyzer | `mix dialyzer` | Clean or known-empty first-run |
| Routes | `mix phx.routes` | `/api/v1/health`, `/api/v1/openapi` both listed |
| Server boots | `mix phx.server` (15s then kill) | Binds to :9190, no crash logs |
| DB migration | `mix ecto.create && mix ecto.migrate` | pgvector extension created |
| Health endpoint | `curl http://localhost:9190/api/v1/health` | 200 JSON `{"status":"ok","version":"0.1.0"}` |
| OpenAPI endpoint | `curl http://localhost:9190/api/v1/openapi` | Valid OpenAPI 3.1 JSON |

### Desktop (`canopy/desktop/`)

| Check | Command | Pass criteria |
|-------|---------|---------------|
| Install clean | `pnpm install --frozen-lockfile=false` | Exit 0, lockfile present |
| Type check | `pnpm check` | 0 errors, 0 warnings |
| Lint | `pnpm lint` (Biome) | 0 errors |
| Unit tests | `pnpm test` (Vitest) | ≥ 1 test, 0 failures |
| E2E gate | `pnpm test:e2e` (Playwright, or skipped with gate var) | Skipped OK w/ CI_ALLOW_E2E=0 |
| Build | `pnpm build` | `build/` dir created, index.html present |
| No `any` | `grep -rn ": any" src/ \| wc -l` | 0 |
| No legacy stores | `grep -rn "writable(" src/ \| grep -v tanstack` | 0 (we use runes + TanStack) |

### Rust sidecar (`canopy/src-tauri/`)

| Check | Command | Pass criteria |
|-------|---------|---------------|
| Cargo check | `cargo check --manifest-path src-tauri/Cargo.toml` | Exit 0, no warnings |
| Cargo test | `cargo test --manifest-path src-tauri/Cargo.toml` | 0 failures |
| Cargo fmt | `cargo fmt --manifest-path src-tauri/Cargo.toml --check` | No diffs |
| Cargo clippy | `cargo clippy --manifest-path src-tauri/Cargo.toml -- -D warnings` | 0 warnings |
| No `.unwrap()` outside main | `grep -rn "unwrap()" src-tauri/src/ \| grep -v main.rs` | 0 |
| No `panic!` outside main | `grep -rn "panic!" src-tauri/src/ \| grep -v main.rs` | 0 |

### Monorepo

| Check | Command | Pass criteria |
|-------|---------|---------------|
| `make doctor` | — | Reports all tool versions, matches .tool-versions |
| CI YAML valid | `yamllint .github/workflows/ci.yml` (or manual) | No syntax errors |
| Workspace resolution | `pnpm -r ls` | Resolves desktop + packages/types without errors |
| No stray root deps | `cat package.json \| jq '.dependencies'` | null or {} (devDeps only at root) |

---

## 2. Architecture Audit (Structural)

### No God Files Rule

| Scope | Limit | Check command |
|-------|-------|---------------|
| Elixir lib/**/*.ex | ≤ 150 LOC (behaviour modules exempt) | `find backend/lib -name "*.ex" -exec wc -l {} + \| awk '$1 > 150'` |
| Svelte components | ≤ 150 LOC | `find desktop/src -name "*.svelte" -exec wc -l {} + \| awk '$1 > 150'` |
| TypeScript files | ≤ 200 LOC | `find desktop/src -name "*.ts" -exec wc -l {} + \| awk '$1 > 200'` |
| Rust modules | ≤ 100 LOC (lib.rs up to 150) | `find src-tauri/src -name "*.rs" -exec wc -l {} + \| awk '$1 > 100'` |

Any violation = split the file. No exceptions.

### Module Boundary Integrity

- **Backend:** `lib/canopy/` must not import from `lib/canopy_web/`. Domain layer is pure.
  - `grep -rn "CanopyWeb\." backend/lib/canopy/` → must be empty
- **Backend:** Each domain module has one clear boundary file (e.g. `canopy/runtimes.ex`) that external callers use. Sub-modules (`canopy/runtimes/registry.ex`) are internal.
- **Desktop:** `src/lib/domain/` does not import from `src/routes/` or `src/lib/design/patterns/`. Domain is pure business logic.
- **Desktop:** `src/lib/design/primitives/` does not import from `src/lib/domain/` or `src/lib/api/`. Primitives are layout-only.

### Supervisor Tree Correctness

Assert order in `Canopy.Application.start/2`:
1. `CanopyWeb.Telemetry`
2. `Canopy.Repo`
3. `DNSCluster`
4. `Phoenix.PubSub`
5. `Finch` (for Req)
6. `Oban`
7. `Registry` (Canopy.Runtimes.Registry)
8. `Canopy.Sessions.Supervisor` (DynamicSupervisor)
9. `CanopyWeb.Endpoint`

If order is wrong (e.g. Endpoint before Repo), the app may start then immediately fail a DB call. Fix.

### Config Completeness

| File | Must contain |
|------|--------------|
| `config/config.exs` | App, ecto_repos, endpoint base, Oban queues + plugins |
| `config/dev.exs` | Repo dev DB, endpoint port 9190, debug_errors |
| `config/test.exs` | Repo test DB + sandbox pool, logger warn only |
| `config/runtime.exs` | DATABASE_URL, SECRET_KEY_BASE, MIOSA_API_URL, MIOSA_API_KEY (required in prod) |

Any missing → add.

### Error Handling

- Backend: every public function has `@spec`. No bare `try/rescue` without specific exceptions.
- Frontend: every async call goes through TanStack Query or a `Result<T, E>` helper. No unhandled promises.
- Rust: all Tauri commands return `Result<T, CanopyError>`. No `unwrap`, no `expect`, no `panic!`.

### Documentation Minimum

- Backend: every public module has `@moduledoc` with 1-line summary + purpose paragraph.
- Desktop: every component file has a leading JSDoc block (3-line minimum) describing purpose + props.
- Rust: every public fn has `///` doc comment.
- Each domain module has a `NOTES.md` slot (even if empty) for pattern decisions.

---

## 3. Hardening Checks (Security / Reliability)

| Check | Verification |
|-------|--------------|
| No secrets in repo | `grep -rEn "(sk-\|api[_-]?key\|secret)" backend/ desktop/ src-tauri/ --include="*.ex" --include="*.ts" --include="*.rs" --include="*.json"` ← visually review matches |
| No hardcoded ports (backend) | Endpoint config reads from runtime.exs / dev.exs; not inline |
| No hardcoded URLs in frontend | `api/client.ts` reads from env var or Tauri command, not baked in |
| Tauri capabilities minimal | `src-tauri/capabilities/default.json` allows only needed commands; no blanket `*` permissions |
| CSP configured | `tauri.conf.json` `security.csp` is set, not null |
| CORS configured | `CanopyWeb.Endpoint` CORS plug present with allowlist, not wildcard |
| Guardian secret rotation ready | `config/runtime.exs` reads `SECRET_KEY_BASE` + Guardian secret separately |
| Bcrypt for passwords | If user schema present, password_hash field uses Bcrypt |
| Logger redacts in prod | `config/runtime.exs` logger config strips `password`, `token`, `secret` fields |
| HTTP client verifies TLS | `Req` default (verify_peer: true). No `verify: :verify_none` anywhere |
| DB connection SSL-ready | `config/runtime.exs` accepts `DATABASE_SSL=true` for prod |
| No `.env` committed | `.gitignore` lists `*.env`, `.envrc` |

---

## 4. Cross-Doc Consistency

Verify no contradictions across:
- `docs/01-foundation.md`
- `docs/02-frontend-design.md`
- `docs/03-steal-synthesis.md`
- `docs/04-platform-breakdown.md`
- `README.md`
- `NOTICE.md`

Check list:

| Claim | Must match in |
|-------|---------------|
| Elixir version (1.19.5) | foundation §4 + .tool-versions + README stack section |
| Node version (24.14) | foundation §4 + .tool-versions + README |
| PostgreSQL (14+) | foundation §4 (already patched) + config/runtime.exs minimum |
| Tauri version (2.6) | foundation §4 + Cargo.toml + package.json |
| 9 CLI runtimes list | foundation §5 + breakdown §5.2 + adapter behaviour docstring |
| OKLCh token values | frontend-design §1 + desktop/src/lib/design/tokens/oklch.css (must match exactly) |
| Module count (19) | breakdown §9 summary + frontend-design §6 screen count + sidebar structure in +layout.svelte |
| Runtime adapter interface | foundation §4 code block + backend/lib/canopy/runtimes/adapter.ex |
| No-human-adapter rule | breakdown §3.2 + no `(actor_type, actor_id)` polymorphism in schemas |

Any mismatch → fix doc OR fix code, whichever represents truth.

---

## 5. Integration Checks

| Check | How |
|-------|-----|
| Backend port = `tauri.conf.json` `devUrl` base | Both read port from same source OR both hardcoded to 9190 for dev |
| Desktop dev port = `tauri.conf.json` `devUrl` | SvelteKit default 5280 matches devUrl |
| Makefile `dev` starts all three | `make dev` → phoenix :9190, vite :5280, tauri, in parallel w/ proper cleanup |
| CI references correct paths | `ci.yml` jobs reference `backend/`, `desktop/`, `src-tauri/` — verify |
| `packages/types/` empty now, ready for generated OpenAPI types | Day 1: placeholder. Week 2+: wire via `mix canopy.gen.openapi` |
| `.tool-versions` matches installed | asdf users don't get surprises |
| Pnpm workspace resolves | `pnpm -r ls` shows `@canopyai/desktop` + `@canopyai/types` |

---

## 6. Day 1 Completion Report (filled after audit)

Fill in after all three agents return:

### Automated checks
- [ ] Backend: `mix compile && mix test && mix format --check-formatted && mix credo --strict`: **PASS / FAIL**
- [ ] Desktop: `pnpm install && pnpm check && pnpm lint && pnpm test && pnpm build`: **PASS / FAIL**
- [ ] Rust: `cargo check && cargo test && cargo fmt --check && cargo clippy -- -D warnings`: **PASS / FAIL**
- [ ] Monorepo: `make doctor`: **PASS / FAIL**

### Architecture
- [ ] No god files (sizes within limits): **YES / NO**
- [ ] Module boundaries clean: **YES / NO**
- [ ] Supervisor tree order correct: **YES / NO**
- [ ] Config 4-tier complete: **YES / NO**
- [ ] Error handling consistent: **YES / NO**

### Hardening
- [ ] No secrets: **YES / NO**
- [ ] Tauri capabilities minimal: **YES / NO**
- [ ] CSP + CORS configured: **YES / NO**
- [ ] TLS defaults preserved: **YES / NO**
- [ ] Secret-key env-driven: **YES / NO**

### Cross-doc consistency
- [ ] All 10 claims match: **YES / NO**
- [ ] Mismatches resolved: **YES / NO**

### Integration
- [ ] Ports align: **YES / NO**
- [ ] `make dev` boots all three: **YES / NO**
- [ ] CI references correct: **YES / NO**
- [ ] `pnpm -r ls` resolves: **YES / NO**

### Found issues + resolutions
_(list anything caught during audit + what was done about it)_

### Ready for Week 1?
**YES / NO** + one-line justification.

---

## 7. Hardening Tasks I Run Post-Scaffold (in-band fixes)

Things I do MYSELF after agents return, before declaring Day 1 done:

1. **Tighten Tauri capabilities** — review `src-tauri/capabilities/default.json`. Remove anything the agent over-granted. Start with absolute minimum (plugin: store + opener + shell + notification). Add more only when a Week-1 command proves it needs more.

2. **Write initial CSP** — `tauri.conf.json` `security.csp`:
   ```
   default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self' http://localhost:9190 ws://localhost:9190
   ```
   Tightened per-environment later.

3. **Add a Phoenix CORS plug** — `CanopyWeb.Router` pipeline for `/api/v1` only, allow origin `tauri://localhost` + `http://localhost:5280` in dev.

4. **Rate limit the API** — `:hammer` or equivalent on `/api/v1/*` with a sane default (100 req/min per IP). Even though it's a desktop app, defense-in-depth.

5. **Add `mix canopy.gen.secret`** task — generates SECRET_KEY_BASE for local dev to avoid hardcoded ones.

6. **Write `canopy/docs/05-operations.md`** — runbook for: first-time setup, DB reset, log locations, troubleshooting, how to regenerate types after OpenAPI changes.

7. **Git hygiene** — ensure `canopy-legacy/` is still tracked in git (it's just renamed), create a commit scope plan: this session's work will land as one clean commit `feat: canopy v2 Day 1 scaffold` once audit passes.

8. **Commit the session work** — once audit is green, prompt Roberto for permission to commit (destructive-ish = hard to reverse). Staged as one commit of the Canopy v2 Day 1 scaffold + docs rearrangement; DOES NOT include the unrelated OptimalOS-level changes (signals/nodes stuff).

9. **Update `CANOPY-V2-FOUNDATION.md` §6** — annotate Week 0 as COMPLETE with date + commit hash.

10. **Write `DAY1-COMPLETION-REPORT.md`** — 1-page summary of what shipped, any assumptions, any deferred items, go/no-go for Week 1.

---

## 8. Anti-Slip Guarantees

Per "no slips" directive:

1. **Every command's output captured** — no "it worked on my machine." Audit log saved.
2. **Every file-size limit verified with grep** — no trust, show numbers.
3. **Every cross-doc claim verified by diff** — consistency is mechanical.
4. **Every security default hardened before Day 1 closes** — no "we'll fix that later."
5. **Every unused dependency removed** — no bloat creeping in.
6. **Every TODO flagged** — if we deferred something, it's written down with a specific Week it lands.
7. **Every hardening pass I do is documented** — so next session knows what's already tight.

---

## 9. If Any Agent Returns With Something Broken

Decision tree:

- **Trivial (typo, wrong flag)** → I fix in-place, no re-dispatch.
- **Wrong pattern (e.g. used Zustand, wrong lib version)** → I fix. Document lesson in `canopy-legacy/../tasks/lessons.md` via OSA protocol.
- **Structural (agent misread spec)** → re-dispatch that ONE agent with clarified prompt + delta. Do NOT wipe their output.
- **Catastrophic (broke canopy-legacy or created chaos)** → stop, assess, surface to Roberto before any more work.

I report what category the issue fell into, not just "I fixed it."
