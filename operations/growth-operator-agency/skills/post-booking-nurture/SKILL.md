---
name: post-booking-nurture
description: Produce the the paid media director Show-Rate Stack — confirmation page + email cadence + SMS cadence + optional phone triage from call-booking to call-show. Targets 70%+ show-rate. Critical for Book-a-Call and Application Funnel archetypes (build-funnel types 3 + 4).
signal:
  mode: linguistic
  genre: post-booking-stack
  type: inform
  format: markdown
  structure: w-post-booking-stack
  receiver: booked prospect
  receiver_capacity: medium
department: nurture
agent_affinity: [nurture-head, email-copywriter]
required_compartments:
  audience_intelligence_system: 60
  offer_architecture: 50
  copy_messaging: 40
  conversion_sales: 30
upstream_dependency: build-funnel
execution_mode: interactive
tier: structured_ai
temperature_gate: warm
required_tools: [file_read, file_write]
required_mcps: [filesystem]
required_integrations:
  email: convertkit-api
  sms: twilio-api
  calendar: cal-com-api                 # or calendly
  crm: gohighlevel-api
  phone: aircall-api                    # optional for phone triage
credentials_required: [TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER, CAL_COM_API_KEY, CONVERTKIT_API_KEY, GHL_API_KEY]
evidence_gate:
  - confirmation_page_spec_complete
  - email_cadence_24h_6h_1h
  - sms_cadence_within_5m_30m_pre_post
  - phone_triage_spec_if_applicable
  - voice_matched
  - compliance_compliant
  - signal_score_gte_0_8
keywords:
  - show rate
  - post booking
  - call reminder
  - confirmation page
  - nurture after booking
priority: 1
version: 1.0
---

# /post-booking-nurture — the paid media director Show-Rate Stack

## Role

Produce the full post-booking nurture stack — confirmation page + email + SMS + optional phone triage — designed to take show-rate from industry-average ~40% to the paid media director target **75%+ for qualified bookings**. Lineage: **the paid media director** (Show Rate stack + Infomatic Setting Flow), **the growth engineer** (Confirmation Page That Converts — 5-function framework), **Show-rate methodology — VSL Call Funnel** (SMS timing within 5m / 30m post / 30m pre / 5m pre).

## Why This Skill

**Show-rate is the silent killer.** 40% show-rate vs 70% show-rate = 75% more revenue on identical lead volume. If a creator spends $10K/mo on ads getting 100 booked calls, 40% show-rate = 40 conversations → $10K+ revenue left on table vs 70% (+30 calls).

## The 5-Function Confirmation Page (growth-engineering methodology)

Every confirmation page does 5 things:

1. **Confirms** the booking (reduces anxiety)
2. **Sets expectations** (what will happen on the call)
3. **Builds authority** (creator video or brief bio)
4. **Pre-handles objections** (common "should I even show up?" doubts)
5. **Provides homework** (something to do before the call — builds commitment)

## The Email Cadence (24h / 6h / 1h)

Three reminder emails:

| Time | Email | Content |
|---|---|---|
| T+0 (immediate) | Booking confirmation | Calendar details + confirmation page link + what to expect |
| T-24h | Day-before reminder | Reminder + homework reminder + "bring these questions" |
| T-6h | Final reminder | Short — "excited to talk at [time]" + calendar link |
| T-1h (optional) | Hour-before | Brief — "see you in 1 hour" |

### The SMS Cadence (the paid media director — within 5m / 30m / 30m-pre / 5m-pre)

Five SMS messages timed precisely:

| Time | SMS | Purpose |
|---|---|---|
| Within 5m of booking | Welcome + expectations set | Immediate acknowledgment builds trust |
| 30m post-booking | Homework reminder | Send the confirmation page + ask to consume |
| T-24h | Day-before | Confirmation + reschedule link if needed |
| T-30m pre | 30-min warning | Calendar link + device check prompt |
| T-5m pre | 5-min warning | Direct join link + "about to start" |

### Phone Triage (optional, high-ticket only)

For $10K+ offers with setter team:
- **Within 5m of booking:** Setter attempts phone call ("double-dial + voicemail")
- **If reached:** Welcome + qualification + pre-call briefing
- **If voicemail:** Follow-up SMS

## Decision Logic

### When Each Component Is Needed

| Offer price | Email cadence | SMS cadence | Phone triage |
|---|---|---|---|
| $500-$3K | Yes | Optional | No |
| $3K-$10K | Yes | Yes | Optional |
| $10K+ | Yes | Yes (full 5-msg) | Yes (within 5m double-dial) |
| Agency / DFY $15K+ | Yes + setter DM | Yes | Yes + dedicated setter |

### Funnel Archetype Match

From `/build-funnel`:
- Archetype 3 (Application) → full stack including phone triage
- Archetype 4 (Book-a-Call) → email + SMS cadence mandatory
- Archetype 2 (Webinar) → different — use webinar show-up sequence from /email-sequence type 4
- Other archetypes → as needed

### Voice + Compliance
- 3+ `phrases_to_use` across all touchpoints
- SMS: TCPA / GDPR consent tracked (opt-in at booking)
- Unsubscribe link in email
- Reply STOP to SMS
- CAN-SPAM physical address in email footer

## The Confirmation Page Structure (the growth engineer 5-function)

```
W(confirmation-page) =
  HERO:
    - "You're confirmed for [date/time]"
    - Creator video (30-90s: welcome + expectations + authority)
  
  EXPECTATIONS:
    - What will happen on the call (structure)
    - How long (20-30 min or 45 min)
    - Who will be on the call
  
  AUTHORITY:
    - Brief creator bio + results
    - 1-3 testimonials from past callers
  
  OBJECTION PRE-HANDLE:
    - "Will this be a pitch?" — honest answer
    - "Do I need to prepare?" — homework list
    - "What if I can't make it?" — reschedule link
  
  HOMEWORK:
    - 3-5 specific items to consume before call (video / guide / case study)
    - Calendar invite reminder
  
  REBOOK LINK (soft):
    - If they need to reschedule
```

## Tacit Principles

1. **Speed to first touch matters more than anything.** 5-min window is non-negotiable. Delay destroys show-rate.

2. **Confirmation page > confirmation email.** Page is consumable + shareable + video-embeddable. Email is less sticky.

3. **Homework creates commitment.** Prospect who watches 1 video before call shows up 80%+. Without homework, ~40%.

4. **SMS outperforms email for reminders.** 98% open rate on SMS within 3 min. Email 20-30% open.

5. **Reply-to-own-SMS boosts trust.** When prospect replies, creator or setter replies within 10 min. Feels personal.

6. **Don't over-stack.** Email + SMS is enough for $3-10K. Phone triage only for high-ticket.

7. **Reschedule link reduces no-shows.** Most no-shows aren't "can't be bothered" — they're "something came up." Make rescheduling easy.

8. **Calendar .ics attachment matters.** Half of prospects don't add to their own calendar. Attach it.

9. **Video on confirmation page = 20%+ show-rate lift.** Don't skip.

10. **Setter DM (Infomatic Flow):** "Setter disguised as creator creates a gc → sends message to creator introduces closer sends pre call checklist" — the paid media director pattern, works for high-ticket.

## Process

### Phase 0 — Load
- `/build-funnel` output (which archetype)
- Offer Doc, ICP Doc (objections)
- Brand Voice Doc
- `reference/operators/paid-media-director.md` (Infomatic Setting Flow + Show Rate stack)
- `reference/operators/growth-engineer.md` (Confirmation Page That Converts)

### Phase 1 — Component Selection
Per offer price + funnel archetype, decide which components (confirmation page + email + SMS + phone triage).

### Phase 2 — Confirmation Page Spec
- Creator video script (30-90s)
- Page copy (5 functions)
- Homework list (3-5 items)
- Reschedule flow

### Phase 3 — Email Cadence (4 emails)
- T+0 booking confirmation
- T-24h day-before
- T-6h final
- T-1h optional

### Phase 4 — SMS Cadence (5 messages)
- Within 5m welcome
- 30m post-booking homework
- T-24h reminder
- T-30m warning
- T-5m final

### Phase 5 — Phone Triage Spec (if applicable)
- Setter script (within 5m double-dial)
- Voicemail template
- Follow-up SMS

### Phase 6 — Voice-Match + Compliance
- 3+ phrases_to_use across touchpoints
- TCPA/GDPR consent tracked
- Unsubscribe + STOP

### Phase 7 — Automation Spec
- CRM trigger on booking → all sequences fire
- Tags + segmentation
- Integration points (Cal.com / Calendly → ConvertKit + Twilio + GHL)

## Output Format

```markdown
# Post-Booking Nurture Stack — [Creator Brand] — [Call Type]

**Offer Price:** $[N]
**Funnel Archetype:** [3 Application | 4 Book-a-Call | etc.]
**Components:** [confirmation page + email + SMS + phone triage]
**Target Show-Rate:** 70%+
**Version:** 1.0

---

## Confirmation Page

### Creator Video Script (30-90s)
```
[opening]
[welcome + expectations]
[authority]
[homework direction]
[close + excitement]
```

### Page Copy (5 functions)
[full spec per structure]

### Homework List
1. [Watch: X video (5 min)]
2. [Read: Y case study]
3. [Review: Z before call]

### Reschedule Flow
[link + message]

---

## Email Cadence (4 emails)

### Email 1 — T+0 Booking Confirmation
**Subject:** "You're confirmed for [date/time]"
**Body:** [...]
**CTA:** [calendar attachment + confirmation page link]

### Email 2 — T-24h Day-Before
[...]

### Email 3 — T-6h Final
[...]

### Email 4 — T-1h Optional
[...]

---

## SMS Cadence (5 messages)

### SMS 1 — Within 5m of Booking
"[copy, 160 chars max]"

### SMS 2 — 30m Post-Booking
"[homework reminder + confirmation page link]"

### SMS 3 — T-24h
"[...]"

### SMS 4 — T-30m Pre
"[...]"

### SMS 5 — T-5m Pre
"[direct join link]"

---

## Phone Triage (if high-ticket)

### Setter Script — Within 5m of Booking
```
[opening]
[welcome]
[pre-call briefing]
[close]
```

### Voicemail Template
[30-second script]

### Follow-up SMS
[if voicemail reached]

---

## Automation Spec

### CRM Triggers
- Trigger: booking submitted
- Actions:
  1. Tag: "booked_call"
  2. Fire email sequence (4 emails)
  3. Fire SMS sequence (5 messages)
  4. Notify setter (Slack or equivalent) for phone triage
  5. Create CRM deal + assign closer

### Integration Points
- Calendar (Cal.com / Calendly) → CRM webhook
- CRM → ConvertKit + Twilio
- Setter notification → Slack or Aircall

---

## Compliance
- [ ] TCPA/GDPR consent at booking
- [ ] Email unsubscribe + physical address
- [ ] SMS reply STOP
- [ ] No fabricated testimonials on confirmation page
- [ ] Accurate scheduling details

## Voice-Match
[phrases_to_use across all touchpoints]

---

## Appendix A — Reply-to-own-SMS playbook
## Appendix B — Reschedule reduction tactics
## Appendix C — Setter objection responses (if no-show)
```

## Important Rules

- **NEVER wait > 5 min for first touch.**
- **NEVER skip confirmation page + video.**
- **NEVER send SMS without explicit TCPA consent.**
- **NEVER burn lead with over-contact** (4 email + 5 SMS is the max stack — more = unsub).
- **ALWAYS include reschedule link** (some no-shows → reschedules with this).
- **ALWAYS attach calendar .ics.**
- **ALWAYS voice-match.**

## Verification Checklist

- [ ] Components selected per offer price + archetype
- [ ] Confirmation page 5-function structure
- [ ] Creator video script 30-90s
- [ ] Homework list 3-5 items
- [ ] Email cadence 4 emails
- [ ] SMS cadence 5 messages
- [ ] Phone triage spec (if high-ticket)
- [ ] Automation triggers specified
- [ ] Integration points mapped
- [ ] Compliance
- [ ] Voice-matched
- [ ] Triple-layer S/N ≥ 0.8

## Next Skills

- `/sales-script` — closer script for the call itself
- `/call-prep` — closer briefing from prospect data
- `/email-sequence` type 7 Post-Purchase — after the call closes

## References

- `reference/operators/paid-media-director.md` (Infomatic Setting Flow + Show Rate stack)
- `reference/operators/growth-engineer.md` (Confirmation Page That Converts — 5-function)
- Growth Operating Agency `Show Rates - VSL Call Funnel` canonical source
- `reference/canonical/spec/INTEGRATIONS.md` (Twilio + Cal.com + GHL)

---
*v1.0 — 2026-04-19. Cycle 4 Educate. The silent-killer skill — show-rate determines revenue on call funnels.*
