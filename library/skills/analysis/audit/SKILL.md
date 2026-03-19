---
name: audit
description: >
  Multi-domain audit with weighted scoring. Spawns parallel subagents per audit
  domain. Each check has severity weight and category weight. Produces a quantified
  health score (0-100) with prioritized findings. Supports security, code quality,
  performance, compliance, and custom domains.
  Triggers on: "audit", "assess", "evaluate quality", "score"
---

# /audit

> Multi-domain audit with quantified scoring and prioritized findings.

## Purpose

Run a comprehensive, multi-domain audit of a workspace, codebase, or knowledge base. Each domain (security, quality, performance, compliance, etc.) gets its own audit pass — optionally parallelized via subagents. Every finding has a severity weight and category weight, producing a single quantified score (0-100) that represents overall health. Results are prioritized so you fix the most impactful issues first.

## Usage

```bash
# Full audit (all domains)
/audit

# Audit specific domains
/audit --domains security,quality

# Audit a specific path
/audit path/to/project/

# Audit with parallel subagents
/audit --parallel

# Audit with custom weights
/audit --weight security:2.0 --weight quality:1.5

# Quick audit (essential checks only)
/audit --depth quick

# Export audit report
/audit --output report.md --format markdown
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `<path>` | positional | `.` | Target to audit |
| `--domains` | string[] | `all` | Domains: `security`, `quality`, `performance`, `compliance`, `knowledge`, `process` |
| `--parallel` | flag | false | Run domain audits as parallel subagents |
| `--depth` | enum | `standard` | `quick` (top checks only), `standard` (full), `deep` (exhaustive + edge cases) |
| `--weight` | key:value[] | defaults | Override category weights (e.g., `security:2.0`) |
| `--format` | enum | `terminal` | `terminal`, `markdown`, `json`, `csv` |
| `--output` | path | stdout | Write report to file |
| `--baseline` | path | — | Compare against previous audit |
| `--fail-under` | int | — | Exit with error if score below this threshold |

## Workflow

1. **Plan** — Determine which domains to audit based on target type and `--domains` flag. Load check definitions for each domain.
2. **Dispatch** — If `--parallel`, spawn a subagent per domain via `/spawn`. Otherwise, run sequentially.
3. **Execute checks** — Each domain runs its check list. Every check produces:
   - Status: `pass`, `warn`, `fail`, `skip`
   - Severity: `critical` (weight 4), `high` (3), `medium` (2), `low` (1)
   - Evidence: specific file, line, or configuration that triggered the finding
4. **Score** — Calculate weighted score per domain and overall:
   - Domain score = (checks passed / total checks) * 100, weighted by severity
   - Overall score = weighted average of domain scores (using category weights)
5. **Prioritize** — Sort findings by impact: severity weight * category weight. Top findings get fixed first.
6. **Compare** — If `--baseline` provided, show delta: improved, regressed, new, resolved.
7. **Report** — Emit scored report with prioritized findings and remediation suggestions.

## Output

```markdown
## Audit Report — 2026-03-20

**Target:** /workspace
**Domains:** security, quality, performance, knowledge
**Depth:** standard
**Overall Score: 72/100**

### Domain Scores
| Domain | Score | Weight | Checks | Pass | Warn | Fail |
|--------|-------|--------|--------|------|------|------|
| Security | 85/100 | 2.0x | 15 | 12 | 2 | 1 |
| Quality | 68/100 | 1.5x | 22 | 14 | 5 | 3 |
| Performance | 74/100 | 1.0x | 10 | 7 | 2 | 1 |
| Knowledge | 61/100 | 1.0x | 18 | 10 | 5 | 3 |

### Top Findings (by impact)

| # | Domain | Severity | Finding | File/Location |
|---|--------|----------|---------|---------------|
| 1 | Security | critical | API key exposed in config | config/dev.exs:14 |
| 2 | Quality | high | 3 functions exceed 100 LOC | lib/engine/search.ex |
| 3 | Knowledge | high | 12 orphaned signal files | 09-new-stuff/signals/ |
| 4 | Performance | medium | N+1 query in context loader | lib/engine/context.ex:88 |
| 5 | Quality | medium | No tests for 4 modules | lib/engine/mcts.ex, ... |

### Remediation Priority
1. **Rotate API key and move to env var** (security/critical, ~5 min)
2. **Extract functions in search.ex** (quality/high, ~30 min)
3. **Route orphaned signals** (knowledge/high, ~20 min)
4. **Add preloading to context query** (performance/medium, ~15 min)
5. **Write module tests** (quality/medium, ~2 hours)

### vs. Baseline (2026-03-13)
| Metric | Previous | Current | Delta |
|--------|----------|---------|-------|
| Overall | 65 | 72 | +7 |
| New findings | — | 2 | — |
| Resolved | — | 5 | — |
| Regressed | — | 1 | — |
```

## Dependencies

- Domain-specific check definitions (security rules, quality standards, etc.)
- `/spawn` — For parallel domain audits
- `/health` — Related but focused on knowledge base specifically
- Code analysis tools (linter, security scanner)
- File system access to audit target
