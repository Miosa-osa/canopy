---
variant: launch-sequence
parent_skill: email-sequence
scope: Product launch email flow that compresses 7 to 14 days around an offer window, moving the list from whisper to tease to shout with belief-stacking and urgency that is real rather than invented.
triggers:
  - offer window is open and dated (cart open and cart close specified)
  - list has been nurtured to a minimum of 35 percent warm-mechanism tag density
  - upstream ads or webinar or VSL are feeding fresh registrants into the launch window
sequence_length: 7 to 14 emails
window: 7 to 14 days total; final 24 hours compress 3 to 6 emails
cadence: Whisper (T-7 to T-4), Tease (T-3 to T-1), Shout (T-0 to T+5), Final 24h compression
open_rate_target: 40 to 55 percent sequence average; final 24 hours spikes to 55 to 70 percent
click_rate_target: 10 to 20 percent sequence average
unsubscribe_loss_budget: 3 to 6 percent across the window (launches are expected to unsub at higher rates)
conversion_event: cart purchase, application submit, call book, or tripwire buy
version: 1.0
---

# Launch Sequence Playbook

## Role In the System

A launch sequence does one job that no other sequence does: it compresses a real decision moment into a finite window. The reader must choose to buy or to pass inside the window. After the window closes, the email stops.

Launch sequences exist because compression creates decisions. Open-ended soft CTAs produce open-ended procrastination. A dated window forces a yes, a no, or a not-right-now. All three outcomes are legitimate and trackable.

The sequence is built around three acoustic phases taught by the growth strategist lineage: Whisper (quiet preview), Tease (mechanism reveal plus proof), Shout (direct offer plus escalating urgency). Each phase has its own cadence, its own CTA class, and its own belief check.

A launch sequence is not a nurture sequence and is not a webinar promotion sequence. Nurture paces belief over months. Webinar promotion drives show-up. Launch sequences sell directly inside a window.

## Gate-in Conditions

Ship this sequence only if:

- Cart open date and cart close date and time are locked and dated in the calendar
- Offer (Compartment 3) is at 70 percent or higher, with value stack, bonuses, guarantee, and price finalized
- Audience (Compartment 2) is at 60 percent or higher
- Copy and Messaging (Compartment 5) includes the top 10 objections from the ICP library with scripted responses
- Nurture sequence has been running long enough that at least 35 percent of the list carries the warm-mechanism or hot-lead tag
- Payment processor is tested end-to-end at the exact price point
- Refund policy and guarantee language are legal-reviewed if over $2,000 price point

## The Whisper-Tease-Shout Arc

| Phase | Days Before Close | CTA Class | Belief Focus |
|---|---|---|---|
| Whisper | T-7 to T-4 | No CTA or soft content CTA | Curiosity, trust-person |
| Tease | T-3 to T-1 | Soft mechanism CTA, waitlist or early-bird | Can-fulfill, this-offer, better-faster |
| Shout | T-0 to T+final | Hot purchase CTA | Urgency, trust-expertise |
| Final 24h | Last day | Hot purchase CTA at 3 to 6 hour intervals | Urgency finalized |

Every launch sequence moves through all three phases. Skipping Whisper jumps the reader from cold to pitched. Skipping Tease breaks the mechanism-to-offer bridge. Skipping Shout leaves the offer unclosed. Skipping the final 24h compression leaves 30 to 50 percent of the conversion on the table.

## The 7-to-14 Email Skeleton

### Whisper Phase (2 to 3 emails, T-7 to T-4)

**Email W1 (T-7 or T-6) — Soft Signal**

| Component | Spec |
|---|---|
| Subject | "Something is coming. Context first." or "Before we talk about [outcome]" |
| Preview text | Hints at the mechanism without naming the offer |
| Hook line | Opens a loop. "I've been quiet on this for a reason." |
| Body | 200 to 300 words. Frame the problem. State that something is coming that addresses it. Do not name price, do not name offer. |
| Single CTA | Soft content CTA back to a pillar piece. Or no CTA at all. |
| P.S. | One line promising more context tomorrow. |

**Email W2 (T-5 or T-4) — Contrarian Context**

| Component | Spec |
|---|---|
| Subject | A contrarian frame. "Most [ICP segment] have the diagnosis wrong" |
| Preview text | Extends the contrarian frame |
| Hook line | One-sentence provocation. |
| Body | 300 to 400 words. Argue the contrarian frame with one or two supporting examples. Tie it to the coming offer at the end without naming the offer. |
| Single CTA | Soft content CTA, or micro-survey (one question reply). |
| P.S. | Flag that a full teach is coming in the Tease phase. |

Writing rules for Whisper:
- Never name the price.
- Never name the cart open date yet. That lands in Tease.
- Never ask for a purchase. The job is to raise curiosity and light up engagement signals in the ESP.

### Tease Phase (2 to 4 emails, T-3 to T-1)

**Email T1 (T-3) — Mechanism Reveal**

| Component | Spec |
|---|---|
| Subject | Names the mechanism. "The [mechanism name] behind this" |
| Preview text | Promises the three to five sub-steps |
| Hook line | Delivers on the loop from Whisper. |
| Body | 400 to 500 words. Name the mechanism. State the sub-steps. Teach one sub-step at a conceptual level. End with "Monday, I open the doors on something built around this." |
| Single CTA | Soft CTA to a mechanism deep-dive asset, or waitlist sign-up if a waitlist exists. |
| P.S. | First explicit mention of the cart open date. |

**Email T2 (T-2) — Case Study + Offer Frame**

| Component | Spec |
|---|---|
| Subject | Specific outcome plus timeframe. "$14,200 in 19 days using [mechanism]" |
| Preview text | Names the case subject |
| Hook line | Anchor the case subject as isomorphic to the reader. |
| Body | 400 to 500 words. Full case study. Ends with "Tomorrow I'll send the full details. Saturday at 9am PT, the doors open." |
| Single CTA | Back to a long-form case study or testimonial video. |
| P.S. | Cart open date and time restated plainly. |

**Email T3 (T-1) — Offer Preview**

| Component | Spec |
|---|---|
| Subject | "Tomorrow at [time]: here's what's inside" |
| Preview text | Promises the specifics |
| Hook line | Names what opens tomorrow. |
| Body | 400 to 600 words. Name the offer. Name who it is for. Name the components at a high level. Name the guarantee. Name the price only if it is above $1,500 (mid-high ticket is qualified; lower-ticket waits for Shout). |
| Single CTA | Waitlist sign-up, calendar reminder, or early-bird notification opt-in. |
| P.S. | "If you don't want these emails during launch, the pause link is below." Give them the opt-out. |

Writing rules for Tease:
- Mechanism gets the full name in every Tease email.
- Case study must be isomorphic to the ICP, not impressive-but-misaligned.
- Cart open date and time stated at least once per Tease email, same formatting every time.
- Offer a pause-during-launch link. Respects the list and reduces full unsubscribes.

### Shout Phase (3 to 7 emails, T-0 to T+5)

**Email S1 (T-0 morning) — Doors Open**

| Component | Spec |
|---|---|
| Subject | "Doors are open. [N] spots." or "Cart is open until [date]." |
| Preview text | Names the deadline |
| Hook line | "As promised, at [time] the doors opened." |
| Body | 300 to 400 words. Direct offer statement. Full value stack. Full guarantee. Full deadline. |
| Single CTA | Buy now / Apply now / Book now. |
| P.S. | "The deadline is real. [date, time zone]." |

**Email S2 (T+1) — First 24 Hours Recap + Social Proof**

| Component | Spec |
|---|---|
| Subject | "First 24 hours: here's who just said yes" |
| Preview text | Promises social proof |
| Hook line | Specific number of buyers or applicants in first 24h, if real. |
| Body | 300 to 400 words. Social proof at scale (plural, not a single case). Reinforce urgency by counting down the window. |
| Single CTA | Same purchase CTA. |
| P.S. | Deadline reminder. |

**Email S3 (T+2) — Objection Destruction #1 (Money)**

| Component | Spec |
|---|---|
| Subject | "What if I can't afford it?" or "The price objection, answered" |
| Preview text | Frames the ROI |
| Hook line | Quote the objection back. |
| Body | 400 to 500 words. Reframe price as ROI. Payment plan specifics. Link to case studies that earned back the price. |
| Single CTA | Purchase CTA with payment plan explicitly offered. |
| P.S. | Deadline reminder. |

**Email S4 (T+3) — Objection Destruction #2 (Time / Fit)**

| Component | Spec |
|---|---|
| Subject | "I don't have time for another thing" or "Will this work for my situation?" |
| Preview text | Validates then reframes |
| Hook line | Specific case of someone who had the same objection. |
| Body | 400 to 500 words. Isomorphic case study of someone with the exact constraint. Reframe using the mechanism. |
| Single CTA | Purchase CTA. |
| P.S. | Deadline reminder. |

**Email S5 (T+4) — Walk-Through of the Offer**

| Component | Spec |
|---|---|
| Subject | "Inside [offer name]: the full walk-through" |
| Preview text | Promises component-by-component detail |
| Hook line | "For anyone on the fence, here's exactly what's inside." |
| Body | 500 to 700 words. Walk through the offer components one at a time. Name each bonus. Name the guarantee terms. Name the total stated value. Name the price. Math the ROI. |
| Single CTA | Purchase CTA. |
| P.S. | Deadline reminder. |

Writing rules for Shout:
- Every email names the deadline. Same formatting. Same time zone.
- Every email has exactly one CTA. No multi-CTA emails.
- Never invent urgency. If no spots limit exists, urgency lives only in the cart close date.
- Reference only real buyers in social proof. Plural counts acceptable if they are real counts.

### Final 24 Hours Compression (3 to 6 emails, last day of window)

The last 24 hours is the single highest-leverage email block in a launch. Expect 30 to 50 percent of total launch revenue to land inside this window.

**Email F1 (24h before close) — "24 hours left"**
- Subject: "24 hours" or "Final day"
- Body: 150 to 250 words. Tight. Restate offer, restate guarantee, restate deadline. One CTA.

**Email F2 (12h before close) — "12 hours"**
- Subject: "12 hours" or "Tonight at midnight"
- Body: 150 to 250 words. Even tighter. Final FAQ link. One CTA.

**Email F3 (6h before close) — "Final 6"**
- Subject: "6 hours. Read this only if you're still deciding."
- Body: 200 to 300 words. Address the fence-sitter directly. State the cost of waiting until the next launch. One CTA.

**Email F4 (3h before close) — "Final 3"**
- Subject: "3 hours. Last call."
- Body: 100 to 200 words. Purely urgency. One CTA.

**Email F5 (1h before close) — "Final hour"**
- Subject: "Doors close at [time]."
- Body: 80 to 150 words. Urgency finalized. One CTA.

**Email F6 (post-close, within 30 min) — "Doors closed"**
- Subject: "Doors are closed."
- Body: 150 to 250 words. Thank the list. Validate those who did not buy. Flag when the next window opens or where to land in the waitlist. No CTA.

Writing rules for Final 24h:
- Emails get shorter, not longer. Reader attention is compressed.
- Every email has the deadline. Every email has one CTA.
- Do not extend the deadline after it closes. Integrity of the window is the only reason the window has force next time.
- The post-close email treats non-buyers with respect. They are future buyers.

## Subject Line Bank — 15 Launch-Specific Patterns

1. "Something is coming. Context first."
2. "Before we talk about [outcome]"
3. "Most [ICP] have the diagnosis wrong"
4. "The [mechanism] behind this"
5. "$[Number] in [N] days using [mechanism]"
6. "Tomorrow at [time]: here's what's inside"
7. "Doors are open. [N] spots."
8. "First 24 hours: here's who just said yes"
9. "What if I can't afford it?"
10. "Will this work for my situation?"
11. "Inside [offer name]: the full walk-through"
12. "24 hours"
13. "6 hours. Read this only if you're still deciding."
14. "3 hours. Last call."
15. "Doors are closed."

## P.S. Bank — 10 Patterns Specific to Launch

1. Deadline restated with full date, time, and time zone.
2. Link to a pause-during-launch opt-out (Whisper and Tease only).
3. Link to an FAQ page.
4. Payment plan callout for Money objection handling.
5. Guarantee restated in one sentence.
6. "If this doesn't feel right, that's a legitimate no" (reduces unsub pressure).
7. Count of seats remaining if a real limit exists. Never invent one.
8. Link to a long-form walk-through video.
9. Reminder of which bonus expires at which milestone.
10. Thank-you without sycophancy, once per phase maximum.

## Segmentation + Tag Logic

| Trigger | Tag Added | Tag Removed |
|---|---|---|
| Enter launch sequence | launch-active, launch-day-0 | nurture-active |
| Click any Tease CTA | launch-warm | |
| Click any Shout CTA without purchase | launch-hot | launch-warm |
| Purchase | buyer, post-purchase-sequence-queued | launch-active, launch-warm, launch-hot |
| Click pause-launch link | launch-paused | launch-active |
| Reach Final 24h without purchase and without click | launch-cold | launch-warm, launch-hot |
| Cart closes without purchase | post-launch-non-buyer | launch-active |

## Cadence Fatigue Check

Launches are the most cadence-heavy sequence in the system. The list is expected to burn at 3 to 6 percent unsubscribe during the window. Protect the list by:

- Stopping broadcast cadence during the full launch window.
- Offering the pause-during-launch link in Whisper W2 and Tease T3.
- Respecting the post-close opt-outs silently. Do not ask why.
- Rotating the launch to the same list at most 2 to 3 times per calendar year at full intensity.

## Benchmarks and What They Tell You

| Metric | Healthy Range | If Below | If Above |
|---|---|---|---|
| Whisper open rate | 35 to 50 percent | Subject too vague, preview text weak | Fine |
| Tease click rate | 8 to 15 percent | Mechanism reveal not landing | Strong launch is loading |
| Shout open rate | 45 to 60 percent | Urgency is not real or not clear | Fine |
| Final 24h open rate | 55 to 70 percent | Deadline not salient | Expect 30 to 50 percent of revenue here |
| Conversion rate on list | 1 to 4 percent for $1K-$3K offers, 0.3 to 1 percent for $5K+ offers | Offer-message fit is off | Scale traffic next launch |
| Unsubscribe during launch | 3 to 6 percent | Launch landed soft, which is fine | Cadence too heavy or audience mismatch |

## Voice-Match and Compliance Rules Specific to Launch

- Every email uses 3 or more `phrases_to_use` from Compartment 1.
- Full banned-vocabulary sweep passes on every email body plus subject plus preview text.
- Never invent scarcity. No fake "only 7 spots left" unless it is literally true.
- Never extend the deadline after it closes.
- Every email carries CAN-SPAM footer, physical address, unsubscribe link.
- Refund policy and guarantee terms visible in at least one email of the Shout phase and on the cart page.
- No income guarantees in any email. "Results vary" disclosure where testimonial numbers appear.

## Common Failure Modes

1. Launch opens to a cold list. Conversion rate is sub-0.3 percent. Fix: nurture the list to 35 percent warm-mechanism tag density before launching again.
2. Cart open date never stated clearly. Buyers miss the window. Fix: stated in every Tease and Shout email, same format.
3. Deadline extended post-close. Next launch has zero urgency force. Fix: respect the deadline even when revenue is down.
4. No final 24h compression. Revenue leaves 30 to 50 percent on the table. Fix: minimum 3 emails in the last 24 hours.
5. Shout phase includes more than one CTA per email. Click-through drops. Fix: one CTA, repeated across emails, not stacked inside one.
6. Objection destruction emails are generic. Fence-sitters do not see themselves. Fix: pull objections from the actual ICP objection library.
7. Broadcast list keeps running during launch. Cadence doubles. Unsubscribe doubles. Fix: pause all non-launch emails for the window.

## Next Sequence Routing

| End-of-launch Tag | Next Route |
|---|---|
| buyer | Post-purchase sequence triggered within 2 minutes of purchase |
| post-launch-non-buyer with launch-hot | Back to nurture Phase 4 for 14 days, then warm CTA, then next launch |
| post-launch-non-buyer with launch-warm | Back to nurture Phase 3 for 30 days |
| launch-cold | Back to nurture Phase 1 for 45 days, or re-engagement if no opens |
| launch-paused | Resume last active sequence at next sequence start |

## Verification Checklist

- [ ] Cart open date and cart close date locked
- [ ] Offer at 70 percent with finalized value stack, bonuses, guarantee, price
- [ ] Payment processor tested end-to-end
- [ ] Refund and guarantee language legal-reviewed if price is $2K or higher
- [ ] All 7 to 14 emails drafted with subject, preview, body, single CTA, P.S.
- [ ] Final 24 hours has 3 to 6 compressed emails
- [ ] Every email states the deadline identically
- [ ] Every email has exactly one CTA
- [ ] Pause-during-launch link live and offered in Whisper and Tease
- [ ] Objection destruction emails drawn from the real ICP objection library
- [ ] 3 or more `phrases_to_use` per email
- [ ] Banned-vocabulary sweep clean
- [ ] Broadcast cadence paused for the full window
- [ ] Tag map live and active
- [ ] Post-launch routing rules wired for buyers, fence-sitters, and cold segments

---
*v1.0 — launch-sequence variant of /email-sequence. Pairs with nurture-sequence (upstream) and post-purchase-sequence (downstream for buyers), back into nurture-sequence (for fence-sitters).*
