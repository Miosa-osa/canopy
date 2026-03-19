# Budgets — 3-Tier Budget Enforcement

> Cost control at every execution boundary. The budget system enforces spending limits
> at three tiers: company, agent, and project. No agent run starts without passing
> a budget preflight check.

---

## Overview

Without budget enforcement, agents spend indefinitely. The 3-tier system provides
cascading limits: the company sets the ceiling, agents have individual caps, and
projects have lifetime bounds. At 80% usage, alerts fire. At 100%, the agent
auto-pauses and the board must intervene.

Budget checks happen at **every execution boundary** — not just heartbeat start,
but scheduler invocation, manual runs, wakeup processing, and task checkout. There
is no path to execution that bypasses the budget gate.

---

## Budget Hierarchy

```
┌─────────────────────────────────────────────────────┐
│ Tier 1: COMPANY BUDGET                               │
│ Period: Calendar month (recurring)                    │
│ Scope: All agent spending across the organization    │
│ Set by: Board                                         │
│ Override by: Board only                               │
├─────────────────────────────────────────────────────┤
│                                                       │
│  ┌───────────────────────┐  ┌──────────────────────┐ │
│  │ Tier 2: AGENT BUDGET  │  │ Tier 2: AGENT BUDGET │ │
│  │ Period: Calendar month│  │ Period: Calendar month│ │
│  │ (recurring)           │  │ (recurring)          │ │
│  │ Scope: One agent      │  │ Scope: One agent     │ │
│  │ Set by: Manager/Board │  │ Set by: Manager/Board│ │
│  └───────────┬───────────┘  └──────────┬───────────┘ │
│              │                          │              │
│  ┌───────────▼───────────┐  ┌──────────▼───────────┐ │
│  │ Tier 3: PROJECT BUDGET│  │ Tier 3: PROJECT      │ │
│  │ Period: Lifetime      │  │ BUDGET               │ │
│  │ (bounded, no reset)   │  │ Period: Lifetime     │ │
│  │ Scope: One project    │  │ (bounded)            │ │
│  │ Set by: CEO/Board     │  │ Set by: CEO/Board    │ │
│  └───────────────────────┘  └──────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

### Tier Details

| Tier | Scope | Period | Reset | Set By | Override By |
|------|-------|--------|-------|--------|------------|
| **1. Company** | All agents, all projects | Calendar month | Hard reset to $0 on period boundary | Board | Board only |
| **2. Agent** | Single agent's total spend | Calendar month (recurring) | Hard reset to $0 on period boundary | Agent's manager or Board | Manager's manager, CEO, or Board |
| **3. Project** | All work on a project | Lifetime (bounded) | Never resets — total spend accumulates | CEO or Board | Board |

### Hierarchy Rules

| Rule | Description |
|------|-------------|
| Company is the ceiling | No agent or project can exceed the company total |
| Agent budgets are independent | Agent A's budget does not affect Agent B's |
| Project budgets are additive | Multiple agents on one project share the project budget |
| Task costs attribute upward | A task's cost counts against both its agent AND its project |
| Cross-team billing | When Agent A asks Agent B to do work, B's costs track against A's billing code |

---

## Enforcement Thresholds

| Threshold | Trigger | Action |
|-----------|---------|--------|
| **0%** (always) | Visibility | Dashboards show spend at every level. No enforcement action. |
| **80%** (soft alert) | `budgetPercentUsed >= 0.80` | Alert fired to escalation chain. Agent continues working. Dashboard shows warning. |
| **100%** (hard stop) | `budgetPercentUsed >= 1.00` | Agent auto-paused. Current run completes (sunk cost). Board notified. Approval required to resume. |

### Preflight Enforcement Points

Budget is checked at **ALL execution boundaries**:

| Boundary | When | What Happens on Breach |
|----------|------|----------------------|
| Scheduler trigger | Before creating a run | Run not created. Agent paused. |
| Manual invoke | Before human-triggered run | Run blocked. UI shows budget error. |
| Wakeup processing | Before processing deferred wake | Wake deferred indefinitely. |
| Task checkout | Before atomic claim | Checkout denied. Task stays unclaimed. |

Budget is NOT checked mid-execution. Once a run starts, it completes. This prevents
partial work artifacts and simplifies the execution model. The cost is recorded
post-execution and may push past the ceiling — that triggers a pause for the NEXT cycle.

---

## What Counts (and What Doesn't)

| Billing Type | Description | Counts Toward Budget? |
|-------------|-------------|----------------------|
| `metered_api` | Pay-per-token API usage (Anthropic, OpenAI, etc.) | **Yes** |
| `subscription_overage` | Usage exceeding subscription plan limits | **Yes** |
| `subscription_included` | Usage within subscription plan (already paid) | **No** (recorded as $0) |
| `advisory` | Estimated or projected cost (not actual) | **No** (informational only) |
| `credits` | Pre-purchased credit pool consumption | Depends on config |
| `fixed` | Flat fee per adapter invocation | **Yes** |
| `unknown` | Cost data missing from adapter | **No** (recorded as $0, flagged in dashboard) |

### Token Usage Normalization

For session-based adapters, token counts are cumulative within a session. The system
normalizes to per-run deltas:

```
Run 1: raw total = 15,000 input → delta = 15,000 (first run)
Run 2: raw total = 28,000 input → delta = 13,000 (28,000 - 15,000)
Run 3: raw total = 45,000 input → delta = 17,000 (45,000 - 28,000)
```

This prevents double-counting cached tokens from prior turns in the same session.

---

## Budget Policy Data Model

### Budget Policy Record

```yaml
id: uuid
company_id: uuid
scope: "company" | "agent" | "project"
scope_id: uuid                    # agent_id or project_id (null for company)
budget_usd: decimal               # Dollar limit (null = unlimited)
period: "monthly" | "weekly" | "quarterly" | "lifetime"
soft_alert_threshold: 0.80        # Percentage (0.0 - 1.0)
hard_stop_threshold: 1.00         # Percentage (0.0 - 1.0)
rollover: false                   # Unused budget carries forward?
created_at: timestamp
updated_at: timestamp
```

### Budget Incident Record

Tracked when thresholds are crossed:

```yaml
id: uuid
budget_policy_id: uuid
incident_type: "soft_alert" | "hard_stop"
triggered_at: timestamp
spend_at_trigger_usd: decimal
budget_limit_usd: decimal
percent_used: decimal
agent_id: uuid                    # Which agent triggered it
run_id: uuid                      # Which run triggered it
resolution: "budget_raised" | "resume_once" | "kept_paused" | null
resolved_at: timestamp | null
resolved_by: uuid | null          # Board member who resolved
```

---

## Approval Resolution

When a hard stop fires, three resolution paths exist:

| Resolution | What Happens | Who Can Do It |
|-----------|-------------|---------------|
| **Raise budget** | Budget limit increased. Agent auto-resumed. Future spend allowed up to new limit. | Board |
| **Resume once** | Agent un-paused for one more run cycle. Budget limit unchanged. If still over after next run, re-paused. | Board |
| **Keep paused** | Agent stays paused until next budget period (reset to $0). | Default if no action taken. |

### Approval Flow

```
Agent hits 100% of budget
  → Agent auto-paused
  → Budget incident created
  → Board notified (dashboard badge + optional webhook/email)
  → Board reviews:
    → "This agent needs more runway" → Raise budget
    → "Let it finish current task" → Resume once
    → "Wait for reset" → Keep paused (or do nothing)
```

---

## Billing Codes

Tasks carry a billing code for cross-team cost attribution.

### How Billing Codes Work

```
Agent A creates task T1 with billing_code="team-a-project-x"
  → Agent A assigns T1 to Agent B
    → Agent B works on T1
    → Agent B's costs for T1 attributed to "team-a-project-x"
    → Team A sees the cost of work they requested from Team B
```

### Propagation

Sub-tasks inherit billing code from parent unless explicitly overridden:

```
T1 (billing_code: "marketing-campaign-q1")
  └── T1.1 (inherits: "marketing-campaign-q1")
       └── T1.1.1 (inherits: "marketing-campaign-q1")

T2 (billing_code: "eng-infrastructure")
  └── T2.1 (override: "eng-debt-reduction")  ← Explicit override
```

---

## Cost Ledger

Every cost entry is recorded in an immutable, append-only ledger.

### Ledger Entry Schema

| Field | Type | Description |
|-------|------|-------------|
| `id` | uuid | Entry identifier |
| `runId` | uuid | Which heartbeat run |
| `agentId` | uuid | Which agent |
| `companyId` | uuid | Which company |
| `issueId` | uuid | Which task (nullable) |
| `projectId` | uuid | Which project (nullable) |
| `billingCode` | string | Cost attribution (nullable) |
| `inputTokens` | integer | Input tokens consumed |
| `cachedInputTokens` | integer | Cached input tokens |
| `outputTokens` | integer | Output tokens consumed |
| `costCents` | integer | Cost in cents (USD x 100) |
| `billingType` | enum | metered_api, subscription_included, etc. |
| `biller` | string | Who billed (anthropic, openai, etc.) |
| `provider` | string | Model provider |
| `createdAt` | timestamp | When recorded |

### Scope Resolution

```
Run completed with contextSnapshot.issueId = "LUN-042"
  → Look up LUN-042 → projectId = "proj-abc"
  → Ledger entry: agentId, issueId=LUN-042, projectId=proj-abc
  → Cost rolls up to: agent total, task total, project total, company total
```

---

## Budget Delegation

| Level | Set By | Override By |
|-------|--------|------------|
| Company | Board | Board only |
| Project | CEO or Board | Board |
| Agent | Agent's manager | Manager's manager, CEO, or Board |
| Per-run limit | Agent config | Same as agent budget |

### Delegation Chain

```
Board sets $10,000/month company budget
  → CEO allocates $3,000 to Engineering team lead
    → Team lead allocates $1,000 each to 3 engineers
  → CEO allocates $2,000 to Sales team
  → CEO keeps $5,000 as reserve
```

A manager cannot allocate more than they have.

---

## Dashboard Metrics

| Level | Metrics |
|-------|---------|
| **Company** | Total spend (MTD), burn rate ($/day), budget utilization %, projected monthly |
| **Project** | Project spend (lifetime), cost per milestone, budget remaining |
| **Agent** | Agent spend (MTD), cost per run (avg), utilization %, runs this period |
| **Task** | Total cost of completion, cost per sub-task |

---

## Related Docs

- [heartbeat.md](heartbeat.md) — Budget check is step 1 of the heartbeat cycle
- [governance.md](governance.md) — Board powers for budget override and approval
- [tasks.md](tasks.md) — Billing codes on tasks for cross-team attribution
- [sessions.md](sessions.md) — Token tracking per session informs budget calculations

---

*Budget Enforcement v2.0 — 3-tier cost control with preflight enforcement*
