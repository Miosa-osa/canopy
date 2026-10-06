# Automation — Purchase to Onboarding

## Purpose
Convert a purchase from a transaction into a momentum-rich onboarding experience within 24 hours. The first 7 days of ownership dictate refund rate, NPS, and case-study eligibility. Automate the predictable; preserve the human signals for the delivery lead.

## Trigger
- Successful payment webhook (Stripe, Paddle, ThriveCart, custom)
- Upsell or order-bump also triggers appropriate version

## End-State
- Welcome sequence delivered
- Portal / workspace access granted
- Founder-signed personal note queued for delivery lead
- Kickoff call booking link sent
- Onboarding task list active
- CRM updated with purchase + LTV estimate
- Slack event logged
- Refund window clock started

## Flow Diagram
```
[Payment success webhook]
      │
      ▼
[Fraud / chargeback screening]
      │  flagged ──► [Hold + manual review]
      ▼
[Provision access: portal, workspace, Slack invite]
      │
      ▼
[Send welcome email (T+0 min)]
      │
      ▼
[CRM update: stage=customer, product:{sku}, ltv_tier:{tier}]
      │
      ▼
[Queue personal founder note for delivery lead]
      │
      ▼
[Send kickoff booking link (T+30 min)]
      │
      ▼
[Start 7-day welcome sequence]
      │
      ├── Day 0: Welcome + access (automated)
      ├── Day 1: Personal note from delivery lead (human-initiated)
      ├── Day 2: Kickoff agenda + intake form
      ├── Day 4: First-week resources + FAQ
      └── Day 7: Pulse CSAT + answer-any-question
      ▼
[Trigger ongoing sequences per product]
```

## Step-by-Step

**Step 1. Fraud Screening**
- Run through processor's risk scoring
- High-risk flags: country mismatch, velocity check, BIN watchlist
- Flagged → hold delivery, manual review within 1h

**Step 2. Access Provisioning**
- Portal account created with buyer email + temp password
- Slack workspace invite sent (if applicable)
- Shared drive / Notion invited with role permissions
- Access test: confirm all three portals resolve

**Step 3. Welcome Email (T+0)**
- Subject: `Welcome to {product_name}, {first_name} — here is everything you need`
- Body includes: access links, password reset, what-to-expect timeline, support contact, first action
- Sends within 60s of payment

**Step 4. CRM Update**
- Stage: `customer`
- Product: `{sku}`
- Purchase amount: `{$}`
- LTV estimate: computed from SKU and historical cohort
- Tag: `purchased:{YYYY-MM-DD}`, `cohort:{month}`, `sku:{sku}`
- Refund window end-date tagged

**Step 5. Personal Note Queued**
- Task created for delivery lead: "send personal welcome" with deadline T+24h
- Includes context summary from intake form (if completed pre-purchase)
- Not auto-sent — intentionally human

**Step 6. Kickoff Booking (T+30 min)**
- Dedicated booking link with kickoff call availability
- Subject: `Book your kickoff — this week if possible`
- Calendar auto-holds delivery lead's next 2 weeks

**Step 7. 7-Day Welcome Sequence**
- Day 0: automated welcome
- Day 1: personal note (manual task)
- Day 2: kickoff agenda + intake form (if not done)
- Day 4: FAQ + first-week resources
- Day 7: CSAT pulse survey (1 question: "How has week 1 been? 1–5")

**Step 8. Refund-Window Checkpoint**
- 48h before refund window closes: internal alert to CS for pulse check
- If CSAT < 4 at Day 7 → escalate to delivery lead for save call

**Step 9. Upsell Trigger (Day 14+)**
- If applicable: upsell sequence fires based on product-ladder

**Step 10. Log**
- `workflows/operations/ledger.jsonl`: `{timestamp, event:purchase_completed, customer_id, sku, amount}`
- Fire conversion pixel (FB, Google, TikTok)
- Revenue dashboard updated

## Fillable Config
```yaml
processor: {stripe | paddle | thrivecart}
portal: {kajabi | circle | notion | custom}
slack_workspace_invite: true
welcome_email:
  send_within_seconds: 60
  subject_template: 'Welcome to {product} — here is everything you need'
personal_note:
  assigned_to: {delivery_lead_email}
  deadline_hours: 24
kickoff:
  booking_link: {url}
  auto_hold_days: 14
welcome_sequence: welcome-7-day
csat_pulse_day: 7
refund_window_days: 14
upsell_trigger_day: 14
```

## Sample Filled (Growth Operating Agency Quarterly $25K)
```yaml
processor: stripe
portal: notion
slack_workspace_invite: true
welcome_email:
  send_within_seconds: 60
  subject_template: 'Welcome to Growth Operating Agency, {first_name} — let us get started'
personal_note:
  assigned_to: ops@example.com
  deadline_hours: 24
kickoff:
  booking_link: https://calendly.com/heuresis/kickoff-60
  auto_hold_days: 14
welcome_sequence: growth-os-welcome-7day
csat_pulse_day: 7
refund_window_days: 14
upsell_trigger_day: 90  # add-on offer at QBR
```

## Failure Modes + Handling
| Failure | Detection | Response |
|---|---|---|
| Portal provisioning fails | Integration error | Retry 3× backoff; manual grant + email apology |
| Welcome email delayed > 5 min | ESP log | Ops alert; fallback template if template broken |
| Slack invite fails | Slack API error | Manual invite by ops, follow-up email |
| Intake form not returned by Day 2 | CRM check | Trigger reminder; at Day 5 delivery lead calls |
| Chargeback fires | Processor webhook | Pause delivery, escalate to founder, case-document |
| CSAT < 4 at Day 7 | Survey response | CS intervention within 24h |

## Compliance Checklist
- [ ] Receipt email includes business identity + tax ID (where required)
- [ ] Refund policy linked in welcome email
- [ ] Access granted only after payment cleared (not authorization)
- [ ] Data processing agreement sent if applicable (B2B)
- [ ] PCI compliance: no card data stored by us (processor handles)

## KPIs
- Time-to-access (target: < 2 min post-payment)
- Welcome email open rate (target: ≥ 70%)
- Kickoff booking conversion (target: ≥ 80% within 7 days)
- Intake completion (target: ≥ 90% by Day 3)
- Day-7 CSAT (target: ≥ 4.5/5)
- Refund rate (target: ≤ 5%)
- Chargeback rate (target: ≤ 0.5%)

## Cross-references
- Onboarding: `workflows/client-onboarding/week-1.md`
- Delivery: `workflows/delivery/4-week-fulfillment.md`
- Next automation: `workflows/automations/churn-detection.md`
- Knowledge: `reference/knowledge/scale.md` (retention starts here)

---
*v1.0 — 2026-04-19.*
