# /handoff

> Transfer context between agents or sessions with structured state preservation.

## Usage
```
/handoff --to <agent|session> [--context "<summary>"] [--files "<file-list>"]
```

## What It Does
Packages the current working context into a structured handoff document that another agent or session can load to continue work without losing state. Captures: current progress, open decisions, blocking issues, relevant files, and next steps.

## Implementation
1. **Capture state** -- current task, progress, decisions made, files modified.
2. **Package context** -- write structured handoff document:
   - What was done
   - What's in progress
   - What's blocked
   - Key decisions made (with rationale)
   - Files to read
   - Next steps
3. **Write handoff** -- save to `work/handoff-<timestamp>.md`.
4. **Notify** -- if handing to a specific agent, include routing metadata.

## Examples
```bash
# Hand off to another agent
/handoff --to "backend-go" --context "Auth flow designed, need implementation"

# Hand off between sessions
/handoff --to session --files "lib/auth.ex, test/auth_test.exs"

# Quick handoff with inline context
/handoff --to "test-automator" --context "Feature implemented, needs test coverage"
```
