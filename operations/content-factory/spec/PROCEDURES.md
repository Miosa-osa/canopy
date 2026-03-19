# Procedure Registry v1.0

> Content Factory — action and query bindings for multi-platform content operations.

## Action Bindings (Side-Effect Producers)

### Draft → Actions.draft/2
  @spec draft(context(), %{topic: String.t(), format: :long_form | :short_form | :thread | :newsletter, tone: atom(), target_words: integer(), outline: map() | nil}) :: {:ok, %{draft_id: String.t(), content: String.t(), word_count: integer()}} | {:error, reason}
  Runtime: LLM provider (hot-swap between Anthropic, OpenAI, Ollama)
  Timeout: 120s
  Approval: none

### Edit → Actions.edit/2
  @spec edit(context(), %{draft_id: String.t(), pass: :structural | :line | :copy | :brand_voice, instructions: String.t() | nil}) :: {:ok, %{draft_id: String.t(), content: String.t(), changes: [change()]}} | {:error, reason}
  Runtime: LLM provider
  Timeout: 90s
  Approval: none

### Publish → Actions.publish/2
  @spec publish(context(), %{content_id: String.t(), platform: :blog | :twitter | :linkedin | :youtube | :newsletter | :instagram, metadata: map()}) :: {:ok, %{post_id: String.t(), url: String.t(), published_at: DateTime.t()}} | {:error, reason}
  Runtime: platform adapter (hot-swap per platform: Ghost, Twitter API, LinkedIn API, etc.)
  Timeout: 30s
  Approval: governance.publish_review (if platform == :blog or :newsletter)

### Schedule → Actions.schedule/2
  @spec schedule(context(), %{content_id: String.t(), platform: atom(), publish_at: DateTime.t(), timezone: String.t()}) :: {:ok, schedule_id} | {:error, reason}
  Runtime: scheduler provider (Buffer, Typefully, custom)
  Timeout: 15s
  Approval: none

### Repurpose → Actions.repurpose/2
  @spec repurpose(context(), %{source_id: String.t(), target_format: :thread | :short_form | :carousel | :email | :video_script, platform: atom()}) :: {:ok, %{draft_id: String.t(), content: String.t(), format: atom()}} | {:error, reason}
  Runtime: LLM provider
  Timeout: 90s
  Approval: none

### NotifyContent → Actions.notify_content/2
  @spec notify_content(context(), %{channel: :slack | :email, message: String.t(), urgency: :low | :normal | :high, mention: [String.t()]}) :: :ok
  Runtime: notification hub
  Timeout: 10s
  Approval: none

### UploadAsset → Actions.upload_asset/2
  @spec upload_asset(context(), %{file_path: String.t(), type: :image | :video | :audio, optimize: boolean()}) :: {:ok, %{asset_id: String.t(), url: String.t(), size_bytes: integer()}} | {:error, reason}
  Runtime: asset storage (S3, Cloudflare R2, Cloudinary)
  Timeout: 60s
  Sandbox: yes
  Approval: none


## Query Bindings (Pure Functions)

### AnalyzeTrend → Queries.analyze_trend/2
  @spec analyze_trend(context(), %{topic: String.t(), platforms: [atom()], window_days: integer()}) :: {:ok, %{trending_score: float(), related_topics: [String.t()], volume: map(), peak_times: [DateTime.t()]}}
  Runtime: analytics engine (social listening + search trends)
  Cache: TTL 3600s, key: {hash(topic), platforms, window_days}

### ScoreEngagement → Queries.score_engagement/2
  @spec score_engagement(context(), %{content_id: String.t(), platform: atom()}) :: {:ok, %{score: float(), impressions: integer(), clicks: integer(), shares: integer(), comments: integer(), saves: integer(), ctr: float()}}
  Runtime: platform analytics adapter
  Cache: TTL 300s, key: {content_id, platform}

### CheckBrandVoice → Queries.check_brand_voice/2
  @spec check_brand_voice(context(), %{content: String.t(), brand_profile: atom()}) :: {:ok, %{alignment_score: float(), tone_match: float(), vocabulary_flags: [String.t()], suggestions: [String.t()]}}
  Runtime: brand analysis engine (LLM-backed)
  Cache: TTL 600s, key: {hash(content), brand_profile}

### GetContentCalendar → Queries.get_content_calendar/2
  @spec get_content_calendar(context(), %{date_range: {Date.t(), Date.t()}, platform: atom() | :all, status: atom() | :all}) :: {:ok, %{items: [calendar_item()], gaps: [Date.t()], conflicts: [conflict()]}}
  Runtime: content management system
  Cache: TTL 60s, key: {date_range, platform, status}

### AnalyzeCompetitor → Queries.analyze_competitor/2
  @spec analyze_competitor(context(), %{competitor: String.t(), platform: atom(), window_days: integer()}) :: {:ok, %{top_content: [content()], posting_frequency: float(), avg_engagement: float(), content_themes: [String.t()]}}
  Runtime: social listening engine
  Cache: TTL 7200s, key: {competitor, platform, window_days}

### GetPerformanceReport → Queries.get_performance_report/2
  @spec get_performance_report(context(), %{period: :weekly | :monthly, platforms: [atom()] | :all}) :: {:ok, %{total_reach: integer(), total_engagement: integer(), top_performers: [content()], growth_rate: float(), platform_breakdown: map()}}
  Runtime: analytics aggregator
  Cache: TTL 1800s, key: {period, platforms}
