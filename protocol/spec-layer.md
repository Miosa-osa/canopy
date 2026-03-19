# Spec Layer — Executable Markdown Specifications

> The optional `spec/` directory turns a workspace from a knowledge library into
> a programmable system. Markdown files compile to executable behavior: procedure
> bindings, finite state machines, and module topology. The spec layer bridges
> human-readable documentation and machine-executable configuration.
>
> **Design principle:** Markdown is the source of truth. The runtime reads these
> files, parses the structured sections, and compiles them into live behavior.
> No code generation step. No build pipeline. Edit the markdown, the system changes.

---

## Why a Spec Layer

Most Operations work fine with agents, skills, and reference files. The agent reads
SYSTEM.md, discovers skills, loads reference on-demand, and operates.

But some Operations need deterministic behavior:
- A sales pipeline that MUST follow qualification gates
- An intake system that routes events to specific handlers
- A deployment workflow with circuit breakers and rollback logic
- A content pipeline that enforces editorial approval before publish

These require more than "agent judgment." They require **declared state machines,
typed procedure bindings, and composed module graphs.** The spec layer provides
all three.

```
Without spec/:
  Agent reads SYSTEM.md → uses judgment → acts

With spec/:
  Agent reads SYSTEM.md → discovers spec/ → loads FSMs, procedures, topology
  → follows deterministic paths where declared
  → uses judgment only where the spec allows flexibility
```

---

## Directory Structure

```
my-operation/
├── SYSTEM.md              ← Agent entry point (always required)
├── agents/                ← Agent definitions
├── skills/                ← Slash command implementations
├── reference/             ← Knowledge files
├── spec/                  ← EXECUTABLE SPECIFICATIONS (optional)
│   ├── PROCEDURES.md      ← Action & query bindings
│   ├── WORKFLOW.md         ← FSM definitions (or multiple: sales.workflow.md, etc.)
│   └── MODULES.md          ← DAG topology + composition
└── company.yaml           ← Org chart + budgets
```

A workspace can have zero, one, two, or all three spec files. They compose independently:
- PROCEDURES.md alone: typed action/query registry without FSMs
- WORKFLOW.md alone: state machines that reference inline procedures
- MODULES.md alone: topology for composing existing agents/skills
- All three: full executable system

---

## PROCEDURES.md — Action & Query Bindings

Maps symbolic names to concrete implementations. This is the workspace's **capability registry** — what the system can DO.

### Two Binding Types

| Type | Semantics | Examples |
|------|-----------|---------|
| **Action** | Side-effect producer. Changes state, sends messages, writes files. | `Say`, `Execute`, `SendEmail`, `WriteFile`, `Deploy`, `Notify` |
| **Query** | Pure function. Reads state, computes results, returns data. | `Listen`, `Analyze`, `Search`, `Classify`, `Score`, `Summarize` |

Actions and queries are separated because:
1. **Caching**: Queries can be cached. Actions cannot.
2. **Safety**: Queries can run without approval gates. Actions may need governance review.
3. **Retry**: Queries are idempotent. Actions may need compensation on retry.
4. **Testing**: Queries can be tested with assertions. Actions need effect verification.

### Binding Schema

Each binding declares:

| Field | Required | Description |
|-------|----------|-------------|
| Name | yes | Symbolic name (PascalCase) |
| Implementation | yes | Module path or shell command |
| Spec | yes | Type signature with input/output types |
| Runtime | no | Which service handles execution (allows hot-swap) |
| Sandbox | no | Whether execution is sandboxed |
| Timeout | no | Max execution time before kill |
| Cache | no | Caching strategy for queries (TTL, key) |
| Approval | no | Governance gate required before execution |

### Format

```markdown
# Procedure Registry v1.0

## Action Bindings (Side-Effect Producers)

### Say → Actions.say/2
  @spec say(context(), %{text: String.t(), channel: atom()}) :: :ok | {:error, reason}
  Runtime: TTS provider (hot-swap between ElevenLabs, OpenAI, local)
  Timeout: 10s
  Approval: none

### Execute → Actions.execute/2
  @spec execute(context(), %{command: String.t(), args: [String.t()]}) :: {:ok, output} | {:error, reason}
  Runtime: shell
  Sandbox: yes
  Timeout: 30s
  Approval: governance.execution_review (if command matches /rm|delete|drop|shutdown/)

### SendEmail → Actions.send_email/2
  @spec send_email(context(), %{to: String.t(), subject: String.t(), body: String.t(), genre: atom()}) :: {:ok, message_id}
  Runtime: SMTP provider (hot-swap)
  Timeout: 15s
  Approval: none (unless to_count > 50 → governance.bulk_send_review)

### WriteFile → Actions.write_file/2
  @spec write_file(context(), %{path: String.t(), content: String.t()}) :: :ok
  Runtime: filesystem
  Sandbox: yes (confined to workspace root)
  Approval: none

### Deploy → Actions.deploy/2
  @spec deploy(context(), %{target: atom(), version: String.t()}) :: {:ok, deployment_id} | {:error, reason}
  Runtime: deployment provider
  Timeout: 300s
  Approval: governance.deploy_review (always)

### Notify → Actions.notify/2
  @spec notify(context(), %{channel: String.t(), message: String.t(), urgency: atom()}) :: :ok
  Runtime: notification hub (Slack, email, SMS — routed by urgency)
  Timeout: 10s
  Approval: none


## Query Bindings (Pure Functions)

### Listen → Queries.listen/1
  @spec listen(context()) :: {:ok, %{events: [event()], since: DateTime.t()}}
  Runtime: event store
  Cache: TTL 5s, key: {context.scope, context.cursor}

### Analyze → Queries.analyze/1
  @spec analyze(context()) :: {:ok, %{intent: atom(), sentiment: float(), entities: [entity()]}}
  Runtime: classifier model
  Cache: TTL 60s, key: {hash(context.input)}

### Search → Queries.search/2
  @spec search(context(), %{query: String.t(), scope: atom(), limit: integer()}) :: {:ok, [result()]}
  Runtime: search engine (FTS + vector hybrid)
  Cache: TTL 30s, key: {hash(query), scope}

### Classify → Queries.classify/2
  @spec classify(context(), %{input: String.t(), taxonomy: atom()}) :: {:ok, %{category: atom(), confidence: float()}}
  Runtime: classifier model
  Cache: TTL 300s, key: {hash(input), taxonomy}

### Score → Queries.score/2
  @spec score(context(), %{entity: map(), rubric: atom()}) :: {:ok, %{score: float(), breakdown: map()}}
  Runtime: scoring engine
  Cache: TTL 60s, key: {hash(entity), rubric}

### Summarize → Queries.summarize/2
  @spec summarize(context(), %{content: String.t(), max_tokens: integer()}) :: {:ok, String.t()}
  Runtime: LLM
  Cache: TTL 3600s, key: {hash(content), max_tokens}
```

### Hot-Swapping

The `Runtime` field enables hot-swapping without changing procedure signatures. The workspace
operator can switch TTS providers, email services, or LLM backends by updating the runtime
config — no procedure changes needed.

```
# Runtime config (separate from PROCEDURES.md)
# Typically in company.yaml or environment config

runtime_bindings:
  tts_provider: elevenlabs    # or: openai, local, azure
  smtp_provider: sendgrid     # or: ses, postmark
  llm_provider: anthropic     # or: openai, ollama, local
  search_engine: hybrid       # or: fts_only, vector_only
```

---

## WORKFLOW.md — Finite State Machine Definitions

Deterministic state machines that govern multi-step processes. Each workflow is a
finite automaton with typed states, trigger predicates, execution pipelines, and
conditional branching.

### Why FSMs in Markdown

Agent judgment is good for novel situations. It is bad for repeatable processes where
skipping a step or making a wrong turn has consequences. FSMs give you:

- **Guaranteed ordering**: Steps execute in the declared sequence
- **Gate enforcement**: A deal cannot reach Proposal without passing Discovery
- **Auditability**: Every state transition is logged with timestamp and trigger
- **Timeout handling**: Stale states auto-transition instead of rotting forever
- **Parallel tracks**: Multiple FSMs can run concurrently on different entities

### State Schema

Each state declares:

| Field | Required | Description |
|-------|----------|-------------|
| Name | yes | State identifier (atom, snake_case with colon prefix) |
| Trigger | yes | Event predicate that causes entry |
| Pipeline | yes | Ordered sequence of procedure invocations |
| Branch | no | Conditional transitions based on pipeline results |
| Timeout | no | Duration before auto-transition |
| On-enter | no | Side effects when entering state |
| On-exit | no | Side effects when leaving state |

### Data Flow

Pipeline steps pass data forward using the arrow operator. Each step's output
becomes available to subsequent steps:

```
Analyze.invoke($lead) → %{score, segment}
```

Here `$lead` is a reference to the entity bound to the FSM instance. The output
`%{score, segment}` is destructured and available in subsequent steps and branch
conditions.

### Format

```markdown
# Sales Pipeline FSM

## Meta
  type: :sales
  entry_state: :prospecting
  entity: :deal
  version: 1.0

## States

### :prospecting
  trigger: Event.eq(:type, :new_lead)
  on-enter: Notify.invoke(owner, "New lead: #{$lead.company}")
  pipeline:
    - Search.invoke(%{query: $lead.company, scope: :crm}) → %{existing}
    - Branch.on(:existing)
        present → FSM.transition(:dedup_review)
        absent  → :continue
    - Analyze.invoke($lead) → %{score, segment}
    - Branch.on(:score)
        >= 0.8 → [Notify.invoke(sales_team, "Hot lead: #{$lead.company}"), FSM.transition(:qualifying)]
        >= 0.5 → FSM.transition(:nurturing)
        :_     → FSM.transition(:cold_storage)
  timeout: 48h → FSM.transition(:cold_storage)

### :qualifying
  trigger: Event.eq(:type, :qualification_started)
  pipeline:
    - Score.invoke($deal, :meddpicc) → %{score, gaps}
    - Branch.on(:score)
        >= 0.6 → FSM.transition(:discovery)
        :_     → [Notify.invoke(owner, "Qualification gaps: #{$gaps}"), FSM.transition(:nurturing)]
  timeout: 7d → Notify.invoke(owner, "Deal stale in qualifying: #{$deal.company}")

### :discovery
  trigger: Event.eq(:type, :discovery_call_complete)
  pipeline:
    - Analyze.invoke($call_transcript) → %{intent, pain_points, budget_signals}
    - Score.invoke($deal, :meddpicc) → %{score, gaps}
    - Branch.on(:score)
        >= 0.8 → FSM.transition(:proposal)
        >= 0.6 → [Notify.invoke(owner, "Gaps remain: #{$gaps}"), FSM.stay]
        :_     → FSM.transition(:nurturing)
  timeout: 14d → FSM.transition(:nurturing)

### :proposal
  trigger: Event.eq(:type, :proposal_requested)
  pipeline:
    - Summarize.invoke($deal.history, 500) → %{deal_summary}
    - Execute.invoke("mix gen.proposal #{$deal.id}") → %{proposal_path}
    - Notify.invoke(owner, "Proposal ready: #{$proposal_path}")
    - FSM.transition(:negotiation)
  timeout: 7d → Notify.invoke(owner, "Proposal not sent: #{$deal.company}")

### :negotiation
  trigger: Event.eq(:type, :negotiation_started)
  pipeline:
    - Analyze.invoke($negotiation_input) → %{terms, objections}
    - Branch.on(:objections)
        empty   → FSM.transition(:closing)
        present → [Notify.invoke(owner, "Objections: #{$objections}"), FSM.stay]
  timeout: 30d → FSM.transition(:lost)

### :closing
  trigger: Event.eq(:type, :verbal_yes)
  pipeline:
    - Execute.invoke("mix gen.contract #{$deal.id}") → %{contract_path}
    - Notify.invoke(owner, "Contract ready: #{$contract_path}")
    - Notify.invoke(finance, "Expected close: #{$deal.value}")
    - FSM.transition(:won)
  timeout: 14d → FSM.transition(:negotiation)

### :won
  trigger: Event.eq(:type, :contract_signed)
  on-enter: Notify.invoke(team, "CLOSED WON: #{$deal.company} — $#{$deal.value}")
  pipeline:
    - Execute.invoke("mix crm.close_won #{$deal.id}")
  terminal: true

### :lost
  trigger: Event.eq(:type, :deal_lost)
  on-enter: Notify.invoke(owner, "Deal lost: #{$deal.company}. Reason: #{$reason}")
  pipeline:
    - Execute.invoke("mix crm.close_lost #{$deal.id} #{$reason}")
  terminal: true

### :nurturing
  trigger: Event.eq(:type, :moved_to_nurture)
  pipeline:
    - Execute.invoke("mix sequences.enroll #{$deal.id} nurture_track")
  timeout: 90d → FSM.transition(:cold_storage)

### :cold_storage
  terminal: true
  on-enter: Execute.invoke("mix crm.archive #{$deal.id}")
```

### Multiple Workflows

A workspace can define multiple FSMs. Use separate files with the `.workflow.md` suffix:

```
spec/
├── PROCEDURES.md
├── sales.workflow.md
├── onboarding.workflow.md
├── support-escalation.workflow.md
└── MODULES.md
```

Or define multiple FSMs in a single WORKFLOW.md using top-level headers as separators.

### FSM Runtime Behavior

| Aspect | Behavior |
|--------|----------|
| **Instantiation** | One FSM instance per entity (e.g., one sales FSM per deal) |
| **Persistence** | Current state + history serialized to session store |
| **Concurrency** | Multiple FSM instances run independently |
| **Transitions** | Atomic — state change + side effects in one transaction |
| **History** | Full transition log: `[{from, to, trigger, timestamp, data}]` |
| **Visualization** | Runtime can render FSM as a state diagram from the markdown |

---

## MODULES.md — DAG Topology & Composition

Defines how modules (agents, workflows, processors) compose into a directed acyclic
graph. This is the system's **wiring diagram** — what connects to what, how events
flow, and where fault tolerance boundaries live.

### Why a Topology File

Individual agents and workflows are powerful alone. But real systems need:
- **Composition**: Chain processors in sequence (pipeline)
- **Fan-out**: Route events to multiple handlers (union)
- **Merge**: Combine results from parallel processors (merge)
- **Fault isolation**: Circuit breakers around unreliable components
- **Backpressure**: Prevent fast producers from overwhelming slow consumers

### Module Registry

Every module must be registered before it can participate in composition.

| Field | Required | Description |
|-------|----------|-------------|
| Name | yes | Module identifier (PascalCase) |
| Source | yes | Where the module is defined (file reference) |
| Supervision | yes | `permanent` (always restart), `transient` (restart on crash), `temporary` (never restart) |
| Circuit breaker | no | Failure threshold + timeout before tripping |
| Rate limit | no | Max invocations per time window |

### Composition Strategies

| Strategy | Semantics | When to Use |
|----------|-----------|-------------|
| **pipeline** | Sequential: output of A feeds input of B | Linear processing chains |
| **merge** | Logical AND: all children must complete, results combined | Parallel analysis that needs consensus |
| **union** | Logical OR: event routed to first matching child | Conditional routing |
| **broadcast** | Fan-out: event sent to all children simultaneously | Notifications, logging, multi-track processing |

### Event Bus

The event bus connects producers to consumers through the module graph.

| Field | Description |
|-------|-------------|
| Source | Which modules produce events (`:any` for global) |
| Handlers | Which composed modules consume events |
| Backpressure | `:demand` (consumer pulls) or `:buffer` (producer pushes to buffer) |
| Buffer | Max buffered events before dropping or blocking |
| Ordering | `:fifo`, `:priority`, or `:unordered` |

### Format

```markdown
# Topology DAG v1.0

## Module Registry

### LeadProcessor
  source: sales.workflow.md
  supervision: permanent
  rate_limit: 100/minute

### EmailSender
  source: PROCEDURES.md → SendEmail
  supervision: transient
  circuit_breaker:
    threshold: 5 failures in 60s
    timeout: 30_000ms
    fallback: queue_for_retry

### LeadScorer
  source: PROCEDURES.md → Score
  supervision: permanent
  cache: TTL 300s

### NotificationHub
  source: PROCEDURES.md → Notify
  supervision: transient
  circuit_breaker:
    threshold: 10 failures in 60s
    timeout: 15_000ms
    fallback: log_and_continue

### ContentGenerator
  source: PROCEDURES.md → Summarize
  supervision: transient
  rate_limit: 20/minute
  circuit_breaker:
    threshold: 3 failures in 120s
    timeout: 60_000ms
    fallback: use_template


## Composition

### SalesPipeline
  strategy: pipeline
  children: [LeadScorer, LeadProcessor, EmailSender]
  description: Score → qualify → send outreach

### AlertSystem
  strategy: broadcast
  children: [NotificationHub, EmailSender]
  description: Fan-out alerts to all channels

### InboundRouter
  strategy: union
  children:
    - SalesPipeline  (when: event.type in [:new_lead, :deal_update])
    - AlertSystem    (when: event.urgency == :high)
    - ContentGenerator (when: event.type == :content_request)
  description: Route inbound events to the right pipeline


## Event Bus

### MainBus
  source: :any
  handlers: [InboundRouter]
  backpressure: :demand
  buffer: 10_000
  ordering: :priority
  dead_letter: true
  dead_letter_retention: 7d

### InternalBus
  source: [LeadProcessor, EmailSender]
  handlers: [NotificationHub]
  backpressure: :buffer
  buffer: 1_000
  ordering: :fifo


## Health Checks

### Readiness
  check: all modules in Registry report :ready
  interval: 10s

### Liveness
  check: MainBus processed > 0 events in last 60s (if not idle)
  interval: 30s

### Circuit Breaker Status
  check: no modules in :open state for > 5 minutes
  interval: 15s
  escalation: governance.system_health_alert
```

---

## How the Runtime Processes Spec Files

### Discovery

When an agent boots and reads SYSTEM.md, it checks for `spec/`:

```
1. Scan workspace root for spec/ directory
2. If absent → standard operation (agents + skills + reference only)
3. If present → parse spec files in order:
   a. PROCEDURES.md → build procedure registry
   b. *.workflow.md or WORKFLOW.md → compile FSM definitions
   c. MODULES.md → build topology graph
4. Validate:
   - All procedure references in workflows resolve to registered procedures
   - All module sources in topology resolve to registered modules or workflows
   - No cycles in the module DAG
   - All governance references resolve to defined approval gates
5. Register compiled specs in the session context
```

### Execution Priority

When the agent receives an event, resolution order is:

```
1. Does an active FSM instance match this event? → Execute FSM transition
2. Does the topology router match this event? → Route through module graph
3. Does a skill match? → Execute skill
4. Does an agent match? → Delegate to agent
5. No match → Agent uses judgment (standard SYSTEM.md behavior)
```

Spec-declared behavior always takes priority over agent judgment. This is by design:
if you declared a deterministic path, you want it followed.

### Validation Rules

| Rule | Consequence of Violation |
|------|------------------------|
| Procedure referenced but not in PROCEDURES.md | Compile error — spec won't load |
| FSM state references nonexistent procedure | Compile error |
| Module graph contains a cycle | Compile error — DAGs only |
| Circuit breaker threshold <= 0 | Warning — defaults to 5 |
| Timeout <= 0 | Warning — defaults to 30s |
| Terminal state has transitions | Warning — transitions ignored |
| Entry state not defined | Compile error |

---

## Relationship to Other Architecture Layers

| Layer | Relationship to Spec |
|-------|---------------------|
| **Heartbeat** | Heartbeat triggers FSM transitions when events match |
| **Governance** | Procedures can require approval gates before execution |
| **Budgets** | Procedure invocations can have cost tracking |
| **Tasks** | FSM states can map to task phases |
| **Sessions** | FSM state + history persisted in session store |
| **Adapters** | Procedure runtimes resolve through adapter layer |
| **Signal Integration** | Procedure outputs pass through S/N quality gates |
| **Marketplace** | Spec files included in Operation bundles |

---

## When to Use Spec vs. Agent Judgment

| Situation | Use Spec | Use Agent Judgment |
|-----------|----------|-------------------|
| Process has mandatory ordering | FSM | — |
| Failure has financial consequences | FSM + circuit breakers | — |
| Process is repeatable across entities | FSM | — |
| Situation is novel or ambiguous | — | Agent decides |
| Output genre varies by receiver | — | Agent applies Signal Theory |
| Multiple valid approaches exist | — | Agent selects approach |
| Compliance requires audit trail | FSM (logged transitions) | — |
| Process involves external integrations | Procedures (typed, sandboxed) | — |

The spec layer and agent judgment are complementary. Spec handles the deterministic
skeleton. The agent handles the flesh — the judgment calls within and between
deterministic paths.

---

## Examples

### Minimal Spec (Procedures Only)

```
spec/
└── PROCEDURES.md    ← Just a capability registry, no FSMs
```

Use case: The workspace wants typed, documented procedures that agents can invoke
by name, with caching and timeout guarantees, but doesn't need state machines.

### Full Spec (All Three)

```
spec/
├── PROCEDURES.md           ← 15 procedures (actions + queries)
├── sales.workflow.md       ← 10-state sales FSM
├── onboarding.workflow.md  ← 6-state customer onboarding FSM
└── MODULES.md              ← Pipeline composition + event bus
```

Use case: A sales operation with deterministic deal flow, automated onboarding,
event-driven routing, and fault-tolerant integrations.

### Spec + Pipelines

```
spec/
├── PROCEDURES.md
├── intake.workflow.md
└── MODULES.md
pipelines/
├── webhook-intake.md
└── daily-digest.md
```

Use case: Event-driven system where external webhooks feed into FSMs through
the pipeline layer (see `architecture/pipelines.md`).

---

*Spec Layer v1.0 — Executable markdown specifications for OSA Operations workspaces*
