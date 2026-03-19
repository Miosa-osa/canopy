# Basement Architecture

> The foundation layer that everything builds on. The Basement defines the typed
> resource system, memory categories, and skill taxonomy that all higher layers
> reference. Nothing in the control plane works without these primitives.
>
> A typed foundation layer that prevents the "everything is a string" problem
> in knowledge management systems.

---

## Why a Foundation Layer

Without typed primitives, every agent, every loader, and every search query must
re-discover what a piece of content IS before it can use it. The Basement eliminates
this by declaring resource types, memory types, and skill types upfront.

```
┌─────────────────────────────────────────────┐
│  Higher Layers (Agents, Tasks, Heartbeat)   │
│  Reference Basement types by ID             │
├─────────────────────────────────────────────┤
│  B A S E M E N T                            │
│                                             │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ │
│  │ Resources │ │  Memory   │ │  Skills   │ │
│  │  Types    │ │  Types    │ │  Types    │ │
│  └───────────┘ └───────────┘ └───────────┘ │
│                                             │
│  Every item typed, categorized, tagged      │
│  Uniform metadata envelope                  │
└─────────────────────────────────────────────┘
```

---

## Resource Types

Resources are the atoms of the knowledge base. Every piece of content in the
workspace is a typed resource.

### Core Resource Types

| Type | ID | Description | Examples |
|------|----|-------------|----------|
| Document | `resource.document` | Long-form structured content | specs, playbooks, SOPs, guides |
| Note | `resource.note` | Short-form capture | meeting notes, observations, ideas |
| Signal | `resource.signal` | Temporal event record | call transcript, status update, decision |
| Bookmark | `resource.bookmark` | External reference | URLs, paper citations, tool links |
| Conversation | `resource.conversation` | Multi-turn interaction | session transcripts, chat logs |
| Artifact | `resource.artifact` | Generated output | reports, briefs, code, diagrams |
| Template | `resource.template` | Reusable skeleton | genre templates, agent templates |
| Config | `resource.config` | System configuration | YAML settings, env vars, budgets |

### Resource Envelope

Every resource carries a uniform metadata envelope regardless of type:

```yaml
# Resource Envelope — every item in the system wraps content in this
resource:
  id: "res_01HQXYZ..."          # ULID — globally unique, time-sortable
  type: "resource.document"      # From the type table above
  title: "AI Masters Pricing"    # Human-readable title
  created_at: "2026-03-15T14:30:00Z"
  updated_at: "2026-03-19T09:15:00Z"
  created_by: "agent.strategist" # Agent or human who created it
  tags: ["pricing", "ai-masters", "revenue"]
  node: "04-ai-masters"          # Owning node in the workspace
  tier: "l1"                     # Current loading tier (l0, l1, l2)
  signal:                        # Signal Theory classification
    mode: "linguistic"
    genre: "spec"
    type: "inform"
    format: "markdown"
    structure: "requirements-spec"
  relations:                     # Explicit links to other resources
    - target: "res_01HQABC..."
      type: "references"
    - target: "res_01HQDEF..."
      type: "supersedes"
  content_hash: "sha256:abc123..." # Content integrity check
  token_count: 1847              # Pre-computed token count
```

### Relation Types

Resources link to each other through typed relations:

| Relation | Semantics | Example |
|----------|-----------|---------|
| `references` | A mentions or cites B | Spec references a design doc |
| `supersedes` | A replaces B | New pricing doc replaces old |
| `derived_from` | A was generated from B | Brief derived from transcript |
| `blocks` | A cannot proceed until B resolves | Task blocked by decision |
| `child_of` | A is a sub-resource of B | Section of a larger document |
| `related_to` | Loose association | Two topics that overlap |

---

## Memory Types

Memory types categorize HOW knowledge is stored and retrieved. See
`memory-architecture.md` for the full 4-layer system. The Basement defines the
type taxonomy that memory layers use.

### Core Memory Types

| Type | ID | What It Stores | Retrieval Pattern |
|------|----|----------------|-------------------|
| Episodic | `memory.episodic` | What happened, when, with whom | Time-based, narrative |
| Semantic | `memory.semantic` | Facts, entities, relationships | Query-based, structured |
| Procedural | `memory.procedural` | How to do things, learned patterns | Trigger-based, automatic |
| Working | `memory.working` | Current session context | Immediate, in-context |

### Memory Record

```yaml
memory:
  id: "mem_01HQ..."
  type: "memory.semantic"
  source_resource: "res_01HQ..."    # Resource this was extracted from
  confidence: 0.85                   # Extraction confidence (0-1)
  created_at: "2026-03-19T09:15:00Z"
  last_accessed: "2026-03-19T14:00:00Z"
  access_count: 7                    # Frequency of retrieval
  decay_factor: 0.95                 # Memory decay multiplier
  content:
    fact: "Ed Honour wants $2K per seat pricing"
    entities: ["Ed Honour", "AI Masters"]
    context: "Pricing discussion, March 2026"
```

### Decay and Reinforcement

Memories are not permanent at full strength. The Basement defines decay behavior:

```
strength(t) = base_strength * decay_factor ^ days_since_access * log(access_count + 1)
```

- **High access_count + recent access** = strong memory, loads at L0/L1
- **Low access_count + old access** = weak memory, loads only at L2
- **Below threshold (strength < 0.1)** = candidate for archival

---

## Skill Types

Skills are capabilities that agents can invoke. The Basement types them so the
orchestrator knows what kind of capability it is dispatching.

### Core Skill Types

| Type | ID | Description | Examples |
|------|----|-------------|---------|
| Tool | `skill.tool` | Single-action capability | search, read-file, send-email |
| Automation | `skill.automation` | Multi-step workflow | deploy-pipeline, onboard-client |
| Integration | `skill.integration` | External system bridge | slack-post, github-pr, crm-update |
| Query | `skill.query` | Data retrieval | search-knowledge, list-tasks, get-metrics |
| Transform | `skill.transform` | Content transformation | summarize, translate, reformat |

### Skill Definition

```yaml
skill:
  id: "search-knowledge"
  type: "skill.query"
  name: "Search Knowledge Base"
  description: "Full-text + semantic search across all resources"
  input_schema:
    query: { type: "string", required: true }
    limit: { type: "integer", default: 10 }
    node: { type: "string", required: false }
    type: { type: "string", enum: ["signal", "document", "note", "all"], default: "all" }
  output_schema:
    results: { type: "array", items: "ResourceEnvelope" }
    total: { type: "integer" }
  budget_cost: 0.002                # Estimated cost per invocation in USD
  requires_approval: false          # Whether governance gate applies
  timeout_ms: 30000                 # Max execution time
  retry_policy: { max: 2, backoff: "exponential" }
```

---

## Category Taxonomy

Beyond types, resources are organized by domain categories. Categories are
workspace-specific — each Operation defines its own.

### Default Categories

```yaml
categories:
  - id: "strategy"
    label: "Strategy & Planning"
    description: "High-level goals, roadmaps, positioning"

  - id: "operations"
    label: "Operations & Execution"
    description: "Day-to-day workflows, SOPs, task management"

  - id: "people"
    label: "People & Relationships"
    description: "Team info, contact details, communication preferences"

  - id: "finance"
    label: "Finance & Revenue"
    description: "Revenue tracking, budgets, invoices, deals"

  - id: "product"
    label: "Product & Engineering"
    description: "Specs, architecture, code, technical decisions"

  - id: "content"
    label: "Content & Media"
    description: "Marketing, social, podcasts, educational material"

  - id: "inbox"
    label: "Inbox / Unrouted"
    description: "New signals not yet categorized"
```

---

## Tag System

Tags provide cross-cutting classification beyond type and category. They enable
faceted search and dynamic grouping.

### Tag Rules

1. Tags are lowercase, hyphenated strings: `ai-masters`, `pricing`, `q1-2026`
2. Maximum 10 tags per resource (prevent tag spam)
3. Tags are workspace-scoped — no global tag namespace
4. Reserved tag prefixes:
   - `status:` — lifecycle state (`status:active`, `status:archived`)
   - `priority:` — urgency (`priority:critical`, `priority:low`)
   - `person:` — people mentions (`person:ed-honour`)
   - `node:` — cross-references (`node:money-revenue`)

### Auto-tagging

The intake pipeline auto-tags resources based on content analysis:

```
New resource arrives
  ↓
Extract entities → person:* tags
Extract topics → domain tags
Detect financial data → node:money-revenue tag
Detect urgency language → priority:* tag
  ↓
Merge with user-provided tags
  ↓
Store in resource envelope
```

---

## Implementation Notes

### Storage

The Basement is schema, not runtime. Implementations choose their own storage:

| Implementation | Storage | Index |
|----------------|---------|-------|
| SQLite (reference) | Single file, JSON columns | FTS5 for full-text |
| PostgreSQL | Typed tables | pg_trgm + tsvector |
| File system | YAML frontmatter + markdown | External index |
| In-memory | ETS/DETS (Erlang) | Built-in pattern match |

### Validation

Every resource MUST pass envelope validation before storage:

```elixir
defmodule Basement.Validator do
  def validate(%{type: type, title: title, node: node} = envelope) do
    with :ok <- validate_type(type),
         :ok <- validate_title(title),
         :ok <- validate_node(node),
         :ok <- validate_signal(envelope[:signal]),
         :ok <- validate_tags(envelope[:tags]) do
      {:ok, envelope}
    end
  end

  defp validate_type(type) when type in @valid_types, do: :ok
  defp validate_type(type), do: {:error, "Unknown resource type: #{type}"}

  defp validate_title(t) when is_binary(t) and byte_size(t) > 0, do: :ok
  defp validate_title(_), do: {:error, "Title required"}

  defp validate_tags(tags) when length(tags) <= 10, do: :ok
  defp validate_tags(_), do: {:error, "Maximum 10 tags per resource"}
end
```

### ID Generation

Use ULIDs (Universally Unique Lexicographically Sortable Identifiers):
- Time-sortable: natural chronological ordering
- Globally unique: no coordination needed
- URL-safe: base32 encoding

```
Format: {prefix}_{ulid}
Examples:
  res_01HQXYZ...   (resource)
  mem_01HQABC...   (memory record)
  skl_01HQDEF...   (skill invocation)
```

---

## Relationship to Other Architecture Files

| File | How It Uses the Basement |
|------|-------------------------|
| `tiered-loading.md` | Loads resources by tier field in envelope |
| `memory-architecture.md` | Stores memories using memory type taxonomy |
| `proactive-agents.md` | Agents query resources by type, tag, category |
| `heartbeat.md` | Workspace resolution uses resource envelopes |
| `signal-integration.md` | S/N scoring reads signal dimensions from envelope |
| `tasks.md` | Tasks reference resources as inputs/outputs |

---

*Basement Architecture v1.0 — Foundation layer for OSA Operations*
