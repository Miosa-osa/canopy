# Procedure Registry v1.0

> Enterprise template — governance-gated actions with audit logging and compliance controls.
> Every action produces an audit trail. Sensitive operations require approval gates.

## Action Bindings (Side-Effect Producers)

### ProcessRequest → Actions.process_request/2
  @spec process_request(context(), %{request_id: String.t(), type: atom(), payload: map(), requester: String.t(), department: atom()}) :: {:ok, result_id} | {:error, reason}
  Runtime: request processing backend
  Timeout: 60s
  Approval: governance.request_review (if type in [:financial, :compliance, :access_change])
  Audit: log({:action, :process_request, requester, department, timestamp})

### ApproveItem → Actions.approve_item/2
  @spec approve_item(context(), %{item_id: String.t(), approver: String.t(), level: :manager | :director | :vp | :c_suite, notes: String.t()}) :: {:ok, approval_id} | {:error, reason}
  Runtime: approval engine
  Timeout: 10s
  Approval: none (approvers are pre-authorized by role)
  Audit: log({:action, :approve, approver, level, item_id, timestamp})

### EscalateItem → Actions.escalate_item/2
  @spec escalate_item(context(), %{item_id: String.t(), from_level: atom(), to_level: atom(), reason: String.t(), urgency: :normal | :urgent | :critical}) :: {:ok, escalation_id} | {:error, reason}
  Runtime: escalation engine
  Timeout: 10s
  Approval: none
  Audit: log({:action, :escalate, from_level, to_level, reason, timestamp})

### UpdateRecord → Actions.update_record/2
  @spec update_record(context(), %{entity_type: atom(), entity_id: String.t(), fields: map(), change_reason: String.t()}) :: :ok | {:error, reason}
  Runtime: data store adapter
  Timeout: 10s
  Sandbox: yes (field whitelist enforced per entity_type and department)
  Approval: governance.data_change_review (if entity_type in [:financial, :pii, :contract])
  Audit: log({:action, :update_record, entity_type, entity_id, fields_changed, timestamp})

### SendCommunication → Actions.send_communication/2
  @spec send_communication(context(), %{channel: :email | :slack | :teams | :sms, recipients: [String.t()], subject: String.t(), body: String.t(), classification: :public | :internal | :confidential | :restricted}) :: {:ok, message_id} | {:error, reason}
  Runtime: communication hub (hot-swap per channel)
  Timeout: 15s
  Approval: governance.communication_review (if classification in [:confidential, :restricted] or length(recipients) > 50)
  Audit: log({:action, :send_communication, channel, classification, recipient_count, timestamp})

### DeployChange → Actions.deploy_change/2
  @spec deploy_change(context(), %{change_id: String.t(), target: :dev | :staging | :production, approved_by: [String.t()], rollback_plan: String.t()}) :: {:ok, deployment_id} | {:error, reason}
  Runtime: deployment provider
  Timeout: 300s
  Approval: governance.change_advisory_board (if target == :production)
  Audit: log({:action, :deploy, target, change_id, approved_by, timestamp})

### GenerateReport → Actions.generate_report/2
  @spec generate_report(context(), %{report_type: atom(), period: {Date.t(), Date.t()}, department: atom(), classification: atom()}) :: {:ok, %{report_id: String.t(), path: String.t()}} | {:error, reason}
  Runtime: reporting engine
  Timeout: 120s
  Approval: none (reports are read-only)
  Audit: log({:action, :generate_report, report_type, department, classification, timestamp})


## Query Bindings (Pure Functions)

### CheckCompliance → Queries.check_compliance/2
  @spec check_compliance(context(), %{entity_id: String.t(), framework: :soc2 | :gdpr | :hipaa | :iso27001 | :pci, scope: atom()}) :: {:ok, %{compliant: boolean(), findings: [finding()], risk_level: :low | :medium | :high | :critical, remediation: [action()]}}
  Runtime: compliance engine
  Cache: TTL 3600s, key: {entity_id, framework, scope}
  Audit: log({:query, :check_compliance, framework, entity_id, timestamp})

### AuditTrail → Queries.audit_trail/2
  @spec audit_trail(context(), %{entity_id: String.t() | nil, actor: String.t() | nil, action_type: atom() | nil, date_range: {Date.t(), Date.t()}, limit: integer()}) :: {:ok, %{entries: [audit_entry()], total: integer()}}
  Runtime: audit store
  Cache: TTL 0s (audit queries always fresh)

### AssessRisk → Queries.assess_risk/2
  @spec assess_risk(context(), %{entity: map(), risk_model: atom(), context: map()}) :: {:ok, %{risk_score: float(), risk_level: atom(), factors: [factor()], mitigation: [String.t()]}}
  Runtime: risk assessment engine
  Cache: TTL 600s, key: {hash(entity), risk_model}

### CheckApprovalStatus → Queries.check_approval_status/2
  @spec check_approval_status(context(), %{item_id: String.t(), required_levels: [atom()]}) :: {:ok, %{approved: boolean(), pending_levels: [atom()], approvals: [approval()], expires_at: DateTime.t() | nil}}
  Runtime: approval engine
  Cache: TTL 30s, key: {item_id}

### GetCapacity → Queries.get_capacity/2
  @spec get_capacity(context(), %{department: atom(), resource_type: atom(), period: {Date.t(), Date.t()}}) :: {:ok, %{available: float(), allocated: float(), utilization: float(), bottlenecks: [String.t()]}}
  Runtime: resource management system
  Cache: TTL 300s, key: {department, resource_type, period}

### ValidatePolicy → Queries.validate_policy/2
  @spec validate_policy(context(), %{action: atom(), actor: String.t(), resource: map(), policy_set: atom()}) :: {:ok, %{allowed: boolean(), matching_policies: [policy()], deny_reasons: [String.t()]}}
  Runtime: policy engine (OPA, Cedar, custom)
  Cache: TTL 60s, key: {action, actor, hash(resource), policy_set}
