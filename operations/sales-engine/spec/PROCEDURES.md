# Procedure Registry v1.0

> Sales Engine — action and query bindings for outbound/inbound sales operations.

## Action Bindings (Side-Effect Producers)

### SendOutreach → Actions.send_outreach/2
  @spec send_outreach(context(), %{lead_id: String.t(), channel: :email | :linkedin | :sms, template: atom(), personalization: map()}) :: {:ok, outreach_id} | {:error, reason}
  Runtime: outreach provider (hot-swap between Instantly, Lemlist, Apollo)
  Timeout: 15s
  Approval: none (unless daily_count > 200 → governance.bulk_outreach_review)

### ScheduleCall → Actions.schedule_call/2
  @spec schedule_call(context(), %{lead_id: String.t(), owner_id: String.t(), duration: integer(), type: :discovery | :demo | :close}) :: {:ok, event_id} | {:error, reason}
  Runtime: calendar provider (hot-swap between Calendly, Cal.com, Google)
  Timeout: 10s
  Approval: none

### UpdateCRM → Actions.update_crm/2
  @spec update_crm(context(), %{entity_type: :lead | :deal | :contact, entity_id: String.t(), fields: map()}) :: :ok | {:error, reason}
  Runtime: CRM adapter (hot-swap between HubSpot, Salesforce, Close)
  Timeout: 10s
  Sandbox: yes (field whitelist enforced per entity_type)
  Approval: none (unless entity_type == :deal and fields.stage == :closed_won → governance.deal_close_review)

### ScoreLead → Actions.score_lead/2
  @spec score_lead(context(), %{lead_id: String.t(), signals: [map()], model: atom()}) :: {:ok, %{score: float(), tier: :hot | :warm | :cold, factors: [String.t()]}}
  Runtime: scoring engine
  Timeout: 5s
  Approval: none

### SendProposal → Actions.send_proposal/2
  @spec send_proposal(context(), %{deal_id: String.t(), template: atom(), pricing: map(), expiry_days: integer()}) :: {:ok, proposal_id} | {:error, reason}
  Runtime: document provider (hot-swap between PandaDoc, Proposify, custom)
  Timeout: 20s
  Approval: governance.proposal_review (if pricing.total > 10_000)

### NotifySales → Actions.notify_sales/2
  @spec notify_sales(context(), %{channel: :slack | :email | :sms, message: String.t(), urgency: :low | :normal | :high | :critical, mention: [String.t()]}) :: :ok
  Runtime: notification hub
  Timeout: 10s
  Approval: none

### CreateDeal → Actions.create_deal/2
  @spec create_deal(context(), %{lead_id: String.t(), pipeline: atom(), value: float(), owner_id: String.t()}) :: {:ok, deal_id} | {:error, reason}
  Runtime: CRM adapter
  Timeout: 10s
  Approval: none


## Query Bindings (Pure Functions)

### AnalyzeLead → Queries.analyze_lead/2
  @spec analyze_lead(context(), %{lead_id: String.t(), depth: :shallow | :deep}) :: {:ok, %{firmographics: map(), technographics: map(), intent_signals: [map()], icp_fit: float()}}
  Runtime: enrichment provider (Clearbit, Apollo, ZoomInfo)
  Cache: TTL 3600s, key: {lead_id, depth}

### CheckPipeline → Queries.check_pipeline/2
  @spec check_pipeline(context(), %{owner_id: String.t() | :all, stage_filter: [atom()] | :all, date_range: {Date.t(), Date.t()}}) :: {:ok, %{deals: [deal()], total_value: float(), weighted_value: float(), stage_distribution: map()}}
  Runtime: CRM adapter
  Cache: TTL 60s, key: {owner_id, stage_filter, date_range}

### ForecastRevenue → Queries.forecast_revenue/2
  @spec forecast_revenue(context(), %{period: :monthly | :quarterly, pipeline_id: atom(), model: :weighted | :historical | :ai}) :: {:ok, %{forecast: float(), confidence: float(), breakdown: map(), risk_factors: [String.t()]}}
  Runtime: analytics engine
  Cache: TTL 300s, key: {period, pipeline_id, model}

### LookupContact → Queries.lookup_contact/2
  @spec lookup_contact(context(), %{query: String.t(), match_on: :email | :name | :company | :phone}) :: {:ok, [contact()]} | {:ok, []}
  Runtime: CRM adapter
  Cache: TTL 120s, key: {hash(query), match_on}

### GetDealHistory → Queries.get_deal_history/2
  @spec get_deal_history(context(), %{deal_id: String.t(), include: [:notes | :emails | :calls | :stage_changes]}) :: {:ok, %{timeline: [event()], days_in_pipeline: integer(), stall_count: integer()}}
  Runtime: CRM adapter
  Cache: TTL 30s, key: {deal_id, include}

### ScoreEngagement → Queries.score_engagement/2
  @spec score_engagement(context(), %{lead_id: String.t(), window_days: integer()}) :: {:ok, %{score: float(), opens: integer(), clicks: integer(), replies: integer(), meetings: integer()}}
  Runtime: outreach provider + CRM adapter
  Cache: TTL 120s, key: {lead_id, window_days}
