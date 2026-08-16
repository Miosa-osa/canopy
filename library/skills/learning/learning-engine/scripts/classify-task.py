#!/usr/bin/env python3
"""
Task Classification Script for Learning Engine
Extracts domain, complexity, and patterns from task descriptions
"""

import re
import sys
import json
from typing import Dict, List, Tuple

# Domain keywords mapping
DOMAIN_KEYWORDS = {
    "frontend": ["react", "svelte", "vue", "css", "tailwind", "component", "ui", "ux", "button", "form", "modal", "page", "route"],
    "backend": ["api", "endpoint", "server", "handler", "controller", "service", "go", "node", "express", "chi", "rest", "graphql"],
    "database": ["sql", "query", "postgres", "redis", "migration", "index", "table", "schema", "database", "db"],
    "devops": ["docker", "kubernetes", "k8s", "deploy", "ci", "cd", "pipeline", "cloud", "gcp", "aws", "terraform"],
    "security": ["auth", "permission", "jwt", "token", "vulnerability", "xss", "injection", "csrf", "owasp"],
    "ai-ml": ["ai", "ml", "model", "train", "inference", "gemma", "llm", "embedding", "fine-tune", "onnx"],
    "testing": ["test", "spec", "coverage", "mock", "unit", "integration", "e2e"]
}

# Complexity indicators
COMPLEXITY_INDICATORS = {
    "simple": ["fix typo", "update text", "change color", "rename", "add comment"],
    "moderate": ["add feature", "implement", "create", "build", "refactor"],
    "complex": ["redesign", "migrate", "optimize", "architecture", "integrate multiple"],
    "critical": ["security fix", "production bug", "data loss", "performance critical"]
}

# Task type patterns
TASK_TYPES = {
    "feature": ["add", "implement", "create", "build", "new"],
    "bug": ["fix", "bug", "error", "broken", "not working", "crash"],
    "refactor": ["refactor", "clean", "improve", "restructure", "simplify"],
    "test": ["test", "spec", "coverage", "tdd"],
    "docs": ["document", "readme", "comment", "explain"],
    "research": ["investigate", "explore", "research", "analyze", "understand"]
}

def classify_domain(text: str) -> Tuple[str, float]:
    """Classify the domain of a task"""
    text_lower = text.lower()
    scores = {}

    for domain, keywords in DOMAIN_KEYWORDS.items():
        score = sum(1 for kw in keywords if kw in text_lower)
        if score > 0:
            scores[domain] = score

    if not scores:
        return "general", 0.5

    best_domain = max(scores, key=scores.get)
    confidence = min(scores[best_domain] / 5, 1.0)  # Normalize to 0-1

    return best_domain, confidence

def classify_complexity(text: str) -> str:
    """Classify task complexity"""
    text_lower = text.lower()

    for complexity, indicators in COMPLEXITY_INDICATORS.items():
        if any(ind in text_lower for ind in indicators):
            return complexity

    # Default based on text length and word count
    words = len(text.split())
    if words < 10:
        return "simple"
    elif words < 30:
        return "moderate"
    else:
        return "complex"

def classify_task_type(text: str) -> str:
    """Classify the type of task"""
    text_lower = text.lower()

    for task_type, patterns in TASK_TYPES.items():
        if any(p in text_lower for p in patterns):
            return task_type

    return "feature"  # Default

def extract_entities(text: str) -> List[str]:
    """Extract file names, function names, etc."""
    entities = []

    # File patterns
    files = re.findall(r'[\w/-]+\.(ts|tsx|js|jsx|go|py|svelte|md|json)', text)
    entities.extend(files)

    # Function/component patterns
    functions = re.findall(r'\b([A-Z][a-zA-Z]+(?:Component|Handler|Service|Controller))\b', text)
    entities.extend(functions)

    return list(set(entities))

def classify(task_description: str) -> Dict:
    """Main classification function"""
    domain, confidence = classify_domain(task_description)
    complexity = classify_complexity(task_description)
    task_type = classify_task_type(task_description)
    entities = extract_entities(task_description)

    return {
        "domain": domain,
        "domain_confidence": confidence,
        "complexity": complexity,
        "task_type": task_type,
        "entities": entities,
        "suggested_agents": get_suggested_agents(domain, task_type)
    }

def get_suggested_agents(domain: str, task_type: str) -> List[str]:
    """Suggest agents based on classification"""
    agents = []

    # Domain-based suggestions
    domain_agents = {
        "frontend": ["@frontend-react", "@frontend-svelte", "@ui-ux-designer"],
        "backend": ["@backend-go", "@backend-node", "@api-designer"],
        "database": ["@database-specialist", "@orm-expert"],
        "devops": ["@devops-engineer", "@angel"],
        "security": ["@security-auditor"],
        "ai-ml": ["@oracle", "@nova"],
        "testing": ["@test-automator", "@qa-engineer"]
    }
    agents.extend(domain_agents.get(domain, []))

    # Task type additions
    if task_type == "bug":
        agents.insert(0, "@debugger")
    elif task_type == "refactor":
        agents.insert(0, "@refactorer")
    elif task_type == "docs":
        agents.append("@doc-writer")

    return agents[:3]  # Return top 3

if __name__ == "__main__":
    if len(sys.argv) > 1:
        task = " ".join(sys.argv[1:])
    else:
        task = sys.stdin.read().strip()

    result = classify(task)
    print(json.dumps(result, indent=2))
