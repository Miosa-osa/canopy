# Main Pipeline FSM

> TODO: Replace state names, triggers, and pipelines with your domain logic.
> This template shows the structural pattern — customize every state.

## Meta
  type: :todo_your_type
  entry_state: :intake
  entity: :item
  version: 1.0

## States

### :intake
  trigger: Event.eq(:type, :item_received)
  on-enter: SendNotification.invoke(:slack, "New item: #{$item.title}")
  pipeline:
    - ValidateInput.invoke(%{input: $item, schema: :intake_schema}) → %{valid, errors}
    - Branch.on(:valid)
        true  → :continue
        false → [SendNotification.invoke(:slack, "Invalid item: #{$errors}"), FSM.transition(:rejected)]
    - AnalyzeInput.invoke(%{input: $item.content, analysis_type: :classification}) → %{classification, confidence}
    - ScoreItem.invoke(%{item: $item, rubric: :priority}) → %{score, recommendation}
    - Branch.on(:recommendation)
        :fast_track → FSM.transition(:processing)
        :standard   → FSM.transition(:queued)
        :review     → FSM.transition(:manual_review)
  timeout: 24h → SendNotification.invoke(:slack, "Item stuck in intake: #{$item.title}")

### :queued
  trigger: Event.eq(:type, :item_queued)
  pipeline:
    - SearchRecords.invoke(%{query: $item.title, scope: :existing, filters: %{}, limit: 5}) → %{results}
    - Branch.on(length($results))
        > 0 → [SendNotification.invoke(:slack, "Possible duplicate: #{$item.title}"), FSM.transition(:manual_review)]
        0   → FSM.transition(:processing)
  timeout: 48h → SendNotification.invoke(:slack, "Item aging in queue: #{$item.title}")

### :processing
  trigger: Event.eq(:type, :processing_started)
  on-enter: UpdateRecord.invoke(%{entity_type: :item, entity_id: $item.id, fields: %{status: :processing, started_at: DateTime.utc_now()}})
  pipeline:
    - ProcessItem.invoke(%{item_id: $item.id, type: $item.classification, payload: $item.data}) → %{result_id}
    - GetStatus.invoke(%{entity_id: $result_id, include: [:metadata]}) → %{status}
    - Branch.on(:status)
        :success → FSM.transition(:review)
        :partial → [SendNotification.invoke(:slack, "Partial result: #{$item.title}"), FSM.stay]
        :failed  → [SendNotification.invoke(:slack, "Processing failed: #{$item.title}", :high), FSM.transition(:manual_review)]
  timeout: 4h → SendNotification.invoke(:slack, "Processing taking too long: #{$item.title}", :high)

### :review
  trigger: Event.eq(:type, :processing_complete)
  on-enter: SendNotification.invoke(:slack, "Ready for review: #{$item.title}", :normal, $item.reviewers)
  pipeline:
    - ScoreItem.invoke(%{item: $item, rubric: :quality}) → %{score, breakdown}
    - Branch.on(:score)
        >= 0.9 → FSM.transition(:output)
        >= 0.6 → [SendNotification.invoke(:slack, "Review needed — quality: #{$score}"), FSM.stay]
        :_     → [SendNotification.invoke(:slack, "Quality too low: #{$score} — reprocessing"), FSM.transition(:processing)]
    - Branch.on($item.review_decision)
        :approved → FSM.transition(:output)
        :rejected → FSM.transition(:processing)
        :pending  → FSM.stay
  timeout: 3d → SendNotification.invoke(:slack, "Review pending: #{$item.title}", :high)

### :output
  trigger: Event.eq(:type, :review_approved)
  pipeline:
    - GenerateOutput.invoke(%{template: $item.output_template, data: $item.result, format: $item.output_format}) → %{output_id, path}
    - UpdateRecord.invoke(%{entity_type: :item, entity_id: $item.id, fields: %{status: :complete, output_path: $path}})
    - SendNotification.invoke(:slack, "Complete: #{$item.title} — output at #{$path}")
    - FSM.transition(:done)
  timeout: 1d → SendNotification.invoke(:slack, "Output generation stalled: #{$item.title}", :high)

### :done
  trigger: Event.eq(:type, :output_delivered)
  on-enter: UpdateRecord.invoke(%{entity_type: :item, entity_id: $item.id, fields: %{status: :done, completed_at: DateTime.utc_now()}})
  terminal: true

### :manual_review
  trigger: Event.eq(:type, :manual_review_required)
  on-enter: SendNotification.invoke(:slack, "MANUAL REVIEW: #{$item.title}", :high, $item.reviewers)
  pipeline:
    - Branch.on($item.manual_decision)
        :approve   → FSM.transition(:processing)
        :reject    → FSM.transition(:rejected)
        :escalate  → [SendNotification.invoke(:email, "Escalation: #{$item.title}", :high), FSM.stay]
        :pending   → FSM.stay
  timeout: 5d → SendNotification.invoke(:slack, "Manual review overdue: #{$item.title}", :high)

### :rejected
  trigger: Event.eq(:type, :item_rejected)
  on-enter: SendNotification.invoke(:slack, "Rejected: #{$item.title} — #{$item.reject_reason}")
  pipeline:
    - UpdateRecord.invoke(%{entity_type: :item, entity_id: $item.id, fields: %{status: :rejected, reason: $item.reject_reason}})
  terminal: true
