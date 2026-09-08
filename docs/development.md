# Development and verification

Effective: 2026-09-08.
This is current operational guidance; the earlier numbered operations runbook is historical.
Read [the current product contract](current-product-contract.md) and [../CLAUDE.md](../CLAUDE.md) before changing behavior.

## Prerequisites and setup

Use the versions in [.tool-versions](../.tool-versions) and the `packageManager` field in [package.json](../package.json).
`make doctor` checks the toolchain and requires ripgrep for workspace search.
PostgreSQL must have the `vector` extension available; the CI workflow pins its PostgreSQL/pgvector image.

From the repository root:

```bash
make doctor
python3 scripts/agent_control_plane.py
make setup
```

`make setup` installs pnpm and Mix dependencies, creates and migrates `canopy_dev`, seeds it, and runs `make gen-types`.
It writes to the development database.
For an existing environment where database initialization is not needed, install dependencies with `pnpm install --frozen-lockfile` and run `mix deps.get` from `backend/`.

Development and test configuration accept `PGUSER`, `PGPASSWORD`, `PGHOST`, and `PGPORT`.
Defaults are the local `rhl` role, empty password, localhost, and port 5432; override these for your installation.
Development uses `canopy_dev`; tests use `canopy_test` plus `MIX_TEST_PARTITION` when set.
Do not point tests at a personal or production database.
`make db-reset` drops and recreates the development database; it is not a routine startup command.

## Browser and native development

For browser development, use two terminals:

```bash
cd backend && mix phx.server
```

```bash
cd desktop && pnpm dev
```

The backend defaults to port 9190 and Vite to port 5280.
Inspect the listener and its working directory before stopping a conflicting process; do not kill all Phoenix, Vite, or PostgreSQL processes.
The frontend API URL and native CSP currently assume backend port 9190.

For native development, start the backend and run `pnpm tauri dev` from `desktop/`.
Tauri's `beforeDevCommand` starts Vite, so do not also start `pnpm dev` on port 5280.
`make dev` is the combined backend/native entry point, with Tauri owning the frontend process.
Native startup and authenticated provider sessions require their own smoke tests; browser rendering and Rust unit tests alone do not establish them.

## Tests and CI parity

From the repository root:

```bash
python3 scripts/agent_control_plane.py
python3 -m unittest discover -s scripts/tests -p 'test_agent_control_plane.py'
make test
make lint
```

The application commands matching required CI are:

```bash
cd backend
MIX_ENV=test mix compile --warnings-as-errors
mix format --check-formatted
MIX_ENV=test mix test --cover
```

```bash
cd desktop
pnpm check
pnpm lint
pnpm test
pnpm build
```

```bash
cd src-tauri
cargo test
cargo clippy --all-targets -- -D warnings
cargo fmt --all -- --check
```

Run each block from the repository root before entering its directory.
The backend test alias creates and migrates the test database.
For an isolated local test database, set a unique `MIX_TEST_PARTITION`, for example `_local_validation`.
Do not set `PHX_SERVER` during tests.

`make test` runs the three application suites but does not collect backend coverage or include every CI build/lint check.
`make test-watch` is frontend Vitest watch mode; use `make test` for all three suites.
Frontend unit tests reject unmocked fetch calls and must pass without a backend listening.
Validate with a clean frozen dependency installation when diagnosing a local/CI discrepancy.

The required status contexts are `agent-control-plane-integrity`, `Backend (ExUnit)`, `Desktop (Vitest + svelte-check)`, and `Rust (cargo test)`.
Job IDs and display names differ; branch protection uses the named contexts.
The full backend coverage floor is 67.5%, with no new exclusions introduced for the September rollout.
See [the measured baseline](agent-control-plane.md#backend-coverage-baseline) for the approximately 67.7% result and the unmet historical 80% target.

## Generated types and builds

```bash
make gen-types
```

This invokes the package's generation script: export backend OpenAPI JSON, then run `openapi-typescript` to generate `packages/types/src/api.ts`.
The JSON export is not TypeScript and must not be redirected directly into that file.
Generated output is not manually edited.
CI verifies that the OpenAPI JSON can be generated; it does not prove that every hand-maintained frontend domain model matches it.

`make build` builds a backend release, the frontend SPA, and the native Tauri bundle.
Production release configuration requires the environment described in [runtime.exs](../backend/config/runtime.exs).
The current desktop CI build covers the SPA, while Rust CI covers compilation, tests, lint, and formatting.
It does not replace signed native-package verification or a real quit/relaunch test.

## Credentials and local Engine execution

Use the existing credential APIs instead of placing secrets in source, logs, or documentation.
The backend [Vault](../backend/lib/canopy/vault.ex) encrypts credentials in PostgreSQL using key material derived from `SECRET_KEY_BASE`.
Rust also has native keyring commands; do not describe every backend credential as already stored exclusively in the OS keychain.
Keep production secret material distinct from development defaults.

The [workspace Engine contract](24-workspace-engine.md) requires a reviewed canonical Engine checkout and explicit compatibility metadata before listing or executing tasks.
The bridge runs local Mix code, not an independent HTTP Engine service.
Use a dedicated workspace Engine and data store rather than a live private OptimalOS Engine checkout.
