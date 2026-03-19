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
├── SYSTEM.md              ← Entry point: "Here's who you are, here's what you do"
├── agents/                ← "Here are your specialist sub-agents"
│   └── {name}.md
├── skills/                ← "Here are your commands"
│   └── {name}/SKILL.md
├── reference/             ← "Here's your domain knowledge"
│   └── *.md / *.yaml
└── [workspace-specific]   ← Whatever this system needs (engine, data, src, etc.)
```

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

## See Also

- `SYSTEM.md` — OptimalOS's workspace entry point (the first workspace built on this protocol)
- `agents/` — OptimalOS's agent definitions
- `skills/` — OptimalOS's skill definitions
- `reference/` — OptimalOS's domain knowledge
- OSA repo: `lib/optimal_system_agent/prompt_loader.ex` — workspace detection and SYSTEM.md loading
- OSA repo: `lib/optimal_system_agent/tools/builtins/list_skills.ex` — skill discovery
