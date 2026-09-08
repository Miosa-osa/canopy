# Canopy — Agent Operating Protocol

Read this before touching any file in this repo.

## What This Is

A desktop terminal workspace that survives a quit. Named sessions, git worktrees,
and PTY rehydration. The product is persistence — your terminals, directories, and
AI agent conversations come back after restart.

The 19-module vision (Inbox, Schedule, Chat, Channels, Files, Docs, Tasks, Dashboard,
Analytics, Skills, Templates, Sandboxes, Governance, etc.) is parked. Routes still
exist but are hidden from the sidebar. Do not remove them — they can be re-enabled.

## Build Order

1. Session persistence — `save_state/0` + `restore_state/0` (JSON to disk)
2. PTY rehydration — scrollback + screen state save/restore
3. Agent session resume — `claude --resume <uuid>` on relaunch
4. Named workspaces — layout + sessions + worktrees as a restoreable unit

## Authoritative Docs (read first, always)

`agent-authority.json` declares document status, ownership, and precedence.
Run `python3 scripts/agent_control_plane.py` before acting on repository architecture.
A failed check blocks dependent implementation until the authority defect is resolved.
The current contracts below outrank historical plans and completion reports.
Historical material remains evidence of its date, not proof of current implementation.

| Doc | What it governs |
|-----|----------------|
| `docs/current-product-contract.md` | Current product scope and implementation evidence |
| `docs/24-workspace-engine.md` | Workspace Engine execution boundary |
| `docs/25-review-queue.md` | Canopy operational review queue |
| `docs/agent-control-plane.md` | Authority validation and permission review |

## First Action — Every Session

```bash
make doctor
```

Verifies tool versions match `.tool-versions` and requires ripgrep (`rg`) for workspace search.
Install ripgrep with `brew install ripgrep` on macOS or `apt-get install ripgrep` on Debian/Ubuntu.
The command exits nonzero when a required tool is missing or mismatched. If versions are wrong, stop and
fix before writing any code. Mismatched tooling is the #1 source of build drift.

## Ownership Boundaries

Three agents work this monorepo. Respect boundaries strictly.

| Agent | Owns | Touch |
|-------|------|-------|
| `@devops-engineer` | `canopy/` root, `docs/`, `.github/`, `packages/` | YES |
| `@backend-elixir` | `backend/` | YES |
| `@frontend-svelte` | `desktop/`, `src-tauri/` | YES |

Do not modify files outside your ownership without explicit instruction.

## Core Rules

1. **One responsibility per file.** No god files. If a file does two things, split it.
2. **Tests before code from Week 1 onward.** RED → GREEN → REFACTOR. Not optional.
3. **Match existing conventions.** Look at adjacent files before creating new ones.
4. **No secrets in code.** Credentials go in macOS Keychain (via Tauri plugin-keyring) or CI secrets. Never in files.
5. **No `any` in TypeScript.** Strict mode is enforced. Use `unknown` + type guards.
6. **OpenAPI first.** Backend controllers have OpenAPISpex schemas before they ship. TS types are generated, not hand-written.
7. **Attribution.** Every pattern lifted from a competitor must be traceable to its original source in `NOTICE.md`.
Historical competitor reports under `wiring/` provide supporting evidence; they do not authorize new dependencies or functionality.

## Stack Quick Reference

```
backend/    Elixir 1.19 + Phoenix 1.8 + Ecto + Oban + OpenAPISpex
desktop/    SvelteKit 2 + Svelte 5 runes + Tailwind 4 + shadcn-svelte + TanStack Query
src-tauri/  Rust + Tauri 2 + Tokio + portable-pty + keyring
packages/   @canopyai/types (generated from OpenAPI — do not hand-edit)
```

## Make Targets

```bash
make doctor      # check tool versions
make setup       # install all deps
make dev         # start all three processes concurrently
make test        # ExUnit + Vitest + cargo test (all must pass)
make lint        # Biome + mix format check
make build       # production build
make clean       # wipe all build artifacts
```

## CI

Application jobs in `.github/workflows/ci.yml` are required for PR merge:
- `backend-test` — ExUnit with PostgreSQL service
- `desktop-test` — Vitest + svelte-check + Biome
- `rust-test` — cargo test + clippy + rustfmt

The `agent-control-plane-integrity` job is also required.
Passing structural checks does not prove runtime behavior; run the relevant application regressions.
