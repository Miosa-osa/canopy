# Content Pipeline FSM

## Meta
  type: :content_pipeline
  entry_state: :ideation
  entity: :content_piece
  version: 1.0

## States

### :ideation
  trigger: Event.eq(:type, :content_idea_submitted)
  on-enter: NotifyContent.invoke(:slack, "New content idea: #{$content.title}")
  pipeline:
    - AnalyzeTrend.invoke(%{topic: $content.topic, platforms: $content.target_platforms, window_days: 14}) → %{trending_score, related_topics}
    - Branch.on(:trending_score)
        >= 0.7 → [NotifyContent.invoke(:slack, "Trending topic: #{$content.topic} (#{$trending_score})"), :continue]
        :_     → :continue
    - GetContentCalendar.invoke(%{date_range: {Date.utc_today(), Date.add(Date.utc_today(), 14)}, platform: :all, status: :all}) → %{gaps, conflicts}
    - Branch.on(length($conflicts))
        > 0 → [NotifyContent.invoke(:slack, "Calendar conflict: #{$content.title} overlaps with #{hd($conflicts).title}"), FSM.stay]
        0   → :continue
    - AnalyzeCompetitor.invoke(%{competitor: $content.competitor_ref, platform: hd($content.target_platforms), window_days: 30}) → %{content_themes}
    - FSM.transition(:drafting)
  timeout: 3d → NotifyContent.invoke(:slack, "Idea aging: #{$content.title} — decide or archive")

### :drafting
  trigger: Event.eq(:type, :drafting_started)
  on-enter: NotifyContent.invoke(:slack, "Drafting: #{$content.title} [#{$content.format}]")
  pipeline:
    - Draft.invoke(%{topic: $content.topic, format: $content.format, tone: $content.tone, target_words: $content.target_words, outline: $content.outline}) → %{draft_id, content, word_count}
    - CheckBrandVoice.invoke(%{content: $content, brand_profile: $content.brand}) → %{alignment_score, vocabulary_flags}
    - Branch.on(:alignment_score)
        >= 0.8 → FSM.transition(:editing)
        >= 0.5 → [Edit.invoke(%{draft_id: $draft_id, pass: :brand_voice, instructions: "Fix brand voice: #{$vocabulary_flags}"}), FSM.transition(:editing)]
        :_     → [NotifyContent.invoke(:slack, "Draft far off brand: #{$content.title} — manual review needed"), FSM.stay]
  timeout: 5d → NotifyContent.invoke(:slack, "Draft overdue: #{$content.title}")

### :editing
  trigger: Event.eq(:type, :draft_complete)
  pipeline:
    - Edit.invoke(%{draft_id: $content.draft_id, pass: :structural, instructions: nil}) → %{changes}
    - Edit.invoke(%{draft_id: $content.draft_id, pass: :line, instructions: nil}) → %{changes}
    - Edit.invoke(%{draft_id: $content.draft_id, pass: :copy, instructions: nil}) → %{changes}
    - CheckBrandVoice.invoke(%{content: $content.latest_draft, brand_profile: $content.brand}) → %{alignment_score, suggestions}
    - Branch.on(:alignment_score)
        >= 0.85 → FSM.transition(:approval)
        :_      → [Edit.invoke(%{draft_id: $content.draft_id, pass: :brand_voice, instructions: $suggestions}), FSM.stay]
  timeout: 3d → NotifyContent.invoke(:slack, "Editing stalled: #{$content.title}")

### :approval
  trigger: Event.eq(:type, :editing_complete)
  on-enter: NotifyContent.invoke(:slack, "Ready for approval: #{$content.title}", :high, $content.approvers)
  pipeline:
    - CheckBrandVoice.invoke(%{content: $content.latest_draft, brand_profile: $content.brand}) → %{alignment_score}
    - Branch.on($content.approval_status)
        :approved → FSM.transition(:published)
        :rejected → [NotifyContent.invoke(:slack, "Revisions needed: #{$content.title}"), FSM.transition(:editing)]
        :pending  → FSM.stay
  timeout: 2d → NotifyContent.invoke(:slack, "Approval pending: #{$content.title}", :high, $content.approvers)

### :published
  trigger: Event.eq(:type, :content_approved)
  on-enter: NotifyContent.invoke(:slack, "Publishing: #{$content.title}")
  pipeline:
    - Branch.on($content.publish_mode)
        :immediate → Publish.invoke(%{content_id: $content.id, platform: hd($content.target_platforms), metadata: $content.metadata})
        :scheduled → Schedule.invoke(%{content_id: $content.id, platform: hd($content.target_platforms), publish_at: $content.scheduled_at, timezone: $content.timezone})
    - Branch.on(length($content.target_platforms))
        > 1 → FSM.transition(:repurposing)
        1   → FSM.transition(:monitoring)
  timeout: 1d → NotifyContent.invoke(:slack, "Publish failed or pending: #{$content.title}", :high)

### :repurposing
  trigger: Event.eq(:type, :primary_published)
  on-enter: NotifyContent.invoke(:slack, "Repurposing #{$content.title} to #{length($content.remaining_platforms)} platforms")
  pipeline:
    - Repurpose.invoke(%{source_id: $content.id, target_format: $content.next_format, platform: hd($content.remaining_platforms)}) → %{draft_id, content}
    - CheckBrandVoice.invoke(%{content: $content, brand_profile: $content.brand}) → %{alignment_score}
    - Branch.on(:alignment_score)
        >= 0.8 → Publish.invoke(%{content_id: $draft_id, platform: hd($content.remaining_platforms), metadata: $content.metadata})
        :_     → [Edit.invoke(%{draft_id: $draft_id, pass: :brand_voice, instructions: nil}), Publish.invoke(%{content_id: $draft_id, platform: hd($content.remaining_platforms), metadata: $content.metadata})]
    - Branch.on(length($content.remaining_platforms))
        > 1 → FSM.stay
        1   → FSM.transition(:monitoring)
  timeout: 7d → NotifyContent.invoke(:slack, "Repurposing incomplete: #{$content.title}")

### :monitoring
  trigger: Event.eq(:type, :all_platforms_published)
  on-enter: NotifyContent.invoke(:slack, "Monitoring: #{$content.title} — tracking engagement")
  pipeline:
    - ScoreEngagement.invoke(%{content_id: $content.id, platform: :all}) → %{score, impressions, shares}
    - Branch.on(:score)
        >= 0.8 → [NotifyContent.invoke(:slack, "Top performer: #{$content.title} — #{$impressions} impressions, #{$shares} shares"), FSM.transition(:done)]
        >= 0.4 → FSM.transition(:done)
        :_     → [NotifyContent.invoke(:slack, "Low engagement: #{$content.title} — consider boost or revision"), FSM.transition(:done)]
  timeout: 14d → FSM.transition(:done)

### :done
  trigger: Event.eq(:type, :monitoring_complete)
  on-enter: GetPerformanceReport.invoke(%{period: :weekly, platforms: $content.target_platforms})
  terminal: true

### :archived
  trigger: Event.eq(:type, :content_archived)
  on-enter: NotifyContent.invoke(:slack, "Archived: #{$content.title}")
  terminal: true
