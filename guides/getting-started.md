# Getting Started with OSA Operations

> From zero to a running AI Operation in 10 minutes.

---

## What Is OSA Operations?

OSA Operations is a framework for building AI-powered businesses as **portable, self-contained
directories**. Instead of writing code to build an AI company, you write markdown and YAML.
The result is an Operation -- a folder that any compatible agent runtime can pick up and run.

Think of it this way:

- **The agent is the phone.** OSA, Claude Code, Cursor, Codex -- these are runtimes.
- **The Operation is the app.** Your folder of agents, skills, workflows, and domain knowledge.
- **You are the builder.** You define what the AI company does, who it employs, and how it operates.

One repo. Every role. Any runtime.

---

## The 5-Layer Stack

Every Operation is built on 5 layers. Each layer depends only on the one below it.
You compose what you need -- not everything is required.

```
Layer 5: COMPANY     company.yaml -- mission, budget, governance, goals
Layer 4: RUNTIME     SYSTEM.md -- entry point, boot sequence, core loop
Layer 3: OPERATIONS  workflows/ -- phase pipelines, handoffs, evidence gates
Layer 2: LIBRARIES   agents/ + skills/ + reference/ -- reusable components
Layer 1: COMPUTE     Adapter layer -- OSA, Claude Code, Cursor, Codex
```

### Layer 1: Compute

The runtime that actually executes your agents. You do not build this layer --
you choose one. Options include:

| Runtime | How It Reads Your Operation |
|---------|---------------------------|
| OSA | `osa run .` -- native support, full heartbeat protocol |
| Claude Code | SYSTEM.md becomes project context, agents become behavioral modes |
| Cursor | Copy agents/ to .cursor/agents/, reference/ to .cursor/rules/ |
| Codex | Point at SYSTEM.md as system prompt, skills as tool definitions |

### Layer 2: Libraries

Reusable components that any Operation can use:

- **agents/** -- Specialist definitions (Software Architect, Outbound Prospector, etc.)
- **skills/** -- Executable commands (`/prospect`, `/build`, `/deploy`)
- **reference/** -- Domain knowledge loaded on demand (ICP frameworks, coding standards)

### Layer 3: Operations

Workflows that coordinate agents through multi-phase pipelines:

- Phase definitions with owners, evidence gates, and signal thresholds
- Handoff protocols between agents
- Retreat patterns (moving backward when quality gates fail)
- Stalled work detection

### Layer 4: Runtime

The SYSTEM.md file -- the single entry point that tells the agent who it is,
what it can do, and how to operate.

### Layer 5: Company

The organizational envelope -- mission, budget, governance, goal hierarchy.
This is what turns a collection of agents into a business.

---

## Your First Operation in 10 Minutes

### Step 1: Clone the Repository

```bash
git clone https://github.com/optimalos/osa-operations.git
cd osa-operations
```

### Step 2: Copy an Example

```bash
cp -r operations/dev-shop my-operation
cd my-operation
```

### Step 3: Edit company.yaml

Open `company.yaml` and change it to match your business:

```yaml
name: My AI Startup
slug: my-ai-startup
description: AI-powered code review service for SaaS companies.
mission: Ship zero-bug releases through automated, context-aware code review.

budget:
  monthly_usd: 3000
  per_agent_usd: 600
  enforcement: warning

governance:
  board_approval_required:
    - new_agent_hire
    - budget_increase_pct: 20
  immutable_log: true
  escalation_chain:
    - tech-lead
    - board

issue_prefix: "MAS-"
```

### Step 4: Pick Your Agents

Browse the agent library and copy the ones you need:

```bash
# See what's available
ls ../agents/engineering/
ls ../agents/sales/

# Copy the ones you want
cp ../agents/engineering/code-reviewer.md agents/
cp ../agents/engineering/software-architect.md agents/
cp ../agents/engineering/security-engineer.md agents/
```

### Step 5: Customize SYSTEM.md

Edit SYSTEM.md to reflect your operation. The critical sections:

```markdown
# My AI Startup -- Agent System Instructions

## Identity
You are operating **My AI Startup** -- an automated code review service...

## Boot Sequence
1. Load reference/standards.md (coding standards)
2. Load reference/patterns.md (review patterns)

## Core Loop
RECEIVE code change
  > CLASSIFY: what type of review?
  > ROUTE: activate the right reviewer agent
  > ACT: perform the review
  > VERIFY: does the review meet quality gates?
  > PERSIST: log results, update metrics

## Available Agents
| Agent | Role | Activate When |
|-------|------|---------------|
| code-reviewer | Primary Reviewer | Any PR submitted |
| software-architect | Architecture Review | Structural changes |
| security-engineer | Security Review | Auth, data, API changes |

## Available Skills
| Skill | Command | What It Does |
|-------|---------|-------------|
| Review | `/review <PR>` | Full code review |
```

### Step 6: Add Domain Knowledge

Create reference files for your specific domain:

```bash
mkdir -p reference
```

Write `reference/standards.md` with your coding standards.
Write `reference/patterns.md` with review patterns to check for.

### Step 7: Run It

```bash
# With OSA (native)
osa run .

# With Claude Code (use SYSTEM.md as project context)
cd my-operation
# Claude Code reads SYSTEM.md automatically

# With Cursor
cp agents/* .cursor/agents/
# Reference SYSTEM.md in your cursor rules
```

---

## Directory Structure Walkthrough

Here is the complete anatomy of an Operation:

```
my-operation/
├── SYSTEM.md              <- THE entry point. Agent reads this first.
├── company.yaml           <- Organizational envelope.
│
├── agents/                <- WHO works here.
│   ├── tech-lead.md       <- Each agent = YAML frontmatter + markdown body
│   ├── frontend-dev.md
│   ├── backend-dev.md
│   └── qa-engineer.md
│
├── skills/                <- WHAT agents can DO.
│   ├── build/
│   │   └── SKILL.md       <- /build command definition
│   ├── test/
│   │   └── SKILL.md       <- /test command definition
│   └── deploy/
│       └── SKILL.md       <- /deploy command definition
│
├── workflows/             <- HOW work flows through phases.
│   ├── feature-cycle.md   <- Spec > Design > Build > Test > Review > Deploy > Monitor
│   └── bug-fix.md         <- Report > Reproduce > Fix > Test > Deploy
│
├── reference/             <- DOMAIN KNOWLEDGE loaded on demand.
│   ├── stack.md           <- Technology stack details
│   ├── patterns.md        <- Design patterns used
│   ├── standards.md       <- Coding standards
│   └── ci-cd.md           <- CI/CD pipeline docs
│
├── handoffs/              <- TEMPLATES for agent-to-agent transitions.
│   ├── standard.md        <- Normal phase transition
│   └── qa-fail.md         <- QA rejection with fix instructions
│
├── tasks/                 <- ACTIVE work items (created at runtime).
│   └── DS-001.yaml
│
├── sessions/              <- PERSISTED agent state (created at runtime).
│
└── logs/                  <- IMMUTABLE audit trail (created at runtime).
    └── activity.log
```

### What Gets Committed vs What Gets Generated

| Committed (you write) | Generated (runtime creates) |
|-----------------------|---------------------------|
| SYSTEM.md | tasks/*.yaml |
| company.yaml | sessions/* |
| agents/*.md | logs/*.log |
| skills/*/SKILL.md | |
| workflows/*.md | |
| reference/*.md | |
| handoffs/*.md | |

---

## Running an Operation with Different Runtimes

### OSA (Native Runtime)

OSA implements the full Workspace Protocol: heartbeat execution, budget enforcement,
session persistence, governance, and the task system.

```bash
# Start the operation
osa run .

# The heartbeat protocol kicks in:
# 1. Reads SYSTEM.md
# 2. Discovers agents/ and skills/
# 3. Loads boot sequence
# 4. Enters core loop
# 5. Agents wake on schedule or assignment
```

### Claude Code

Claude Code reads SYSTEM.md as project context. Agents become behavioral modes
that Claude adopts based on the task at hand.

```bash
# Navigate to your operation directory
cd my-operation

# Claude Code automatically detects SYSTEM.md
# You interact naturally:
#   "Review this PR" -> activates code-reviewer agent behavior
#   "Design the API" -> activates software-architect agent behavior
#   "/build user-auth" -> executes the build skill
```

Limitations with Claude Code:
- No automatic heartbeat (agent runs on your prompts, not on schedule)
- No budget enforcement (you manage costs manually)
- No persistent sessions across conversations (session state resets)
- Skills execute as tool sequences within the conversation

### Cursor

Cursor uses agent files as rule sets. Copy agents into `.cursor/agents/`
and reference files into `.cursor/rules/`.

```bash
cp agents/* .cursor/agents/
cp reference/* .cursor/rules/
```

### Any Other Runtime

Any agent that can:
1. Read a markdown file (SYSTEM.md)
2. Discover files in a directory (agents/, skills/)
3. Execute tool sequences

...can run an Operation. The Workspace Protocol is runtime-agnostic by design.

---

## Example Operations

The repository ships with three complete examples:

### Dev Shop (`operations/dev-shop/`)
A software development operation. 6 agents (tech-lead, architect, frontend-dev,
backend-dev, qa-engineer, devops). Workflows for feature cycles and bug fixes.
Budget: $8,000/month.

### Sales Engine (`operations/sales-engine/`)
A B2B SaaS sales operation. 5 agents (director, prospector, closer, researcher,
copywriter). 7-phase deal cycle from prospect to closed-won. Budget: $5,000/month.

### Content Factory (`operations/content-factory/`)
A content production operation. Agents for editorial, writing, SEO, and social media.
Workflows for content ideation through multi-platform publishing. Budget: $4,000/month.

---

## What to Read Next

| Guide | When to Read It |
|-------|----------------|
| [Agent Design](agent-design.md) | You need to create or customize agents |
| [Skill Design](skill-design.md) | You need to add new commands to your operation |
| [Workflow Design](workflow-design.md) | You need multi-phase pipelines with quality gates |
| [Proactive Agents](proactive-agents.md) | You want agents that self-activate on schedule |
| [Company Setup](company-setup.md) | You need to configure budgets, governance, goals |
| [Signal Theory Quickstart](signal-theory-quickstart.md) | You want to understand the quality framework |

---

## Common Questions

**Q: Do I need all 5 layers?**
No. An agent file works without a company. A company works without workflows.
Start with SYSTEM.md + a few agents. Add layers as you need them.

**Q: Can I mix agents from different examples?**
Yes. Agents are portable. Copy a sales agent into a dev operation if you need it.
Just update SYSTEM.md to reference the new agent.

**Q: What if my runtime does not support the full protocol?**
Use what it supports. Claude Code does not have heartbeats, but it reads SYSTEM.md
and can follow agent definitions. The protocol degrades gracefully.

**Q: How much does it cost to run an Operation?**
Depends on your runtime and usage. The budget system in company.yaml lets you set
hard ceilings. A typical dev-shop Operation running on Claude Code costs $100-500/month
in API calls depending on volume.

**Q: Can I sell my Operation?**
Yes. An Operation is a self-contained directory. Package it, distribute it, license it.
The marketplace spec in `architecture/marketplace.md` defines the bundle format.
