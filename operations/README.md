# Operations — Complete AI Businesses in a Folder

> An Operation is a self-contained AI business. It has agents with defined roles,
> skills they can execute, reference knowledge they draw from, workflows that govern
> process, and a SYSTEM.md that ties it all together. Drop it into any agent runtime
> and it runs.

---

## What Is an Operation?

An Operation is a directory that contains everything an AI agent (or team of AI agents)
needs to run a business function autonomously. Not a chatbot. Not a prompt template.
A complete operational unit with:

- **Identity**: Who the system is and what it does (SYSTEM.md)
- **Agents**: Specialists with defined roles, skills, and communication styles
- **Skills**: Executable commands the agents can invoke
- **Reference**: Domain knowledge the agents load on demand
- **Workflows**: Multi-phase processes with handoff gates between agents
- **Handoffs**: Structured transition protocols between agents/phases
- **Spec** (optional): Executable FSMs, typed procedures, and module topology

```
my-operation/
├── SYSTEM.md           ← Entry point. Any agent reads this first.
├── company.yaml        ← Org chart, budget, mission
├── agents/             ← Specialist definitions (markdown + YAML frontmatter)
├── skills/             ← Slash commands the agents can run
├── reference/          ← Domain knowledge (loaded on-demand, not at boot)
├── workflows/          ← Multi-phase process definitions
├── handoffs/           ← Structured transition protocols
└── spec/               ← (Optional) FSMs, procedures, topology
```

The key insight: **SYSTEM.md is the only file the runtime needs to discover.** Everything
else is referenced from there. An agent reads SYSTEM.md, discovers what skills exist,
what agents are available, what reference to load, and how to operate.

---

## The 5-Layer Stack

Operations exist at Layer 3 of a 5-layer stack. Each layer is independently swappable.

```
┌─────────────────────────────────────────────────┐
│  Layer 5: COMPANY ORCHESTRATION                 │
│  Org charts, budgets, goals, agent hiring,      │
│  cross-team governance, board oversight          │
│  (company.yaml + governance rules)               │
├─────────────────────────────────────────────────┤
│  Layer 4: RUNTIME                               │
│  The engine that reads SYSTEM.md and executes.  │
│  OSA, Claude Code, Cursor, any agent framework. │
├─────────────────────────────────────────────────┤
│  Layer 3: OPERATIONS          ◄── YOU ARE HERE  │
│  Complete business functions in a folder.        │
│  Sales engines, dev shops, content factories.    │
├─────────────────────────────────────────────────┤
│  Layer 2: AGENT LIBRARIES                       │
│  Reusable personality templates. Markdown files  │
│  that define agent identity, rules, style.       │
│  Imported into Operations as agents/.            │
├─────────────────────────────────────────────────┤
│  Layer 1: COMPUTE                               │
│  Infrastructure. VMs, containers, sandboxes.     │
│  Where the runtime physically executes.          │
└─────────────────────────────────────────────────┘
```

### Layer 2: Agent Libraries

Agent libraries are collections of reusable personality templates stored as markdown
files. Each template defines an agent's identity, core rules, communication style,
and domain expertise. Think of them as "character sheets" for AI agents.

An Operation imports the agents it needs from libraries into its `agents/` directory.
A sales operation pulls in a prospector, closer, and researcher. A dev shop pulls in
a tech lead, frontend dev, and QA engineer. Same library, different compositions.

Agent libraries enable:
- **Consistency**: The same "closer" personality works across different sales operations
- **Versioning**: Update a template in the library, propagate to operations
- **Marketplace**: Share and sell agent templates independently of full operations
- **Specialization**: Deep domain experts that carry knowledge across deployments

### Layer 5: Company Orchestration

The company orchestration layer manages the human side of AI operations: org charts
that define reporting hierarchies, budgets that constrain spending per agent and per
project, goals that cascade from company mission to individual agent objectives, and
governance rules that require human approval for high-stakes actions.

This layer answers questions Operations alone cannot:
- "How much can this agent spend before it needs approval?"
- "Who does this agent escalate to when it's stuck?"
- "What's the company-wide priority when two operations compete for resources?"
- "Which actions require human sign-off before execution?"

Company orchestration is defined in `company.yaml` at the operation level and in
governance policies at the platform level. It is optional for simple operations
but essential for multi-agent, multi-team deployments.

---

## Connecting to a Runtime

An Operation is runtime-agnostic. The same directory works with any agent that can
read markdown files and execute shell commands. Here's how to connect:

### With OSA (Native Runtime)

```bash
osa connect /path/to/sales-engine
# OSA reads SYSTEM.md → discovers skills/ → loads agents/ → ready to operate
# Skills become executable commands in the agent loop
# Agents become dispatchable specialists
# Reference files are loaded on-demand via tiered loading
# company.yaml configures budgets, org chart, governance
```

OSA is the native runtime. It understands the full spec: heartbeat protocol, session
persistence, workspace management, budget enforcement, governance gates, and the
spec layer (FSMs, procedures, topology). Everything just works.

### With Claude Code

```bash
# 1. Copy SYSTEM.md content into your project's CLAUDE.md
cp /path/to/sales-engine/SYSTEM.md ./CLAUDE.md

# 2. Skills become slash commands
#    /prospect <company>  → runs the prospect skill
#    /pipeline            → shows pipeline status
#    /qualify <deal>      → MEDDPICC scoring

# 3. Agents become subagent dispatches
#    "Activate the prospector agent" → Claude Code reads agents/prospector.md

# 4. Reference files loaded on-demand
#    Claude Code reads reference/icp.md when it needs ICP scoring criteria

# 5. Spec layer (if present) becomes behavioral constraints
#    FSM states → Claude Code follows the declared state machine
#    Procedures → Claude Code invokes the declared implementations
```

Claude Code supports most of the Operation format natively. The main difference is
session persistence (Claude Code manages its own context window) and governance
(approval gates are manual rather than automated).

### With Cursor / Windsurf

```bash
# 1. Copy SYSTEM.md into .cursorrules (Cursor) or rules file (Windsurf)
cp /path/to/sales-engine/SYSTEM.md ./.cursorrules

# 2. Skills become @commands or inline instructions
#    The agent reads the skill definitions and executes them when invoked

# 3. Reference files loaded via @file mentions
#    @reference/icp.md → loads the ICP framework into context

# 4. Agents are described in SYSTEM.md
#    The IDE agent reads agent definitions and adopts the persona when needed
```

### With Any Agent Framework

```bash
# Any agent that can:
#   1. Read a markdown file         → Read SYSTEM.md for instructions
#   2. List a directory             → Discover skills/, agents/, reference/
#   3. Execute shell commands       → Run skill implementations
#   4. Read files on-demand         → Load reference when needed
# ...can operate any workspace.

# The minimum viable integration:
agent.load_instructions("SYSTEM.md")
agent.discover_skills("skills/")
agent.discover_agents("agents/")
agent.set_reference_path("reference/")
agent.run()
```

The format is intentionally simple. SYSTEM.md is plain markdown. Skills are
markdown files that describe shell commands. Agents are markdown files with YAML
frontmatter. Reference files are markdown. No proprietary format. No SDK required.
Any agent that reads files can operate a workspace.

---

## Example Operations

### [Sales Engine](./sales-engine/)

A B2B SaaS sales operation that runs the full pipeline from prospect identification
through closed-won deals. Five specialist agents (VP Sales, SDR, AE, Research Analyst,
Sales Copywriter) execute a 7-phase deal cycle governed by MEDDPICC qualification,
ICP scoring, and multi-threaded account strategy. Skills include `/prospect`, `/pipeline`,
`/qualify`, `/close-plan`, and `/battlecard`. Every deal is scored at every phase gate,
and handoffs between agents follow structured protocols.

### [Dev Shop](./dev-shop/)

A software development operation that delivers production-grade software through a
disciplined engineering pipeline. Six specialist agents (Tech Lead, Solutions Architect,
Frontend Dev, Backend Dev, QA Engineer, DevOps Engineer) execute a 7-phase feature
cycle with a parallel fast-track bug fix pipeline. QA defaults to NEEDS WORK — nothing
ships without QA approval. Skills include `/build`, `/test`, `/review`, `/deploy`,
`/spec`, and `/debug`. The dev-QA loop enforces quality with retry limits and tech
lead escalation.

### [Content Factory](./content-factory/)

A content production operation that turns ideas into published, optimized, multi-platform
content. Five specialist agents (Editor-in-Chief, Writer, Social Media Manager, SEO
Specialist, Visual Designer) execute a 7-phase content cycle from ideation through
performance analysis. Every piece is audience-targeted, SEO-optimized, and repurposed
across platforms. Skills include `/ideate`, `/write`, `/repurpose`, `/schedule`, and
`/analyze`. Brand voice is enforced at every editorial gate.

### [Cognitive OS](./cognitive-os/)

A personal cognitive operating system — an externalized decision tree library stored
as markdown files, searched by an Elixir engine, processed by an AI agent. Four
specialist agents (Knowledge Guide, Signal Processor, Context Assembler, Health Monitor)
manage 12 numbered knowledge nodes with tiered loading (L0/L1/L2) and a daily rhythm
layer (boot, operate, build, break, shutdown). Skills include `/ingest`, `/search`,
`/assemble`, `/health`, `/reweave`, `/simulate`, and 8 more. This is the most complex
example — it demonstrates how the Workspace Protocol can model an entire personal
knowledge management system.

### [Agency Workflows](./agency-workflows/)

A collection of multi-agent workflow examples showing how Operations compose agents
for real-world tasks: landing page generation, startup MVP planning, book chapter
writing, and workflows with persistent memory. These demonstrate the breadth of
agent collaboration patterns — from linear handoffs to parallel fan-out to
memory-augmented iteration.

---

## The Spec Layer (Optional Power)

Operations that need deterministic behavior beyond agent judgment can add a `spec/`
directory with three file types:

| File | What It Declares | When You Need It |
|------|-----------------|-----------------|
| `PROCEDURES.md` | Typed action & query bindings (Say, Execute, Analyze, Score) | When you want a capability registry with caching, sandboxing, and hot-swap |
| `WORKFLOW.md` | Finite state machines with triggers, pipelines, and branching | When your process has mandatory ordering and phase gates |
| `MODULES.md` | DAG topology with composition, event bus, and circuit breakers | When you need fault-tolerant module wiring and backpressure |

The spec layer is optional. Most Operations work fine with just agents, skills, and
reference files. Add spec files when you need:
- FSM workflows that MUST follow a specific path (sales pipeline, deployment, compliance)
- Typed procedure bindings with runtime hot-swap (switch email providers without changing workflows)
- Module composition with circuit breakers (fault tolerance for external integrations)
- Event-driven pipelines with filtering and routing (webhook intake, scheduled processing)

See `architecture/spec-layer.md` for the full specification and format reference.
See `architecture/pipelines.md` for event stream processing patterns.

---

## Creating a New Operation

```bash
# From this repository:
# 1. Copy an example as a starting point
cp -r operations/sales-engine my-new-operation

# 2. Edit SYSTEM.md to define your operation's identity and behavior
# 3. Customize agents/ for your domain's specialists
# 4. Write skills/ for the commands your agents need
# 5. Add reference/ files for domain knowledge
# 6. (Optional) Add spec/ for deterministic workflows

# Or use the scaffolding skill:
# /create-operation my-new-operation --agents engineering,sales --workflow sprint
```

The only hard requirement is SYSTEM.md. Everything else is discovered from there.
Start minimal, add layers as your operation grows.

---

*Operations v1.0 — The portable AI business unit format for OSA Operations*
