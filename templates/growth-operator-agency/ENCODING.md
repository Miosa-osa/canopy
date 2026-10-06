# ENCODING — Creator Context Profile Schema

> **The variable substitution contract.** This file defines the 11-compartment schema that every skill pulls from. `company.yaml` stores the actual values for a specific creator. The completeness of each compartment determines which skills can execute.
>
> **Weighting maps to Impact Distribution (40/40/20):** Audience 20% + Offer 15% + Creator Identity 15% = 50% (strategic layer). Copy/Content/Traffic/Sales/Nurture/Lifecycle/Ops = 50% (execution layer).

## The 11 Compartments

### Compartment 1 — Creator Identity Matrix (weight 15%)

```yaml
creator_identity_matrix:
  basic_info:
    creator_name: string              # Full name or stage name
    brand_name: string                # Business/brand name
    industry_vertical: string         # Coaching / Consulting / Agency / Info / SaaS / E-com
    business_model: string            # High-ticket coaching | Agency retainer | Course | Membership | Hybrid
    revenue_tier: string              # pre-revenue | $10K-$50K/mo | $50K-$250K/mo | $250K-$1M/mo | $1M+/mo
    years_active: integer

  brand_voice_architecture:
    communication_style: string       # direct / consultative / storytelling / analytical / contrarian
    tone_framework:
      - primary: string               # e.g. "blunt"
      - secondary: string             # e.g. "warm-under-blunt"
    personality_traits: [string]      # 3-5 traits
    language_patterns: [string]       # signature phrases / cadence patterns
    phrases_to_use: [string]          # verbatim phrases from creator
    phrases_to_avoid: [string]        # words/phrases that break voice
    persuasion_style: string          # authority-by-proof / story-first / mechanism-first / contrarian-provocation
    authority_positioning: string     # Category-king / challenger / insider / outsider-with-edge

  unique_positioning:
    unique_mechanism: string          # The named mechanism (e.g. "The 40/40/20 Framework")
    category_positioning: string      # The category they own
    competitive_differentiation: string
    core_philosophy: string           # One-sentence worldview
    contrarian_beliefs: [string]      # Things they believe that the market doesn't
```

### Compartment 2 — Audience Intelligence System (weight 20% — HEAVIEST)

```yaml
audience_intelligence_system:
  ideal_customer_profile:
    demographics:
      age_range: string
      gender_split: string
      geography: [string]
      income_range: string
      education: string
    firmographics:
      role: string                    # Founder / CEO / Coach / Consultant
      company_stage: string           # Solo / 2-10 / 11-50 / 50+
      revenue_stage: string           # <$100K / $100K-$1M / $1M-$10M / $10M+
      industry: [string]
    psychographics:
      pain_points: [string]           # 5-10 specific pains
      desires: [string]               # 5-10 outcomes they want
      fears: [string]                 # What they're afraid of
      aspirations: [string]           # Identity they want to become
      beliefs: [string]               # What they currently believe
      objections: [string]            # Sale-killing objections (min 10)
    behavioral_patterns:
      buying_triggers: [string]       # Specific trigger events that create urgency
      decision_making_process: string # Solo / partner-consult / board-approval
      research_behavior: [string]     # Where they search, who they follow, what they read
      trust_signals_required: [string] # What makes them trust

  market_sophistication:
    awareness_level: string           # Unaware / Problem-aware / Solution-aware / Product-aware / Most-aware (awareness-spectrum methodology)
    solution_awareness: string        # Naive / Aware / Skeptical / Exhausted (market maturity stage)
    market_maturity: string           # Emerging / Growing / Mature / Saturated
    competitive_density: string       # Low / Medium / High / Saturated

  voice_of_customer:
    actual_customer_language: [string]    # Verbatim phrases from sales calls, DMs, reviews
    pain_language_patterns: [string]      # How they describe their pain
    desire_language_patterns: [string]    # How they describe their desired outcome
    objection_patterns: [string]          # How they frame their objections

  limiting_belief_diagnosis:
    dominant_belief: string           # Worthless | Helpless | Hopeless (Limiting Belief Triad)
    transformation_type: string       # Status | Capability | Safety (matches belief)
```

### Compartment 3 — Offer Architecture (weight 15%)

```yaml
offer_architecture:
  core_offers:
    - offer_name: string
      offer_type: string              # High-ticket 1:1 / Group program / Course / Membership / Done-for-you
      price_point: number             # USD
      positioning: string             # How it's positioned
      core_promise: string            # The transformation
      unique_mechanism: string        # What makes it work (named mechanism)
      transformation_delivered: string # Before → After
      target_avatar: string           # Which segment from compartment 2
      value_stack:                    # List the value components with dollar values
        - component: string
          value_usd: number
      bonuses:                        # 3-5 bonuses (ideally 5); each counters an objection
        - bonus_name: string
          value_usd: number
          objection_countered: string
      guarantee: string               # ROI-positive guarantee copy
      risk_reversal: string           # Specific risk-reversal mechanism

  offer_ladder:
    lead_magnet: string               # Free entry offer
    tripwire: string                  # Low-ticket entry ($7-$97)
    core_offer: string                # Main high-ticket
    upsells: [string]                 # 1-3 upsells
    high_ticket: string               # Top of ladder ($10K+)
    continuity: string                # Recurring revenue component

  pricing_psychology:
    pricing_strategy: string          # Identity-aligned / value-based / competitive / anchor-and-discount
    payment_options: [string]         # Pay-in-full / 3-pay / 6-pay / payment-plan
    comparison_anchoring: string      # What it's anchored against
    value_justification: string       # ROI math shown to prospects

  economics_validation:
    ltv: number                       # Lifetime value per customer
    cac: number                       # Customer acquisition cost
    ltv_cac_ratio: number             # Must be ≥ 3.0
    gross_margin_pct: number          # Target ≥ 70%
    breakeven_per_cohort: string      # Months to breakeven per cohort
```

### Compartment 4 — Funnel Systems Architecture (weight 10%)

```yaml
funnel_systems:
  active_funnels:
    - funnel_name: string
      funnel_type: string             # VSL / Webinar / Application / Book-a-call / Tripwire / Challenge / Community
      funnel_objective: string
      traffic_source: [string]        # Organic / Paid / Partnership / Email
      stages:
        awareness:
          traffic_mechanism: string   # What brings them in
          hook_frameworks: [string]   # Which hook types used
          pattern_interrupts: [string]
        interest:
          lead_magnet: string
          opt_in_page_framework: string
          delivery_mechanism: string
        consideration:
          nurture_sequence: string
          belief_installation_framework: [string]
          objection_pre_framing: [string]
        decision:
          sales_mechanism: string     # VSL | Webinar | Challenge | Call
          vsl_structure: string       # 11-step / 15-step / 13-step / 3X / hidden-pitch long-form video
          sales_page_framework: string
          closing_mechanism: string
        action:
          checkout_optimization: string
          upsell_sequence: [string]
          downsell_strategy: string
      conversion_metrics:
        target_cvr: number
        current_cvr: number
        optimization_priorities: [string]
```

### Compartment 5 — Copy & Messaging Framework (weight 5%)

```yaml
copy_messaging:
  proven_headlines: [string]          # Ones that have worked for this creator
  proven_hooks: [string]
  proven_angles: [string]
  story_frameworks:
    - story_type: string              # Origin / Transformation / Conflict / Revelation
      story_structure: string
      emotional_arc: string
      key_lessons: [string]
  psychological_triggers:
    primary_emotions: [string]        # Fear/Anger/Greed/Guilt/Pride
    cognitive_biases_leveraged: [string]
    persuasion_principles: [string]   # influence-principles research primitives used
    urgency_mechanisms: [string]
    scarcity_frameworks: [string]
  objection_handling_library:
    - objection: string
      reframe: string
      proof_points: [string]
  social_proof_assets:
    case_studies: [string]
    testimonials: [string]
    results_database: [string]
    authority_indicators: [string]
```

### Compartment 6 — Content Strategy Matrix (weight 5%)

```yaml
content_strategy:
  content_pillars:
    - pillar_name: string
      pillar_objective: string
      topics: [string]
      conversion_bridge: string       # How this pillar bridges to offer
  platform_strategies:
    # Growth Operating Agency: keep platform entries minimal — for full platform ops use a vertical workspace
    youtube:
      active: boolean
      content_types: [string]         # Educational / VSSL / Lifestyle / Tutorial / Case Study
      posting_frequency: string
    linkedin:
      active: boolean                 # Minimal — only to post about offers
      post_types: [string]            # Thought / Proof / Offer-tied / Contrarian
      posting_frequency: string
    instagram:
      active: boolean                 # Minimal — stories/reels about offers
    twitter_x:
      active: boolean                 # Minimal — threads about offers
    tiktok:
      active: boolean                 # Minimal
    email:
      sequence_frameworks: [string]
      email_types: [string]
      subject_line_patterns: [string]
      cadence_strategy: string
  content_to_conversion_bridge:
    awareness_content: [string]
    consideration_content: [string]
    decision_content: [string]
```

### Compartment 7 — Traffic & Acquisition Systems (weight 10%)

```yaml
traffic_acquisition:
  organic_strategies:
    seo_strategy: string
    content_distribution: [string]
    platform_growth_tactics: [string]
  paid_strategies:
    active_channels: [string]         # Meta / Google / YouTube / TikTok / LinkedIn / X
    ad_frameworks:
      - channel: string
        ad_types: [string]            # Profile Funnel / Retargeting / Video Hook / Testimonial / UGC / Carousel
        proven_angles: [string]
        targeting_parameters:
          audiences: [string]
          interests: [string]
          lookalikes: [string]
        creative_frameworks: [string]
        budget_allocation_pct: number
    spend_total_monthly: number
  partnership_strategies:
    affiliate_program: string
    influencer_partnerships: [string]
    jv_webinars: [string]
    strategic_alliances: [string]
```

### Compartment 8 — Conversion & Sales Systems (weight 10%)

```yaml
conversion_sales:
  sales_process_architecture:
    sales_model: string               # Self-serve / Application-funnel / Setter-closer / AE / Hybrid
    qualification_criteria: [string]
    discovery_framework: string       # 8-stage / FST / SPIN
    pitch_structure: string
    closing_methodology: string       # Crossroads / Assumptive / Question / Takeaway
  sales_scripts:
    opening_scripts: [string]
    discovery_questions: [string]
    pitch_frameworks: [string]
    objection_handling_scripts: [string]  # Maps to compartment 5 library
    closing_scripts: [string]
  application_qualification:
    qualification_questions: [string]
    disqualification_criteria: [string]
    filtering_mechanism: string       # Application / Typeform / AI-screening
  team_roles:
    has_setter: boolean
    has_closer: boolean
    has_sdr: boolean
    commission_structure: string
```

### Compartment 9 — Education & Nurture OS (weight 5%)

```yaml
education_nurture:
  onboarding_architecture:
    welcome_sequence: string
    activation_strategy: string
    first_win_engineering: string     # Ensure quick win in first 7 days
    milestone_progression: [string]
  email_sequence_frameworks:
    indoctrination_sequence: [string]
    value_sequence: [string]
    conversion_sequence: [string]
    retention_sequence: [string]
  community_systems:
    platform: string                  # Skool / Circle / Discord / Slack / Private FB
    engagement_strategy: string
    content_calendar: [string]
    ritual_frameworks: [string]       # Weekly rituals, monthly recurring events
```

### Compartment 10 — Lifecycle & Optimization (weight 3%)

```yaml
lifecycle_optimization:
  retention_strategy:
    churn_prevention: [string]
    engagement_triggers: [string]
    value_delivery_cadence: string
  upsell_architecture:
    upsell_paths: [string]
    cross_sell_opportunities: [string]
    expansion_triggers: [string]
  metrics_dashboard:
    north_star_metric: string         # MRR | cash-collected | clients-closed | LTV
    key_performance_indicators: [string]
    current_performance: {}           # Keyed by KPI
    optimization_priorities: [string]
```

### Compartment 11 — Operational Intelligence (weight 2%)

```yaml
operational_intelligence:
  tech_stack:
    crm: string                       # HubSpot / GoHighLevel / Close / Custom
    email_platform: string            # ConvertKit / ActiveCampaign / Beehiiv / Klaviyo
    funnel_builder: string            # GoHighLevel / {FUNNEL_BUILDER} / Custom
    payment_processor: string         # Stripe / PayPal / Custom
    analytics_tools: [string]
    automation_tools: [string]        # Zapier / Make / n8n / Custom
  team_structure:
    roles: [string]
    responsibilities: {}              # Keyed by role
    communication_protocols: [string]
  workflows:
    content_creation_workflow: string
    launch_workflow: string
    client_onboarding_workflow: string
```

---

## Completeness Scoring

Each compartment is scored 0-100:

- 0% = empty
- 25% = skeleton (business type, name)
- 50% = foundation (core fields populated)
- 75% = solid (nested fields populated with voice-of-customer evidence)
- 90% = optimized (every field, verbatim customer language, proven frameworks tagged)
- 100% = elite (compartment output is blind-test indistinguishable from the creator's own)

The weighted sum = overall Context Quality Score.

## How Skills Use Compartments

Every skill declares required compartments + minimum completeness in its `SKILL.md` frontmatter:

```yaml
# example skill frontmatter
required_compartments:
  audience_intelligence_system: 70
  offer_architecture: 70
  copy_messaging: 50
```

If any required compartment is below threshold, the skill refuses to execute and **interview-mode** activates to fill the gap.

## How the Boot Sequence Reads ENCODING.md

1. Boot reads `SYSTEM.md`
2. Boot reads `INVARIANTS.md`
3. Boot reads `ENCODING.md` (this file) to know the schema
4. Boot reads `company.yaml` to load actual values
5. Boot computes compartment completeness scores
6. Boot determines which skills are unlocked
7. Agent operates within those unlocks

## Variable Substitution

Throughout skill bodies, reference compartments with `{{path.to.field}}` notation:

- `{{creator_identity_matrix.basic_info.creator_name}}`
- `{{audience_intelligence_system.voice_of_customer.pain_language_patterns}}`
- `{{offer_architecture.core_offers[0].core_promise}}`
- `{{offer_architecture.core_offers[0].value_stack}}`

Skills hydrate these at execution time from `company.yaml`.

## Authoritative Schema

This file is the **authoritative schema**. `company.yaml` must conform. If a creator has data outside this schema, extend this file first, then add to `company.yaml`. Never store schema-violating data in `company.yaml`.

---

*Version: 1.0.0 — 2026-04-21. Based on Creator Context Profile Architecture + Signal Theory. Derived from Notion page {NOTION_ID}.*

*Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
