---
variant: welcome-sequence
parent_skill: email-sequence
scope: Onboarding new subscribers immediately after opt-in. Delivers the lead magnet, establishes the creator as the in-group authority, seeds the unique mechanism, and routes to the first soft offer mention.
triggers:
  - subscriber opts into a lead magnet, quiz, calculator, or training
  - tag added by ESP on form submission
  - post-purchase of a low-ticket tripwire (treated as high-intent opt-in)
sequence_length: 5-7 emails
window: 14 days (Day 0 through Day 14)
cadence: Day 0 (immediate) / Day 1 / Day 3 / Day 5 / Day 7 / Day 10 / Day 14
open_rate_target: 45 to 60 percent average across sequence
click_rate_target: 8 to 15 percent average across sequence
unsubscribe_loss_budget: 1.5 to 3 percent cumulative across the full sequence
conversion_event: opt-in of welcome sequence to first soft CTA click or booked call
version: 1.0
---

# Welcome Sequence Playbook

## Role In the System

The welcome sequence is the first chance the subscriber hears from the creator in their inbox. It owns three jobs and only three:

1. Deliver the promised asset within 2 minutes of opt-in. Late delivery kills the trust that the lead magnet title just built.
2. Reset expectations. The subscriber came for one thing. This sequence shows what else they will get, how often, and what the creator stands for.
3. Plant the mechanism. By the end of Email 3, the subscriber should be able to name the creator's unique mechanism in a sentence of their own words.

The welcome sequence is a not a launch sequence and is not a nurture sequence. If it acts like either one, it dies. Launch sequences sell inside a window. Nurture sequences pace belief over months. Welcome sequences earn the right to send both of those later.

## Gate-in Conditions

Ship this sequence only if:

- Lead magnet is live, tested, and delivers within 120 seconds of form submit
- Compartment 2 (Audience) is at 60 percent or higher, so the greeting is written to a specific ICP not a generic subscriber
- Compartment 3 (Offer) is at 50 percent or higher, so Email 6 has a real offer to soft-mention
- Compartment 1 brand voice phrases_to_use list has at least 15 entries
- ESP is configured with CAN-SPAM footer, verified sender, and physical address on record

## The 5-to-7 Email Structure

### Email 1 — Deliver + Orient (Day 0, sent within 2 min of opt-in)

| Component | Spec |
|---|---|
| Subject | "[Your asset] is inside" or "Ready as promised" (40 to 50 chars) |
| Preview text | Names the asset's primary payoff in 35 to 90 chars |
| Hook line | One sentence. Delivers the asset. "The [asset name] is below." |
| Body | Three short paragraphs. What the asset is. How to use it in the next 15 minutes. What comes next from this address. |
| Single CTA | Download link or inline asset attachment |
| Sign-off | Creator's first name, not the brand |
| P.S. | One line naming the next email's topic. Builds stay-through. |

Writing rules specific to Email 1:
- Never bury the asset below the fold. First CTA is in the first 40 lines of pixel height.
- Never ask a question that invites a reply yet. The subscriber does not know this creator well enough to write back on Day 0.
- Never mention the paid offer. This email is a delivery receipt, not a pitch.

### Email 2 — Origin Story (Day 1)

| Component | Spec |
|---|---|
| Subject | Contrarian belief or personal-crisis angle. "I used to think [conventional view]. I was wrong." |
| Preview text | Extends the subject curiosity gap without repeating it |
| Hook line | One-sentence scene anchor. "It was a Tuesday. The bank balance showed $184." |
| Body | 250 to 400 words. Three beats: where the creator was stuck, what they tried that did not work, the shift that started to work. End the body at the shift. Do not explain the mechanism yet. |
| Single CTA | Soft CTA back to a piece of pillar content (not to the offer) |
| Sign-off | First name |
| P.S. | Teaser for Email 3: "Tomorrow I'll show you exactly what I did." |

Writing rules:
- Story must be isomorphic to the target ICP's current state. A creator who started as a broke trainer speaks to broke trainers, not to enterprise buyers.
- End the story one beat before the resolution. That gap is what drags Email 3 open.
- No calls to buy anything in this email.

### Email 3 — Mechanism Reveal, One Sub-step (Day 3)

| Component | Spec |
|---|---|
| Subject | Names the mechanism. "The [mechanism name] that flipped it" |
| Preview text | Promises the one sub-step inside |
| Hook line | Delivers on yesterday's open loop. "Yesterday I said I would show you the shift. Here it is." |
| Body | 300 to 500 words. Name the mechanism. State the three to five sub-steps at a high level. Expand only one of them in detail. Tease the rest for future emails. |
| Single CTA | Soft CTA to a piece of content that goes deeper on the mechanism (blog post, YouTube video, podcast episode) |
| Sign-off | First name |
| P.S. | Preview Email 4: an isomorphic case study using this exact mechanism |

Writing rules:
- Teach what the mechanism does, not the full how-to. The full how-to lives inside the paid offer.
- Name the mechanism the exact same way every single time. Consistency is compounding here.
- Do not compare to competitor mechanisms by name.

### Email 4 — Isomorphic Case Study (Day 5)

| Component | Spec |
|---|---|
| Subject | Specific number plus timeframe. "$7,500 in 11 days using [mechanism]" |
| Preview text | Tells the reader who the case study subject is |
| Hook line | Names the person (first name plus identity tag). "Jenna runs a bookkeeping practice in Cleveland." |
| Body | Four beats in 300 to 450 words: starting situation, what she tried, the mechanism applied, the measurable outcome. Include one verbatim quote from the case study if you have it. |
| Single CTA | "Here's what she actually did" linking to a longer case study page or video |
| Sign-off | First name |
| P.S. | One-liner noting Email 5 will handle the top objection |

Writing rules:
- Case subject must mirror the ICP. Same stage, same role, same core pain.
- Cite only real, permission-cleared cases. No composites. No "someone I worked with."
- If no permission-cleared cases exist, swap Email 4 for a second mechanism sub-step and flag the gap to the creator.

### Email 5 — Objection Pre-Handle (Day 7)

| Component | Spec |
|---|---|
| Subject | Flips a belief the reader holds. "Why time is not your real problem" |
| Preview text | Names the specific objection about to be handled |
| Hook line | Quotes the objection back at them. "Most people tell me: 'I'd love to but I don't have the time.'" |
| Body | 300 to 400 words. State the objection. Validate it (briefly). Reframe it using the mechanism. Give a micro-action they can take today that proves the reframe. |
| Single CTA | Micro-action CTA (complete a worksheet, reply with one word, take a 5-minute action). Not a purchase CTA. |
| Sign-off | First name |
| P.S. | Sets up Email 6 as the first soft offer mention |

Writing rules:
- Pick the number-one objection from the ICP objection library, not a made-up one.
- Reframe the objection inside the mechanism's language. The reader should feel that this creator has heard this exact concern before.
- This is the last email before any offer mention. If it feels like a pitch, it has failed.

### Email 6 — Soft Offer Mention (Day 10)

| Component | Spec |
|---|---|
| Subject | Curiosity around the offer without naming the price. "What I actually do for clients" |
| Preview text | Frames the offer as optional, not urgent |
| Hook line | Permission frame. "A few of you have asked: what is it you actually sell?" |
| Body | 250 to 400 words. Name the offer. Name who it is for (reinforce ICP). Name one outcome. Name the call to action (booking, application, VSL watch, cart). Do not stack bonuses or urgency. |
| Single CTA | Direct link to the next asset in the funnel (VSL, application, landing page) |
| Sign-off | First name |
| P.S. | "If this isn't the right time, ignore it. Tomorrow I'll send something useful regardless." |

Writing rules:
- This is the first time the offer is mentioned. It must feel inevitable, not pushed.
- The CTA is optional for the reader. Making it optional is what makes it work.
- Never stack urgency here. Urgency goes in launch sequences, not welcome sequences.

### Email 7 — Decision Point (Day 14, optional)

| Component | Spec |
|---|---|
| Subject | Directly asks the reader to choose. "Ready, not ready, or not for you?" |
| Preview text | Frames the three-way choice |
| Hook line | "You've been reading for two weeks. Three options from here." |
| Body | 250 to 400 words. Option A: ready, here is the next step. Option B: not ready, stay on the main list for weekly value. Option C: this is not for you, here is the unsubscribe link. Treat all three as legitimate. |
| Single CTA | Primary CTA to Option A with Options B and C as plain text links |
| Sign-off | First name |
| P.S. | "Whichever option you pick, thanks for being here." |

Writing rules:
- Offering the unsubscribe explicitly raises trust and cleans the list. Do not hide Option C.
- Email 7 is optional. Shorter 5-email sequences omit it.
- Never use fake-reply subjects ("Re:") to boost Email 7 open rate.

## Subject Line Bank — 15 Ready-to-Adapt Patterns

1. "[Your asset] is inside"
2. "Ready as promised"
3. "I was wrong about [common belief]"
4. "The [mechanism] that flipped it"
5. "[Number] days. [Specific outcome]. Here's how."
6. "Why [common objection] is not your real problem"
7. "What I actually do for clients"
8. "Ready, not ready, or not for you?"
9. "[First name of case subject] hit [specific number]"
10. "The one thing I wish I'd known at [ICP stage]"
11. "A question I keep getting from [ICP segment]"
12. "This took me [timeframe] to figure out"
13. "If you're stuck at [specific milestone]"
14. "Here's the shortest version"
15. "Before you go any further, read this"

Test two subjects per email. Rotate winners in every 60 days.

## P.S. Bank — 10 Proven Patterns

1. Preview the next email by name.
2. Restate the single CTA in fresher language.
3. Link to a longer-form piece of content that supports the email's point.
4. Ask a one-word reply question that tells the ESP this subscriber is engaged.
5. Quote a line from a case study that reinforces the email's main idea.
6. Name a deadline if one exists, but never invent one.
7. Flag what is coming in the next 7 days at a high level.
8. Address one specific objection in a single sentence.
9. Thank them for reading without sycophancy. One line maximum.
10. Share a link to unsubscribe or switch list, stated plainly.

## Segmentation + Tag Logic

Every welcome sequence ships with this tag map declared upfront:

| Trigger | Tag Added | Tag Removed |
|---|---|---|
| Opt-in on lead magnet | welcome-active, lm-[magnet-slug] | |
| Open Email 2 | engaged-welcome | |
| Click Email 3 content link | interested-mechanism | |
| Click Email 4 case study | interested-case-study | |
| Click Email 5 micro-action | interested-action | |
| Click Email 6 offer CTA | interested-offer | welcome-active |
| Reach Email 7 without any clicks | cold-welcome | welcome-active |
| Click unsub in Email 7 | off-list | all above |

The tag map is what lets the creator route subscribers into the right next sequence (nurture, launch, application, or re-engage) without manual sorting.

## Cadence Fatigue Check

A 7-email welcome sequence running across 14 days averages one email every other day. That is hot but not scorching. If the subscriber is also on a weekly broadcast list, pause the broadcast until the welcome finishes, then resume. Overlapping cadences are the single most common cause of early unsubscribes.

## Benchmarks and What They Tell You

| Metric | Healthy Range | If Below | If Above |
|---|---|---|---|
| Email 1 open rate | 55 to 75 percent | Deliverability issue or wrong sender name | Subject too tight, maybe curiosity-heavy |
| Email 1 click rate | 40 to 60 percent (asset download) | Asset link broken or CTA buried | Fine, carry on |
| Sequence-average open rate | 45 to 60 percent | Lead magnet attracting wrong audience | Fine, sequence is working |
| Sequence-average click rate | 8 to 15 percent | Weak CTAs or content not relevant | Fine, carry on |
| Cumulative unsubscribe rate | 1.5 to 3 percent | Highly engaged list | Cadence too heavy or wrong audience |
| Email 6 offer CTA click rate | 3 to 8 percent | Offer mismatch or soft CTA too quiet | Fine, route to next funnel step |

If Email 1 open rate drops below 50 percent, the problem is almost always the sender name, the subject line, or deliverability configuration. Fix that before tuning Emails 2 through 7.

## Voice-Match and Compliance Rules Specific to Welcome

- Each email uses 3 or more `phrases_to_use` from Compartment 1.
- Full banned-vocabulary sweep passes on every email body plus subject plus preview text.
- Sender name is the creator's first name plus last name, never the brand alone.
- Physical address plus unsubscribe link in every email footer.
- No fake-reply subjects, no fake-forward subjects, no fake-read-receipts.
- No income guarantees, no health claims, no before/after without timeline and context.

## Common Failure Modes

1. Asset delivery fails in Email 1. Subscriber never opens Email 2. Fix: test opt-in to delivery on every sequence revision.
2. Origin story in Email 2 is not isomorphic. Subscriber does not identify. Fix: swap the story for one that matches the target ICP stage.
3. Mechanism reveal in Email 3 teaches the full how-to. Subscriber feels done, does not need the offer. Fix: teach the what, tease the how.
4. Case study in Email 4 is impressive but not isomorphic. Reader thinks "that's not me." Fix: use the case study whose starting state most mirrors the ICP.
5. Objection in Email 5 is the wrong objection. Reader feels unheard. Fix: pull the objection from the ICP library, not from assumption.
6. Offer mention in Email 6 stacks urgency and bonuses. Reads like a pitch. Fix: keep it plain. Welcome is not a launch.
7. Decision email in Email 7 hides the unsubscribe option. List gets dirty. Fix: surface all three options equally.

## Next Sequence Routing

After Day 14, subscriber lands in one of four destinations based on tag:

- `interested-offer` tag → route to application sequence or launch sequence at the next open window
- `interested-mechanism` or `interested-case-study` tag → route to nurture sequence
- `engaged-welcome` tag with no interest flag → route to nurture sequence
- `cold-welcome` tag → route to re-engagement sequence in 30 to 45 days
- `off-list` → respect the unsubscribe, do not email again

## Verification Checklist

- [ ] Lead magnet delivery tested end-to-end, under 120 seconds
- [ ] All 5 to 7 emails written with subject, preview, body, single CTA, P.S.
- [ ] 3 or more `phrases_to_use` present per email
- [ ] Banned-vocabulary sweep clean across every email
- [ ] CAN-SPAM footer plus physical address plus unsubscribe link in every email
- [ ] Tag map declared and wired in the ESP
- [ ] Cadence check: no overlapping broadcast during welcome window
- [ ] Email 6 offer CTA points to the correct next-step asset (VSL, application, landing page, cart)
- [ ] Email 7 decision point surfaces all three options equally
- [ ] Next-sequence routing rules written and active
- [ ] Open rate plus click rate benchmarks baselined for first 30 days

---
*v1.0 — welcome-sequence variant of /email-sequence. Pairs with /lead-magnet (upstream) and nurture-sequence, launch-sequence, or application-sequence (downstream).*
