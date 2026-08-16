# Canopy E2E Test Results

**Date:** 2026-04-19
**Run:** `cd desktop && npx playwright test --config tests/e2e/playwright.e2e.config.ts --reporter=list`
**Result:** 40 passed, 2 skipped, 0 failed
**Frontend:** http://localhost:5281 (running)
**Backend:** http://localhost:4000 (running, Phoenix)
**Backend API (dev env var):** http://localhost:9190 (MISCONFIGURED — causes CORS on all data fetches)

---

## Infrastructure Note

Every route triggers CORS errors because the frontend dev environment has `VITE_API_URL` (or equivalent) pointing to `:9190` while the backend runs on `:4000`. This means all API data calls fail silently — pages render their empty/loading states but the shell, navigation, and structural elements load correctly. The route matrix tests assert structural presence, not data content, so all 39 route tests pass. Fix: set `VITE_API_URL=http://localhost:4000` in `.env.local`.

---

## Route Matrix

| # | Route | Slug | HTTP | JS Errors | Screenshot | Status |
|---|-------|------|------|-----------|------------|--------|
| 1 | `/` | root | 200 | CORS only | root.png | ✓ |
| 2 | `/command-center` | command-center | 200 | CORS only | command-center.png | ✓ |
| 3 | `/runtimes` | runtimes | 200 | CORS only | runtimes.png | ✓ |
| 4 | `/sessions` | sessions | 200 | CORS only | sessions.png | ✓ |
| 5 | `/agents` | agents | 200 | CORS only | agents.png | ✓ |
| 6 | `/workspaces` | workspaces | 200 | CORS only | workspaces.png | ✓ |
| 7 | `/sandboxes` | sandboxes | 200 | CORS only | sandboxes.png | ✓ |
| 8 | `/agent-control` | agent-control | 200 | CORS only | agent-control.png | ✓ |
| 9 | `/activity` | activity | 200 | CORS only | activity.png | ✓ |
| 10 | `/review` | review | 200 | CORS only | review.png | ✓ |
| 11 | `/workspace` | workspace-mosaic | 200 | CORS only | workspace-mosaic.png | ✓ |
| 12 | `/notifications` | notifications | 200 | CORS only | notifications.png | ✓ |
| 13 | `/schedule` | schedule | 200 | CORS only | schedule.png | ✓ |
| 14 | `/chat` | chat | 200 | CORS only | chat.png | ✓ |
| 15 | `/channels` | channels | 200 | CORS + BUG-001 | channels.png | ⚠ |
| 16 | `/files` | files | 200 | CORS only | files.png | ✓ |
| 17 | `/docs` | docs | 200 | CORS only | docs.png | ✓ |
| 18 | `/tasks` | tasks | 200 | CORS only | tasks.png | ✓ |
| 19 | `/issues` | issues | 200 | CORS + BUG-002 | issues.png | ⚠ |
| 20 | `/my-issues` | my-issues | 200 | CORS only | my-issues.png | ✓ |
| 21 | `/projects` | projects | 200 | CORS only | projects.png | ✓ |
| 22 | `/goals` | goals | 200 | CORS + BUG-003 | goals.png | ⚠ |
| 23 | `/routines` | routines | 200 | CORS only | routines.png | ✓ |
| 24 | `/knowledge` | knowledge | 200 | CORS only | knowledge.png | ✓ |
| 25 | `/skills` | skills | 200 | CORS only | skills.png | ✓ |
| 26 | `/templates` | templates | 200 | CORS only | templates.png | ✓ |
| 27 | `/team` | team | 200 | CORS + BUG-004 | team.png | ⚠ |
| 28 | `/analytics` | analytics | 200 | CORS only | analytics.png | ✓ |
| 29 | `/governance` | governance | 200 | CORS only | governance.png | ✓ |
| 30 | `/settings` | settings | 200 | CORS only | settings.png | ✓ |
| 31 | `/settings/sidebar` | settings-sidebar | 200 | CORS only | settings-sidebar.png | ✓ |
| 32 | `/settings/appearance` | settings-appearance | 200 | CORS only | settings-appearance.png | ✓ |
| 33 | `/settings/runtimes` | settings-runtimes | 200 | CORS only | settings-runtimes.png | ✓ |
| 34 | `/settings/budgets` | settings-budgets | 200 | CORS only | settings-budgets.png | ✓ |
| 35 | `/settings/governance` | settings-governance | 200 | CORS only | settings-governance.png | ✓ (redirects → /governance) |
| 36 | `/settings/miosa` | settings-miosa | 200 | CORS only | settings-miosa.png | ✓ |
| 37 | `/settings/keyboard` | settings-keyboard | 200 | CORS only | settings-keyboard.png | ✓ |
| 38 | `/settings/integrations` | settings-integrations | 200 | CORS only | settings-integrations.png | ✓ |
| 39 | `/settings/profile` | settings-profile | 200 | CORS only | settings-profile.png | ✓ |

Legend: ✓ pass | ⚠ pass with known bug logged | ✗ fail | — skipped

---

## Claude Round-Trip

| Step | Description | Result |
|------|-------------|--------|
| 1 | Navigate to /runtimes | ✓ |
| 2 | Runtimes region visible | ✓ |
| 3 | Navigate to /sessions | ✓ |
| 4 | New session button visible + clicked | ✓ |
| 5 | NewSessionModal opens | ✓ |
| 6 | Prompt textarea present, filled "say hello" | ✓ |
| 7 | Runtime select visible | BLOCKED — no authenticated runtimes (CORS blocks /api/v1/runtimes at :9190) |
| 8–17 | Spawn → terminal → input → output → pause/resume | NOT REACHED |

**Root cause:** `VITE_API_URL` in dev points to `:9190`. Runtimes API call is blocked by CORS. Modal shows "No authenticated runtimes — configure one in Settings." The spawn button is disabled. Fix the env var and re-run to complete the full round-trip.

Screenshot: `screenshots/claude-roundtrip-blocked.png`

---

## Kanban Dispatch

**Status:** — SKIPPED

Reason: `/tasks` renders in list view by default. No board/kanban column visible without seeded task data. Board view toggle exists but no task cards to drag. Seed tasks via the API then re-run.

---

## Multi-Board

**Status:** — SKIPPED

Reason: No BoardPicker component found on `/tasks`. Feature not yet implemented — board picker not in DOM. Will pass once the feature ships.

---

## Known Bugs (found during test run)

| ID | Severity | Route | Error | Root Cause |
|----|----------|-------|-------|------------|
| BUG-001 | HIGH | `/channels` | `Cannot read properties of undefined (reading '0')` | `channels[0]` accessed without null guard when API is unreachable; page crashes before redirect |
| BUG-002 | MEDIUM | `/issues` | `each_key_duplicate` | Svelte `{#each}` block has duplicate `key` values in issues list; likely duplicate IDs in mock/empty data |
| BUG-003 | MEDIUM | `/goals` | `p.charAt is not a function` | `assigneeFilter` is `null` or non-string when passed into a `.charAt(0).toUpperCase()` formatter |
| BUG-004 | HIGH | `/team` | `agentsQuery not exported` + `Cannot read properties of undefined (reading 'default')` | Vite HMR stale module cache (timestamp in URL); manifests as broken import. Restart dev server to clear. If it persists after restart, the export was renamed without updating the import. |

---

## Infrastructure Issue

| Issue | Impact | Fix |
|-------|--------|-----|
| `VITE_API_URL` points to `:9190` but backend runs on `:4000` | All API calls CORS-blocked in browser; pages render empty/loading state only | Set `VITE_API_URL=http://localhost:4000` in `desktop/.env.local` |

---

## How to Re-Run

```bash
cd /Users/rhl/Desktop/OptimalOS/CanopyOS/canopy/desktop
npx playwright test --config tests/e2e/playwright.e2e.config.ts --reporter=list
```

Screenshots land in `tests/e2e/screenshots/`.

To run a single suite:
```bash
# Route matrix only
npx playwright test --config tests/e2e/playwright.e2e.config.ts --grep "Route matrix" --reporter=list

# Claude round-trip only
npx playwright test --config tests/e2e/playwright.e2e.config.ts --grep "claude-roundtrip" --reporter=list
```

To unblock the full round-trip:
1. Add `VITE_API_URL=http://localhost:4000` to `desktop/.env.local`
2. Restart the dev server (`pnpm dev`)
3. Re-run the test suite
