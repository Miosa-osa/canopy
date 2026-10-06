# Client Onboarding — Week 1

## Purpose
Set tone, expectations, and pace. By end of Week 1: client is welcomed, kicked off, workspace is live, expectations are signed, first deliverable is shipped or dated. The client should finish Week 1 feeling relieved, not overwhelmed.

## Outcomes (definition of done)
- [ ] Welcome email + portal access delivered (Day 1)
- [ ] Signed agreement + payment cleared (Day 1–2)
- [ ] Kickoff call held (Day 3–5)
- [ ] Workspace provisioned (Day 3)
- [ ] Expectations document signed (Day 5)
- [ ] First deliverable shipped OR calendared (by Day 7)
- [ ] Week-1 satisfaction scored (CSAT ≥ 4.5/5)

## Day-by-Day

### Day 1 — Welcome
- [ ] Automated welcome email fires on payment (see `automations/purchase-to-onboarding.md`)
- [ ] Portal / workspace access granted
- [ ] Founder-signed personal note (video or text) sent manually — this is not automated
- [ ] Calendar link for kickoff sent
- [ ] FAQ + "what to expect this week" doc attached

### Day 2 — Admin + Intake
- [ ] Client fills intake form (ICP, offer, current state, goals, assets, access)
- [ ] Contract / agreement countersigned
- [ ] Payment confirmation on file
- [ ] Communication preferences captured (Slack / email / loom / voice)

### Day 3 — Workspace Provisioned
- [ ] Drive / Notion / portal created with client-specific structure
- [ ] Read-only access to shared assets (SOPs, templates, swipe file)
- [ ] CRM record created + tagged
- [ ] Internal team Slack channel created
- [ ] Kickoff agenda sent 24h before call

### Day 4–5 — Kickoff Call (60 min)
Agenda:
1. Welcome + re-state why they chose us (2 min)
2. Confirm goals + success metrics (10 min)
3. Walk through 4-week fulfillment plan (15 min)
4. Confirm access: ad accounts, analytics, email platform, landing page builder, CRM (10 min)
5. Expectations: cadence, response times, feedback loops (10 min)
6. Risks + dependencies surfaced (5 min)
7. First-week deliverable locked + date set (5 min)
8. Q&A (3 min)

### Day 5 — Expectations Document
- [ ] SLA: response within 24 business hours; deliverable dates; escalation path
- [ ] Cadence: weekly call day/time, daily Slack async, weekly written report
- [ ] Decision-rights: what client owns, what we own, what's jointly decided
- [ ] Change-order process: scope additions are documented and quoted before execution
- [ ] Signed by both parties

### Day 6–7 — First Deliverable or Dated Commitment
- [ ] If Foundations client: `research-brief.md` draft ready OR intake review + research scoped
- [ ] If Scale client: current-state audit delivered
- [ ] If Launch client: launch-plan.md v0 delivered
- [ ] CSAT pulse survey sent (1 question: "How is Week 1 going? 1–5")

## Artifacts Produced
- `output/onboarding/{client}/kickoff-notes.md`
- `output/onboarding/{client}/expectations.md` (signed)
- `output/onboarding/{client}/week-1-csat.md`
- `output/onboarding/{client}/intake.md`
- Calendar invites for Week 2 + Week 3 + Week 4 + 30/60/90-day milestones
- CRM tags: `onboarded-{date}`, `offering-{sku}`, `ltv-tier-{est}`

## Fillable Template Variables
- `{client_name}` — client legal + display name
- `{offer_sku}` — which offering they bought
- `{start_date}` — contracted start date
- `{success_metric}` — primary outcome (e.g., "book 10 calls in 30 days")
- `{kickoff_datetime}` — calendar-locked
- `{primary_contact}` — decision-maker
- `{delivery_lead}` — our point of contact
- `{weekly_cadence}` — day + time

## Sample Filled Week-1 Plan
- `{client_name}`: {CLIENT_NAME} / Alex
- `{offer_sku}`: Growth Operating Agency Quarterly ($25K)
- `{start_date}`: 2026-04-22
- `{success_metric}`: Full foundations + live funnel + first 5 cold demos booked by Day 60
- `{kickoff_datetime}`: 2026-04-24 at 14:00 PT
- `{primary_contact}`: {FOUNDER_NAME} ({FOUNDER_ROLE})
- `{delivery_lead}`: Syed
- `{weekly_cadence}`: Tuesdays 14:00 PT (60 min)

Day-1 email opens: "{FOUNDER_NAME} — welcome to {WORKSPACE_NAME}. Here is what we are going to do in the next 90 days, starting Tuesday..."

## Common Risks to Pre-empt
- Client over-scoped their own goals in sales process — surface + re-contract at kickoff
- Access bottlenecks (ad account, Stripe, ESP) — ask for them on Day 2, not Day 10
- Stakeholder not on kickoff — require decision-maker attendance or reschedule
- Silence after Day 5 — Day-6 check-in is required, not optional
- Wrong communication channel — confirm default in Day-1 email

## Escalation Path
- L1: Delivery lead handles in 24h
- L2: Department lead loops in if L1 misses SLA
- L3: Founder owns if > 48h unresolved OR contract-risk signal

## Cross-references
- Automation: `workflows/automations/purchase-to-onboarding.md`
- Next: `workflows/client-onboarding/90-day.md`
- Delivery: `workflows/delivery/4-week-fulfillment.md`
- Templates: `workflows/execution-templates/daily-standup-template.md`, `workflows/execution-templates/weekly-review-template.md`

---
*v1.0 — 2026-04-19.*
