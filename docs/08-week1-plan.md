# Canopy v2 — Week 1 Execution Plan

**Date started:** 2026-04-17
**Goal:** Backend unified runtime contract + sessions + 3 live adapters + SSE streaming
**Exit criterion:** `POST /api/v1/sessions { runtime, prompt, cwd }` → spawns subprocess → streams `TranscriptEntry` SSE events → persists session + messages → returns cost. Contract tests green for all 3 adapters.

---

## Parallelization Map

```
Day 1 (today):
  Track A ─ Port markdown (protocol + architecture + 336 agents)            [DONE]
  Track B ─ Ecto schemas + migrations + factories + OpenAPISpex schemas     [in flight]
  Track C ─ ClaudeLocal adapter (reference implementation)                  [in flight]

Day 2:
  Track D ─ SessionsController + RuntimesController + SSE endpoint
  Track E ─ CodexLocal adapter (parallel pattern)
  Track F ─ GeminiLocal adapter (parallel pattern)

Day 3:
  Track G ─ Agent seeder (priv/agents/*.md → Agents table)
  Track H ─ Tauri runtime_detect command → Phoenix sync
  Track I ─ OpenAPI → TS type generation wiring

Day 4 (audit):
  Full e2e test: real Claude binary → sessions row + messages rows + cost.
  Re-run Day 1 audit checklist for Week 1 gate.
  Write 09-week1-report.md.
```

---

## Agent Frontmatter Shape (discovered during port)

Porting the 336 legacy agents revealed the persona format we inherit:

```yaml
---
name: AI Data Remediation Engineer
description: "Specialist in self-healing data pipelines..."
color: green
emoji: 🧬
vibe: Fixes your broken data with surgical AI precision.
reportsTo: null                    # DROPPED in v2 (no org hierarchy)
budget: 500                        # maps to Agent.budget_monthly_usd
adapter: osa                       # LEGACY — needs mapping to v2 runtime type
signal: "S=(linguistic, spec, inform, markdown, structured)"  # Signal Theory, optional
skills: [development/debug, ...]   # skill refs (slashes)
---
```

**Mapping required during Agent seeding (Day 3, Track G):**

| Legacy `adapter:` value | v2 runtime_type |
|------------------------|-----------------|
| `osa` | (drop — OSA is canopy-legacy only) |
| `claude-code` / `claude_code` | `claude-local` |
| `codex` | `codex-local` |
| `gemini` | `gemini-local` |
| `cursor` | `cursor-local` |
| `opencode` | `opencode-local` |
| `aider` | `aider-local` |
| `windsurf` | `windsurf-local` |
| `pi` | `pi-local` |
| `hermes` | `hermes-local` |
| (missing) | fallback to `claude-local` (most common) |
| anything else | nil — agent needs manual review |

**Fields to drop / ignore when seeding:**
- `reportsTo` (org hierarchy — dropped per 03-steal-synthesis.md)
- `color`, `emoji`, `vibe` — keep in persona markdown body, surface in UI as-needed (Week 4), don't persist in Agents schema column

---

## Day 2 — Track D: SessionsController + RuntimesController + SSE

**Depends on:** Track B (schemas), Track C (ClaudeLocal).

### RuntimesController

```
GET    /api/v1/runtimes                 list all (with status, version, quota, cost)
GET    /api/v1/runtimes/:type           detail for one (config schema, models, recent sessions)
POST   /api/v1/runtimes/:type/test      runs test_environment/1 preflight
GET    /api/v1/runtimes/:type/models    list models via list_models/0
```

Response shape (`runtime_detail_response`, declared in OpenAPISpex):
```elixir
%{
  type: "claude-local",
  kind: "cli",
  name: "Claude Code",
  enabled: true,
  installed: true,
  version: "1.0.24",
  binary_path: "/usr/local/bin/claude",
  capabilities: ["streaming", "tool_calls", "thinking", "resume", "skills_injection"],
  models: [ ... ],
  config_schema: %{ ... },        # from getConfigSchema()
  quota_windows: [ ... ],         # from getQuotaWindows(), or null
  last_detected_at: "..."
}
```

### SessionsController

```
POST   /api/v1/sessions             create + start (body: runtime, model, prompt, cwd, agent_slug, workspace_slug, parent_session_id)
GET    /api/v1/sessions             list (with filters: status, runtime, workspace, limit, cursor)
GET    /api/v1/sessions/:id         detail (includes last N messages)
GET    /api/v1/sessions/:id/events  **SSE stream** of TranscriptEntry events (live + replay option)
DELETE /api/v1/sessions/:id         cancel (if running) or delete (if completed)
GET    /api/v1/sessions/:id/chain   full chain (parent + children + compaction markers)
```

SSE event format:
```
event: transcript_entry
data: {"kind":"assistant","content":{"text":"..."},"emitted_at":"..."}

event: transcript_entry
data: {"kind":"tool_call","content":{"name":"read_file","args":{...}},"tool_call_id":"..."}

event: status
data: {"status":"completed","cost_usd":"0.0234","input_tokens":1200,"output_tokens":450}

event: done
data: {}
```

Uses `Plug.Conn.chunk/2` + Phoenix.PubSub subscription on `"session:<id>"` topic. Replay from DB for past messages before switching to live pub/sub.

### CORS

Already installed (Corsica in :api pipeline). No new work.

### Exit criteria Day 2 / Track D

- `curl -N http://localhost:9190/api/v1/sessions/<id>/events` streams events live
- Full integration test: POST create → SSE subscribe → fake-claude fires → messages arrive → completion event → session row finalized with cost
- RuntimesController returns real data from Runtime schema (populated by Track H Tauri detection)
- Controller tests + integration test green
- OpenAPISpex endpoint reflects new controllers

---

## Day 2 — Tracks E + F: CodexLocal + GeminiLocal

**Depends on:** Track C (ClaudeLocal pattern).

### CodexLocal

Binary: `codex` (OpenAI's open-source Codex CLI — /tmp/competitor-research/paperclip/packages/adapters/codex-local/ is the reference).
Stream format: OpenAI-style with tool-calling extensions. Parser module handles the differences from Claude's stream-json.

### GeminiLocal

Binary: `gemini`.
Stream format: Gemini CLI stream format (verify via Paperclip's gemini-local if present, else Google docs).

### Pattern Reuse

Both adapters follow the ClaudeLocal scaffold:
1. `Canopy.Runtimes.<Adapter>` module (behaviour callbacks)
2. `Canopy.Runtimes.<Adapter>.Parser` (stream → TranscriptEntry)
3. `Canopy.Runtimes.<Adapter>.Runner` GenServer (supervised)
4. Fake binary fixture for tests

Common code should be extracted into `Canopy.Runtimes.Subprocess` helper module after the first adapter ships — refactor, not upfront design.

### Exit criteria

Same as ClaudeLocal: full execute → stream → persist → finalize path. Contract tests green. Each adapter registers on Canopy.Application boot.

---

## Day 3 — Agent Seeder + Detection Sync + Type Gen

### Track G: `mix canopy.seed.agents`

Mix task that:
1. Scans `priv/agents/**/*.md`
2. Parses frontmatter
3. Maps `adapter:` → `runtime_type` per table above
4. Upserts into `agents` table (by slug — category_slug becomes unique composite)
5. Reports count ported + warnings for unmappable adapters

### Track H: Runtime detection

Two halves:
- **Rust side (Tauri command)**: `runtime_detect` scans `$PATH` for `claude`, `codex`, `gemini`, etc. Returns `Vec<DetectedBinary { slug, path, version }>`
- **Elixir side**: `Canopy.Runtimes.sync_from_detection/1` takes that list, upserts into `runtimes` table, sets `installed = true`, updates `version` + `binary_path`

Trigger: desktop calls `runtime_detect` on boot, POSTs result to `/api/v1/runtimes/detect` (new endpoint on RuntimesController).

### Track I: OpenAPI → TypeScript types

```bash
# backend
mix canopy.gen.openapi > ../packages/types/src/api.ts
```

Uses `openapi-typescript` inside the Mix task (or shell-out). Generated file is ONE `api.ts` with all endpoint request/response types as a discriminated union. `@canopyai/desktop` imports from `@canopyai/types`.

---

## Day 4 — Audit + Report

Re-run Day 1 audit checklist (`06-audit.md`) with Week 1 additions:
- Schema file size check (≤ 120 LOC per schema)
- Adapter file size (≤ 250 LOC, the justified exception)
- Controller size (≤ 150 LOC)
- Test count growth (from 4 → expected ~40+ by end of Week 1)
- Migration count (expect 8–12 new migrations)
- `mix credo --strict`, `mix dialyzer` clean
- Full end-to-end CLI-driven demo: spawn real Claude, get transcript, done

Write `docs/09-week1-report.md` with same structure as `07-day1-report.md`.

---

## Sequencing Guarantees

1. **No agent works on the same files as another agent.** Ownership is declared in each prompt.
2. **Schemas land BEFORE controllers use them** — controllers are Day 2, schemas are Day 1.
3. **Pattern gets established by ClaudeLocal BEFORE CodexLocal/GeminiLocal** — copycats can then be simpler.
4. **Agent seeder depends on schemas being live** — Day 3 is correct sequencing.
5. **TS type generation is last** — everything upstream must have OpenAPISpex schemas first.

---

## Open Questions (non-blocking)

- **How do we represent "no binary found" on Runtime schema?** Currently: `installed = false`, `version = nil`, `binary_path = nil`. Alternative: separate `runtime_detections` table for historical detection runs. Day 4 decision.
- **SSE replay behaviour:** when user subscribes to a finished session's events, do we stream the full history then close, or require `GET /messages` for history + `GET /events?live_only=true` for live? Recommend: unified replay-then-live with `?from=<sequence>` param.
- **Skills injection on resume:** Paperclip skips `--append-system-prompt-file` on resume. Do we also skip? Default YES (matches Paperclip), configurable per-runtime.
- **Agent library categories stay as 19?** Legacy shipped 19 categories. We can merge/split later when UI taxonomy is built (Week 4 agent library screen).

---

## Status Right Now

- Track A: ✅ DONE (port complete, 381 files, 1 rejection logged)
- Track B: ✅ DONE (132 tests passing, 6 migrations, 28 files, 2,151 LOC)
- Track C: ✅ DONE (61 new tests, 4 files, fake_claude.sh fixture verified)
- Track C' (refactor pass): 🟡 in flight — splitting `claude_local.ex` (483 LOC) + `parser.ex` (337 LOC) into single-responsibility sub-modules to comply with ≤150 LOC rule. No behavior change, 132 tests must stay green.

## Open Issues Pending Decision

### Dev DB collision (flagged by Track B)

`mix ecto.migrate` on `canopy_dev` fails with "duplicate table" — canopy-legacy previously used the same database name. Test DB works fine.

**Options:**
- **A.** `mix ecto.drop && mix ecto.create && mix ecto.migrate` — destructive, but `canopy_dev` should be empty (freshly created Day 1) or only have canopy-legacy tables we no longer need.
- **B.** Rename v2 database to `canopy_v2_dev` in `config/dev.exs` — non-destructive, but leaves a stale data island.

Recommendation: A. Awaiting approval before executing.

### Ownership crossover (flagged by Track B)

Schemas agent made 4 surgical edits inside ClaudeLocal agent's scope (`@type t`, `_arg` renames, `length > 0` credo fix, mix format) to pass its own exit criteria. These are cosmetic. ClaudeLocal agent did not overwrite them. Acceptable but noted for future parallelism planning — consider a lockfile or sequencing constraint in Week 2.

## Day 2 Trigger

Fires automatically when refactor-pass (Track C') returns green. Tracks D/E/F dispatch in parallel:

- **D. Controllers + SSE** — RuntimesController + SessionsController with `/events` SSE stream
- **E. CodexLocal adapter** — copy pattern from refactored ClaudeLocal (sub-modules)
- **F. GeminiLocal adapter** — same

Exit criterion unchanged: POST `/api/v1/sessions` → spawns subprocess → streams TranscriptEntry via SSE → persists to DB → returns cost + status.
