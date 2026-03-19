# Company Setup Guide

> How to configure the organizational envelope that turns a collection of agents
> into a governed AI business.

---

## What Is company.yaml?

`company.yaml` is Layer 5 of the stack -- the organizational envelope. It defines:

- **Who** the company is (name, mission)
- **How much** it can spend (budget)
- **What rules** it follows (governance)
- **What it wants** to achieve (goals)

Without company.yaml, you have agents but no organization. The company file adds
the structure that makes agents accountable to budgets, governed by approval gates,
and directed toward measurable goals.

---

## company.yaml Schema

Here is the complete schema with all fields:

```yaml
# === IDENTITY ===
name: My AI Company                    # Human-readable name
slug: my-ai-company                    # URL-safe identifier (kebab-case)
description: >                         # What this company does (1-2 sentences)
  AI-powered code review service
  for SaaS companies.
mission: >                             # The north star (1 sentence)
  Ship zero-bug releases through
  automated, context-aware code review.

# === BUDGET ===
budget:
  monthly_usd: 5000                    # Total monthly spend ceiling
  per_agent_usd: 800                   # Default per-agent ceiling
  enforcement: warning                 # warning | soft_cap | hard_cap

# === GOVERNANCE ===
governance:
  board_approval_required:             # Actions that need board approval
    - new_agent_hire
    - budget_increase_pct: 20          # Threshold for budget change approval
    - new_workflow_production
  immutable_log: true                  # Activity log cannot be modified
  escalation_chain:                    # Who gets escalations, in order
    - tech-lead
    - board

# === TASK MANAGEMENT ===
issue_prefix: "MAS-"                   # Prefix for task IDs (e.g., MAS-001)

# === GOALS ===
goals:
  initiatives:
    - id: INI-001
      title: Ship MVP to Production
      projects:
        - id: PRJ-001
          title: Core Platform Build
          milestones:
            - id: MIL-001
              title: Architecture design approved
              evidence_gate: review_approved
            - id: MIL-002
              title: MVP feature-complete
              evidence_gate: tests_pass
```

---

## Organizational Structure

### Agent Hierarchy

The org chart is defined by the `reportsTo` field in each agent's YAML frontmatter.
The company.yaml does not list agents -- it provides the envelope they operate within.

A typical org structure:

```
board (human)
  └── ceo (agent, reportsTo: board)
       ├── cto (agent, reportsTo: ceo)
       │    ├── tech-lead (agent, reportsTo: cto)
       │    ├── frontend-dev (agent, reportsTo: tech-lead)
       │    ├── backend-dev (agent, reportsTo: tech-lead)
       │    └── qa-engineer (agent, reportsTo: tech-lead)
       └── cro (agent, reportsTo: ceo)
            ├── prospector (agent, reportsTo: cro)
            └── closer (agent, reportsTo: cro)
```

### Departments

Departments are implicit -- defined by the directory structure of `agents/`:

```
agents/
├── engineering/       <- Engineering department
│   ├── tech-lead.md
│   ├── frontend-dev.md
│   └── backend-dev.md
├── sales/             <- Sales department
│   ├── prospector.md
│   └── closer.md
└── product/           <- Product department
    └── product-manager.md
```

### Roles

Each agent has a `role` field that maps to workflow phase ownership. Multiple agents
can share the same role. The role determines which workflow phases the agent can own.

| Role | Typical Phases |
|------|---------------|
| `architect` | Design, Architecture Review |
| `developer` | Build |
| `tester` | Test, QA |
| `reviewer` | Code Review |
| `lead` | Planning, Review, Escalation |
| `prospector` | Research, Outreach |
| `closer` | Discovery, Demo, Proposal, Negotiate, Close |

### Reporting Lines

The `reportsTo` chain determines:

1. **Escalation path** -- When an agent is blocked, escalation traverses up the chain
2. **Delegation authority** -- Managers can assign tasks to their reports
3. **Review authority** -- Managers review and approve their reports' work

The top-level agent (usually CEO or equivalent) reports to `board`.
The board is always a human.

---

## Budget Configuration

### Budget Hierarchy

Budgets cascade from company to agent:

```
company.monthly_usd: $5000 (total ceiling)
  └── per_agent_usd: $800 (default per agent)
       ├── tech-lead: $1200 (override in agent YAML)
       ├── frontend-dev: $800 (uses default)
       ├── backend-dev: $800 (uses default)
       └── qa-engineer: $600 (override in agent YAML)
```

The company monthly total is the hard ceiling. Per-agent budgets are enforced
individually -- an agent hitting its ceiling does not affect other agents.

### Enforcement Tiers

| Tier | Behavior |
|------|----------|
| `warning` | Agent continues but dashboard shows warning. Board notified. |
| `soft_cap` | Agent completes current run then pauses. Board can resume. |
| `hard_cap` | Agent immediately paused. Current run aborts after grace period. |

Start with `warning` while you learn your cost patterns. Move to `soft_cap`
once you have baseline data. Use `hard_cap` only when cost overruns are unacceptable.

### Cost Tracking

Every agent run records costs:

```
{ISO8601} | {agent-id} | cost_entry | {task-id} | $0.15 | {tokens}
```

Costs are attributed to:
- **Agent** -- who ran
- **Task** -- what they worked on
- **Project** -- which initiative the task belongs to

This enables cost analysis at every level: "How much did the frontend-dev
spend on the MVP project this month?"

### Budget Sizing Guide

| Operation Type | Typical Monthly Budget | Why |
|---------------|----------------------|-----|
| Solo dev (3-4 agents) | $1,000-3,000 | Low volume, simple workflows |
| Dev shop (6-8 agents) | $5,000-10,000 | Regular builds, CI/CD, reviews |
| Sales engine (5 agents) | $3,000-6,000 | Research + outreach volume |
| Content factory (4-6 agents) | $2,000-5,000 | Content production cadence |
| Full operation (15+ agents) | $10,000-25,000 | Multiple departments, high volume |

---

## Governance and Approval Gates

### What Requires Board Approval

Configure in `governance.board_approval_required`:

```yaml
governance:
  board_approval_required:
    - new_agent_hire              # Adding a new agent to the org
    - budget_increase_pct: 20    # Budget increases over 20%
    - new_workflow_production     # Deploying a new workflow
    - production_database_migration  # Domain-specific gates
    - brand_voice_change         # Domain-specific gates
    - discount_above_pct: 15     # Domain-specific gates
```

You can add any custom approval gate. The system treats them as strings --
your agents' rules sections determine when to trigger them.

### Approval Flow

```
Agent proposes action that requires approval
  -> Approval request created (logged immutably)
  -> Board notified via dashboard
  -> Board reviews:
     -> APPROVE: action executes, logged
     -> REJECT: agent notified with reason, logged
     -> No response: reminder escalation after timeout
```

### Immutable Logging

When `immutable_log: true`, all activity is recorded in append-only log files:

```
logs/
├── activity.log        # All agent actions, task transitions, cost entries
└── escalations.log     # Unresolved escalations
```

These logs cannot be modified or deleted. They provide:
- Post-incident analysis
- Cost attribution
- Governance compliance audit trail
- Performance review data

---

## Board Powers and Controls

The board (human operator) has unrestricted access at all times:

| Power | Effect |
|-------|--------|
| Set/modify budgets | Immediate -- takes effect on next budget check |
| Pause agent | Graceful stop + block future heartbeats |
| Resume agent | Re-enable heartbeats, process deferred queue |
| Pause work item | Item and descendants not picked up by agents |
| Resume work item | Items re-enter active pool |
| Full task management | Create, edit, comment, delete, reassign |
| Override agent decisions | Reassign tasks, change priorities |
| Approve/reject proposals | Hiring, strategy, budget changes |
| Terminate agent | Permanent removal from org |

### The Board Philosophy

The board is a control surface, not an approval bottleneck. The system is designed to:

1. **Run autonomously** within configured constraints
2. **Surface problems** to the board (not silently fix them)
3. **Require approval** only for high-stakes actions
4. **Allow intervention** at any level at any time

Automatic recovery hides failures. The board exists to make judgment calls
that agents should not make alone.

---

## Scaling From Solo to Team

### Solo Operator (1 human, 3-5 agents)

```yaml
name: Solo Dev Studio
budget:
  monthly_usd: 2000
  per_agent_usd: 500
  enforcement: warning

governance:
  board_approval_required:
    - new_agent_hire
  immutable_log: true
  escalation_chain:
    - board
```

At this scale, all agents report directly to the board. No manager agents needed.
Keep it flat. The human is the tech lead, product manager, and CEO.

### Small Team (1-2 humans, 6-10 agents)

```yaml
name: Small Dev Shop
budget:
  monthly_usd: 8000
  per_agent_usd: 1200
  enforcement: soft_cap

governance:
  board_approval_required:
    - new_agent_hire
    - budget_increase_pct: 20
    - new_workflow_production
  immutable_log: true
  escalation_chain:
    - tech-lead
    - board
```

Add a tech-lead or director agent to handle orchestration. Agents report to the
lead, who reports to the board. The human handles strategic decisions and approvals.

### Growing Operation (2-5 humans, 10-20 agents)

```yaml
name: AI Development Agency
budget:
  monthly_usd: 20000
  per_agent_usd: 1500
  enforcement: hard_cap

governance:
  board_approval_required:
    - new_agent_hire
    - budget_increase_pct: 15
    - new_workflow_production
    - production_database_migration
  immutable_log: true
  escalation_chain:
    - department-lead
    - cto
    - board
```

Multiple departments, each with a lead agent. Deeper escalation chains.
Tighter budget enforcement. More approval gates. The humans focus on
strategy, governance, and client relationships.

---

## Goals and Initiatives

The goals section structures what the company wants to achieve:

```
Initiative (high-level strategic objective)
  └── Project (a body of work toward the initiative)
       └── Milestone (a measurable checkpoint)
            └── Evidence Gate (proof the milestone is met)
```

### Goal Hierarchy

```yaml
goals:
  initiatives:
    - id: INI-001
      title: Ship MVP to Production
      projects:
        - id: PRJ-001
          title: Core Platform Build
          milestones:
            - id: MIL-001
              title: Architecture design approved
              evidence_gate: review_approved
            - id: MIL-002
              title: API contracts locked
              evidence_gate: tests_pass
            - id: MIL-003
              title: MVP feature-complete
              evidence_gate: tests_pass
```

### Evidence Gates on Milestones

Each milestone has an evidence gate that determines when it is complete:

| Gate | Meaning |
|------|---------|
| `review_approved` | A designated reviewer has signed off |
| `tests_pass` | Automated test suite passes with required coverage |
| `signal_score` | Output achieves minimum S/N quality score |
| `human_approval` | Board or stakeholder explicitly approves |
| `budget_check` | Work completed within budget constraints |

### Tasks Map to Projects

Runtime tasks (in `tasks/`) reference project IDs. This allows cost and
progress tracking from task level up to initiative level:

```
Initiative: Ship MVP
  └── Project: Core Platform Build ($4,200 spent)
       ├── MIL-001: Architecture ✓ (approved)
       ├── MIL-002: API contracts ✓ (tests pass)
       └── MIL-003: Feature-complete ⟳ (in progress, $2,800 spent)
            ├── Task DS-001: User auth (completed, $400)
            ├── Task DS-002: Dashboard (in progress, $350)
            └── Task DS-003: API layer (todo)
```

---

## Company Setup Checklist

- [ ] `name` and `slug` are set (slug is unique, kebab-case)
- [ ] `description` is 1-2 sentences
- [ ] `mission` is a single clear sentence
- [ ] `budget.monthly_usd` is set with realistic ceiling
- [ ] `budget.per_agent_usd` default makes sense for your agents
- [ ] `budget.enforcement` tier matches your risk tolerance
- [ ] `governance.board_approval_required` lists high-stakes actions
- [ ] `governance.immutable_log` is true (no reason to disable)
- [ ] `governance.escalation_chain` reflects your org hierarchy
- [ ] `issue_prefix` is short and unique (2-4 characters)
- [ ] Goals have at least one initiative with measurable milestones
- [ ] Evidence gates are assigned to every milestone
- [ ] Agent `reportsTo` chains resolve correctly (no dangling references)
- [ ] Total per-agent budgets do not exceed company monthly budget
