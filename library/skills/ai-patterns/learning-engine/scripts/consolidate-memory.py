#!/usr/bin/env python3
"""
Memory Consolidation Script - Implements Mem0-style consolidation
Based on: Mem0 Architecture and Synapse Spreading Activation (arXiv:2601.02744)

Consolidates episodic memories into semantic memory with deduplication.
"""

import json
import os
import sys
import hashlib
from datetime import datetime, timezone
from pathlib import Path
from collections import defaultdict

LEARNING_DIR = Path.home() / ".claude" / "learning"
EPISODES_DIR = LEARNING_DIR / "episodes"
SEMANTIC_DIR = LEARNING_DIR / "semantic"
CONSOLIDATED_DIR = LEARNING_DIR / "consolidated"

# Ensure directories exist
SEMANTIC_DIR.mkdir(parents=True, exist_ok=True)
CONSOLIDATED_DIR.mkdir(parents=True, exist_ok=True)

SIMILARITY_THRESHOLD = 0.85  # For deduplication
MAX_EPISODES_PER_BATCH = 100


def get_timestamp():
    """Get ISO timestamp."""
    return datetime.now(timezone.utc).isoformat()


def hash_fact(fact: str) -> str:
    """Generate hash for fact comparison."""
    return hashlib.sha256(fact.lower().strip().encode()).hexdigest()[:16]


def load_recent_episodes(days: int = 7) -> list:
    """Load recent episode files."""
    episodes = []

    if not EPISODES_DIR.exists():
        return episodes

    # Get episode files from last N days
    cutoff = datetime.now().strftime("%Y-%m-")  # Current month

    for ep_file in sorted(EPISODES_DIR.glob("*.jsonl"), reverse=True)[:30]:
        with open(ep_file) as f:
            for line in f:
                if line.strip():
                    try:
                        episodes.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue

        if len(episodes) >= MAX_EPISODES_PER_BATCH:
            break

    return episodes[:MAX_EPISODES_PER_BATCH]


def load_semantic_memory() -> dict:
    """Load existing semantic memory."""
    memory = {"facts": [], "patterns": [], "decisions": []}

    for mem_type in memory.keys():
        mem_file = SEMANTIC_DIR / f"{mem_type}.jsonl"
        if mem_file.exists():
            with open(mem_file) as f:
                for line in f:
                    if line.strip():
                        try:
                            memory[mem_type].append(json.loads(line))
                        except json.JSONDecodeError:
                            continue

    return memory


def extract_facts_from_episodes(episodes: list) -> list:
    """Extract semantic facts from episodic memories."""
    facts = []

    for ep in episodes:
        # Extract from successful interactions
        if not ep.get("success", False):
            continue

        tool_name = ep.get("tool_name", "")
        classification = ep.get("classification", {})

        # Create fact based on classification
        if classification.get("domain"):
            fact = {
                "type": "interaction_pattern",
                "domain": classification["domain"],
                "tool": tool_name,
                "complexity": classification.get("complexity", "simple"),
                "timestamp": ep.get("timestamp", get_timestamp()),
                "hash": hash_fact(f"{tool_name}:{classification['domain']}")
            }
            facts.append(fact)

    return facts


def deduplicate_facts(new_facts: list, existing_facts: list) -> tuple:
    """Deduplicate facts using hash comparison."""
    existing_hashes = {f.get("hash") for f in existing_facts}

    unique_facts = []
    duplicate_count = 0

    for fact in new_facts:
        if fact.get("hash") not in existing_hashes:
            unique_facts.append(fact)
            existing_hashes.add(fact.get("hash"))
        else:
            duplicate_count += 1

    return unique_facts, duplicate_count


def consolidate_patterns(episodes: list) -> list:
    """Consolidate repeated patterns into semantic memory."""
    pattern_counts = defaultdict(int)
    pattern_examples = defaultdict(list)

    for ep in episodes:
        classification = ep.get("classification", {})
        key = f"{classification.get('domain', 'general')}:{classification.get('task_type', 'unknown')}"
        pattern_counts[key] += 1
        pattern_examples[key].append(ep)

    # Only keep patterns that appear 3+ times
    consolidated_patterns = []
    for pattern_key, count in pattern_counts.items():
        if count >= 3:
            domain, task_type = pattern_key.split(":")
            pattern = {
                "type": "consolidated_pattern",
                "domain": domain,
                "task_type": task_type,
                "occurrence_count": count,
                "confidence": min(1.0, count / 10),
                "first_seen": min(e.get("timestamp", "") for e in pattern_examples[pattern_key]),
                "last_seen": max(e.get("timestamp", "") for e in pattern_examples[pattern_key]),
                "hash": hash_fact(pattern_key),
                "consolidated_at": get_timestamp()
            }
            consolidated_patterns.append(pattern)

    return consolidated_patterns


def merge_memories(existing: dict, new_facts: list, new_patterns: list) -> dict:
    """Merge new memories into existing, handling updates."""
    # Deduplicate facts
    unique_facts, fact_dupes = deduplicate_facts(new_facts, existing["facts"])

    # Deduplicate patterns
    unique_patterns, pattern_dupes = deduplicate_facts(new_patterns, existing["patterns"])

    # Merge
    result = {
        "facts": existing["facts"] + unique_facts,
        "patterns": existing["patterns"] + unique_patterns,
        "decisions": existing["decisions"],
        "consolidation_stats": {
            "new_facts": len(unique_facts),
            "duplicate_facts": fact_dupes,
            "new_patterns": len(unique_patterns),
            "duplicate_patterns": pattern_dupes,
            "timestamp": get_timestamp()
        }
    }

    return result


def save_semantic_memory(memory: dict):
    """Save semantic memory to files."""
    for mem_type in ["facts", "patterns", "decisions"]:
        mem_file = SEMANTIC_DIR / f"{mem_type}.jsonl"
        with open(mem_file, "w") as f:
            for item in memory.get(mem_type, []):
                f.write(json.dumps(item) + "\n")


def save_consolidation_log(stats: dict):
    """Log consolidation run."""
    log_file = CONSOLIDATED_DIR / "consolidation-log.jsonl"
    with open(log_file, "a") as f:
        f.write(json.dumps(stats) + "\n")


def main():
    """Main consolidation process."""
    print("Starting memory consolidation...", file=sys.stderr)

    # Load recent episodes
    episodes = load_recent_episodes()
    print(f"Loaded {len(episodes)} recent episodes", file=sys.stderr)

    if not episodes:
        result = {
            "status": "no_episodes",
            "episodes_processed": 0,
            "timestamp": get_timestamp()
        }
        print(json.dumps(result))
        return

    # Load existing semantic memory
    existing_memory = load_semantic_memory()
    print(f"Existing memory: {len(existing_memory['facts'])} facts, {len(existing_memory['patterns'])} patterns", file=sys.stderr)

    # Extract facts from episodes
    new_facts = extract_facts_from_episodes(episodes)
    print(f"Extracted {len(new_facts)} new facts", file=sys.stderr)

    # Consolidate patterns
    new_patterns = consolidate_patterns(episodes)
    print(f"Consolidated {len(new_patterns)} patterns", file=sys.stderr)

    # Merge memories
    merged_memory = merge_memories(existing_memory, new_facts, new_patterns)

    # Save
    save_semantic_memory(merged_memory)
    save_consolidation_log(merged_memory["consolidation_stats"])

    result = {
        "status": "success",
        "episodes_processed": len(episodes),
        "new_facts": merged_memory["consolidation_stats"]["new_facts"],
        "new_patterns": merged_memory["consolidation_stats"]["new_patterns"],
        "total_facts": len(merged_memory["facts"]),
        "total_patterns": len(merged_memory["patterns"]),
        "timestamp": get_timestamp()
    }

    print(json.dumps(result))


if __name__ == "__main__":
    main()
