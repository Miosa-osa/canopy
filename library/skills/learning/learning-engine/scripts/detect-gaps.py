#!/usr/bin/env python3
"""
Detect capability gaps that may require new agents or skills.
Analyzes task history to find patterns of failure or inefficiency.
"""

import json
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict

LEARNING_DIR = Path.home() / ".claude" / "learning"

def load_metrics() -> dict:
    """Load session metrics."""
    metrics_file = LEARNING_DIR / "metrics" / "index.json"
    if metrics_file.exists():
        with open(metrics_file) as f:
            return json.load(f)
    return {"sessions": [], "stats": {}}

def load_events() -> list:
    """Load recent events."""
    events_dir = LEARNING_DIR / "events"
    events = []
    if events_dir.exists():
        for event_file in events_dir.glob("*.json"):
            with open(event_file) as f:
                events.extend(json.load(f).get("events", []))
    return events

def analyze_agent_performance(events: list) -> dict:
    """Analyze performance by agent."""
    agent_stats = defaultdict(lambda: {"success": 0, "failure": 0, "partial": 0, "avg_time": 0})

    for event in events:
        agent = event.get("agent", "unknown")
        outcome = event.get("outcome", "unknown")
        duration = event.get("duration_ms", 0)

        if outcome == "success":
            agent_stats[agent]["success"] += 1
        elif outcome == "failure":
            agent_stats[agent]["failure"] += 1
        else:
            agent_stats[agent]["partial"] += 1

        # Running average
        total = agent_stats[agent]["success"] + agent_stats[agent]["failure"] + agent_stats[agent]["partial"]
        agent_stats[agent]["avg_time"] = (agent_stats[agent]["avg_time"] * (total - 1) + duration) / total

    return dict(agent_stats)

def detect_coverage_gaps(events: list) -> list:
    """Detect areas without good agent coverage."""
    domain_outcomes = defaultdict(lambda: {"handled": 0, "unhandled": 0, "corrected": 0})

    for event in events:
        domain = event.get("domain", "unknown")
        was_handled = event.get("agent") is not None
        needed_correction = event.get("user_corrected", False)

        if was_handled:
            domain_outcomes[domain]["handled"] += 1
        else:
            domain_outcomes[domain]["unhandled"] += 1

        if needed_correction:
            domain_outcomes[domain]["corrected"] += 1

    gaps = []
    for domain, stats in domain_outcomes.items():
        total = stats["handled"] + stats["unhandled"]
        if total == 0:
            continue

        coverage_rate = stats["handled"] / total
        correction_rate = stats["corrected"] / total if total > 0 else 0

        # Flag gaps
        if coverage_rate < 0.8:
            gaps.append({
                "type": "coverage",
                "domain": domain,
                "coverage_rate": coverage_rate,
                "severity": "high" if coverage_rate < 0.5 else "medium",
                "recommendation": f"Need specialist agent for {domain}"
            })

        if correction_rate > 0.2:
            gaps.append({
                "type": "accuracy",
                "domain": domain,
                "correction_rate": correction_rate,
                "severity": "high" if correction_rate > 0.4 else "medium",
                "recommendation": f"Improve {domain} agent training or add rules"
            })

    return gaps

def detect_pattern_gaps(events: list) -> list:
    """Detect missing patterns based on repeated similar tasks."""
    task_signatures = defaultdict(int)

    for event in events:
        # Create signature from task characteristics
        sig = f"{event.get('domain', 'x')}-{event.get('task_type', 'x')}-{event.get('complexity', 'x')}"
        task_signatures[sig] += 1

    gaps = []
    for sig, count in task_signatures.items():
        if count >= 3:  # Task pattern repeated 3+ times
            domain, task_type, complexity = sig.split("-")
            gaps.append({
                "type": "pattern",
                "signature": sig,
                "occurrences": count,
                "recommendation": f"Create reusable pattern for {task_type} in {domain}"
            })

    return gaps

def detect_skill_gaps(events: list) -> list:
    """Detect areas where skills might help."""
    workflow_patterns = defaultdict(int)

    for event in events:
        # Track common workflows
        workflow = event.get("workflow_type")
        if workflow:
            workflow_patterns[workflow] += 1

    gaps = []
    for workflow, count in workflow_patterns.items():
        if count >= 5 and not skill_exists(workflow):
            gaps.append({
                "type": "skill",
                "workflow": workflow,
                "occurrences": count,
                "recommendation": f"Create skill for {workflow} workflow"
            })

    return gaps

def skill_exists(name: str) -> bool:
    """Check if a skill exists."""
    skills_dir = Path.home() / ".claude" / "skills"
    return (skills_dir / f"{name}.md").exists() or (skills_dir / "core" / f"{name}.md").exists()

def save_gaps(gaps: list):
    """Save detected gaps to file."""
    gaps_file = LEARNING_DIR / "gaps" / "index.json"
    gaps_file.parent.mkdir(parents=True, exist_ok=True)

    # Load existing
    if gaps_file.exists():
        with open(gaps_file) as f:
            existing = json.load(f)
    else:
        existing = {"version": "1.0.0", "detected_gaps": [], "resolved_gaps": [], "pending_agents": []}

    # Add new gaps (avoid duplicates)
    existing_sigs = {g.get("signature", g.get("domain", "")) for g in existing["detected_gaps"]}
    for gap in gaps:
        sig = gap.get("signature", gap.get("domain", ""))
        if sig not in existing_sigs:
            gap["detected_at"] = datetime.now().isoformat()
            existing["detected_gaps"].append(gap)

    # Save
    with open(gaps_file, "w") as f:
        json.dump(existing, f, indent=2)

def main():
    events = load_events()

    if not events:
        print(json.dumps({
            "status": "no_data",
            "message": "No events to analyze. Gaps will be detected as usage accumulates."
        }))
        return

    # Run all detection
    coverage_gaps = detect_coverage_gaps(events)
    pattern_gaps = detect_pattern_gaps(events)
    skill_gaps = detect_skill_gaps(events)
    agent_stats = analyze_agent_performance(events)

    all_gaps = coverage_gaps + pattern_gaps + skill_gaps

    # Save gaps
    save_gaps(all_gaps)

    # Generate report
    report = {
        "status": "analyzed",
        "events_analyzed": len(events),
        "gaps_detected": len(all_gaps),
        "gaps": all_gaps,
        "agent_performance": agent_stats,
        "recommendations": [g["recommendation"] for g in all_gaps if g.get("severity") == "high"]
    }

    print(json.dumps(report, indent=2))

if __name__ == "__main__":
    main()
