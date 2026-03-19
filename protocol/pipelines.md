# Pipelines — Event Stream Processing

> Pipelines define how external events enter the system, get filtered and transformed,
> and reach their consumers. They are the plumbing between the outside world and the
> spec layer's FSMs, procedures, and module topology.
>
> A pipeline is a markdown file that declares a producer → filter → consumer chain.
> The runtime reads the file and wires the stream. No code generation. Edit the
> markdown, the pipeline changes.

---

## Why Pipelines

Operations need to react to external events:
- A webhook fires when a lead fills out a form
- A cron job triggers daily digest generation
- A file appears in a watched directory
- A human types a command in the CLI

Without pipelines, the agent must poll, check, and route these events manually.
Pipelines make event intake declarative: define the source, the filter conditions,
and the destination. The runtime handles the rest.

```
External World                    Pipeline                     Internal System
─────────────────    ─────────────────────────────    ─────────────────────
Webhook POST    ───→ Producer → Filter → Consumer ───→ FSM transition
Cron tick       ───→ Producer → Filter → Consumer ───→ Procedure invocation
File change     ───→ Producer → Filter → Consumer ───→ Agent notification
Manual trigger  ───→ Producer →         Consumer ───→ Skill execution
```

---

## Pipeline Anatomy

Every pipeline has three sections:

### 1. Producer — Where Events Come From

| Producer Type | Source | Configuration |
|--------------|--------|---------------|
| `webhook` | HTTP POST to an endpoint | endpoint, auth, format |
| `cron` | Time-based schedule | cron expression, timezone |
| `file_watch` | Filesystem change detection | path, pattern, events (create/modify/delete) |
| `manual` | Human-triggered (CLI, UI button) | command name, args schema |
| `event_bus` | Internal event from another pipeline or module | bus name, event type filter |
| `queue` | Message queue consumer | queue name, consumer group |

### 2. Filter — Conditional Routing

Filters are optional. They evaluate event properties and either pass the event
through (with optional tags) or drop it.

| Filter Type | Logic |
|-------------|-------|
| `when` | Boolean predicate on event properties |
| `tag` | Adds metadata tags for downstream routing |
| `transform` | Reshapes event data (rename fields, extract nested values) |
| `debounce` | Suppresses duplicate events within a time window |
| `batch` | Collects events into groups by count or time window |

Filters chain. An event passes through all filters in order. If any `when` filter
returns false, the event is dropped (unless `on_drop` is configured).

### 3. Consumer — What Happens

| Consumer Type | Action |
|---------------|--------|
| `procedure` | Invoke a registered procedure from PROCEDURES.md |
| `fsm` | Trigger a state transition in a running FSM |
| `notify` | Send notification (Slack, email, SMS) |
| `write` | Write to a file or database |
| `pipeline` | Forward to another pipeline (chaining) |
| `agent` | Wake an agent with the event as context |
| `broadcast` | Fan-out to multiple consumers |

---

## Pipeline Format

```markdown
# Pipeline: Lead Intake

## Meta
  version: 1.0
  description: Routes inbound leads from web forms to the sales FSM
  active: true

## Producer: WebForm
  type: webhook
  endpoint: /api/leads/inbound
  auth: api_key (header: X-API-Key)
  format: json
  schema:
    required: [email, company, source]
    optional: [name, phone, message, utm_source, utm_campaign]

## Filter: Deduplicate
  type: debounce
  key: event.email
  window: 1h
  on_duplicate: drop_silent

## Filter: ScoreAndTag
  type: transform
  pipeline:
    - Classify.invoke(event) → %{segment}
    - Score.invoke(event, :lead_quality) → %{score}
  tag:
    - when: score >= 0.8 → "hot-lead"
    - when: score >= 0.5 → "warm-lead"
    - when: score < 0.5  → "cold-lead"

## Filter: HighValueOnly
  type: when
  condition: event.score >= 0.3
  on_drop: log("Dropped low-quality lead: #{event.email}")

## Consumer: SalesFSM
  type: fsm
  target: sales.workflow.md → :prospecting
  bind:
    $lead: event
  when: tag in ["hot-lead", "warm-lead"]

## Consumer: NurtureSequence
  type: procedure
  target: Execute
  args:
    command: "mix sequences.enroll #{event.email} cold_nurture"
  when: tag == "cold-lead"

## Consumer: LogAll
  type: write
  target: logs/leads/#{date}.jsonl
  format: jsonl
  fields: [timestamp, email, company, source, score, segment, tags]
```

---

## Real-Time Pipeline Composition

Pipelines can chain and compose. A consumer can forward events to another pipeline,
creating multi-stage processing.

```markdown
# Pipeline: Content Publishing

## Meta
  version: 1.0
  description: End-to-end content pipeline from draft to multi-platform publish

## Producer: DraftComplete
  type: event_bus
  source: MainBus
  filter: event.type == :draft_approved

## Filter: PlatformRouter
  type: transform
  pipeline:
    - Classify.invoke(event.content, :platform_fit) → %{platforms}

## Consumer: BlogPublish
  type: pipeline
  target: blog-publish.pipeline.md
  when: "blog" in event.platforms

## Consumer: SocialPublish
  type: pipeline
  target: social-publish.pipeline.md
  when: "social" in event.platforms

## Consumer: NewsletterQueue
  type: pipeline
  target: newsletter-queue.pipeline.md
  when: "newsletter" in event.platforms
```

---

## Common Pipeline Patterns

### Webhook Intake

The most common pattern. External service POSTs data, pipeline routes it.

```markdown
# Pipeline: Stripe Webhook

## Producer: StripeEvents
  type: webhook
  endpoint: /api/webhooks/stripe
  auth: signature (header: Stripe-Signature, secret: env.STRIPE_WEBHOOK_SECRET)
  format: json

## Filter: RelevantEvents
  type: when
  condition: event.type in [
    "invoice.paid",
    "invoice.payment_failed",
    "customer.subscription.deleted",
    "customer.subscription.updated"
  ]

## Consumer: RevenueTracker
  type: procedure
  target: Execute
  args:
    command: "mix revenue.process #{event.type} #{event.data.object.id}"
  when: event.type starts_with "invoice."

## Consumer: ChurnAlert
  type: notify
  channel: #revenue-alerts
  template: "CHURN: {{event.data.object.customer}} cancelled subscription"
  urgency: high
  when: event.type == "customer.subscription.deleted"
```

### Scheduled Processing

Cron-driven pipelines for batch operations.

```markdown
# Pipeline: Daily Digest

## Producer: MorningCron
  type: cron
  schedule: "0 9 * * 1-5"
  timezone: America/Chicago

## Filter: GatherSignals
  type: transform
  pipeline:
    - Search.invoke(%{query: "*", scope: :signals, since: "24h"}) → %{signals}
    - Summarize.invoke(signals, 1000) → %{digest}

## Consumer: DeliverDigest
  type: notify
  channel: email
  to: team@company.com
  template: "daily-digest"
  data: {signals: event.signals, digest: event.digest}
```

### File Watch

React to filesystem changes.

```markdown
# Pipeline: Document Intake

## Producer: DropFolder
  type: file_watch
  path: ./inbox/
  pattern: "*.md"
  events: [create]

## Filter: ValidateFormat
  type: when
  condition: file.size > 0 AND file.size < 1_000_000

## Consumer: Ingest
  type: procedure
  target: Execute
  args:
    command: "mix optimal.ingest --file #{event.path}"
```

---

## Pipeline Runtime Behavior

| Aspect | Behavior |
|--------|----------|
| **Startup** | Pipelines activate when the workspace boots |
| **Hot reload** | Edit the pipeline markdown → runtime detects change → rewires |
| **Error handling** | Consumer failures retry 3x with exponential backoff |
| **Dead letters** | Events that fail all retries go to dead letter log |
| **Ordering** | Events processed in order within a pipeline (FIFO) |
| **Concurrency** | Multiple pipelines run concurrently |
| **Backpressure** | Configurable per-consumer (drop, buffer, block) |
| **Metrics** | Events received, processed, dropped, errored per pipeline |

### Error Handling Configuration

```markdown
## Error Policy
  retries: 3
  backoff: exponential (1s, 2s, 4s)
  dead_letter: logs/dead-letters/#{pipeline_name}.jsonl
  on_persistent_failure: notify(ops, "Pipeline #{name} failing: #{error}")
```

---

## Pipeline Discovery

The runtime discovers pipelines by scanning for:

1. `spec/` directory files with pipeline content
2. `pipelines/` directory (alternative location for pipeline-heavy workspaces)
3. Any `.pipeline.md` file in the workspace

```
my-operation/
├── spec/
│   ├── PROCEDURES.md
│   └── WORKFLOW.md
├── pipelines/              ← Pipeline-heavy operations use this
│   ├── lead-intake.md
│   ├── stripe-webhook.md
│   ├── daily-digest.md
│   └── file-watch.md
└── SYSTEM.md
```

---

## Relationship to Other Layers

| Layer | Relationship |
|-------|-------------|
| **Spec / Procedures** | Pipelines invoke procedures as consumers |
| **Spec / Workflows** | Pipelines trigger FSM transitions |
| **Spec / Modules** | Pipelines feed events into the module topology's event bus |
| **Heartbeat** | Pipeline events can wake agents via heartbeat triggers |
| **Adapters** | Pipeline producers use adapters for external connectivity |
| **Governance** | High-risk pipeline consumers can require approval gates |

---

*Pipelines v1.0 — Event stream processing specifications for OSA Operations*
