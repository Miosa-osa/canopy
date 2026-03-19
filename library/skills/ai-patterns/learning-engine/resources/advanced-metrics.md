---
name: advanced-metrics
description: Advanced learning metrics for session tracking and pattern quality
triggers:
  - metrics
  - learning analysis
  - performance tracking
---

# Advanced Learning Metrics

## Session Metrics

### Per-Session Tracking
- Total tasks completed
- Agent utilization rates
- Average task completion time (estimated)
- Pattern reuse rate
- Memory hit rate

### Aggregated Metrics
- Most effective agents per domain
- Common task patterns
- Gap frequency by domain
- Agent creation rate

## Pattern Quality Metrics

### Usage Score
```
usage_score = (times_used * 0.4) + (success_rate * 0.4) + (recency_score * 0.2)
```

### Pattern Freshness
```
recency_score = 1 / (1 + days_since_last_use / 30)
```

### Pattern Relevance
Factors:
- Exact keyword match
- Domain match
- Similar complexity
- Same task type

## Gap Analysis

### Gap Detection Criteria
1. **No Match Gap**: Task has <50% confidence match to any agent
2. **Correction Gap**: User corrects agent output >2 times
3. **Explanation Gap**: Agent needs >3 clarifications
4. **Time Gap**: Task takes >3x expected time
5. **Failure Gap**: Task fails after multiple attempts

### Gap Resolution Priority
```
priority = (frequency * 0.5) + (impact * 0.3) + (feasibility * 0.2)
```

## Agent Effectiveness Scoring

### Agent Score Components
```python
agent_score = {
    "success_rate": successful_tasks / total_tasks,
    "avg_iterations": sum(iterations) / total_tasks,
    "user_satisfaction": positive_signals / total_signals,
    "pattern_contribution": patterns_created / tasks_completed,
    "reuse_rate": times_reused / times_invoked
}
```

### Agent Ranking
Sort agents by weighted score for dispatch priority.

## Learning Rate Metrics

### Knowledge Growth
```
growth_rate = new_patterns_per_session / avg_patterns_per_session
```

### Improvement Indicators
- Decreasing task iterations over time
- Increasing pattern reuse
- Decreasing gap detection rate
- Improving success rate

## Export Formats

### Daily Report
```json
{
  "date": "2024-01-20",
  "sessions": 3,
  "tasks_completed": 15,
  "patterns_learned": 2,
  "gaps_detected": 1,
  "top_agents": ["@backend-go", "@debugger"],
  "domains": {"backend": 8, "frontend": 5, "testing": 2}
}
```

### Weekly Trends
```json
{
  "week": "2024-W03",
  "trend": "improving",
  "success_rate_delta": +0.05,
  "new_patterns": 8,
  "gaps_resolved": 3,
  "agents_created": 1
}
```
