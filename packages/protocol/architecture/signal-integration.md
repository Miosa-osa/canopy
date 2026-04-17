# Signal Theory Integration

> The quality layer of OSA Operations. The control plane orchestrates agents, tracks
> tasks, and enforces budgets. Signal Theory is the quality layer that ensures every
> agent output is high-signal, properly encoded, and matched to its receiver.

---

## What the Control Plane Doesn't Cover

The control plane answers: **when does an agent run, what task does it work on, and how much
does it cost?**

It does NOT answer:
- Is the agent's output any good?
- Is the output formatted correctly for the receiver?
- Is the agent wasting tokens on filler?
- Does the output match the situation's genre requirements?
- Is the knowledge base healthy and current?
- Are there hidden connections between topics the agents are missing?

Signal Theory fills every one of these gaps.

---

## Signal Classification

Every agent output is classified on 5 dimensions: **S = (M, G, T, F, W)**

| Dimension | Name | What It Answers | Examples |
|-----------|------|----------------|----------|
| **M** | Mode | How is it perceived? | linguistic, visual, code, data, mixed |
| **G** | Genre | What conventionalized form? | brief, spec, plan, transcript, note, pitch, report |
| **T** | Type | What does it DO? | direct (compel action), inform, commit, decide, express |
| **F** | Format | What container? | markdown, code, JSON, HTML, YAML |
| **W** | Structure | What internal skeleton? | Genre-specific template |

### Resolution Requirement

All 5 dimensions must be resolved before output is transmitted. Unresolved dimensions
create noise. An agent that produces a "report" in "markdown" but hasn't decided
whether it's "informing" or "compelling action" has an unresolved Type dimension —
the receiver won't know how to decode it.

### Agent Default Signal

Each agent carries a default signal encoding in its YAML frontmatter:

```yaml
signal: S=(linguistic, brief, direct, markdown, persuasion)
```

This is the agent's natural output mode. Agents CAN override their default for
specific situations, but the default ensures every output starts from a defined
encoding position.

---

## S/N Quality Gate

The Signal-to-Noise ratio gate is applied at phase transitions and output delivery.
Outputs below the threshold are rejected.

### How It Works

```
Agent produces output
  │
  ▼
┌──────────────────────┐
│ S/N Scorer           │
│                      │
│ Check:               │
│ 1. All 5 dimensions  │   ← Any unresolved? REJECT
│    resolved?         │
│ 2. Filler detected?  │   ← "Let me think..." REJECT
│ 3. Genre matches     │   ← Spec sent to salesperson? REJECT
│    receiver?         │
│ 4. Shannon check     │   ← 500 lines when 20 suffice? REJECT
│ 5. Structure present?│   ← No headers/sections? REJECT
└──────────┬───────────┘
           │
     SCORE >= 0.3          SCORE < 0.3
           │                    │
           ▼                    ▼
     TRANSMIT              REJECTION NOTICE
     to receiver           returned to agent
```

### Rejection Notice

```markdown
## S/N Rejection Notice
**Agent:** {agent-id}  **Phase:** {phase}  **Score:** {score}

### Violations Detected
- {violation-type}: {description}

### Required Corrections
1. [correction]

Resubmit after corrections. Retry {n} of {max}.
```

### What Gets Checked

| Check | Violation Type | Example |
|-------|---------------|---------|
| Unresolved dimensions | `dimension_unresolved` | Genre not specified |
| Filler phrases | `filler_detected` | "That's a great question...", "Let me think about this..." |
| Genre-receiver mismatch | `genre_mismatch` | Technical spec sent to salesperson (should be brief) |
| Shannon violation | `bandwidth_overload` | 500 lines when 20 would convey the same intent |
| Missing structure | `structure_failure` | Wall of prose when a table is needed |
| Redundancy | `redundancy_excess` | Same point restated 3 times |

### Threshold Configuration

```yaml
# In company.yaml
governance:
  signal_threshold: 0.3        # Minimum S/N for any output (default 0.3)

# In workflow phases
phases:
  - id: qa-review
    signal_threshold: 0.7      # Higher bar for QA deliverables
```

---

## Genre-Receiver Alignment

Every person and agent has genre preferences. The system enforces alignment.

### Person Genre Map

| Receiver | Send Them | NOT This |
|----------|-----------|----------|
| Salespeople | brief, pitch | spec, technical docs |
| Developers | spec, readme, changelog | fluff, sales content |
| Executives | brief, proposal, report | raw specs, deep technical |
| Board | brief, dashboard, decision-log | implementation details |
| QA | spec, test-plan, bug-report | strategy documents |

### Agent-to-Agent Alignment

When Agent A sends output to Agent B, the system checks:

```
Agent A's output genre  vs  Agent B's expected input genre
                                (from B's frontmatter)

Match?     → Transmit
Mismatch?  → S/N rejection with genre_mismatch violation
```

### The 4 Governing Constraints

These are the physics of signal quality. Violating any one = failed output.

| Constraint | What It Enforces | Violation Example |
|------------|-----------------|-------------------|
| **Shannon** (the ceiling) | Don't exceed receiver's bandwidth | 500-line explanation when 20 suffice |
| **Ashby** (the repertoire) | Have enough genre variety for every situation | Prose when a table is needed |
| **Beer** (the architecture) | Coherent structure at every scale | Orphaned logic, no section headers |
| **Wiener** (the feedback loop) | Close every loop — verify receiver decoded correctly | Broadcasting without confirmation |

---

## Temporal Decay

Different content types have different half-lives. The system tracks freshness.

| Content Type | Half-Life | What Happens When Stale |
|-------------|-----------|------------------------|
| Signal files (episodic) | 1-2 weeks | Flagged in health check, archived |
| Context files (persistent) | 3-6 months | Flagged for review, reweave suggested |
| Reference files (domain) | 6-12 months | Version-checked, update prompted |
| Decision logs | Permanent | Never decay — historical record |
| Playbooks/processes | 3-6 months | Effectiveness review triggered |

### Staleness Detection

The health diagnostic checks for temporal decay:

```
For each context file:
  last_modified = file modification date
  half_life = content_type_half_life
  staleness_score = days_since_modified / half_life

  if staleness_score > 1.0:
    FLAG as stale, suggest reweave
  if staleness_score > 2.0:
    FLAG as critical, require review
```

---

## Tiered Loading

Context is loaded in tiers to manage the token budget. Never load more than needed.

### Tier Definitions

| Tier | Token Budget | Content | When to Use |
|------|-------------|---------|-------------|
| **L0** | ~100 tokens | Abstract — what this file is about, one-paragraph summary | Always loaded. Part of agent's permanent context. |
| **L1** | ~2K tokens | Overview — key facts, decisions, current state | Phase entry, context assembly, answering questions |
| **L2 / full** | Unlimited | Complete file content | Deep analysis, synthesis tasks, editing the file |

### Loading Strategy

```
1. SEARCH — mix optimal.search returns L0 abstracts (~100 tokens each)
   "What do we know about pricing?"
   → 5 results at L0 = 500 tokens

2. READ L1 — if L0 result is relevant, load L1 for details
   "Tell me more about the AI Masters pricing decision"
   → 1 result at L1 = 2,000 tokens

3. READ FULL — only if editing or deep analysis required
   "Update the AI Masters context with the new pricing"
   → 1 result at full = varies
```

### Token Budget Discipline

| Rule | Rationale |
|------|-----------|
| Never load full when L1 suffices | Context window is finite |
| Search before loading | Don't guess which files to read |
| L0 is always available | No search needed for frequently-accessed context |
| Compaction preserves tier structure | Compacted sessions reference L0/L1, not full content |

---

## Knowledge Graph Integration

The system builds a knowledge graph from entity extraction across all files.

### Entity Extraction

Every signal and context file is processed for entities:

| Entity Type | Examples |
|------------|---------|
| People | "Ed Honour", "Bennett", "Alex" |
| Organizations | "Acme Corp", "Partner LLC", "Agency Network" |
| Projects | "AI Masters course", "ContentOS", "Enterprise Client" |
| Decisions | "Pricing set at $2K/seat", "Hire QA lead" |
| Financial | "$5,000 MRR", "Q1 revenue target" |
| Dates | "March 18 call", "Q2 launch" |

### Edge Creation

Edges are created when entities co-occur in the same file or signal:

```
Ed Honour ──[mentioned_in]──→ AI Masters pricing call
Ed Honour ──[works_on]──→ AI Masters course
AI Masters ──[revenue_target]──→ $50K/month
```

### Triangle Detection

The most powerful graph analysis: find A→B and A→C edges where B→C is missing.

```
Ed Honour ──→ AI Masters
Ed Honour ──→ Pricing Strategy
AI Masters ──→ ???  ← No edge to Pricing Strategy

TRIANGLE FOUND: Ed Honour connects AI Masters and Pricing Strategy,
but there's no direct edge between them. This is a synthesis opportunity.
```

### Graph Commands

```bash
mix optimal.graph                    # Stats + sample edges
mix optimal.graph triangles          # Missing edges (synthesis opportunities)
mix optimal.graph clusters           # Isolated knowledge islands
mix optimal.graph hubs               # Most-connected entities (>2σ degree)
mix optimal.reflect                  # Co-occurring entities without edges
mix optimal.reflect --min 3          # Require 3+ co-occurrences
```

---

## Learning Loop

The system captures friction, accumulates evidence, and synthesizes insights.

### Three-Phase Loop

```
Phase 1: CAPTURE
  Agent encounters friction or makes an observation
  → mix optimal.remember "observation text"
  → Stored with category, confidence, timestamp

Phase 2: ACCUMULATE
  Multiple observations in the same category build up
  → System tracks observation count and confidence per category
  → Confidence increases with each corroborating observation

Phase 3: SYNTHESIZE
  When confidence >= threshold (default 1.5)
  → mix optimal.rethink "category"
  → System synthesizes all observations into an insight
  → Insight is promoted to knowledge base
```

### Observation Schema

```yaml
observation:
  text: string                 # What was observed
  category: string             # Classified category (process, people, tools, etc.)
  confidence: number           # Starts at 0.5, increases with corroboration
  source: string               # Which agent/session recorded this
  timestamp: ISO8601
  escalation_ready: boolean    # True when confidence >= threshold
```

### Learning Commands

```bash
mix optimal.remember "always check duplicates before inserting"  # Explicit observation
mix optimal.remember --contextual    # Scan recent signals for friction patterns
mix optimal.remember --mine          # Bulk extract from session transcripts
mix optimal.remember --list          # See all stored observations
mix optimal.remember --escalations   # Categories ready for rethink
mix optimal.rethink "process"        # Synthesize when confidence >= 1.5
mix optimal.rethink "people" --force # Override confidence threshold
```

---

## Health Diagnostics

10 diagnostic checks on the knowledge base. Run regularly to maintain quality.

```bash
mix optimal.health
```

| Check | What It Detects | Severity |
|-------|----------------|----------|
| **Orphaned files** | Files not linked to any node or entity | Warning |
| **Stale contexts** | Context files past their half-life | Warning → Critical |
| **Duplicate entities** | Same entity with different names/spellings | Warning |
| **Broken references** | Links to files that don't exist | Error |
| **Empty nodes** | Folders with no content files | Info |
| **Unresolved signals** | Signal files not yet classified or routed | Warning |
| **Missing L0 abstracts** | Files without generated abstracts | Warning |
| **Entity drift** | Entity mentioned in many places with inconsistent facts | Critical |
| **Orphaned decisions** | Decisions logged but not linked to any initiative | Warning |
| **Graph islands** | Clusters with no edges to the main graph | Info |

### Verification

```bash
mix optimal.verify                   # L0 fidelity test (do abstracts match content?)
mix optimal.verify --sample 20       # Test 20 random contexts
mix optimal.reweave "Ed Honour"      # Find stale contexts about a topic + suggest updates
mix optimal.reweave "pricing" --days 60  # Custom staleness threshold
```

---

## What This Changes

| Aspect | Control Plane Alone | With Signal Theory |
|--------|----------------|-------------------|
| Output quality | No quality check | S/N gate rejects noise |
| Genre alignment | Agent decides | System enforces receiver match |
| Context loading | Load everything | Tiered: L0 → L1 → full |
| Knowledge health | No knowledge base | 10 diagnostic checks |
| Hidden connections | No graph | Triangle detection + synthesis |
| Learning | No learning loop | Capture → Accumulate → Synthesize |
| Temporal awareness | No decay model | Content half-lives + staleness |
| Output structure | No enforcement | Genre skeletons required |
| Filler detection | No detection | Auto-reject filler phrases |
| Cost efficiency | Budget only | Budget + token-aware loading |

Signal Theory transforms the control plane from "agents that run on schedule" to
"agents that produce high-quality, properly-encoded output matched to their
receivers, with a self-improving knowledge base underneath."

---

*Signal Theory Integration v1.0 — The quality layer for OSA Operations*
