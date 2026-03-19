# Topology DAG v1.0

> TODO: Replace module names and composition with your domain topology.
> This template shows the structural pattern for registry, composition, and event bus.

## Module Registry

### ItemProcessor
  source: PROCEDURES.md → ProcessItem
  supervision: permanent
  rate_limit: 100/minute

### Analyzer
  source: PROCEDURES.md → AnalyzeInput, ScoreItem
  supervision: permanent
  cache: TTL 300s
  rate_limit: 200/minute

### RecordStore
  source: PROCEDURES.md → UpdateRecord, SearchRecords, GetStatus
  supervision: permanent
  circuit_breaker:
    threshold: 5 failures in 60s
    timeout: 15_000ms
    fallback: queue_for_retry

### OutputGenerator
  source: PROCEDURES.md → GenerateOutput
  supervision: transient
  circuit_breaker:
    threshold: 3 failures in 120s
    timeout: 60_000ms
    fallback: notify_and_queue
  rate_limit: 30/minute

### Notifier
  source: PROCEDURES.md → SendNotification
  supervision: transient
  circuit_breaker:
    threshold: 10 failures in 60s
    timeout: 15_000ms
    fallback: log_and_continue

### TaskExecutor
  source: PROCEDURES.md → ExecuteTask
  supervision: transient
  circuit_breaker:
    threshold: 3 failures in 60s
    timeout: 30_000ms
    fallback: halt_and_notify
  rate_limit: 20/minute

### Validator
  source: PROCEDURES.md → ValidateInput
  supervision: permanent
  rate_limit: 500/minute


## Composition

### IntakePipeline
  strategy: pipeline
  children: [Validator, Analyzer, RecordStore]
  description: Validate input → analyze/classify → store record

### ProcessingPipeline
  strategy: pipeline
  children: [ItemProcessor, RecordStore, Notifier]
  description: Process item → update record → notify stakeholders

### OutputPipeline
  strategy: pipeline
  children: [OutputGenerator, RecordStore, Notifier]
  description: Generate output → update record → notify delivery

### QualityGate
  strategy: merge
  children: [Analyzer, Validator]
  description: Parallel — score quality + validate schema — both must pass

### AlertBroadcast
  strategy: broadcast
  children: [Notifier]
  description: Fan-out alerts to all configured channels

### MainRouter
  strategy: union
  children:
    - IntakePipeline       (when: event.type in [:item_received, :item_resubmitted])
    - ProcessingPipeline   (when: event.type in [:processing_started, :retry_requested])
    - OutputPipeline       (when: event.type in [:review_approved, :output_requested])
    - AlertBroadcast       (when: event.urgency in [:high, :critical])
  description: Route all events to the correct pipeline


## Event Bus

### MainBus
  source: :any
  handlers: [MainRouter]
  backpressure: :demand
  buffer: 10_000
  ordering: :priority
  dead_letter: true
  dead_letter_retention: 7d

### InternalBus
  source: [ItemProcessor, OutputGenerator]
  handlers: [Notifier, RecordStore]
  backpressure: :buffer
  buffer: 2_000
  ordering: :fifo


## Health Checks

### Readiness
  check: all modules in Registry report :ready
  interval: 10s

### Liveness
  check: MainBus processed > 0 events in last 120s (if not idle)
  interval: 30s

### Circuit Breaker Status
  check: no modules in :open state for > 5 minutes
  interval: 15s
  escalation: governance.system_health_alert
