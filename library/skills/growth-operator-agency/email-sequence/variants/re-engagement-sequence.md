---
variant: re-engagement-sequence
parent_skill: email-sequence
scope: Reactivate subscribers who have gone dormant. Salvage the still-interested, clean the truly disengaged, and preserve list health for deliverability.
triggers:
  - subscriber has not opened an email in 60 to 90 days
  - subscriber carries the tag cold-nurture or cold-welcome
  - subscriber is on a list approaching an ESP's deliverability risk threshold
  - seasonal cleanup run before a major launch to protect sender reputation
sequence_length: 5 to 8 emails
window: 21 to 30 days
cadence: Day 0 / Day 3 / Day 7 / Day 12 / Day 18 / Day 25 / Day 30 (final scrub notice)
open_rate_target: 12 to 25 percent on re-engagement subjects (deliberately low because these are dormant subscribers)
click_rate_target: 2 to 6 percent
unsubscribe_loss_budget: 25 to 50 percent cumulative (the point of the sequence is to remove the disengaged)
conversion_event: re-opened an email plus clicked a link, OR explicitly unsubscribed, OR auto-removed from list
version: 1.0
---

# Re-Engagement Sequence Playbook

## Role In the System

The re-engagement sequence has a counterintuitive job: it is designed to lose subscribers. A disengaged subscriber who never opens is a tax on deliverability, a drag on sender reputation, and a source of false-positive metrics. The re-engagement sequence has three outcomes, all legitimate:

1. Wake up the still-interested subscriber who let the inbox slip. They reply, open, click. They get routed back into nurture or broadcast.
2. Surface the "I meant to unsubscribe" subscriber. They unsubscribe. Their departure cleans the list.
3. Auto-remove the ghost subscriber who neither engages nor opts out. They get scrubbed by the sequence's final action.

Ship the re-engagement sequence before every major launch and at least once per quarter regardless. Aggressive pruning is how sender reputation stays high enough that future emails actually reach inboxes.

A re-engagement sequence is not a nurture sequence and is not a broadcast. Nurture assumes engagement. Broadcast assumes a baseline of attention. Re-engagement assumes neither. Its tone is direct, its cadence is spread, its close is a plain unsubscribe or scrub.

## Gate-in Conditions

Ship this sequence only if:

- Subscriber has been on the list long enough to be fairly considered dormant (minimum 90 days)
- Subscriber has not opened any email in 60 to 90 days
- ESP engagement metrics are tracked (opens, clicks, unsubs, complaints)
- Auto-suppression or auto-delete rule is configured for subscribers who fail the final email
- A clear value proposition exists for re-engaging: a real piece of value, an updated offer, a specific reason to check back in

Never run re-engagement as a disguised launch. Never ship without the auto-scrub rule in place. Without auto-scrub, the sequence collects unsubs but keeps the ghost subscribers, defeating the purpose.

## The 5-to-8 Email Structure

The arc has four beats: wake-up, value-drop, direct-ask, final-scrub.

### Wake-Up Beat (1 to 2 emails, Day 0 to Day 3)

**Email R1 (Day 0) — "Are you still with me?"**

| Component | Spec |
|---|---|
| Subject | Direct, plain question. "Are you still on this list?" or "Quick check-in" (40 to 50 chars) |
| Preview text | Honest framing. "Haven't seen you in a while. Here's what's going on." |
| Hook line | "I noticed you haven't opened anything from me in [N] weeks." |
| Body | 200 to 300 words. Plain. Name what has happened since they last engaged (new content, new offer, new direction). Name what the next email will cover. Offer them three options at the end: stay, pause, leave. |
| Single CTA | Three plain-text links: "I'm still in" / "Pause for 60 days" / "Take me off the list" |
| Sign-off | First name |
| P.S. | "No hard feelings if you want to go. The list stays honest this way." |

Writing rules for R1:
- Tone is direct and adult. No guilt-trips. No false "we miss you" corporate-speak.
- The three options are equal. The unsubscribe link is not buried.
- Never use fake-reply subjects to spike opens.

**Email R2 (Day 3, optional) — Value Confirmation**

| Component | Spec |
|---|---|
| Subject | Specific value preview. "The one thing I've figured out since we last talked" |
| Preview text | Extends the specific hook |
| Hook line | Names a specific insight or change since the subscriber went dormant. |
| Body | 300 to 400 words. One tactical idea they can apply today. No offer mention. Prove that staying on the list still pays off in content terms. |
| Single CTA | Back to a pillar content piece. |
| P.S. | Mention next email's topic. |

### Value-Drop Beat (1 to 2 emails, Day 7 to Day 12)

**Email R3 (Day 7) — Mechanism Refresh**

| Component | Spec |
|---|---|
| Subject | Mechanism reframe. "Here's the one idea still working for me" |
| Preview text | Names the mechanism update angle |
| Hook line | "Since we last talked, I've refined how I think about [mechanism]." |
| Body | 300 to 450 words. Restate the mechanism. State what has been added or sharpened since the subscriber went dormant. End with "If this still fits, I'll keep sending." |
| Single CTA | Back to mechanism content, or a micro-reply prompt ("Reply with one word if this is still useful"). |
| P.S. | "Next email has a case study. If you still want to see them, stay." |

**Email R4 (Day 12, optional) — Case Study**

| Component | Spec |
|---|---|
| Subject | Specific case plus specific outcome. "[Case subject] went from [A] to [B] in [N] weeks" |
| Preview text | Names the stakes |
| Hook line | Case subject's starting state as isomorphic to the original ICP. |
| Body | 300 to 400 words. Full micro-case. No offer mention. |
| Single CTA | Back to a longer case study or a piece of public content. |
| P.S. | "Next week I'll ask you directly if this list still fits. No wrong answer." |

Writing rules for Value-Drop:
- Pick one tactical idea and one case study. Do not stack.
- Do not use the re-engagement window to pitch. Pitching at this stage converts poorly and loses the borderline subscriber.
- Every CTA leads to content, not cart.

### Direct-Ask Beat (1 to 2 emails, Day 18 to Day 25)

**Email R5 (Day 18) — The Yes or No**

| Component | Spec |
|---|---|
| Subject | "Yes or no?" or "Stay on this list?" |
| Preview text | Frames a direct choice |
| Hook line | "I won't drag this out. Yes or no: do these emails still fit?" |
| Body | 200 to 300 words. Three plain options. "Yes, keep sending" (link or reply word). "Pause for 60 days, then check in." "No, take me off." Treat all three as legitimate. |
| Single CTA | Three-way link set. |
| P.S. | Restate the scrub deadline: "If I don't hear from you by [date], I'll take you off automatically." |

**Email R6 (Day 25, optional) — Last Value Drop**

| Component | Spec |
|---|---|
| Subject | "One more thing before I let this go" or "Final useful idea" |
| Preview text | Promises a tactical payoff |
| Hook line | One sentence of specific value. |
| Body | 300 to 400 words. One last tactical idea. Tie it to the mechanism. End with the same three options from R5 in a shorter form. |
| Single CTA | Same three-way link set. |
| P.S. | Scrub deadline restated. |

### Final-Scrub Beat (1 email, Day 30)

**Email R7 (Day 30) — "Taking you off"**

| Component | Spec |
|---|---|
| Subject | "Taking you off the list today" |
| Preview text | States the action plainly |
| Hook line | "Haven't heard from you. I'm going to remove you from the list today." |
| Body | 150 to 250 words. State that the removal happens today. Give them one final link to stay ("If you want to keep getting emails, click this once"). If they click, they stay. If they do not, the ESP auto-removes them. |
| Single CTA | "Keep me on the list" (single link). |
| P.S. | "No email afterward. Thanks for the time you did give." |

**Auto-Scrub Rule (Day 30 + 24h)**

- Subscriber who did not click R7's "keep me" link is automatically unsubscribed or moved to a suppressed segment
- They stop receiving emails
- Their records stay in the ESP for compliance but are excluded from all active sends

Writing rules for Final-Scrub:
- The scrub happens. No "well, maybe next time" exceptions. The value of the re-engagement sequence is the cleaning action itself.
- The final "keep me" link is a single, low-friction click. No form, no field, no reply required.
- Tone is respectful. These subscribers gave attention at some point. They leave with thanks.

## Subject Line Bank — 15 Re-Engagement Patterns

1. "Are you still on this list?"
2. "Quick check-in"
3. "The one thing I've figured out since we last talked"
4. "Here's the one idea still working for me"
5. "[Case subject] went from [A] to [B] in [N] weeks"
6. "Yes or no?"
7. "Stay on this list?"
8. "One more thing before I let this go"
9. "Final useful idea"
10. "Taking you off the list today"
11. "Last email from me unless you say otherwise"
12. "Short one: are you in or out?"
13. "I'll stop emailing unless..."
14. "I miss you" is banned. Never use corporate "we miss you" framing.
15. "Important: list cleanup today"

## P.S. Bank — 10 Patterns Specific to Re-Engagement

1. Scrub deadline restated plainly.
2. Three-way option reminder (stay, pause, leave).
3. Link to a public content home base for anyone who wants to stay in touch without email.
4. One-sentence note about why the creator is cleaning the list (usually deliverability).
5. "No pitch. This isn't a launch" note.
6. Pointer to the most useful piece of public content the creator has made this year.
7. Brief note that the creator will not email after the scrub.
8. Optional reply prompt: one word keeps them on the list.
9. Link to social handle for anyone who wants non-email connection.
10. Thank-you without sycophancy, for the attention they did give.

## Segmentation + Tag Logic

| Trigger | Tag Added | Tag Removed |
|---|---|---|
| Enter re-engagement sequence | re-engage-active | cold-nurture, cold-welcome, any other dormant tag |
| Click "I'm still in" in R1 | re-engaged, back-to-nurture | re-engage-active |
| Click "Pause for 60 days" | paused-60d | re-engage-active |
| Click any content CTA in R2 to R4 | partial-re-engage | |
| Click "Yes" in R5 | re-engaged, back-to-broadcast | re-engage-active, partial-re-engage |
| Click "Pause" in R5 | paused-60d | re-engage-active |
| Click "No" in R5 or R7 | opted-out | all active tags |
| Reach R7 + 24h without click | scrubbed | all active tags, off main list |

## Cadence Fatigue Check

Re-engagement cadence is spread deliberately. Day 0, 3, 7, 12, 18, 25, 30 gives dormant subscribers room to notice. Protect the sequence by:

- Never running re-engagement in parallel with launch or webinar promotion to the same subscriber.
- Not resurrecting a subscriber who was scrubbed in a prior quarter without a fresh opt-in (their silence was the answer).
- Capping re-engagement attempts at 2 per subscriber per year, lifetime.
- Running re-engagement as a scheduled quarterly cleanup, not a reaction to one bad open rate.

## Benchmarks and What They Tell You

| Metric | Healthy Range | If Below | If Above |
|---|---|---|---|
| R1 open rate | 12 to 25 percent | Subscribers are truly dormant (expected) | These weren't really cold; check the tag logic |
| R5 direct-ask click rate | 3 to 8 percent | Fine, most ghosts do not engage | Audience was under-emailed, not disengaged |
| Final scrub rate (subscribers auto-removed) | 40 to 70 percent of enrollers | Suspiciously low, check ESP is actually executing the rule | Healthy cleanup |
| Explicit unsubscribe rate | 5 to 15 percent of enrollers | Fine | Audience was frustrated; review the sending cadence that created the dormancy |
| Re-engaged rate (back to nurture/broadcast) | 10 to 25 percent | List is truly cold | Healthy re-awakening |

A successful re-engagement sequence removes 50 to 70 percent of its enrollers. That is the point.

## Voice-Match and Compliance Rules Specific to Re-Engagement

- Every email uses 2 or more `phrases_to_use` from Compartment 1 (slightly lower than other sequences because the voice is deliberately flat and direct).
- Banned-vocabulary sweep clean.
- No corporate "we miss you" framing.
- No fake-reply subjects.
- Every email carries CAN-SPAM footer, physical address, unsubscribe link.
- Auto-scrub action respects GDPR if EU subscribers are in scope: the data retention policy must be explicit.

## Common Failure Modes

1. Sequence runs with no auto-scrub rule. List stays dirty. Deliverability stays low. Fix: configure the Day-30-plus-24h auto-scrub before shipping.
2. Tone is corporate or guilt-trippy. "We've missed you!" reads as spam. Subscribers mark as spam. Fix: write in plain, adult, direct tone.
3. Offer is mentioned. The still-hot subscriber sees a pitch during re-engagement. Unsubscribe rate spikes. Fix: re-engagement is content and choice, not pitch.
4. Cadence too tight (every other day). Dormant subscribers feel pressured. Unsubscribe rate spikes. Fix: space at Day 0, 3, 7, 12, 18, 25, 30.
5. The three options in R1 and R5 are not equal. Unsubscribe is buried. Borderline subscribers stay and stay disengaged. Fix: surface all three options equally.
6. Running re-engagement during a launch or webinar promotion. Subscriber sees conflicting cadences and messages. Fix: re-engagement runs in its own window only.
7. Same subscribers re-entering the sequence each quarter. The scrub is not actually scrubbing. Fix: verify the ESP's suppression list is receiving the scrubbed records.

## Next Sequence Routing

| End-of-Sequence Tag | Next Route |
|---|---|
| re-engaged, back-to-nurture | Nurture Phase 1 for 30 days, then broadcast |
| re-engaged, back-to-broadcast | Weekly broadcast |
| partial-re-engage | Broadcast only, at reduced cadence (every other week for 60 days) |
| paused-60d | No emails for 60 days, then a single check-in, then auto-scrub if no response |
| opted-out | No further emails. Respect the choice. |
| scrubbed | No further emails. Record stays for compliance only. |

## Verification Checklist

- [ ] Dormancy threshold defined (60 to 90 days no opens)
- [ ] Auto-scrub rule live in the ESP for Day-30-plus-24h
- [ ] All 5 to 8 emails drafted with subject, preview, body, single CTA, P.S.
- [ ] Three-way option set (stay, pause, leave) in R1 and R5
- [ ] Single "keep me" link in R7 for final-chance click
- [ ] No offer pitches in any email
- [ ] 2 or more `phrases_to_use` per email
- [ ] Banned-vocabulary sweep clean
- [ ] CAN-SPAM plus GDPR compliance verified
- [ ] Re-engagement runs in its own window with no overlap to launch, webinar, or broadcast
- [ ] Suppression list receiving scrubbed records, verified
- [ ] Next-sequence routing rules wired
- [ ] Scheduled as quarterly cadence in the calendar

---
*v1.0 — re-engagement-sequence variant of /email-sequence. Pairs with nurture-sequence and welcome-sequence (upstream trigger when subscribers go cold) and back into nurture-sequence or broadcast (downstream for successfully re-engaged subscribers).*
