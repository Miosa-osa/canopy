# Integrations Reference — Tech Stack for Growth Operators

> **Catalog of APIs, MCPs, and services** Growth Operating Agency skills can bind to. Every creator's actual stack is a subset of this catalog — fill in only what they use.

## Contents

This file is the catalog. Detailed per-MCP and per-API pages are populated as they get wired into a live workspace — start with the matrix and the tier strategy below; expand into per-platform files only when a skill needs the depth.

## Quick Reference — Integration Matrix

| Capability | Default | Alternatives |
|---|---|---|
| LLM | Anthropic Claude | OpenAI, Google Gemini, local Ollama |
| Research search | Perplexity + Brave | Tavily, Firecrawl, Kagi |
| Ads | Meta Ads API | Google Ads, LinkedIn Ads, TikTok Ads |
| CRM | GoHighLevel | HubSpot, Close, Salesforce |
| Email | ConvertKit | ActiveCampaign, Beehiiv, Klaviyo |
| Payment | Stripe | PayPal, Chargebee |
| Funnel builder | GoHighLevel | a funnel-building platform, a European funnel tool, Webflow, Framer |
| Analytics | GA4 + Meta CAPI | Mixpanel, Segment, Plausible |
| Automation | Zapier | Make, n8n, Activepieces |
| Community | Skool | Circle, Discord, Slack |
| Video | YouTube Data API | Vimeo, Loom, Wistia |
| Calendar | Cal.com | Calendly, SavvyCal |
| Social posting | platform-native APIs | Buffer, Hootsuite, Later |
| Scheduling (async) | Typeform + Airtable | Tally, Jotform |
| SMS | Twilio | MessageBird, Vonage |
| Design | Figma | Canva, Adobe Express |

## Integration Priority by Skill Department

### Foundations (research + docs + analysis)
- Low integration needs — mostly file ops + web research
- Primary: filesystem MCP, web search (Brave/Tavily/Perplexity), Notion MCP (for pulling creator's existing docs)

### Marketing / Attention (content + ads)
- Heavy integration needs
- Ads platforms (Meta primary), social posting (platform APIs or Buffer), design (Figma/Canva), video (YouTube Data API)

### Nurture / Educate (email + community + SMS)
- Email platform (ConvertKit/AC/Beehiiv), SMS (Twilio), community (Skool/Circle/Discord)

### Sales / Convert (funnel + CRM + calendar)
- CRM (GHL/HubSpot), payment (Stripe), calendar (Cal.com/Calendly), funnel builder (GHL / a funnel-building platform)

### Launch (cross-department orchestration)
- Automation layer (Zapier/Make/n8n) to coordinate all the above
- Analytics dashboards (GA4, Mixpanel)

### Scale (ops + hiring + finance)
- Project mgmt (Notion/a productivity-software brand/Linear), hiring (LinkedIn Jobs, Greenhouse), finance (QuickBooks/Xero), analytics deep-dive

### Partnerships (CRM + contracts)
- CRM with partnership pipeline, contract tools (PandaDoc, DocuSign)

## The Tiered Stack Strategy

Per creator revenue tier:

**Tier 1 — Pre-revenue to $10K/mo** (budget stack)
- LLM: Claude (via slash-command runtime) or ChatGPT (direct)
- CRM: Close free tier OR Airtable
- Email: ConvertKit free tier
- Payment: Stripe
- Funnel: Carrd + Stripe checkout
- Community: Skool free tier
- Cost: $0-$100/mo

**Tier 2 — $10K-$100K/mo** (growing stack)
- LLM: Claude API direct + MCPs
- CRM: GoHighLevel all-in-one ($97-$297/mo)
- Email: Inside GHL OR ConvertKit ($29-$79/mo)
- Payment: Stripe
- Funnel: GHL
- Community: Skool ($99/mo)
- Ads: Meta + minimal Google ($1K-$10K/mo spend)
- Cost: $500-$2K/mo infrastructure

**Tier 3 — $100K-$1M/mo** (operator stack)
- LLM: Claude Enterprise + specialized agents
- CRM: GoHighLevel or HubSpot Pro
- Email: ActiveCampaign Professional
- Payment: Stripe + Chargebee for subs
- Funnel: GHL + custom pages (Webflow/Framer)
- Community: Skool or Circle
- Ads: Meta + Google + YouTube + LinkedIn ($10K-$100K/mo spend)
- Analytics: Mixpanel + Segment + Meta CAPI
- Automation: Zapier + Make
- Cost: $2K-$10K/mo infrastructure

**Tier 4 — $1M+/mo** (scale stack)
- LLM: Multi-model (Claude + GPT + specialized) with orchestration
- CRM: Salesforce or HubSpot Enterprise
- Email: Klaviyo or custom
- Payment: Stripe + recurly
- Full analytics stack: Segment + Amplitude + data warehouse (BigQuery/Snowflake)
- Automation: n8n self-hosted + custom
- Multi-channel ad spend: $100K+ / mo
- Cost: $10K-$50K/mo infrastructure

## What goes in `company.yaml` (tech_stack section — Compartment 11)

```yaml
operational_intelligence:
  tech_stack:
    llm: claude-anthropic
    crm: gohighlevel
    email_platform: convertkit
    funnel_builder: gohighlevel
    payment_processor: stripe
    analytics_tools: [google-analytics-4, meta-conversions-api]
    automation_tools: [zapier]
    community_platform: skool
    video_hosting: youtube
    calendar: cal-com
    sms: twilio
    design: figma
    social_scheduling: buffer
```

Skills query this to route integration calls to the right services.

## Recommended Reading Path

1. `reference/canonical/spec/INTEGRATIONS.md` — the runtime contract for how skills bind to external services
2. The Integration Matrix above — pick defaults per capability
3. The Tiered Stack Strategy above — match infrastructure to current revenue tier
4. `.env.template` (top-level) — environment-variable scaffolding for secrets

---

*v1.0 — 2026-04-19*
