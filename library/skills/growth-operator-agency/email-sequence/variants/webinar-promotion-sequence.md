---
variant: webinar-promotion-sequence
parent_skill: email-sequence
scope: Pre-webinar plus post-webinar email flow. Pre-webinar drives registration and show-up. Post-webinar handles replay, close, and bonus-deadline urgency for non-buyers.
triggers:
  - webinar date and time locked in calendar
  - registration page live and tested
  - webinar script complete (output of /webinar-script)
sequence_length: 5 to 8 emails pre-webinar, 3 to 5 emails post-webinar
window: 7 days pre-webinar, 5 to 7 days post-webinar
cadence: T-7d invite / T-3d value preview / T-1d reminder / T-1h show-up / T+0 replay if missed / T+1d close / T+2d bonus / T+5d final
open_rate_target: 45 to 65 percent pre-webinar; 50 to 70 percent post-webinar close emails
click_rate_target: 15 to 30 percent on registration emails; 4 to 10 percent on close emails
show_up_rate_target: 35 to 50 percent of registrants for live webinars; 60 to 80 percent replay consumption for evergreen
unsubscribe_loss_budget: 2 to 4 percent across pre and post combined
conversion_event: webinar registration, webinar attendance, and post-webinar offer conversion
version: 1.0
---

# Webinar Promotion Sequence Playbook

## Role In the System

The webinar promotion sequence has two distinct halves with two distinct jobs.

**Pre-webinar** owns registration plus show-up. A registrant who does not attend the live event is worth a fraction of one who does. Every email in the pre-webinar half is engineered to raise either registration count or show-up rate, never both in the same email.

**Post-webinar** owns the close. A webinar converts a small fraction of attendees live. The rest convert in the 48-hour to 7-day replay plus deadline window. Post-webinar emails are where the majority of webinar revenue lands.

Webinar promotion is not a launch sequence. Launches sell the offer directly. Webinar promotion sells the event, then the event sells the offer. Keep the halves separate in writing, in CTAs, and in cadence.

## Gate-in Conditions

Ship this sequence only if:

- Webinar date, time, and time zone are locked and dated
- Registration page is live, tested, and captures name plus email plus any qualification field
- Webinar script is complete (output of /webinar-script) with Crossroads Close and bonus deadline defined
- Replay delivery system is tested end-to-end
- Cart or application is wired to the offer that the webinar pitches
- Compartment 2 (Audience) is at 60 percent, Compartment 3 (Offer) is at 70 percent
- Platform integrations live: webinar platform (live or evergreen), ESP, CRM

## Pre-Webinar Arc (5 to 8 emails)

The pre-webinar half has three sub-phases: invite, value-build, show-up.

| Sub-phase | Timing | Job | CTA Class |
|---|---|---|---|
| Invite | T-7d to T-5d | Get the registration | Register for webinar |
| Value-build | T-3d to T-1d | Raise perceived value of attending | Register (late opt-ins) + save-the-date reminders |
| Show-up | T-1d to T-0 | Raise attendance rate | Click calendar add, confirm attendance, join link |

### Invite Phase (2 to 3 emails, T-7d to T-5d)

**Email P1 (T-7d) — Opening Invite**

| Component | Spec |
|---|---|
| Subject | Title of the webinar in plain language, plus the date. Example: "[Webinar title] on [day + date]" |
| Preview text | Names the specific outcome the webinar teaches |
| Hook line | One sentence of the big idea. |
| Body | 300 to 400 words. Name the webinar title. Name who it is for. Name the three to five specific things the attendee will learn. Name the date, time, and time zone. Name whether replay will be available (answer: briefly, yes, but live is better). |
| Single CTA | Register now. |
| P.S. | Repeat the date and time. |

**Email P2 (T-6d) — The Big Idea**

| Component | Spec |
|---|---|
| Subject | Contrarian or specific-outcome framing. "Why [conventional approach] keeps failing in [ICP segment]" |
| Preview text | Extends the contrarian frame |
| Hook line | One-sentence big idea of the webinar. |
| Body | 400 to 500 words. Argue the contrarian frame. Tie it to what the webinar reveals. End with the registration CTA. |
| Single CTA | Register now. |
| P.S. | Date and time restated. |

**Email P3 (T-5d, optional) — Who It's For + Who It's Not For**

| Component | Spec |
|---|---|
| Subject | "Is this webinar right for you?" |
| Preview text | Self-qualification frame |
| Hook line | "Before you register, read this." |
| Body | 300 to 400 words. Name the three types of people this webinar is for. Name two types of people this webinar is not for. The exclusion raises perceived selectivity. |
| Single CTA | Register now. |
| P.S. | Date and time restated. |

### Value-Build Phase (1 to 2 emails, T-3d to T-2d)

**Email V1 (T-3d) — Preview Value Drop**

| Component | Spec |
|---|---|
| Subject | Specific teaser from the webinar content. "One of the three sub-steps I'll teach on [day]" |
| Preview text | Extends the teaser |
| Hook line | Names the sub-step. |
| Body | 300 to 500 words. Teach the sub-step at a conceptual level. State that the webinar expands this plus two more sub-steps plus applies them to a specific outcome. |
| Single CTA | Register now (for non-registrants) or "You're already registered. Here's how to prepare." (for registrants, using segmentation). |
| P.S. | Date and time restated. |

**Email V2 (T-2d, optional) — Case Study Preview**

| Component | Spec |
|---|---|
| Subject | Specific outcome plus case subject's first name. "How [case subject] hit [specific number]" |
| Preview text | Names the stakes |
| Hook line | Case subject's starting state as isomorphic to the reader. |
| Body | 300 to 400 words. Full micro-case. End with "I'll walk through the full approach on [day]." |
| Single CTA | Register (non-registrants) or save-the-date (registrants). |
| P.S. | Date and time restated. |

### Show-Up Phase (2 to 3 emails, T-1d to T-0)

**Email S1 (T-1d) — "Tomorrow" Reminder**

| Component | Spec |
|---|---|
| Subject | "Tomorrow at [time]" |
| Preview text | Restates the core outcome |
| Hook line | "Tomorrow, at [time in recipient's time zone], here's what happens." |
| Body | 200 to 300 words. Three things they will walk away with. Link to calendar add. Link to how to join. Mention that showing up live matters because Q&A only happens live. |
| Single CTA | Confirm attendance or add to calendar. |
| P.S. | Join link restated. |

**Email S2 (T-1h) — "Starting Soon"**

| Component | Spec |
|---|---|
| Subject | "Starting in 1 hour" |
| Preview text | Restates the join link |
| Hook line | "We go live in one hour. Here's your link." |
| Body | 100 to 200 words. Short. Join link. One line on what to have ready (pen, paper, a specific question from their business). |
| Single CTA | Join now. |
| P.S. | Time zone reminder. |

**Email S3 (T-5min, optional) — "Live Now"**

| Component | Spec |
|---|---|
| Subject | "We're live" |
| Preview text | Link to join |
| Hook line | "Started 2 minutes ago. Room's already filling." |
| Body | 50 to 100 words. Extreme brevity. Join link. |
| Single CTA | Join now. |

Writing rules for Pre-Webinar:
- Segment pre-webinar emails by registered vs not-registered starting at Email V1. Registered subscribers get "prepare" framing; non-registered subscribers get "register" framing.
- Never use fake urgency on registration. Seats can be capped, but the cap must be real.
- Every reminder carries the exact time in plural time zones (at least the creator's and a second major ICP time zone).
- Never ask registrants for a purchase before the webinar. The webinar sells the offer.

## Post-Webinar Arc (3 to 5 emails)

The post-webinar half segments by three behaviors: attended live, missed and need replay, and engaged post-webinar without purchase. Each behavior gets a tuned flow.

### Post-Webinar Emails for All Registrants

**Email PW1 (T+0, within 2h of webinar end) — Replay + Fast-Action Bonus**

| Component | Spec |
|---|---|
| Subject | For attendees: "Thank you for showing up. Here's what's next." For missers: "Missed it? Replay is inside." |
| Preview text | Replay link plus fast-action bonus deadline |
| Hook line | Attendee version: gratitude plus the offer reminder. Misser version: replay link. |
| Body | 300 to 400 words. Replay link. Offer CTA. Fast-action bonus deadline (first 24h post-webinar usually). Link to the offer landing page. |
| Single CTA | Buy / Apply / Book call. |
| P.S. | Fast-action bonus deadline restated. |

**Email PW2 (T+1d) — Objection Destruction #1**

| Component | Spec |
|---|---|
| Subject | "What if [objection from the webinar Q&A]?" |
| Preview text | Names the objection |
| Hook line | Quote the objection back, cite the Q&A moment. |
| Body | 300 to 400 words. Reframe the objection using mechanism logic. Cite an isomorphic case study. |
| Single CTA | Buy / Apply / Book call. |
| P.S. | Fast-action bonus deadline or main deadline, whichever is closer. |

**Email PW3 (T+2d) — Objection Destruction #2**

| Component | Spec |
|---|---|
| Subject | Different objection. "The [specific objection] question, answered" |
| Preview text | Frames the reframe |
| Hook line | Quote the objection. |
| Body | 300 to 400 words. Reframe. Different case study than PW2. |
| Single CTA | Buy / Apply / Book call. |
| P.S. | Deadline restated. |

**Email PW4 (T+4d or T+5d, optional) — Bonus Recap + Deadline Warning**

| Component | Spec |
|---|---|
| Subject | "[N] hours left on [specific bonus]" |
| Preview text | Deadline clarity |
| Hook line | Names the bonus at risk. |
| Body | 300 to 400 words. Recap every bonus. Name which expires when. Final CTA. |
| Single CTA | Buy / Apply / Book call. |
| P.S. | Deadline to the minute. |

**Email PW5 (T+5d or T+6d) — "Doors Closed" or "Last Call"**

| Component | Spec |
|---|---|
| Subject | "Last call" or "Closing at [time]" |
| Preview text | Deadline now |
| Hook line | Hours remaining. |
| Body | 150 to 250 words. Tight. Recap offer, recap deadline, one CTA. |
| Single CTA | Buy / Apply / Book call. |
| P.S. | Deadline to the minute. |

Writing rules for Post-Webinar:
- Respect the real bonus deadline. Never extend it silently. If it moves, it moves publicly.
- Every email references the webinar, not the offer alone. "During the webinar, I taught..." anchors the authority earned in the live event.
- Never rehash the full webinar. Reference key moments by phrase, not by retelling.
- Objection destruction draws from the webinar Q&A plus the ICP objection library, blended.

## Subject Line Bank — 15 Webinar-Specific Patterns

1. "[Webinar title] on [day + date]"
2. "Why [conventional approach] keeps failing"
3. "Is this webinar right for you?"
4. "One of the three things I'll teach on [day]"
5. "How [case subject] hit [specific number]"
6. "Tomorrow at [time]"
7. "Starting in 1 hour"
8. "We're live"
9. "Missed it? Replay is inside"
10. "Thank you for showing up. Here's what's next."
11. "What if [objection]?"
12. "The [specific objection] question, answered"
13. "[N] hours left on [specific bonus]"
14. "Last call"
15. "Closing at [time]"

## P.S. Bank — 10 Patterns Specific to Webinar Promotion

1. Date plus time plus time zone restated.
2. Calendar-add link.
3. Join link restated.
4. Replay link restated.
5. Deadline to the minute.
6. Bonus-by-bonus expiration schedule.
7. Link to webinar Q&A recap page.
8. FAQ page link.
9. One-line pointer to the offer guarantee.
10. Unsubscribe link, plainly stated (every 4 to 5 emails at minimum).

## Segmentation + Tag Logic

| Trigger | Tag Added | Tag Removed |
|---|---|---|
| Register for webinar | webinar-registered, webinar-[date-slug] | |
| Attend webinar (30+ min attendance) | webinar-attended | |
| Miss webinar live | webinar-missed | |
| Click replay link | webinar-replay-viewed | |
| Click offer CTA post-webinar | webinar-hot-lead | |
| Purchase during fast-action bonus window | buyer-fast-action | webinar-hot-lead |
| Purchase after fast-action, before deadline | buyer | webinar-hot-lead |
| Reach deadline without purchase | webinar-non-buyer | webinar-hot-lead, webinar-attended, webinar-missed |

Segmentation critical: starting with Email V1 (T-3d), split "registered" from "not-registered" branches. Starting with Email PW1 (T+0), split "attended" from "missed." Blending the branches kills both.

## Cadence Fatigue Check

A full webinar sequence runs 8 to 13 emails across 12 to 14 days. That cadence is hotter than nurture, slightly cooler than launch. Protect the list by:

- Pausing weekly broadcast during the full window.
- Running no more than 2 webinar promotions per month to the same list.
- Offering a "I'm not going to attend, stop emailing me about it" link in Email P3.
- Tracking unsub rate phase by phase. If pre-webinar unsub exceeds 1 percent, the audience is wrong for this webinar topic.

## Benchmarks and What They Tell You

| Metric | Healthy Range | If Below | If Above |
|---|---|---|---|
| Registration rate (email list click-to-register) | 2 to 8 percent | Subject line or webinar title not compelling | Webinar topic is hot |
| Pre-webinar open rate | 45 to 60 percent | Sender reputation issue or subject fatigue | Fine |
| Show-up rate (live) | 35 to 50 percent | Reminder cadence too light | Fine |
| Replay consumption (missers) | 40 to 60 percent | Replay CTA buried | Fine |
| Post-webinar offer click rate | 8 to 15 percent on attendees | Offer-webinar alignment weak | Fine |
| Conversion rate (attendee to buyer) | 5 to 15 percent for $2K-$5K, 2 to 6 percent for $5K+ | Offer pitch weak or objection emails generic | Scale traffic to the funnel |

## Voice-Match and Compliance Rules Specific to Webinar Promotion

- Every email uses 3 or more `phrases_to_use` from Compartment 1.
- Banned-vocabulary sweep clean on all emails plus subject plus preview.
- Time zones always stated. Always the creator's primary time zone plus at least one other major ICP time zone.
- Join links tested manually before the sequence ships.
- Replay deadline stated clearly. Real deadlines only. No extensions after close.
- No income guarantees. Testimonial numbers carry "results vary" disclosure.
- If the webinar includes a live offer pitch, the registration page states that upfront. No bait-and-switch framing.

## Common Failure Modes

1. Webinar title is vague. Registration rate below 2 percent. Fix: rewrite title for specificity on ICP segment plus outcome plus timeframe.
2. Reminder cadence too light. Show-up rate below 30 percent. Fix: add Email S2 (T-1h) and Email S3 (T-5min).
3. No segmentation between registered and non-registered starting at V1. Registered subscribers get told to register. They unsubscribe. Fix: split the segments.
4. Post-webinar offer CTA is different from live offer CTA. Buyers confused. Fix: one offer, one CTA, named the same way everywhere.
5. Objection destruction emails are generic. Attendee Q&A is richer than the emails. Fix: draw objections from the actual Q&A plus ICP library.
6. Bonus deadline extended after close. Next webinar has no urgency force. Fix: respect the deadline.
7. Webinar email overlaps with launch sequence or broadcast. Cadence exceeds 3 emails per day. Unsubscribe spikes. Fix: pause all other sequences for the window.

## Next Sequence Routing

| End-of-webinar Tag | Next Route |
|---|---|
| buyer-fast-action or buyer | Post-purchase sequence within 2 minutes of purchase |
| webinar-non-buyer with webinar-replay-viewed | Nurture Phase 4 for 14 days, then warm re-engage |
| webinar-non-buyer with webinar-attended but no offer click | Nurture Phase 3 for 21 days |
| webinar-non-buyer with webinar-missed and no replay view | Re-engagement sequence after 14 days |

## Verification Checklist

- [ ] Webinar date, time, time zone locked
- [ ] Registration page live and tested
- [ ] Webinar script final with Crossroads Close and bonus deadlines defined
- [ ] Replay delivery tested
- [ ] Offer page live and wired to the webinar offer
- [ ] All pre-webinar emails drafted (5 to 8)
- [ ] All post-webinar emails drafted (3 to 5)
- [ ] Segmentation between registered and non-registered live from V1 onward
- [ ] Segmentation between attended and missed live from PW1 onward
- [ ] Time zones stated in every reminder and join email
- [ ] Fast-action bonus deadline and main offer deadline stated in every post-webinar email
- [ ] 3 or more `phrases_to_use` per email
- [ ] Banned-vocabulary sweep clean
- [ ] Cadence check: broadcast and other sequences paused for the window
- [ ] Tag map live and active
- [ ] Post-webinar routing rules wired

---
*v1.0 — webinar-promotion-sequence variant of /email-sequence. Pairs with /webinar-script (upstream) and post-purchase-sequence (for buyers) or nurture-sequence and re-engagement-sequence (for non-buyers).*
