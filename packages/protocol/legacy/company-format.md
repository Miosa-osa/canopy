# Company Format Standard

> The standard for defining a company in OSA Operations. Company orchestration
> model with Signal Theory governance extensions.

## Overview

Every Operation root contains `company.yaml`. This file is the source of truth for
the organizational envelope — mission, budget, governance, and goal hierarchy.

## Schema

```yaml
# company.yaml
name: string                    # Display name ("Acme Agency")
slug: string                    # URL-safe identifier ("acme")
description: string             # One sentence
mission: string                 # North star statement

budget:
  monthly_usd: number           # Total monthly budget cap
  per_agent_usd: number         # Default per-agent budget (overridden in agent frontmatter)
  enforcement: visibility | warning | stop

governance:
  board_approval_required:
    - new_agent_hire
    - budget_increase_pct: 20
    - new_workflow_production
  immutable_log: true
  escalation_chain:
    - ceo
    - cto
    - board

issue_prefix: string            # Task ID prefix ("ACM-", "PRJ-")

goals:
  initiatives:
    - id: INI-001
      title: string
      description: string
      projects:
        - id: PRJ-001
          title: string
          milestones:
            - id: MIL-001
              title: string
              evidence_gate: tests_pass | review_approved | signal_score | human_approval | budget_check
```

## Budget Model

### Enforcement Tiers

| Tier | Threshold | Behavior |
|------|-----------|----------|
| `visibility` | 0% | Log spend, no action |
| `warning` | 80% of monthly cap | Alert escalation chain |
| `stop` | 100% of monthly cap | Block new agent calls, require board override |

Per-agent `budget` in agent frontmatter overrides `per_agent_usd`. Agent-level
enforcement is independent of company-level enforcement.

### Cost Tracking

All agent API calls are logged with cost in `logs/activity.log`:

```
{ISO8601} | {agent-id} | agent_call | {resource} | {outcome} | {cost_usd}
```

Monthly rollup is available via `/budget-report` skill (if installed).

## Goal Hierarchy

```
Initiative  (north star — months to years)
  └── Project  (workstream — weeks to months)
       └── Milestone  (checkpoint — days to weeks, has evidence gate)
            └── Task  (atomic unit — hours to days, assigned to one agent)
                 └── Sub-task  (breakdown — minutes to hours)
```

### Evidence Gates

A Milestone is not complete until its evidence gate is satisfied:

| Gate Type | What It Checks |
|-----------|---------------|
| `tests_pass` | All tests in scope green |
| `review_approved` | N designated reviewers approved |
| `signal_score` | S/N score >= threshold on all deliverables |
| `human_approval` | Explicit human sign-off recorded in log |
| `budget_check` | Milestone spend within allocated budget |

## Governance

### Board Approval Gate

| Action | Trigger | Approval Required From |
|--------|---------|----------------------|
| New agent hire | `agents/` file added | Board quorum |
| Budget increase > 20% | `company.yaml` monthly_usd change | Board quorum |
| New workflow to production | `workflows/` file merged | CTO + CEO |
| Scope change on active Initiative | Initiative modified | CEO |

Board quorum = majority of agents with `role: board`.

### Activity Log

All activity is appended to `logs/activity.log` in append-only format:

```
{ISO8601} | {agent-id} | {action-type} | {resource} | {outcome} | {cost_usd}
```

Log types: `agent_call`, `task_transition`, `handoff`, `budget_event`,
`approval_request`, `approval_decision`, `escalation`, `phase_gate`, `sn_rejection`.

Entries are never deleted or modified.

### Escalation Chain

Escalation traverses `reportsTo` upward:

```
Triggering agent -> reportsTo -> reportsTo -> ... -> board -> human notification
```

If the chain is exhausted without resolution, the incident is written to
`logs/escalations.log` and a human notification is sent.

## Organizational Hierarchy

The full hierarchy has 5 layers: Company → Division → Department → Team → Agent.
`company.yaml` defines the company envelope. The layers below are defined in their
own protocol specs and instantiated as files in the operation:

```
company.yaml                              # Company-level config
├── divisions/{id}.md                     # 5 divisions (division-format.md)
│   └── departments/{division}/{id}.md    # 20 departments (department-format.md)
│       └── teams/{id}.md                 # 43 teams (team-format.md)
│           └── agents/{division}/{department}/{team}/{id}.md # 169 agents (agent-format.md)
```

| Layer | Spec | Governs |
|-------|------|---------|
| Company | `company-format.md` | Mission, total budget, governance policy |
| Division | `division-format.md` | Strategic envelope, division budget ceiling, cross-department coordination |
| Department | `department-format.md` | Domain ownership, department budget ceiling, cross-team coordination |
| Team | `team-format.md` | Operational coordination, team budget, agent composition |
| Agent | `agent-format.md` | Individual behavior, signal encoding, tool access |

Budget enforcement cascades downward: company → division → department → team → agent.
The most restrictive limit in the chain applies at every moment.

## Org Chart

The org chart is composed from `reportsTo` fields across all agent files.
`company.yaml` does not define the org chart directly — it emerges from agent
definitions. The CEO agent (`reportsTo: null`) is the root. Division heads report
to the CEO. Department heads report to division heads. Team managers report to
department heads. Team members report to team managers.

Rules:
- Must be a directed acyclic graph (no cycles)
- Root node is always the CEO with `reportsTo: null`
- Every agent must have a path to the root via `reportsTo`
- Escalation always traverses upward

## Example

```yaml
name: Acme Dev Shop
slug: acme-dev
description: AI-powered software development agency
mission: Ship production-quality software faster than any human team

budget:
  monthly_usd: 5000
  per_agent_usd: 500
  enforcement: warning

governance:
  board_approval_required:
    - new_agent_hire
    - budget_increase_pct: 25
  immutable_log: true
  escalation_chain:
    - cto
    - ceo

issue_prefix: ACME-

goals:
  initiatives:
    - id: INI-001
      title: Launch MVP
      description: Ship v1.0 of the client's SaaS platform
      projects:
        - id: PRJ-001
          title: Core API
          milestones:
            - id: MIL-001
              title: Auth system complete
              evidence_gate: tests_pass
            - id: MIL-002
              title: API endpoints deployed
              evidence_gate: review_approved
```

## Validation Rules

A `company.yaml` is valid if:

1. `name`, `slug`, `description`, `mission` are non-empty strings
2. `budget.monthly_usd` > 0
3. `budget.enforcement` is one of: `visibility`, `warning`, `stop`
4. `governance.escalation_chain` has at least one entry
5. All initiative/project/milestone IDs are unique
6. Evidence gates reference valid gate types
7. `issue_prefix` ends with `-` and is uppercase

---

## Signal Theory Position

This spec implements **Layer 1 (Network) + Layer 7 (Governance)** of the Optimal System architecture.

`company.yaml` defines the Signal Network topology. The org chart that emerges from `reportsTo` fields is a directed graph of signal-carrying nodes — departments are subnets, agents are endpoints, and budget ceilings constrain signal throughput at each node. The file does not merely describe an organization; it encodes the network's routing rules.

The governance block — board approval gates, escalation chains, and budget enforcement tiers — IS System 5 (Policy) encoded in YAML. These rules constrain what every downstream agent and team can do, making `company.yaml` the policy anchor for the entire Operation.

**Most relevant governing principles:**
- **Beer (organizational structure as recursive VSM)** — The initiative → project → milestone → task hierarchy mirrors the 5-subsystem VSM recursion: each level is viable on its own while remaining coherent with the level above.
- **Wiener (escalation chains close feedback loops)** — The `escalation_chain` field is a Wiener feedback mechanism: failures propagate upward until a capable handler is found or a human is notified.

See `architecture/optimal-system-mapping.md` for the canonical layer mapping.
