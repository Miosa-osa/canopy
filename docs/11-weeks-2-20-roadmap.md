> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Canopy v2 — Weeks 2–20 Roadmap

**Date:** 2026-04-17
**Status:** Active plan. Week 1 complete (commits `2688410` / `23d7cd5` / `f0645a9`).
**Exit criterion for v1.0:** all 19 modules live, installer shipping, voice layer optional.

---

## Phase Overview

```
         ┌─────────────── v0.1 SHIPPED ───────────────┐
Week 1   Cockpit + 3 adapters + SSE + Foundation UI    ✅ DONE
Week 2   Agent autonomy — heartbeat + MIOSA + skills + MCP
Week 3   Workspace protocol + file ops + agent seeder polish
         ┌─────────────── v0.2 PRODUCTIVITY ───────────┐
Week 4   Shell polish — keyboard nav + empty states + motion
Week 5   Tasks module (Kanban w/ agents as teammates)
Week 6   Chat module (multi-thread AI chat w/ tool-calling)
Week 7   Docs module (Tiptap collaborative, no CRDT yet)
Week 8   Channels module (team messaging w/ agents)
Week 9   Files module (local + pgvector semantic search)
Week 10  Command Center (dashboard widgets + metrics)
Week 11  Schedule (Google Cal + M365 OAuth)
Week 12  Inbox (Gmail + Outlook OAuth + triage agents)
         ┌─────────────── v0.3 SYSTEM ────────────────┐
Week 13  Skills library + marketplace + sharing
Week 14  Templates + workspace starter kits
Week 15  Analytics (session/cost/goal progress)
Week 16  Governance UI (approval flows + audit log)
Week 17  Multi-user + RBAC + invites
         ┌─────────────── v1.0 SHIP ──────────────────┐
Week 18  Real-time collab (CRDT / Yjs for docs)
Week 19  Voice layer (Pipecat pipeline)
Week 20  Installer, notarize, auto-update, DMG, docs site
```

Every week ends with a commit + `docs/NN-weekN-report.md` audit gate.

---

## Week 2 — Agent Autonomy

**Goal:** agents run without user intervention. Heartbeat cron fires, sandboxes provision, session resume works across restarts.

### Day 1 — MIOSA + Heartbeat + Session Resume

| Track | Scope | File deliverables |
|-------|-------|-------------------|
| **A. MIOSA client** | Real HTTP client for external MIOSA API. `POST /v1/sandboxes`, `exec/3`, `destroy/1`. Reads `MIOSA_API_URL` + `MIOSA_API_KEY` from runtime config. | `lib/canopy/miosa/client.ex` (~150), `lib/canopy/miosa.ex` real impl, tests |
| **B. Heartbeat Oban worker** | `Canopy.Heartbeat.Worker` impl `Oban.Worker`. Reads `agent.heartbeat_cron`, fires `Canopy.Sessions.create/1` on schedule. Registers cron entries on agent hire. | `lib/canopy/heartbeat/worker.ex` (~120), `lib/canopy/heartbeat/registrar.ex` (~80) |
| **C. Session resume persistence** | Persist `{workspace_id, agent_slug} → external_session_id` on every `:result` entry. On new session creation, look up + pass `--resume <id>` via adapter args. | `lib/canopy/sessions/resume.ex` (~100), migration, adapter args lookup |
| **D. OpenAPI → TS generation** | `mix canopy.gen.openapi` writes `packages/types/src/api.ts`. Wire into `pnpm -C desktop typecheck` pipeline. | `lib/mix/tasks/canopy.gen.openapi.ex`, `packages/types/package.json` gen script |

Parallel-safe: A + B touch backend/lib/canopy/{miosa, heartbeat, sessions}/* (no overlap). C touches sessions + adapter args (coordinate with A, B before merging). D is meta/tooling.

### Day 2 — Skills + Tools + Governance + Budgets

| Track | Scope |
|-------|-------|
| **E. Skills table + API** | Markdown in Postgres, imported from registries. `lib/canopy/skills/*`, `GET/POST /api/v1/skills`, `mix canopy.seed.skills` |
| **F. Tool registry** | `@tool` macro pattern in Elixir. Tools registered at boot, exposed via `list_tools/0`. Used by adapters via MCP or system-prompt injection. |
| **G. Governance gates** | Approval rules: "block session if runtime X AND workspace Y AND prompt matches regex Z". API + middleware plug. |
| **H. Budget enforcement** | 3-tier (visibility / soft alert 80% / hard ceiling). Per-agent + per-project. Enforced at session-create time + warned at 80%. |

### Day 3 — Dual-Plane Bridge + MCP Server + Polish

| Track | Scope |
|-------|-------|
| **I. Dual-plane adapter bridge** | MCP-capable adapters (Claude/Codex/OpenCode) get tools via MCP stdio server. Non-MCP adapters (Aider/Cursor/Windsurf) get tools via system-prompt curl instructions. Same workspace API. |
| **J. MCP server wrapper** | Expose `/api/v1/*` as an MCP server: `@canopyai/mcp-server`. External agents can call Canopy tools. |
| **K. Svelte warnings cleanup** | 29 `state-referenced-locally` TanStack warnings. Fix pattern: replace `const opts = $derived(...); createQuery(opts)` with `createQuery(() => factory())`. Ensure types still infer. |
| **L. Rate limiting plug** | Hammer plug on `/api/v1/*`, 100 req/min per IP. Defense-in-depth for eventual public exposure. |
| **M. `miosa-foundation/` rename** | Audit item #1. Renames `src/lib/design/foundation/` → `design/miosa-foundation/` to resolve "foundation" name overload. |

### Day 4 — Audit + Report

Re-run `06-audit.md` checklist. Write `docs/12-week2-report.md`. Commit as `feat: Week 2 — agent autonomy + MIOSA + skills + MCP`.

### Week 2 Exit Criteria

- [ ] Agent with `heartbeat_cron: "*/5 * * * *"` fires every 5 minutes automatically
- [ ] Session requests a MIOSA sandbox, receives URL, adapter injects `CANOPY_MIOSA_SANDBOX_URL` env var
- [ ] User runs session → restarts app → hires agent again → resume picks up where it left off
- [ ] `pnpm typecheck` in `desktop/` uses generated types from OpenAPI spec
- [ ] `curl http://localhost:9190/api/v1/skills` returns seeded skills
- [ ] Governance rule blocks a session when triggered, surfaces approval UI
- [ ] Budget exceeded → session fails with clear error
- [ ] Third-party MCP client can call Canopy tools
- [ ] 0 svelte-check warnings
- [ ] 450+ backend tests passing

---

## Weeks 3–12 — Productivity Modules

Each module is a self-contained week. Most follow this template:

### Module Template (applied to Tasks/Chat/Docs/Channels/Files/Schedule/Inbox/Dashboard)

| Day | Work |
|-----|------|
| 1 | Ecto schemas + migrations + context module + OpenAPISpex schemas |
| 2 | Phoenix controllers + API endpoints |
| 3 | SvelteKit pages + Foundation patterns + `$lib/api/queries/<module>.ts` |
| 4 | Tests + polish + `/coming-soon` → real route flip |

### Week 3 — Workspace Protocol + File Ops

- Workspace CRUD endpoints (`GET/POST/PUT /api/v1/workspaces`)
- File tree API (list/read/write with path-traversal guards)
- Workspace switcher in sidebar
- Persona editor (Tiptap) for `/agents/:slug`

### Week 4 — Shell Polish

Not a new module — a polish pass. Fixes the real rough edges:
- Command palette scrubs (⌘K fuzzy search fixes)
- Keyboard nav on every list (j/k/↵/r works everywhere)
- All empty / loading / error states per FRONTEND-DESIGN §9
- Motion polish (hover states, transitions, glows consistent)
- Onboarding wizard (5 steps, skippable)

### Week 5 — Tasks (Kanban)

Initiatives → Projects → Issues → Sub-issues. Agents as assignees. Board / list / calendar views.

### Week 6 — Chat

Multi-thread AI chat with tool-calling. Each thread backed by a Canopy Session. Streaming via existing SSE.

### Week 7 — Docs

Tiptap collaborative editor. **No CRDT in Week 7** — single-user only. CRDT deferred to Week 18.

### Week 8 — Channels

Team messaging. Foundation chat components. Agents as channel members (using `ActorAvatar`).

### Week 9 — Files

Local + optional cloud (S3/R2). pgvector semantic search. File preview component (image/PDF/CSV/md).

### Week 10 — Command Center

Dashboard widgets. Active agents live panel. Spend breakdown. Goal progress.

### Week 11 — Schedule

Google Calendar + M365 OAuth. Heartbeat cron overlay on calendar view.

### Week 12 — Inbox

Gmail + Outlook OAuth. Triage agents auto-categorize. Agent response drafts.

---

## Weeks 13–17 — System Modules

### Week 13 — Skills library + marketplace + sharing
### Week 14 — Templates + workspace starter kits
### Week 15 — Analytics (sessions/cost/goals) — charts
### Week 16 — Governance UI (approval flows + audit log viewer)
### Week 17 — Multi-user + RBAC + invites

---

## Weeks 18–20 — v1.0 Ship

### Week 18 — Real-time collaboration
Yjs or automerge integration for Docs. Multi-cursor presence.

### Week 19 — Voice layer
Pipecat pipeline (Deepgram STT → LLM → Cartesia TTS). Wake word optional.

### Week 20 — Installer
- macOS DMG + notarize
- Windows MSI + code sign
- Linux AppImage
- Auto-update via Tauri Updater
- Public docs site (Docusaurus or VitePress)
- Public launch

---

## Non-Weekly Continuous Work

These don't get their own week but happen alongside:

- **Bug fixes** from user dogfooding
- **Test coverage** maintained at ≥ 80% on new code
- **Performance profiling** when latency > 200ms appears
- **Security audit** before v0.2 (Week 12 exit) and v1.0 (Week 20 exit)
- **Doc maintenance** — every week's report also updates `docs/01-foundation.md` if architecture changes
- **Audit item cleanup** — 8 inconsistencies in `10-naming-ontology-audit.md` addressed opportunistically

---

## Dependency Graph (high-level)

```
Week 1 (cockpit)
  ↓
Week 2 (autonomy) ─────────→ Week 3 (workspaces + files)
  │                             ↓
  │                           Week 9 (Files module)
  ↓
Week 4 (shell polish) ──────→ Weeks 5-12 (productivity modules, any order)
                                  ↓
                                Week 13-16 (system modules)
                                  ↓
                                Week 17 (multi-user)
                                  ↓
                                Weeks 18-20 (ship)
```

Weeks 5–12 can run in any order — they're independent modules. Weeks 11–12 depend on OAuth scaffolding from Week 2's auth work.

---

## Commitment

One commit per week minimum. Weekly reports in `docs/NN-weekN-report.md`. Every report opens with the same triple-stack verify table (backend tests / desktop check+lint+test+build / rust check+clippy+fmt+test). If a report shows regressions, the week doesn't close until they're fixed.

Track record so far:
- Week 0: 100% green commit — `2688410`
- Week 1 Day 1-3: 100% green commit — `23d7cd5`
- Week 1 Day 4: 100% green commit — `f0645a9`

Pattern holds or we slow down.
