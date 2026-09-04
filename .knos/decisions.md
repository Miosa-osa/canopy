# Decisions and current work

<!-- Written by `knos export`. Commit this file. -->

A second clone reads this on its first question — it is one of the decision
records knos looks for. Nothing here is private: secrets and private paths
never reach it.


## Decisions

- **ownership boundaries** — Three agents work this monorepo. `@devops-engineer` owns `canopy/` root, `docs/`, `.github/` and `packages/`; `@backend-elixir` owns `backend/`; `@frontend-svelte` owns `desktop/` and `src-tauri/`. Do not modify files outside your ownership without explicit instruction.  _(CLAUDE.md)_
- **make doctor first, every session** — Verify tool versions match `.tool-versions` before writing any code. Mismatched tooling is the number one source of build drift.  _(CLAUDE.md)_
- **read the authoritative docs first** — `docs/01-foundation.md` for architecture, `docs/02-frontend-design.md` for UX, `docs/04-platform-breakdown.md` for the feature inventory.  _(CLAUDE.md, CONTRIBUTING.md)_
- **claims expire on their own** — Issue locks are released by an expiry worker rather than held until something clears them.  _(backend/lib/canopy/issues/lock_expiry_worker.ex)_

## Being worked on right now

_Nothing claimed._

---
<sub>knos export. Claims lapse after 30 minutes.</sub>
