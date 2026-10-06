# Crisis Management

## Purpose
The playbook for the 6 crisis types a Growth business actually hits: refund storm, negative review wave, tech outage, PR issue, team crisis, legal threat. Each has a first-24-hour script. Operators panic-act without a plan; this document replaces panic with procedure.

## Crisis Tiers

| Tier | Definition | Owner | Response Window |
|---|---|---|---|
| T1 | Threatens survival (cash, legal, PR scale) | Operator | Within 2 hours |
| T2 | Material impact (revenue, team, ops) | Department lead + Operator informed | Within 8 hours |
| T3 | Contained incident | Department lead | Within 24 hours |

Call the tier early and loudly. Mis-tiering is the most common failure.

## Universal First-24-Hour Framework

1. **Name it, tier it** (first 30 min)
2. **Convene war room** (Slack huddle + Notion doc, even for T3)
3. **Assign incident lead** (one person, even if Operator is involved)
4. **Gather facts, don't guess** (first 2 hours)
5. **Stabilize before fixing** (stop the bleed)
6. **Communicate internally first, externally second**
7. **Decide + act with documentation**
8. **Post-mortem within 7 days, always**

---

## Crisis 1 — Refund Storm

**Definition:** Refund rate spikes to 2x baseline, or >5 refund requests in 24h (whichever is smaller), or any single refund request going viral on social.

**First 24-hour script:**

- **Hour 0-2:** CS Mgr pulls the list. Every refund requester named. Pattern search: same campaign? Same cohort? Same product? Same CS rep?
- **Hour 2-4:** Operator + CS Mgr + Marketing Mgr + Closer convene. Confirm root cause hypothesis. 3 candidate causes, rank by evidence.
- **Hour 4-8:** Contact every requester personally. Offer: (a) refund as requested, or (b) named remedy + retention offer. Script below.
- **Hour 8-24:** If pattern confirmed (bad offer, bad promise, bad delivery), pause the upstream funnel for that offer until fixed. Communicate to team.

**Communication template (to requester):**
```
Hi [name],

Thank you for being direct with us about [issue]. I've reviewed your account personally.

Here's what I know: [specific facts about their experience].

Here's what I'd like to do:
Option A — Full refund processed today, no strings.
Option B — [specific remedy: extra coaching call / alternate program / full do-over]
 plus [retention element: extended access / bonus / direct line to me].

Either is fine. Let me know which works, and if you need to talk, I'm at [direct number].

[Operator or CS Mgr name]
```

**Stabilize rule:** approve refunds ≤$5k automatically during a refund storm; don't litigate. Customers escalating to chargebacks are more expensive than the refund.

**Post-mortem checklist:**
- What did the promise vs the reality mismatch look like?
- Was it a sales script issue, a delivery issue, or an expectation-setting issue?
- What changes to the offer/sales/CS flow prevent a repeat?

---

## Crisis 2 — Negative Review Wave

**Definition:** 3+ negative public reviews (Google, Trustpilot, G2, BBB, YouTube comments) in 7 days, OR a single review above 5000 followers / high SEO weight.

**First 24-hour script:**

- **Hour 0-1:** CS Mgr + Marketing Mgr surface every review. Named person per review for outreach.
- **Hour 1-4:** Respond publicly on platform (script below). Private outreach parallel-tracked.
- **Hour 4-8:** Private call/DM with reviewer. Goal: understand first, remedy second, updated review third (never ask for retraction on first contact).
- **Hour 8-24:** Operator reviews each response; adjust if any came across defensive.

**Public response template:**
```
[Name], thank you for the feedback. This isn't the experience we want you to have. I'm [name, role], and I'd like to make it right. I've emailed you directly; please check your inbox. We're reading this carefully and will fix what's broken.
```

**Do:**
- Respond within 24h, named human, not brand voice
- Own specific mistakes, don't generalize
- Move to private channel for resolution

**Don't:**
- Argue facts publicly
- Offer public discount
- Ghost the review
- Respond from an @support@ email — it reads as corporate

**Post-mortem:** pattern check — if reviews cluster around one promise or one person, the system is the problem.

---

## Crisis 3 — Tech Outage

**Definition:** Any system critical to revenue or delivery is down >30 min (CRM, payment, course platform, website, phone).

**First 24-hour script:**

- **Hour 0-15 min:** Ops Mgr or on-call engineer confirms outage, opens incident doc in Notion `/incidents/YYYY-MM-DD-[system]/`
- **Hour 0-30 min:** Post to affected channels. Internal first: #alerts-ops. Customer-facing: status page or email.
- **Hour 30 min-4h:** Work the fix. Named incident lead, named tech lead. Update every 30 min in the incident doc and #alerts-ops.
- **Hour 4-24h:** Post-resolution: send "here's what happened, here's what we're doing to prevent" email to affected customers within 24h.

**Customer comms template (outage >1 hour affecting customers):**
```
Subject: [Service] — service interruption [date] [time] — status update

Between [start] and [end] today, [service] was unavailable. If you tried to [specific thing], it may have failed.

Here's what happened: [plain English, non-technical].
Here's what we did: [fix].
Here's what we're doing to prevent a repeat: [specific action + timeline].

If this affected you specifically, please reply to this email. We'll make it right.

[Operator or CS Mgr name]
```

**Stabilize rule:** during active outage, ONE person speaks to customers (usually CS Mgr). Others work the fix. Channels get confused when multiple people respond.

**Post-mortem within 7 days:** root cause, action items with owners, monitoring/alerting gap that should have caught it earlier.

---

## Crisis 4 — PR Issue

**Definition:** Negative coverage in a publication, viral negative social post (>10k impressions), or public call-out by an influencer or ex-customer.

**First 24-hour script:**

- **Hour 0-1:** Operator + Marketing Mgr + (Legal if applicable). Pull the content. Screenshot and preserve. Do NOT engage yet.
- **Hour 1-4:** Assess: is it factual, inaccurate, or malicious? Different responses per type.
- **Hour 4-8:** Draft response. Legal review if any factual claim. Operator approves.
- **Hour 8-24:** Respond if warranted. Sometimes: don't engage (rare, but real option).

**Response decision tree:**
- Factual complaint → respond publicly, own it, fix it, link to action
- Factually inaccurate → correct the record privately first; respond publicly only if DM fails
- Malicious / bad-faith actor → consult legal; response rarely wins; starve oxygen

**Public response template (factual complaint):**
```
[Name], we hear you. [One sentence acknowledging the specific issue.] Here's what we've done in the last [timeframe]: [concrete actions]. Here's what we're doing next: [specific + dated]. We'd like to talk directly — we've DM'd you. This one is on us.
— [Operator name]
```

**Do:**
- Sign as the Operator, by name, not the brand
- Be specific about actions and timelines
- Say "we were wrong" if we were wrong

**Don't:**
- Lawyer-speak ("allegedly," "we deny")
- Delete comments or block users (except spam or harassment)
- Respond angry; 24h cooling-off minimum on any draft

**Escalation:** If the story is picked up by a real publication (not just social), Operator owns the external comms; bring a PR advisor if revenue is >$2M.

---

## Crisis 5 — Team Crisis

**Definition:** Public resignation, multiple resignations (3+ in 30 days), harassment complaint, team leak of private information.

**First 24-hour script:**

- **Hour 0-1:** Operator + direct mgr + HR/legal advisor convene. Fact-find. Containment first.
- **Hour 1-4:** For harassment complaint: investigation plan opened, accused and complainant separated from reporting line until investigation completes. Never litigate in team Slack.
- **Hour 4-8:** Communicate to affected people privately. Do not address the whole team until facts are established.
- **Hour 8-24:** If multiple resignations: exit interviews scheduled. Pattern analysis (usually a manager). Operator does skip-levels with remaining team within 7 days.

**Single resignation comms template (to team, same day or next day):**
```
Team,

[Name] let me know they're leaving [Company] to pursue [generic description or what they're comfortable saying]. Their last day is [date].

I want to thank [name] for [specific contribution]. We'll miss [specific quality].

In the interim, [continuity plan — who covers what]. We're opening the role this week; details in the hiring channel.

If you have questions, my door is open.
[Operator name]
```

**Multiple resignation response:** The problem is usually a manager. Run skip-levels; if the pattern is confirmed, address the manager per `team-leadership.md`'s firing protocol.

**Harassment complaint:** immediately move to formal HR process. Do not investigate yourself if >10 people. Bring in external HR advisor. Document every step.

---

## Crisis 6 — Legal Threat

**Definition:** Cease & desist letter, lawsuit filed, regulatory inquiry, IP complaint, DMCA notice.

**First 24-hour script:**

- **Hour 0-2:** Operator + Legal counsel (retain within 24h if not on retainer). Preserve all documents. Stop responding publicly.
- **Hour 2-8:** Fact-find with counsel. Assess exposure. Decide internal comms plan.
- **Hour 8-24:** Communicate to team on need-to-know basis. Response to legal correspondence always through counsel, never directly.

**Rules:**
- Do not respond to the threat yourself, ever
- Do not post about it on social
- Preserve everything: emails, DMs, docs, code
- Named single point of contact (counsel) for the matter

**Operator comms to team (if team notices):**
```
Team,

Some of you may have heard about [brief description]. I'm limited in what I can share. I'm working with counsel and will update you as appropriate. Please route any inbound questions to me directly — do not respond individually.

Business as usual for our work this week.
[Operator name]
```

**Post-resolution:** process review — what business practice led to exposure? Close the gap.

---

## Post-Mortem Requirement (ALL Crises)

Within 7 days of resolution (or stabilization if resolution takes longer), a blameless post-mortem is delivered. Format:

```
## Crisis Post-Mortem — [crisis name] — [date]

### Summary
[2-3 sentences: what happened, impact, status]

### Timeline
- [time] — [event]
- [time] — [event]

### Root cause
[1-2 paragraphs; go past the first cause to the system-level cause]

### What worked
- [bullet]

### What didn't work
- [bullet]

### Action items (owners + dates)
- [ ] [action] — [owner] — [due]

### Prevention / monitoring
[What signal would catch this next time earlier?]

### Comms log
[Links to internal + external comms sent]
```

Shared in Notion `/incidents/YYYY-MM-DD-[crisis]/` and reviewed at next leadership weekly.

## Crisis Drills (Preventive)

Once a year, tabletop each of these 6 crisis types. 90-min drill per type, with leadership. Build muscle before you need it.

## Metrics / Success Criteria
- 100% of crises get a named incident lead within 2 hours
- 100% of T1/T2 crises get post-mortem within 7 days
- Customer comms issued within the windows above
- No crisis-caused regulatory fines or litigation settlements >$10k in a rolling 12 months
- 1 tabletop drill per crisis type per year

## Failure Modes
- **Silence.** Hoping it goes away. Never does. Fix: the 24-hour script is not optional.
- **Over-response.** Apologizing for things we didn't do. Fix: facts first, then response.
- **Multiple voices.** 3 team members responding to a negative review. Fix: ONE voice rule, named.
- **No post-mortem.** Same crisis recurs. Fix: post-mortem gate before the crisis closes.
- **Operator responds emotionally at 11pm.** Fix: 24-hour cooling off on any draft; peer review before publishing.

## Cross-references
- Skills: `skills/incident-lead/`, `skills/post-mortem/`, `skills/customer-comms/`
- Frameworks: `frameworks/incident-template/`, `frameworks/refund-script/`
- Other operations docs: `team-collaboration.md`, `team-leadership.md`, `cadences-weekly.md`

---
*v1.0 — 2026-04-19.*
