#!/usr/bin/env python3
"""
Generate metrics and analytics from learning data.
"""

import json
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict

LEARNING_DIR = Path.home() / ".claude" / "learning"

def count_files(directory: Path, pattern: str = "*.json") -> int:
    """Count files matching pattern in directory."""
    if not directory.exists():
        return 0
    return len(list(directory.rglob(pattern)))

def load_all_patterns() -> list:
    """Load all saved patterns."""
    patterns = []
    patterns_dir = LEARNING_DIR / "patterns"
    if patterns_dir.exists():
        for pattern_file in patterns_dir.rglob("*.json"):
            if pattern_file.name != "index.json":
                with open(pattern_file) as f:
                    patterns.append(json.load(f))
    return patterns

def load_all_solutions() -> list:
    """Load all saved solutions."""
    solutions = []
    solutions_dir = LEARNING_DIR / "solutions"
    if solutions_dir.exists():
        for solution_file in solutions_dir.rglob("*.json"):
            if solution_file.name != "index.json":
                with open(solution_file) as f:
                    solutions.append(json.load(f))
    return solutions

def load_gaps() -> dict:
    """Load gap detection data."""
    gaps_file = LEARNING_DIR / "gaps" / "index.json"
    if gaps_file.exists():
        with open(gaps_file) as f:
            return json.load(f)
    return {"detected_gaps": [], "resolved_gaps": [], "pending_agents": []}

def load_events() -> list:
    """Load all events."""
    events = []
    events_dir = LEARNING_DIR / "events"
    if events_dir.exists():
        for event_file in events_dir.glob("*.json"):
            with open(event_file) as f:
                data = json.load(f)
                events.extend(data.get("events", [data]))
    return events

def calculate_metrics() -> dict:
    """Calculate comprehensive metrics."""
    patterns = load_all_patterns()
    solutions = load_all_solutions()
    gaps = load_gaps()
    events = load_events()

    # Time-based analysis
    now = datetime.now()
    week_ago = now - timedelta(days=7)
    month_ago = now - timedelta(days=30)

    def in_timeframe(item, cutoff):
        created = item.get("created", item.get("timestamp", ""))
        if not created:
            return False
        try:
            item_time = datetime.fromisoformat(created.replace("Z", "+00:00"))
            return item_time.replace(tzinfo=None) > cutoff
        except:
            return False

    recent_events = [e for e in events if in_timeframe(e, week_ago)]
    monthly_events = [e for e in events if in_timeframe(e, month_ago)]

    # Pattern analytics
    pattern_usage = defaultdict(int)
    for p in patterns:
        pattern_usage[p.get("domain", "general")] += p.get("usage_count", 1)

    top_patterns = sorted(patterns, key=lambda x: x.get("usage_count", 0), reverse=True)[:10]

    # Agent usage
    agent_usage = defaultdict(int)
    agent_success = defaultdict(int)
    agent_total = defaultdict(int)

    for event in events:
        agent = event.get("agent", "unknown")
        agent_usage[agent] += 1
        agent_total[agent] += 1
        if event.get("outcome") == "success":
            agent_success[agent] += 1

    agent_success_rates = {
        agent: agent_success[agent] / agent_total[agent] if agent_total[agent] > 0 else 0
        for agent in agent_total
    }

    # Domain distribution
    domain_counts = defaultdict(int)
    for event in events:
        domain_counts[event.get("domain", "unknown")] += 1

    # Complexity distribution
    complexity_counts = defaultdict(int)
    for event in events:
        complexity_counts[event.get("complexity", "unknown")] += 1

    return {
        "generated_at": now.isoformat(),
        "summary": {
            "total_patterns": len(patterns),
            "total_solutions": len(solutions),
            "total_events": len(events),
            "events_this_week": len(recent_events),
            "events_this_month": len(monthly_events),
            "detected_gaps": len(gaps.get("detected_gaps", [])),
            "resolved_gaps": len(gaps.get("resolved_gaps", [])),
        },
        "patterns": {
            "by_domain": dict(pattern_usage),
            "top_used": [{"id": p.get("id"), "title": p.get("title"), "usage": p.get("usage_count", 0)}
                        for p in top_patterns[:5]],
            "total_usage": sum(p.get("usage_count", 0) for p in patterns),
        },
        "agents": {
            "usage_counts": dict(agent_usage),
            "success_rates": agent_success_rates,
            "most_used": sorted(agent_usage.items(), key=lambda x: x[1], reverse=True)[:5],
        },
        "tasks": {
            "by_domain": dict(domain_counts),
            "by_complexity": dict(complexity_counts),
        },
        "gaps": {
            "detected": len(gaps.get("detected_gaps", [])),
            "resolved": len(gaps.get("resolved_gaps", [])),
            "pending_agents": gaps.get("pending_agents", []),
            "high_severity": [g for g in gaps.get("detected_gaps", []) if g.get("severity") == "high"],
        },
        "trends": {
            "weekly_average": len(monthly_events) / 4 if monthly_events else 0,
            "growth": "increasing" if len(recent_events) > len(monthly_events) / 4 else "stable",
        }
    }

def format_report(metrics: dict) -> str:
    """Format metrics as readable report."""
    summary = metrics["summary"]
    patterns = metrics["patterns"]
    agents = metrics["agents"]
    tasks = metrics["tasks"]
    gaps_info = metrics["gaps"]

    report = f"""
CLAUDE CODE ANALYTICS
=====================
Generated: {metrics['generated_at']}

SUMMARY
-------
Patterns Saved:    {summary['total_patterns']}
Solutions Saved:   {summary['total_solutions']}
Total Events:      {summary['total_events']}
This Week:         {summary['events_this_week']}
This Month:        {summary['events_this_month']}

PATTERNS
--------
Total Usage: {patterns['total_usage']}

By Domain:
"""
    for domain, count in patterns['by_domain'].items():
        report += f"  {domain}: {count}\n"

    report += "\nTop Patterns:\n"
    for p in patterns['top_used']:
        report += f"  - {p['title']} (used {p['usage']}x)\n"

    report += "\nAGENT PERFORMANCE\n-----------------\n"
    for agent, rate in sorted(agents['success_rates'].items(), key=lambda x: x[1], reverse=True)[:10]:
        usage = agents['usage_counts'].get(agent, 0)
        report += f"  @{agent}: {rate*100:.0f}% success ({usage} uses)\n"

    report += "\nTASK DISTRIBUTION\n-----------------\n"
    report += "By Domain:\n"
    for domain, count in sorted(tasks['by_domain'].items(), key=lambda x: x[1], reverse=True):
        report += f"  {domain}: {count}\n"

    report += "\nBy Complexity:\n"
    for complexity, count in tasks['by_complexity'].items():
        report += f"  {complexity}: {count}\n"

    report += f"\nGAPS\n----\nDetected: {gaps_info['detected']}\nResolved: {gaps_info['resolved']}\n"

    if gaps_info['high_severity']:
        report += "\nHigh Severity Gaps:\n"
        for gap in gaps_info['high_severity']:
            report += f"  - {gap.get('recommendation', gap.get('type'))}\n"

    return report

def main():
    output_format = sys.argv[1] if len(sys.argv) > 1 else "json"

    metrics = calculate_metrics()

    # Save metrics
    metrics_file = LEARNING_DIR / "metrics" / "index.json"
    metrics_file.parent.mkdir(parents=True, exist_ok=True)

    # Load existing and append
    if metrics_file.exists():
        with open(metrics_file) as f:
            existing = json.load(f)
    else:
        existing = {"version": "1.0.0", "history": []}

    existing["latest"] = metrics
    existing["history"].append({
        "timestamp": metrics["generated_at"],
        "summary": metrics["summary"]
    })

    # Keep last 30 days of history
    existing["history"] = existing["history"][-30:]

    with open(metrics_file, "w") as f:
        json.dump(existing, f, indent=2)

    # Output
    if output_format == "text":
        print(format_report(metrics))
    else:
        print(json.dumps(metrics, indent=2))

if __name__ == "__main__":
    main()
