# INTEGRATIONS.md — Tech Stack + MCPs + APIs Contract

> **How skills actually do things in the world.** Every skill can declare what external services, MCP servers, APIs, and tools it needs at runtime. The adapter layer resolves these per-runtime. Skills remain runtime-agnostic; adapters wire the concrete bindings.

## The Three Integration Layers

```
L3 — Skills declare capability needs (runtime-agnostic)
      "This skill needs calendar booking + payment processing + audience analysis"
  ↓
L2 — Adapters resolve capabilities to concrete services
      the slash-command adapter → {WebFetch tool, Notion MCP, Cal.com API}
      manifest adapter → {runtime tier skill registry, native engine calls}
  ↓
L1 — Runtime executes against concrete services
      Actual API calls, MCP invocations, tool usage
```

## Skill Frontmatter — Integration Declarations

Every SKILL.md frontmatter may include these optional fields:

```yaml
required_tools:            # Generic tool capabilities (runtime-mapped)
  - web_search
  - web_fetch
  - file_read
  - file_write
  - file_edit
  - bash

required_mcps:             # MCP servers this skill uses
  - filesystem             # file operations
  - notion                 # Notion pages + databases
  - github                 # repos, issues, PRs
  - sequential-thinking    # deep reasoning
  - context7               # library/SDK docs

required_integrations:     # External services via API or MCP
  category: service-name
  # e.g.
  ads: meta-ads-api
  email: convertkit-api
  crm: gohighlevel-api
  payment: stripe-api
  analytics: google-analytics-4
  automation: zapier-webhook
  calendar: cal-com-api

credentials_required:      # Env vars / secrets needed
  - META_ADS_API_TOKEN
  - STRIPE_SECRET_KEY
  - NOTION_API_KEY

scopes_required:           # OAuth scopes if relevant
  - linkedin:posts.write
  - google-ads:campaigns.read
```

## The 12 Integration Categories

Every growth operator business uses services in 12 categories. Growth Operating Agency maps skill needs to categories; adapters bind category → concrete service per creator's actual stack.

### 1. Ads Platforms
- **Meta Ads API** — FB + IG ad management, Profile Funnel Ads, retargeting, creative upload
- **Google Ads API** — search + display + YouTube ads
- **TikTok Ads API** — TikTok paid creative
- **LinkedIn Ads API** — B2B paid
- **YouTube Data API** — YouTube-specific + ad placement data
- **Meta Ad Library** (public research) — competitor ad intelligence

### 2. CRM
- **HubSpot API** — pipeline, contacts, deals
- **GoHighLevel API** (primary for high-ticket) — pipeline, automations, calendars
- **Close.io API** — sales team ops
- **Salesforce API** — enterprise
- **Copper API** — Google-native CRM

### 3. Email Marketing
- **ConvertKit API** — creator-native ESP
- **ActiveCampaign API** — automation-heavy
- **Beehiiv API** — newsletter-native, growth tools built-in
- **Klaviyo API** — e-com heavy (less common for info creators)
- **Mailchimp API** — legacy but widespread

### 4. Funnel Builders / Page Hosting
- **a funnel-building platform API** — classic funnel stack
- **GoHighLevel** — all-in-one including funnel pages
- **Systeme.io API** — budget alternative
- **Kajabi API** — course + membership hosting
- **Webflow API** — custom landing pages
- **Framer API** — modern landing pages
- **Carrd** — minimal landing

### 5. Payment Processing
- **Stripe API** (default) — subscriptions, checkout, products, invoices
- **PayPal API** — secondary option
- **Chargebee / Recurly** — subscription management at scale

### 6. Analytics + Tracking
- **Google Analytics 4 API** — site + behavioral
- **Mixpanel API** — product analytics
- **Segment API** — event pipeline
- **Plausible API** — privacy-first alternative
- **Meta Conversions API** — server-side Meta pixel
- **Triple Whale API** — e-com attribution (less common for info)

### 7. Automation
- **Zapier** (MCP or webhook) — cross-platform glue
- **Make (Integromat)** — deeper logic flows
- **n8n API** — self-hosted automation
- **Activepieces** — open-source alternative

### 8. Community + Communication
- **Skool API** — creator-community-native
- **Circle API** — premium community
- **Discord API** — bot + server ops
- **Slack MCP / API** — team comms + client portals
- **WhatsApp Business API** — DM at scale (Mandarin legacy market)

### 9. Video + Media
- **YouTube Data API** — channel, uploads, analytics
- **Vimeo API** — private hosting
- **Loom API** — recording + embeds
- **Wistia API** — video analytics
- **VEED / Descript API** — editing automation

### 10. Calendar + Booking
- **Cal.com API** (open source) — creator-native
- **Calendly API** — widespread
- **SavvyCal API** — round-robin + AE models
- **Google Calendar MCP** — native

### 11. Social + Content Posting
- **LinkedIn API** — posts (OAuth), analytics, DM (limited)
- **Twitter/X API** — posts, threads, DMs
- **Instagram Graph API** — posts, Reels, Stories
- **TikTok Content Posting API** — video upload + publish
- **YouTube Data API** — video upload + metadata
- **Buffer / Hootsuite / Later API** — multi-platform scheduling (aggregator)

### 12. AI + LLM + Research
- **Anthropic API** (Claude) — primary LLM
- **OpenAI API** — GPT-4, DALL-E
- **Perplexity API** — research + citations
- **Tavily Search API** — AI-optimized search
- **Brave Search API** — independent web search
- **Firecrawl API** — structured web scraping
- **Midjourney API** — image generation (if available)
- **ElevenLabs API** — voice cloning + TTS
- **HeyGen API** — AI video + avatar

## The MCP Server Catalog

Model Context Protocol servers Growth Operating Agency skills can invoke:

| MCP Server | Purpose | Key tools |
|---|---|---|
| `filesystem` | Local file ops | read_file, write_file, list_directory, search_files |
| `notion` | Notion pages + databases | notion-search, notion-fetch, notion-create-pages, notion-update-page, notion-update-data-source |
| `github` | Repos, issues, PRs, code search | via gh CLI or native MCP |
| `slack` | Team comms | list_channels, post_message, get_thread |
| `gmail` | Email ops | search_threads, create_draft, list_drafts, label_message |
| `google-calendar` | Calendar | list_events, create_event, find_free_slots |
| `google-drive` | Drive files | search, fetch, upload |
| `sequential-thinking` | Deep reasoning loops | For complex multi-step analysis |
| `context7` | Library/SDK docs lookup | For code skills referring to external libraries |
| `brave-search` | Web search | search, news |
| `firecrawl` | Web scraping | scrape, crawl, extract structured data |
| `perplexity` | Research with citations | ask, search |

## Skill → Integration Bindings (examples)

### /research
```yaml
required_tools: [web_search, web_fetch, file_read, file_write]
required_mcps: [filesystem, notion, brave-search, firecrawl]
required_integrations:
  research: perplexity-api     # for cross-validated source lookup
  competitor_intel: meta-ad-library  # ad scan (public)
credentials_required: [BRAVE_API_KEY, PERPLEXITY_API_KEY, FIRECRAWL_API_KEY]
```

### /ad-creative
```yaml
required_tools: [web_fetch, file_read, file_write]
required_integrations:
  ads: meta-ads-api
  ad_research: meta-ad-library
  asset_storage: google-drive
  design: figma-api       # or canva-api
credentials_required: [META_ADS_API_TOKEN, FIGMA_API_KEY]
```

### /write-linkedin-post
```yaml
required_tools: [file_read, file_write]
required_integrations:
  social_posting: linkedin-api  # via OAuth
  scheduling: buffer-api        # optional
credentials_required: [LINKEDIN_ACCESS_TOKEN]
scopes_required: [linkedin:r_liteprofile, linkedin:w_member_social]
```

### /build-funnel
```yaml
required_tools: [file_read, file_write]
required_integrations:
  crm: gohighlevel-api
  payment: stripe-api
  email: convertkit-api
  analytics: google-analytics-4
  funnel_builder: clickfunnels-api  # optional
credentials_required: [GHL_API_KEY, STRIPE_SECRET_KEY, CONVERTKIT_API_KEY, GA4_PROPERTY_ID]
```

### /email-sequence
```yaml
required_tools: [file_read, file_write]
required_integrations:
  email: convertkit-api            # or activecampaign-api
  crm: gohighlevel-api
credentials_required: [CONVERTKIT_API_KEY]
```

### /post-booking-nurture
```yaml
required_tools: [file_read, file_write]
required_integrations:
  sms: twilio-api
  email: convertkit-api
  calendar: cal-com-api
  crm: gohighlevel-api
credentials_required: [TWILIO_SID, TWILIO_TOKEN, CAL_COM_API_KEY]
```

### /hiring-brief
```yaml
required_tools: [file_read, file_write, web_fetch]
required_integrations:
  job_boards: linkedin-jobs-api  # optional
  ats: greenhouse-api            # optional
```

## Credential Management

### Where credentials live
- **NEVER** in `company.yaml` directly (per INV-11 privacy)
- **NEVER** in skill files (committed to git)
- **ALWAYS** in `.env.local` (gitignored) or creator's secret manager

### `.env.template` (template, no real values)
Ship a `.env.template` at workspace root listing every credential the template skills CAN use. Creator fills in only the ones their chosen stack needs.

```
# AI + LLM
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
PERPLEXITY_API_KEY=

# Search + Research
BRAVE_API_KEY=
TAVILY_API_KEY=
FIRECRAWL_API_KEY=

# Ads
META_ADS_API_TOKEN=
GOOGLE_ADS_DEVELOPER_TOKEN=
TIKTOK_ADS_ACCESS_TOKEN=
LINKEDIN_ADS_TOKEN=

# CRM + Email
GHL_API_KEY=
HUBSPOT_PRIVATE_APP_TOKEN=
CONVERTKIT_API_KEY=
ACTIVECAMPAIGN_API_KEY=
BEEHIIV_API_KEY=

# Payment
STRIPE_SECRET_KEY=

# Analytics
GA4_PROPERTY_ID=
MIXPANEL_PROJECT_TOKEN=

# Automation
ZAPIER_WEBHOOK_URL=
MAKE_WEBHOOK_URL=

# Community
SKOOL_API_KEY=
CIRCLE_API_TOKEN=
SLACK_BOT_TOKEN=
DISCORD_BOT_TOKEN=

# Video + Media
YOUTUBE_DATA_API_KEY=
VIMEO_ACCESS_TOKEN=
LOOM_API_TOKEN=

# Calendar
CAL_COM_API_KEY=
CALENDLY_TOKEN=
GOOGLE_CALENDAR_OAUTH_TOKEN=

# Social
LINKEDIN_ACCESS_TOKEN=
TWITTER_BEARER_TOKEN=
INSTAGRAM_ACCESS_TOKEN=

# SMS / Voice
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=

# Other
NOTION_API_KEY=
GITHUB_TOKEN=
```

### MCP server config

Creator adds MCP servers to `.mcp.json` (slash-command runtime) or equivalent runtime config:

```json
{
  "mcpServers": {
    "notion": {
      "command": "mcp-server-notion",
      "env": {"NOTION_API_KEY": "${NOTION_API_KEY}"}
    },
    "filesystem": {
      "command": "mcp-server-filesystem",
      "args": ["/path/to/workspace"]
    },
    "brave-search": {
      "command": "mcp-server-brave",
      "env": {"BRAVE_API_KEY": "${BRAVE_API_KEY}"}
    }
  }
}
```

## Adapter Responsibility (per skill)

When a skill declares `required_integrations: {ads: meta-ads-api}`, the adapter for a specific runtime translates:

**the slash-command adapter:**
```markdown
## Runtime tool bindings
- Ads integration: use WebFetch on Meta Ads API endpoints
- Or use Meta Ads MCP if installed
- Credentials from .env.local via Bash with env-var echo
```

**workspace manifests adapter:**
```yaml
integrations:
  ads:
    service: meta-ads-api
    adapter_file: adapters/meta_ads_adapter.go
    credentials: vault://creator/meta_ads
```

**HTTP adapter (generic REST):**
```yaml
integrations:
  ads:
    base_url: https://graph.facebook.com/v20.0
    auth: bearer
    credentials_ref: ${META_ADS_API_TOKEN}
```

## Integration-Free Skills

Some skills need NO external integrations — they're pure reasoning + file operations:
- `/research` — mostly web research (file-write + web-search only)
- `/build-icp` — file-read + file-write
- `/build-positioning` — file-read + file-write
- `/design-offer` — file-read + file-write
- `/extract-voice` — file-read + file-write + (optional) web-fetch for content samples

Integration-heavy skills:
- `/ad-creative` — Meta Ads + asset storage + design tools
- `/build-funnel` — CRM + payment + email + analytics + funnel builder
- `/email-sequence` — email platform API + CRM
- `/post-booking-nurture` — SMS + email + calendar + CRM
- `/content-calendar` — social posting + scheduling aggregator
- `/write-linkedin-post` + other posting skills — platform APIs

## The Runtime-Agnostic Guarantee (Revisited)

Adding integrations does NOT break runtime-agnostic. The pattern:
- SKILL.md declares capability CATEGORIES (not concrete services)
- Adapters resolve CATEGORIES to concrete services
- If a creator uses ConvertKit, their adapter maps `email` → ConvertKit API. If they use ActiveCampaign, same skill, different adapter config.

This is the **everlasting principle** at the integration layer — change CRM vendor? Change adapter config. Skill is unchanged.

## MCP-First Over API-Direct

**Preference order** when multiple options exist:
1. **Native MCP server** (if available, clean protocol boundary)
2. **Unified aggregator** (Zapier / Make / n8n — broad coverage, some overhead)
3. **Direct API** (fastest but tightest coupling)

Most skills should prefer MCP where possible. Direct API only when MCP doesn't cover the need.

## Security + Privacy

- **INV-11** — credentials never committed to git, never in `company.yaml`
- **Scope-limit** OAuth tokens — request only the scopes needed (e.g. `linkedin:w_member_social` not full profile access)
- **Rotate credentials** quarterly
- **Audit log** every API call (the workspace manifest heartbeat logs by default; slash-command runtime via bash history)
- **No PII in prompts** — when feeding data to LLMs, strip PII unless absolutely required + authorized

## Sources

- Anthropic Agent SDK + Claude Skills documentation
- the workspace manifest `architecture/adapters.md`
- Growth Operating Agency Context Profile Compartment 11 (Operational Intelligence — tech_stack)
- MCP specification — https://modelcontextprotocol.io

---

*v1.0 — 2026-04-19. Growth Operating Agency skills remain runtime-agnostic. Adapters carry concrete-service bindings. Creators' stacks are configurable.*
