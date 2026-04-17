# Project Layer Architecture

> The workspace has two layers: the Canopy Layer (config, instructions, ROM) and
> the Project Layer (work product, artifacts, RAM-in-motion). This document defines
> the Project Layer — where agent output lives.

---

## The Two Layers

```
workspace/
├── [Canopy Layer]        Config. Instructions. Knowledge. Skills. Agents.
│   SYSTEM.md, agents/, skills/, reference/, workflows/, spec/, engine/
│
├── [Project Layer]       Work product. What agents BUILD.
│   output/, data/, src/, apps/
│
└── .canopy/              Runtime state. Ephemeral. Gitignored.
    tasks/, sessions/, observations/
```

### Canopy Layer = ROM

Persistent. Transferable. Version-controlled. This is what you distribute on the
marketplace. When someone downloads a "sales-engine" workspace, they get the Canopy
Layer — the skills, agents, reference docs, and engine config that make a generic
agent into a sales specialist.

The Canopy Layer doesn't change during normal operation. An agent reads it, follows it,
but doesn't modify it (except through explicit learning loop commands like `/remember`
and `/rethink`, which require human approval before writing).

### Project Layer = Work Product

What agents create during operation. Documents, code, data, analyses, reports,
compositions, signals. This is where the actual value gets produced.

The user comes back and reviews this. Approves proposals. Reads analyses. Merges code.
Edits drafts. Sends reports. The Project Layer is the inbox of completed work.

### .canopy/ = Runtime State

Task queues, session persistence, accumulated observations. Ephemeral. If you delete
`.canopy/`, the workspace still works — agents just lose in-progress context and start
fresh. Always gitignored.

---

## Project Layer Directory Standard

Not every workspace needs every directory. Use what fits the domain.

### `output/` — Generated Artifacts

Structured output that agents produce for human review.

```
output/
├── {genre}/                  Organized by Signal genre
│   └── {date}-{title}.md    Timestamped, titled, reviewable
```

Examples by workspace type:

| Workspace | output/ contains |
|-----------|-----------------|
| Sales engine | proposals/, analyses/, reports/, sequences/ |
| Dev shop | specs/, designs/, changelogs/, docs/ |
| Content factory | articles/, social-posts/, scripts/, thumbnails/ |
| Cognitive OS | signals/, decisions/, syntheses/, reviews/ |
| Agency | briefs/, pitches/, audits/, recommendations/ |

Every output file SHOULD include frontmatter:

```yaml
---
genre: proposal          # Signal genre
type: commit             # Speech act (direct, inform, commit, decide, express)
status: draft            # draft | review | approved | sent | archived
created_by: closer       # Which agent produced this
created_at: 2026-03-20
for: ACME Corp           # Intended receiver
---
```

This lets the OSA command center display output files with proper metadata —
filter by status, sort by date, group by genre, assign for review.

### `data/` — Working Data

Data the workspace accumulates and uses during operation.

```
data/
├── {domain-specific}/    Whatever the workspace needs
```

| Workspace | data/ contains |
|-----------|---------------|
| Sales engine | leads.csv, pipeline.json, call-notes/ |
| Dev shop | metrics/, benchmarks/, error-logs/ |
| Content factory | research/, trends/, audience-data/ |
| Cognitive OS | contexts/, entities/, knowledge-graph/ |

Data files are NOT for human review — they're for agent consumption. Agents read from
`data/`, process it, and write results to `output/`.

### `src/` — Source Code

When the workspace builds software.

```
src/
├── {standard project structure}
```

A dev-shop workspace might have `src/` with a full app. Agents write code here,
run tests, deploy. The Canopy Layer (skills like `/test`, `/deploy`, `/review`)
defines HOW agents work on the code. The code itself lives in `src/`.

### `apps/` — Managed Applications

When the workspace manages multiple applications or integrations.

```
apps/
├── {app-name}/
│   ├── config.yaml       Connection config, credentials reference
│   └── ...               App-specific files
```

A company workspace might manage CRM, email, Slack, billing — each as a sub-app
with its own config. Skills reference these by name: `/crm update-deal ACME`.

---

## Signal Flow: Canopy → Project

The typical flow:

```
1. Agent boots              → reads SYSTEM.md (Canopy Layer)
2. Agent receives task      → reads relevant skill (Canopy Layer)
3. Agent gathers context    → reads reference/ + data/ (both layers)
4. Agent produces output    → writes to output/ (Project Layer)
5. Agent logs state         → writes to .canopy/ (Runtime)
6. Human reviews            → reads output/ (Project Layer)
7. Human approves/edits     → modifies output/ status field
8. Agent acts on approval   → sends, publishes, deploys, archives
```

### Compositions and Frameworks

Users can create reusable output templates — "compositions" — that agents use when
generating artifacts. These live in the Canopy Layer as reference docs:

```
reference/
├── compositions/
│   ├── quarterly-review.md      Template for Q reviews
│   ├── client-brief.md          Template for client deliverables
│   └── weekly-signal.md         Template for weekly status signals
```

When an agent runs `/compose quarterly-review`, it:
1. Loads the composition template from `reference/compositions/`
2. Gathers relevant data from `data/` and recent `output/`
3. Produces a new file in `output/reviews/2026-03-20-q1-review.md`
4. Sets status to `draft` for human review

The composition is ROM (reusable template). The output is work product (unique instance).

---

## Cognitive OS Example

For a second-brain / cognitive OS workspace, the Project Layer is where the knowledge
grows:

```
cognitive-os/
├── [Canopy Layer]
│   ├── SYSTEM.md                 Identity, routing, classification rules
│   ├── agents/                   Signal processor, synthesizer, reviewer
│   ├── skills/                   /ingest, /search, /reflect, /reweave, /remember
│   ├── reference/                Methodology, node definitions, genre catalogue
│   └── engine/                   SQLite, FTS5, vector search, knowledge graph
│
├── [Project Layer]
│   ├── output/
│   │   ├── signals/              Captured signals (calls, meetings, ideas)
│   │   ├── decisions/            Decision logs with rationale
│   │   ├── syntheses/            Cross-topic synthesis documents
│   │   └── reviews/              Weekly/monthly reviews
│   │
│   ├── data/
│   │   ├── contexts/             Per-node persistent context (ground truth)
│   │   ├── entities/             Knowledge graph entities
│   │   └── observations/         Friction patterns for learning loop
│   │
│   └── nodes/                    Domain-specific knowledge tree
│       ├── 01-personal/
│       ├── 02-business/
│       ├── 03-projects/
│       └── ...
│
└── .canopy/
    ├── tasks/                    Processing queue
    └── sessions/                 Agent session state
```

User captures a signal: "Ed called about pricing, wants $2K per seat."
Agent classifies it, routes to the right node, writes to `output/signals/`,
updates `data/contexts/`, extracts entities to `data/entities/`.
User opens `output/signals/` and sees the processed signal with extracted
action items, decisions, and cross-references — ready to review.

---

## Rules

1. **Agents NEVER modify the Canopy Layer** during normal operation. The only
   exceptions are explicit learning commands (`/remember`, `/rethink`) which
   require human approval before writing.

2. **Agents ALWAYS write work product to the Project Layer.** Generated documents
   go to `output/`. Working data goes to `data/`. Code goes to `src/`.

3. **The `.canopy/` directory is always gitignored.** Runtime state is ephemeral.

4. **Output files SHOULD have frontmatter** with genre, status, creator, and date.
   This enables the OSA command center to display, filter, and manage outputs.

5. **Compositions (templates) live in Canopy Layer** (`reference/compositions/`).
   Instantiated outputs live in Project Layer (`output/`).

6. **The Project Layer is domain-specific.** Not every workspace has `src/`. Not
   every workspace has `apps/`. Use what fits. The Canopy Layer structure is
   standardized. The Project Layer structure is flexible.

---

## Related

- [workspace-protocol.md](../protocol/workspace-protocol.md) — Full workspace standard
- [three-space-model.md](three-space-model.md) — Self/Knowledge/Ops separation
- [processing-pipeline.md](processing-pipeline.md) — 6R pipeline for knowledge workspaces
- [sessions.md](sessions.md) — Runtime state and session persistence
