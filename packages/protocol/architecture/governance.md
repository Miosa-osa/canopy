# Governance — Board Powers & Approval Gates

> The human oversight layer. The Board is not just an approval gate — it is a live
> control surface with unrestricted authority. The human can intervene at any level
> at any time. The system surfaces problems; it does not silently fix them.

---

## Overview

Governance solves the "who controls the agents" problem. Without it, agents operate
autonomously with no human oversight. The governance layer provides:

1. **Board powers** — Unrestricted control over every aspect of the system
2. **Approval gates** — Actions that require human sign-off before execution
3. **Escalation protocol** — How problems traverse the org chart to resolution
4. **Activity logging** — Immutable audit trail of every mutation
5. **Crash recovery philosophy** — Surface problems, don't auto-fix them

---

## Board Model

### V1: Single Human Board

One human operator controls the entire system. Future versions may support
multi-member boards, but V1 is deliberately simple.

The Board has **unrestricted access** to everything, always. No time limits,
no scope restrictions, no approval needed for Board actions.

---

## Board Powers

Available at all times, from any view in the system.

| Power | Scope | Effect |
|-------|-------|--------|
| **Create agents** | Company | Add new agents to the organization |
| **Pause agent** | Single agent | Graceful stop + block future heartbeats |
| **Resume agent** | Single agent | Re-enable heartbeats, drain deferred queue |
| **Terminate agent** | Single agent | Permanent removal from org (irreversible) |
| **Set/modify budgets** | Company, project, agent | Immediate — changes take effect on next budget check |
| **Override budgets** | Any level | Raise limits, resume paused agents, approve overspend |
| **Pause work item** | Task, project, milestone, subtask tree | Paused items not picked up by agents |
| **Resume work item** | Task, project, milestone, subtask tree | Items re-enter active pool |
| **Full task management** | Any task/project/milestone | Create, edit, comment, delete, reassign, reprioritize |
| **Override agent decisions** | Any agent's work | Reassign tasks, change priorities, modify descriptions |
| **Approve/reject proposals** | Pending approval items | Hiring, strategy, budget increases |

### Pause Mechanics (Agents)

```
Board pauses Agent X:
  1. Current run receives graceful termination signal
  2. Grace period (configurable, default 30s) for agent to save state
  3. Force-kill if agent doesn't stop within grace period
  4. All future heartbeats blocked
  5. Deferred wake requests preserved (not discarded)
  6. Agent status → "paused" in dashboard
```

### Pause Mechanics (Work Items)

When the Board pauses a work item (task/project/milestone):
- The item and all descendants are marked `paused`
- No agent can claim or work on paused items
- In-progress work on paused items continues to completion (current run only)
- Next heartbeat will not pick up paused tasks

---

## Approval Gates

These actions require Board approval before execution:

| Action | Triggers When | Who Approves |
|--------|--------------|-------------|
| **New agent hire** | Any agent creates a new agent definition | Board |
| **CEO strategic breakdown** | CEO proposes initial plan (org structure, hiring, task decomposition) | Board |
| **Budget increase > threshold** | Budget increase exceeds configured % (default 20%) | Board |
| **New workflow to production** | Workflow file promoted to production use | CTO + CEO |
| **Scope change on active Initiative** | Initiative definition modified after work has started | CEO |

### Approval Types (Enum)

```
hire_agent              — New agent creation
approve_ceo_strategy    — CEO's strategic plan/org proposal
budget_override_required — Budget limit increase
workflow_promotion      — Workflow goes live
initiative_scope_change — Active initiative modified
```

### Approval State Machine

```
┌──────────┐     ┌──────────┐
│ PENDING  │────→│ APPROVED │  (action executes)
└────┬─────┘     └──────────┘
     │
     ├─────────→┌──────────┐
     │          │ REJECTED │  (agent notified with reason)
     │          └──────────┘
     │
     └─────────→┌────────────────────┐
                │ REVISION_REQUESTED │  (agent revises and resubmits)
                └────────────────────┘
```

### Approval Record Schema

```yaml
id: uuid
type: string                    # hire_agent, approve_ceo_strategy, etc.
status: pending | approved | rejected | revision_requested
requested_by: agent-id          # Who proposed the action
requested_at: timestamp
reviewed_by: uuid | null        # Board member who reviewed
reviewed_at: timestamp | null
reason: text | null             # Rejection/revision reason
payload: jsonb                  # The proposed action details
entity_type: string             # What entity this affects
entity_id: uuid                 # Which entity
```

### Approval Flow

```
Agent proposes action
  → Approval request created (status: pending)
  → Board notified (dashboard badge + optional webhook/email)
  → Board reviews proposal
    → APPROVE → Action executes, agent notified
    → REJECT → Agent notified with reason, proposal archived
    → REVISION_REQUESTED → Agent revises, resubmits (new approval cycle)
  → No response → Reminder escalation after configurable timeout
```

---

## Board Mutation Guard

All mutations that affect system state are validated server-side against a permission
model. The Board mutation guard ensures:

1. **Authentication** — Every mutation has an authenticated actor (agent or board member)
2. **Authorization** — The actor has permission for the specific mutation
3. **Logging** — Every mutation produces an immutable activity log entry
4. **Validation** — Mutation payload is schema-valid before execution

### Guard Enforcement

```
Mutation request arrives
  → Authenticate actor (JWT verification)
  → Check actor permissions against mutation type
  → Validate payload against schema
  → Execute mutation
  → Write activity log entry
  → Return result
```

Board members bypass authorization checks (unrestricted access) but still produce
activity log entries. Agent mutations are checked against their role permissions.

---

## Activity Logging

Every mutation in the system produces an immutable audit log entry. Entries are
**never deleted or modified**. Append-only.

### Log Entry Schema

```yaml
id: uuid
timestamp: ISO8601
actor_id: uuid                  # Who performed the action (agent or board member)
actor_type: "agent" | "board"   # Actor classification
entity_type: string             # What was affected (agent, task, budget, etc.)
entity_id: uuid                 # Which entity
action: string                  # What was done (see Action Types below)
outcome: string                 # Result (success, denied, error)
cost_usd: decimal | null        # Associated cost (if applicable)
metadata: jsonb                 # Additional context (varies by action type)
```

### Action Types

| Type | What It Records |
|------|----------------|
| `agent_call` | Agent heartbeat invocation (start + end) |
| `task_transition` | Task status change (backlog → todo → in_progress → ...) |
| `task_assignment` | Task assigned or reassigned |
| `handoff` | Inter-agent handoff (phase transition) |
| `budget_event` | Budget threshold crossed, budget modified |
| `approval_request` | Action submitted for Board approval |
| `approval_decision` | Board approved or rejected |
| `escalation` | Escalation fired and traversal path |
| `phase_gate` | Workflow phase evidence gate checked |
| `sn_rejection` | Signal Theory S/N gate rejected output |
| `agent_pause` | Agent paused (by board or budget) |
| `agent_resume` | Agent resumed |
| `agent_terminate` | Agent permanently removed |
| `cost_entry` | Token/dollar cost recorded |
| `board_override` | Board overrode an agent decision |

---

## Escalation Protocol

Escalation traverses the org chart upward until resolution:

```
Triggering agent
  → reports_to (direct manager)
    → reports_to (manager's manager)
      → ... (traverse up)
        → CEO
          → Board
            → Human notification (if Board doesn't respond)
```

### When Escalation Fires

| Trigger | Example |
|---------|---------|
| Agent blocked on cross-team task | Agent B cannot do what Agent A requested |
| Budget exceeded | Agent hits hard ceiling mid-task |
| Repeated failures | Same task fails N times |
| Max retries exceeded | Dev/QA review loop hits limit |
| Unresolvable conflict | Two agents disagree on approach |
| Orphaned work | Task in_progress with no recent activity |

### Escalation Record

```yaml
id: uuid
source_agent_id: uuid           # Who triggered the escalation
resource_type: string            # What's being escalated (task, budget, conflict)
resource_id: uuid                # Which resource
traversal_path: uuid[]           # Chain of managers traversed
resolved_by: uuid | null         # Who resolved it
resolved_at: timestamp | null
outcome: text | null             # Resolution description
```

---

## Cross-Team Task Rules

Agents can create tasks assigned to agents outside their reporting line. These rules
govern cross-team work:

### Task Acceptance

| Situation | Agent Action |
|-----------|-------------|
| Agrees + can do it | Complete it directly |
| Agrees + cannot do it | Mark `blocked`, explain why |
| Questions whether it's worth doing | **Cannot cancel.** Must reassign to own manager with explanation. |

**Critical rule:** An agent can never unilaterally cancel a cross-team task. Only the
originating agent, their manager, or the Board can cancel. The receiving agent can
only accept, block, or escalate.

### Request Depth Tracking

```
Agent A creates task → depth 0
  Agent A assigns to Agent B → depth 1
    Agent B delegates to Agent C → depth 2
      Agent C delegates to Agent D → depth 3
```

High depth indicates potential process issues (work cascading too far from originator).

---

## Crash Recovery Philosophy

**The system reports problems. It does not silently fix them.**

### What the System Does

| Situation | System Response |
|-----------|----------------|
| Agent crashes mid-task | Task stays `in_progress`. Dashboard shows "stale" indicator. |
| Agent disappears | Run marked `errored` after timeout. Task not auto-released. |
| Multiple agents conflict | 409 on atomic checkout. Second agent picks another task. |
| Budget breach mid-run | Current run completes (sunk cost). Agent auto-paused after. |
| Network partition | Run logs stop streaming. Orphan detection triggers. |

### What the System Does NOT Do

- Auto-reassign stale tasks
- Auto-release in_progress locks
- Auto-retry failed runs
- Auto-rollback partial work
- Auto-restart crashed agents

All recovery is **manual** — by the Board, by a manager agent, or by the agent
itself on its next wake cycle. Automatic recovery hides failures.

---

## Agent Visibility

**Full visibility across the org.** Every agent can see the entire org chart, all tasks,
all agents. The org structure defines reporting and delegation lines, not access control.

Each agent publishes a short description of responsibilities and capabilities — a
skills directory that lets other agents discover who can help with what.

---

## VSM Position

Governance implements **Layer 7 (The Governance / VSM)** of the Optimal System — Beer's Viable System Model applied to AI agent organizations.

| VSM Subsystem | Governance Implementation |
|--------------|--------------------------|
| S5 (Policy) | Board powers, SYSTEM.md identity rules, immutable constraints |
| S4 (Intelligence) | CEO/orchestrator environmental scanning, strategic adaptation |
| S3 (Control) | Budget enforcement, approval workflows, resource allocation |
| S2 (Coordination) | Team coordination protocols, cross-agent scheduling |
| S1 (Operations) | Individual agent execution within governance constraints |

**Algedonic channel**: The escalation protocol IS the algedonic bypass — when normal channels are too slow or too noisy, critical signals route directly from the point of disturbance to the policy level (board/human operator).

**Autonomy levels**: Approval gates define the boundary between autonomy levels. An agent at Level 4 (Approver) operates independently but requires human gates for consequential actions. The governance spec encodes WHERE those gates fire.

See `architecture/optimal-system-mapping.md` for the full 7-layer mapping.

---

## Related Docs

- [heartbeat.md](heartbeat.md) — Pause behavior and orphaned run detection
- [budgets.md](budgets.md) — Budget breach triggers board notification
- [tasks.md](tasks.md) — Cross-team task rules and escalation triggers
- [team-coordination.md](team-coordination.md) — Multi-agent coordination patterns

---

*Governance v2.0 — Board authority, approval gates, and escalation protocol*
