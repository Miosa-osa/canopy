# Self-Healing — Autonomous Error Recovery Protocol

> When agents fail, the system diagnoses and fixes itself. Ephemeral healing
> agents are spawned with budget caps, execute the lifecycle (pending → diagnosing
> → fixing → completed), and auto-terminate when done. Unresolvable failures
> escalate through the governance chain. The system monitors itself and intervenes
> before humans need to.

---

## Overview

Failures in a multi-agent system are inevitable. The question is not whether errors
occur but whether the system can recover without human intervention. Self-healing
provides that capacity.

When an error is detected — by the heartbeat protocol, a monitoring probe, or a
peer agent — the self-healing subsystem classifies it, spawns an ephemeral healing
agent with a budget cap, and tracks the healing lifecycle. The healing agent
diagnoses the root cause, applies a fix, verifies recovery, and terminates. If
diagnosis or fixing exceed the budget, or if the error is beyond autonomous
resolution, the subsystem escalates through the governance chain.

The design principle: **the system should exhaust autonomous options before
burdening humans**. Escalation is always available but never the first response.

---

## Error Classification

### 8 Categories

| Category | Code | Description | Examples |
|----------|------|-------------|---------|
| **Transient** | `ERR_TRANSIENT` | Temporary failures that resolve on retry | Network timeout, LLM rate limit, DB connection blip |
| **Resource** | `ERR_RESOURCE` | Budget exhaustion, quota exceeded, capacity unavailable | Token budget depleted, cost ceiling hit, no compute slots |
| **Configuration** | `ERR_CONFIG` | Misconfigured agent, adapter, or workspace | Missing env var, wrong adapter type, invalid system prompt |
| **Logic** | `ERR_LOGIC` | Agent produced output that violated invariants | Checkout conflict loop, circular delegation, invalid task state |
| **Data** | `ERR_DATA` | Corrupt, missing, or inconsistent data | Missing session file, corrupt task JSON, orphaned dependency |
| **External** | `ERR_EXTERNAL` | Third-party service failure | GitHub API down, Slack unavailable, embedding service timeout |
| **Security** | `ERR_SECURITY` | Authentication failure, authorization violation | Expired token, RBAC violation, suspicious pattern |
| **Unknown** | `ERR_UNKNOWN` | Unclassified error, no matching category | Unexpected exception type, unstructured error output |

### 4 Severities

| Severity | Code | Description | Default Action |
|----------|------|-------------|---------------|
| **Low** | `SEV_LOW` | Non-blocking, work continues | Log, schedule repair during next run |
| **Medium** | `SEV_MEDIUM` | Work degraded but not stopped | Spawn healing agent, continue current run |
| **High** | `SEV_HIGH` | Work blocked, agent cannot proceed | Spawn healing agent, pause current run |
| **Critical** | `SEV_CRITICAL` | System integrity at risk, viability threatened | Spawn healing agent, escalate to governance immediately |

### Retryability Matrix

| Category | Low | Medium | High | Critical |
|----------|-----|--------|------|---------|
| `ERR_TRANSIENT` | auto-retry (3×) | auto-retry (2×) | healing agent | escalate |
| `ERR_RESOURCE` | log only | healing agent | healing agent | escalate |
| `ERR_CONFIG` | healing agent | healing agent | healing agent | escalate |
| `ERR_LOGIC` | healing agent | healing agent | escalate | escalate |
| `ERR_DATA` | healing agent | healing agent | healing agent | escalate |
| `ERR_EXTERNAL` | auto-retry (3×) | auto-retry (2×) | healing agent | escalate |
| `ERR_SECURITY` | escalate | escalate | escalate | escalate |
| `ERR_UNKNOWN` | log only | healing agent | escalate | escalate |

Security errors never receive autonomous healing — they always escalate.

---

## Healing Lifecycle

Every healing episode is a tracked state machine.

### States

```
               ┌──────────┐
               │ PENDING  │  Error detected, healing agent not yet spawned
               └────┬─────┘
                    │ healing agent starts
                    ▼
               ┌──────────────┐
               │  DIAGNOSING  │  Agent analyzing root cause
               └──────┬───────┘
                      │ root cause identified
                      ▼
               ┌──────────────┐
               │   FIXING     │  Agent applying remediation
               └──────┬───────┘
                      │
            ┌─────────┼─────────────┐
            ▼         ▼             ▼
       ┌──────────┐ ┌──────────┐ ┌────────────┐
       │COMPLETED │ │  FAILED  │ │ ESCALATED  │
       │(verified)│ │(no fix)  │ │(governance)│
       └──────────┘ └──────────┘ └────────────┘
```

### State Transitions

| Transition | Trigger | Condition |
|-----------|---------|-----------|
| `pending → diagnosing` | Healing agent spawned and invoked | Healing agent process starts |
| `diagnosing → fixing` | Root cause identified | Agent produces `diagnosis_result` with `root_cause` |
| `diagnosing → escalated` | Diagnosis budget exhausted | Token spend ≥ diagnosis budget cap |
| `diagnosing → escalated` | Unresolvable category | `ERR_SECURITY`, `ERR_UNKNOWN` at High/Critical |
| `fixing → completed` | Fix verified | Agent confirms fix applied, verification probe passes |
| `fixing → failed` | Fix budget exhausted | Token spend ≥ fix budget cap without resolution |
| `fixing → escalated` | Fix attempted but failed | 3× fix attempts failed, or fix produced new errors |
| `failed → escalated` | Auto-escalate on failed | All `SEV_HIGH` and `SEV_CRITICAL` failed episodes escalate automatically |

### Episode Record

```elixir
defmodule SelfHealing.Episode do
  @type t :: %__MODULE__{
    id:               String.t(),
    company_id:       String.t(),
    team_id:          String.t(),
    failed_agent_id:  String.t(),
    failed_run_id:    String.t(),
    error_category:   atom(),
    error_severity:   atom(),
    error_message:    String.t(),
    error_code:       String.t() | nil,
    state:            :pending | :diagnosing | :fixing | :completed | :failed | :escalated,
    healing_agent_id: String.t() | nil,
    diagnosis_result: map() | nil,
    fix_result:       map() | nil,
    tokens_spent:     non_neg_integer(),
    budget_cap:       non_neg_integer(),
    attempt_count:    non_neg_integer(),
    started_at:       DateTime.t() | nil,
    completed_at:     DateTime.t() | nil,
    escalated_at:     DateTime.t() | nil,
    escalation_path:  [String.t()]
  }
end
```

---

## Ephemeral Healing Agents

Healing agents are ephemeral — they are created for a specific episode and
auto-terminate when the episode reaches a terminal state.

### Budget Caps

The healing budget is split between diagnosis and fixing:

```
Total healing budget = base_budget × error_severity_multiplier

base_budget (default by category):
  ERR_TRANSIENT:   5,000 tokens
  ERR_RESOURCE:    8,000 tokens
  ERR_CONFIG:      10,000 tokens
  ERR_LOGIC:       15,000 tokens
  ERR_DATA:        12,000 tokens
  ERR_EXTERNAL:    6,000 tokens
  ERR_UNKNOWN:     8,000 tokens

severity_multiplier:
  SEV_LOW:      0.5
  SEV_MEDIUM:   1.0
  SEV_HIGH:     2.0
  SEV_CRITICAL: 3.0

Budget split:
  40% → diagnosis phase (root cause identification)
  60% → fixing phase (remediation + verification)
```

### Budget Enforcement

```elixir
defmodule SelfHealing.BudgetGuard do
  def check_and_proceed(episode, phase) do
    phase_budget = case phase do
      :diagnosing -> trunc(episode.budget_cap * 0.40)
      :fixing     -> trunc(episode.budget_cap * 0.60)
    end

    spent_this_phase = episode.tokens_spent - prior_phase_spend(episode, phase)

    cond do
      spent_this_phase >= phase_budget ->
        {:escalate, "Budget cap reached in #{phase} phase"}
      spent_this_phase >= phase_budget * 0.85 ->
        {:warn_and_continue, "85% of #{phase} budget consumed"}
      true ->
        :continue
    end
  end
end
```

### Healing Agent Spawn

```
Error detected by: heartbeat failure handler | monitoring probe | peer agent
  │
  ▼
Classify error: {category, severity}
  │
  ▼
Check retryability matrix → "spawn healing agent"
  │
  ▼
Create Episode record (state: pending)
  │
  ▼
Spawn ephemeral healing agent:
  - model: sonnet (standard) or opus (SEV_CRITICAL)
  - system_prompt: healing-agent-system-prompt.md
  - budget_cap: computed from category + severity
  - context: error_message, error_code, failed_run_id, failed_agent_config
  - auto_terminate: true (on terminal episode state)
  │
  ▼
Update Episode: {state: diagnosing, healing_agent_id: agent.id, started_at: now()}
```

### Auto-Terminate Protocol

```
Episode reaches terminal state (completed | failed | escalated)
  │
  ▼
Healing agent receives :terminate signal
  │
  ▼
Agent writes final report to episode.fix_result (or diagnosis_result)
  │
  ▼
Agent exits cleanly (process terminates)
  │
  ▼
Supervisor removes agent from registry
  │
  ▼
Episode record preserved in DB (permanent audit trail)
```

---

## Retry Protocol

Before spawning a healing agent, certain error categories support auto-retry.
Retries are cheaper than healing episodes (no agent spawn, no diagnosis).

### Retry Configuration

```yaml
self_healing:
  retry:
    max_attempts: 3
    backoff: exponential
    base_delay_ms: 1000
    max_delay_ms: 30_000
    jitter: true
```

### Backoff Calculation

```
attempt 1: delay = 1000ms + jitter(0–500ms)
attempt 2: delay = 2000ms + jitter(0–1000ms)
attempt 3: delay = 4000ms + jitter(0–2000ms)
```

After max_attempts, if still failing: classify as non-retryable and spawn
a healing agent or escalate based on the retryability matrix.

---

## Escalation Protocol

When self-healing fails or the error category mandates escalation, the episode
escalates through the governance chain.

### Escalation Path

```
Episode escalates
  │
  ▼
1. Identify escalation target:
   - Start at failed agent's direct manager (reportsTo)
   - Traverse up reportsTo chain until escalation is accepted
   │
   ▼
2. Create escalation task in manager's inbox:
   {
     type: "healing_escalation",
     episode_id: episode.id,
     error_category: category,
     error_severity: severity,
     diagnosis_result: episode.diagnosis_result,  # what we know so far
     fix_attempts: episode.attempt_count,
     recommended_action: computed_recommendation
   }
   │
   ▼
3. Update Episode: {state: escalated, escalated_at: now(), escalation_path: [...]}
   │
   ▼
4. If SEV_CRITICAL and no response within 15 min:
   → Escalate to Board (algedonic channel bypass)
   → See governance.md for Board intervention protocol
```

### Recommended Actions (Computed)

The healing agent generates a `recommended_action` before escalating:

| Scenario | Recommendation |
|----------|---------------|
| Config error with identified fix | "Update `{config_key}` to `{correct_value}` in agent config" |
| Resource exhaustion | "Increase budget allocation by `{amount}` or reduce task scope" |
| Data corruption | "Re-import `{resource}` from source at `{location}`" |
| Logic error | "Review agent system prompt for invariant `{rule}` violation" |
| Unknown | "Manual investigation required — logs at `{log_ref}`" |

---

## Monitoring Probes

Self-healing is triggered not only by heartbeat failures but by periodic
monitoring probes that run independently.

### Probe Types

| Probe | Interval | What It Checks |
|-------|----------|---------------|
| **Orphan detector** | Every 5 min | Runs in `running` state with no activity for > 30 min |
| **Budget sentinel** | Every 15 min | Agents approaching budget ceiling (> 90%) |
| **Session health** | Every 30 min | Sessions with failed deserializations or corrupt state |
| **Task graph integrity** | Every 60 min | Tasks with impossible states or broken dependency chains |
| **Context keeper health** | Every 60 min | Keepers with write failures or staleness scoring errors |
| **Decision graph drift** | Every 6 hours | Goals with no decisions, confidence < 0.3 on active decisions |

### Probe → Healing Flow

```
Probe detects anomaly
  │
  ▼
Map anomaly to error: {category, severity, message}
  │
  ▼
Create Episode (same flow as heartbeat-triggered healing)
  │
  ▼
Proceed through standard healing lifecycle
```

---

## Healing Agent System Prompt

The healing agent receives a specialized system prompt at spawn:

```markdown
You are a Healing Agent for the OSA system. Your mission is to diagnose and
fix a specific error that occurred during agent execution. You are ephemeral —
you exist only to resolve this episode. You will auto-terminate when done.

## Your Context
- Failed Agent: {agent_name} ({agent_id})
- Error: {error_message}
- Category: {error_category}
- Severity: {error_severity}
- Token Budget (this phase): {phase_budget} tokens

## Your Process
1. DIAGNOSE: Identify the root cause. Check logs, config, session state, task graph.
2. REPORT diagnosis: structured JSON with root_cause, confidence, evidence.
3. FIX: Apply the minimal fix. Do not refactor or improve — only fix.
4. VERIFY: Confirm the fix works (re-run the failing operation if safe to do so).
5. REPORT result: structured JSON with fix_applied, verified, evidence.
6. TERMINATE: Your work is done. Exit cleanly.

## Constraints
- Never exceed your token budget. Escalate if you will run out before finishing.
- Never modify agent system prompts, governance rules, or budget configurations.
- Never delete data — quarantine or repair only.
- If you are unsure, escalate. Do not guess on critical fixes.
```

---

## Signal Theory Position

The Self-Healing subsystem implements **Layer 7 (The Governance / VSM)** and
**Layer 6 (The Feedback Loop)** of the Optimal System.

```
OS Layer 7 — The Governance (VSM) — S3 and S4
  ↕
SelfHealing — autonomous S3 control + S4 intelligence at the agent level

BEER S3 (CONTROL): The self-healing subsystem IS S3 at the agent scope.
  S3 monitors operational units (S1 agents), detects when they go outside
  viable operating parameters, and intervenes to restore viability.
  This is exactly what healing episodes do: monitor agent runs, detect errors,
  intervene with a targeted fix.

BEER S4 (INTELLIGENCE): The diagnosis phase IS S4. Before fixing, the healing
  agent scans the environment (logs, config, session state), builds a model
  of what went wrong, and proposes a correction strategy. S4 scans, learns,
  and feeds intelligence back to S3 (the fix).

BEER ALGEDONIC CHANNEL: Escalation to Board (SEV_CRITICAL with no manager
  response) is the algedonic bypass — a viability-preserving channel that
  routes directly to S5 (Policy/Board) when normal S3/S4 channels are
  too slow or have failed.
```

### Governing Principle: Beer — Viable Structure

Self-healing maintains the viability of the agent system by implementing the
full Beer S3/S4 cycle at the agent level: monitor operations → detect deviation
→ diagnose → correct → verify → close loop. Without this, the system is not
viable under disturbance — it requires constant human intervention to maintain
operations, which violates Beer's definition of a viable system.

### Governing Principle: Wiener — Feedback Closure

Every healing episode closes a feedback loop. The error is detected (open loop),
diagnosed (root cause identified), fixed (loop corrected), verified (loop closed).
An episode that escalates without a fix closes the loop differently — but it still
closes it: the human receives a complete diagnosis, and the episode transitions to
a terminal state. No open loops. No silent failures.

---

## See Also

- [heartbeat.md](heartbeat.md) — Step 7 failure triggers healing episode creation
- [governance.md](governance.md) — Escalation chain and Board intervention protocol
- [budgets.md](budgets.md) — Budget enforcement that healing agents cannot override
- [decision-graph.md](decision-graph.md) — Healing episodes create observation nodes on root cause identification
- [context-mesh.md](context-mesh.md) — Keeper health is monitored by the context keeper health probe
- [optimal-system-mapping.md](optimal-system-mapping.md) — Full 7-layer OS mapping

---

*Self-Healing v1.0 — Autonomous error classification, ephemeral healing agents, and governance-integrated escalation*
