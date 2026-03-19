# /review

> Code and deliverable review. Analyst-owned.

## Usage
```
/review <target> [--checklist <standard|security|performance>]
```

## What It Does
Reviews code, documents, or deliverables against quality standards. Produces a
structured verdict with issues categorized by severity.

## Implementation
1. **Load target** — Read the file, PR, or deliverable.
2. **Check** — Run against selected checklist (correctness, security, performance, style).
3. **Categorize** — Issues ranked: CRITICAL > MAJOR > MINOR.
4. **Verdict** — APPROVE, NEEDS CHANGES, or BLOCK with actionable items.

## Examples
```bash
/review src/auth.ts --checklist security
/review docs/proposal.md
/review PR#42 --checklist standard
```
