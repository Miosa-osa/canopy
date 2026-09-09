# Contributing to Canopy

Read [CLAUDE.md](CLAUDE.md), the [current product contract](docs/current-product-contract.md), and [development guidance](docs/development.md) first.
Historical plans are reference material; [agent-authority.json](agent-authority.json) determines current ownership and precedence.
Use [NOTICE.md](NOTICE.md) for third-party provenance.

## Before changing code

```bash
make doctor
python3 scripts/agent_control_plane.py
```

Install dependencies and initialize the development database using [the setup guide](docs/development.md).
Reproduce a bug through the affected user flow, then write a regression and implement the fix.
Use the relevant application checks and the full required CI jobs before merge.

## Contribution workflow

1. Describe the problem, intended behavior, and scope in an issue or PR.
2. Branch from current `main` using a descriptive `feat/`, `fix/`, or `docs/` name.
3. Keep changes reviewable and separate unrelated changes where practical.
4. Update current contracts and the authority registry when behavior or ownership changes.
5. Regenerate OpenAPI types with `make gen-types`; do not hand-edit generated output.
6. Request independent code-owner review and resolve review threads.

Protected `main` requires one approving review, code-owner approval, last-push approval, stale-approval dismissal, conversation resolution, and all four required checks.
These requirements also apply to administrators.
A PR author cannot supply their own independent approval.
See [the dated review policy](docs/agent-control-plane.md#permission-changes) and recheck live repository settings before release.

| Area | Engineering owner |
|------|-------------------|
| `backend/` | Backend/Elixir specialist |
| `desktop/`, `src-tauri/` | Frontend/Svelte and Rust specialist |
| Root files, `docs/`, `.github/`, `packages/` | Platform/devops specialist |

[CODEOWNERS](.github/CODEOWNERS) defines actual GitHub review ownership.
Engineering role names in prose do not substitute for configured repository permissions.
