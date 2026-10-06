# Automation — Referral Trigger

## Purpose
Ask for referrals at the moment of peak happiness: right after a customer hits a meaningful win. Automation tracks the win, fires the referral ask within 24h, tracks the introduction, pays out correctly, and loops learnings back.

## Trigger Conditions
Fire when one of the following "happy-moment" signals hit:
- **Result Win**: customer hits a pre-agreed outcome metric (first sale, first hire, first $10K month, etc.)
- **NPS 9–10**: high-score survey response
- **Case-study completion**: customer provides case-study content
- **Milestone Renewal**: customer renews for Year 2+
- **Spontaneous Praise**: customer sends unprompted compliment (Slack, email, review)

## End-State
- Referral ask delivered within 24h of signal
- Referral link/code issued, tracked
- Referral submissions captured and routed to sales
- Reward processed on qualifying conversion
- Customer receives confirmation + appreciation
- Event logged for future optimization

## Flow Diagram
```
[Happy-moment signal detected]
      │
      ▼
[Tag customer in CRM: referral-ready]
      │
      ▼
[Compose + send referral ask within 24h]
      │
      ▼
[Customer submits referral via form or share link]
      │
      ▼
[Track introduction: tag referred lead with referrer_id]
      │
      ▼
[Referred lead progresses through standard nurture]
      │
      ▼
[Conversion → reward processing]
      │
      ├── Referrer receives reward
      ├── Thank-you + public recognition (optional)
      └── Loop: referrer becomes stronger advocate → next cycle
```

## Step-by-Step

**Step 1. Signal Detection**
- **Result Win**: monitored via delivery tracking (per-engagement metric)
- **NPS**: captured via survey tool, score ≥ 9 fires
- **Case-study**: when `/case-study` skill produces an approved artifact
- **Renewal**: billing webhook on Year-2+ renewal
- **Spontaneous praise**: manual tag by delivery lead when witnessed

**Step 2. Tag + Queue**
- CRM tag: `referral-ready:{signal_type}:{YYYY-MM-DD}`
- Task created for owner: "send referral ask"
- Timing rule: 24h after signal (not immediate; let the win land)

**Step 3. Send Referral Ask**
- Channel: email (primary), Slack/WhatsApp (if preferred channel known)
- Personal, not generic — reference the specific win
- Subject: `{First_name} — quick ask (now that the {win} happened)`
- Body structure:
  1. Name the win specifically
  2. Ask if they know 1–2 people who would benefit from same
  3. Offer reward (tiered by referral value)
  4. Include one-click share link + form link
  5. Make it easy (no essay required)

**Step 4. Share Options**
- Unique referral link with `?ref={customer_id}` parameter
- Pre-filled intro template customer can forward
- Direct submit form ("tell us who to reach out to")
- Tracked short URL for SMS / social sharing

**Step 5. Track Introduction**
- Any new lead with `ref={customer_id}` tagged `referred_by:{customer_id}`
- Any referred lead inbound via form: record `referrer` explicitly
- Source of truth: single referral attribution table

**Step 6. Sales Handoff for Referred Lead**
- Referred leads routed to high-intent path in `lead-to-crm.md`
- Sales owner notified with context: referrer name + relationship
- First contact mentions mutual connection

**Step 7. Conversion → Reward**
- On qualifying conversion (customer purchases + clears refund window), reward triggers
- Reward types (by value):
  - < $1K referred purchase: $100 credit or $100 gift
  - $1K–$10K: $500 credit or $500 cash
  - $10K+: $1,000+ cash or 10% of first payment (whichever higher)
- Payment via same W-9/W-8 process as affiliate (1099-NEC at year-end for $600+)

**Step 8. Thank-You + Recognition**
- Email: `{first_name} — your referral {referred_name} just became a customer. Here is your {reward}.`
- Optional: public recognition (LinkedIn shoutout, newsletter mention) — with permission
- Log event in CRM: `referral_rewarded:{YYYY-MM-DD}:{amount}`

**Step 9. Loop: Next Ask**
- Tag customer `referrer:{count}` — incremented on every successful referral
- Customers with count ≥ 2 qualify for "Ambassador" tier with higher rewards + recognition
- Ambassador tier triggers quarterly "refer a peer" check-in

## Fillable Config
```yaml
signal_triggers:
  result_win: true
  nps_min_score: 9
  case_study_completion: true
  renewal_year_min: 2
  spontaneous_praise: true
ask_delay_hours: 24
ask_owner: {delivery_lead_email}
reward_tiers:
  under_1k: { type: credit, amount: 100 }
  under_10k: { type: cash, amount: 500 }
  over_10k: { type: percentage, amount: 10 }  # 10% of first payment
refund_window_days: 14
thanks_email: true
public_recognition: optional  # requires written consent
ambassador_threshold: 2  # successful referrals to qualify
```

## Sample Filled
```yaml
signal_triggers:
  result_win: true
  nps_min_score: 9
  case_study_completion: true
  renewal_year_min: 2
  spontaneous_praise: true
ask_delay_hours: 24
ask_owner: ops@example.com
reward_tiers:
  under_1k: { type: credit, amount: 100 }
  under_10k: { type: cash, amount: 500 }
  over_10k: { type: percentage, amount: 10 }
refund_window_days: 14
thanks_email: true
public_recognition: optional
ambassador_threshold: 2
```

## Sample Referral Ask Email (NPS 9 trigger)
```
Subject: Alex — one quick ask (if you're up for it)

Alex —

Just saw your NPS came in at a 10 with the note that the Q1 launch hit $142K.
That is exactly the kind of story we are trying to help more founders write.

One ask: is there one person in your world — another founder transitioning
services to software, or hitting the wall around $30K MRR — who you think
would get the same kind of result?

If so, two options:
- Forward this email to them and cc me
- Or send me their name / LinkedIn and I'll reach out directly

Either way, if they end up working with us, you get $500 cash (standard referral).
If they're at enterprise scale, 10% of their first engagement.

No pressure at all. Just thought the question was worth asking now,
while the launch is fresh.

— Syed
```

## Failure Modes + Handling
| Failure | Detection | Response |
|---|---|---|
| Signal fires but ask never sent | Task overdue > 48h | Alert ops; send manually |
| Referral link not attributing | Analytics gap | Check UTM + cookie; verify ref param on destination |
| Duplicate attribution (two refs to same lead) | Referral table | First-touch wins; document rule |
| Reward not processed on conversion | Post-clearance audit | Ops reconciles weekly; pay with interest if late |
| Customer declines referral ask | Response tracking | Do not re-ask for 90 days |

## Compliance
- [ ] Referral program disclosed (FTC — if reward is material)
- [ ] Tax reporting: 1099-NEC for $600+ / year
- [ ] GDPR: referrer needs consent to share third-party contact details (we contact them, not referrer sharing unauthorized)
- [ ] Anti-spam: no mass-forwarding templates that could be mistaken for unsolicited marketing

## KPIs
- Referral rate (target: ≥ 15% of happy-moment customers generate ≥ 1 referral)
- Referral-to-customer CVR (target: ≥ 40%, much higher than cold)
- Referral LTV (target: ≥ 1.2× average cohort LTV)
- Time-from-signal-to-ask (target: ≤ 24h)
- Ambassador count (target: growing month-over-month)
- Reward payout speed (target: ≤ 7 days after conversion cleared)

## Cross-references
- Skill: `skills/referral-program/`
- Knowledge: `reference/knowledge/partnerships.md`
- Pipeline: `workflows/divisions/partnerships-pipeline.md`
- Automations: `workflows/automations/purchase-to-onboarding.md` (referred-lead entry), `workflows/automations/lead-to-crm.md` (attribution)

---
*v1.0 — 2026-04-19.*
