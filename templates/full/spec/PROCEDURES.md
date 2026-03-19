# Procedure Registry v1.0

> TODO: Replace this template with your domain-specific procedures.
> Each binding maps a symbolic name to a concrete implementation.

## Action Bindings (Side-Effect Producers)

### ProcessItem → Actions.process_item/2
  @spec process_item(context(), %{item_id: String.t(), type: atom(), payload: map()}) :: {:ok, result_id} | {:error, reason}
  Runtime: TODO — your processing backend
  Timeout: 30s
  Approval: none

### SendNotification → Actions.send_notification/2
  @spec send_notification(context(), %{channel: :slack | :email | :sms, recipient: String.t(), message: String.t(), urgency: :low | :normal | :high}) :: :ok | {:error, reason}
  Runtime: notification hub (hot-swap between Slack, SendGrid, Twilio)
  Timeout: 10s
  Approval: none

### UpdateRecord → Actions.update_record/2
  @spec update_record(context(), %{entity_type: atom(), entity_id: String.t(), fields: map()}) :: :ok | {:error, reason}
  Runtime: TODO — your data store adapter
  Timeout: 10s
  Sandbox: yes
  Approval: none (unless entity_type in [:financial, :compliance] → governance.data_review)

### ExecuteTask → Actions.execute_task/2
  @spec execute_task(context(), %{command: String.t(), args: [String.t()], env: map()}) :: {:ok, output} | {:error, reason}
  Runtime: shell
  Sandbox: yes
  Timeout: 60s
  Approval: governance.execution_review (if command matches /delete|drop|destroy/)

### GenerateOutput → Actions.generate_output/2
  @spec generate_output(context(), %{template: atom(), data: map(), format: :pdf | :html | :markdown | :json}) :: {:ok, %{output_id: String.t(), path: String.t()}} | {:error, reason}
  Runtime: TODO — your document/output generator
  Timeout: 30s
  Approval: none

### TransferItem → Actions.transfer_item/2
  @spec transfer_item(context(), %{item_id: String.t(), from: atom(), to: atom(), metadata: map()}) :: {:ok, transfer_id} | {:error, reason}
  Runtime: TODO — your handoff/transfer system
  Timeout: 15s
  Approval: none


## Query Bindings (Pure Functions)

### AnalyzeInput → Queries.analyze_input/2
  @spec analyze_input(context(), %{input: String.t(), analysis_type: atom()}) :: {:ok, %{classification: atom(), confidence: float(), entities: [map()]}}
  Runtime: TODO — your analysis engine (LLM, rules engine, ML model)
  Cache: TTL 300s, key: {hash(input), analysis_type}

### SearchRecords → Queries.search_records/2
  @spec search_records(context(), %{query: String.t(), scope: atom(), filters: map(), limit: integer()}) :: {:ok, [record()]}
  Runtime: TODO — your search backend (FTS, vector, hybrid)
  Cache: TTL 60s, key: {hash(query), scope, filters}

### GetStatus → Queries.get_status/2
  @spec get_status(context(), %{entity_id: String.t(), include: [atom()]}) :: {:ok, %{status: atom(), history: [event()], metadata: map()}}
  Runtime: TODO — your data store
  Cache: TTL 30s, key: {entity_id, include}

### ScoreItem → Queries.score_item/2
  @spec score_item(context(), %{item: map(), rubric: atom()}) :: {:ok, %{score: float(), breakdown: map(), recommendation: atom()}}
  Runtime: TODO — your scoring engine
  Cache: TTL 120s, key: {hash(item), rubric}

### GenerateReport → Queries.generate_report/2
  @spec generate_report(context(), %{report_type: atom(), date_range: {Date.t(), Date.t()}, filters: map()}) :: {:ok, %{data: map(), summary: String.t(), charts: [chart()]}}
  Runtime: TODO — your analytics/reporting engine
  Cache: TTL 600s, key: {report_type, date_range, filters}

### ValidateInput → Queries.validate_input/2
  @spec validate_input(context(), %{input: map(), schema: atom()}) :: {:ok, %{valid: boolean(), errors: [String.t()]}}
  Runtime: schema validator
  Cache: TTL 0s (no caching — always validate fresh)
