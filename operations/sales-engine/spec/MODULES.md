# Topology DAG v1.0

> Sales Engine — module composition, event routing, and fault tolerance boundaries.

## Module Registry

### LeadProcessor
  source: WORKFLOW.md → :prospecting, :qualifying
  supervision: permanent
  rate_limit: 200/minute

### OutreachEngine
  source: PROCEDURES.md → SendOutreach
  supervision: transient
  circuit_breaker:
    threshold: 10 failures in 60s
    timeout: 30_000ms
    fallback: queue_for_retry
  rate_limit: 100/minute

### CRMSync
  source: PROCEDURES.md → UpdateCRM, CreateDeal
  supervision: permanent
  circuit_breaker:
    threshold: 5 failures in 60s
    timeout: 15_000ms
    fallback: queue_for_retry

### LeadScorer
  source: PROCEDURES.md → ScoreLead, AnalyzeLead
  supervision: permanent
  cache: TTL 300s
  rate_limit: 500/minute

### ProposalBuilder
  source: PROCEDURES.md → SendProposal
  supervision: transient
  circuit_breaker:
    threshold: 3 failures in 120s
    timeout: 60_000ms
    fallback: notify_owner_manual
  rate_limit: 20/minute

### CalendarSync
  source: PROCEDURES.md → ScheduleCall
  supervision: transient
  circuit_breaker:
    threshold: 5 failures in 60s
    timeout: 10_000ms
    fallback: notify_owner_manual

### SalesNotifier
  source: PROCEDURES.md → NotifySales
  supervision: transient
  circuit_breaker:
    threshold: 10 failures in 60s
    timeout: 15_000ms
    fallback: log_and_continue

### RevenueAnalyzer
  source: PROCEDURES.md → ForecastRevenue, CheckPipeline
  supervision: permanent
  cache: TTL 300s


## Composition

### InboundLeadPipeline
  strategy: pipeline
  children: [LeadScorer, LeadProcessor, CRMSync, OutreachEngine]
  description: Score lead → qualify via FSM → sync to CRM → trigger outreach

### DealProgressionPipeline
  strategy: pipeline
  children: [LeadScorer, CRMSync, SalesNotifier]
  description: Re-score deal → update CRM stage → notify owner of changes

### ProposalPipeline
  strategy: pipeline
  children: [RevenueAnalyzer, ProposalBuilder, CRMSync, SalesNotifier]
  description: Pull deal context → generate proposal → update CRM → notify

### AlertBroadcast
  strategy: broadcast
  children: [SalesNotifier, OutreachEngine]
  description: Fan-out high-urgency alerts to Slack + email simultaneously

### InboundRouter
  strategy: union
  children:
    - InboundLeadPipeline    (when: event.type in [:new_lead, :lead_enriched])
    - DealProgressionPipeline (when: event.type in [:stage_change, :score_update, :call_complete])
    - ProposalPipeline       (when: event.type in [:proposal_requested, :proposal_expired])
    - AlertBroadcast         (when: event.urgency == :critical)
    - CalendarSync           (when: event.type == :meeting_requested)
  description: Route all inbound sales events to the correct pipeline

### EngagementMonitor
  strategy: merge
  children: [LeadScorer, RevenueAnalyzer]
  description: Parallel scoring + forecasting, merge results for pipeline health


## Event Bus

### SalesBus
  source: :any
  handlers: [InboundRouter]
  backpressure: :demand
  buffer: 10_000
  ordering: :priority
  dead_letter: true
  dead_letter_retention: 7d

### CRMEventBus
  source: [CRMSync, LeadProcessor]
  handlers: [SalesNotifier, RevenueAnalyzer]
  backpressure: :buffer
  buffer: 5_000
  ordering: :fifo

### OutreachEventBus
  source: [OutreachEngine]
  handlers: [LeadScorer, CRMSync]
  backpressure: :buffer
  buffer: 2_000
  ordering: :fifo


## Health Checks

### Readiness
  check: all modules in Registry report :ready
  interval: 10s

### Liveness
  check: SalesBus processed > 0 events in last 120s (if not idle)
  interval: 30s

### CRM Connection
  check: CRMSync.ping() returns :ok within 5s
  interval: 60s
  escalation: governance.integration_health_alert

### Circuit Breaker Status
  check: no modules in :open state for > 5 minutes
  interval: 15s
  escalation: governance.system_health_alert
