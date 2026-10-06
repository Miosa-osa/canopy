# $200k/mo Outreach Operating System

> **Why this matters:** Content-led funnels plateau. When an operator has a validated $5k–$30k offer but the inbound flow is inconsistent — or they don't have the content discipline to compound — a disciplined outbound operating system can carry $200k/mo with a solo founder + 2–3 setters. This playbook is the reference architecture: ICP filters, 5-message sequence, daily targets, handoff mechanics, compliance guardrails, and failure modes. It is what Growth Operating Agency recommends for operators who are stronger at diagnosis than at publishing.

## Source / Lineage

- Synthesized from 2023–2025 outbound operator patterns on LinkedIn (primarily Sales Navigator + Dripify/Expandi stacks)
- Calibrated to post-2024 LinkedIn TOS enforcement (connection-request throttling, unavoidable automation detection at high volume)
- Economics verified against 2–3 setter team P&Ls selling $5k–$25k offers to B2B operators
- Assumes ICP + offer already validated per `reference/frameworks/foundations-methodology.md`

## Architecture Overview

```
[ICP filter (Sales Nav)]
        ↓
[Daily CR send (connection request)]
        ↓
[Acceptance]
        ↓
[5-message sequence over 14–21 days]
        ↓
[Positive reply]
        ↓
[Qualification DM thread]
        ↓
[Handoff to closer / book call]
        ↓
[Call + close]
```

Two viable team shapes:

- **Solo operator:** One person runs ICP, outreach, qualification, and calls. Cap ~$80k–$100k/mo.
- **2–3 setter team:** Setters run ICP + messaging + qualification. Founder (closer) takes booked calls only. Cap ~$200k–$300k/mo before needing a second closer.

Growth Operating Agency default: start solo to pressure-test ICP + sequence, then add setters once the sequence → booked-call rate stabilizes above 3%.

## ICP Filter Criteria (LinkedIn Sales Navigator)

The ICP filter is the single highest-leverage variable in the entire system. A tight ICP raises reply rate 3–5x vs a loose one.

**Standard filter stack (adjust to offer):**

| Field | Setting | Why |
|---|---|---|
| Geography | Operator-time-zone ± 4 hours | Enables same-day reply thread |
| Industry | 2–4 specific industries (not "broad") | Sequence language stays specific |
| Company size | 2–10 / 11–50 / 51–200 (pick one band) | Budget + decision-speed matches offer |
| Seniority | Owner / C-level / VP / Director (pick 1–2) | Decision-maker, not influencer |
| Years in current role | 1–5 years | Still ambitious, not entrenched |
| Years of experience | 5+ | Has budget authority + pain accumulation |
| Posted on LinkedIn in last 30 days | Yes | Active user → higher reply rate |
| Changed jobs in last 90 days | Exclude | New-in-role has no budget authority |
| Excluded connections | 1st-degree | Don't re-touch existing network |

**Saved search size target:** 800–2,500 profiles. Under 800 = too tight, sequence will run out. Over 2,500 = too loose, reply rate will tank.

Build 3–5 saved searches per offer and rotate weekly to keep freshness.

## 5-Message Sequence (14–21 days)

Total 5 messages from acceptance to final ask. Spaced to avoid algorithm flagging and prospect fatigue.

### Message 1 — Connection request (with note)

Day 0. Personal, specific, under 250 chars. No pitch.

> "Hi [First name], saw your [specific trigger — a post, a recent hire, a company milestone]. Curious how [specific observation about their business / role]. Thought worth connecting."

**Rules:** Reference one specific thing from their profile or activity. Do not mention your offer. Do not ask a question.

### Message 2 — Value / framing (Day 2–3 post-acceptance)

First message after acceptance. Purpose: open a conversation, not pitch.

> "[First name] — appreciate you connecting. Quick context: I work with [ICP segment] on [specific outcome]. Was reading your post on [topic] — your take on [specific point] matches what we're seeing with [adjacent customer segment]. Couple of our clients at [similar-stage company] hit [specific problem] around the [X month] mark. Curious — is [specific related challenge] on your radar at all, or pretty locked in?"

**Rules:** Specific reference to their content. Name-drop a problem pattern, not the offer. End with a low-stakes question.

### Message 3 — Soft pitch (Day 7–8 if no reply, Day 3 if prior reply)

If no reply to M2: re-open. If prior reply: transition to offer shape.

**No-reply variant:**

> "Hey [first name] — no worries if not relevant, but wanted to ask: are you currently [specific problem framed as question]? If yes, I have a [resource / note / framework] I've been sharing with [ICP] this month that might be useful. Happy to send over — just let me know."

**Prior-reply variant:**

> "That makes sense. The pattern we see most often with [ICP] at [stage] is [specific mechanism insight]. We run a [mechanism name] that [outcome] — usually 60–90 days. Worth a 20-min call to see if it fits?"

### Message 4 — Case study (Day 12–14 if no reply)

Proof. Numbers-first.

> "[First name] — last note in case timing was off. We just wrapped with [anonymized client: '"a Series A B2B SaaS founder'"] — went from [specific before-state metric] to [specific after-state metric] in [timeframe]. Full breakdown here [link or 'happy to send']. If this shape of problem is on your plate, worth a chat. If not, all good — I'll stop bugging you."

**Rules:** One specific client. One specific number. Explicit "I'll stop bugging you" — this is what triggers replies.

### Message 5 — Hard ask / break-up (Day 19–21)

Final touch. Break-up framing.

> "Okay, [first name] — taking this as a no for now, which is totally fine. Closing the loop. If things change and [specific problem] becomes a priority, reply to this message and I'll circle back. Otherwise I won't hit you up again. Appreciate the connection."

**Rules:** Break-up messages get 8–15% reply rate on otherwise-cold prospects. The "I won't hit you up again" is load-bearing — do not break it (pay off in 60 days if at all).

## Daily Targets Per Setter

| Activity | Target | Time |
|---|---|---|
| Connection requests sent | 25–50/day | 45 min |
| Follow-up messages (M2–M5) | 75–150/day | 90 min |
| Qualification DM threads | 5–15/day | 60 min |
| Booked call handoffs | 1–3/day | 15 min |
| Sales Nav list maintenance | Weekly refresh | 60 min/week |

**Hard ceiling:** 100 CRs/day per LinkedIn account. Above that = TOS violation + restriction. 30–50 is the sustainable band.

**LinkedIn weekly CR limit:** ~100–200 connection requests per week per account (enforced since 2021, variable). Treat 150/week as the ceiling.

## Qualification → Handoff

When a prospect replies positive-intent ("yes interested" / "tell me more" / "what does it cost"):

1. **Setter sends qualification questions** in-thread (3 questions max):
   - Current state on [specific metric or outcome]
   - What they've tried
   - Timeframe / urgency
2. **Setter proposes a call** with closer: "Makes sense — quickest next step is a 30-min call with [closer name] who leads our [offer area]. Here's the link: [Calendly]. Book a slot that works."
3. **Setter tags prospect in CRM** with qualification notes + LinkedIn thread link.
4. **Closer reviews notes before call** — 5 min prep. Call script follows Mentorship Funnel playbook `[call section]`.

Handoff SLA: prospect goes from positive reply → booked call within 24 hours or the thread cools off.

## Stack (reference only — tools change)

| Tool | Role | Alternative |
|---|---|---|
| LinkedIn Sales Navigator | ICP filter + saved searches | — (required) |
| Dripify / Expandi / Heyreach | Semi-automated message sequence | Manual (caps at ~30% of automated volume) |
| GoHighLevel (GHL) / Close.com | CRM + scheduling + pipeline | Pipedrive, HubSpot |
| Calendly / SavvyCal | Call booking | GHL native calendar |
| Loom | Personalized video follow-up (optional) | Vidyard |
| ChatGPT / Claude | ICP research + message personalization | — |

**Automation caveat:** Dripify/Expandi violate LinkedIn TOS strictly read. In practice LinkedIn tolerates moderate automation (≤50 CRs/day, human-paced sends) but enforces against high-volume bot behavior. At $5k–$30k offer prices, **human-sent qualification DMs (M3+) are non-negotiable** — a bot reply thread will kill conversion. Use automation for M1/M2/reminders only.

## Compliance (LinkedIn TOS + buyer trust)

- **No bots for high-ticket conversations.** At $5k+, prospects detect automated responses within 2 messages. Sequence must hand off to human by M2 reply.
- **Respect weekly CR limits.** 100–150/week per account. Running 2 accounts ≠ 300/week — detection correlates across accounts.
- **No scraping email outside LinkedIn.** Pulling emails via Apollo/RocketReach and cold-emailing prospects you connected with on LinkedIn = GDPR + CAN-SPAM risk depending on jurisdiction. Keep the conversation on-platform until the prospect volunteers their email.
- **One account per person.** Multiple accounts per operator = ban risk. Scale via hiring setters with their own accounts, not via multi-accounting.
- **Data retention:** CRM notes about prospects — treat as PII. Delete on request.

## Economics

Benchmarks for a disciplined 2–3 setter team on a $5k–$15k offer:

| Metric | Range | Notes |
|---|---|---|
| CR → acceptance | 25–40% | Below 25% = CR note or ICP off. Above 40% = unusually strong positioning. |
| Acceptance → M2 reply | 10–20% | Specific reference to their content is the main lever. |
| M2–M5 → positive intent | 3–8% of accepted | Sum across sequence. |
| Positive intent → booked call | 40–60% | Qualification thread is the filter. |
| Booked call → show rate | 50–70% | Outbound-sourced calls show at ~15% lower rate than inbound. |
| Call → close rate | 25–35% | Outbound prospects close ~5pp lower than inbound; less pre-call warmth. |
| Cost per booked call | $50–$150 | Setter time + tools, allocated. |
| Revenue per booked call (show-weighted) | $800–$3,500 | At $8k AOV, 65% show, 30% close = $1,560 |
| Setter comp | $2k–$4k base + $150–$400 per closed deal | Total OTE $4k–$10k/mo |

**Path to $200k/mo on $10k offer:** 20 closes/mo → ~70 calls/mo → ~130 booked → ~260 positive-intent → ~3,500 accepted connections → ~10,000 CRs sent. Split across 3 setters at 150 CRs/week each = tight but achievable.

## Failure Modes + Recovery

| Failure mode | Symptom | Fix |
|---|---|---|
| Low CR acceptance | Under 25% | ICP too broad, or CR note generic. Rewrite note with specific trigger. |
| Low M2 reply | Under 10% | M2 too pitch-y. Cut to 2 sentences. Reference specific post. |
| High reply, low positive-intent | Replies but all "not interested" | Offer/ICP mismatch. Audit last 20 replies for pattern. Re-filter. |
| Positive intent but no booked call | Prospect ghosts after qualification | Setter is over-qualifying. Cut to 3 questions max, propose call fast. |
| Booked calls, low show rate | Under 50% | Time-to-call too long. Book within 48h of positive reply. Add SMS reminder. |
| Calls, low close rate | Under 25% | Closer is skipping diagnosis. Review call recordings. Enforce 15-min diagnosis block. |
| Account restricted (LinkedIn jail) | Can't send CRs for 24–72h | Cut volume 50% for 2 weeks. Switch to manual for 30 days. Never run at pre-restriction volume. |
| Setter burnout / churn | Setter quits after 3 months | Rotate ICP lists weekly. Pay per closed deal not per booked call. Cap daily CR count. |
| Brand damage (negative public post about spam) | Viral complaint | Pause sequence 72h. Audit last 500 messages for any that read as bot. Rewrite M1 + M2. |

## When to run this playbook

**Good fit:**
- Offer $5k–$30k, B2B, targeting operators/founders/executives
- Operator has diagnosis skill but weak/inconsistent content cadence
- Willing to hire + manage 1–3 setters OR disciplined enough to run solo at 100–150 CRs/week
- Offer has a specific ICP definable in Sales Nav filters
- Can sustain 60–90 days of list-building before compounding kicks in

**Not a fit:**
- Offer under $3k — economics break (setter cost > margin)
- Consumer / B2C offers
- Highly regulated industries (healthcare, finance) where LinkedIn outreach triggers compliance issues
- Operator unwilling to read 200+ messages/week to catch bot-feel drift
- No validated offer yet — do not scale a bad offer via outbound

## How this applies in Growth Operating Agency

- **Skills:** `icp-filter-builder`, `sequence-writer`, `qualification-designer`, `call-handoff-scripter`
- **Agents:** `outbound-department-agent` runs the whole sequence end-to-end. `sales-department-agent` takes booked calls. `ops-department-agent` manages CRM + handoffs.
- **Sub-agents:** `sales-nav-filterer`, `message-personalizer`, `compliance-auditor`, `setter-scorecard`
- **Knowledge sources:** `reference/frameworks/foundations-methodology.md`, `reference/frameworks/icp-deep-dive.md`, `reference/frameworks/sales/`
- **Operator artifacts touched:** `output/foundations/icp-document.md`, `output/foundations/offer-document.md`, new `output/outreach/sequence-v*.md` + `output/outreach/compliance-log.md`

## INV-8 Scope Note

**This playbook is scoped to the operator running outbound for THEIR OWN offer, on THEIR OWN LinkedIn account (or a small in-house setter team on their own accounts).** It is explicitly NOT:
- A done-for-you LinkedIn outbound agency service offered to external clients
- A multi-tenant lead-gen SaaS
- A LinkedIn consulting retainer
- A "we'll run outbound for you" productized service

If a founder wants to sell outbound-as-a-service to others, that is a separate workspace (`linkedin-agency-os`, future) with very different economics, tooling, and delivery. Growth Operating Agency assumes the operator is the seller, the offer, and the eventual closer.

## Non-applicable scenarios

- **Enterprise 6-figure deals** — need ABM, multi-stakeholder, marketing-ops support; outbound is one input of many
- **Marketplace / two-sided platforms** — outbound to one side doesn't solve the chicken-and-egg
- **Transactional / commodity offers** — SEO + paid ads beat outbound on unit economics
- **Founder-led outbound with no setter capacity** — if founder also closes, outbound above ~100 CRs/week cannibalizes close-time
- **Regions where LinkedIn is not dominant** (Japan, China) — use native platforms

## Cross-references

- `reference/playbooks/mentorship-funnel-97k.md` — inbound-first complement for operators who can publish
- `reference/operators/external/outreach-director.md` — outbound-volume archetype (5000+ calls operator)
- `reference/frameworks/icp-deep-dive.md` — ICP construction upstream of Sales Nav filter
- `reference/frameworks/sales/` — call scripts + objection library
- `reference/frameworks/foundations-methodology.md` — pre-requisite (don't scale a bad offer)

---
*v1.0 — 2026-04-19.*
