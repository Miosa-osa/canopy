# Enterprise Request Pipeline FSM

> Multi-level approval gates, escalation paths, and compliance checkpoints.
> Every state transition is audited. Sensitive operations require tiered approval.

## Meta
  type: :enterprise_request
  entry_state: :submitted
  entity: :request
  version: 1.0

## States

### :submitted
  trigger: Event.eq(:type, :request_submitted)
  on-enter: SendCommunication.invoke(%{channel: :slack, recipients: [$request.owner], subject: "Request received", body: "#{$request.title} — ID: #{$request.id}", classification: :internal})
  pipeline:
    - ValidatePolicy.invoke(%{action: $request.type, actor: $request.requester, resource: $request, policy_set: :request_policies}) → %{allowed, deny_reasons}
    - Branch.on(:allowed)
        false → [SendCommunication.invoke(%{channel: :email, recipients: [$request.requester], subject: "Request denied", body: "Policy violation: #{$deny_reasons}", classification: :internal}), FSM.transition(:rejected)]
        true  → :continue
    - CheckCompliance.invoke(%{entity_id: $request.id, framework: $request.compliance_framework, scope: $request.type}) → %{compliant, findings, risk_level}
    - Branch.on(:compliant)
        false → [SendCommunication.invoke(%{channel: :email, recipients: [$request.requester], subject: "Compliance issue", body: "Findings: #{$findings}", classification: :confidential}), FSM.transition(:compliance_review)]
        true  → :continue
    - AssessRisk.invoke(%{entity: $request, risk_model: :standard, context: %{department: $request.department}}) → %{risk_score, risk_level}
    - Branch.on(:risk_level)
        :critical → FSM.transition(:executive_review)
        :high     → FSM.transition(:director_approval)
        :medium   → FSM.transition(:manager_approval)
        :low      → FSM.transition(:processing)
  timeout: 24h → SendCommunication.invoke(%{channel: :slack, recipients: [$request.owner], subject: "Intake stalled", body: "#{$request.title}", classification: :internal})

### :manager_approval
  trigger: Event.eq(:type, :manager_review_required)
  on-enter: SendCommunication.invoke(%{channel: :email, recipients: [$request.manager], subject: "Approval needed: #{$request.title}", body: "Risk: #{$request.risk_level}. Review at #{$request.url}", classification: :internal})
  pipeline:
    - CheckApprovalStatus.invoke(%{item_id: $request.id, required_levels: [:manager]}) → %{approved, pending_levels}
    - Branch.on(:approved)
        true  → FSM.transition(:processing)
        false → FSM.stay
  timeout: 3d → [EscalateItem.invoke(%{item_id: $request.id, from_level: :manager, to_level: :director, reason: "Manager approval timeout", urgency: :urgent}), FSM.transition(:director_approval)]

### :director_approval
  trigger: Event.eq(:type, :director_review_required)
  on-enter: SendCommunication.invoke(%{channel: :email, recipients: [$request.director], subject: "Director approval: #{$request.title}", body: "Escalated or high-risk. Risk: #{$request.risk_level}", classification: :internal})
  pipeline:
    - CheckApprovalStatus.invoke(%{item_id: $request.id, required_levels: [:manager, :director]}) → %{approved, pending_levels}
    - Branch.on(:approved)
        true  → FSM.transition(:processing)
        false → FSM.stay
  timeout: 5d → [EscalateItem.invoke(%{item_id: $request.id, from_level: :director, to_level: :vp, reason: "Director approval timeout", urgency: :critical}), FSM.transition(:executive_review)]

### :executive_review
  trigger: Event.eq(:type, :executive_review_required)
  on-enter: SendCommunication.invoke(%{channel: :email, recipients: [$request.vp, $request.ciso], subject: "EXECUTIVE REVIEW: #{$request.title}", body: "Critical risk. Requires executive sign-off.", classification: :confidential})
  pipeline:
    - CheckApprovalStatus.invoke(%{item_id: $request.id, required_levels: [:manager, :director, :vp]}) → %{approved, pending_levels}
    - Branch.on(:approved)
        true  → FSM.transition(:processing)
        false → FSM.stay
    - AuditTrail.invoke(%{entity_id: $request.id, actor: nil, action_type: nil, date_range: {$request.submitted_at, DateTime.utc_now()}, limit: 50}) → %{entries}
    - SendCommunication.invoke(%{channel: :email, recipients: [$request.vp], subject: "Audit trail: #{$request.title}", body: "#{length($entries)} events logged", classification: :restricted})
  timeout: 7d → [SendCommunication.invoke(%{channel: :sms, recipients: [$request.vp], subject: "OVERDUE", body: "Executive review overdue: #{$request.title}", classification: :restricted}), FSM.stay]

### :compliance_review
  trigger: Event.eq(:type, :compliance_review_required)
  on-enter: SendCommunication.invoke(%{channel: :email, recipients: [$request.compliance_officer], subject: "Compliance review: #{$request.title}", body: "Framework: #{$request.compliance_framework}", classification: :confidential})
  pipeline:
    - CheckCompliance.invoke(%{entity_id: $request.id, framework: $request.compliance_framework, scope: :full}) → %{compliant, findings, remediation}
    - Branch.on(:compliant)
        true  → [SendCommunication.invoke(%{channel: :slack, recipients: [$request.owner], subject: "Compliance cleared", body: "#{$request.title}", classification: :internal}), FSM.transition(:submitted)]
        false → [SendCommunication.invoke(%{channel: :email, recipients: [$request.requester], subject: "Remediation required", body: "#{$remediation}", classification: :confidential}), FSM.stay]
  timeout: 10d → EscalateItem.invoke(%{item_id: $request.id, from_level: :compliance, to_level: :c_suite, reason: "Compliance review timeout", urgency: :critical})

### :processing
  trigger: Event.eq(:type, :processing_started)
  on-enter: UpdateRecord.invoke(%{entity_type: :request, entity_id: $request.id, fields: %{status: :processing, started_at: DateTime.utc_now()}, change_reason: "Approved — processing started"})
  pipeline:
    - ProcessRequest.invoke(%{request_id: $request.id, type: $request.type, payload: $request.data, requester: $request.requester, department: $request.department}) → %{result_id}
    - Branch.on(:result_id)
        nil → [SendCommunication.invoke(%{channel: :slack, recipients: [$request.owner], subject: "Processing failed", body: "#{$request.title}", classification: :internal}), FSM.transition(:failed)]
        :_  → :continue
    - UpdateRecord.invoke(%{entity_type: :request, entity_id: $request.id, fields: %{result_id: $result_id, status: :review}, change_reason: "Processing complete"})
    - FSM.transition(:verification)
  timeout: 4h → [EscalateItem.invoke(%{item_id: $request.id, from_level: :system, to_level: :manager, reason: "Processing timeout", urgency: :urgent}), FSM.stay]

### :verification
  trigger: Event.eq(:type, :processing_complete)
  pipeline:
    - CheckCompliance.invoke(%{entity_id: $request.id, framework: $request.compliance_framework, scope: :output}) → %{compliant, findings}
    - Branch.on(:compliant)
        false → [SendCommunication.invoke(%{channel: :email, recipients: [$request.compliance_officer], subject: "Output compliance failure", body: "#{$findings}", classification: :confidential}), FSM.transition(:compliance_review)]
        true  → :continue
    - AuditTrail.invoke(%{entity_id: $request.id, actor: nil, action_type: nil, date_range: {$request.submitted_at, DateTime.utc_now()}, limit: 100}) → %{entries}
    - GenerateReport.invoke(%{report_type: :request_summary, period: {$request.submitted_at, DateTime.utc_now()}, department: $request.department, classification: :internal}) → %{report_id, path}
    - SendCommunication.invoke(%{channel: :email, recipients: [$request.requester], subject: "Request complete: #{$request.title}", body: "Report: #{$path}", classification: :internal})
    - FSM.transition(:completed)
  timeout: 2d → SendCommunication.invoke(%{channel: :slack, recipients: [$request.owner], subject: "Verification stalled", body: "#{$request.title}", classification: :internal})

### :completed
  trigger: Event.eq(:type, :verification_passed)
  on-enter: UpdateRecord.invoke(%{entity_type: :request, entity_id: $request.id, fields: %{status: :completed, completed_at: DateTime.utc_now()}, change_reason: "Request fulfilled"})
  terminal: true

### :rejected
  trigger: Event.eq(:type, :request_rejected)
  on-enter: UpdateRecord.invoke(%{entity_type: :request, entity_id: $request.id, fields: %{status: :rejected, rejected_at: DateTime.utc_now()}, change_reason: $request.reject_reason})
  terminal: true

### :failed
  trigger: Event.eq(:type, :processing_failed)
  on-enter: SendCommunication.invoke(%{channel: :slack, recipients: [$request.owner, $request.manager], subject: "Request FAILED: #{$request.title}", body: "Manual intervention required", classification: :internal})
  pipeline:
    - EscalateItem.invoke(%{item_id: $request.id, from_level: :system, to_level: :manager, reason: "Processing failure", urgency: :critical})
  timeout: 3d → FSM.transition(:rejected)
