# Canopy

> Open-source workspace protocol for AI agent systems.
> If Claude Code is the employee, Canopy is the office.

Canopy is a folder structure that turns any AI agent into a specialist. Point Claude,
Codex, Cursor, Gemini, or any agent at a Canopy workspace — it reads the
SYSTEM.md, discovers the skills, loads the agents, and starts working. No server.
No database. No lock-in. Just folders of markdown files.

It looks like a bunch of markdown — but underneath it has org charts, budgets,
governance, heartbeats, tiered context loading, knowledge graphs, and multi-agent
coordination.

**Manage AI systems, not prompts.**

| Step | What Happens |
|------|-------------|
| **01** Pick a workspace | `sales-engine/`, `dev-shop/`, `content-factory/`, `cognitive-os/`, or build your own |
| **02** Connect your agent | Claude Code, OSA, Cursor, Codex, Gemini, Aider, Windsurf, OpenClaw, or any agent |
| **03** Run | Agent reads SYSTEM.md, discovers skills and specialists, operates autonomously |

```bash
git clone https://github.com/Miosa-osa/canopy.git
cd canopy/operations/sales-engine

# Claude Code: reads SYSTEM.md automatically
# OSA: osa connect .
# Cursor: ./scripts/install.sh --tool cursor
# Any agent: read SYSTEM.md, run skills via shell
```

---

## Works With

| | | | | | | | |
|---|---|---|---|---|---|---|---|
| **Claude Code** | **Codex** | **Cursor** | **Gemini** | **OSA** | **OpenClaw** | **Aider** | **Windsurf** |

Plus OpenCode, HTTP endpoints, shell processes, and any agent that can read files.

**If it can read markdown, it's hired.**

---

## Canopy is right for you if

- You want to build autonomous AI companies, agencies, or workflows
- You coordinate multiple agents (Claude, Codex, Cursor, Gemini) toward a common goal
- You have 20 agent terminals open and lose track of what everyone is doing
- You want agents running on heartbeats 24/7, but still want to audit and override
- You want to build a second brain, knowledge system, or cognitive OS with AI
- You want to monitor costs and enforce budgets across agent teams
- You want pre-built workspaces you can download and run in 5 minutes
- You want a workspace protocol that isn't locked to one vendor's server

---

## What a Full Workspace Looks Like

Here's a complete B2B sales workspace — every file, every layer:

```
sales-engine/
│
│  ═══════════════════════════════════════════════════════
│  L0 — ALWAYS LOADED (~2K tokens total)
│  Agent reads these on boot. Identity, goals, routing.
│  ═══════════════════════════════════════════════════════
│
├── SYSTEM.md                      ← Entry point: identity, boot sequence, core loop,
│                                     skills list, agents list, routing table,
│                                     deal phases, handoff protocol, quality rules
│                                     (~120 lines — the brain transplant)
│
├── company.yaml                   ← Mission, monthly budget ($5K), governance rules,
│                                     org chart, goal hierarchy with evidence gates
│
│  ═══════════════════════════════════════════════════════
│  L1 — LOADED ON DEMAND (~2K tokens per item)
│  Agent discovers these from SYSTEM.md. Loads only the
│  specific agent or skill needed for the current task.
│  ═══════════════════════════════════════════════════════
│
├── agents/                        ← Specialist behavioral templates
│   ├── director.md                   Pipeline review, deal strategy, forecasting
│   ├── prospector.md                 Lead generation, ICP matching, outbound sequences
│   ├── closer.md                     Discovery calls, demos, negotiation, close
│   ├── researcher.md                 Market intel, competitive analysis, account research
│   └── copywriter.md                 Email sequences, proposals, case studies
│
├── skills/                        ← Executable slash commands
│   ├── prospect/SKILL.md            /prospect — find and qualify leads
│   ├── pipeline/SKILL.md            /pipeline — view pipeline status, forecasting
│   ├── qualify/SKILL.md             /qualify — run MEDDPICC qualification
│   ├── close-plan/SKILL.md          /close-plan — build deal close strategy
│   └── battlecard/SKILL.md          /battlecard — competitive intel for a deal
│
│  ═══════════════════════════════════════════════════════
│  L2 — DEEP CONTEXT (loaded for specific tasks)
│  Domain knowledge, workflows, handoff protocols.
│  ═══════════════════════════════════════════════════════
│
├── reference/                     ← Domain knowledge (playbooks, decision trees)
│   ├── icp.md                        Ideal customer profile, scoring rubric
│   ├── meddpicc.md                   Full qualification methodology
│   ├── objections.md                 20+ objections with response scripts
│   └── sequences.md                  Email templates with A/B variants
│
├── workflows/                     ← Multi-phase pipelines with gates
│   └── deal-cycle.md                 7 phases: Research → Outreach → Discovery →
│                                     Demo → Proposal → Negotiate → Close
│
├── handoffs/                      ← Structured agent-to-agent transitions
│   ├── standard.md                   Task clarity, constraints, expected genre
│   └── escalation.md                 When to escalate, who to, with what evidence
│
├── spec/                          ← Executable specifications
│   ├── PROCEDURES.md                 Action bindings with typed parameters
│   ├── WORKFLOW.md                   FSM: lead states, deal states, triggers
│   └── contracts/
│       └── workspace.spec.md         Self-validation and drift detection
│
│  ═══════════════════════════════════════════════════════
│  L3 — ENGINE (invisible to agent)
│  Skills call the engine. Zero tokens in context window.
│  ═══════════════════════════════════════════════════════
│
└── engine/                        ← Optional software underneath
    └── (CRM integration, email API, SQLite pipeline DB,
         lead scoring model, sequence automation...)
```

**~25 files. ~2,000 lines of markdown. That's a complete AI sales team.**

---

## Features

### Tiered Context Loading

The folder structure IS the context architecture. Layer 0 is what the agent reads
first. Each layer deeper costs more tokens and loads only when needed.

```
L0: SYSTEM.md + company.yaml        Always loaded (~2K tokens)
L1: agents/ + skills/                On-demand (~2K tokens per item)
L2: reference/ + workflows/ + spec/  Deep context (full content, via search)
L3: engine/                          Invisible (0 tokens, powers skills)
```

No other system does this. Traditional agent frameworks dump everything into the prompt.
File-based systems use ripgrep on flat directories. Canopy loads context in tiers —
abstracts first, summaries on-demand, full content only when needed. 96% cost reduction
vs traditional RAG.

### Heartbeat Protocol

Agents wake on schedule, check for work, execute, and delegate — autonomously.

```
Agent wakes (schedule, task assignment, or mention)
  → Retrieves identity and role
  → Checks pending approvals
  → Fetches assigned tasks (sorted by priority)
  → Atomic checkout (prevents double-work)
  → Executes task
  → Comments on progress (always, before exiting)
  → Delegates subtasks to reports
  → Sleeps until next heartbeat
```

See [`architecture/heartbeat.md`](architecture/heartbeat.md) for the full 9-step protocol.

### Multi-Runtime Adapter Registry

One orchestrator dispatches work to different runtimes based on task type:

```
/delegate "Write the API spec"    → Claude Code (deep reasoning)
/delegate "Refactor 50 files"     → Codex (bulk code changes)
/delegate "Analyze screenshots"   → Gemini (multimodal)
/delegate "Run test suite"        → Shell process
/delegate "Check production"      → HTTP webhook
```

Each runtime is a pluggable adapter behind a standard interface. New runtime?
Write one adapter. Register it. Done.

See [`architecture/adapters.md`](architecture/adapters.md).

### Budget Enforcement

Three tiers — visibility, soft alert, hard ceiling:

| Threshold | What Happens |
|-----------|-------------|
| **Always** | Dashboard shows spend per agent, task, project, goal |
| **80%** | Soft alert — agent warned to focus on critical tasks only |
| **100%** | Hard stop — auto-pause, approval required to resume |

Tracks tokens and dollars. Rollup at any level. Enforced at every execution
boundary — scheduler, manual invoke, task checkout.

See [`architecture/budgets.md`](architecture/budgets.md).

### Governance & Approval Gates

You operate as the board of directors:

- Agents can't hire new agents without your approval
- Strategy proposals require board review before execution
- Budget overrides require explicit authorization
- Every action logged in an immutable audit trail
- Approval states: pending → approved / rejected / revision requested

See [`architecture/governance.md`](architecture/governance.md).

### Task Coordination

Tasks ARE the communication protocol. No agent-to-agent messaging:

- **Delegation** = create child task assigned to a report
- **Status** = modify task fields
- **Escalation** = traverse parent chain up to orchestrator
- **Atomic checkout** = only one agent works on a task at a time (409 = move on)

Hierarchy: Initiatives → Projects → Milestones → Issues → Sub-issues.
Every task traces back to a company goal.

See [`architecture/tasks.md`](architecture/tasks.md).

### Session Persistence & Compaction

Agents resume context across heartbeats instead of starting fresh:

- Task-scoped sessions persist across invocations
- When context fills, generate handoff summary + start fresh
- Compaction policy: max runs, max tokens, max age
- Agent never loses progress — just compacts and continues

See [`architecture/sessions.md`](architecture/sessions.md).

### 6R Knowledge Pipeline

For knowledge workspaces (second brains, cognitive OS):

```
Record (capture) → Reduce (extract insights)
  → Reflect (discover connections) → Reweave (update older content)
    → Verify (quality gate) → Rethink (evolve the system)
```

Each phase can spawn a fresh subagent for clean context. Per-note task files
serve as inter-phase communication. Three depths: Deep, Standard, Quick.

See [`architecture/processing-pipeline.md`](architecture/processing-pipeline.md).

### Multi-Agent Team Coordination

Spawn teams of agents that coordinate via filesystem:

- **Inbox messaging** — file-based, atomic writes, consume or peek
- **Git worktree isolation** — each agent gets its own branch, no conflicts
- **Task dependencies** — auto-unblock when upstream completes
- **Team templates** — YAML/TOML archetypes for repeatable setups
- **Liveness detection** — dead agents auto-release locks

See [`architecture/team-coordination.md`](architecture/team-coordination.md).

### Cross-Workspace Signals

Workspaces communicate through signals with universal encoding:
**S = (Mode, Genre, Type, Format, Structure)**

```
Sales agent closes a deal
  → Signal routes to Content Factory (case study material)
  → Signal routes to Cognitive OS (revenue tracking)
  → Each workspace decodes using its own context
```

Same signal, different receiver, different genre. A salesperson gets a brief.
A developer gets a spec. A CEO gets a decision log.

See [`architecture/cross-workspace-signals.md`](architecture/cross-workspace-signals.md).

---

## Company Orchestration

Run an entire AI company from a workspace:

```
ai-company/
├── SYSTEM.md                     "You orchestrate an AI-native company."
├── company.yaml                  Mission, $50K/mo budget, org chart, governance
├── agents/
│   ├── orchestrator.md           Assigns work, tracks progress, manages budgets
│   ├── cfo.md                    Budget tracking, spend alerts, ROI analysis
│   ├── strategist.md             OKR tracking, quarterly reviews, pivot decisions
│   └── analyst.md                Cross-workspace analytics, trend detection
├── skills/
│   ├── delegate/SKILL.md         /delegate — assign work to a workspace
│   ├── budget/SKILL.md           /budget — view spend, set limits, approve
│   ├── hire/SKILL.md             /hire — add agent from library
│   ├── status/SKILL.md           /status — cross-workspace dashboard
│   └── plan/SKILL.md             /plan — create initiative with milestones
├── workspaces/                   Pointers to child workspaces
│   ├── sales-engine.yaml         Path, budget allocation, team, goals
│   ├── dev-shop.yaml
│   ├── content-factory.yaml
│   └── support-ops.yaml
└── engine/                       Goal tracking, budget ledger, signal bus
```

The orchestrator doesn't do domain work. It coordinates the workspaces that do.

---

## Agent Config + Workspace = Specialized System

Every agent runtime has a base configuration. When it enters a Canopy workspace,
the workspace layers on top — doesn't replace, extends:

```
Base config (always active):              Workspace (added on entry):
  ~/.claude/                               sales-engine/
  ├── agents/ (debugger, reviewer)         ├── agents/ (closer, prospector)
  ├── commands/ (/commit, /test)           ├── skills/ (/qualify, /pipeline)
  ├── rules/ (coding standards)            ├── reference/ (ICP, MEDDPICC)
  └── hooks/ (automation)                  └── engine/ (CRM integration)

= A fully equipped sales agent that can also debug code
```

When the agent leaves and enters a different workspace, it drops the sales
context and picks up whatever the new workspace provides. Base config persists.

| Runtime | Base Config | How Workspace Layers On |
|---|---|---|
| **Claude Code** | `~/.claude/` | Reads SYSTEM.md as project CLAUDE.md |
| **OSA** | `~/.osa/` | `osa connect .` auto-discovers everything |
| **Cursor** | `.cursor/` | SYSTEM.md → `.cursorrules`, agents → project rules |
| **Windsurf** | `.windsurfrules` | SYSTEM.md → `.windsurfrules` |
| **Aider** | `CONVENTIONS.md` | SYSTEM.md → `CONVENTIONS.md` |
| **Any agent** | Whatever it has | Read SYSTEM.md, run skills via shell |

---

## What's in This Repo

### [`protocol/`](protocol/) — The Standard

| Spec | What It Defines |
|------|----------------|
| `workspace-protocol.md` | SYSTEM.md + agents/ + skills/ + reference/ standard |
| `signal-theory.md` | S=(M,G,T,F,W) universal signal encoding |
| `agent-format.md` | YAML frontmatter + body sections for agent definitions |
| `company-format.md` | company.yaml schema (org chart, budgets, governance) |
| `spec-layer.md` | PROCEDURES.md, WORKFLOW.md, MODULES.md formats |
| `verification.md` | Spec contracts and drift detection |

### [`library/`](library/) — 159 Agents, 83 Skills

**`library/agents/`** — 159 agents across 13 categories:
academic, design, engineering, game-development, marketing, paid-media,
product, project-management, sales, spatial-computing, specialized,
support, testing

**`library/skills/`** — 83 skills across 16 categories:
development, content, search, knowledge, operations, strategy, agent,
workflow, learning, security, ai-patterns, processing, coordination,
governance, analysis, workspace

### [`operations/`](operations/) — Ready-to-Run Workspaces

| Workspace | What It Is | Agents | Skills |
|-----------|-----------|--------|--------|
| `sales-engine/` | B2B sales pipeline | 5 | 5 |
| `dev-shop/` | Software development team | 6 | 6 |
| `content-factory/` | Multi-platform content | 5 | 5 |
| `cognitive-os/` | Personal knowledge OS | 4 | 14 |
| `agency-workflows/` | Workflow examples | -- | -- |

### [`templates/`](templates/) — Starter Kits

| Template | Files | Use Case |
|----------|-------|----------|
| `micro/` | ~5 | Single-purpose agent (email responder, code reviewer) |
| `small/` | ~15 | Small team (2 agents, 3 skills, company.yaml) |
| `full/` | ~30 | Full operation (4 agents, 8 skills, workflows, spec/) |
| `enterprise/` | ~50 | Enterprise (governance, budgets, compliance, audit) |

### [`architecture/`](architecture/) — 18 Spec Documents

Heartbeat protocol, adapter registry, session persistence, budget enforcement,
task hierarchy, governance, marketplace format, tiered loading, memory architecture,
signal integration, cross-workspace signals, proactive agents, processing pipeline,
three-space model, team coordination, workspaces, and more.

### [`strategy/`](strategy/) — 7-Phase Orchestration

Discovery → Strategy → Foundation → Build → Hardening → Launch → Operate.
Playbooks, runbooks, handoff templates, agent activation prompts.

### [`guides/`](guides/) — Learn the System

Getting started, agent design, skill design, workflow design, proactive agents,
company setup, signal theory quickstart.

### [`integrations/`](integrations/) — 11 Runtime Connectors

Claude Code, OSA, Cursor, Copilot, Gemini CLI, Aider, Windsurf, OpenCode,
OpenClaw, Antigravity. Plus install/convert scripts for all.

---

## Why Canopy Beats Everything Else

### vs Server-Based Agent Frameworks

Every other agent orchestration system requires a server — Node.js, Postgres, React UI,
Docker containers. Canopy requires a folder.

| | Server-Based Frameworks | Canopy |
|---|---|---|
| **Requires** | Runtime + DB + UI | A folder |
| **Templates** | Usually "coming soon" | 159 agents, 83 skills, 5 operations |
| **Context mgmt** | Flat prompt injection | L0-L3 tiered loading |
| **Classification** | None | Signal Theory auto-routing |
| **Knowledge** | None | 6R pipeline, knowledge graph, learning loop |
| **Runtimes** | Usually 1-6 | 10+ |
| **Use cases** | Companies only | Companies, second brains, dev, content, automation |
| **Portability** | Tied to their server | Any agent, any machine |

### The Synthesis

No single system had all the pieces. Canopy synthesized the best ideas from across
the ecosystem:

```
Heartbeat Protocol   — Scheduled autonomous agent execution with atomic task checkout
Adapter Registry     — Pluggable runtime connectors behind a standard interface
Budget Enforcement   — 3-tier cost control (visibility → soft alert → hard ceiling)
6R Pipeline          — Record → Reduce → Reflect → Reweave → Verify → Rethink
Three-Space Model    — Self (identity) + Knowledge (graph) + Ops (ephemeral)
Tiered Loading       — L0/L1/L2/L3 context hierarchy, 96% cost reduction
Signal Theory        — S=(M,G,T,F,W) classification + auto-routing + quality gates
Simulation Engine    — Monte Carlo scenario planning + impact analysis
Agent Library        — 159 agents, 83 skills, 5 ready-to-run operations
Team Templates       — Filesystem-as-DB, inbox messaging, worktree isolation
```

**Protocol-based orchestration.** Works with any agent runtime. Requires zero
infrastructure. Deeper context management, knowledge processing, and quality
control than any server-based alternative.

---

## Quick Start

```bash
# Clone
git clone https://github.com/Miosa-osa/canopy.git
cd canopy

# Run a workspace
cd operations/sales-engine
# Your agent reads SYSTEM.md and starts working

# Build your own
cp -r templates/small/ my-workspace/
# Edit SYSTEM.md, add agents/, skills/, reference/

# Run a company
cp -r templates/enterprise/ my-company/
# Configure company.yaml, add workspace pointers
# Install: ../scripts/install.sh --tool claude-code
```

---

## The Big Picture

```
┌─────────────────────────────────────────────────────────────┐
│  L0 — ENTRY POINT (always loaded, ~2K tokens)               │
│  SYSTEM.md + company.yaml                                    │
└────────────────────────┬────────────────────────────────────┘
                         │ discovers
┌────────────────────────┴────────────────────────────────────┐
│  L1 — CAPABILITIES (on-demand, ~2K tokens each)              │
│  agents/ + skills/                                           │
└────────────────────────┬────────────────────────────────────┘
                         │ references
┌────────────────────────┴────────────────────────────────────┐
│  L2 — DEEP CONTEXT (loaded for specific tasks)               │
│  reference/ + workflows/ + handoffs/ + spec/                 │
└────────────────────────┬────────────────────────────────────┘
                         │ powered by
┌────────────────────────┴────────────────────────────────────┐
│  L3 — ENGINE (invisible, 0 tokens in context)                │
│  Search, vectors, knowledge graph, classification, CI/CD     │
└─────────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────────┐
│  CANOPY ORCHESTRATION                                        │
│  company.yaml — run workspaces toward shared goals           │
│  Heartbeats, budgets, governance, approval gates             │
└────────┬─────────┬─────────┬─────────┬──────────────────────┘
         │         │         │         │
    ┌────┴───┐ ┌───┴────┐ ┌─┴──────┐ ┌┴──────────┐
    │ Sales  │ │  Dev   │ │Content │ │ Cognitive │
    │ Engine │ │  Shop  │ │Factory │ │ OS        │
    │ 5 agt  │ │ 6 agt  │ │ 5 agt  │ │ 4 agt     │
    │ 5 skl  │ │ 6 skl  │ │ 5 skl  │ │ 14 skl    │
    │ CRM    │ │ CI/CD  │ │Publish │ │ 39-module │
    │ engine │ │ engine │ │engine  │ │ engine    │
    └────────┘ └────────┘ └────────┘ └───────────┘
     WORKSPACE  WORKSPACE  WORKSPACE   WORKSPACE
```

Each workspace is a complete AI system in a folder.
Same protocol. Different domain. Different depth.

**The workspace is the product.** The agent is just the runtime.

---

## License

MIT License. Open source. Use it, fork it, build on it.
