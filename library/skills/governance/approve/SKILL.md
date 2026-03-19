---
name: approve
description: >
  Human-in-the-loop approval gates. Creates approval requests for high-stakes actions
  like hiring agents, strategy proposals, or budget overrides. Tracks states from
  pending through approved/rejected/revision_requested. Blocks execution until resolved.
  Triggers on: "approve", "approval", "review request", "sign off"
---

# /approve

> Human-in-the-loop approval gates for high-stakes decisions.

## Purpose

Some actions should not execute without human review. The approve skill creates structured approval requests, tracks their lifecycle, and blocks execution until a human makes a decision. Three approval types by default: `hire_agent` (adding compute cost), `strategy_proposal` (changing direction), `budget_override` (exceeding limits). Custom types supported.

## Usage

```bash
# Create an approval request
/approve --type hire_agent --summary "Spawn a deep researcher for patent analysis" --cost "~50K tokens"

# List pending approvals
/approve list

# Approve a request
/approve ok req-a1b2

# Reject with reason
/approve reject req-a1b2 --reason "Budget too tight this week"

# Request revision
/approve revise req-a1b2 --note "Reduce scope to 20K tokens"

# View approval history
/approve history --last 20

# Auto-approve low-risk actions
/approve policy set hire_agent --auto-approve-under 10000
```

## Arguments

| Subcommand | Description |
|------------|-------------|
| (default) | Create a new approval request |
| `list` | Show all pending approvals |
| `ok <req-id>` | Approve a request |
| `reject <req-id>` | Reject a request |
| `revise <req-id>` | Request revision |
| `history` | View past approvals |
| `policy` | Configure auto-approval rules |

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--type` | enum | required | `hire_agent`, `strategy_proposal`, `budget_override`, or custom |
| `--summary` | string | required | Human-readable description of what needs approval |
| `--cost` | string | — | Estimated cost (tokens, dollars, or time) |
| `--reason` | string | — | Rejection reason or revision note |
| `--note` | string | — | Additional context for revision request |
| `--last` | int | 10 | Number of history entries to show |
| `--auto-approve-under` | int | — | Auto-approve if cost below this threshold |
| `--urgency` | enum | `normal` | `critical`, `high`, `normal`, `low` |
| `--deadline` | duration | — | Approval needed by this time |
| `--requestor` | string | auto | Agent or person requesting approval |

## Workflow

### Creating a request
1. **Compose** — Build approval request: type, summary, cost estimate, requestor, urgency, deadline.
2. **Check policy** — If auto-approval rules exist for this type and cost is under threshold, auto-approve and log.
3. **Store** — Write request to `approvals/pending/{req-id}.json`.
4. **Notify** — Send to human's attention via highest-priority channel (terminal alert, inbox).
5. **Block** — Return request ID. The requesting agent/process must wait for resolution.

### Resolving
1. **Human decides** — Reviews request via `/approve list`, then runs `ok`, `reject`, or `revise`.
2. **Update state** — Move from `pending/` to `resolved/`. Record: decision, decider, timestamp, reason.
3. **Notify requestor** — Send resolution to the requesting agent's inbox.
4. **Unblock** — Requesting process resumes with the decision.

## Output

### Pending approvals
```markdown
## Pending Approvals (2)

### req-a1b2 | hire_agent | high urgency
**Summary:** Spawn a deep researcher for patent analysis
**Requestor:** orchestrator
**Cost:** ~50,000 tokens ($5.00)
**Submitted:** 2026-03-20 14:30
**Deadline:** 2026-03-20 16:00
**Blocking:** task-d4e5

→ `/approve ok req-a1b2` or `/approve reject req-a1b2 --reason "..."`

### req-c3d4 | budget_override | normal
**Summary:** Analyst agent requests 20K additional tokens for deep revenue analysis
**Requestor:** analyst (agent-e5f6)
**Cost:** 20,000 tokens ($2.00)
**Submitted:** 2026-03-20 14:35
**Deadline:** none

→ `/approve ok req-c3d4` or `/approve reject req-c3d4 --reason "..."`
```

## Dependencies

- File system for approval store (`approvals/pending/`, `approvals/resolved/`)
- `/inbox` — Notification delivery
- `/budget` — Cost estimation and budget checks
- Human operator availability
