# Canopy v2 — Operations Runbook

**Audience:** Anyone setting up, running, or debugging Canopy locally or in CI.
**Scope:** Concrete commands. No architecture theory — that's `01-foundation.md`.

---

## 1. Port Map

| Service | Port | Protocol | Notes |
|---------|------|----------|-------|
| Phoenix backend | `9190` | HTTP + SSE | Configurable via `PORT` env var |
| SvelteKit dev server | `5280` | HTTP | Vite default |
| Tauri webview | N/A | `tauri://`, `ipc:` | Native protocols; see CSP in `src-tauri/tauri.conf.json` |
| PostgreSQL | `5432` | TCP | Local `postgresql@15` via Homebrew |

If any port is taken, stop: `pkill -f "mix phx.server"`, `pkill -f "vite"`, `brew services stop postgresql@15`.

---

## 2. First-Time Setup

```bash
# Clone (if fresh)
cd ~/Desktop/OptimalOS/CanopyOS
git status canopy/                         # verify clean

# Verify toolchain
cd canopy && make doctor                   # elixir 1.19.5, nodejs 24.14.1, rust 1.94.1, pnpm, erlang 28

# Install deps (one shot)
make setup                                 # runs `cd backend && mix deps.get` + `pnpm install` at root

# Initialize database
cd backend
mix ecto.create                            # creates canopy_dev
mix ecto.migrate                           # runs pgvector + oban migrations

# Smoke-test each stack independently
mix test                                   # backend: 4/4 should pass
cd ../desktop && pnpm test                 # desktop: 4/4 should pass
cd ../src-tauri && cargo test              # rust: passes

# Launch the app
cd .. && make dev                          # runs backend + desktop + tauri in parallel
```

Tauri should open a window showing "Canopy" in the sidebar wordmark.

---

## 3. Daily Development

### Starting / stopping

```bash
make dev                                   # start all three processes
# ⌃C to stop; make kills all child processes cleanly
```

### Running only one stack

```bash
# Backend only
cd backend && mix phx.server               # :9190

# Desktop only (browser mode, no Tauri)
cd desktop && pnpm dev                     # :5280

# Desktop in Tauri window
cd desktop && pnpm tauri:dev               # spawns backend via beforeDevCommand
```

### Tests

```bash
make test                                  # all three suites, must all pass
make test-watch                            # watches all three
```

### Lint / format

```bash
make lint                                  # biome check + mix format --check-formatted
make format                                # apply all formatters
```

### Build

```bash
make build                                 # production: mix release + pnpm build + cargo tauri build
```

---

## 4. Database Operations

### Reset local DB

```bash
cd backend
mix ecto.reset                             # drop + create + migrate + seed
```

### New migration

```bash
cd backend
mix ecto.gen.migration add_something_to_something_table
# edit priv/repo/migrations/TIMESTAMP_*.exs
mix ecto.migrate
```

### Rollback

```bash
mix ecto.rollback                          # single step
mix ecto.rollback --all                    # to clean
```

### Inspect

```bash
mix ecto.dump                              # schema dump to priv/repo/structure.sql
psql canopy_dev                            # direct connection
```

---

## 5. OpenAPI → TS Types

After any controller or schema change, regenerate frontend types:

```bash
cd backend
mix canopy.gen.openapi > ../packages/types/src/api.ts   # (Week 1 task — not yet wired)
cd ../desktop && pnpm install                           # picks up new types via workspace link
```

Until the `mix canopy.gen.openapi` task ships (Week 1), the OpenAPI spec is
available live at `http://localhost:9190/api/v1/openapi` and can be fed through
`openapi-typescript` manually.

---

## 6. Secrets & Credentials

### Local dev

- Postgres password: `System.get_env("PGPASSWORD") || ""` — empty for local socket
- Postgres user: `System.get_env("PGUSER") || "rhl"` — override in your shell if different

Nothing else is secret in dev. `SECRET_KEY_BASE` is baked into `config/dev.exs`
for convenience — NEVER reuse it in prod.

### Production

All required env vars (crash if missing):

```
DATABASE_URL=ecto://user:pass@host/db
SECRET_KEY_BASE=$(mix phx.gen.secret)
MIOSA_API_URL=https://miosa.example.com
MIOSA_API_KEY=...
PHX_HOST=canopy.yourdomain.com
```

Optional:

```
PORT=9190                                  # default
CANOPY_CORS_ORIGINS=https://app.example.com,tauri://localhost   # comma-separated
ECTO_IPV6=1                                # if your DB host requires IPv6
POOL_SIZE=10                               # connection pool
DNS_CLUSTER_QUERY=my-app.internal          # for multi-node
```

### Desktop vault

User credentials (API keys for runtime adapters) live in macOS Keychain via
`tauri-plugin-keyring`. Never in files. Vault access is gated by the Tauri
capability `store:default`.

---

## 7. Log Locations

| Source | Where | How to tail |
|--------|-------|-------------|
| Phoenix | stdout | `tail -f` output of `mix phx.server` |
| SvelteKit | stdout | Vite dev server output |
| Tauri (Rust) | stdout + `~/Library/Logs/ai.canopy.desktop/` | `tail -f` the log file |
| Ecto SQL | stdout when `show_sensitive_data_on_connection_error: true` | dev only |
| Oban jobs | `oban_jobs` table | `SELECT * FROM oban_jobs ORDER BY id DESC LIMIT 20;` |
| Production | stdout captured by your orchestrator | depends on deploy |

---

## 8. Common Errors & Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `could not connect to server` | Postgres not running | `brew services start postgresql@15` |
| `role "postgres" does not exist` | Local PG uses system user `rhl` | Set `PGUSER=rhl` or create `postgres` role |
| `extension "vector" is not available` | pgvector not installed for pg15 | `brew install pgvector` OR build from source (see §10) |
| `Port 9190 already in use` | Previous phoenix still running | `pkill -f "mix phx.server"` |
| `Port 5280 already in use` | Previous vite still running | `pkill -f "vite"` |
| `'unsafe-inline' CSP violation` | CSP blocking inline script | Tauri 2 should not need inline script — check `tauri.conf.json` |
| `CORS error in browser dev` | Origin not allowlisted | Add origin to `CANOPY_CORS_ORIGINS` env var |
| `git lock file exists` | Stale lock from crashed git process | `ls -la .git/index.lock` — if 0 bytes + old + no `ps aux \| grep git` process → `rm .git/index.lock` |
| `Biome lints unused imports in .svelte` | Biome doesn't parse Svelte templates | Already suppressed in `biome.json` override — pull latest config |

---

## 9. Clean Slate

Start over without reinstalling tools:

```bash
cd canopy
make clean                                 # wipes _build, node_modules, target, dist
rm -rf backend/priv/repo/migrations/*.exs  # only if you want to re-seed schema
cd backend && mix ecto.drop
make setup                                 # reinstall everything
```

---

## 10. Building pgvector from source (pg15)

Homebrew ships pgvector for pg17+ only. For pg15:

```bash
cd /tmp
git clone --branch v0.8.0 https://github.com/pgvector/pgvector
cd pgvector
export PG_CONFIG=$(brew --prefix postgresql@15)/bin/pg_config
make
make install
psql canopy_dev -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

Once pg17+ is the locally-running version, drop this step and use Homebrew.

---

## 11. CI Failure Decoding

Three jobs run on every PR (see `.github/workflows/ci.yml`):

| Job | Failure means |
|-----|---------------|
| `backend-test` | ExUnit failed, compile warnings, format drift, or credo flagged something |
| `desktop-test` | Vitest failed, svelte-check errors, or Biome found issues |
| `rust-test` | cargo test failed, clippy warned, or rustfmt found drift |

All three must be green to merge. If CI fails:

1. Reproduce locally with `make test` + `make lint`
2. Fix root cause (don't suppress warnings)
3. Push fix as a new commit (not amend)

---

## 12. Where to Look for Week N Changes

| Week | Adds | Major files touched |
|------|------|---------------------|
| 1 | Runtime adapters (3 of 9) | `backend/lib/canopy/runtimes/*` |
| 2 | MIOSA client, Sessions, Skills | `backend/lib/canopy/{miosa,sessions,skills}/*` |
| 3 | Realtime SSE, Governance, Budgets | `backend/lib/canopy_web/channels/*`, `governance/*` |
| 4 | Frontend shell, Runtime Dashboard | `desktop/src/lib/design/**`, `desktop/src/routes/runtimes/*` |
| 5 | Composer, Sessions UI, Workspaces | `desktop/src/routes/{sessions,workspaces,agents}/*` |
| 6 | Onboarding, command palette, ship | Everywhere; final polish |

See `docs/01-foundation.md` §6 for the full build-order spec.

---

## 13. Contact / Escalation

- Architecture questions → `docs/01-foundation.md`
- Design/UX questions → `docs/02-frontend-design.md`
- "Where did this pattern come from?" → `docs/03-steal-synthesis.md` + `NOTICE.md`
- "Does Canopy have X?" → `docs/04-platform-breakdown.md`
- "Day 1 / gate audit procedure" → `docs/06-audit.md`
