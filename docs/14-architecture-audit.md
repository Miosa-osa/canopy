> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Canopy v2 — Architecture Audit

**Date:** 2026-04-18
**Scope:** Full-system plumbing audit across 9 parallel analysis streams
**Commit:** `80acf10` (Week 3 sign-off)
**Backend LOC:** ~12k Elixir · **Desktop LOC:** ~15k TS/Svelte · **Rust:** ~1.5k

---

## 0. TL;DR — The 7 Findings That Matter

| # | Finding | Severity | Location |
|---|---------|----------|----------|
| 1 | **`Sessions.create/1` bypasses `Governance.evaluate/1` AND `Budgets.check/3`** — both modules complete, tested, documented, UNWIRED | CRIT | `sessions.ex:33` |
| 2 | **Rate limiter fully implemented but never plugged into `:api` pipeline** — zero throttle on any endpoint | CRIT | `router.ex:25-38` vs `plugs/rate_limiter.ex` |
| 3 | **Markdown renderer accepts `javascript:` hrefs verbatim** → LLM-output → click → `invoke('pty_spawn')` → shell RCE in Tauri WebView | CRIT | `utils/markdown.ts:31-35` |
| 4 | **Adapter subprocess crash leaves ghost `running` sessions forever** — no `Sessions.update_status(:failed)` on exit, SSE `done_entry?` never fires on `error` kind | HIGH | `process_runner.ex:131-138`, `session_events_controller.ex:199-201` |
| 5 | **Type contract divergence** — generated `packages/types/src/api.ts` has ZERO imports; hand-written `$lib/domain/*/types.ts` contains fields (`agentName`, `runtimeName`, `durationMs`) that don't exist on backend → `undefined` at runtime, no type error, no test failure | HIGH | `domain/sessions/types.ts:44-54` |
| 6 | **Missing compound index on `sessions(agent_slug, workspace_slug, status, inserted_at DESC)`** — `Resume.find_resumable/4` seq-scans NOW; at 100x scale = catastrophic | HIGH | `resume.ex:56-66` + missing migration |
| 7 | **Vault AES-256-GCM key = raw SHA-256(SECRET_KEY_BASE ⨁ suffix), no KDF, no salt, no iterations** — with committed dev key, all dev vault ciphertext pre-computable | HIGH | `vault/crypto.ex:73-76` + `dev.exs:19` |

**One move in next 4 weeks that most improves posture:** wire governance + budget gates into `Sessions.create/1` (~2h), plug rate limiter (1 line), filter markdown href schemes (~15min). These three fixes close 3 of the 7 CRITs, take less than a day, and require no architectural changes.

---

## 1. Entry Topology (71 entry points)

```
┌─────────────────────────────────────────────────────────────┐
│                   EXTERNAL ATTACK SURFACE                    │
├─────────────────────────────────────────────────────────────┤
│ HTTP (46 routes, :api pipeline, port 9190)                  │
│   └─ ZERO auth · ZERO rate limit active · 12 RISK:HIGH      │
│ SSE (1 stream /sessions/:id/events) — 25s keepalive DB poll │
│ Tauri IPC (9 commands) — webview → Rust, NO allowlist       │
│   └─ pty_spawn takes arbitrary command+cwd+env              │
│   └─ vault_get takes caller-supplied service name           │
│ MCP stdio (5 JSON-RPC methods via mix canopy.mcp)           │
│   └─ NO auth on initialize · tool arguments NOT schema'd    │
│ Global keyboard shortcuts (8) — ⌘K, ⌘⇧W, ⌘1-5, ⌘,          │
│ First-run redirect — /onboarding if installedCount=0        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    INTERNAL MACHINERY                        │
├─────────────────────────────────────────────────────────────┤
│ Oban workers (2) — Heartbeat.Worker, Budgets.Snapshotter    │
│   └─ Heartbeat: self-rescheduling, NO circuit breaker       │
│   └─ Unique [period: 60] — dedupe window                    │
│ Oban cron (1 static entry — hourly budget snapshot)         │
│ Boot Task — Registrar.register_all_hired/0 at 500ms         │
│ Mix tasks (4) — gen.openapi, seed.agents, seed.skills, mcp  │
│ Phoenix.PubSub — 1 topic family "session:<id>"              │
└─────────────────────────────────────────────────────────────┘

Supervisor tree (Canopy.Application):
  Telemetry → Repo → DNSCluster → PubSub → Finch → Oban →
  Runtimes.RegistryServer → Tools.Registry → Sessions.Supervisor →
  TaskSupervisor → Endpoint
```

**12 RISK:HIGH entry points** (no auth + no rate limit + writes state):
`POST /sessions`, `POST /agents/:slug/hire`, `DELETE /agents/:slug/hire`, `PUT /agents/:slug/persona`, `PUT /workspaces/:slug/files/*path`, `DELETE /workspaces/:slug/files/*path`, `POST /workspaces/:slug/files/move`, `POST /governance/rules`, `POST /governance/approvals/:id/approve`, `POST /tools/:name/dispatch`, `pty_spawn` (Tauri), `tools/call` (MCP stdio).

---

## 2. Critical Data Flows (8 paths traced)

### Path 1 — Session Create → Adapter → SSE (THE hot path)
```
POST /sessions
  → Sessions.create/1 (sessions.ex:33)
  → maybe_inject_resume/1 → DB SELECT sessions (find_resumable, UNINDEXED)
  → Repo.insert (status="pending")
  → maybe_provision_miosa_sandbox/2 (Task.start, fire-and-forget)
  → adapter.execute/1 → DynamicSupervisor.start_child → Port.open subprocess
  → Sessions.update_status(:running)
  → 201 + sse_url

GET /sessions/:id/events (SSE)
  → Sessions.get + PubSub.subscribe "session:<id>"
  → send_chunked(200)
  → receive loop (25s heartbeat with DB poll)

ProcessRunner parse loop:
  → {port, {:data, data}} → line_buffer → Parser.parse_line
  → emit_entry/2 → PubSub.broadcast + Sessions.add_message (Repo.insert)
```
**Bottleneck:** `Port.open` subprocess spawn (cold claude startup ~2-5s).
**Side-effects per session:** 2 DB writes + N× message inserts + 1× OS process + N× PubSub broadcasts.

### Path 2 — Heartbeat Fire (self-rescheduling)
```
Oban dequeue (queue :heartbeats, concurrency=5)
  → Worker.perform/1 → Agents.get_by_slug → Sessions.create (Path 1)
  → schedule_next/1 → Registrar.schedule_next_job
  → Expression.next_at(utc_now) → Oban.insert(scheduled_at: next)
```
**Failure mode:** missed intervals are DROPPED not replayed (`registrar.ex:189` uses wall clock). No backfill. Invalid cron at runtime = chain terminates silently.

### Path 3/4 — Workspace file read/write
- Read: `resolve_safe` (traversal guard — solid for `..`, but **no `File.realpath/1`** so symlink-escape works on macOS) → `guard_readable` → `guard_size (10MB)` → `File.read` UTF-8 validate
- Write: same guard + `tmp + rename` atomic. **`.tmp` orphan on rename failure (no cleanup)**.

### Path 6/7 — Budget + Governance (DESIGNED, UNWIRED)
`Sessions.create/1` at `sessions.ex:33` does NOT call `Governance.evaluate/1` or `Budgets.check/3`. Both are fully implemented. Docstring at `governance.ex:22-35` explicitly says "the wiring agent adds this call." **It never did.** Enforcement is opt-in only via `POST /budgets/:id/check` — the primary session creation path bypasses all gates.

### Path 8 — MCP tool call (JSON-RPC over stdio)
ETS lookup O(1) → `apply(mod, fun, [args | extra])` → try/rescue → JSON-RPC response. `tools/list` and `tools/call` work; `resources/list` and `prompts/list` return empty (unpopulated).

---

## 3. Storage Topology — Hot / Warm / Cold

### HOT (in-process, sub-ms)
| Surface | Risk |
|---|---|
| `:canopy_runtimes_registry` ETS | None — bounded by adapter count |
| `:canopy_tools_registry` ETS | `list/1` does full `tab2list` scan — degrades linearly with tool count |
| Hammer ETS rate buckets (cleanup every 10min) | ETS owned by Backend process, NO heir — crash = `ArgumentError` on every request until supervisor restarts |
| `ProcessRunner.State.line_buffer` | **Unbounded until newline arrives** — subprocess printing without `\n` accumulates heap |
| PTY `Arc<Mutex<HashMap>>` (Rust) | Global mutex on full registry — concurrent `pty_write` from 2 tabs serializes |

### WARM (Postgres, few-ms)
| Table | Current | 10k users | Hot query | Index coverage |
|---|---|---|---|---|
| `sessions` | ~300 rows | **3M rows** | resume lookup filter (agent_slug, workspace_slug, status, inserted_at) | **MISSING compound index** |
| `session_messages` | ~15k rows | **150M rows** / ~750GB | `WHERE session_id = ? AND sequence >= ?` | Unique(session_id,sequence) — covered; **NO partitioning** |
| `oban_jobs` | ~100 | thousands in-flight | Oban poll on state/queue/scheduled_at | Oban's own indexes; Pruner retention=60s default |
| `budget_spend_snapshots` | ~720 | **432M rows/year**, NEVER PRUNED | `(budget_id, snapshot_at)` range | `budget_id`, `(budget_id, snapshot_at)` — **NO TTL, NO partition** |
| `governance_audit_log` | ~100 | **15M rows/month** | `occurred_at DESC`, `session_id`, `event_type` | Single-col indexes only — **needs (session_id, occurred_at) compound** |
| `oban_jobs.args` JSONB | — | `fragment("?->>'agent_slug' = ?")` in Registrar.unregister | **NO GIN index** — full seq scan |

### COLD (filesystem, infrequent)
| Surface | Notes |
|---|---|
| `priv/agents/*.md` (336 files) | **Read per-heartbeat inside Oban worker at concurrency=5** — cold FS stalls the queue |
| `priv/workspace_templates/` | `File.cp_r` entire tree on workspace create — blocks calling process |
| User workspace `root_path` | User-provided, NO size cap, NO quota — agent tools can fill disk |
| `credentials` table (vault) | AES-256-GCM ciphertext, ~5 rows bounded |
| macOS Keychain (keyring crate) | Per-`(service, account)`, no Canopy prefix enforcement |
| `localStorage` | 2 keys: `canopy.currentWorkspaceSlug`, theme |

**5 scaling cliffs ranked:**
1. `session_messages` — crosses 100M rows at ~6,700 users (750GB unpartitioned)
2. `budget_spend_snapshots` — 432M rows/year at 10k users, no TTL
3. `sessions.agent_slug` missing index — seq scan on every budget preflight
4. `governance_audit_log` — 15M rows/month unbounded
5. Persona `File.read` inside Oban heartbeat worker — blocks queue under slow FS

---

## 4. Dependency Mesh — Strict DAG, 3 Smells

**Clean graph. Zero cycles.** `Canopy.Repo` is the expected hotspot — every context module hits it.

### External dependencies by blast radius
1. **Claude/Codex/Gemini CLIs** — stream-json contract controlled by Anthropic/OpenAI/Google. Zero influence. Adapter isolation is one-file, but protocol changes = adapter rewrite.
2. **Postgres** — 15+ migrations, pgvector, JSONB, UUIDs, `fragment/2`. Switch cost: weeks-months.
3. **Oban** — self-rescheduling pattern is coupled to Oban's state machine. Swap cost: days.
4. **Tauri 2 + portable-pty + keyring** — PTY lifecycle owned by Rust sidecar. Tauri IPC contract is not portable.
5. **Svelte 5 runes + TanStack Query** — writable-untrack-$effect bridge documented as brittle, Svelte 5 pre-5.56 specific.
6. **MIOSA external API** — Roberto's own separate codebase; gracefully degrades via `configured?()==false`.
7. **clawhub.ai / skills.sh** — NO auth, NO content validation, returns `{:ok, []}` on failure (graceful).
8. **LLM pricing** — existential. 10x pricing event breaks economic model immediately.

### Bad-smell findings
1. **4 controllers bypass context modules** — `AgentsController:176` (raw Oban.Job query), `SandboxesController:41+126`, `BudgetsController:167-173`, `GovernanceController:232-239` all have `alias Canopy.Repo` + direct queries. Business logic leaked to HTTP layer.
2. **Cross-context schema leakage** — `Canopy.Budgets.ex:36` imports `Canopy.Sessions.Session` schema to SUM `cost_usd`. Should call `Canopy.Sessions.sum_cost/2` (doesn't exist).
3. **Raw Ecto struct → `json/2`** in 5 controller actions (`budgets_controller.ex:101,145`; `governance_controller.ex:159,183`; `skills_controller.ex:79`). Bypasses OpenAPISpex response schemas. Any Ecto field rename silently breaks API contract.

### External HTTP surface
- **MIOSA** — `Req.post/get/delete`, Bearer token auth, 2 retries × 30s timeout, graceful skip path
- **ClawHub** (`clawhub.ai/api/v1/skills`) — NO auth, 10s timeout, `{:ok, []}` on failure
- **Skills.sh** (same) — NO auth, 10s timeout
- **Claude/Codex/Gemini** — via subprocess stdin/stdout, not HTTP

---

## 5. Failure Propagation (15 modes)

### 3 existential risks
1. **Oban cron parse error at boot (#13)** — 100% blast radius. Cron plugin fails → Oban supervisor fails → app-level supervisor fails after max_restarts → BEAM exits. No partial start. Redeploy required.
2. **Postgres unavailable (#1)** — 95% blast. Ecto checkout timeouts. Oban stops polling. New SSE fails. Running sessions continue but transcripts LOST (ProcessRunner try/rescue logs but doesn't persist).
3. **Adapter crash ghost session (#4)** — 30% per-session blast, **compounding**. `process_runner.ex:131-138` doesn't call `Sessions.update_status(:failed)`. `session_events_controller.ex:199-201` `done_entry?` returns false for `"error"` kind. Session stuck `running` FOREVER, SSE loop blocks indefinitely. Observer-invisible.

### Unhandled paths
- `vault.ex:120` — decryption failure silently mapped to `:not_found`, **ZERO log**. Key rotation = silent 70% blast.
- `tree.ex:66` — `File.stat!` (bang) raises on unreadable paths, no rescue → 500
- `fallback_controller.ex:78` — `:enospc` hits generic 500, should be 507
- Heartbeat chain with invalid cron at runtime → logs warning, chain terminates silently, NO metric

### Observability gaps (CRITICAL severity)
- **Zero log** on vault decryption failure
- NO DB pool saturation metric
- NO Oban queue depth alert
- Ghost `running` sessions invisible without DB inspection

---

## 6. Scale Breaking Points

### Required BEFORE 10x
Add: `CREATE INDEX CONCURRENTLY idx_sessions_resume ON sessions (agent_slug, workspace_slug, status, inserted_at DESC) WHERE status = 'completed';`

### Breaks at 100x
1. **Oban heartbeats concurrency=5** — 100 jobs/min arriving, ~12/min clearing → queue diverges permanently
2. **Postgres pool=10** — 300 concurrent sessions needs ~100 connections → `DBConnection.ConnectionError` under load
3. **MIOSA provisioning** — 300× `Task.start` fire-and-forget with 3 retries × 30s → Finch pool exhaustion, no backpressure
4. **Adapter subprocess RAM** — 300 sessions × 100MB = **30GB RAM floor** on single host
5. **SSE keepalive** — 300 connections × `Sessions.get/1` every 25s = 12 DB queries/sec sustained just from keepalive
6. **Governance audit** — O(rules) INSERT per session create, no batching
7. **Oban `unique: [period:60]`** — JSONB fragment query on `args->>'agent_slug'` with NO GIN index

### Breaks at 1000x (architectural redesign required)
1. **Subprocess memory** — 3000 sessions × 100MB = **300GB RAM IMPOSSIBLE on single node** → requires MIOSA Firecracker execution pool or equivalent
2. **Oban heartbeats 60k/hour** (16.7/sec) — must shard across nodes
3. **sessions table** — 3.65M rows/year, compound index helps but planner overhead grows → partition by `inserted_at` monthly
4. **Single Postgres node** — no pool tuning serves 3000 concurrent sessions → PgBouncer + read replicas mandatory
5. **Snapshotter sequential aggregation** — 3000 queries/hour serial → batch GROUP BY

### Cost projection
- 10x: ~$50/month
- 100x: ~$460/month
- 1000x: ~$7,000-12,000/month (dominated by subprocess compute pools)

---

## 7. Entropy — Top 10 Debt Hotspots

| # | Finding | File | Severity | Accumulation | Fix (h) |
|---|---------|------|----------|--------------|---------|
| 1 | Type contract divergence — parallel hand-written + generated systems, fields `agentName/runtimeName/durationMs` undefined at runtime | `domain/sessions/types.ts:44-54` | CRIT | **Compounding** | 6 |
| 2 | `Governance.evaluate/1` never called from `Sessions.create/1` — inert feature | `sessions.ex:33` + `governance.ex:22-35` | CRIT | Stable | 2 |
| 3 | 5 controllers pass raw Ecto structs to `json/2` | `budgets_controller.ex:101,145`; `governance_controller.ex:159,183`; `skills_controller.ex:79` | HIGH | Compounding | 4 |
| 4 | `dev-placeholder-key` as MIOSA default, not enforced in `runtime.exs` | `config/config.exs:64` | HIGH | Stable | 1 |
| 5 | Zero route-level Vitest coverage across all 500+ LOC Svelte pages | `desktop/src/routes/` | HIGH | Growing | 8 |
| 6 | Binary module triplication — 94 LOC × 3 adapters identical | `runtimes/{claude,codex,gemini}_local/binary.ex` | MED | Growing | 3 |
| 7 | `put_if/4` + `parse_int/2` copied into 17 controller defps | `canopy_web/controllers/` | MED | Compounding | 2 |
| 8 | Raw Repo queries inside governance + budgets controllers | `governance_controller.ex:232-239`, `budgets_controller.ex:167-173` | MED | Compounding | 2 |
| 9 | 11-file writable-store TanStack bridge boilerplate, no abstraction | `routes/**/+page.svelte` | MED | Compounding | 4 |
| 10 | `FileViewer.svelte` at 677 LOC, 4 distinct responsibilities | `patterns/FileViewer.svelte` | MED | Growing | 6 |

**The ONE fundamental compounding decision:** the type contract has two parallel systems (generated + hand-written) with no enforcement that they agree. Every new endpoint requires updating both. The generated file has zero imports. The hand-written file has fields that don't exist on the backend. This is architectural gap, not bug density.

---

## 8. Control Point Map

### LEVERAGE (what we own)
| Asset | Moat | Copy-ability |
|---|---|---|
| `Canopy.Runtimes.Adapter` behaviour | Medium — defines "what it means to be a runtime in Canopy" | Medium |
| Workspace Protocol v1 (`packages/protocol/workspace-protocol.md`) | Deep once users invest | Medium |
| `TranscriptEntry` wire format | Medium — session history shaped to it | Easy (struct spec) |
| MCP tool surface (`CanopyMCP`) | Shallow today (resources/prompts empty) | Easy |
| 336-agent persona corpus | Shallow — curated from public sources, scrapeable | Easy |
| Session transcripts + spend snapshots | Deep, growing — usage intelligence layer | Hard (local data) |

### VULNERABILITY (what we depend on)
- **Strategic:** Claude/Codex/Gemini CLI protocols (zero influence); Postgres + Ecto (months to migrate); Svelte 5 + Tauri 2 (200-400h to migrate — the least-reversible decision); LLM token pricing (existential)
- **Tactical:** Oban (days); Bandit/Phoenix (hours); OpenAPISpex (medium)
- **Commodity:** Hammer, clawhub.ai, skills.sh (near-zero switch cost; already graceful-degraded)

### INSERT (where control can be inserted NOW)
1. **Tool dispatch** (`Tools.Registry.dispatch/2`) — single chokepoint, ready for telemetry/gate/meter/replay
2. **Session mediation** (`Sessions.create/1`) — governance gate DESIGNED not wired
3. **Budget gate** (`Budgets.check/3`) — 3-tier enforcement DESIGNED not wired
4. **MCP resources/prompts** — surfaces exist, empty lists. Populate = Canopy becomes tool *provider* not just consumer
5. **Workspace Protocol publication** — first-mover advantage if published as open standard before competitors ship theirs

### LOCK-IN ranked by migration hours
1. Svelte 5 + TanStack Query → React: **200-400h** (least reversible)
2. Tauri 2 + portable-pty + keyring → Electron: **100-200h**
3. Postgres → any other DB: **80-160h** (pgvector, JSONB, UUID, fragment/2)
4. Ecto → Postgrex raw: **60-120h**
5. Oban → static crontab + alternative queue: **30-60h**
6. Phoenix → Plug-only: **20-40h**

### Strategic answers
- **If Anthropic ships "Claude Workspaces"** → multi-runtime management, governance, MIOSA, Workspace Protocol all survive. Claude-only positioning dies.
- **If OpenAI ships agent OS** → runtime-management layer commoditized. Remaining moats: governance+budget, published Workspace Protocol, BEAM reliability.
- **If MIOSA pivots** → Canopy degrades gracefully. `miosa.configured?() == false` path already wired.
- **If Roberto exits** → acquirers: DevTools (JetBrains/Atlassian/GitHub) for Workspace Protocol + adapter pattern; Enterprise AI for governance + compliance surface. Session data does NOT transfer (local).
- **Least reversible:** Svelte 5 + Tauri 2 + Rust PTY stack. 200-400h migration cost. Probably correct but locked.

---

## 9. Security — Attack Surface

### 5 findings that matter TODAY (local desktop)
1. **`javascript:` URI in markdown renderer** → LLM/README click → `invoke('pty_spawn',{command:'bash'})` → shell RCE. Fix: URL scheme allowlist. **15 min.**
2. **Governance + budget gates unwired** → any LLM-triggered session bypasses all policy. Fix: 2 function calls in `Sessions.create/1`. **2 hours.**
3. **Rate limiter dead code** → no throttle anywhere. Fix: 1 line in `router.ex :api` pipeline. **Trivial.**
4. **`read_file` MCP tool has NO workspace root scope** → unauthenticated caller reads `/Users/rhl/.ssh/id_rsa`. Fix: require `workspace_slug` arg. **1 hour.**
5. **Vault AES key = raw SHA-256(SECRET_KEY_BASE)** with committed dev key → DB read = all dev API keys decryptable offline. Fix: swap to HKDF via `:crypto.hkdf_extract/3`. **1 hour.**

### 3 findings that matter IF exposed beyond localhost
1. **`runtime.exs:74` binds `{0,0,0,0,0,0,0,0}` + zero auth** → network peer gets full unauth API. Need firewall rule or bind to `127.0.0.1`.
2. **Skills import = system-prompt poisoning vector** → unauthenticated `POST /skills/import` persists content injected into every future agent system prompt.
3. **CORS allows `localhost:5280`** with `allow_credentials:true` → DNS rebinding vector on exposed instance.

### Other findings
- `pty_spawn` Tauri IPC accepts arbitrary `command` — only boundary is WebView CSP (`style-src 'unsafe-inline'`)
- `shell.open: true` in tauri.conf.json with no scheme restriction — `file://` or `javascript:` URIs reach OS handler
- `vault_get` accepts caller-supplied `service` name → WebView-side attacker reads other app credentials (subject to macOS TCC)
- Adversarial LLM output: tool_call args with pasted API keys land in Postgres + SSE + transcript — NO redaction layer
- Governance `prompt_regex` compiled per-evaluation from DB string → ReDoS risk via unauth `POST /governance/rules`
- Symlink escape in `resolve_safe` — Elixir guard doesn't call `File.realpath/1` before prefix check. macOS user-created symlinks escape workspace root.

---

## 10. Priority Matrix — What To Do

### Tier 0 — THIS WEEK (less than 1 day total, closes 4 critical findings)
| # | Action | File | Effort | Closes |
|---|--------|------|--------|--------|
| 1 | Add URL scheme allowlist to `inlineRender` (http/https only) | `utils/markdown.ts:31-35` | 15min | RCE chain |
| 2 | Plug `RateLimiter` into `:api` pipeline | `router.ex:26` | 1 line | throttle gap |
| 3 | Wire `Governance.evaluate/1` + `Budgets.check/3` into `Sessions.create/1` | `sessions.ex:33` | 2h | gate bypass |
| 4 | Add `Sessions.update_status(session_id, "failed")` to `ProcessRunner.on_exit` error path | `process_runner.ex:131-138` | 30min | ghost sessions |
| 5 | Add `"error"`/`"session_expired"` to `done_entry?` terminal set | `session_events_controller.ex:199-201` | 15min | SSE blocks |
| 6 | Add compound index on sessions | migration | 30min | seq-scan NOW |

### Tier 1 — WEEK 4 (Shell Polish week — deferrals fit here)
| Action | Effort | Value |
|--------|--------|-------|
| Swap vault key derivation: SHA-256 → HKDF via `:crypto.hkdf_extract/3` | 1h | Crypto hygiene |
| Add `workspace_slug` requirement to `read_file`/`write_file` tool built-ins | 2h | MCP scope |
| Raise `runtime.exs` on missing MIOSA_API_KEY (remove `dev-placeholder-key` fallback) | 30min | Security hygiene |
| Add `Logger.warning` on vault decryption failure | 15min | Observability |
| Add `File.realpath/1` to `resolve_safe` symlink check | 30min | Path traversal |
| Replace `File.stat!` with `File.stat/1` in `Tree.build_node` (no bang on untrusted paths) | 30min | Crash hygiene |
| Fix type contract — rename frontend fields OR add transformation in `client.ts` | 6h | Type safety |
| Populate MCP `resources/list` + `prompts/list` with workspace files + agent personas | 1-2 days | Control surface |

### Tier 2 — WEEK 5-8 (scaling preparation before 10x/100x)
| Action | Target | Effort |
|--------|--------|--------|
| Raise Oban `:heartbeats` concurrency 5 → 50 | 100x | 1 line config |
| Bump Postgres `pool_size` 10 → 50-100 + PgBouncer | 100x | config |
| Add GIN index on `oban_jobs.args` | 100x | migration |
| Cache governance rules in ETS (GenServer keeper) | 100x | 4h |
| Move persona file read from heartbeat worker → DB column | queue unblocking | 3h |
| Extract `Canopy.Runtimes.Binary` shared module (eliminate triplication) | code hygiene | 3h |
| Extract `CanopyWeb.ControllerHelpers` for `put_if/parse_int` | code hygiene | 2h |
| Move `Repo.all` queries out of 4 controllers into context modules | code hygiene | 2h |
| Add `beforeNavigate` dirty guards + transactional write for file ops | reliability | 2h |

### Tier 3 — WEEK 13+ (architectural redesigns before 1000x)
- Decouple subprocess execution from Phoenix process space (MIOSA Firecracker pool) — **the 300GB RAM physical ceiling**
- Partition `sessions` + `session_messages` + `governance_audit_log` + `budget_spend_snapshots` by month
- Shard Oban heartbeat queue with node affinity
- Replace `writable+untrack+$effect` bridge with TanStack Query runes-native adapter (when library ships)
- Publish Workspace Protocol as versioned open standard (separate repo/site)
- Canopy-owned skill registry replacing `clawhub.ai` dependency

---

## 11. Convergence — Findings Confirmed By Multiple Streams

These appeared in 3+ of the 9 analysis streams and are the highest-confidence action items:

1. **`Sessions.create/1` bypasses governance + budget gates** — data flow, entropy, control, security all confirm
2. **Rate limiter built but not plugged** — entry points, failure, security all confirm
3. **Type contract divergence (generated vs hand-written)** — entropy, control confirm
4. **Adapter crash ghost sessions** — failure, entropy confirm
5. **Missing compound index on sessions** — storage, scale confirm
6. **Vault decryption silent `:not_found`** — failure, security confirm
7. **4 controllers bypass context modules** — dependency mesh, entropy confirm
8. **`Canopy.Budgets` imports `Sessions.Session` schema directly** — dependency mesh, entropy confirm
9. **Heartbeat chain has no circuit breaker / silent failure** — entry points, failure confirm
10. **`session_messages` scaling cliff unpartitioned** — storage, scale confirm

---

## 12. Topology Verdict

**Structurally:** Clean DAG, no cycles, well-ordered supervisor tree, domain/context separation is mostly sound. Per-responsibility file discipline holds except in 4 controllers and 2 Svelte files (FileViewer, TranscriptView).

**Functionally:** Week 0-3 velocity has been high. Backend tests: 1026 / 0. Frontend tests: 208 / 0. Rust: 11 / 0. The mesh is solid on happy paths.

**Gap class:** The critical gaps are NOT bugs — they are **unwired wiring**. Governance evaluator exists, is tested, is documented as "should be called," is not called. Rate limiter exists, is tested, is documented as "add to pipeline," is not in pipeline. The type generator exists, produces output, has zero imports. The pattern: *machinery-built-not-plugged*.

**At current scale (1 user):** risk surface is real but not exploitable without local access. Tauri's single-user model absorbs most of it.

**At 10x (cloud-hosted):** the unplugged rate limiter + unauthenticated endpoints + wide IPv6 bind + shell RCE chain via markdown link + read_file unscoped = **multiple paths to unauthenticated RCE**. Cannot ship to cloud without Tier 0.

**At 100x:** Oban heartbeat queue divergence + 30GB subprocess RAM floor + missing indexes = backend falls over without Tier 2.

**At 1000x:** requires architectural split (subprocess execution out of Phoenix) — there is no amount of tuning that serves 3000 concurrent agent subprocesses from one node.

---

## 13. Single Recommended Action

**Execute Tier 0 this week.** ~4 hours total. Closes the governance bypass, the RCE chain, the rate-limit gap, the ghost session leak, and the resume seq-scan. These are not new features — they are finishing touches on work already done. The paydown ratio (critical risk reduction ÷ engineering hours) exceeds any new-feature investment in the Week 2-20 roadmap.

After Tier 0, Week 4 "Shell Polish" naturally absorbs Tier 1. Week 5+ cockpit work can proceed with the security floor raised.
