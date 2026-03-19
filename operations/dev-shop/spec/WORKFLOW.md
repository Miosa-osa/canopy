# Development Pipeline FSM

## Meta
  type: :development
  entry_state: :backlog
  entity: :ticket
  version: 1.0

## States

### :backlog
  trigger: Event.eq(:type, :ticket_created)
  on-enter: NotifyDev.invoke(:slack, "New ticket: #{$ticket.title} [#{$ticket.priority}]")
  pipeline:
    - AnalyzeCode.invoke(%{repo: $ticket.repo, path: $ticket.affected_paths, analysis: [:complexity, :dependencies]}) → %{findings, risk_score}
    - Branch.on(:risk_score)
        >= 0.8 → [NotifyDev.invoke(:slack, "High-risk ticket: #{$ticket.title} — risk #{$risk_score}"), FSM.stay]
        :_     → :continue
    - Branch.on($ticket.priority)
        :critical → FSM.transition(:in_progress)
        :high     → FSM.transition(:in_progress)
        :_        → FSM.stay
  timeout: 7d → NotifyDev.invoke(:slack, "Ticket aging in backlog: #{$ticket.title}")

### :in_progress
  trigger: Event.eq(:type, :work_started)
  on-enter: CreateBranch.invoke(%{repo: $ticket.repo, base: :main, name: "feat/#{$ticket.id}-#{$ticket.slug}", ticket_id: $ticket.id})
  pipeline:
    - LintCheck.invoke(%{repo: $ticket.repo, branch: $ticket.branch, rules: :default}) → %{errors, warnings}
    - Branch.on(:errors)
        > 0 → [NotifyDev.invoke(:github, "Lint errors on #{$ticket.branch}: #{$errors} errors"), FSM.stay]
        0   → :continue
    - RunTests.invoke(%{repo: $ticket.repo, branch: $ticket.branch, suite: :unit, parallel: true}) → %{passed, failed}
    - Branch.on(:failed)
        > 0 → [NotifyDev.invoke(:slack, "Tests failing on #{$ticket.branch}: #{$failed} failures"), FSM.stay]
        0   → :continue
    - CheckCoverage.invoke(%{repo: $ticket.repo, branch: $ticket.branch, threshold: 0.80}) → %{total, meets_threshold}
    - Branch.on(:meets_threshold)
        true  → FSM.transition(:review)
        false → [NotifyDev.invoke(:github, "Coverage below threshold: #{$total}%"), FSM.stay]
  timeout: 5d → NotifyDev.invoke(:slack, "Ticket stalling in progress: #{$ticket.title}")

### :review
  trigger: Event.eq(:type, :pr_opened)
  on-enter: CreatePR.invoke(%{repo: $ticket.repo, head: $ticket.branch, base: :main, title: $ticket.title, body: $ticket.description, reviewers: $ticket.reviewers, labels: [$ticket.priority, $ticket.type]})
  pipeline:
    - ReviewCode.invoke(%{pr_id: $ticket.pr_id, repo: $ticket.repo, focus: [:security, :correctness, :performance], depth: :thorough}) → %{comments, verdict}
    - Branch.on(:verdict)
        :approve          → FSM.transition(:testing)
        :request_changes  → [NotifyDev.invoke(:github, "Changes requested: #{length($comments)} comments"), FSM.transition(:in_progress)]
        :needs_discussion → [NotifyDev.invoke(:slack, "PR needs team discussion: #{$ticket.title}", :high), FSM.stay]
    - GetPRStatus.invoke(%{pr_id: $ticket.pr_id, repo: $ticket.repo}) → %{approvals, conflicts}
    - Branch.on(:conflicts)
        true  → [NotifyDev.invoke(:github, "Merge conflicts detected"), FSM.transition(:in_progress)]
        false → :continue
    - Branch.on(:approvals)
        >= 2 → FSM.transition(:testing)
        :_   → FSM.stay
  timeout: 3d → NotifyDev.invoke(:slack, "PR awaiting review: #{$ticket.title}", :high)

### :testing
  trigger: Event.eq(:type, :review_approved)
  on-enter: NotifyDev.invoke(:slack, "Running full test suite for #{$ticket.title}")
  pipeline:
    - RunTests.invoke(%{repo: $ticket.repo, branch: $ticket.branch, suite: :all, parallel: true}) → %{passed, failed, duration_ms}
    - Branch.on(:failed)
        > 0 → [NotifyDev.invoke(:slack, "Integration/E2E failures: #{$failed}"), FSM.transition(:in_progress)]
        0   → :continue
    - CheckCoverage.invoke(%{repo: $ticket.repo, branch: $ticket.branch, threshold: 0.80}) → %{total, meets_threshold}
    - AnalyzeCode.invoke(%{repo: $ticket.repo, path: :all, analysis: [:security, :duplication]}) → %{findings}
    - Branch.on(length($findings))
        > 0 → [NotifyDev.invoke(:github, "Security/quality findings: #{length($findings)}"), FSM.stay]
        0   → :continue
    - CheckDependencies.invoke(%{repo: $ticket.repo, scope: :vulnerable}) → %{vulnerabilities}
    - Branch.on(length($vulnerabilities))
        > 0 → [NotifyDev.invoke(:slack, "Vulnerability detected: #{length($vulnerabilities)} issues", :high), FSM.stay]
        0   → FSM.transition(:staging)
  timeout: 1d → NotifyDev.invoke(:slack, "Tests running too long: #{$ticket.title}", :high)

### :staging
  trigger: Event.eq(:type, :tests_passed)
  on-enter: Deploy.invoke(%{repo: $ticket.repo, branch: $ticket.branch, target: :staging, strategy: :rolling})
  pipeline:
    - GetBuildStatus.invoke(%{repo: $ticket.repo, branch: $ticket.branch}) → %{status}
    - Branch.on(:status)
        :passing → :continue
        :failing → [NotifyDev.invoke(:slack, "Staging deploy failed"), RollbackDeploy.invoke(%{deployment_id: $deployment.id, target: :staging}), FSM.transition(:in_progress)]
        :pending → FSM.stay
    - NotifyDev.invoke(:slack, "Staged: #{$ticket.title} — verify at #{$staging_url}")
    - FSM.transition(:deployed)
  timeout: 2d → NotifyDev.invoke(:slack, "Staging verification pending: #{$ticket.title}")

### :deployed
  trigger: Event.eq(:type, :staging_verified)
  pipeline:
    - MergePR.invoke(%{pr_id: $ticket.pr_id, repo: $ticket.repo, strategy: :squash}) → %{merge_sha}
    - Deploy.invoke(%{repo: $ticket.repo, branch: :main, target: :production, strategy: :blue_green}) → %{deployment_id}
    - GetBuildStatus.invoke(%{repo: $ticket.repo, branch: :main}) → %{status}
    - Branch.on(:status)
        :passing → [NotifyDev.invoke(:slack, "DEPLOYED: #{$ticket.title} → production"), FSM.transition(:done)]
        :failing → [RollbackDeploy.invoke(%{deployment_id: $deployment_id, target: :production}), NotifyDev.invoke(:slack, "Production deploy FAILED — rolled back", :critical), FSM.transition(:in_progress)]
        :pending → FSM.stay
  timeout: 1d → NotifyDev.invoke(:slack, "Production deploy pending: #{$ticket.title}", :critical)

### :done
  trigger: Event.eq(:type, :production_verified)
  on-enter: NotifyDev.invoke(:slack, "Ticket complete: #{$ticket.title} #{$merge_sha}")
  terminal: true

### :blocked
  trigger: Event.eq(:type, :ticket_blocked)
  on-enter: NotifyDev.invoke(:slack, "BLOCKED: #{$ticket.title} — #{$block_reason}", :high)
  pipeline:
    - NotifyDev.invoke(:slack, "Blocked ticket needs attention: #{$ticket.title}", :high, $ticket.assignee)
  timeout: 3d → NotifyDev.invoke(:slack, "Still blocked: #{$ticket.title}", :critical)
