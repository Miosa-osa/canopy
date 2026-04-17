# The Workspace Protocol

> The standard interface between an AI agent and a specialized AI system.
>
> The standard interface specification, March 2026

## The Insight

The agent is thin. The workspaces are smart.

An AI agent (OSA, Claude Code, or anything) is just a runtime — a ReAct loop
with tools, channels, and memory. It doesn't know anything about any domain.
When it enters a workspace, it reads that workspace's SYSTEM.md and becomes
specialized. The SYSTEM.md is the brain transplant.

You don't build one massive agent that knows everything. You build one thin
agent that can operate ANY workspace. **The workspace IS the product.**

Each workspace is a sellable, deployable, self-contained AI business.

## The Protocol

Any workspace that follows this protocol can be operated by any agent:

```
workspace/
│
│  ── CANOPY LAYER (workspace config) ──────────────────────────
│  The agent's brain. Identity, capabilities, knowledge, rules.
│  This is ROM — persistent, transferable, version-controlled.
│
├── SYSTEM.md              ← Entry point: "Here's who you are, here's what you do"
├── company.yaml           ← Org chart, budgets, governance, goals (optional)
├── agents/                ← "Here are your specialist sub-agents"
│   └── {name}.md
├── skills/                ← "Here are your commands"
│   └── {name}/SKILL.md
├── teams/                 ← "Here are your team definitions"
│   └── {name}/TEAM.md
├── projects/              ← "Here are your active project charters"
│   └── {name}/PROJECT.md
├── tasks/                 ← "Here are your task definitions and backlog"
│   └── {name}/TASK.md
├── reference/             ← "Here's your domain knowledge"
│   └── *.md / *.yaml
├── workflows/             ← Multi-step process definitions
│   └── *.md
├── spec/                  ← Acceptance criteria, contracts, validation rules
│   └── *.md
├── engine/                ← Invisible infrastructure (search, DB, integrations)
│   └── ...
│
│  ── PROJECT LAYER (work product) ─────────────────────────────
│  What the agents BUILD. Code, apps, data, assets, outputs.
│  This is RAM in motion — actively created, deployed, shipped.
│
├── src/                   ← Source code (if building software)
│   └── ...
├── data/                  ← Datasets, exports, scraped content
│   └── ...
├── output/                ← Generated artifacts (reports, assets, builds)
│   └── ...
├── apps/                  ← Applications the workspace builds/manages
│   └── {app-name}/
└── .canopy/               ← Runtime state (task queue, sessions, observations)
    ├── tasks/
    ├── sessions/
    └── observations/
```

### The Two Layers

Every workspace has two distinct layers:

**Canopy Layer** — The workspace configuration. SYSTEM.md, agents, skills, reference,
workflows, specs, engine. This is what makes a generic agent into a specialist. It's
the ROM — persistent knowledge that doesn't change during execution. You version control
this. You distribute this. This IS the product.

**Project Layer** — The work product. Source code, applications, data, generated output.
This is what the agents actually BUILD when they operate. A dev-shop workspace has a
`src/` directory with the app it's building. A content-factory has an `output/` directory
with published articles. A sales-engine has `data/` with pipeline exports.

The `.canopy/` directory holds runtime state — task queues, active sessions, accumulated
observations. It's ephemeral. You can delete it and the workspace still works (agents
just lose their in-progress state).

**Why the separation matters:**
- You can ship the Canopy Layer without the Project Layer (that's what the marketplace does)
- You can swap the Canopy Layer on an existing project (re-specialize without losing work)
- Agents know which files are "instructions" vs "work product" — no conflation
- Git ignores `.canopy/` by default (runtime state shouldn't be committed)

### SYSTEM.md — The Brain Transplant

Every workspace MUST have a SYSTEM.md at its root. This file tells the agent:

1. **Identity** — What this workspace is, what domain it operates in
2. **Boot sequence** — What to load first (context injection)
3. **Core loop** — The primary workflow (receive → process → output)
4. **Skills available** — What slash commands exist in `skills/`
5. **Agents available** — What specialists exist in `agents/`
6. **Reference files** — What domain knowledge exists in `reference/`
7. **Quality rules** — Constraints, failure modes, validation

The SYSTEM.md is the ONLY file the agent needs to read to become operational
in this workspace. Everything else is referenced from SYSTEM.md.

### agents/ — Specialist Definitions

Markdown files that define sub-agent behaviors. Each agent has:
- **Role** — What it does
- **When to activate** — Trigger conditions
- **Capabilities** — What it can do
- **Dependencies** — What workspace resources it needs

Agents are NOT running processes. They're behavioral templates that the core
agent assumes when conditions match. "Become the signal-processor agent" means
"follow the instructions in agents/signal-processor.md."

### skills/ — Executable Commands

Each skill is a folder with a SKILL.md that defines:
- **Command** — The slash command name (`/search`, `/ingest`, etc.)
- **Description** — What it does
- **Usage** — How to invoke it
- **Implementation** — What shell commands, API calls, or tool sequences to execute

The agent discovers skills by scanning `skills/*/SKILL.md`. Skills are the
workspace's API — the things the agent can DO in this workspace.

### teams/ — Team Definitions

Each team is a folder with a TEAM.md that defines the team's composition,
responsibilities, and operating rules. Teams group agents and humans around
a shared mission. See `protocol/team-format.md` for the full specification.

### projects/ — Project Charters

Each project is a folder with a PROJECT.md that defines the project's scope,
goals, milestones, and linked tasks. Projects are the unit of work the workspace
tracks to completion. See `protocol/project-format.md` for the full specification.

### tasks/ — Task Definitions

Each task is a folder with a TASK.md that defines an atomic unit of work: what
to do, acceptance criteria, assignee, and status. Tasks are the lowest-level
planning primitive. See `protocol/task-format.md` for the full specification.

### reference/ — Domain Knowledge

Static reference files that the agent loads on-demand:
- Methodology documents
- Component catalogs
- Configuration schemas
- Failure mode guides
- Domain vocabulary

These are NOT loaded at boot (too much context). They're loaded when the agent
needs deep reference on a specific topic.

## How the Agent Connects

```
Agent starts
  ↓
Detects workspace (current directory, config, or explicit)
  ↓
Reads SYSTEM.md
  ↓
Executes boot sequence (from SYSTEM.md)
  ↓
Discovers skills/ → registers available commands
  ↓
Discovers agents/ → loads behavioral templates
  ↓
Ready to operate in this workspace's domain
```

## Multi-Workspace Operation

An agent can connect to multiple workspaces simultaneously or switch between them:

```
OSA
 ├── Workspace: OptimalOS     → cognitive OS, knowledge management
 ├── Workspace: dev/myapp     → coding, testing, deployment
 ├── Workspace: automations   → scheduled tasks, workflows, cron jobs
 └── Workspace: sales-engine  → pipeline management, outreach
```

Each workspace is independent. Its SYSTEM.md, skills, agents, and reference
files are self-contained. No workspace knows about any other workspace.

The agent's CORE memory (its own learning, preferences, patterns) persists
across workspaces. Workspace-specific memory stays in the workspace.

## Workspace Sizes

Workspaces can be tiny or massive:

### Micro Workspace (~5 files)
```
email-responder/
├── SYSTEM.md              "You respond to emails in this tone..."
├── skills/
│   └── respond/SKILL.md   "Draft a response matching the template"
└── reference/
    └── tone-guide.md      "Here's how we write emails"
```

### Small Workspace (~20 files)
```
code-reviewer/
├── SYSTEM.md
├── agents/
│   └── reviewer.md
├── skills/
│   ├── review/SKILL.md
│   ├── suggest/SKILL.md
│   └── approve/SKILL.md
└── reference/
    ├── standards.md
    └── patterns.md
```

### Full Workspace (~100+ files)
```
OptimalOS/                     ← This is a full workspace
├── SYSTEM.md
├── agents/ (4)
├── skills/ (14)
├── reference/ (11)
├── engine/ (39 Elixir modules)
├── rhythm/ (15 operating files)
├── 01-12/ (knowledge nodes)
└── docs/ (200+ files)
```

### Enterprise Workspace (~1000+ files)
```
business-platform/
├── SYSTEM.md
├── agents/ (20+)
├── skills/ (50+)
├── reference/ (30+)
├── services/ (microservices)
├── data/ (databases, warehouses)
└── integrations/ (APIs, webhooks)
```

## The Business Model

Each workspace is a product. The pattern:

1. **Build a workspace** — SYSTEM.md + agents + skills + reference + domain logic
2. **The workspace IS the AI business** — it turns a generic agent into a specialist
3. **Distribute the workspace** — anyone with OSA (or any protocol-compatible agent) can run it
4. **The agent is free** — the value is in the workspace

Examples:
- **Real estate AI** — workspace with property analysis skills, market data reference, client agents
- **Content production AI** — workspace with editorial skills, brand reference, publishing agents
- **Legal review AI** — workspace with contract analysis skills, compliance reference, review agents
- **Customer support AI** — workspace with ticket handling skills, product reference, escalation agents
- **Trading AI** — workspace with market analysis skills, strategy reference, risk agents

The workspace creator doesn't build an agent. They build the domain knowledge,
the skills, the reference files. The agent runtime already exists.

## Protocol Compliance

A workspace is protocol-compliant if:

1. ✅ Has `SYSTEM.md` at root
2. ✅ SYSTEM.md has identity, boot sequence, core loop sections
3. ✅ Skills are in `skills/{name}/SKILL.md` format
4. ✅ Agents are in `agents/{name}.md` format
5. ✅ Reference files are in `reference/`
6. ✅ SYSTEM.md references available skills and agents
7. ✅ Workspace is self-contained (doesn't depend on other workspaces)

**Optional manifest types** (include when the workspace manages structured work):

| Directory | Manifest | Purpose |
|-----------|----------|---------|
| `teams/{name}/` | `TEAM.md` | Team composition and operating rules |
| `projects/{name}/` | `PROJECT.md` | Project charter, scope, and milestones |
| `tasks/{name}/` | `TASK.md` | Atomic unit of work with acceptance criteria |

All three follow the same discovery pattern as skills: the agent scans
`teams/*/TEAM.md`, `projects/*/PROJECT.md`, and `tasks/*/TASK.md` to build
its operational context.

## Relationship to Existing Systems

| System | What It Is | In Workspace Protocol Terms |
|--------|-----------|---------------------------|
| Claude Code CLAUDE.md | Project instructions | A simplified SYSTEM.md (no agents/, skills/, reference/) |
| Knowledge management plugins | Note-taking extensions | A workspace with hooks, skills, and reference/ |
| OpenClaw | Multi-channel assistant | An agent runtime (like OSA) that could load workspaces |
| Cursor Rules | Editor instructions | A stripped-down SYSTEM.md |
| GPT Instructions | System prompt | A single-file SYSTEM.md equivalent |
| MCP Servers | Tool providers | Skills implemented as external services |

The Workspace Protocol is the formalization of what everyone is doing ad-hoc.
CLAUDE.md is already a SYSTEM.md — it's just not called that, and it doesn't
have the agents/skills/reference structure around it.

## Why This Matters

Every AI agent today hardcodes its capabilities. Claude Code knows about code.
ChatGPT knows about conversation. Cursor knows about editing.

With the Workspace Protocol, capabilities are PORTABLE. A workspace built for
OSA works with any agent that reads SYSTEM.md and discovers skills. The agent
is the runtime. The workspace is the application.

**This is the App Store model for AI agents.**

The agent is the phone. The workspace is the app.
Nobody buys a phone for the phone. They buy it for the apps.
Nobody will use an agent for the agent. They'll use it for the workspaces.

## External Skill and Agent References

Operations can reference skills and agents defined outside the workspace without
copying them in. External references are resolved at activation time — when the
referencing agent is loaded to Tier 1 — using provenance metadata declared inline
in the `skills` or agents list.

### Why External References

Vendoring (copying files into the workspace) creates maintenance burden. When an
upstream skill updates, every operation that copied it must update manually. External
references let operations consume shared skill libraries while staying in sync with
upstream changes.

External references are appropriate when:
- A skill is maintained by an external team or community
- Multiple operations share the same skill without wanting to diverge
- The skill is large enough that vendoring it would inflate the workspace

Local skills (defined in `skills/`) are appropriate when:
- The skill is specific to this operation
- You need full control over the skill's behavior
- The operation must work offline or without external resolution

### Reference Syntax

In an agent's `skills` list, a reference entry replaces the bare skill slug with
a structured object:

```yaml
# In an agent's frontmatter skills list

skills:
  - review                           # local skill — resolved from skills/review/SKILL.md
  - ref: remotion-best-practices     # external reference — slug for runtime use
    source: github
    repo: remotion-dev/skills
    path: skills/remotion
    pin: main
    license: MIT
  - ref: elixir-otp-patterns
    source: github
    repo: optimalos/skill-library
    path: skills/elixir/otp-patterns
    pin: v2.1.0
    license: Apache-2.0
  - ref: meddpicc-scoring
    source: url
    url: https://skills.optimalos.com/sales/meddpicc/SKILL.md
    pin: sha256:a1b2c3d4e5f6...
    license: MIT
```

### Reference Fields

| Field | Required | Description |
|-------|----------|-------------|
| `ref` | yes | Local slug the runtime uses to identify this skill |
| `source` | yes | Resolution method: `github`, `url`, or `registry` |
| `repo` | yes (if `source: github`) | GitHub repo in `owner/repo` format |
| `path` | yes (if `source: github`) | Path within the repo to the skill directory or SKILL.md |
| `url` | yes (if `source: url`) | Direct URL to the SKILL.md file |
| `pin` | yes | Branch name, tag, or commit SHA (for `github`); SHA256 hash (for `url`) |
| `license` | yes | SPDX license identifier |

### Pin Strategy

The `pin` field determines how the reference is resolved:

| Pin Value | Behavior | Use When |
|-----------|----------|----------|
| Branch name (e.g., `main`) | Always resolves to the branch HEAD | Rapid iteration; acceptable to get upstream changes |
| Tag (e.g., `v2.1.0`) | Resolves to a specific release | Production operations; controlled update cadence |
| Commit SHA | Resolves to an exact commit | Maximum stability; never changes without explicit update |
| SHA256 hash | Verifies URL content hash | Direct URL references where version tagging is unavailable |

For production operations, pin to a tag or commit SHA. Branch pins create implicit
dependency on upstream changes and should be used only during development.

### Provenance Tracking

The runtime records all external reference resolutions in `logs/activity.log`:

```
{ISO8601} | {agent-id} | skill_ref_resolved | {ref-slug} | {resolved-sha} | 0.00
```

This creates an audit trail: for any session, you can determine exactly which
version of every external skill was used. This is critical for debugging and
compliance in production operations.

### Resolution at Activation

External references are resolved when the referencing agent is activated to Tier 1
(see `architecture/progressive-disclosure.md`). Resolution:

1. Check the local reference cache (`skills/.refs/{ref-slug}/`)
2. If cached and pin matches: use cached version
3. If not cached or pin is a branch name: fetch from the external source
4. Verify the fetched content matches the pin (SHA comparison for tags and commits)
5. Write to local cache
6. Load the SKILL.md into the agent's active skill set

The local reference cache is not committed to version control. It is populated
at runtime and can be cleared without affecting workspace behavior.

### Security Considerations

External references introduce supply chain risk. Mitigations:

- Always pin to a tag or commit SHA in production (never `main` or `latest`)
- Include the `license` field; the runtime can enforce license allowlists
- Review external skill content before pinning to a new version
- Treat external skills as untrusted input: the governance layer applies the
  same approval gates to externally-sourced skill invocations as to local ones

Board approval is required before adding an external reference to a production
agent (same gate as new workflow production — see `protocol/company-format.md`).

---

## See Also

- `SYSTEM.md` — OptimalOS's workspace entry point (the first workspace built on this protocol)
- `agents/` — OptimalOS's agent definitions
- `skills/` — OptimalOS's skill definitions
- `teams/` — OptimalOS's team definitions
- `projects/` — OptimalOS's project charters
- `tasks/` — OptimalOS's task definitions
- `reference/` — OptimalOS's domain knowledge
- `protocol/team-format.md` — TEAM.md specification and field reference
- `protocol/project-format.md` — PROJECT.md specification and field reference
- `protocol/task-format.md` — TASK.md specification and field reference
- `architecture/progressive-disclosure.md` — How entities are loaded at each tier
- OSA repo: `lib/optimal_system_agent/prompt_loader.ex` — workspace detection and SYSTEM.md loading
- OSA repo: `lib/optimal_system_agent/tools/builtins/list_skills.ex` — skill discovery

---

## Signal Theory Position

This spec implements **Layer 5 (Data) + Layer 7 (Governance)** of the Optimal System architecture.

The directory layout — `agents/`, `skills/`, `teams/`, `reference/` — IS the data layer: it is the physical substrate where organizational intent is stored, versioned, and distributed. These directories are not scaffolding; they are the storage topology for encoded knowledge.

SYSTEM.md IS Beer's System 5 (Policy). It carries the identity and boot rules that constrain everything downstream — the first signal a runtime decodes when entering a workspace. Nothing in the workspace overrides it.

**Most relevant governing principles:**
- **Beer (viable structure at every scale)** — The two-layer separation (Canopy / Project) ensures structural coherence: instructions and work product never conflate, and the workspace remains viable at every size from micro to enterprise.
- **Shannon (progressive loading prevents context overflow)** — Reference files, agents, and skills are loaded on-demand from the data layer, not injected wholesale at boot. This respects channel capacity limits.

See `architecture/optimal-system-mapping.md` for the canonical layer mapping.
