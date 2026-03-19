# Proactive Agent Patterns

> Agents that self-activate without waiting for human input. The heartbeat protocol
> defines HOW agents execute. Proactive patterns define WHEN agents wake themselves up
> based on triggers, conditions, schedules, and events.
>
> Self-activating agent patterns for OSA Operations with budget-aware
> activation and governance gates.

---

## Why Proactive Agents

Reactive agents wait for commands. Proactive agents watch for conditions that require
action and self-activate when those conditions are met. Without proactive agents:

- Knowledge goes stale without anyone noticing
- Quality degrades silently until a human hits a bad answer
- Routine maintenance requires human initiation every time
- Emergent patterns go undetected until manually investigated

```
REACTIVE AGENT                      PROACTIVE AGENT
Human: "check for stale docs"       Agent: detects staleness at 3am
Agent: finds 12 stale docs          Agent: refreshes 12 docs
Agent: reports findings              Agent: logs report for morning review
Human: "update them"                 Human: reviews report, approves
Agent: updates them                  (work already done)
```

---

## Activation Types

### 1. Heartbeat-Triggered (Periodic)

The simplest pattern. Agent wakes on a fixed interval to perform maintenance,
checks, or summaries.

```yaml
activation:
  type: heartbeat
  interval: "6h"              # Every 6 hours
  jitter: "30m"               # Random offset to prevent thundering herd
  max_runtime: "10m"          # Kill if exceeds this
  budget_per_run: 0.50        # USD cap per activation
  skip_if_idle: true          # Don't run if no changes since last run

  task:
    description: "Scan knowledge base for staleness and quality issues"
    skill: "health-check"
    output: "report"
```

**Use cases:**
- Knowledge base health checks
- Index freshness verification
- Memory decay processing
- Cost budget summaries

**Implementation:**

```elixir
defmodule ProactiveAgent.Heartbeat do
  use GenServer

  def init(config) do
    schedule_next(config.interval, config.jitter)
    {:ok, config}
  end

  def handle_info(:tick, config) do
    if should_run?(config) do
      case Budget.check(config.agent_id, config.budget_per_run) do
        :ok ->
          Heartbeat.execute(config.agent_id, config.task)
        {:over_budget, remaining} ->
          Logger.warn("Proactive run skipped: budget #{remaining} < #{config.budget_per_run}")
      end
    end

    schedule_next(config.interval, config.jitter)
    {:noreply, config}
  end

  defp should_run?(%{skip_if_idle: true} = config) do
    Store.changes_since(config.last_run_at) > 0
  end
  defp should_run?(_), do: true

  defp schedule_next(interval, jitter) do
    delay = interval + :rand.uniform(jitter)
    Process.send_after(self(), :tick, delay)
  end
end
```

---

### 2. Event-Triggered (Reactive to System Events)

Agent activates in response to specific system events. The event bus notifies
subscribed agents when their trigger conditions are met.

```yaml
activation:
  type: event
  events:
    - resource.created           # New resource added to knowledge base
    - resource.updated           # Existing resource modified
    - signal.ingested            # New signal processed by intake
    - task.completed             # A task finished
    - session.ended              # An agent session closed
    - budget.threshold_reached   # Budget hit warning level

  filter:                        # Only trigger on matching events
    node: "04-ai-masters"        # Only for this node
    genre: "decision-log"        # Only for this genre

  debounce: "5m"                 # Wait 5 min after first event, batch process
  budget_per_run: 0.25

  task:
    description: "Process new signal, update cross-references"
    skill: "cross-reference"
    output: "updated_relations"
```

**Use cases:**
- Cross-referencing new signals with existing knowledge
- Updating L0 abstracts when source documents change
- Alerting on financial signals crossing thresholds
- Auto-tagging and categorizing new resources

**Implementation:**

```elixir
defmodule ProactiveAgent.EventTrigger do
  use GenServer

  def init(config) do
    for event <- config.events do
      EventBus.subscribe(event, filter: config.filter)
    end
    {:ok, %{config: config, pending: [], debounce_ref: nil}}
  end

  def handle_info({:event, event}, %{config: config} = state) do
    new_pending = [event | state.pending]

    # Reset debounce timer on each new event
    if state.debounce_ref, do: Process.cancel_timer(state.debounce_ref)
    ref = Process.send_after(self(), :flush, config.debounce)

    {:noreply, %{state | pending: new_pending, debounce_ref: ref}}
  end

  def handle_info(:flush, %{config: config, pending: events} = state) do
    # Batch process all accumulated events
    case Budget.check(config.agent_id, config.budget_per_run) do
      :ok ->
        Heartbeat.execute(config.agent_id, %{
          config.task | context: %{events: Enum.reverse(events)}
        })
      {:over_budget, _} ->
        Logger.warn("Event-triggered run deferred: over budget")
        # Re-queue for next budget cycle
        Budget.defer(config.agent_id, events)
    end

    {:noreply, %{state | pending: [], debounce_ref: nil}}
  end
end
```

---

### 3. Condition-Triggered (Threshold Monitoring)

Agent monitors a metric or condition and activates when a threshold is crossed.
Unlike event triggers (which respond to discrete events), condition triggers
poll a state and fire when the state matches.

```yaml
activation:
  type: condition
  conditions:
    - metric: "knowledge.staleness_ratio"
      operator: ">"
      threshold: 0.3             # More than 30% of resources stale
      check_interval: "1h"

    - metric: "l0.abstract_drift"
      operator: ">"
      threshold: 0.2             # 20% of L0 abstracts don't match source

    - metric: "memory.conflict_count"
      operator: ">"
      threshold: 5               # More than 5 conflicting memory records

  cooldown: "4h"                 # Don't re-trigger within 4 hours
  budget_per_run: 1.00           # Higher budget — condition fixes are heavier

  task:
    description: "Diagnose and repair knowledge quality issues"
    skill: "knowledge-repair"
    output: "repair_report"
```

**Use cases:**
- Quality degradation detection and repair
- L0 abstract drift correction (abstracts diverged from source content)
- Memory conflict resolution (contradictory facts detected)
- Entity relationship staleness (relations no longer accurate)
- Token budget approaching limits

**Implementation:**

```elixir
defmodule ProactiveAgent.ConditionMonitor do
  use GenServer

  def init(config) do
    for condition <- config.conditions do
      schedule_check(condition)
    end
    {:ok, %{config: config, last_triggered: nil}}
  end

  def handle_info({:check, condition}, state) do
    current_value = Metrics.get(condition.metric)

    if meets_threshold?(current_value, condition.operator, condition.threshold) do
      if not in_cooldown?(state.last_triggered, state.config.cooldown) do
        trigger_agent(state.config, condition, current_value)
        {:noreply, %{state | last_triggered: DateTime.utc_now()}}
      else
        {:noreply, state}
      end
    else
      schedule_check(condition)
      {:noreply, state}
    end
  end

  defp meets_threshold?(value, ">", threshold), do: value > threshold
  defp meets_threshold?(value, "<", threshold), do: value < threshold
  defp meets_threshold?(value, ">=", threshold), do: value >= threshold
  defp meets_threshold?(value, "==", threshold), do: value == threshold
end
```

---

### 4. Schedule-Triggered (Calendar-Based)

Agent activates at specific times — daily summaries, weekly reviews, monthly
reports. Uses cron-like scheduling.

```yaml
activation:
  type: schedule
  schedule: "0 9 * * 1"          # Every Monday at 9am
  timezone: "America/Chicago"
  budget_per_run: 2.00           # Weekly reviews are comprehensive

  task:
    description: "Generate weekly knowledge base review"
    skill: "weekly-review"
    output: "review_report"
    notify: ["board"]             # Send to governance board
```

**Use cases:**
- Daily summaries of changes and activity
- Weekly knowledge base reviews
- Monthly metric reports
- Quarterly strategy alignment checks

**Common schedules:**

```yaml
schedules:
  daily_summary:
    schedule: "0 8 * * *"         # Daily at 8am
    task: "Summarize yesterday's signals, decisions, and open items"

  weekly_review:
    schedule: "0 9 * * 1"         # Monday at 9am
    task: "Review all nodes for staleness, generate weekly digest"

  monthly_metrics:
    schedule: "0 10 1 * *"        # 1st of month at 10am
    task: "Compile monthly metrics: revenue, activity, quality scores"

  quarterly_alignment:
    schedule: "0 10 1 1,4,7,10 *" # Quarterly
    task: "Full alignment review across all nodes and strategies"
```

---

## Activation Priority

When multiple proactive agents are ready to fire simultaneously, priority
determines execution order:

```yaml
priority_levels:
  critical: 1    # Security alerts, data integrity issues
  high: 2        # Quality degradation, budget warnings
  normal: 3      # Routine maintenance, summaries
  low: 4         # Optimization, nice-to-have improvements
```

### Concurrency Control

```
MAX_CONCURRENT_PROACTIVE = 3

Queue: priority queue ordered by (priority, scheduled_time)

When slot available:
  1. Pop highest priority agent from queue
  2. Budget check → skip if over budget
  3. Governance check → defer if approval needed
  4. Execute via heartbeat protocol
  5. On completion, release slot → pop next
```

---

## Governance Integration

Proactive agents operate autonomously but within governance boundaries:

### Approval Gates

```yaml
governance:
  auto_approve:
    - budget_per_run < 0.50      # Cheap runs auto-approved
    - activation_type: heartbeat  # Routine checks auto-approved
    - output_type: report         # Read-only outputs auto-approved

  requires_approval:
    - modifies_resources: true    # Changes to knowledge base
    - budget_per_run > 5.00       # Expensive runs
    - affects_external: true      # Sends emails, Slack messages, etc.

  escalation:
    - consecutive_failures > 3    # Agent keeps failing
    - budget_monthly > 50.00      # Monthly proactive spend high
```

### Audit Trail

Every proactive activation is logged:

```yaml
audit_entry:
  agent_id: "knowledge-guardian"
  activation_type: "condition"
  trigger: "knowledge.staleness_ratio > 0.3 (actual: 0.37)"
  started_at: "2026-03-19T03:15:00Z"
  completed_at: "2026-03-19T03:22:14Z"
  budget_used: 0.73
  result: "success"
  actions_taken:
    - "Refreshed 8 L0 abstracts"
    - "Flagged 3 resources for human review"
    - "Updated staleness_ratio: 0.37 → 0.12"
  artifacts: ["reports/health-check-2026-03-19.md"]
```

---

## Common Proactive Agent Definitions

### Knowledge Guardian

```yaml
agent:
  id: knowledge-guardian
  role: "Knowledge base maintenance"
  activations:
    - type: heartbeat
      interval: "6h"
      task: "health-check"
    - type: condition
      metric: "knowledge.staleness_ratio"
      threshold: 0.3
      task: "knowledge-repair"
    - type: event
      events: ["resource.created"]
      task: "cross-reference"
```

### Quality Monitor

```yaml
agent:
  id: quality-monitor
  role: "Output quality assurance"
  activations:
    - type: condition
      metric: "l0.abstract_drift"
      threshold: 0.2
      task: "abstract-refresh"
    - type: event
      events: ["resource.updated"]
      debounce: "10m"
      task: "verify-abstracts"
```

### Summary Generator

```yaml
agent:
  id: summary-generator
  role: "Periodic reporting"
  activations:
    - type: schedule
      schedule: "0 8 * * *"
      task: "daily-summary"
    - type: schedule
      schedule: "0 9 * * 1"
      task: "weekly-review"
    - type: schedule
      schedule: "0 10 1 * *"
      task: "monthly-report"
```

### Drift Detector

```yaml
agent:
  id: drift-detector
  role: "Strategic alignment monitoring"
  activations:
    - type: schedule
      schedule: "0 10 * * 5"     # Friday mornings
      task: "alignment-check"
    - type: condition
      metric: "alignment.drift_score"
      threshold: 0.4
      task: "drift-alert"
```

---

## Implementation Checklist

1. **Event bus** — Central pub/sub for system events. All components publish,
   proactive agents subscribe.

2. **Metrics registry** — Named metrics that condition triggers can poll.
   `Metrics.register("knowledge.staleness_ratio", fn -> calculate() end)`

3. **Scheduler** — Cron-compatible scheduler for schedule triggers. Use
   existing libraries (Quantum for Elixir, node-cron for Node.js).

4. **Priority queue** — Concurrent-safe priority queue for activation ordering.

5. **Budget integration** — Every proactive run deducts from the agent's
   budget. Over-budget agents are paused until next cycle.

6. **Audit logger** — Every activation logged with trigger, duration, cost,
   result, and actions taken.

7. **Governance hooks** — Pre-execution check against approval gates.
   Deferred activations queue for human approval.

---

## Relationship to Other Architecture Files

| File | How It Relates |
|------|---------------|
| `heartbeat.md` | Proactive agents execute VIA the heartbeat protocol |
| `basement.md` | Proactive agents query typed resources for monitoring |
| `tiered-loading.md` | L0 abstracts enable cheap proactive health checks |
| `memory-architecture.md` | Proactive agents maintain memory layers |
| `budgets.md` | Budget enforcement gates every proactive activation |
| `governance.md` | Approval gates for resource-modifying proactive actions |
| `tasks.md` | Proactive activations create internal tasks |

---

*Proactive Agent Patterns v1.0 — Self-activating agents for OSA Operations*
