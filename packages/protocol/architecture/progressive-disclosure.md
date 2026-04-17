# Progressive Disclosure Model

> How Canopy loads context in tiers — from lightweight catalog discovery to
> full resource activation. The system that keeps context windows focused and
> token budgets under control without sacrificing depth when depth is needed.

---

## The Problem

An Operation with 20 agents, 15 skills, 10 reference files, 5 teams, and 8
project manifests contains roughly 350,000 tokens of definition content. Loading
all of it at session start would exhaust a significant fraction of the context
window before the agent executes a single task.

Most of that content is irrelevant to any given task. The engineering team's
coordination patterns are noise when an agent is analyzing a sales pipeline.
The security reference is noise when an agent is writing editorial content.

Progressive disclosure solves this: every entity in the workspace has a
**lightweight representation** (a catalog entry) and a **full representation**
(its complete file). The agent loads catalog entries always. It loads full
representations on demand, only for entities that are relevant to the current task.

This is the same design principle as `tiered-loading.md` applied to the
workspace's structural entities — agents, teams, projects, tasks, skills —
rather than to knowledge base resources.

---

## Three Tiers

```
┌─────────────────────────────────────────────────────────────────────┐
│  Tier 0 — Catalog                                                   │
│  ~100 tokens per entity                                             │
│  Name, id, description, type, status — from frontmatter only       │
│  Loaded at session boot. Always present.                            │
├─────────────────────────────────────────────────────────────────────┤
│  Tier 1 — Activation                                                │
│  ~2K tokens per entity                                              │
│  Full frontmatter + body sections for relevant entities             │
│  Loaded when relevance is detected. Cached with 10 min TTL.         │
├─────────────────────────────────────────────────────────────────────┤
│  Tier 2 — Full                                                      │
│  All referenced resources, scripts, assets                          │
│  Loaded only for deep work — editing, synthesis, debugging          │
│  Variable size. Not cached.                                         │
└─────────────────────────────────────────────────────────────────────┘
```

### Tier Definitions

| Tier | Name | Token Cost | Cache | When Loaded |
|------|------|-----------|-------|-------------|
| 0 | Catalog | ~100 per entity | ETS, session lifetime | Always, at boot |
| 1 | Activation | ~2K per entity | LRU, 10 min TTL | On relevance detection |
| 2 | Full | Variable | None | Explicit request or deep task |

The `context_tier` field in an agent's frontmatter declares the agent's **default**
tier. An agent with `context_tier: l0` is always present in the catalog but never
auto-loaded to L1. An agent with `context_tier: l1` is auto-loaded when invoked.
An agent with `context_tier: full` is always loaded completely — use this only for
orchestrators that genuinely need full context at all times.

---

## Tier 0: Catalog

The catalog answers one question: "What exists in this workspace and what is it?"

### What Goes in a Catalog Entry

For each entity type, the catalog entry is derived entirely from frontmatter fields:

**Agent catalog entry**
```yaml
type: agent
id: backend-architect
name: Backend Architect
role: engineer
title: Senior Backend Architect
reportsTo: cto
team: engineering
context_tier: l1
signal_summary: code + spec + commit
```

**Team catalog entry**
```yaml
type: team
id: engineering
name: Engineering
manager: cto
member_count: 5
budget: 3000
```

**Project catalog entry**
```yaml
type: project
id: q2-launch
name: Q2 Platform Launch
owner: tech-lead
team: engineering
status: active
milestone_count: 3
next_milestone: mvp (2026-04-01)
```

**Task manifest catalog entry**
```yaml
type: task-manifest
id: monday-review
name: Monday Review
assignee: ceo
type: recurring
schedule: "0 9 * * 1 America/Chicago"
priority: medium
```

**Skill catalog entry**
```yaml
type: skill
id: code-review
command: /code-review
description: Structured code review with scoring
```

Each catalog entry is approximately 100 tokens. A workspace with 20 agents,
10 skills, 5 teams, 8 projects, and 15 task manifests has a catalog of ~58 entries
at ~5,800 tokens — well within the L0 budget.

### Catalog Generation

Catalogs are pre-computed at workspace boot or when files change:

```
Workspace boot
  → Scan agents/*.md, teams/*.md, projects/**/PROJECT.md,
        tasks/manifests/*.md, skills/*/SKILL.md
  → Extract frontmatter from each file
  → Compress into catalog entries (~100 tokens each)
  → Sort by relevance score (recency + invocation frequency)
  → Cache in ETS with session TTL
```

Catalog entries do not include the Markdown body. Agents that know entities exist
but have not yet loaded their L1 representation see only the catalog entry.

---

## Tier 1: Activation

Activation loads the full manifest for a relevant entity. This includes all
frontmatter fields plus the complete Markdown body — mission, coordination
patterns, instructions, acceptance criteria, and everything else defined in the
protocol files.

### Activation Triggers

An entity transitions from Tier 0 (catalog) to Tier 1 (activation) when any
of these conditions are met:

| Trigger | Example |
|---------|---------|
| Agent is directly invoked or addressed | "Ask the code-reviewer to check this" |
| Agent is `assignee` on the active task | Task assigned to `code-reviewer` |
| Team is the owner of the active project | Active project `team: engineering` |
| Project is in the active task's frontmatter | Task `project: q2-launch` |
| Task manifest is being instantiated | Cron fires for `monday-review` |
| Skill is invoked by name | `/code-review` executed |
| Cross-reference in an already-loaded L1 entity | Engineering team L1 mentions `backend-architect` |

### Skill Loading at Activation

When an agent is activated to L1, the skills listed in its frontmatter `skills`
field are also loaded. If those skills reference external sources (see External
References, `workspace-protocol.md`), the reference is resolved at this point.

Skill loading at agent activation means the agent immediately has its full
capability set available. Skills are not loaded separately on first use — they
are part of the activation payload.

### L1 Token Budget

The total L1 budget per task session is 20K–50K tokens depending on the
operation's configuration. The runtime uses LRU eviction when the budget is
exceeded: the least-recently-used L1 entity is evicted to make room for the
newly activated one.

```
L1 budget: 40,000 tokens (configurable in company.yaml or SYSTEM.md)
Agent average: ~2,000 tokens
Skills average: ~500 tokens each
Headroom for 8-10 activated entities simultaneously
```

---

## Tier 2: Full

Tier 2 loads everything referenced by an activated entity — all imported skills,
external references, linked documents, asset files, and configuration.

Tier 2 is appropriate for:
- An orchestrator agent synthesizing across many entities
- A task that requires editing an agent definition
- Deep debugging of a workflow that spans multiple agents
- Onboarding a new agent with full workspace context injection

Tier 2 is never loaded automatically. It requires either an explicit request from
an agent tool call, or a task with `context_tier: full` declared in the manifest.

---

## The Resolution Graph

When the runtime processes a workspace, it follows a resolution graph to determine
what to load at each tier:

```
Operation
  └── Teams (Tier 0 catalog always; Tier 1 when team's project is active)
       └── Agents (Tier 0 always; Tier 1 when activated)
            └── Skills (loaded when parent agent activates)
                 └── References (loaded when skill is invoked)
  └── Projects (Tier 0 catalog always; Tier 1 when project is active)
       └── Task Manifests (Tier 0 catalog always; Tier 1 when instantiated)
  └── company.yaml (always loaded in full — it is always small)
  └── SYSTEM.md (always loaded in full — it is the entry point)
```

### Resolution Order at Session Boot

```
1. Load company.yaml (full — always small)
2. Load SYSTEM.md (full — always small)
3. Scan all entity files → build Tier 0 catalog
4. Identify active tasks from tasks/*.yaml
5. For each active task:
   a. Activate the assignee agent to Tier 1
   b. Activate the task's project to Tier 1 (if present)
   c. Activate the task manifest to Tier 1 (if instantiated from one)
6. For each activated agent: load its skills
7. Agent is ready to execute
```

### Resolution Order During Execution

```
Agent receives a request
  → Check active L1 entities: does any match?
    YES → Execute using existing L1 context
    NO  → Check Tier 0 catalog: does any entity match?
           YES → Activate to Tier 1 (LRU evict if budget exceeded)
                 → Execute
           NO  → Agent uses judgment without entity-specific context
```

---

## context_tier Field

The `context_tier` field in agent frontmatter sets the agent's default tier
preference. This is a hint to the runtime about how frequently this agent is
needed:

| Value | Meaning | When to Use |
|-------|---------|-------------|
| `l0` | Catalog only; never auto-activate | Rarely-used specialists; low-priority reference agents |
| `l1` | Activate when invoked or assigned | Standard agents — most agents should use this |
| `full` | Always load fully | Primary orchestrators that always need complete context |

`l0` agents are visible to the runtime (they appear in the catalog) but their
body is never loaded unless explicitly requested. Use `l0` for agents that
exist in the operation but are rarely invoked — a board member, a compliance
reviewer, a one-off specialist.

`full` agents consume significant context budget at all times. Reserve `full`
for the agent that is always active — typically the orchestrator or CEO agent.
A typical operation should have at most 1-2 agents at `full`.

---

## Token Budget Summary

| Entity Type | Tier 0 | Tier 1 | Notes |
|------------|--------|--------|-------|
| Agent | ~100 tokens | ~2K tokens | Skills add ~500 tokens each at T1 |
| Team | ~80 tokens | ~1.5K tokens | |
| Project | ~100 tokens | ~1.5K tokens | Risk register adds volume |
| Task manifest | ~80 tokens | ~1K tokens | Output template adds volume |
| Skill | ~60 tokens | ~500 tokens | impl file adds significant tokens at T2 |
| Reference file | ~80 tokens | ~2K tokens | Full reference loads at T2 |

### Typical Session Budget (20-entity operation)

```
Tier 0 catalog:       20 entities × ~80 tokens avg   =  ~1,600 tokens
company.yaml (full):                                  =    ~800 tokens
SYSTEM.md (full):                                     =  ~1,500 tokens
Active L1 entities:   5 agents + 3 skills + 2 teams  = ~14,500 tokens
                                                       ─────────────
                                                       ~18,400 tokens total
```

A typical session uses under 20,000 tokens on workspace structure, leaving
over 980,000 tokens for reasoning, task execution, and knowledge base content.

---

## Relationship to Tiered Loading

Progressive disclosure for workspace entities is the structural counterpart to
tiered loading for knowledge base resources (see `architecture/tiered-loading.md`).
The mechanics are the same — L0/L1/L2 tiers, relevance scoring, LRU eviction —
but the domains differ:

| System | Domain | Source |
|--------|--------|--------|
| Tiered Loading | Knowledge base resources (documents, contexts, notes) | `architecture/tiered-loading.md` |
| Progressive Disclosure | Workspace entities (agents, teams, projects, skills) | This file |

Both systems share the same tier naming convention and the same `context_tier`
vocabulary. An agent's `context_tier` field in its frontmatter applies to the
progressive disclosure system, not to tiered loading — the tiered loading system
manages knowledge resources independently.

---

## Interface Layer Position

Progressive disclosure implements **Layer 4 (The Interface)** of the Optimal System — the decoding surface through which information is presented to agents.

- **L0/L1/L2 tiers ARE Shannon constraint enforcement** — token budgets ensure the agent's context window (channel) is not overloaded
- **`context_tier` field IS autonomy-appropriate information density** — L1 agents get activation context, L5 agents can request full resources
- **LRU eviction IS Ashby's variety engineering** — when context capacity is finite, the system maintains requisite variety by keeping the most relevant signals and evicting the least relevant
- The tiered loading model IS bandwidth matching (Encoding Principle 6): match output density to the receiver's decoding capacity

See `architecture/optimal-system-mapping.md` for the full 7-layer mapping.

---

## See Also

- `architecture/tiered-loading.md` — Tiered loading for knowledge base resources
- `protocol/agent-format.md` — `context_tier` field in agent frontmatter
- `protocol/team-format.md` — Team manifests loaded via progressive disclosure
- `protocol/project-format.md` — Project manifests loaded via progressive disclosure
- `protocol/task-format.md` — Task manifests loaded via progressive disclosure
- `architecture/sessions.md` — Session state and how L1 entities are tracked across sessions

---

*Progressive Disclosure Model v1.0 — Context tier management for OSA Operations entities*
