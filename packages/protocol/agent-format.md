# Agent Format Standard

> The standard for writing agent definitions in OSA Operations. Deep behavioral
> definitions with organizational fields and Signal Theory encoding.

## File Convention

Every agent file lives in `agents/{division}/{department}/{team}/{role-slug}.md` and follows a YAML
frontmatter + Markdown body convention. The frontmatter is machine-readable (parsed by
orchestrators, adapters, and UIs). The body is the agent's injected system prompt.

## Frontmatter Schema

```yaml
---
name: string                    # Display name ("Deal Strategist")
id: string                      # Unique slug ("deal-strategist")
role: string                    # Functional role ("closer", "engineer", "analyst")
title: string                   # Full title ("Senior Deal Strategist")
reportsTo: string | null        # Agent id of manager, or null if CEO
budget: number                  # Monthly USD cap for this agent's API calls
color: string                   # Hex color for UI display (#1B4D3E)
emoji: string                   # Single emoji identifier
adapter: string                 # Default runtime adapter (see below)
signal: string                  # Signal Theory default encoding
tools: [string]                 # Tool slugs this agent can use
skills: [string]                # Skill slugs this agent can invoke (from skills/)
context_tier: string            # Default context loading depth (l0 | l1 | full)
team: string | null             # Team id this agent belongs to (null for CEO)
department: string | null       # Department id (null for CEO)
division: string | null         # Division id (null for CEO)
---
```

### Required Fields

All fields are required except:
- `reportsTo` — null for the CEO (root of the org chart)
- `tools` — empty list if agent uses no tools
- `skills` — empty list if agent uses no skills
- `context_tier` — defaults to `l1` if omitted
- `team`, `department`, `division` — null for agents that sit above the division layer (CEO)

### Optional Fields

These fields are not required by the schema but are commonly used in agent definitions:

| Field | Type | Description |
|-------|------|-------------|
| `description` | string | One-line summary of what this agent does |
| `vibe` | string | Informal personality tagline for UI display |

### Organizational Placement

Every agent (except the CEO) belongs to exactly one team, which belongs to exactly one
department, which belongs to exactly one division. The `team`, `department`, and `division`
fields encode this placement explicitly:

```yaml
# A frontend developer on the Application Development team
team: application-development
department: software-engineering
division: technology
reportsTo: senior-developer       # team manager
```

The `reportsTo` chain follows the hierarchy:
- Regular agents → team manager
- Team managers → department head
- Department heads → division head
- Division heads → CEO
- CEO → null (root)

### Frontmatter as Signal Theory Encoding

Every frontmatter field maps to a Signal Theory concept. This is not a metaphor —
each field encodes a specific architectural property of the agent as a node in the
Signal Network:

| Field | Signal Theory Concept | What It Encodes |
|-------|----------------------|-----------------|
| `name`, `id` | Node identity | The agent's address in the Signal Network |
| `role`, `title` | Genre competence declaration | What classes of signals this node can encode/decode |
| `reportsTo` | Signal routing topology | Where unresolvable signals escalate — the network edge |
| `budget` | Channel capacity allocation | Shannon constraint expressed in dollars — finite compute bandwidth |
| `adapter` | Channel type | The physical medium through which signals flow (CLI, HTTP, editor) |
| `signal` | Default output encoding | S=(M,G,T,F,W) — the agent's primary transmission pattern |
| `tools` | Signal transcoders | Mode/format converters — tools transform signals between representations |
| `skills` | Genre templates (dual-process) | Reusable encoding procedures that convert System 2 → System 1 |
| `context_tier` | Autonomy level / VSM scope | How much of the viable system this agent can access (L0→L1, L1→L2-3, full→L4-5) |
| `team` | Cluster membership | Which Signal Network cluster (team) this node belongs to |
| `department` | Supercluster membership | Which department-level supercluster this node is governed by |
| `division` | Subnet membership | Which division-level subnet constrains this node's budget and strategic scope |
| `color`, `emoji` | Visual mode encoding | Interface layer (L4) display properties for human decoding |

### Adapter Values

| Adapter | ID | Description |
|---------|-----|------------|
| OSA Native | `osa` | Full feature support including engine commands |
| Claude Code | `claude_code` | Bridge via CLAUDE.md injection |
| Codex | `codex_local` | OpenAI Codex CLI |
| Cursor | `cursor` | Editor context only |
| OpenClaw | `openclaw` | Multi-channel gateway |
| Process | `process` | External process (shell script, HTTP API) |
| HTTP | `http` | HTTP webhook adapter |

### Tools as Signal Transcoders

Tools are not just APIs an agent can call. In Signal Theory terms, tools are
**signal transcoders** — they convert signals between modes, formats, and
representations that the agent cannot natively process.

| Tool Category | Signal Transformation | Example |
|--------------|---------------------|---------|
| **File readers** | Format → linguistic mode | `read` converts PDF/code/config → text the agent can decode |
| **Search tools** | Query → information | `search`, `web-search` convert intent into retrieved signals |
| **Shell execution** | Intent → system action | `bash` converts linguistic instructions into executable commands |
| **Write tools** | Linguistic → persistent artifact | `write`, `edit` convert agent output into stored signals (Data Layer) |
| **Multimodal tools** | Cross-mode conversion | Transcription (audio→text), OCR (visual→text), TTS (text→audio) |
| **API tools** | Cross-network bridging | HTTP calls bridge the agent's Signal Network to external networks |

When an agent receives a signal in a mode it cannot decode (e.g., a video file),
the agent's tool repertoire determines whether it can **transcode** the signal into
a decodable mode. An agent without transcription tools cannot decode audio signals.
An agent without file-read tools cannot decode document signals.

Tool assignment is therefore **Ashby's Law at the capability level**: the agent's
tool variety must match the variety of signal transformations it will need to perform.

### Signal Encoding

Every agent is a node in the Signal Network. The `signal` field encodes the agent's
default **output** encoding — the Signal it transmits. But agents also **receive** and
**decode** signals. The full signal lifecycle at the agent level:

```
RECEIVE (decode incoming signal)
  → What modes can this agent perceive? (linguistic, visual, code, data)
  → What genres does it have competence to decode? (spec, brief, report)
  → What types does it respond to? (direct, inform, decide)

PROCESS (apply domain expertise)
  → Identity & Memory → Core Mission → Critical Rules → Process/Methodology

TRANSMIT (encode output signal)
  → signal: S=(mode, genre, type, format, structure)
```

#### The `signal` Field (Output Encoding)

```
signal: S=(mode, genre, type, format, structure)
```

All 5 dimensions must be resolved. This is the agent's default output mode — the
Signal pattern it produces most often. Agents can override per-deliverable, but the
default encodes their primary encoding pattern.

```yaml
# A deal strategist who produces MEDDPICC scorecards
signal: S=(linguistic, report, decide, markdown, meddpicc-scorecard)

# A backend engineer who produces system architecture specs
signal: S=(code, spec, commit, markdown, system-architecture)

# An SRE who produces SLO dashboards
signal: S=(data, report, inform, markdown, slo-framework)
```

#### The 5 Dimensions

| Dim | Name | What It Resolves | Common Values |
|-----|------|-----------------|---------------|
| **M** | Mode | How is the signal perceived? | `linguistic` (text), `visual` (images/diagrams), `code` (source code), `data` (structured data), `mixed` (multimodal) |
| **G** | Genre | What conventionalized form? | `spec`, `brief`, `report`, `proposal`, `plan`, `review-checklist`, `battlecard`, `adr`, `email`, `pitch` |
| **T** | Type | What does it DO? (speech act) | `direct` (compel action), `inform` (state facts), `commit` (promise delivery), `decide` (choose between options), `express` (convey perspective) |
| **F** | Format | What container/vessel? | `markdown`, `code`, `json`, `yaml`, `html`, `pdf`, `video`, `audio`, `cli-output` |
| **W** | Structure | Internal skeleton/template? | Genre-specific: `meddpicc-scorecard`, `system-architecture`, `adr-template`, `review-checklist` |

#### Signal Routing

When an agent receives a signal it cannot decode (wrong mode, unfamiliar genre,
unsupported format), it MUST NOT attempt to process it. Instead:

1. **Mode mismatch** — Route to an agent with the required mode competence, or invoke
   a tool to transcode (e.g., video → transcript via transcription tool, PDF → text
   via extraction tool)
2. **Genre mismatch** — Route to an agent whose `signal` field declares competence in
   that genre, or escalate via `reportsTo`
3. **Format mismatch** — Use a tool to convert the format, or route to an agent with
   the required tool access

This is Ashby's Law applied at the agent level: the agent's decoding variety must
match the variety of signals it will encounter. When it doesn't, the agent routes
rather than guesses. See `architecture/optimal-system-mapping.md` for the full
Optimal System layer mapping.

### Skills

Skills are slash commands defined in `skills/{category}/{skill-slug}/SKILL.md`. The `skills`
field lists which skills this agent is authorized to invoke. At runtime, when a skill is
invoked, the agent reads the corresponding SKILL.md and follows its Process section.

Skills bridge the gap between agent identity (who they are) and agent capability (what they
can do). An agent's `tools` field covers raw integrations; `skills` covers structured
multi-step procedures the agent can execute on demand.

```yaml
# A code reviewer who can invoke /code-review and /lint
skills: [code-review, lint]

# A devops agent who can invoke /deploy, /build, and /health
skills: [deploy, build, health]

# An orchestrator who can invoke all development skills
skills: [build, test, lint, deploy, review, commit, create-pr]
```

## Body Sections

The Markdown body below the frontmatter MUST contain these 8 sections in order.
Each section encodes a specific dimension of the agent's behavior in the Signal Network:

| Section | Signal Theory Function |
|---------|----------------------|
| 1. Identity & Memory | Node identity — who this agent IS in the network |
| 2. Core Mission | Variety amplification — what signals this agent CAN handle (Ashby) |
| 3. Critical Rules | Variety attenuation — what signals this agent MUST NOT handle (Ashby) |
| 4. Process / Methodology | Domain encoding procedures — how this agent transforms signals |
| 5. Deliverable Templates | Pre-resolved Structure (dimension W) — output skeletons already encoded |
| 6. Communication Style | Encoding behavior — tone, genre selection, receiver bandwidth matching |
| 7. Success Metrics | Feedback targets — what to measure for loop closure (Wiener) |
| 8. Skills | Capability repertoire — which genre templates this agent can invoke |

### 1. Identity & Memory

Role definition, personality traits, domain experience, and persistent context the
agent carries across sessions. Written in second person ("You are...").

```markdown
# Identity & Memory
- **Role**: [functional description]
- **Personality**: [3-4 traits]
- **Memory**: [what the agent remembers across sessions]
- **Experience**: [domain expertise and perspective]
```

### 2. Core Mission

Numbered list of 3-5 primary capabilities. Each is a verb phrase describing what
this agent does.

```markdown
# Core Mission

1. **[Capability verb phrase]** — [description]
2. **[Capability verb phrase]** — [description]
3. **[Capability verb phrase]** — [description]
```

### 3. Critical Rules

Hard behavioral constraints that override any instruction. Written as imperatives.

```markdown
# Critical Rules

- NEVER [prohibited behavior]
- ALWAYS [required behavior]
- When [condition] -> [required action]
```

### 4. Process / Methodology

Domain frameworks, decision trees, and operating procedures. Numbered steps where
order matters. Tables where tradeoffs exist.

```markdown
# Process / Methodology

## [Framework Name]
### Step 1: [Phase]
...
```

### 5. Deliverable Templates

Exact output templates the agent produces. Named and formatted. The agent MUST use
these templates for tracked deliverables — no freeform output.

```markdown
# Deliverable Templates

### Template: [Deliverable Name]
```markdown
# [Title]
## Section 1
...
```

### 6. Communication Style

How the agent encodes and decodes signals. This section defines the agent's position
in the Signal Network — what it transmits, what it can receive, and how it calibrates
to the receiver's decoding capacity.

```markdown
# Communication Style
- **Tone**: [direct / consultative / formal / conversational]
- **Lead with**: [decision / finding / question / action]
- **Default genre**: [brief / spec / report / pitch / ...]
- **Receiver calibration**: [what downstream agents/humans expect]
```

The `signal` frontmatter field encodes the default output (what the agent transmits).
The Communication Style section describes the behavioral nuance: tone calibration,
genre selection strategy, and receiver bandwidth matching. Together, they fully
specify the agent's encoding behavior per Signal Theory's 6 encoding principles.

### 7. Success Metrics

Quantified targets the agent self-evaluates against.

```markdown
# Success Metrics
- [Metric]: [target]
- [Metric]: [target]
```

### 8. Skills

Which skills this agent activates and when. Maps skill slugs from frontmatter to
activation conditions specific to this agent's domain.

| Skill | Activates When |
|-------|---------------|
| `/code-review` | On every PR before merge — run structured review |
| `/lint` | After writing code — check style compliance |

## Org Chart

The `reportsTo` field composes agents into a directed acyclic org chart. Cycles are
invalid. The root node is always the CEO with `reportsTo: null`. The hierarchy has
4 levels below the CEO: Division → Department → Team → Agent.

```
ceo (reportsTo: null)
├── software-architect (Technology division head)
│    ├── devops-automator (Platform & Infrastructure dept head)
│    │    ├── security-engineer (Security Engineering team manager)
│    │    │    └── threat-detection-engineer
│    │    └── sre, incident-response-commander
│    ├── api-tester (Quality Assurance dept head)
│    │    └── ...
│    └── senior-developer (Application Development team manager)
│         └── frontend-developer, mobile-app-builder, ...
├── ux-architect (Creative & Content division head)
│    └── ...
├── seo-specialist (Growth division head)
│    └── ...
├── deal-strategist (Revenue division head)
│    └── ...
└── senior-project-manager (Operations division head)
     └── ...
```

Escalation always traverses upward via `reportsTo` until resolution. See
`protocol/division-format.md`, `protocol/department-format.md`, and
`protocol/team-format.md` for the organizational layers that group agents.

## Validation Rules

An agent file is valid if:

1. YAML frontmatter parses without error
2. All required frontmatter fields are present
3. `signal` field has exactly 5 comma-separated dimensions
4. `reportsTo` references an existing agent id or is null
5. All 8 body sections are present (matched by `# Section Name` headers)
6. `skills` field references existing skill directories in `skills/`
7. No emoji in section headers (emoji are for display, not structure)
8. Deliverable templates are fenced in code blocks

## Signal Theory Position

This spec implements **Layer 2 (The Signal)** and **Layer 3 (Composition)** of the
Optimal System architecture.

- **Layer 2**: The `signal` frontmatter field encodes the agent's default output as
  S=(M,G,T,F,W). The Signal Routing rules define how mismatched signals are re-routed.
- **Layer 3**: The 8 body sections ARE the compositional micro-structure of the agent
  definition — each section is a structural unit that composes into the complete agent.
- **Governing principles**: Ashby (variety of agent types must match variety of tasks),
  Beer (8-section structure maintains coherent architecture at every scale).

See `architecture/optimal-system-mapping.md` for the full 7-layer mapping.
