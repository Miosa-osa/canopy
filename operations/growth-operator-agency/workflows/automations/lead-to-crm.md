# Automation — Lead to CRM

## Purpose
Capture a lead, enrich the record, tag by source and intent, route to the right sequence and owner, and trigger the first touch — all within 3 minutes of form submission.

## Trigger
- Form submission on any landing page (lead magnet, webinar opt-in, contact form, event registration)
- API lead from integrated source (Zapier, Make, native integration)
- Inbound call transcript if voice lead-capture is active

## End-State
- CRM record exists with enriched fields and correct tags
- Lead is routed to correct nurture sequence
- First-touch email has fired
- Owner (human) assigned with SLA clock started
- Slack / dashboard event logged

## Flow Diagram
```
[Form submit]
      │
      ▼
[Validate email + required fields]
      │  invalid ──► [Reject + show error]
      ▼
[Enrich: clearbit/apollo/fullcontact for firmographics]
      │
      ▼
[De-duplicate against existing CRM contact]
      │
      ▼
[Create or update CRM record]
      │
      ▼
[Apply tags: source, campaign, intent-level]
      │
      ▼
[Route: by intent score + source]
      │
      ├──► [High-intent → owner assignment + Slack alert]
      └──► [Standard → nurture sequence enrollment]
            │
            ▼
      [Day-0 email fires]
            │
            ▼
      [Log event: operations/ledger.jsonl]
```

## Step-by-Step

**Step 1. Validate**
- Email format + MX record check
- Required fields present (name, email minimum)
- Consent flag true (GDPR/CASL regions)
- Honeypot field empty (bot detection)

**Step 2. Enrich**
- Query enrichment API ({enrichment_provider}) with email
- Append: company, title, company size, industry, LinkedIn URL, location
- Timeout 5s — proceed with partial record on miss

**Step 3. De-duplicate**
- Look up by email (exact match)
- If match: merge, update last-touch, don't fire new welcome
- If no match: create new record

**Step 4. Tag**
- `source:{utm_source}` (e.g., `source:youtube`)
- `campaign:{utm_campaign}` (e.g., `campaign:q2-launch-waitlist`)
- `form:{form_id}` (e.g., `form:lead-magnet-voice-template`)
- `intent:{score}` — derived from form type + enrichment (low/med/high)
- `consent:{region}:{YYYY-MM-DD}`

**Step 5. Route**
- If `intent:high` (books call form, pricing page form, high-value enrichment) → route to sales owner, Slack alert `#sales-hot-leads`, SLA 60 min first contact
- If `intent:med` (webinar opt-in, lead magnet from conversion page) → enroll in Medium-Intent sequence
- If `intent:low` (footer opt-in, blog subscribe) → enroll in Long-Term Nurture sequence

**Step 6. First Touch**
- Day-0 email fires within 3 min (see nurture-pipeline.md)
- For high-intent: concurrently send Slack notification to owner
- For high-intent with phone: add to SMS sequence if opted in

**Step 7. Log**
- Write to `workflows/operations/ledger.jsonl`: `{timestamp, event:lead_captured, lead_id, source, intent}`
- Fire pixel conversion event (FB CAPI / Google Enhanced Conversions)

## Fillable Config
```yaml
enrichment_provider: {clearbit | apollo | fullcontact}
enrichment_timeout_s: 5
crm: {hubspot | pipedrive | close | custom}
esp: {customer_io | activecampaign | mailchimp}
high_intent_rules:
  - form_id: book-call
  - enrichment.title contains: [founder, ceo, owner, vp]
  - utm_campaign contains: {high_intent_campaign}
routing:
  high:
    owner: {sales_owner_email}
    sla_minutes: 60
    slack_channel: '#sales-hot-leads'
  medium:
    sequence: medium-intent-7day
  low:
    sequence: long-term-nurture
```

## Sample Filled
```yaml
enrichment_provider: clearbit
enrichment_timeout_s: 5
crm: hubspot
esp: customer_io
high_intent_rules:
  - form_id: book-call
  - form_id: application-form
  - enrichment.title contains: [founder, ceo, owner, vp, director]
  - utm_campaign contains: pricing-page
routing:
  high:
    owner: ops@example.com
    sla_minutes: 60
    slack_channel: '#sales-hot-leads'
  medium:
    sequence: medium-intent-7day
  low:
    sequence: long-term-nurture
```

## Failure Modes + Handling
| Failure | Detection | Response |
|---|---|---|
| Enrichment timeout | 5s timeout | Proceed with partial record; log for batch re-enrichment nightly |
| Email bounces on first send | ESP webhook | Mark as invalid, remove from sequences, do not re-send |
| CRM write fails | Integration error log | Retry 3× with exponential backoff, then alert ops |
| Slack alert fails | API error | Retry once; if still fails, write to backup channel + page on-call |
| Duplicate lead | Match on create | Merge logic: last-touch updated, tags appended |

## Compliance Checklist
- [ ] Consent flag captured on every form
- [ ] GDPR/CCPA: double-opt-in for EU/CA regions
- [ ] Privacy policy linked on form
- [ ] Unsubscribe link in first email
- [ ] Sender identity + physical address in first email
- [ ] Honeypot or reCAPTCHA to block bots

## KPIs
- Lead-to-CRM latency (target: < 30s)
- Enrichment hit rate (target: ≥ 70%)
- Dedupe accuracy (target: ≥ 99%)
- High-intent SLA adherence (target: ≥ 95% contacted within 60 min)
- First-touch delivery rate (target: ≥ 98%)

## Cross-references
- Pipeline: `workflows/divisions/nurture-pipeline.md`
- Next: `workflows/automations/booking-to-show.md`
- Knowledge: `reference/knowledge/nurture.md`

---
*v1.0 — 2026-04-19.*
