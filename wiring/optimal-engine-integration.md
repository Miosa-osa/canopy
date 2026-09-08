> SUPERSEDED: This historical proposal is not an executable integration contract.
> Current authority: [Workspace OptimalEngine](../docs/24-workspace-engine.md).
> Machine classification: `agent-authority.json`, `superseded_by: workspace-engine`.
> The proposed in-process dependency and module mapping below are not claims of shipped behavior.

# Optimal Engine → Canopy Integration Plan

## Engine Overview

`app: :optimal_engine`, version `0.1.0`, Elixir `~> 1.17`.

A signal-native context storage engine: SQLite + FTS5 + tiered L0/L1/L2 loading +
OWL 2 RL reasoning. Exposes a Plug/Cowboy HTTP JSON API on its own port.

Key modules:

| Module | What It Does |
|--------|-------------|
| `OptimalEngine.Signal` | Core data model — every context is a Signal with S=(M,G,T,F,W) dimensions |
| `OptimalEngine.Retrieval` | Wiki-first RAG → hybrid FTS5/vector/graph fallback. Single `ask/2` entry point |
| `OptimalEngine.Memory` | Key/value episodic memory with tag-based search (ETS-backed) |
| `OptimalEngine.Knowledge` | SPARQL + OWL 2 RL triple store, namespace-scoped per tenant/agent |
| `OptimalEngine.Graph` | Typed directed edge graph (mentioned_in, lives_in, cross_ref, supersedes) |
| `OptimalEngine.Wiki` | LLM-curated Tier 3 wiki pages with citation integrity and audience-aware rendering |
| `OptimalEngine.Workspace` | Org topology: nodes, members, skills, principal↔skill grants |
| `OptimalEngine.Signal.PubSub` | CloudEvents pub/sub broker for signal causality tracking |
| `OptimalEngine.API.Router` | HTTP JSON API: `/api/graph`, `/api/search`, `/api/l0`, `/api/health` |

Supervision tree: one_for_one flat tree — Store (SQLite GenServer), Pipeline.Router,
Pipeline.Indexer, Retrieval.Search, Retrieval.L0Cache, Pipeline.Intake, Memory subsystem,
Knowledge registry, Signal.PubSub + Journal, optional HTTP endpoint.

## Integration Strategy

**Chosen path: Shell bridge (current) + in-process OTP for next phase.**

Canopy already has a working bridge at `Canopy.Workspaces.Engine` — it shells out to
`mix optimal.*` inside a workspace's `engine/` directory, guarded by a `.canopy/engine.yaml`
allowlist. The `Canopy.Tools.WorkspaceEngine` MCP tool exposes `engine_health`,
`engine_commands`, and `engine_run` to agents.

This is the right architecture for user-owned workspaces (each workspace ships its own
engine). It is NOT the right path for Canopy-level features (search, memory, knowledge
graph) that need to be fast, always-on, and shared across the platform.

**Two integration tiers:**

1. **Tier 1 (now)**: Extend the shell bridge — add `optimal.search`, `optimal.ingest`,
   `optimal.l0`, `optimal.assemble` to the manifest allowlist. No new code needed in
   Canopy backend; workspace owners configure `engine.yaml`.

2. **Tier 2 (next)**: Add `optimal_engine` as a direct Mix dependency in `canopy/backend/mix.exs`
   for platform-level features. Run the engine's OTP supervision tree as a child of
   Canopy's supervisor. Create a `Canopy.Engine.Bridge` module that wraps the engine
   facades behind Canopy's tenant/workspace context.

Tier 2 is the right endgame: no subprocess overhead, shared BEAM process space,
direct message passing, telemetry integration.

## Module Mapping

| Engine Module | Canopy Module | Integration Point |
|--------------|--------------|-------------------|
| `OptimalEngine.Retrieval` | `Canopy.Engine.Bridge` (new) | `ask/2` → workspace knowledge search |
| `OptimalEngine.Memory` | `Canopy.Engine.Bridge` (new) | `store/recall/search` → agent session memory |
| `OptimalEngine.Knowledge` | `Canopy.Engine.Bridge` (new) | `open/assert/sparql` → per-workspace KB |
| `OptimalEngine.Graph` | `Canopy.Engine.Bridge` (new) | `create_edges_for_context/1` → signal routing |
| `OptimalEngine.Wiki` | `Canopy.Engine.Bridge` (new) | `ask/2` wiki-first → workspace docs |
| `OptimalEngine.Workspace` | `Canopy.Workspaces.*` (existing) | Merge node/member/skill model |
| `OptimalEngine.API.Router` | `CanopyWeb.Router` | Mount under `/engine` or proxy from Phoenix |
| `OptimalEngine.Signal` | `Canopy.Signals.*` (new context) | Signal ingestion pipeline for workspace events |
| `OptimalEngine.Signal.PubSub` | `Phoenix.PubSub` (existing) | Bridge: publish engine signals to Phoenix PubSub |

## Step-by-Step Plan

### Phase 1 — Manifest Expansion (zero code, immediate)

1. Add standard `optimal.*` commands to workspace `engine.yaml` template:
   `optimal.search`, `optimal.ingest`, `optimal.l0`, `optimal.assemble`, `optimal.health`
2. Expose `workspace.engine_search` tool in `Canopy.Tools.WorkspaceEngine` — thin wrapper
   over the existing `run/3` path with `command: "search"`.

### Phase 2 — Direct Dependency (platform-level features)

3. Add to `canopy/backend/mix.exs` deps:
   ```elixir
   {:optimal_engine, path: "../../../engine", runtime: true}
   ```
   Pin to a local path first; extract to hex package when stable.

4. Add engine config in `config/config.exs`:
   ```elixir
   config :optimal_engine, :store,
     base_path: System.get_env("CANOPY_ENGINE_STORE_PATH", "priv/engine_stores"),
     pool_size: 5
   ```

5. Add engine children to `Canopy.Application` supervision tree (after `Canopy.Repo`):
   ```elixir
   OptimalEngine.Store,
   OptimalEngine.Pipeline.Router,
   OptimalEngine.Retrieval.Search,
   OptimalEngine.Retrieval.L0Cache,
   {Registry, keys: :unique, name: OptimalEngine.Knowledge.Registry},
   {Registry, keys: :unique, name: OptimalEngine.Memory.SessionRegistry},
   OptimalEngine.Memory.Store.ETS,
   OptimalEngine.Memory.Cortex,
   {OptimalEngine.Signal.PubSub, name: OptimalEngine.Signal.PubSub},
   {OptimalEngine.Signal.Journal, name: OptimalEngine.Signal.Journal}
   ```

### Phase 3 — Bridge Module

6. Create `lib/canopy/engine/bridge.ex` — thin facade that:
   - Scopes `OptimalEngine.Knowledge.open/2` calls by `workspace_id`
   - Delegates `Retrieval.ask/2`, `Memory.store/4`, `Memory.recall/2`, `Memory.search/2`
   - Translates `{:error, _}` tuples to Canopy error atoms
   - Emits Telemetry events tagged with `workspace_id`

7. Wire `Canopy.Engine.Bridge` into existing workspace contexts:
   - `Canopy.Workspaces` — on workspace create, open a scoped knowledge store
   - `Canopy.Agents` — pass workspace KB to agent context injection

### Phase 4 — API Exposure

8. Add Phoenix controller `CanopyWeb.EngineController` with actions:
   - `GET /api/workspaces/:slug/engine/search?q=` → `Bridge.search/2`
   - `POST /api/workspaces/:slug/engine/ingest` → `Pipeline.Intake.ingest/2`
   - `GET /api/workspaces/:slug/engine/graph` → proxy `OptimalEngine.API.Router`
   - `GET /api/workspaces/:slug/engine/health` → `OptimalEngine.Health`

9. Add OpenAPISpex schemas for all four endpoints (Canopy rule: OpenAPI before ship).

10. Add MCP tool `workspace.engine_search` with `mcp_exposed: true` so agents can
    search workspace knowledge natively without shelling out.

## What Gets Unlocked

- **Workspace knowledge bases**: every workspace gets a scoped triple store (Knowledge)
  + signal index (Store) + wiki layer (Wiki) — the full OptimalOS KB stack.
- **Agent memory**: agents can store/recall decisions, patterns, context across sessions
  via `Memory.store/recall`.
- **Semantic search**: `Retrieval.ask/2` gives agents wiki-first + FTS5/vector hybrid
  search over all workspace signals — replaces naive grep/file reads.
- **Signal graph**: all workspace events become graph edges, enabling synthesis
  opportunity detection (`Graph.triangles`) and hub analysis.
- **PubSub bridge**: engine signals fan out to Phoenix PubSub → LiveView + Channels
  can react to knowledge mutations in real time.
