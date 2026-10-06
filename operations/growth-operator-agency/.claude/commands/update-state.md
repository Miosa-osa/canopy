---
description: Refresh PROJECT-STATE.md + memory index from current workspace state + tasks. Run at end of each working session OR whenever significant progress has been made so the next session boots without cold-read overhead.
argument-hint: [optional: "full" to also re-read all _private/ extracts, else fast pass]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, TaskList
---

# /update-state — Harness: Cross-Session State Sync

This is a **harness command**, not a business skill. It exists to keep the workspace's state layer coherent so every new Claude Code session wakes up informed.

## What this command does

1. **Read current state source-of-truth files:**
   - `CLAUDE.md` (mission + strategy)
   - `PROJECT-STATE.md` (current dashboard)
   - Per-project memory index (Claude Code project memory directory)
   - `_private/<agency>/agency-profile.yaml` (agency identity, gitignored)
   - `_private/<agency>/active-engagements.md` (active clients, gitignored)
   - `_private/<client-slug>/` (active client extracts, gitignored)
   - `company.yaml` (active creator profile)

2. **Pull live task state** via `TaskList`.

3. **Compute deltas:**
   - What shipped since last update (check git log + recent edits)
   - What's blocked and why
   - What's next priority (look at tasks + goals in company.yaml)
   - What compartments in `company.yaml` are below threshold (per `spec/CONTEXT-THRESHOLDS.md`)

4. **Rewrite `PROJECT-STATE.md`:**
   - Keep `Last updated` fresh
   - Update runtime status table
   - Sync active tasks (from TaskList)
   - Refresh blockers list
   - Append to `## Log` section with today's entry

5. **Optionally update CLAUDE.md Version log** (only if mission/strategy shifted — not routine task movement).

6. **Verify memory index** matches memory files on disk. If new memory file exists without index entry, add pointer to `MEMORY.md`.

## When to run

- At end of every working session
- After a significant strategic pivot (so the state reflects it before compaction)
- Before hopping between clients (so we know what we're leaving behind)
- Whenever `PROJECT-STATE.md` is older than 24h and real work has happened

## When NOT to run

- Mid-skill-execution (finish the skill first)
- If the only change is a minor tweak to one file

## Arguments

- `full` — re-read all `_private/` extracts + case studies + engagements. Slower but catches drift.
- (default) — fast pass: tasks + git + top-level state files only.

`$ARGUMENTS`

## Output format

```markdown
# State update — {YYYY-MM-DD} {HH:MM}

**Since last update ({prev_timestamp}):**
- Shipped: [bullet list of completed tasks + significant edits]
- Deleted: [bullet list of obsolete tasks]
- Added: [bullet list of new tasks]
- Blocked: [bullet list of blockers]

**Compartment completeness (company.yaml):**
- C1 Creator Identity: {X}% {status}
- C2 Audience: {X}% {status}
- ...

**Next-up recommendations (ranked by $ leverage):**
1. [task id] — [task subject] — [estimated delta]
2. ...

**Files updated this run:**
- PROJECT-STATE.md
- MEMORY.md (if needed)
```

Emit this summary inline, then write the updated files.

## Failure handling

If any source file is missing (e.g., `company.yaml` emptied, `PROJECT-STATE.md` deleted), flag the gap inline but do NOT auto-create placeholder files — surface to the operator for intentional action.

## Cross-command routing

Pairs with:
- `/attach-client {slug}` — when switching active client, run this first to checkpoint current state
- Any skill invocation — run this after significant skill outputs to keep state fresh

---

*harness v1.0 — the persistence layer for Claude-Code-first operating mode.*
*When autonomous mode activates (Paperclip-driven), this command becomes a heartbeat-triggered routine instead of operator-invoked.*
