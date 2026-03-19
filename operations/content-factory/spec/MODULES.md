# Topology DAG v1.0

> Content Factory — module composition for multi-platform content production and distribution.

## Module Registry

### ContentGenerator
  source: PROCEDURES.md → Draft, Repurpose
  supervision: transient
  circuit_breaker:
    threshold: 3 failures in 120s
    timeout: 60_000ms
    fallback: use_template
  rate_limit: 30/minute

### Editor
  source: PROCEDURES.md → Edit, CheckBrandVoice
  supervision: transient
  circuit_breaker:
    threshold: 5 failures in 120s
    timeout: 30_000ms
    fallback: queue_for_manual_review
  rate_limit: 50/minute

### Distributor
  source: PROCEDURES.md → Publish, Schedule
  supervision: permanent
  circuit_breaker:
    threshold: 3 failures in 60s
    timeout: 30_000ms
    fallback: queue_for_retry
  rate_limit: 20/minute

### TrendAnalyzer
  source: PROCEDURES.md → AnalyzeTrend, AnalyzeCompetitor
  supervision: permanent
  cache: TTL 3600s
  rate_limit: 20/minute

### EngagementTracker
  source: PROCEDURES.md → ScoreEngagement, GetPerformanceReport
  supervision: permanent
  cache: TTL 300s
  rate_limit: 60/minute

### AssetManager
  source: PROCEDURES.md → UploadAsset
  supervision: transient
  circuit_breaker:
    threshold: 5 failures in 60s
    timeout: 30_000ms
    fallback: log_and_retry
  rate_limit: 50/minute

### CalendarManager
  source: PROCEDURES.md → GetContentCalendar
  supervision: permanent
  cache: TTL 60s

### ContentNotifier
  source: PROCEDURES.md → NotifyContent
  supervision: transient
  circuit_breaker:
    threshold: 10 failures in 60s
    timeout: 15_000ms
    fallback: log_and_continue


## Composition

### IdeationPipeline
  strategy: pipeline
  children: [TrendAnalyzer, CalendarManager, ContentNotifier]
  description: Analyze trends → check calendar availability → notify team of opportunities

### ProductionPipeline
  strategy: pipeline
  children: [ContentGenerator, Editor, AssetManager]
  description: Draft content → multi-pass editing → upload assets

### DistributionPipeline
  strategy: pipeline
  children: [Distributor, EngagementTracker, ContentNotifier]
  description: Publish to platform → track initial engagement → notify team

### RepurposePipeline
  strategy: pipeline
  children: [ContentGenerator, Editor, Distributor]
  description: Repurpose source → edit for platform → publish derivative

### QualityCheck
  strategy: merge
  children: [Editor, TrendAnalyzer]
  description: Parallel — brand voice check + trend alignment — both must pass

### ContentRouter
  strategy: union
  children:
    - IdeationPipeline      (when: event.type in [:content_idea_submitted, :trend_alert])
    - ProductionPipeline    (when: event.type in [:drafting_started, :revision_requested])
    - DistributionPipeline  (when: event.type in [:content_approved, :schedule_triggered])
    - RepurposePipeline     (when: event.type == :repurpose_requested)
    - ContentNotifier       (when: event.urgency in [:high, :critical])
  description: Route content events to the correct production pipeline

### PerformanceDashboard
  strategy: broadcast
  children: [EngagementTracker, ContentNotifier]
  description: Fan-out performance data to tracker + team notifications


## Event Bus

### ContentBus
  source: :any
  handlers: [ContentRouter]
  backpressure: :demand
  buffer: 5_000
  ordering: :priority
  dead_letter: true
  dead_letter_retention: 14d

### DistributionBus
  source: [Distributor]
  handlers: [EngagementTracker, ContentNotifier]
  backpressure: :buffer
  buffer: 2_000
  ordering: :fifo

### AnalyticsBus
  source: [EngagementTracker, TrendAnalyzer]
  handlers: [ContentNotifier, CalendarManager]
  backpressure: :buffer
  buffer: 1_000
  ordering: :fifo


## Health Checks

### Readiness
  check: all modules in Registry report :ready
  interval: 10s

### Liveness
  check: ContentBus processed > 0 events in last 300s (if not idle)
  interval: 30s

### LLM Provider Connection
  check: ContentGenerator.ping() returns :ok within 10s
  interval: 60s
  escalation: governance.integration_health_alert

### Platform API Status
  check: Distributor.ping_all() returns all :ok within 15s
  interval: 120s
  escalation: governance.integration_health_alert

### Circuit Breaker Status
  check: no modules in :open state for > 5 minutes
  interval: 15s
  escalation: governance.system_health_alert
