# OSA Operations Spec v1.0

> Formal specification for OSA Operations — the unit of deployment for an AI-powered
> company, team, or workflow. Unifies company orchestration, deep agent definitions,
> and Signal Theory encoding into a single portable format.
>
> An Operation is a self-contained, portable, runtime-agnostic bundle that defines
> an organizational structure, its agents, their workflows, and the governance rules
> that govern execution.

---

## Table of Contents

1. [Core Concepts](#1-core-concepts)
2. [Company Definition](#2-company-definition)
3. [Agent Format](#3-agent-format)
4. [Goal Hierarchy](#4-goal-hierarchy)
5. [Orchestration](#5-orchestration)
6. [Governance](#6-governance)
7. [Skills](#7-skills)
8. [Reference](#8-reference)
9. [Marketplace](#9-marketplace)
10. [Adapters](#10-adapters)
11. [Session Persistence](#11-session-persistence)
12. [Directory Layout](#12-directory-layout)

---

## 1. Core Concepts

| Term | Definition |
|------|-----------|
| **Operation** | A complete, portable bundle: company + agents + workflows + skills + reference |
| **Company** | The organizational envelope — mission, budget, governance, goal hierarchy |
| **Agent** | A specialized AI role with fixed identity, signal encoding, and process methodology |
| **Workflow** | A phase pipeline: ordered stages, agent activations, handoff gates |
| **Skill** | An engine-backed slash command, reusable across Operations |
| **Adapter** | The runtime that executes an agent (OSA, Claude Code, Cursor, etc.) |
| **Signal** | Every agent output encodes `S=(M, G, T, F, W)` per Signal Theory |
| **S/N Gate** | A quality threshold applied at phase transitions — low-signal output is rejected |

An Operation is the smallest unit that can be exported, versioned, priced, and deployed
on any supported adapter. It is not a project — it is the permanent organizational
infrastructure within which projects run.

---

## 2. Company Definition

Every Operation root contains `company.yaml`. This file is the source of truth for
the organizational envelope.

### Schema

```yaml
# company.yaml
name: string                    # Display name ("Acme Agency")
slug: string                    # URL-safe identifier ("acme")
description: string             # One sentence
mission: string                 # North star statement

budget:
  monthly_usd: number           # Total monthly budget cap
  per_agent_usd: number         # Default per-agent budget (overridden in agent YAML)
  enforcement: visibility | warning | stop   # What happens at threshold

governance:
  board_approval_required:
    - new_agent_hire
    - budget_increase_pct: 20   # Threshold % that triggers board approval
    - new_workflow_production
  immutable_log: true           # All activity appended to logs/activity.log
  escalation_chain:             # Ordered list — first available handles escalation
    - ceo
    - cto
    - board

issue_prefix: string            # Task ID prefix ("LUN-", "MIO-")

goals:
  initiatives:                  # See Section 4
    - id: INI-001
      title: string
      projects: [...]
```

### Budget Enforcement Tiers

| Tier | Threshold | Behavior |
|------|-----------|----------|
| `visibility` | 0% | Log spend, no action |
| `warning` | 80% of monthly cap | Alert escalation chain |
| `stop` | 100% of monthly cap | Block new agent calls, require board override |

Per-agent budget overrides company default. Agent-level enforcement is independent.

---

## 3. Agent Format

Every file in `agents/` follows a YAML frontmatter + Markdown body convention.
The frontmatter is machine-readable. The body is the agent's injected system prompt.

### Frontmatter Schema

```yaml
---
name: string                    # Display name ("Deal Strategist")
id: string                      # Unique slug ("deal-strategist")
role: string                    # Functional role ("closer", "engineer", "analyst")
title: string                   # Full title ("Senior Deal Strategist")
reportsTo: string               # Agent id or "ceo" / "board"
team: string                    # Team id this agent belongs to (see team-format.md)
budget: number                  # Monthly USD cap for this agent
color: string                   # Hex color for UI (#1B4D3E)
emoji: string                   # Single emoji identifier
adapter: string                 # Runtime adapter (see Section 10)
signal: string                  # Signal Theory encoding (see below)
skills: [string]                # Skill slugs this agent loads (see Section 7)
context_tier: l0 | l1 | full    # Default context loading depth
---
```

### Signal Encoding Field

The `signal:` field encodes the agent's default output mode per Signal Theory:

```
signal: S=(mode, genre, type, format, structure)
```

Examples:
```yaml
signal: S=(linguistic, brief, direct, markdown, persuasion)
signal: S=(code, spec, commit, elixir, genserver-pattern)
signal: S=(data, report, inform, markdown, metrics-table)
signal: S=(linguistic, transcript, inform, markdown, meeting-minutes)
```

All 5 dimensions must be resolved. Unresolved dimensions = undefined output behavior.

### Body Sections (required)

```markdown
# Identity & Memory
Role definition, personality traits, domain experience, persistent context the
agent carries across sessions. First-person voice.

# Core Mission
Numbered list of 3–5 primary capabilities. Each is a verb phrase.
1. [Capability]
2. [Capability]
...

# Critical Rules
Hard behavioral constraints. These override any instruction.
- NEVER [X]
- ALWAYS [Y]
- When [condition] → [action]

# Process / Methodology
Domain frameworks, decision trees, and operating procedures.
Numbered steps where order matters. Tables where tradeoffs exist.

# Deliverable Templates
Exact output templates the agent produces. Named and formatted.
Agent MUST use these templates — no freeform output for tracked deliverables.

### Template: [Name]
[Template body]

# Communication Style
- Tone: [direct / consultative / formal / conversational]
- Lead with: [decision / finding / question / action]
- Default genre: [brief / spec / report / pitch / ...]
- Receiver calibration: [what the downstream agent/human expects]

# Success Metrics
Quantified targets. Agent self-evaluates against these.
- [Metric]: [target]
```

### Team Membership

The `team` field assigns an agent to a team defined in `teams/{team-id}.md`. An
agent can belong to only one team. Teams add a coordination layer on top of the
org chart — shared budget ceilings, escalation rules, and handoff patterns. See
`protocol/team-format.md` for the full team definition standard.

### Org Chart

`reportsTo` fields compose into a directed acyclic org chart. Cycles are invalid.
The root node is always `ceo` or `board`. Escalation always traverses upward.

```
board
  └── ceo
       ├── cto
       │    ├── lead-engineer
       │    └── qa-lead
       └── cro
            └── deal-strategist
```

---

## 4. Goal Hierarchy

Goals live in `company.yaml` under `goals.initiatives` and in individual task files
under `tasks/`. Complex workstreams use standalone `projects/{project-id}/PROJECT.md`
files (see `protocol/project-format.md`). Recurring or template tasks use manifest
files under `tasks/manifests/` (see `protocol/task-format.md`). The hierarchy is:

```
Initiative  (north star — months to years)
  └── Project  (workstream — weeks to months)
       └── Milestone  (checkpoint — days to weeks, has evidence gate)
            └── Task  (atomic unit — hours to days, assigned to one agent)
                 └── Sub-task  (breakdown — minutes to hours)
```

### Task Schema

```yaml
# tasks/{ISSUE_PREFIX}-{number}.yaml
id: LUN-042
title: string
type: task | bug | decision | research | review
status: backlog | active | blocked | review | done
assigned_to: agent-id
project: project-id            # Project this task contributes to (optional)
milestone: MIL-007
priority: critical | high | medium | low
estimate_hours: number
evidence_required: string      # What must be true for this to be "done"
manifest: task-manifest-id     # Source manifest if instantiated from tasks/manifests/
created_at: ISO8601
updated_at: ISO8601
parent: LUN-041                # Optional sub-task parent
```

For richer task definitions — recurring tasks, structured acceptance criteria, and
output format templates — use task manifests in `tasks/manifests/`. See
`protocol/task-format.md` for the full manifest standard.

### Milestone Evidence Gates

A Milestone is not complete until its evidence gate is satisfied. Evidence gates are
defined in the workflow (Section 5) and checked by the orchestrating agent before
advancing to the next phase.

| Gate Type | What It Checks |
|-----------|---------------|
| `tests_pass` | All tests in scope green |
| `review_approved` | N designated reviewers approved |
| `signal_score` | S/N score >= threshold on all deliverables |
| `human_approval` | Explicit human sign-off recorded in log |
| `budget_check` | Milestone spend within allocated budget |

---

## 5. Orchestration

Workflows live in `workflows/` as YAML files. A workflow defines the phase pipeline
for a repeating work pattern (sprint, feature, incident, sales cycle, etc.).

### Workflow Schema

```yaml
# workflows/{name}.yaml
name: string
description: string
trigger: manual | scheduled | event    # What starts the workflow
schedule: cron-expression              # If trigger: scheduled

phases:
  - id: phase-id
    name: string
    owner: agent-id                    # Accountable agent
    evidence_gate: string              # Milestone gate type (Section 4)
    signal_threshold: 0.0–1.0         # Minimum S/N score to advance
    agents:                            # Activation sequence
      - wave: 1                        # Parallel within a wave
        activate: [agent-id, agent-id]
      - wave: 2
        activate: [agent-id]
    max_retries: number                # Dev↔QA loop limit
    timeout_hours: number
    on_failure: escalate | retry | skip | stop

handoffs:
  standard:
    template: handoff-standard
  qa_pass:
    template: handoff-qa-pass
  qa_fail:
    template: handoff-qa-fail
    max_retries: 3
  escalation:
    template: handoff-escalation
    notify: [agent-id]
  phase_gate:
    template: handoff-phase-gate
    requires_human: false
  sprint:
    template: handoff-sprint
  incident:
    template: handoff-incident
    notify: [ceo, cto]
```

### Handoff Templates

All 7 handoff types use a structured template. Agents MUST NOT freeform handoffs.

```markdown
## Handoff: {type}
**From:** {agent}  **To:** {agent}  **Phase:** {phase}

### Work Completed
- [item]

### Decisions Made
- [decision] — rationale: [why]

### Artifacts Produced
- [artifact-name]: [location or inline]

### Evidence Gate Status
- [ ] {gate-type}: {status}

### Open Items / Blockers
- [item]

### Signal Quality
- S/N score: {score}  Mode: {mode}  Genre: {genre}

### Next Agent Instructions
[Explicit instructions for the receiving agent]
```

### Dev↔QA Loop

When a workflow has a `qa_fail` handoff with `max_retries`, the loop operates as:

```
Dev → QA review → FAIL → back to Dev (retry_count++)
                → PASS → advance to next phase
                → max_retries exceeded → escalate
```

Max retries exceeded triggers `escalation` handoff regardless of workflow config.

### Signal Theory Quality Gates

Every phase transition applies an S/N gate. The gate rejects output when:

1. Any of the 5 Signal dimensions (M, G, T, F, W) is unresolved
2. Filler phrases detected (flagged by S/N scorer)
3. Output genre mismatches the receiving agent's expected input genre
4. Shannon violation: output length exceeds 2x the minimum required to convey intent

Rejected output is returned to the producing agent with a structured rejection notice:

```markdown
## S/N Rejection Notice
**Agent:** {agent-id}  **Phase:** {phase}  **Score:** {score}

### Violations Detected
- {violation-type}: {description}

### Required Corrections
1. [correction]

Resubmit after corrections. Retry {n} of {max}.
```

---

## 6. Governance

### Board Approval Gate

The following actions require board approval before execution:

| Action | Trigger | Approval Required From |
|--------|---------|----------------------|
| New agent hire | `agents/` file added | Board quorum |
| Budget increase > 20% | `company.yaml` monthly_usd change | Board quorum |
| New workflow to production | `workflows/` file merged to main | CTO + CEO |
| Scope change on active Initiative | Initiative modified | CEO |

Board quorum = majority of agents with `role: board`.

### Activity Log

All activity is appended to `logs/activity.log` in append-only format. Entries are
never deleted or modified. Format:

```
{ISO8601} | {agent-id} | {action-type} | {resource} | {outcome} | {cost_usd}
```

Log types: `agent_call`, `task_transition`, `handoff`, `budget_event`, `approval_request`,
`approval_decision`, `escalation`, `phase_gate`, `sn_rejection`.

### Escalation Chain

Escalation traverses `reportsTo` upward until an available agent handles it.
If the chain is exhausted without resolution, the incident is written to
`logs/escalations.log` and a human notification is sent (channel defined in adapter config).

```
Triggering agent → reportsTo → reportsTo → ... → board → human notification
```

---

## 7. Skills

Skills are engine-backed slash commands reusable across Operations. Agents declare
which skills they load via the `skills` field in their frontmatter (Section 3).
The value is a list of skill slugs that correspond to directories under `skills/`.

### Directory Layout

```
skills/
└── {skill-name}/
     ├── SKILL.md       # Spec + usage
     └── impl.ex        # Elixir implementation (or impl.sh, impl.js per adapter)
```

### SKILL.md Schema

```markdown
# {Skill Name}

## Command
/{skill-slug} [args]

## Purpose
One sentence.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|

## Output
Genre + format of output produced.

## Engine Integration
Which engine commands this skill wraps.

## Examples
/{skill-slug} example-arg
```

### Standard Skill Library

| Skill | Command | What It Does |
|-------|---------|-------------|
| search | `/search <query>` | FTS5 search across knowledge base |
| ingest | `/ingest <text>` | Classify, route, write, index signal |
| assemble | `/assemble <topic>` | Tiered context bundle for a topic |
| health | `/health` | 10-check knowledge base diagnostic |
| reweave | `/reweave <topic>` | Find stale contexts, suggest updates |
| graph | `/graph [triangles\|clusters\|hubs]` | Knowledge graph analysis |
| reflect | `/reflect` | Co-occurring entities without edges |
| remember | `/remember <obs>` | Capture observation into learning loop |
| rethink | `/rethink <topic>` | Synthesize when evidence >= threshold |
| simulate | `/simulate` | Scenario planning |
| impact | `/impact` | Impact analysis on proposed change |

---

## 8. Reference

Domain knowledge loaded on-demand. Not injected at session start unless `context_tier: full`.

```
reference/
├── {domain}.md         # Human-readable domain knowledge
└── {domain}.yaml       # Machine-readable structured reference
```

Reference files are loaded by agents via:
- Explicit tool call: `mix optimal.read "optimal://reference/{file}" --tier l1`
- Workflow phase config: `load_reference: [file-slug]`
- Agent frontmatter: `context_tier: l1` (loads all agent-relevant reference at L1)

### Tiered Loading for Reference

| Tier | Token Budget | When to Use |
|------|-------------|-------------|
| L0 | ~100 tokens | Always-loaded abstract |
| L1 | ~2K tokens | Phase entry, context assembly |
| full | Unlimited | Deep analysis, synthesis tasks |

Never load `full` when L1 suffices. Token budget is finite.

---

## 9. Marketplace

Operations are exportable as versioned bundles. A bundle is a deployable artifact
that can be sold, shared, or imported into any compatible OSA instance.

### Bundle Format

```
operation-bundle.zip
├── manifest.yaml        # Bundle metadata
├── company.yaml         # Company definition
├── SYSTEM.md            # Agent system entry point
├── agents/              # All agent definitions
├── skills/              # All skills
├── reference/           # Domain knowledge
├── workflows/           # Orchestration pipelines
├── tasks/               # Example/template tasks (optional)
└── examples/            # Sample inputs/outputs
```

### manifest.yaml Schema

```yaml
name: string
slug: string
version: semver           # "1.2.0"
description: string
price_usd: number         # 0 = free
author:
  name: string
  id: string
  url: string
tags: [string]
adapter_compatibility: [osa, claude-code, openclaw, cursor]
min_osa_version: string
changelog:
  - version: string
    date: ISO8601
    notes: string
dependencies:             # Other bundles this one requires
  - slug: string
    version: semver-range
```

### Import/Export Commands

```bash
# Export current Operation as bundle
mix optimal.bundle export --output ./my-operation-v1.0.0.zip

# Import bundle into current workspace
mix optimal.bundle import ./downloaded-bundle.zip

# Validate bundle before import
mix optimal.bundle validate ./downloaded-bundle.zip

# List installed bundles
mix optimal.bundle list
```

### Versioning

Bundles follow semver. Breaking changes (agent signature changes, removed skills,
company schema changes) require a major version bump. Additive changes are minor.
Patches are bug fixes only.

---

## 10. Adapters

An adapter is the runtime that executes an agent. Operations are runtime-agnostic —
the same agent definition runs on any supported adapter without modification.

### Supported Adapters

| Adapter | ID | Entry Point | Notes |
|---------|-----|-------------|-------|
| OSA Native | `osa` | `SYSTEM.md` | Full feature support including engine |
| Claude Code | `claude_code` | `CLAUDE.md` | Bridge via CLAUDE.md injection |
| OpenClaw | `openclaw` | Gateway API | Requires gateway credentials |
| Cursor | `cursor` | `.cursor/rules` | Limited to editor context |
| Codex | `codex` | API adapter | No file system access |
| Gemini | `gemini` | API adapter | No file system access |

### Adapter Capability Matrix

| Capability | OSA | Claude Code | OpenClaw | Cursor |
|------------|-----|------------|----------|--------|
| Engine commands | Full | Via mix | Gateway | No |
| File system R/W | Full | Full | No | Limited |
| Session persistence | Full | Partial | No | No |
| Budget enforcement | Full | Manual | Gateway | No |
| Org chart routing | Full | Manual | Gateway | No |
| S/N scoring | Full | Manual | No | No |
| Workflow phases | Full | Manual | Gateway | No |

### Claude Code Bridge

When `adapter: claude_code`, the agent's body is injected into `CLAUDE.md` under
the relevant section. The bridge maps:

| Agent field | CLAUDE.md location |
|-------------|-------------------|
| Identity & Memory | `## IDENTITY` section |
| Core Mission | `## CAPABILITIES` section |
| Critical Rules | `## RULES` section |
| Skills | `## COMMANDS` section |
| Signal encoding | Appended to output instructions |

---

## 11. Session Persistence

Agents maintain conversation state across runs. State is serialized at session end
and deserialized at session start.

### Session State Schema

```yaml
# sessions/{agent-id}/{session-id}.yaml
agent_id: string
session_id: uuid
started_at: ISO8601
last_active: ISO8601
token_count: number
phase: string                   # Current workflow phase
task_id: string                 # Active task
working_memory:                 # Key-value store, arbitrary agent state
  key: value
pending_handoffs: [handoff]     # Outbound handoffs not yet delivered
```

### Compaction Protocol

When `token_count` exceeds the compaction threshold (default: 90% of context window),
the session codec compacts the conversation:

1. Summarize completed phases into `working_memory.phase_summaries`
2. Retain last N turns verbatim (default N=10)
3. Compress intermediate turns to L0 abstracts
4. Write compacted state to `sessions/{agent-id}/{session-id}.compacted.yaml`
5. Continue session from compacted state

Compaction is lossless for decisions, artifacts, and handoffs. It is lossy for
intermediate reasoning — by design. Reasoning is noise once a decision is made.

### Serialize / Deserialize

```bash
# Serialize session state (called at session end)
mix optimal.session serialize --agent deal-strategist --session abc123

# Deserialize and resume (called at session start)
mix optimal.session resume --agent deal-strategist --session abc123

# List sessions for an agent
mix optimal.session list --agent deal-strategist

# Prune sessions older than N days
mix optimal.session prune --days 30
```

### Cross-Agent State Sharing

Agents share state only via handoffs (Section 5) and the knowledge base (Section 8).
Direct state sharing between agents is not permitted — it bypasses the activity log
and breaks governance. All inter-agent communication is a recorded handoff.

---

## 12. Directory Layout

Complete Operation directory structure:

```
{operation-root}/
├── manifest.yaml               # Bundle metadata (Section 9)
├── company.yaml                # Company definition (Section 2)
├── SYSTEM.md                   # Agent system entry point
│
├── agents/                     # Agent definitions (Section 3)
│    ├── executive/             # Agents above the division layer
│    │    └── ceo.md
│    └── {division}/            # Organized by hierarchy
│         └── {department}/
│              └── {team}/
│                   └── {agent-id}.md
│
├── divisions/                  # Division manifests (protocol/division-format.md)
│    └── {division-id}.md
│
├── departments/                # Department manifests (protocol/department-format.md)
│    └── {division-id}/
│         └── {department-id}.md
│
├── teams/                      # Team manifests (protocol/team-format.md)
│    └── {team-id}.md
│
├── projects/                   # Standalone project definitions (protocol/project-format.md)
│    └── {project-id}/
│         └── PROJECT.md
│
├── workflows/                  # Orchestration pipelines (Section 5)
│    ├── sprint.yaml
│    ├── incident.yaml
│    └── {workflow}.yaml
│
├── skills/                     # Engine-backed commands (Section 7)
│    └── {skill-name}/
│         ├── SKILL.md
│         └── impl.ex
│
├── reference/                  # Domain knowledge (Section 8)
│    ├── {domain}.md
│    └── {domain}.yaml
│
├── tasks/                      # Active + template tasks (Section 4)
│    ├── {ISSUE_PREFIX}-{n}.yaml
│    └── manifests/             # Reusable task manifests (protocol/task-format.md)
│         └── {task-id}.md
│
├── sessions/                   # Persisted agent sessions (Section 11)
│    └── {agent-id}/
│         └── {session-id}.yaml
│
├── logs/                       # Immutable governance logs (Section 6)
│    ├── activity.log
│    └── escalations.log
│
└── examples/                   # Sample inputs/outputs for marketplace
     └── {scenario}.md
```

### File Ownership

| File/Dir | Writable By | Writable At |
|----------|------------|-------------|
| `company.yaml` | CEO agent + board | Governance approval |
| `agents/` | Board | Board approval |
| `divisions/` | Board | Board approval |
| `departments/` | Board | Board approval |
| `teams/` | Board | Board approval |
| `projects/` | Project owner agent | Workflow phase only |
| `workflows/` | CTO agent | CTO + CEO approval |
| `tasks/` | All agents | Any time |
| `tasks/manifests/` | CTO agent | Board approval |
| `sessions/` | Assigned agent | Own session only |
| `logs/` | System only | Append only, never delete |
| `reference/` | Designated knowledge agent | Workflow phase only |
| `skills/` | CTO agent | Board approval |

---

## See Also

| File | What it covers |
|------|---------------|
| `protocol/agent-format.md` | Detailed agent definition standard including all frontmatter fields |
| `protocol/division-format.md` | Division manifests — strategic envelope, cross-department coordination, budget ceilings |
| `protocol/department-format.md` | Department manifests — domain ownership, cross-team coordination, budget ceilings |
| `protocol/team-format.md` | Team manifests — coordination patterns, escalation rules, budget ceilings |
| `protocol/project-format.md` | Standalone project definitions — goals, milestones, risk registers |
| `protocol/task-format.md` | Task manifest standard — recurring tasks, acceptance criteria, evidence gates |
| `protocol/company-format.md` | Company definition and governance schema |

---

*OSA Operations Spec v1.0 — OptimalOS reference layer*

---

## Signal Theory Position

This spec **spans all 7 layers** of the Optimal System architecture. An Operation IS a portable Optimal System — it contains every layer in deployable format.

| Layer | Where It Lives in an Operation |
|-------|-------------------------------|
| L1 Network | `agents/` + `reportsTo` org chart — the node topology and routing edges |
| L2 Signal | `signal:` frontmatter field — each agent's default S=(M,G,T,F,W) encoding |
| L3 Composition | Agent body sections (Identity, Mission, Rules, Methodology, Templates) — micro-structure within each signal |
| L4 Interface | Tiered context loading (`l0` / `l1` / `full`) — progressive disclosure as the interface contract |
| L5 Data | `reference/`, `tasks/`, `sessions/` — the file substrate that stores and persists organizational state |
| L6 Feedback | Phase gates, S/N scoring, and the Dev→QA loop — the feedback mechanism at every workflow transition |
| L7 Governance | `company.yaml` + board approval gates + `logs/activity.log` — System 5 (Policy) encoded in YAML |

All 4 governing principles apply simultaneously: Beer (viable structure in the org), Shannon (tiered loading respects bandwidth), Ashby (agent variety must match operational variety), Wiener (every handoff closes a feedback loop).

See `architecture/optimal-system-mapping.md` for the canonical layer mapping.
