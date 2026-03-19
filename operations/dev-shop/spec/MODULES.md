# Topology DAG v1.0

> Dev Shop — module composition for CI/CD pipeline, code quality, and deployment.

## Module Registry

### CodeAnalyzer
  source: PROCEDURES.md → AnalyzeCode, LintCheck, CheckDependencies
  supervision: permanent
  cache: TTL 300s
  rate_limit: 100/minute

### TestRunner
  source: PROCEDURES.md → RunTests, CheckCoverage
  supervision: permanent
  rate_limit: 50/minute

### Deployer
  source: PROCEDURES.md → Deploy, RollbackDeploy
  supervision: transient
  circuit_breaker:
    threshold: 3 failures in 300s
    timeout: 60_000ms
    fallback: notify_oncall_and_halt

### PRManager
  source: PROCEDURES.md → CreatePR, MergePR, ReviewCode, GetPRStatus
  supervision: permanent
  circuit_breaker:
    threshold: 5 failures in 60s
    timeout: 15_000ms
    fallback: queue_for_retry

### BranchManager
  source: PROCEDURES.md → CreateBranch
  supervision: transient
  rate_limit: 50/minute

### DevNotifier
  source: PROCEDURES.md → NotifyDev
  supervision: transient
  circuit_breaker:
    threshold: 10 failures in 60s
    timeout: 15_000ms
    fallback: log_and_continue

### BuildMonitor
  source: PROCEDURES.md → GetBuildStatus
  supervision: permanent
  cache: TTL 15s
  rate_limit: 200/minute


## Composition

### QualityGatePipeline
  strategy: pipeline
  children: [CodeAnalyzer, TestRunner]
  description: Static analysis → lint → tests → coverage — sequential quality gates

### CodeReviewPipeline
  strategy: pipeline
  children: [PRManager, CodeAnalyzer, DevNotifier]
  description: Open PR → AI review + static analysis → notify reviewers

### DeploymentPipeline
  strategy: pipeline
  children: [TestRunner, Deployer, BuildMonitor, DevNotifier]
  description: Full test suite → deploy → verify build → notify team

### PreMergeChecks
  strategy: merge
  children: [CodeAnalyzer, TestRunner, PRManager]
  description: Parallel — static analysis + tests + PR status — all must pass to merge

### CIRouter
  strategy: union
  children:
    - QualityGatePipeline   (when: event.type in [:push, :branch_created])
    - CodeReviewPipeline    (when: event.type in [:pr_opened, :pr_updated])
    - DeploymentPipeline    (when: event.type in [:pr_merged, :deploy_requested])
    - PreMergeChecks        (when: event.type == :merge_requested)
    - DevNotifier           (when: event.urgency in [:high, :critical])
  description: Route CI/CD events to the correct pipeline

### RollbackPipeline
  strategy: pipeline
  children: [Deployer, DevNotifier]
  description: Emergency rollback → notify oncall


## Event Bus

### CIBus
  source: :any
  handlers: [CIRouter]
  backpressure: :demand
  buffer: 5_000
  ordering: :priority
  dead_letter: true
  dead_letter_retention: 14d

### DeployBus
  source: [Deployer, BuildMonitor]
  handlers: [DevNotifier]
  backpressure: :buffer
  buffer: 1_000
  ordering: :fifo

### QualityBus
  source: [CodeAnalyzer, TestRunner]
  handlers: [PRManager, DevNotifier]
  backpressure: :buffer
  buffer: 2_000
  ordering: :fifo


## Health Checks

### Readiness
  check: all modules in Registry report :ready
  interval: 10s

### Liveness
  check: CIBus processed > 0 events in last 300s (if not idle)
  interval: 30s

### Git Provider Connection
  check: PRManager.ping() returns :ok within 5s
  interval: 60s
  escalation: governance.integration_health_alert

### CI Provider Connection
  check: TestRunner.ping() returns :ok within 10s
  interval: 60s
  escalation: governance.integration_health_alert

### Circuit Breaker Status
  check: no modules in :open state for > 5 minutes
  interval: 15s
  escalation: governance.system_health_alert
