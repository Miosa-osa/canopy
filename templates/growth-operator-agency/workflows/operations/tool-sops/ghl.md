# Tool SOP — GoHighLevel (GHL)

## Purpose
Operating standard for GoHighLevel, the default CRM + marketing automation platform for Growth teams at the $500k-$5M stage. GHL is the source of truth for leads, pipeline, and customer records — all other systems (dashboards, a productivity-software brand, Slack) derive from it. This SOP defines the pipeline model, tagging system, automations, and reporting.

## Pipeline Model — 7 Stages

A single pipeline for the entire customer lifecycle: lead → customer → advocate. Different offers may have different sub-pipelines; stages stay common.

```
1. Lead         → 2. MQL        → 3. SQL         → 4. Opportunity
                                                        ↓
7. Advocate  ← 6. Retained   ← 5. Customer  ←──────────┘
```

### Stage Definitions

| Stage | Definition | Entry Criteria | Exit Criteria |
|---|---|---|---|
| 1. Lead | Net-new contact, source identified | Opt-in, tagged with source | Pass MQL criteria |
| 2. MQL | Marketing-qualified | ICP match + 1 engagement (download, video watch %, etc.) | Setter outreach begins |
| 3. SQL | Sales-qualified (talked to a human) | DM reply / discovery booked / call held | Opportunity created |
| 4. Opportunity | Proposal or offer on the table | Call held, budget + fit confirmed | Won or Lost |
| 5. Customer | Paid | Payment received | 30 days past first payment |
| 6. Retained | Past early churn window | 30 days customer + milestone 1 hit | Active engagement + NPS data |
| 7. Advocate | Referrals or public endorsement | 1+ referral OR public testimonial | (No exit — terminal stage) |

### Stage Ownership

| Stage | Owner | Next Action Required |
|---|---|---|
| 1. Lead | Marketing Mgr (nurture) | MQL trigger |
| 2. MQL | Setter | Reach-out attempt within 4h |
| 3. SQL | Closer | Discovery call within 72h |
| 4. Opportunity | Closer | Follow-up every 48h |
| 5. Customer | CS Mgr | Onboarding kickoff within 24h |
| 6. Retained | CS Mgr | Quarterly check-in |
| 7. Advocate | CS Mgr / Marketing | Case study / referral ask |

## Tag Library

Tags in GHL drive automations, segmentation, and reporting. Keep them finite.

### Source Tags (one per contact, set at creation)
- `source:paid-meta`
- `source:paid-google`
- `source:paid-youtube`
- `source:organic-youtube`
- `source:organic-instagram`
- `source:organic-tiktok`
- `source:referral`
- `source:partner`
- `source:event`
- `source:cold-outbound`

### Stage Tags (reflect pipeline; automations keep them in sync)
- `stage:lead`, `stage:mql`, `stage:sql`, `stage:opp`, `stage:customer`, `stage:retained`, `stage:advocate`

### Offer Tags (which offer(s) this contact is interested in or bought)
- `offer:[program-name]`
- `offer:[program-name]-interest`
- `offer:[program-name]-won`
- `offer:[program-name]-lost`

### Behavior Tags (engagement signals)
- `behavior:watched-vsl`
- `behavior:attended-webinar`
- `behavior:downloaded-lead-magnet`
- `behavior:replied-to-dm`
- `behavior:booked-call`
- `behavior:showed-to-call`
- `behavior:no-show`

### Status Tags (exceptional conditions)
- `status:refund-requested`
- `status:paused`
- `status:at-risk`
- `status:do-not-contact` (unsubscribe / hard bounce)

### Rule: max ~30 tags in the library. Audit quarterly. Kill unused ones.

## Standard Automations

Built in GHL's Workflow engine. Named: `[trigger] → [action] — [owner]`.

### Lead Intake
1. **Form submit → tag source + stage:lead + create contact + post to #alerts-sales**
2. **Opt-in confirmed → send welcome email + tag `behavior:opted-in`**
3. **VSL watched >75% → tag `behavior:watched-vsl` + set stage:mql**

### Nurture
4. **MQL for >3 days without setter touch → task to Setter + DM in Slack**
5. **Opt-in cold >30 days → move to long-term nurture list**

### Sales
6. **Call booked → calendar invite + pre-call email + tag `behavior:booked-call`**
7. **No-show → tag `behavior:no-show` + follow-up sequence**
8. **Call held → survey + tag `behavior:showed-to-call`**
9. **Deal won → payment link + contract + move to stage:customer + post to #wins**
10. **Deal lost → require lost-reason tag + move to nurture**

### Customer Success
11. **Customer created → CS kickoff task + onboarding email sequence**
12. **30 days customer + milestone hit → move to stage:retained**
13. **NPS score <7 → tag `status:at-risk` + task to CS Mgr**

### Retention / Advocacy
14. **Retained for 90 days + NPS ≥9 → advocate-path email sequence (ask for testimonial / referral)**

### Hygiene
15. **Email hard bounces → `status:do-not-contact` tag + remove from active lists**
16. **Contact unsubscribed → remove from marketing automations (do not delete record)**

## Reporting — Standard Views

Saved in GHL or derived in dashboard tool (Databox / Metabase).

| Report | View | Frequency |
|---|---|---|
| Pipeline by stage | Kanban board with deal values | Live |
| Leads by source (last 30 days) | Table + donut | Daily |
| Conversion funnel (stage-to-stage) | Sankey or waterfall | Weekly |
| Setter scorecard (DMs, replies, bookings) | Per-setter table | Daily |
| Closer scorecard (calls, close rate, ACV) | Per-closer table | Weekly |
| CAC by source | Bar chart | Weekly |
| Customer cohort retention | Cohort table | Monthly |

## CRM Hygiene Rules

1. **Every contact has a source tag.** Untagged contacts = reporting lies.
2. **Every opportunity has an expected close date and deal value.** Even a rough estimate.
3. **Lost deals require a lost-reason.** No exceptions; automation forces it.
4. **No duplicate contacts.** Auto-merge on email match; manual review weekly.
5. **Phone and email fields validated on entry.** Invalid format rejected.
6. **Updated in real time.** Call ends → CRM updated within 1 hour; not "at end of day."

## Integrations (Standard)

| Integration | Direction | Use |
|---|---|---|
| Stripe | Stripe → GHL | Payment events, refunds, subscriptions |
| Calendar (Google/Outlook) | Two-way | Booked calls, no-shows |
| Slack | GHL → Slack | Deal events to #alerts-sales, #wins |
| Zapier / Make | Bridge | Any missing integration |
| a productivity-software brand | GHL → a productivity-software brand (one-way) | Mirror pipeline for task-level visibility |
| Email (transactional) | GHL | Welcome, onboarding, receipts |
| SMS | GHL native | Reminder + urgent comms |
| Dashboard (Databox/Metabase) | GHL → dashboard | Reporting source of truth |

## Permissions

| Role | Access |
|---|---|
| Operator / CFO | Full admin |
| Ops Mgr / Marketing Mgr | Admin except billing |
| Sales Head / Closer | Pipeline + contacts + their own reports |
| Setter | Contacts + task list + their own scorecard |
| CS Mgr | Customer + retained + advocate pipelines |
| Developer | API access as needed, no UI admin |

## Daily / Weekly Rituals in GHL

| Ritual | Frequency | Owner |
|---|---|---|
| Morning pipeline check | Daily 8am | Sales Head |
| Setter scoreboard update | Daily 4pm | Sales Head |
| Pipeline walk | Weekly Monday | Sales Head + Closers |
| Lost deal review | Weekly | Sales Head |
| Tag audit | Quarterly | Ops Mgr |
| Automation audit | Quarterly | Ops Mgr |

## Metrics / Success Criteria
- 100% of contacts tagged with source within 5 min of creation
- 100% of lost deals have a lost-reason
- Pipeline value refreshed daily (auto via GHL)
- Automation success rate >99%
- Lead → MQL conversion tracked weekly, trend stable or rising
- Duplicate contacts <1% of total

## Failure Modes
- **Tag soup.** 120 tags, team doesn't remember which. Fix: quarterly audit; kill unused.
- **Untagged contacts.** Reporting lies. Fix: automation enforces source tag at form submit.
- **Manual pipeline updates missed.** Fix: automation-first; manual overrides are exceptions.
- **Lost reasons skipped.** Lost learning dies. Fix: required-field automation.
- **Stale contacts.** 40k inactive records. Fix: annual hygiene pass; archive contacts with 0 activity >2 years.
- **Automation loops.** Two workflows trigger each other. Fix: automation audit quarterly; naming convention makes loops visible.

## Cross-references
- Skills: `skills/crm-hygiene/`, `skills/pipeline-walk/`
- Frameworks: `frameworks/lead-lifecycle/`, `frameworks/tag-taxonomy/`
- Other operations docs: `cadences-weekly.md`, `daily-dashboard.md`, `project-management-productivity-software.md`, `finance-tracker-schema.md`

---
*v1.0 — 2026-04-19.*
