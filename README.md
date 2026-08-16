# Canopy

A desktop terminal workspace that survives a quit. Named sessions, git worktrees, and PTY
rehydration — so when you close the app or reboot, your terminals, working directories, and
AI agent conversations come back where you left them.

Built on Ghostty + tmux habits. Not a chat app. Not a notebook. **A terminal workspace that
doesn't forget.**

## What it does (current scope)

- **Sessions** — named terminal sessions with cwd, command, and status
- **Runtimes** — agent runtime configs (Claude, Codex, Gemini, etc.)
- **Workspaces** — named layouts of sessions + worktrees you can open and close
- **Command Center** — direct terminal access
- **Build** — build view

## What it will do (build order)

1. **Session persistence** — `save_state/0` writes active sessions to disk on quit, `restore_state/0` reads on launch
2. **PTY rehydration** — save terminal scrollback + screen state, restore on launch, relaunch command in the right directory
3. **Agent session resume** — capture which `claude`/`codex` session UUID was in which pane, pass `--resume` on relaunch
4. **Named workspaces** — save a layout + sessions + worktrees as a named workspace, restore on open

## What it doesn't do (anymore)

The 19-module vision (Inbox, Schedule, Chat, Channels, Files, Docs, Tasks, Dashboard, Analytics,
Skills, Templates, Sandboxes, Governance, etc.) is parked. Those routes still exist in the codebase
but are hidden from the sidebar. They can be re-enabled when needed.

---

## Quickstart

```bash
# Verify tool versions match .tool-versions
make doctor

# Install all dependencies (pnpm + mix)
make setup

# Run backend + desktop + Tauri dev server concurrently
make dev

# Run all test suites (ExUnit + Vitest + cargo test)
make test
```

## Stack

| Layer     | Technology                              |
|-----------|-----------------------------------------|
| Backend   | Elixir 1.19 + Phoenix 1.8, PostgreSQL   |
| Desktop   | SvelteKit 2 + Svelte 5, Tailwind 4      |
| App shell | Tauri 2 (Rust sidecar)                  |
| Styling   | OKLCh design tokens + MIOSA Foundation components (pill-first, glassmorphism, dark monochrome) |
| Ports     | Backend `:9190`, SvelteKit dev `:5280`, Tauri window auto-follows |
| Realtime  | Phoenix PubSub + SSE                    |
| Jobs      | Oban (Postgres-backed)                  |
| Types     | OpenAPISpex → generated TS (`@canopyai/types`) |
| Tests     | ExUnit + Vitest + Playwright + cargo    |
| CI        | GitHub Actions (all suites required)    |

## Commands

| Command          | What it does                                          |
|------------------|-------------------------------------------------------|
| `make doctor`    | Verify tool versions vs `.tool-versions`              |
| `make setup`     | Install pnpm deps + mix deps                          |
| `make dev`       | Start backend + desktop + Tauri concurrently          |
| `make test`      | ExUnit → Vitest → cargo test (sequential, all must pass) |
| `make test-watch`| All three test suites in watch mode                   |
| `make lint`      | Biome check (desktop) + mix format check (backend)    |
| `make format`    | Apply all formatters                                  |
| `make build`     | Production: mix release + pnpm build + cargo tauri build |
| `make clean`     | Remove `_build`, `node_modules`, `target`, `dist`     |
| `make seed`      | Insert the 9 canonical runtimes into dev DB           |
| `make db-reset`  | Drop + create + migrate + seed the dev database       |

## Documentation

Architecture and design decisions live in [`docs/`](./docs/README.md):

- [`docs/01-foundation.md`](./docs/01-foundation.md) — Platform architecture, tech stack, build order
- [`docs/02-frontend-design.md`](./docs/02-frontend-design.md) — Design system, screens, component patterns
- [`docs/03-steal-synthesis.md`](./docs/03-steal-synthesis.md) — Competitor patterns lifted with attribution
- [`docs/04-platform-breakdown.md`](./docs/04-platform-breakdown.md) — Full feature inventory with provenance
- [`docs/05-operations.md`](./docs/05-operations.md) — Runbook (setup / dev / troubleshooting)
- [`docs/06-audit.md`](./docs/06-audit.md) — Reusable hardening checklist
- [`docs/07-day1-report.md`](./docs/07-day1-report.md) — Day 1 completion record
- [`docs/08-week1-plan.md`](./docs/08-week1-plan.md) — Week 1 execution plan
- [`docs/09-foundation-migration.md`](./docs/09-foundation-migration.md) — MIOSA Foundation migration plan

See [`NOTICE.md`](./NOTICE.md) for third-party acknowledgments.
See [`CONTRIBUTING.md`](./CONTRIBUTING.md) for contribution guidelines.

## Repository Layout

```
canopy/
├── backend/       Elixir + Phoenix (owned by backend-elixir agent)
├── desktop/       SvelteKit + Svelte 5 (owned by frontend-svelte agent)
├── src-tauri/     Rust sidecar (owned by frontend-svelte agent)
├── packages/
│   └── types/     Shared TS types generated from OpenAPI schemas
├── docs/          Authoritative architecture and design docs
└── .github/       CI/CD workflows
```

## License

Apache 2.0 — see [`LICENSE`](./LICENSE).
