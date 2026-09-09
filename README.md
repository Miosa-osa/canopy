# Canopy

Canopy is a desktop workspace for terminal sessions, agent runtimes, and git worktrees.
Its current product focus is session continuity across restarts.
The [current product contract](docs/current-product-contract.md) separates implemented persistence from remaining end-to-end verification.
A saved session row or a passing build does not establish complete terminal-screen or agent-conversation restoration.

## Current scope

The visible product centers on Build, sessions, runtimes, workspaces, and terminal access.
Broader module routes remain in source but are parked in navigation.
Their existence and historical completion reports do not establish current product readiness.

Implemented foundations include session snapshots, guarded restore behavior, scrollback storage, workspace state, and a workspace-local OptimalEngine task bridge.
See the [product evidence](docs/current-product-contract.md) and [Engine execution contract](docs/24-workspace-engine.md) for code, tests, and limitations.

## Start here

Use [development and verification](docs/development.md) for current setup instructions.
From the repository root:

```bash
make doctor
python3 scripts/agent_control_plane.py
make setup
```

`make setup` installs dependencies, creates and migrates the development database, seeds it, and generates OpenAPI TypeScript types.
It requires PostgreSQL with the `vector` extension available.
Tool versions are pinned in [.tool-versions](.tool-versions) and [package.json](package.json).

For browser development, run these in separate terminals:

```bash
cd backend && mix phx.server
```

```bash
cd desktop && pnpm dev
```

The backend listens on `http://localhost:9190`; the frontend uses `http://localhost:5280`.
Browser mode does not provide Tauri's native folder picker.
For native development, follow the separate instructions in [development and verification](docs/development.md).

## Verification

```bash
make test
make lint
python3 -m unittest discover -s scripts/tests -p 'test_agent_control_plane.py'
```

`make test` runs ExUnit, Vitest, and Rust tests sequentially.
The CI backend job additionally collects coverage with an explicit 67.5% floor; the desktop job also checks types and builds the SPA.
Rust CI runs tests, clippy, and rustfmt.
See [the evidence and retest commands](docs/agent-control-plane.md) for the September 8 baseline and the limits of each check.
The historical 80% coverage target and Mix's former implicit 90% threshold were not achieved baselines.

## Documentation and ownership

[agent-authority.json](agent-authority.json) classifies current contracts, reference material, and historical documents.
Start with [CLAUDE.md](CLAUDE.md), [the documentation index](docs/README.md), and [CONTRIBUTING.md](CONTRIBUTING.md).
Historical plans are preserved for provenance and do not override current contracts.

| Path | Purpose |
|------|---------|
| `backend/` | Elixir/Phoenix API, sessions, persistence, workspace Engine bridge |
| `desktop/` | SvelteKit/Svelte 5 SPA, terminal UI, workspace state |
| `src-tauri/` | Rust/Tauri shell and native commands |
| `packages/types/` | Generated OpenAPI TypeScript definitions |
| `docs/` | Classified contracts, guidance, and historical evidence |
| `.github/` | CI and code-owner configuration |

Protected `main` requires the four named checks and independent code-owner review, including for administrators.
See [permission review](docs/agent-control-plane.md#permission-changes) for the dated settings and review requirements.

Apache 2.0: see [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
