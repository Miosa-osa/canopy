---
name: learning-engine
description: "Self-learning system based on SICA, VIGIL, and Mem0 patterns. Auto-triggers after task completion. Captures patterns, consolidates memory, generates skills, recovers from errors."
triggers: ["*"]
priority: 1
metadata:
  version: "4.0"
  research_basis:
    - "SICA: Self-Improving Coding Agent (arXiv:2504.15228)"
    - "VIGIL: Reflective Runtime for Self-Healing (arXiv:2512.07094)"
    - "Mem0: Memory Consolidation Architecture"
    - "Synapse: Spreading Activation Memory (arXiv:2601.02744)"
    - "ReCreate: Experience-Driven Agent Creation (arXiv:2601.11100)"
---

# Learning Engine v4.0 (Self-Learning Core)

## Overview

The learning engine implements a continuous self-improvement loop:

```
OBSERVE → REFLECT → PROPOSE → TEST → INTEGRATE
   ↓         ↓         ↓        ↓        ↓
Capture   Analyze   Generate   Rank    Accept if
metrics   failures  options    by      beneficial
& traces  & gaps             merit
```

## Self-Learning Loop (SICA Pattern)

### 1. Observe
- Capture all tool executions via `learning-capture.py` hook
- Record decisions, outcomes, durations
- Store episodic traces in `~/.claude/learning/episodes/`

### 2. Reflect
- Analyze failures with VIGIL pattern (`error-recovery.py` hook)
- Classify errors and suggest recovery strategies
- Generate reflection on what went wrong

### 3. Propose
- When patterns repeat 5+ times, propose skill generation
- Run `scripts/generate-skill.py` to create new skills
- Store in `~/.claude/skills/generated/`

### 4. Test
- Validate new patterns against success criteria
- Compare against baseline performance
- Check for regressions

### 5. Integrate
- Accept improvements if performance > baseline
- Consolidate memory with `scripts/consolidate-memory.py`
- Update agent capabilities and routing

## Quick Classification

After task completion, classify:

1. **Task Type**: feature | bug | refactor | test | docs | research | security
2. **Domain**: frontend | backend | database | devops | security | ai-ml | orchestration
3. **Complexity**: simple | moderate | complex | critical
4. **Agent Used**: Record which agent handled the task
5. **Outcome**: success | partial | failed | escalated
6. **Learning Value**: low | medium | high (errors are high value)

## Memory Architecture (Three-Tier)

### Tier 1: Working Memory
- Current conversation context
- TTL: 15 minutes
- Storage: In-context
- Purpose: Immediate recall

### Tier 2: Episodic Memory
- Full interaction traces with timestamps
- TTL: 30 days
- Storage: `~/.claude/learning/episodes/`
- Purpose: Experience replay, pattern extraction

### Tier 3: Semantic Memory
- Consolidated facts and patterns
- TTL: Permanent
- Storage: `~/.claude/learning/semantic/`
- Purpose: Long-term knowledge

## Consolidation Process (Mem0 Pattern)

Run periodically (after 5 interactions or end of session):

```bash
python3 ~/.claude/skills/learning-engine/scripts/consolidate-memory.py
```

Operations:
- **ADD**: Genuinely new information
- **UPDATE**: Augment existing with recent details
- **DELETE**: Remove contradicted facts
- **NOOP**: Already exists or irrelevant

## Dynamic Skill Generation (ReCreate Pattern)

When patterns repeat 5+ times:

```bash
python3 ~/.claude/skills/learning-engine/scripts/generate-skill.py
```

Generated skills stored in `~/.claude/skills/generated/` with:
- SKILL.md definition
- Metadata (confidence, domain, pattern type)
- Auto-incremented instance count

## Error Recovery (VIGIL Pattern)

Error taxonomy with recovery strategies:

| Error Type | Severity | Recovery |
|------------|----------|----------|
| file_not_found | recoverable | Check path, use Glob |
| permission_denied | recoverable | Check permissions |
| syntax_error | recoverable | Review code, validate syntax |
| import_error | recoverable | Install dependency |
| type_error | recoverable | Check signatures |
| network_error | transient | Retry, check connectivity |
| timeout_error | transient | Increase timeout, chunk work |

## Gap Detection Signals

- No good agent match found for task
- User corrections needed after completion
- Repeated explanations required
- Task outside known domains
- Low success rate (<70%) on task type
- Multiple escalations needed (3+)
- Confidence below threshold (0.7)

When a gap is detected:
1. Log to `~/.claude/learning/gaps/`
2. Suggest agent creation
3. Track for pattern emergence

## Storage Structure

```
~/.claude/learning/
├── episodes/           # Episodic memory (by date)
│   └── YYYY-MM-DD-episodes.jsonl
├── semantic/           # Semantic memory (consolidated)
│   ├── facts.jsonl
│   ├── patterns.jsonl
│   └── decisions.jsonl
├── patterns/           # Extracted patterns (by domain)
│   ├── go/
│   ├── typescript/
│   └── general/
├── solutions/          # Problem-solution pairs
│   ├── error_resolution/
│   └── feature_implementation/
├── gaps/               # Detected capability gaps
│   └── index.json
├── metrics/            # Usage statistics
│   └── index.json
├── errors/             # Error log for VIGIL
│   └── error-log.jsonl
└── consolidated/       # Consolidation history
    └── consolidation-log.jsonl
```

## Pattern Storage Format

```json
{
  "id": "auth-jwt-refresh",
  "domain": "backend",
  "type": "code_pattern",
  "title": "JWT Token Refresh",
  "description": "Pattern for refreshing expired JWT tokens",
  "code_snippet": "...",
  "tags": ["auth", "jwt", "security"],
  "usage_count": 5,
  "success_rate": 0.9,
  "confidence": 0.85,
  "created": "2026-01-15",
  "last_used": "2026-01-26",
  "hash": "abc123def456"
}
```

## Hooks Integration

### learning-capture.py (PostToolUse)
- Captures all tool executions
- Extracts patterns from successful interactions
- Updates metrics

### error-recovery.py (PostToolUse)
- Analyzes errors with VIGIL pattern
- Suggests recovery strategies
- Logs for future learning

### telemetry-collector.py (PostToolUse)
- Tracks routing decisions
- Measures latency and cost
- Feeds into optimization

### context-optimizer.py (PreToolUse)
- Applies progressive disclosure
- Manages token budget
- Tracks context usage

## Commands

```bash
# Run memory consolidation
python3 ~/.claude/skills/learning-engine/scripts/consolidate-memory.py

# Generate skills from patterns
python3 ~/.claude/skills/learning-engine/scripts/generate-skill.py

# View learning metrics
cat ~/.claude/learning/metrics/index.json | jq .

# View recent episodes
tail -20 ~/.claude/learning/episodes/$(date +%Y-%m-%d)-episodes.jsonl | jq .

# View error log
tail -20 ~/.claude/learning/errors/error-log.jsonl | jq .
```

## Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Pattern Extraction | 80%+ success rate | patterns with usage_count > 3 |
| Memory Consolidation | <500ms latency | consolidation run time |
| Skill Generation | 70%+ confidence | generated skill confidence |
| Error Recovery | 60%+ auto-resolution | errors with recovery applied |
| Gap Detection | 90%+ coverage | detected vs undetected gaps |

## Advanced Resources

- @scripts/generate-skill.py - Dynamic skill generation
- @scripts/consolidate-memory.py - Memory consolidation
- @resources/advanced-metrics.md - Detailed metrics guide
- @resources/error-taxonomy.md - Full error classification
