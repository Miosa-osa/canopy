# /pattern-capture

> Extract and store reusable patterns from completed tasks.

## Usage
```
/pattern-capture [--domain <domain>] [--from-session] [--list]
```

## What It Does
Analyzes completed work to extract reusable patterns: code patterns, debugging approaches, architectural decisions, process improvements. Stores them in the pattern library indexed by domain and task type, with usage count and success rate tracking.

## Implementation
1. **Analyze** -- review the current session's tool executions and outcomes.
2. **Extract** -- identify repeatable patterns (code structures, debugging steps, decision frameworks).
3. **Classify** -- domain (frontend, backend, devops, etc.), type (code_pattern, process, decision), confidence.
4. **Deduplicate** -- check against existing patterns, increment usage count if duplicate.
5. **Store** -- write to pattern library with metadata (domain, confidence, usage_count, success_rate).

Pattern format:
```json
{
  "id": "pattern-id",
  "domain": "backend",
  "type": "code_pattern",
  "title": "Pattern name",
  "description": "When and how to use",
  "confidence": 0.85,
  "usage_count": 5
}
```

## Examples
```bash
# Capture patterns from current session
/pattern-capture --from-session

# Capture patterns for a specific domain
/pattern-capture --domain backend

# List all stored patterns
/pattern-capture --list
```
