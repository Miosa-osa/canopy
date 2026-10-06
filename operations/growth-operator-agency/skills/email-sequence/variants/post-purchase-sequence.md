---
variant: post-purchase-sequence
parent_skill: email-sequence
scope: New-buyer onboarding, first-win engineering, and ascension bridging. Turns a purchase into an activated customer who completes the promised outcome and is a candidate for ascension to a higher-ticket offer, case study contribution, or referral.
triggers:
  - Stripe or cart purchase webhook fires
  - application-sequence or launch-sequence buyer tag added
  - tripwire-to-core upsell accepted
sequence_length: 5 to 10 emails
window: 90 days (Day 0 to Day 90)
cadence: Day 0 (within 2 min of purchase) / Day 1 / Day 3 / Day 7 / Day 14 / Day 30 / Day 60 / Day 90
open_rate_target: 55 to 75 percent (buyer list is the most engaged segment)
click_rate_target: 15 to 30 percent on onboarding emails; 3 to 10 percent on ascension emails
unsubscribe_loss_budget: under 1 percent
conversion_event: buyer completes their first-win milestone, contributes a case study, or ascends to a higher-ticket offer
version: 1.0
---

# Post-Purchase Sequence Playbook

## Role In the System

The post-purchase sequence runs the single most valuable segment on the list: actual buyers. Every email here does compound-interest work. An activated buyer who hits their first-win milestone is a referral source, a case study contributor, an ascension candidate, and a retention-positive account. An unactivated buyer is a refund risk and a silent churn.

The sequence has four jobs, sequential and non-skippable:

1. Welcome plus access. Within 2 minutes of purchase, the buyer knows exactly where to go, what to do next, and who to reach if something breaks.
2. First-win engineering. The offer document specifies a 7-to-30 day first-win milestone. The sequence makes that milestone happen by guiding the buyer to the exact next action at the exact right moment.
3. Milestone celebration plus case-study capture. When the first win lands, the sequence captures it before the memory fades. Specific numbers. Specific timeframes. Specific story beats.
4. Ascension or retention bridge. If a higher-ticket offer exists, the sequence qualifies the buyer for it around Day 60 to 90. If not, the sequence bridges into the retention loop.

Post-purchase is not a nurture sequence and is not a launch sequence. It is the onboarding-to-ascension conveyor belt. Its tone is warm, decisive, and ownership-oriented. It treats the buyer as a new member of the inner circle, not a subscriber to convince.

## Gate-in Conditions

Ship this sequence only if:

- Cart or application checkout is wired to trigger post-purchase email within 2 minutes
- Delivery asset is live: login access, course platform, welcome video, or live cohort onboarding calendar
- First-win milestone is defined in the offer document (Compartment 3) with a specific outcome and a specific timeframe
- Support channel is operational (Slack, Circle, Skool, email, or dedicated inbox)
- Case-study capture template is ready and legal-reviewed for permissions
- Ascension offer (if exists) is defined with qualification criteria
- Compartment 9 (Education and Nurture OS) and Compartment 10 (Lifecycle and Optimization) together are at 40 percent or higher

## The 5-to-10 Email Skeleton

The sequence has five beats: welcome, activation, first-win, capture, ascension. Longer sequences (10 emails) hit all five. Shorter sequences (5 emails) hit welcome, activation, first-win, and one ascension.

### Welcome Beat (1 email, T+0, within 2 min of purchase)

**Email PP1 (T+0) — Welcome + Access + First Action**

| Component | Spec |
|---|---|
| Subject | "You're in. Here's how to start." |
| Preview text | Names the access link and the first action |
| Hook line | "Welcome. Three things in this email. Read them once." |
| Body | 300 to 500 words. (1) Access: login link and credentials, with a fallback "if this doesn't work, email [address]." (2) First action: the single next thing to do in the next 30 minutes. Named. Specific. (3) Expectations: what to expect in the next 7 days from the sequence, the support channel, and the program. |
| Single CTA | Access the platform or complete the first action. |
| Sign-off | Creator or onboarding lead first name |
| P.S. | Support channel contact, stated plainly. |

Writing rules for PP1:
- Fires within 2 minutes of purchase webhook. Delay kills activation.
- Names the first action in 30 minutes or less. "Watch the 12-minute kickoff video" works. "Plan your first week" is too vague.
- Credentials and access link tested before every sequence edit.
- Support channel stated at end, with contact method and response-time expectation.

### Activation Beat (1 to 2 emails, Day 1 to Day 3)

**Email PP2 (Day 1) — The First-Win Engineering Email**

| Component | Spec |
|---|---|
| Subject | "Your first win: [specific outcome]" |
| Preview text | Names the first-win milestone and the timeframe |
| Hook line | "By [day N], here's what I want you to have done." |
| Body | 400 to 500 words. State the first-win milestone from the offer document. Break it into the three specific sub-actions that get the buyer there. Timebox each sub-action. Link to the first sub-action's resource. End with "By end of day [N], reply with [simple confirmation]. That's how I know you're on track." |
| Single CTA | Start sub-action one. |
| P.S. | Pointer to the support channel if stuck. |

**Email PP3 (Day 3, optional) — Check-In + Course-Correct**

| Component | Spec |
|---|---|
| Subject | "Checking in on [first-win milestone]" |
| Preview text | Names the specific sub-actions |
| Hook line | "Day 3. Where are you?" |
| Body | 250 to 400 words. Three short check-in questions tied to the sub-actions from PP2. Offer a "I'm stuck" reply option that routes to the support channel. |
| Single CTA | Reply with status, or book a support call, or pick one of three resource links. |
| P.S. | First-win deadline reminder. |

Writing rules for Activation:
- First-win milestone comes from the offer document's definition, not an invented goal. If the offer document does not have one defined, pause the sequence and fix the offer.
- Sub-actions are timeboxed. "Do this in the next 30 minutes" works. "Do this this week" does not.
- The Day 3 check-in is a real check-in. Replies are read. If the buyer replies "stuck," the support team actually responds within the promised window.

### First-Win Beat (1 to 2 emails, Day 7 to Day 14)

**Email PP4 (Day 7) — Week 1 Milestone**

| Component | Spec |
|---|---|
| Subject | "Week 1 milestone: what to check" |
| Preview text | Names the milestone and the next-step bridge |
| Hook line | "End of Week 1. Here's what should be in place." |
| Body | 400 to 500 words. Restate the Week 1 milestone. Ask the buyer to confirm specific outcomes (reply with "done" or "not yet" to each). Pointer to Week 2's milestone. |
| Single CTA | Confirm milestone or request help. |
| P.S. | Case-study-in-advance framing: "If Week 1 landed, tell me the numbers. That's how I help more people like you." |

**Email PP5 (Day 14) — First Win Celebration + Capture**

| Component | Spec |
|---|---|
| Subject | "If [first-win milestone] is done, read this" |
| Preview text | Names the capture ask |
| Hook line | "If your first win is in, I want to capture it before memory fades." |
| Body | 400 to 500 words. Three prompts for the buyer to respond to: (1) What was the starting state on Day 0? (2) What is the current state on Day 14? (3) What specific action or sub-step made the difference? State that responses feed a case study that will help future buyers and that the buyer will get to review before it is published. |
| Single CTA | Reply with the three answers, or book a 20-minute case-study call. |
| P.S. | "If Week 1 didn't land, tell me what got in the way. I can help." |

Writing rules for First-Win:
- Celebration is not hype. It is specific. Specific sub-actions completed, specific sub-outcomes achieved.
- Capture happens while the memory is fresh. Day 14 is the sweet spot. Day 30 loses narrative detail.
- Always offer an alternative for buyers who did not hit the milestone. They need support, not a celebration email that lands wrong.

### Capture + Course-Correct Beat (1 email, Day 30)

**Email PP6 (Day 30) — Month 1 Review + Support Escalation**

| Component | Spec |
|---|---|
| Subject | "30 days in. Quick review." |
| Preview text | Names the review framework |
| Hook line | "30 days. Three questions." |
| Body | 300 to 400 words. Three-question review: (1) What's working? (2) What's still stuck? (3) What's your Month 2 goal? Promise a specific follow-up based on the answers. For buyers who are stuck, route to a 20-minute course-correct call. For buyers who are winning, tease the ascension bridge. |
| Single CTA | Reply with the three answers. |
| P.S. | Link to the current case study page with Week 1 capture stories from recent buyers (social proof in the inner circle). |

Writing rules for Capture + Course-Correct:
- Real replies mean real follow-ups. If the buyer says "stuck," the support team responds in 24 hours.
- Case-study page link treats the buyer as a peer in the member group, not as an outside audience member.
- Month 2 goal-setting is the bridge into either ascension or deepening retention.

### Ascension or Retention Beat (1 to 3 emails, Day 60 to Day 90)

**Email PP7 (Day 60) — Ascension Invitation (if ascension offer exists)**

| Component | Spec |
|---|---|
| Subject | "What's next after [current offer]" |
| Preview text | Names the ascension offer as optional |
| Hook line | "Some of you are ready for what comes after. Here's what that looks like." |
| Body | 400 to 500 words. Name the ascension offer. Name who it is for (buyers who have hit specific milestones). Name what it adds beyond the current offer. Name the application or booking link for the next step. State plainly that ascension is optional and the current offer is complete on its own. |
| Single CTA | Apply for ascension or book a fit call. |
| P.S. | "If now isn't right, nothing changes. You have the current offer for the full retention window." |

**Email PP8 (Day 75, optional) — Ascension Case Study**

| Component | Spec |
|---|---|
| Subject | "[Case subject] went from [current offer] to [ascension offer] and here's what changed" |
| Preview text | Names the isomorphic case |
| Hook line | Positions the case subject as a buyer on the same path. |
| Body | 300 to 500 words. Case study of a buyer who ascended. Specific before-and-after. End with the ascension application link. |
| Single CTA | Apply for ascension or book a fit call. |
| P.S. | Case-study-in-advance reminder for current buyers. |

**Email PP9 (Day 90) — Alumni / Deep Retention Bridge**

| Component | Spec |
|---|---|
| Subject | "90 days. What's the play now?" |
| Preview text | Names the two paths (stay, ascend) |
| Hook line | "90 days in. Two paths from here." |
| Body | 400 to 500 words. Path A: deepen the current offer (specific actions to sustain the Month 3 outcome). Path B: ascend to the higher-ticket offer (link to apply). Treat both as legitimate. |
| Single CTA | Pick a path (Path A resource or Path B application). |
| P.S. | Refer-a-friend link: "If this has worked for you, tell someone who'd benefit. Here's a referral link with [specific thank-you]." |

Writing rules for Ascension:
- Ascension is optional. Buyers who do not ascend are still high-value retention accounts.
- Ascension pitch is quiet, not loud. These are already-buyers. Loud pitches damage trust.
- Refer-a-friend link lands in the P.S. of Day 90, never before. A buyer who has just bought is not ready to refer; a buyer who has completed 90 days is.

### Optional Extensions (Day 120, Day 180, annual)

For longer-retention offers (12-month memberships, ongoing coaching, annual cohorts), extend with milestone-based emails at Day 120 (second-quarter review), Day 180 (half-year capture), and Day 365 (annual reflection + renewal decision). Keep cadence at monthly or less beyond Day 90.

## Subject Line Bank — 15 Post-Purchase Patterns

1. "You're in. Here's how to start."
2. "Your first win: [specific outcome]"
3. "Checking in on [first-win milestone]"
4. "Week 1 milestone: what to check"
5. "If [first-win milestone] is done, read this"
6. "30 days in. Quick review."
7. "What's next after [current offer]"
8. "[Case subject] went from [current offer] to [ascension offer]"
9. "90 days. What's the play now?"
10. "Quick question from the inside"
11. "Before the community call on [day]"
12. "Your [case study] is ready to review"
13. "Ready for the next level? Here's who this is for."
14. "Keep this one thing going"
15. "Refer someone like you"

## P.S. Bank — 10 Patterns Specific to Post-Purchase

1. Support channel link plus response-time expectation.
2. Access link restated in case the buyer lost the first one.
3. Case-study capture prompt: "If this worked, tell me the numbers."
4. Case-study page link showing buyer stories (social proof inside the inner circle).
5. Ascension link with "optional" framing.
6. Refer-a-friend link with the specific thank-you named.
7. "If you're stuck, reply with one word and I'll route you to help."
8. Community-call schedule or next live event link.
9. Renewal or next-phase-of-offer reminder if relevant.
10. Thank-you without sycophancy, once per beat maximum.

## Segmentation + Tag Logic

| Trigger | Tag Added | Tag Removed |
|---|---|---|
| Purchase | buyer, post-purchase-active, cohort-[date-slug] | launch-active, application-submitted, any pre-purchase tags |
| Access link clicked | activated | |
| First-win milestone confirmed (PP4 or PP5 reply) | first-win-hit | |
| Case study capture submitted | case-study-contributor | |
| 30-day review reply | month-1-reviewed | |
| Stuck reply (any email) | support-requested | |
| Ascension application submitted | ascension-applied | |
| Ascension purchased | ascension-buyer, post-purchase-active-ascension | post-purchase-active |
| Refer-a-friend link clicked | referrer-active | |
| 90-day complete with no ascension | retention-90, stay-path | post-purchase-active |
| Refund requested | refund-active | all buyer tags |

Segmentation critical: buyers who do not hit the first-win milestone get a different downstream than buyers who do. Route stuck buyers to live support, not to ascension emails. Route first-win hitters to case-study capture, then ascension.

## Cadence Fatigue Check

Buyer cadence is the most forgiving of all segments because engagement is high, but it still has limits:

- Cap at 10 emails in 90 days. Less is fine; more starts to feel like noise.
- Pause broadcast and nurture for buyers in the active 90-day window.
- Community or cohort emails can overlap with the sequence, but total email volume from all sources stays under 3 per week.
- For buyers who refund, suspend the sequence immediately and route to the refund protocol.

## Benchmarks and What They Tell You

| Metric | Healthy Range | If Below | If Above |
|---|---|---|---|
| PP1 open rate | 75 to 90 percent | Sender reputation issue or webhook delay | Fine |
| PP1 access-link click rate | 60 to 85 percent | Access friction or confusing first-action framing | Fine |
| First-win confirmation rate (PP4 or PP5 reply) | 40 to 70 percent | First-win milestone is unclear or too hard | Healthy onboarding |
| Case-study capture rate | 15 to 35 percent of first-win hitters | Capture prompt is buried or timing too late | Healthy |
| Ascension application rate (PP7) | 5 to 15 percent of eligible buyers | Ascension offer mismatch or qualification criteria too loose | Healthy |
| 90-day retention rate | 80 to 95 percent | First-win engineering failed; buyers churned early | Healthy |
| Refund rate | under 5 percent | Fine | Offer-delivery mismatch; audit the first 30 days |

## Voice-Match and Compliance Rules Specific to Post-Purchase

- Every email uses 3 or more `phrases_to_use` from Compartment 1.
- Banned-vocabulary sweep clean.
- Case-study capture includes a permissions clause. The buyer must explicitly consent to use of their name, quote, or numbers before any public publication.
- Testimonial numbers in ascension emails carry "results vary" disclosure.
- Refund policy visible in PP1 and linked in every email footer.
- Sender name is creator or onboarding lead, never a generic support alias.

## Common Failure Modes

1. PP1 fires late (>5 min after purchase). Activation rate drops. Fix: wire PP1 to the purchase webhook with a <2 min SLA, tested.
2. First-win milestone is not defined in the offer document. Activation email sends the buyer to do vague work. Fix: pause sequence, fix the offer document, redefine the milestone specifically.
3. Sub-actions in PP2 are not timeboxed. Buyers procrastinate. Fix: every sub-action has a clock attached.
4. Day 3 check-in email goes out but replies are not read. Buyers who say "stuck" get no response. Fix: route check-in replies to a monitored inbox with a 24-hour SLA.
5. Case-study capture in PP5 has no permissions clause. Case study cannot be used. Fix: include explicit consent language in the capture prompt.
6. Ascension invitation in PP7 is too loud. Buyers feel re-pitched. Trust drops. Fix: quiet framing, optional explicitly, and only for qualified buyers.
7. Refund requests trigger the next email in the sequence anyway. The refunded customer gets an ascension pitch. Fix: suspend sequence on refund tag immediately.

## Next Sequence Routing

| End-of-Sequence Tag | Next Route |
|---|---|
| ascension-buyer | Post-purchase sequence for the ascension offer (new 90-day loop) |
| retention-90, stay-path | Monthly retention broadcast plus annual renewal sequence |
| case-study-contributor | Monthly community broadcast plus invite to live case-study events |
| referrer-active | Referral program email loop |
| refund-active | Refund handling protocol, no further emails until resolution |
| support-requested unresolved | Escalation inbox, sequence paused until resolved |

## Verification Checklist

- [ ] Purchase webhook fires PP1 within 2 minutes, tested end-to-end
- [ ] Access link and credentials live and tested
- [ ] First-win milestone defined in the offer document with specific outcome and timeframe
- [ ] All 5 to 10 emails drafted with subject, preview, body, single CTA, P.S.
- [ ] Day 3 check-in replies routed to a monitored inbox with <24h response SLA
- [ ] Case-study capture prompt includes explicit permissions clause
- [ ] Ascension invitation in PP7 respects qualification criteria
- [ ] Refund tag suspends sequence immediately
- [ ] Refer-a-friend link active only in Day 90 or later
- [ ] 3 or more `phrases_to_use` per email
- [ ] Banned-vocabulary sweep clean
- [ ] Broadcast and nurture paused for active 90-day buyers
- [ ] Cohort tag applied for cohort-based offers
- [ ] Next-sequence routing rules wired for ascension, retention, referral, refund, and support paths

---
*v1.0 — post-purchase-sequence variant of /email-sequence. Pairs with /case-study (capture asset), /retention-check (health scoring), and the ascension loop (next offer's post-purchase sequence).*
