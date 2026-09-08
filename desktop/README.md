# Canopy desktop

This directory contains Canopy's SvelteKit/Svelte 5 frontend.
It builds a client-rendered SPA for the Tauri shell, with `ssr = false`, `prerender = false`, and an `index.html` fallback.
Dynamic workspace and session routes need the running backend and are not statically prerendered.

Follow [the development guide](../docs/development.md) and [current product contract](../docs/current-product-contract.md).
Install dependencies from the repository root with `pnpm install --frozen-lockfile` using the package-manager version in the root package manifest.
Do not recreate this project with the Svelte scaffolding CLI.

## Browser development

Run the backend separately on port 9190, then run from this directory:

```bash
pnpm dev
```

The frontend listens on port 5280 with strict-port checking.
The API client currently targets `http://localhost:9190/api/v1`; changing backend `PORT` alone does not update that client or Tauri's CSP.
Tauri native APIs, including the folder picker, are unavailable in an ordinary browser.
A rendered page is not evidence of a completed authenticated runtime session.

## Validation

```bash
pnpm check
pnpm lint
pnpm test
pnpm build
```

`pnpm test` already runs `vitest run`; do not append `--run` to the pnpm command.
Unit tests reject unexpected fetch calls by default and must mock API responses explicitly.
They must pass without a backend running.
`@types/node` is an explicit development dependency for Node-based tooling and test files.

For frontend watch mode, use `pnpm exec vitest`.
The Playwright configurations are separate from the required Vitest CI check.
The legacy harness under `tests/e2e/` contains its own endpoint assumptions and can skip when services are unavailable; a skipped harness is not acceptance evidence.
Confirm its configured URLs and skipped-test count before relying on a run.

`pnpm build` verifies the SPA bundle.
It does not package the native Tauri application or prove native quit/restart restoration.
Use the [native development and build instructions](../docs/development.md) for those separate steps.

Preserve Svelte imports used by templates when formatting.
The Biome configuration disables unused-import/variable checks for Svelte components because template usage is not inferred reliably.
Do not override those exclusions with broad `--only` or unsafe autofixes.
