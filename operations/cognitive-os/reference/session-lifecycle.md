# Session Lifecycle

A reference for how to structure any working session in OptimalOS — from the moment context loads to the moment state is persisted. Every session has three phases, five types, and a set of context budget constraints that determine what can be loaded at once.

---

## Three Phases

Every session — regardless of type — follows this structure.

### Phase 1: Orient

Load the minimum context needed to work effectively. Do not load everything. Load what the session type requires.

```bash
# Always-loaded context (L0 cache — ~2K tokens)
cd engine && mix optimal.l0

# Today's operating state (~500 tokens)
# Read: /Users/rhl/Desktop/OptimalOS/rhythm/today.md

# Topic context if working on a specific domain (~5K tokens)
cd engine && mix optimal.assemble "{topic}"
```

Orient checklist:
- [ ] What mode is this session? (BUILD / OPERATE / LEARN / SYNTHESIZE / EXTRACT)
- [ ] What is the single focus for this session?
- [ ] What context is needed — and what is NOT needed?
- [ ] Are there pending signals from the previous session? (check `rhythm/today.md`)

### Phase 2: Work

Execute in the current cognitive mode. Each mode has a different operating pattern.

| Mode | What You Do | What the Engine Does |
|------|------------|---------------------|
| BUILD | Create: code, specs, content, playbooks | Provide assembled context via `assemble` |
| OPERATE | Clear queue: Slack, email, delegate, triage | Route incoming signals via `ingest` |
| LEARN | Absorb: read, watch, process new material | Search for related existing context |
| SYNTHESIZE | Connect: find patterns across nodes, build ADRs | Graph analysis via `graph triangles` |
| EXTRACT | Capture: post-call, convert conversation to signal | Immediate `ingest` of raw transcript |

During work, apply the Signal Theory encoding check before any output leaves the system:
1. Mode: How will the receiver perceive this?
2. Genre: What conventionalized form fits?
3. Type: Direct / Inform / Commit / Decide / Express?
4. Format: Markdown / code / JSON / prose?
5. Structure: Is the skeleton imposed?

### Phase 3: Persist

Save state before ending the session. Nothing is real until it is written.

```bash
# Capture any pending observations
cd engine && mix optimal.remember --contextual

# For EXTRACT sessions: ingest the signal immediately
cd engine && mix optimal.ingest "summary of what happened"

# For decisions: update the relevant context.md "Key Decisions" section manually
# For financial data: engine auto-routes, but verify 11-money-revenue was updated
# For delegations: add fidelity tracking entry to relevant signal.md
```

Persist checklist:
- [ ] All signals ingested (`mix optimal.ingest` or manual write)
- [ ] Persistent facts updated in context.md (not signal.md)
- [ ] Decisions logged with date and rationale
- [ ] Delegations added to fidelity tracking table in signal.md
- [ ] `rhythm/today.md` updated with what happened and what's next
- [ ] Energy log updated if end of day (`rhythm/energy.md`)

---

## Session Types

### 1. Brain Dump (Monday)

**Trigger**: Monday morning, start of week
**Mode**: EXTRACT → SYNTHESIZE → BUILD
**Duration**: 60-90 minutes

**Procedure**:
1. The operator talks stream-of-consciousness, node by node (01 through 12)
2. Capture everything — do not interrupt while The operator is processing
3. After capture: classify each statement → route to the right signal.md / context.md
4. Identify the top 3 critical non-negotiables for the week
5. Build `week-plan.md` from extracted priorities
6. Identify signals that need to go OUT to people (and in what genre for each person)

**Engine commands**:
```bash
cd engine && mix optimal.ingest "raw brain dump content" --genre note
cd engine && mix optimal.assemble "current week priorities"
```

**Output**: Updated `week-plan.md` with non-negotiables, time blocks, dependencies, and success criteria.

---

### 2. Deep Work (BUILD mode)

**Trigger**: BUILD blocks (5-8pm and 9pm-1am per rhythm)
**Mode**: BUILD
**Duration**: 2-4 hours (single focus)

**Procedure**:
1. Load topic context: `mix optimal.assemble "{topic}"`
2. Single focus — no Slack, no queue clearing
3. Work against a specific output: spec, code, playbook, content
4. At end of block: capture any new signals or decisions before switching modes

**Engine commands**:
```bash
cd engine && mix optimal.assemble "the specific topic being built"
cd engine && mix optimal.search "related prior work" --limit 5
```

**Output**: The built artifact (spec / code / playbook / content) + updated signal files.

---

### 3. Triage (OPERATE mode)

**Trigger**: OPERATE block (3-5pm, after boot)
**Mode**: OPERATE
**Duration**: 1-2 hours

**Procedure**:
1. Clear queue: Slack, email, voicemail
2. For each incoming item: classify → route → delegate or action
3. Delegate using the People table genre preferences — never send Robert a spec
4. Capture all delegations in the relevant signal.md fidelity tracking table
5. Ingest any signals that arrived since last session

**Engine commands**:
```bash
cd engine && mix optimal.ingest "signal from Slack or email"
cd engine && mix optimal.search "context for incoming question"
```

**Output**: Empty queue + ingested signals + delegations logged.

---

### 4. Review (Friday)

**Trigger**: Friday, end of week
**Mode**: SYNTHESIZE
**Duration**: 45-60 minutes

**Procedure**:
1. **Single-loop**: Did the 3 non-negotiables happen? (check `week-plan.md`)
2. **Double-loop**: Were they the RIGHT 3 things? Update `weekly-review.md`
3. **Fidelity check**: Did delegated signals come back as intended? Check signal.md fidelity tracking tables
4. Update `alignment.md` drift scores across 4 dimensions
5. Run health diagnostics:
   ```bash
   cd engine && mix optimal.health
   cd engine && mix optimal.reweave "key topic" --days 14
   cd engine && mix optimal.graph triangles
   cd engine && mix optimal.remember --escalations
   ```
6. Build next week's priorities (seeds `week-plan.md` for Monday)

**Output**: Updated `weekly-review.md`, `alignment.md`, and seeded priorities for Monday brain dump.

---

### 5. Extract (Post-Call)

**Trigger**: Immediately after any call or meeting
**Mode**: EXTRACT
**Duration**: 10-15 minutes (do not let it go longer — memory decays fast)

**Procedure**:
1. While memory is fresh: `mix optimal.ingest` the signal immediately
2. Use `--genre transcript` for meeting notes, `--genre note` for quick captures
3. Extract: participants, key points, decisions made, action items, open questions
4. For decisions: update relevant context.md "Key Decisions" manually
5. For financial commitments: verify engine routed to 11-money-revenue

**Engine commands**:
```bash
cd engine && mix optimal.ingest "Ed called about pricing. He wants $2K per seat. Decision pending." --genre note
cd engine && mix optimal.ingest --file path/to/notes.md --genre transcript --title "Ed Honour Pricing Call"
```

**Rule**: Never let an EXTRACT session happen more than 30 minutes after the triggering call. Signal degrades.

---

## Context Budget

The context window is a finite resource. Treat it like RAM.

| Layer | Token Budget | Source | When to Load |
|-------|-------------|--------|-------------|
| L0 always-loaded | ~2K | `mix optimal.l0` | Every session |
| Today context | ~500 | `rhythm/today.md` | Every session |
| Topic assembly | ~5K | `mix optimal.assemble` | When working on a specific domain |
| Active work content | ~40K | Files read during session | As needed, purge when done |
| Reasoning reserve | 150K minimum | System reserve | Never consume this |
| Buffer | 25K | Safety margin | Never consume this |

**Total usable**: ~1M tokens minus reserves = ~825K active tokens

**Token allocation per agent**:
- System context: 75K
- Agent instructions: 125K
- Tools: 75K
- Conversation history: 250K
- Execution context: 300K
- Reasoning: 150K
- Buffer: 25K

**Tiered loading strategy** (follow this every time):
1. Search returns L0 abstracts (~100 tokens each)
2. Read L1 if a result looks relevant (~2K tokens per file)
3. Read full only if L1 confirms it's necessary (~10K+ tokens)
4. Never read full when L1 suffices — this is the most common context waste

---

## Transitions

Every mode switch follows: **SAVE → CLEAR → LOAD**

This is not optional. Context bleed between modes degrades performance.

```
SAVE:  Capture pending signals. Update rhythm/today.md with current state.
       Note any half-finished thoughts. Ingest if in EXTRACT mode.

CLEAR: Mental context switch. Close files. The engine handles the rest.
       Take the break if the schedule calls for one (8-9pm per rhythm).

LOAD:  Identify the new session type.
       Run: mix optimal.assemble "{new topic}" for BUILD sessions.
       Read: rhythm/today.md for OPERATE sessions.
       No load needed for EXTRACT — just start ingesting.
```

**Transition triggers**:
- Clock-based: end of BUILD block (8pm or 1am per rhythm)
- Completion-based: artifact is done, ship it and switch
- Interruption-based: incoming urgent signal forces OPERATE mode
- Energy-based: fatigue detected → LEARN or FLEX mode

---

## Boot and Shutdown

These are the system-level sessions that bracket every day.

**Boot** (~3pm):
1. Run `rhythm/boot.md`
2. Generate `rhythm/today.md` from `week-plan.md`
3. Load L0 context: `mix optimal.l0`
4. Log energy state: `rhythm/energy.md`
5. Enter OPERATE mode to clear overnight queue

**Shutdown** (~4-5am):
1. Run `rhythm/shutdown.md`
2. Capture everything unwritten: `mix optimal.remember --contextual`
3. Update `rhythm/today.md` with what happened and what's seeded for tomorrow
4. Log energy state: `rhythm/energy.md`
5. Note top 3 priorities for next boot

---

## See Also

- `CLAUDE.md` — Full workflow documentation and routing table
- `rhythm/` — Boot, shutdown, modes, energy, and transition files
- `reference/failure-modes.md` — What goes wrong and how to diagnose it
- `reference/three-spaces.md` — Why Self / Notes / Ops separation matters for session hygiene
