# Proactive Agents Guide

> How to build agents that self-activate instead of waiting for commands.

---

## Reactive vs Proactive Agents

Most agents are **reactive** -- they wake up when a human types a command or when
another agent hands off work. They do nothing on their own.

**Proactive agents** self-activate. They monitor, check, alert, and execute on
their own schedule without waiting for someone to ask. They are the Operations
equivalent of cron jobs, but with judgment.

| Aspect | Reactive Agent | Proactive Agent |
|--------|---------------|----------------|
| Trigger | Human command or agent handoff | Schedule, event, condition, or heartbeat |
| Frequency | On demand | Continuous or periodic |
| Use case | Task execution | Monitoring, maintenance, scheduling |
| Example | Code reviewer | Health monitor, pipeline watcher |

---

## The 4 Activation Patterns

### 1. Heartbeat (Scheduled Interval)

The agent wakes on a fixed schedule, checks its responsibilities, and acts if needed.

```yaml
adapter_config:
  heartbeat:
    schedule: "*/15 * * * *"    # Every 15 minutes
    max_concurrent_runs: 1
    wake_on_assignment: false
```

**When to use**: Regular monitoring, status reports, periodic cleanup.

**How it works**:
1. Timer fires at the configured interval
2. Heartbeat protocol executes: budget check -> task checkout -> workspace resolve -> session restore -> invoke
3. Agent reads its instructions and decides what to do
4. Results captured, session persisted, costs logged
5. Agent goes dormant until next heartbeat

**Example**: A health monitor that checks API latency every 15 minutes.

### 2. Event-Driven (Triggered by System Events)

The agent wakes when a specific event occurs in the system.

```yaml
adapter_config:
  heartbeat:
    wake_on_assignment: true     # Wake when a task is assigned
    wake_on_mention: true        # Wake when @mentioned in a comment
```

**When to use**: Responding to task assignments, mentions, webhook events.

**How it works**:
1. System event fires (task assigned, comment created, webhook received)
2. Wake context snapshot created with event details
3. Agent wakes and receives the context
4. Agent processes the event and produces output

**Example**: A triage agent that wakes when a new bug report is filed.

### 3. Condition-Based (Triggered by State Change)

The agent wakes on a heartbeat but only acts when a condition is met.

```yaml
adapter_config:
  heartbeat:
    schedule: "0 */4 * * *"     # Check every 4 hours
    max_concurrent_runs: 1
```

The condition logic lives in the agent's Process section:

```markdown
# Process / Methodology

## Activation Check
1. Run `/status` to get current pipeline state
2. Check: Are there deals stalled > 7 days?
3. If YES: Generate stalled deal report and escalate to director
4. If NO: Log "Pipeline healthy" and go dormant
```

**When to use**: Anomaly detection, threshold alerts, SLA enforcement.

**Example**: A pipeline watcher that alerts when deals stall beyond thresholds.

### 4. Signal Intake (Triggered by New Information)

The agent wakes when new signals arrive that match its domain.

```yaml
adapter_config:
  heartbeat:
    schedule: null               # No fixed schedule
    wake_on_assignment: true     # Wake when signal routes to this agent
```

**When to use**: Processing incoming data, reacting to external events, content curation.

**Example**: A content scheduler that activates when a new draft is marked "ready for publishing."

---

## How to Configure Activation Triggers

Activation is configured in two places:

1. **Agent YAML frontmatter** -- The adapter and basic config
2. **Architecture heartbeat config** -- The detailed execution parameters

### Basic Configuration (YAML Frontmatter)

```yaml
---
name: Health Monitor
id: health-monitor
role: monitor
title: System Health Monitor
reportsTo: tech-lead
budget: 300
adapter: osa
signal: S=(data, report, inform, markdown, health-dashboard)
tools: [read, search, bash]
context_tier: l0
---
```

### Detailed Configuration (Heartbeat)

```yaml
adapter_config:
  heartbeat:
    schedule: "*/30 * * * *"       # Cron expression (every 30 minutes)
    max_concurrent_runs: 1          # Only one instance at a time
    grace_period_seconds: 30        # Time to save state when paused
    context_delivery: thin          # thin (wake context only) or fat (full task)
    wake_on_assignment: true        # Auto-wake when task assigned
    wake_on_mention: true           # Auto-wake when @mentioned
```

### Cron Expression Reference

| Expression | Meaning |
|-----------|---------|
| `*/5 * * * *` | Every 5 minutes |
| `*/15 * * * *` | Every 15 minutes |
| `0 * * * *` | Every hour |
| `0 */4 * * *` | Every 4 hours |
| `0 9 * * *` | Daily at 9am |
| `0 9 * * 1` | Every Monday at 9am |
| `0 9 1 * *` | First of every month at 9am |

---

## Monitoring and Control

Proactive agents require oversight. Without controls, they can burn budget,
generate noise, or create work nobody asked for.

### Budget Controls

The primary safety mechanism. Set budgets conservatively for proactive agents --
they run frequently and costs add up.

```yaml
budget: 300    # Monthly ceiling
```

Budget guidance for proactive agents:

| Frequency | Typical Budget | Reasoning |
|-----------|---------------|-----------|
| Every 5 min | $500-1000 | High-frequency = high cost |
| Every 15 min | $200-500 | Moderate frequency |
| Every hour | $100-300 | Low frequency |
| Daily | $50-150 | Minimal cost |

When budget is exceeded:
1. Current run completes (sunk cost)
2. Agent auto-pauses
3. Board notified
4. No future heartbeats until board resumes the agent

### Pause and Resume

The board can pause any proactive agent at any time:

```
Board pauses agent
  -> Current run receives graceful termination signal
  -> Grace period (30s default) for agent to save state
  -> Force-kill after timeout
  -> All future heartbeats blocked
  -> Deferred wake requests preserved (not discarded)
```

When resumed:
- Deferred wakes are processed
- Scheduled heartbeat resumes at next interval
- Agent picks up where it left off (session restored)

### Concurrency Limits

Proactive agents should almost always run with `max_concurrent_runs: 1`.
Multiple concurrent instances of the same monitor or scheduler create
conflicting actions and duplicate alerts.

Only increase concurrency when the agent processes independent work items
that cannot conflict (e.g., a code reviewer that can review multiple PRs
simultaneously).

### Activity Logging

Every proactive agent run is logged immutably:

```
{ISO8601} | health-monitor | agent_call | heartbeat | completed | $0.12
```

Use logs to audit:
- How often the agent runs
- How much each run costs
- Whether the agent is producing value vs noise
- Error rates and failure patterns

---

## Examples

### Health Monitor

A proactive agent that checks system health every 15 minutes.

```yaml
---
name: Health Monitor
id: health-monitor
role: monitor
title: System Health Monitor
reportsTo: tech-lead
budget: 300
adapter: osa
signal: S=(data, report, inform, markdown, health-dashboard)
tools: [read, search, bash]
context_tier: l0
---

# Identity & Memory

You are **Health Monitor**, an automated system watcher that runs every 15 minutes
to check the health of all services, agents, and workflows. You are the early
warning system -- you catch problems before they become incidents.

- **Role**: Automated health check and alerting
- **Personality**: Precise, concise, zero false positives preferred over false negatives
- **Memory**: You track baseline metrics and alert only on deviations

# Core Mission

1. **Service health** -- Check API endpoints, error rates, latency
2. **Agent health** -- Verify agents are running, budgets healthy, no orphaned runs
3. **Pipeline health** -- Check for stalled tasks, overdue milestones
4. **Alert on anomaly** -- Escalate when metrics deviate from baseline

# Critical Rules

- NEVER alert on a single data point -- require 2 consecutive anomalous readings
- NEVER generate alerts for known maintenance windows
- ALWAYS include the specific metric, threshold, and current value in alerts
- ALWAYS check budget before running diagnostics that cost money

# Process / Methodology

## Every 15-Minute Cycle
1. Check API health endpoints (exit early if all healthy)
2. Check agent run history for errors in last 30 minutes
3. Check task queue for items stalled > configured threshold
4. If any check fails:
   a. Verify failure (re-check once to avoid false positives)
   b. Generate health report with specific issues
   c. If P0 severity: escalate to tech-lead immediately
   d. If P1-P2: add to daily health summary

# Deliverable Templates

### Template: Health Report
- **Status**: HEALTHY | DEGRADED | CRITICAL
- **Checks Run**: {count}
- **Issues Found**: {count}
- **Issues**:
  - [{severity}] {service}: {metric} at {value} (threshold: {threshold})

# Communication Style

- **Tone**: Terse, factual, numbers-first
- **Default genre**: report
- **Receiver calibration**: tech-lead wants severity + metric + action needed. Nothing else.

# Success Metrics

- False positive rate: < 5%
- Mean time to detect real issues: < 30 minutes
- Budget utilization: < 80% of allocated monthly budget
```

### Content Scheduler

A proactive agent that publishes content on a weekly editorial calendar.

```markdown
---
name: Content Scheduler
id: content-scheduler
role: scheduler
title: Editorial Calendar Manager
reportsTo: editor-in-chief
budget: 200
adapter: osa
signal: S=(linguistic, plan, direct, markdown, calendar-template)
tools: [read, write, search]
context_tier: l0
---

# Identity & Memory

You are **Content Scheduler**, the editorial calendar operator. You wake daily
to check what content is due for publishing, verify it has passed editorial review,
and trigger the publish workflow.

# Core Mission

1. Check editorial calendar for content due today
2. Verify all due content has passed edit + SEO review gates
3. Queue approved content for publishing
4. Flag overdue content to editor-in-chief
5. Update calendar with publish confirmations

# Critical Rules

- NEVER publish content that has not passed editorial review
- NEVER reschedule content without editor-in-chief approval
- ALWAYS flag content due in 48 hours that has not entered edit phase
```

### Pipeline Watcher

A proactive agent that monitors the sales pipeline for stalled deals.

```markdown
---
name: Pipeline Watcher
id: pipeline-watcher
role: monitor
title: Pipeline Health Monitor
reportsTo: director
budget: 250
adapter: osa
signal: S=(data, report, inform, markdown, pipeline-dashboard)
tools: [read, search]
context_tier: l0
---

# Identity & Memory

You are **Pipeline Watcher**, an automated monitor that checks the sales pipeline
every 4 hours for stalled deals, missing MEDDPICC scores, and overdue follow-ups.

# Core Mission

1. Identify deals stalled beyond phase thresholds (7/14/21/30 days)
2. Flag deals missing required qualification data (MEDDPICC gaps)
3. Alert on overdue follow-up commitments
4. Generate weekly pipeline health summary for director

# Critical Rules

- NEVER auto-close or auto-disqualify a deal -- only flag and escalate
- ALWAYS include deal age, current phase, and last activity in alerts
- ALWAYS group alerts by severity (stall duration) for director review
```

---

## Proactive Agent Design Checklist

- [ ] Clear activation pattern chosen (heartbeat, event, condition, signal)
- [ ] Cron schedule is appropriate for the task (not too frequent, not too infrequent)
- [ ] Budget is sized for expected run frequency and cost per run
- [ ] `max_concurrent_runs` is set to 1 (unless parallel execution is safe)
- [ ] Process section defines the "activation check" -- when to act vs go dormant
- [ ] False positive prevention is addressed (re-check before alerting)
- [ ] Escalation path is defined (who gets notified for what severity)
- [ ] The agent produces value, not noise -- every run should have a clear purpose
- [ ] Graceful degradation is handled (what if a dependency is down?)
- [ ] Logging is sufficient to audit run history and cost
