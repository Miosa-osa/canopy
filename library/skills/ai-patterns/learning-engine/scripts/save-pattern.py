#!/usr/bin/env python3
"""
Save a learned pattern to the learning storage.
Called after successful task completion.
"""

import json
import os
import sys
from datetime import datetime
from pathlib import Path

LEARNING_DIR = Path.home() / ".claude" / "learning"

def save_pattern(pattern_data: dict) -> dict:
    """Save a pattern to the patterns storage."""
    domain = pattern_data.get("domain", "general")
    pattern_id = pattern_data.get("id", f"pattern-{datetime.now().strftime('%Y%m%d%H%M%S')}")

    # Ensure directory exists
    pattern_dir = LEARNING_DIR / "patterns" / domain
    pattern_dir.mkdir(parents=True, exist_ok=True)

    # Add metadata
    pattern_data["id"] = pattern_id
    pattern_data["created"] = pattern_data.get("created", datetime.now().isoformat())
    pattern_data["last_used"] = datetime.now().isoformat()
    pattern_data["usage_count"] = pattern_data.get("usage_count", 0) + 1

    # Save pattern
    pattern_file = pattern_dir / f"{pattern_id}.json"
    with open(pattern_file, "w") as f:
        json.dump(pattern_data, f, indent=2)

    # Update index
    update_index("patterns", pattern_data)

    return {"status": "saved", "id": pattern_id, "path": str(pattern_file)}

def save_solution(solution_data: dict) -> dict:
    """Save a solution to the solutions storage."""
    category = solution_data.get("category", "general")
    solution_id = solution_data.get("id", f"solution-{datetime.now().strftime('%Y%m%d%H%M%S')}")

    # Ensure directory exists
    solution_dir = LEARNING_DIR / "solutions" / category
    solution_dir.mkdir(parents=True, exist_ok=True)

    # Add metadata
    solution_data["id"] = solution_id
    solution_data["created"] = solution_data.get("created", datetime.now().isoformat())
    solution_data["last_used"] = datetime.now().isoformat()

    # Save solution
    solution_file = solution_dir / f"{solution_id}.json"
    with open(solution_file, "w") as f:
        json.dump(solution_data, f, indent=2)

    # Update index
    update_index("solutions", solution_data)

    return {"status": "saved", "id": solution_id, "path": str(solution_file)}

def update_index(storage_type: str, item_data: dict):
    """Update the index file for a storage type."""
    index_file = LEARNING_DIR / storage_type / "index.json"

    # Load existing index
    if index_file.exists():
        with open(index_file) as f:
            index = json.load(f)
    else:
        index = {"version": "1.0.0", "items": [], "stats": {}}

    # Update or add item
    item_id = item_data["id"]
    existing = next((i for i in index["items"] if i.get("id") == item_id), None)

    summary = {
        "id": item_id,
        "title": item_data.get("title", "Untitled"),
        "domain": item_data.get("domain", item_data.get("category", "general")),
        "tags": item_data.get("tags", []),
        "created": item_data.get("created"),
        "last_used": item_data.get("last_used"),
    }

    if existing:
        index["items"].remove(existing)
    index["items"].append(summary)

    # Update stats
    index["stats"]["total"] = len(index["items"])
    index["stats"]["last_updated"] = datetime.now().isoformat()

    # Save index
    with open(index_file, "w") as f:
        json.dump(index, f, indent=2)

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No data provided"}))
        sys.exit(1)

    try:
        data = json.loads(sys.argv[1])
        storage_type = data.get("type", "pattern")

        if storage_type == "pattern":
            result = save_pattern(data)
        elif storage_type == "solution":
            result = save_solution(data)
        else:
            result = {"error": f"Unknown type: {storage_type}"}

        print(json.dumps(result))
    except json.JSONDecodeError as e:
        print(json.dumps({"error": f"Invalid JSON: {e}"}))
        sys.exit(1)

if __name__ == "__main__":
    main()
