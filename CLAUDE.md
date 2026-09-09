# Canopy - Agent Operating Protocol

Read this before touching any file in this repo.

## What This Is

Canopy is a desktop workspace for terminal sessions, agent runtimes, and git worktrees.
Session continuity across restarts is the current product focus.
The current product contract identifies implemented persistence paths and the remaining native/runtime verification limits.
Do not claim complete screen restoration, crash recovery, or universal provider conversation resume solely from metadata snapshots or unit tests.

The broader module vision is parked in navigation.
Existing routes remain for possible future activation; do not treat their presence as current product readiness or remove them without a scoped decision.

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
| `docs/agent-control-plane.md` | Authority validation, evidence, and permission review |
| `docs/development.md` | Current setup, commands, and verification reference |

## First Action - Every Session

```bash
make doctor
```

Verifies tool versions match `.tool-versions` and requires ripgrep (`rg`) for workspace search.
Install ripgrep with `brew install ripgrep` on macOS or `apt-get install ripgrep` on Debian/Ubuntu.
The command exits nonzero when a required tool is missing or mismatched.
Fix mismatched tooling before writing code.
Use the package-manager version declared in the root package manifest for reproducible dependency installs.

## Ownership Boundaries

Three agents work this monorepo.
Respect boundaries strictly.

| Agent | Owns | Touch |
|-------|------|-------|
| `@devops-engineer` | `canopy/` root, `docs/`, `.github/`, `packages/` | YES |
| `@backend-elixir` | `backend/` | YES |
| `@frontend-svelte` | `desktop/`, `src-tauri/` | YES |

Do not modify files outside your ownership without explicit instruction.

## Core Rules

1. **One responsibility per file.**
   Split a file when it has multiple responsibilities.
2. **Tests before code.**
   Reproduce the behavior, then use red, green, and refactor steps.
3. **Match existing conventions.**
   Read adjacent files before introducing a new pattern.
4. **No plaintext secrets in source or logs.**
   Use approved credential interfaces.
   The backend Vault encrypts credentials in PostgreSQL; Rust native keyring commands are a separate interface.
   Do not describe every runtime credential as stored only in the OS keychain.
5. **No `any` in TypeScript.**
   Use `unknown` and type guards under strict mode.
6. **OpenAPI first.**
   Backend controllers have OpenAPISpex schemas before they ship.
   Generated TypeScript definitions are not hand-edited.
7. **Attribution.**
   Trace borrowed patterns through `NOTICE.md`.
   Historical competitor reports provide supporting evidence and do not authorize new dependencies or functionality.

## Stack Quick Reference

```
backend/    Elixir 1.19 + Phoenix 1.8 + Ecto + Oban + OpenAPISpex
desktop/    SvelteKit 2 + Svelte 5 runes + Tailwind 4 + MIOSA components + TanStack Query
src-tauri/  Rust + Tauri 2 + Tokio + portable-pty + keyring
packages/   @canopyai/types (generated from OpenAPI - do not hand-edit)
```

## Make Targets

```bash
make doctor      # check tool versions
make setup       # install all deps
make dev         # backend + Tauri; Tauri starts the single Vite server
make test        # ExUnit + Vitest + cargo test (all must pass)
make test-watch  # frontend Vitest watch only
make lint        # Biome + mix format check
make build       # production build
make clean       # wipe all build artifacts
```

## CI

Required application contexts from `.github/workflows/ci.yml` are:

- `Backend (ExUnit)` (`backend-test`): warnings-as-errors compilation, formatting, full ExUnit coverage, and OpenAPI generation.
- `Desktop (Vitest + svelte-check)` (`desktop-test`): typecheck, Biome, unit tests, and SPA build.
- `Rust (cargo test)` (`rust-test`): Rust tests, clippy, and rustfmt.

The separate `agent-control-plane-integrity` context is also required.
The backend coverage floor is explicitly 67.5%; historical 80% targets and the previous implicit 90% default were not achieved baselines.
Protected `main` requires independent code-owner review and applies that requirement to administrators.
Follow the live settings and the evidence limits documented in the current control-plane contract.
Passing structural checks does not prove semantic instruction consistency, runtime authorization, or complete product behavior.
