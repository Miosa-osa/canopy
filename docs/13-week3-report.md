> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Canopy v2 — Week 3 Completion Report

**Date:** 2026-04-18
**Status:** ✅ COMPLETE — Week 4 (Shell Polish) unblocked
**Scope:** Workspace Protocol + File Ops + Session↔Workspace Binding + Persona Editor + Agent Seeder Polish

---

## 1. Go / No-Go Decision

**GO.** Triple-stack verify clean. 1026 backend / 208 vitest — all green. Zero
TypeScript errors. `/workspaces` + `/workspaces/[slug]` routes both live.
WorkspaceSwitcher mounted in sidebar, ⌘⇧W shortcut wired. Agent corpus
expanded from 169 → 336 unique rows (2.0× growth). Workspace Protocol
backend pre-shipped in Week 2 is now end-to-end usable from the UI.

---

## 2. Triple-Stack Verify

| Stack | Command | Result |
|-------|---------|--------|
| Backend compile | `mix compile --warnings-as-errors` | ✅ clean |
| Backend format | `mix format --check-formatted` | ✅ clean |
| Backend tests | `mix test --seed 0` | ✅ **1026 / 0 failures** (13.1s) |
| Desktop type-check | `pnpm check` | ✅ **0 errors**, 16 warnings (pre-existing Foundation primitives) |
| Desktop tests | `pnpm test` | ✅ **208 / 208** (210ms) |
| Rust compile | `cargo check --manifest-path src-tauri/Cargo.toml` | ✅ clean |
| Rust tests | `cargo test --manifest-path src-tauri/Cargo.toml` | ✅ **11 / 0** |

Growth since Week 2 sign-off: backend +25 tests (1001 → 1026), vitest
+159 tests (49 → 208).

---

## 3. What Shipped — 7 Tracks

### Track #53 — Workspace queries + types (prerequisite, synchronous)

- `desktop/src/lib/domain/workspaces/types.ts` — `Workspace`, `WorkspaceTemplate`, `FileTreeNode`, `DirEntry`, `FileReadResponse`, filter/body shapes
- `desktop/src/lib/api/queries/workspaces.ts` — 11 raw API calls + 6 query factories + 5 mutation factories matching all backend endpoints
- Splat-path encoding helper preserves `/` between URI-encoded segments (matches Phoenix `*path` wildcard)

### Track #54 — Workspace list + TemplatePicker

- `desktop/src/routes/workspaces/+page.svelte` (148 LOC) — grid of glass-cards with empty state and new-workspace CTA
- `desktop/src/lib/design/patterns/TemplatePicker.svelte` (249 LOC) — modal with 4 starter templates and create form
- `desktop/src/lib/design/patterns/WorkspaceCard.svelte` (207 LOC) — card with inline delete confirm (over 100 LOC target; left inline rather than extract a 40-line sub-component)
- 27 tests

### Track #55 — Workspace detail + FileTree

- `desktop/src/routes/workspaces/[slug]/+page.svelte` (387 LOC) — three-pane: tree / viewer / info PushPanel + breadcrumb
- `desktop/src/lib/design/patterns/FileTree.svelte` (224 LOC) — recursive tree with full keyboard navigation (↑↓→←↵)
- `desktop/src/lib/design/patterns/FileTreeNode.svelte` (160 LOC) — extracted row component (Svelte 5 self-import pattern)
- Focus tracked as `focusedPath` in `$state`; selected row uses `aria-current="true"`
- 18 tests

### Track #56 — FileViewer pattern

- `desktop/src/lib/design/patterns/FileViewer.svelte` (677 LOC — CSS-heavy, logic ~180)
- `desktop/src/lib/utils/markdown.ts` (121 LOC) — zero-dep inline renderer (headings, bold, italic, inline-code, fenced code blocks, lists, links), HTML-escaped
- Three modes: markdown (split edit+preview), code (mono + line numbers), binary fallback
- `⌘S` save + `beforeNavigate` dirty guard + toast feedback
- Supported extensions: `ts, js, tsx, jsx, ex, exs, rs, go, py, json, yaml, yml, sh, svelte, css`
- 37 tests (22 markdown util + 15 viewer logic)

### Track #57 — WorkspaceSwitcher + sidebar

- `desktop/src/lib/design/patterns/WorkspaceSwitcher.svelte` (246 LOC) — dropdown with search, keyboard nav, "New workspace" CTA, emoji-derived-from-template
- `desktop/src/lib/stores/ui.svelte.ts` — extended with `currentWorkspaceSlug` + `workspaceSwitcherOpen` (+ 36 LOC)
- `desktop/src/lib/utils/keyboard.ts` — added `⌘⇧W` case delegating to `ui.toggleWorkspaceSwitcher()`
- `desktop/src/routes/+layout.svelte` — mounted WorkspaceSwitcher in sidebar footer between spend bar and settings
- localStorage persistence for `currentWorkspaceSlug`
- 33 tests

### Track #58 — Session ↔ workspace binding

- Backend: `sessions.workspace_slug` already existed — **one pre-existing bug caught**: frontend `listSessions()` sent `workspace_slug` param but backend reads `workspace`. Fixed in `queries/sessions.ts` (1-line change).
- Frontend: `/sessions/+page.svelte` got workspace `<Select>` loaded from `workspacesQuery()` + URL pre-fill support (`?workspace=slug`)
- `/sessions/[id]/+page.svelte` got a "Mounted workspace" chip linking to `/workspaces/:slug`
- 5 new backend tests + 16 new frontend tests
- **Deferral flagged:** `listSessions()` sends `runtime_type` but backend reads `runtime` — pre-existing mismatch, out of scope for this track. Captured in §6.

### Track #59 — Persona editor

- Backend (additive): `PUT /api/v1/agents/:slug/persona` route + `Agents.update_persona/2` + controller action + OpenAPI schema + FallbackController `:write_failed` clause
- Frontend: `updatePersonaMutation` factory + full rewrite of `/agents/[slug]/+page.svelte` with edit/read toggle, `⌘S` save, `beforeNavigate` dirty guard, markdown preview via shared `markdown.ts`
- Tests for the new API and the new page contract
- **Deferral flagged:** persona writes to the `priv/agents/*.md` source file — fragile (tests assert `200 | 422` depending on whether the file exists at runtime). Captured in §6.

### Track #60 — Agent seeder polish

- `mix canopy.seed.agents` rewritten (219 → 381 LOC) with:
  - **All-qualify slug collision strategy:** collisions get `{base}-{category}` suffix; globally-unique bases keep bare slug
  - **Idempotency:** re-runs report `0 inserted, N updated`
  - **Category normalization:** any subdir not in the canonical 19 → categorized as `specialized` with warning
  - **Filter-safe:** `--only <category>` preserved
- **Corpus expansion:** 169 → **336 unique DB rows** (2.0×)
- 1 source file skipped (`engineering/placeholder.md` — no frontmatter)
- Full conflict report at `/tmp/canopy-agent-conflicts.txt` (682 lines)
- 18 seeder tests added

Per-category top 5: technology 42, growth 41, creative-content 33, operations 30, marketing 27.

---

## 4. Integration Notes

- **FileViewer ↔ FileTree:** wired clean; tree's `onSelect(path)` flows through to viewer via `selectedPath` parent state.
- **FileViewer ↔ markdown util:** shared between Track #56 and Track #59 (persona preview). Single renderer, no duplication.
- **WorkspaceSwitcher ↔ sessions page:** sessions page temporarily uses a Foundation `<Select>` (Track #58 began before #57 landed). Migration to WorkspaceSwitcher tracked in §6.
- **Seeder ↔ persona editor:** both touch `priv/agents/*.md`. Seeder is source-of-truth on boot; persona editor writes back at runtime. Fragile coupling — §6 deferral.

---

## 5. Week 3 Exit Criteria

| Criterion (from roadmap) | Status | Evidence |
|--------------------------|--------|----------|
| Workspace CRUD endpoints | ✅ (Week 2 preship) | 54 routes merged, workspace detail tested |
| File tree API with path-traversal guards | ✅ (Week 2 preship) | 105 workspace tests |
| Workspace switcher in sidebar | ✅ | Track #57 |
| Persona editor (Tiptap) for `/agents/[slug]` | ⚠️ partial | Markdown-only textarea with preview — Tiptap deferred to Week 18 collab work |
| Template materialization UX | ✅ | TemplatePicker |
| Session ↔ workspace binding | ✅ | chip + filter + create-form selector |

---

## 6. Issues Found + Deferrals

| # | Issue | Target |
|---|-------|--------|
| 1 | `listSessions()` sends `runtime_type` but backend reads `runtime` — pre-existing mismatch, not a Week 3 regression | Week 4 polish — 1-line fix in `queries/sessions.ts` |
| 2 | Persona edit writes to `backend/priv/agents/*.md` (seed source file). Fragile. Test hedges on `200 \| 422`. | Week 4 polish — add `agents.persona_markdown` DB column + migration, make `update_persona/2` write to DB, seeder stops being live source-of-truth |
| 3 | Sessions page uses Foundation `<Select>` instead of WorkspaceSwitcher | Week 4 polish — 20-min migration once both land on main |
| 4 | `WorkspaceCard.svelte` is 207 LOC vs 100 target (inline delete confirm) | Accept — no compelling split |
| 5 | `FileViewer.svelte` is 677 LOC (logic 180, CSS 330, template 120) | Accept — multi-mode editor with proper theming; extraction already done (markdown util) |
| 6 | No browser-project vitest config → component DOM tests run as logic contract tests only | Week 4 or later — add `browser` project to vitest; currently tests cover query factories, shape contracts, and pure logic |
| 7 | `engineering/placeholder.md` has no frontmatter, seeder skips it | Remove the file — it's a stray artifact |
| 8 | Phantom ` 2` directories from macOS Finder duplicates in `priv/agents/` | Seeder silently excludes them. Clean up priv tree in ops pass. |

---

## 7. Assumptions

1. Markdown renderer is deliberately minimal. Shiki/highlight.js deferred
   to Week 4 polish — code files render in mono + line numbers without
   tokenization for now.
2. All-qualify slug collision strategy produced 336 rows from 337 source
   files. If future agent corpus additions expect specific slugs, the
   `{base}-{category}` format is stable and URL-safe.
3. localStorage persistence for `currentWorkspaceSlug` is deliberately
   session-scoped — a multi-workspace session routing system (Week 5+)
   will supersede this.
4. The `beforeNavigate` dirty guards in FileViewer and persona editor use
   native browser `confirm()` — a styled modal is deferred to Week 4.

---

## 8. Next (Week 4 kickoff)

Week 4 scope per `docs/11-weeks-2-20-roadmap.md` §Week 4: Shell Polish.

1. Command palette ⌘K fuzzy search refinements
2. Keyboard nav pass on every list view (j/k/↵/r consistent)
3. All empty / loading / error states per design doc §9
4. Motion polish (hover, focus, transition glow consistency)
5. Onboarding wizard full sweep (already scaffolded in Week 2 Track #47)
6. **Week 3 deferral cleanup batch** — items §6/1, §6/2, §6/3 — one focused PR
7. `miosa-foundation/` rename (audit item #1) — cross-stack
