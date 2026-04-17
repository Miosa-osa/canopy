# Cross-Workspace Signal Flow

> How workspaces communicate through universal signal encoding.

## The Problem

An agent operating a sales workspace closes a deal. Three other workspaces
need to know: the content workspace (for a case study), the financial
workspace (for revenue tracking), and the personal knowledge workspace
(for relationship context).

Without a universal encoding, each workspace needs custom adapters to
understand every other workspace. With N workspaces, that's N*(N-1)
adapters. It doesn't scale.

## The Solution: Universal Signal Encoding

Every output from every workspace is a **Signal**: `S = (M, G, T, F, W)`

| Dimension | Name | What It Determines |
|---|---|---|
| M | Mode | How is it perceived? (linguistic, visual, code, data) |
| G | Genre | What form does it take? (brief, spec, decision-log, transcript) |
| T | Type | What does it DO? (direct, inform, commit, decide, express) |
| F | Format | What container? (markdown, JSON, code, audio) |
| W | Structure | Internal skeleton (genre-specific template) |

The signal encoding is the **lingua franca** between workspaces. Every
workspace can encode signals (produce output with all 5 dimensions resolved)
and decode signals (interpret incoming signals using its own context).

## How Signals Flow

```
┌──────────────┐    Signal: S=(linguistic, decision-log, commit, md, deal-template)
│ Sales Engine │────┐
│              │    │
│ Agent closes │    ├──→ Content Factory
│ a $50K deal  │    │    Decodes: "New case study material"
│              │    │    Re-encodes: S=(linguistic, case-study, inform, md, story-template)
│              │    │
│              │    ├──→ Financial Workspace
│              │    │    Decodes: "Revenue event: $50K, Q1, Enterprise segment"
│              │    │    Re-encodes: S=(data, ledger-entry, commit, json, transaction)
│              │    │
│              │    └──→ Cognitive OS (Second Brain)
│              │         Decodes: "Key decision with Company X, contact: John"
│              │         Re-encodes: S=(linguistic, note, inform, md, signal-template)
└──────────────┘         Routes to: relationships node + revenue node
```

### Same Signal, Different Decoding

The originating workspace produces ONE signal. Each receiving workspace
decodes it differently based on its own context:

| Receiving Workspace | What It Sees | What It Does |
|---|---|---|
| Content Factory | Case study opportunity | Drafts case study from deal details |
| Financial Workspace | Revenue event | Creates ledger entry, updates forecast |
| Cognitive OS | Relationship + decision signal | Updates relationship graph, logs decision |
| Dev Shop | (Ignores — not relevant) | Signal filtered out by relevance scoring |

### Receiver-Aware Encoding

When a workspace sends a signal TO a specific receiver, it can encode
for that receiver's decoding capacity:

```
Same deal info → different encoding per receiver:

  For salesperson:  S=(linguistic, brief, direct, md, brief-template)
    "Closed $50K with Company X. Update deck. Next: upsell in Q2."

  For developer:    S=(linguistic, spec, inform, md, spec-template)
    "New client: Company X. Integration requirements: REST API, OAuth2."

  For CEO:          S=(linguistic, decision-log, commit, md, decision-template)
    "Deal: $50K/yr enterprise. Rationale: [full context]. Impact: [analysis]."
```

## Signal Routing

### Within a Workspace

Signals route to the right agent/skill based on classification:

```
Incoming signal
  → Classify: S=(M, G, T, F, W)
  → Route by genre:
      brief → sales agent
      spec → engineering agent
      transcript → context assembler
      decision-log → knowledge agent
  → Score quality: S/N ratio
  → Reject if S/N < 0.3 (noise)
```

### Between Workspaces

Cross-workspace routing uses a **signal bus** — an event stream that
workspaces can subscribe to:

```yaml
# signal-bus.yaml (workspace-level config)
subscriptions:
  - source: sales-engine
    filter:
      genre: [decision-log, deal-summary]
      type: [commit, inform]
    action: ingest

  - source: content-factory
    filter:
      genre: [published-content]
    action: reference-update

publish:
  - on: [deal-closed, pipeline-update]
    to: signal-bus
```

### Signal Quality Gates

Not every signal should propagate. Quality scoring prevents noise:

```
Signal arrives at workspace boundary
  → S/N scoring (0.0 to 1.0)
  → If S/N < 0.3: reject (noise)
  → If S/N 0.3-0.6: queue for review
  → If S/N > 0.6: auto-route to appropriate agent
  → If S/N > 0.9: high-priority, immediate processing
```

## Implementation Patterns

### Pattern 1: File-Based (Simplest)

Workspaces share a directory. Signals are markdown files:

```
shared/signals/
├── 2026-03-20-deal-closed-company-x.md
├── 2026-03-20-content-published-blog.md
└── 2026-03-20-deploy-completed-v2.md
```

Each workspace watches this directory and processes new signals.

### Pattern 2: Event Bus (Real-Time)

A running service (could be part of the engine) manages signal routing:

```
Producer workspace → Event Bus → Consumer workspaces
                         │
                    ┌────┴────┐
                    │ Filter  │
                    │ Route   │
                    │ Score   │
                    │ Deliver │
                    └─────────┘
```

### Pattern 3: Agent Delegation

One workspace's agent directly invokes another workspace's skill:

```
Sales agent in sales-engine workspace:
  "New deal closed. /delegate cognitive-os /ingest 'Deal closed: Company X, $50K'"
```

The runtime handles workspace switching — the agent just calls the skill
with a workspace prefix.

## The 4 Constraints on Cross-Workspace Communication

1. **Shannon (capacity)**: Don't flood workspaces with signals they can't
   process. Batch low-priority signals. Respect token budgets.

2. **Ashby (variety)**: Have enough signal genres to handle every cross-workspace
   scenario. If a workspace needs a genre that doesn't exist, create it.

3. **Beer (coherence)**: Signals must be coherent across workspaces. A decision
   logged in one workspace must mean the same thing in another.

4. **Wiener (feedback)**: Close the loop. If a workspace sends a signal,
   confirm it was received and processed. No fire-and-forget for important signals.

## Example: Multi-Workspace Company

```
Company Goal: "Launch SaaS product, reach $100K MRR in 6 months"

Workspaces:
  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
  │ Dev Shop     │────→│ Content      │────→│ Sales Engine │
  │              │     │ Factory      │     │              │
  │ Builds the   │     │ Writes docs, │     │ Sells the    │
  │ product      │     │ blog posts,  │     │ product      │
  │              │     │ case studies │     │              │
  │ Signals OUT: │     │              │     │ Signals OUT: │
  │ - deploy     │     │ Signals OUT: │     │ - deal-closed│
  │ - feature    │     │ - published  │     │ - feedback   │
  │              │     │ - campaign   │     │ - objection  │
  │ Signals IN:  │     │              │     │              │
  │ - feedback   │     │ Signals IN:  │     │ Signals IN:  │
  │ - bug-report │     │ - feature    │     │ - feature    │
  │ - objection  │     │ - deploy     │     │ - published  │
  └──────────────┘     └──────────────┘     └──────────────┘
         │                    │                     │
         └────────────────────┼─────────────────────┘
                              ↓
                    ┌──────────────────┐
                    │ Cognitive OS     │
                    │ (Second Brain)   │
                    │                  │
                    │ Captures ALL     │
                    │ signals from all │
                    │ workspaces.      │
                    │ Tracks decisions,│
                    │ relationships,   │
                    │ revenue, health. │
                    └──────────────────┘
```

The Cognitive OS workspace is the meta-workspace — it observes all other
workspaces and maintains the organizational memory. It's the workspace
that doesn't do domain work itself but tracks everything that happens
across all workspaces.

This is what OptimalOS is — the first Cognitive OS workspace, built with
an Elixir engine underneath for search, classification, knowledge graph,
and learning loop capabilities.
