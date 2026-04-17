# Contributing to Canopy v2

Contributions welcome.

## Read First

- **Architecture:** [`docs/01-foundation.md`](./docs/01-foundation.md) — platform design, tech stack, build order
- **UX:** [`docs/02-frontend-design.md`](./docs/02-frontend-design.md) — design system and component patterns
- **Lifted patterns:** [`docs/03-steal-synthesis.md`](./docs/03-steal-synthesis.md) — competitor patterns with attribution decisions
- **Feature inventory:** [`docs/04-platform-breakdown.md`](./docs/04-platform-breakdown.md) — full feature list with provenance
- **Third-party notices:** [`NOTICE.md`](./NOTICE.md) — attribution for adapted open-source patterns

## Before You Start

```bash
make doctor   # verify tool versions match .tool-versions
make setup    # install all dependencies
make test     # confirm everything is green locally
```

## Workflow

1. Open an issue describing what you want to change and why.
2. Get acknowledgment before writing code — the architecture docs govern scope.
3. Branch from `main`. Branch name: `feat/short-description` or `fix/short-description`.
4. Write tests first (ExUnit for backend, Vitest for desktop).
5. Keep PRs under 400 lines of diff. Larger changes should be broken into sequential PRs.
6. All CI jobs must pass before review is requested.

## Ownership

Three areas of the monorepo have separate owners. If your change spans more
than one area, tag the relevant owner in your PR.

| Area | Owner |
|------|-------|
| `backend/` | backend-elixir specialist |
| `desktop/`, `src-tauri/` | frontend-svelte specialist |
| Root files, `docs/`, `.github/`, `packages/` | devops-engineer |

## Attribution Requirement

Any pattern adapted from Cabinet, Multica, Core-OSS, SuperHQ, Gradient-bang,
or Paperclip must be documented in `docs/03-steal-synthesis.md` and attributed
in `NOTICE.md`. See existing entries for the required format.
