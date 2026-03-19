# Sales Pipeline FSM

## Meta
  type: :sales_pipeline
  entry_state: :prospecting
  entity: :deal
  version: 1.0

## States

### :prospecting
  trigger: Event.eq(:type, :new_lead)
  on-enter: NotifySales.invoke(owner, "New lead: #{$lead.company} — #{$lead.source}")
  pipeline:
    - LookupContact.invoke(%{query: $lead.email, match_on: :email}) → %{existing}
    - Branch.on(:existing)
        present → FSM.transition(:dedup_review)
        absent  → :continue
    - AnalyzeLead.invoke(%{lead_id: $lead.id, depth: :shallow}) → %{icp_fit, firmographics}
    - ScoreLead.invoke(%{lead_id: $lead.id, signals: $lead.signals, model: :icp_v2}) → %{score, tier}
    - Branch.on(:tier)
        :hot  → [NotifySales.invoke(sales_team, "Hot lead: #{$lead.company} (#{$score})"), CreateDeal.invoke(%{lead_id: $lead.id, pipeline: :main, value: $firmographics.estimated_value, owner_id: :auto_assign}), FSM.transition(:qualifying)]
        :warm → [CreateDeal.invoke(%{lead_id: $lead.id, pipeline: :main, value: 0, owner_id: :auto_assign}), FSM.transition(:nurturing)]
        :cold → FSM.transition(:cold_storage)
  timeout: 48h → FSM.transition(:cold_storage)

### :qualifying
  trigger: Event.eq(:type, :qualification_started)
  on-enter: UpdateCRM.invoke(%{entity_type: :deal, entity_id: $deal.id, fields: %{stage: :qualifying, qualified_at: DateTime.utc_now()}})
  pipeline:
    - AnalyzeLead.invoke(%{lead_id: $deal.lead_id, depth: :deep}) → %{firmographics, technographics, intent_signals}
    - ScoreLead.invoke(%{lead_id: $deal.lead_id, signals: $intent_signals, model: :meddpicc}) → %{score, factors}
    - Branch.on(:score)
        >= 0.7 → [ScheduleCall.invoke(%{lead_id: $deal.lead_id, owner_id: $deal.owner_id, duration: 30, type: :discovery}), FSM.transition(:discovery)]
        >= 0.4 → [NotifySales.invoke(owner, "Qualification gaps: #{$factors}"), FSM.transition(:nurturing)]
        :_     → FSM.transition(:cold_storage)
  timeout: 5d → NotifySales.invoke(owner, "Deal stalling in qualification: #{$deal.company}")

### :discovery
  trigger: Event.eq(:type, :discovery_call_complete)
  pipeline:
    - AnalyzeLead.invoke(%{lead_id: $deal.lead_id, depth: :deep}) → %{icp_fit, intent_signals}
    - ScoreLead.invoke(%{lead_id: $deal.lead_id, signals: $intent_signals, model: :meddpicc}) → %{score, factors}
    - UpdateCRM.invoke(%{entity_type: :deal, entity_id: $deal.id, fields: %{discovery_score: $score, pain_points: $factors}})
    - Branch.on(:score)
        >= 0.8 → FSM.transition(:proposal)
        >= 0.5 → [NotifySales.invoke(owner, "Re-engage on: #{$factors}"), ScheduleCall.invoke(%{lead_id: $deal.lead_id, owner_id: $deal.owner_id, duration: 30, type: :discovery}), FSM.stay]
        :_     → FSM.transition(:nurturing)
  timeout: 10d → FSM.transition(:nurturing)

### :proposal
  trigger: Event.eq(:type, :proposal_requested)
  on-enter: NotifySales.invoke(owner, "Preparing proposal for #{$deal.company}")
  pipeline:
    - GetDealHistory.invoke(%{deal_id: $deal.id, include: [:notes, :calls]}) → %{timeline}
    - ForecastRevenue.invoke(%{period: :quarterly, pipeline_id: :main, model: :weighted}) → %{forecast}
    - SendProposal.invoke(%{deal_id: $deal.id, template: :standard, pricing: $deal.pricing, expiry_days: 14}) → %{proposal_id}
    - UpdateCRM.invoke(%{entity_type: :deal, entity_id: $deal.id, fields: %{stage: :proposal, proposal_id: $proposal_id, proposal_sent_at: DateTime.utc_now()}})
    - NotifySales.invoke(owner, "Proposal sent: #{$proposal_id}")
    - FSM.transition(:negotiation)
  timeout: 7d → NotifySales.invoke(owner, "Proposal not yet sent for #{$deal.company}")

### :negotiation
  trigger: Event.eq(:type, :negotiation_started)
  on-enter: UpdateCRM.invoke(%{entity_type: :deal, entity_id: $deal.id, fields: %{stage: :negotiation}})
  pipeline:
    - ScoreEngagement.invoke(%{lead_id: $deal.lead_id, window_days: 7}) → %{score, replies}
    - Branch.on(:replies)
        >= 1 → :continue
        0    → [SendOutreach.invoke(%{lead_id: $deal.lead_id, channel: :email, template: :followup_negotiation, personalization: %{deal: $deal}}), FSM.stay]
    - Branch.on(:score)
        >= 0.7 → FSM.transition(:closing)
        :_     → [NotifySales.invoke(owner, "Engagement dropping on #{$deal.company}"), FSM.stay]
  timeout: 21d → FSM.transition(:closed_lost)

### :closing
  trigger: Event.eq(:type, :verbal_commit)
  on-enter: NotifySales.invoke(owner, "Verbal commit from #{$deal.company} — prepare contract")
  pipeline:
    - UpdateCRM.invoke(%{entity_type: :deal, entity_id: $deal.id, fields: %{stage: :closing}})
    - NotifySales.invoke(:finance, "Expected close: #{$deal.company} — $#{$deal.value}")
    - FSM.transition(:closed_won)
  timeout: 14d → [NotifySales.invoke(owner, "Close stalling: #{$deal.company}"), FSM.transition(:negotiation)]

### :closed_won
  trigger: Event.eq(:type, :contract_signed)
  on-enter: NotifySales.invoke(:team, "CLOSED WON: #{$deal.company} — $#{$deal.value}")
  pipeline:
    - UpdateCRM.invoke(%{entity_type: :deal, entity_id: $deal.id, fields: %{stage: :closed_won, closed_at: DateTime.utc_now()}})
  terminal: true

### :closed_lost
  trigger: Event.eq(:type, :deal_lost)
  on-enter: NotifySales.invoke(owner, "Deal lost: #{$deal.company}. Reason: #{$reason}")
  pipeline:
    - UpdateCRM.invoke(%{entity_type: :deal, entity_id: $deal.id, fields: %{stage: :closed_lost, lost_reason: $reason, closed_at: DateTime.utc_now()}})
  terminal: true

### :nurturing
  trigger: Event.eq(:type, :moved_to_nurture)
  on-enter: UpdateCRM.invoke(%{entity_type: :deal, entity_id: $deal.id, fields: %{stage: :nurturing}})
  pipeline:
    - SendOutreach.invoke(%{lead_id: $deal.lead_id, channel: :email, template: :nurture_sequence, personalization: %{deal: $deal}})
    - ScoreEngagement.invoke(%{lead_id: $deal.lead_id, window_days: 30}) → %{score}
    - Branch.on(:score)
        >= 0.5 → FSM.transition(:qualifying)
        :_     → FSM.stay
  timeout: 60d → FSM.transition(:cold_storage)

### :cold_storage
  terminal: true
  on-enter: UpdateCRM.invoke(%{entity_type: :deal, entity_id: $deal.id, fields: %{stage: :archived, archived_at: DateTime.utc_now()}})

### :dedup_review
  trigger: Event.eq(:type, :duplicate_detected)
  pipeline:
    - GetDealHistory.invoke(%{deal_id: $existing.deal_id, include: [:stage_changes]}) → %{timeline}
    - NotifySales.invoke(owner, "Duplicate lead: #{$lead.company} — existing deal #{$existing.deal_id}")
  terminal: true
