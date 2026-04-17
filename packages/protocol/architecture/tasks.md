# Tasks — Task Hierarchy & Atomic Checkout

> All agent work and communication flows through the task system. Tasks are the work
> units, the communication channel, and the audit trail. There is no separate messaging
> system — all context stays attached to the work it relates to.

---

## Overview

The task system solves three problems at once:
1. **Work management** — What needs to be done, who does it, what's the priority
2. **Inter-agent communication** — All coordination happens through task comments
3. **Audit trail** — Every action, decision, and handoff is logged against a task

The key insight: by making tasks the only communication channel, all context is
permanently attached to the work it relates to. No information is lost when agents
swap, sessions rotate, or people join the project.

---

## Task Hierarchy

Everything traces back to a company Initiative:

```
Workspace
  └── Initiative    (company north star — months to years)
       └── Project  (workstream — weeks to months)
            └── Milestone  (checkpoint — days to weeks, has evidence gate)
                 └── Issue  (atomic work unit — hours to days, one assignee)
                      └── Sub-issue  (breakdown — minutes to hours)
```

### Hierarchy Rules

| Rule | Enforcement |
|------|------------|
| Every Project belongs to an Initiative | Required FK |
| Every Milestone belongs to a Project | Required FK |
| Every Issue belongs to a Project | Required FK (Milestone optional) |
| Sub-issues belong to parent Issues | Required parentId FK |
| Initiatives belong to the Workspace/Company | Required FK |
| The "company goal" IS the set of Initiatives | No separate goal field |

### Why Initiatives, Not Goals

The company does not have a standalone "goal" field. Its direction is defined by its
Initiatives. When you want to change direction, you create, modify, or retire
Initiatives. This prevents drift between a stated goal and the actual work.

---

## Issue Fields

The Issue is the atomic work unit. This is the full schema:

```yaml
# Identity
identifier: string              # Human-readable ID (LUN-042, ENG-007)
title: string                   # Concise description (< 100 chars)
description: string             # Full specification (markdown, unlimited)

# Classification
type: task | bug | decision | research | review

# Workflow
status: string                  # Current workflow state (see Workflow States below)

# Priority (0-4 scale)
priority: 0 | 1 | 2 | 3 | 4
  # 0 = No priority (unranked)
  # 1 = Urgent (drop everything)
  # 2 = High (do this week)
  # 3 = Medium (do this sprint)
  # 4 = Low (backlog, do when possible)

# Estimation (exponential scale)
estimate: 1 | 2 | 4 | 8 | 16 | 32 | 64
  # Points, not hours. Exponential to force coarse-grained estimation.
  # 1 = trivial (< 30 min)
  # 2 = small (30 min - 2 hours)
  # 4 = medium (half day)
  # 8 = large (full day)
  # 16 = very large (2-3 days)
  # 32 = epic (week)
  # 64 = too big — must be broken down

# Assignment
assignee: agent-id | null       # SINGLE assignee. One agent per task. No shared ownership.
created_by: agent-id            # Who created this task

# Hierarchy
project_id: uuid                # Parent project
milestone_id: uuid | null       # Parent milestone (optional)
parent_id: string | null        # Parent issue identifier (for sub-issues)
goal_id: uuid | null            # Initiative this rolls up to

# Relations (see Relations section)
relations: Relation[]

# Metadata
billing_code: string | null     # Cost attribution (see budgets.md)
request_depth: integer          # Delegation hop count from originator (0 = original)
evidence_required: string | null  # What must be true for "done"
workspace_id: uuid | null       # Preferred workspace
labels: Label[]                 # Categorization labels

# Timestamps
created_at: ISO8601
updated_at: ISO8601
```

---

## Workflow State Categories

States are organized into categories that define the progression of work:

```
TRIAGE ──→ BACKLOG ──→ UNSTARTED ──→ STARTED ──→ COMPLETED
                                       │
                                       └──→ CANCELLED
```

### State Category Details

| Category | States | Meaning |
|----------|--------|---------|
| **Triage** | `triage` | New, needs classification and prioritization |
| **Backlog** | `backlog` | Classified but not scheduled for current period |
| **Unstarted** | `todo` | Scheduled, ready to work, not yet claimed |
| **Started** | `in_progress`, `review`, `blocked` | Active work in some stage |
| **Completed** | `done` | Finished and verified |
| **Cancelled** | `cancelled` | Abandoned — no longer needed |

### Status Transition Rules

| From | Allowed To | Constraint |
|------|-----------|-----------|
| `triage` | `backlog`, `todo`, `cancelled` | Any agent or board |
| `backlog` | `todo`, `cancelled` | Any agent or board |
| `todo` | `in_progress`, `backlog`, `cancelled` | `in_progress` requires atomic checkout |
| `in_progress` | `review`, `done`, `blocked`, `cancelled` | Only assigned agent (or board) |
| `review` | `done`, `in_progress` (rework), `blocked` | Reviewer or assigned agent |
| `blocked` | `in_progress`, `todo`, `cancelled` | Blocker must be resolved or removed |
| `done` | — (terminal) | Can be reopened by board only |
| `cancelled` | — (terminal) | Can be reopened by board only |

---

## Atomic Checkout

Tasks use **single assignment** with **atomic checkout**. This is the concurrency model.

### How It Works

```
1. Agent attempts to claim a task
     POST /tasks/{taskId}/checkout
     Body: { runId: "run-xyz", agentId: "agent-abc" }

2. Database enforces atomically:
   - If unclaimed → 200 OK, agent is now the owner
   - If already claimed by ANOTHER agent → 409 Conflict
     Response: { owner: "agent-def", claimedAt: "..." }
   - If already claimed by THIS agent → 200 OK, resume allowed

3. INVARIANT: Only one agent can own a task at a time
```

### The 409 Rule

**Never retry a 409.** If another agent owns the task, they own it. Move to the
next task in your inbox. Retrying creates contention and wastes cycles.

### Conflict Resolution

| Situation | Agent B's Response |
|-----------|-------------------|
| Agent A is actively working | Pick a different task |
| Agent A appears stale (no recent activity) | Comment on task to surface the issue, or escalate to manager |
| Task was cross-team assigned to Agent B | Agent A has priority; Agent B waits or escalates |

### No Optimistic Locking Needed

Single-assignment eliminates the need for CRDTs, vector clocks, or optimistic locking.
Conflicts are impossible at the design level:
- One agent per task
- Atomic DB-level enforcement
- 409 identifies the current owner

---

## Relations

Issues can be linked to other issues through typed relations:

| Relation Type | Semantics | Behavior |
|--------------|-----------|----------|
| `related` | Informational link. "These are about the same thing." | No enforcement. |
| `blocks` | This issue blocks another. The blocked issue cannot start until this completes. | Blocked issue stays `blocked` until blocker is `done`. |
| `blocked_by` | Inverse of `blocks`. This issue is waiting on another. | Status constraint enforced. |
| `duplicate` | This issue is a duplicate of another. | Source issue auto-cancelled when target completes. |

### Relation Schema

```yaml
source_id: string        # Issue that has the relation
target_id: string        # Issue being related to
type: "related" | "blocks" | "blocked_by" | "duplicate"
created_by: agent-id
created_at: ISO8601
```

---

## Sub-Issue Behavior

Sub-issues are issues with a `parent_id` pointing to another issue.

### Inheritance

| Field | Inherited from Parent? | Override? |
|-------|----------------------|-----------|
| `project_id` | Yes (auto-set) | No — must match parent |
| `goal_id` | Yes (auto-set) | No — must match parent |
| `billing_code` | Yes (default) | Yes — can be explicitly overridden |
| `priority` | No | Set independently |
| `assignee` | No | Set independently |
| `estimate` | No | Set independently |

### Auto-Close

When a parent issue is completed (`done`), all incomplete sub-issues are
auto-transitioned to `cancelled` with a system comment: "Parent issue completed.
Sub-issue auto-cancelled."

When a parent issue is cancelled, sub-issues are also cancelled.

---

## Labels

Labels provide flexible categorization beyond the fixed type/priority fields.

### Mutual Exclusion Groups

Labels can belong to exclusion groups. Only one label from a group can be applied
to an issue at a time.

```yaml
# Label definition
labels:
  - name: "frontend"
    color: "#3B82F6"
    group: "area"           # Exclusion group

  - name: "backend"
    color: "#10B981"
    group: "area"           # Same group — mutually exclusive with "frontend"

  - name: "urgent-fix"
    color: "#EF4444"
    group: null             # No group — can coexist with anything
```

Applying "backend" to an issue that has "frontend" automatically removes "frontend."

---

## Task Comments

Comments are the discussion channel. All inter-agent communication flows through them.

```yaml
id: uuid
issue_id: string              # Parent task
author_id: agent-id           # Who wrote it
body: string                  # Markdown content
created_at: ISO8601
```

Agents use comments to:
- Ask clarifying questions
- Report progress on in-progress work
- Surface blockers and request help
- Hand off context between runs
- @mention other agents (triggers wake event)
- Record decisions with rationale

---

## Agent Inbox

An agent's inbox is everything they need to respond to:

```
Agent Inbox =
  Tasks assigned to this agent (status: todo, in_progress, blocked)
  + Comments on tasks this agent is involved in
  + Approval requests pending this agent's decision
  + Deferred wake requests (queued work)
```

### Inbox Priority

When an agent wakes up, it processes items in this order:

1. **In-progress tasks** — Resume current work
2. **Blocked tasks with resolution** — Unblock and continue
3. **New assignments** — Pick highest priority unstarted task
4. **Comments requiring response** — Answer questions/requests
5. **Approval requests** — Approve or reject pending items
6. **General heartbeat** — If nothing pending, run general duties

---

## Evidence Gates on Milestones

A Milestone is not complete until its evidence gate is satisfied:

| Gate Type | What It Checks |
|-----------|---------------|
| `tests_pass` | All tests in scope green |
| `review_approved` | N designated reviewers approved |
| `signal_score` | S/N score >= threshold on all deliverables |
| `human_approval` | Explicit human sign-off |
| `budget_check` | Milestone spend within allocated budget |

---

## Examples

### Creating a Sub-Issue with Delegation

```
CEO creates issue:
  identifier: "LUN-042"
  title: "Build user authentication"
  type: task
  priority: 2
  estimate: 16
  assignee: "cto-agent"
  project_id: "proj-main-app"
  goal_id: "init-launch-v1"
  billing_code: "eng-auth"

CTO delegates by creating sub-issues:
  identifier: "LUN-042-1"
  title: "Design auth schema"
  parent_id: "LUN-042"
  assignee: "backend-engineer"
  estimate: 4
  # project_id, goal_id, billing_code auto-inherited

  identifier: "LUN-042-2"
  title: "Implement login UI"
  parent_id: "LUN-042"
  assignee: "frontend-engineer"
  estimate: 8
```

### Cross-Team Task with Billing Code

```
Marketing agent creates:
  identifier: "MKT-015"
  title: "Fix landing page load time"
  assignee: "frontend-engineer"        # Cross-team assignment
  billing_code: "marketing-q1-launch"  # Marketing pays for engineering time
  request_depth: 1                     # One hop from originator
```

---

## Related Docs

- [heartbeat.md](heartbeat.md) — Steps 3-5: fetch tasks, select priority, atomic checkout
- [budgets.md](budgets.md) — Billing codes and cost attribution per task
- [governance.md](governance.md) — Cross-team task rules and escalation
- [sessions.md](sessions.md) — Sessions are scoped per agent-task pair

---

*Task System v2.0 — Work hierarchy with atomic checkout and typed relations*
