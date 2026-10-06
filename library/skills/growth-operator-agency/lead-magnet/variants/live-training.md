---
variant: live-training
parent_skill: lead-magnet
scope: Free training delivered as a live or pre-recorded session. 30 to 90 minutes of teaching that functions as a lead magnet while also filtering for high-intent prospects and bridging to a core-offer pitch. Serves as the front-door asset for webinar funnels and application funnels.
length: 30 to 90 minutes
consumption_time: 30 to 90 minutes on live attendance or replay
opt_in_rate_target: 25 to 40 percent on warm traffic; 12 to 22 percent on cold traffic
design_weight: 25 percent of perceived value; content authority and delivery quality own 75 percent
bridge_to_offer: final 10 to 20 percent of the training; explicit pitch transition
delivery_channel: webinar platform for live; hosted video page for pre-recorded; email reminders drive show-up
version: 1.0
---

# Live Training Playbook

## Role In the Funnel

A live training is the highest-intent lead magnet. Opting in means the reader has committed 30 to 90 minutes of their future time. That commitment filters for prospects who are further along the readiness curve than any text lead magnet could filter.

Three jobs:

1. Teach a mental model or tactical skill at depth impossible in a PDF or checklist.
2. Filter for high-intent prospects by extracting the 30-to-90-minute commitment up front.
3. Bridge to the core offer from a position of demonstrated authority earned during the session.

A live training is not a full-length webinar and is not a mini course. Full webinars have explicit sales transitions and Q&A as a close mechanism. Mini courses are serialized across days. A live training is a single session, positioned as teaching, with a bridge-to-offer inside the last fifth.

## Gate-in Conditions

Ship a live training only if:

- Compartment 2 (Audience) at 65 percent
- Compartment 3 (Offer) at 70 percent; the offer the training bridges to must be defined with price, guarantee, and bonuses
- Compartment 5 (Copy and Messaging) at 40 percent; the training's hooks and objection-handling draw from this compartment
- Creator's mechanism is named and can be taught in one session at depth
- Webinar platform configured and tested
- Registration-to-show-up email sequence drafted (pairs with /email-sequence webinar-promotion-sequence if already defined)

## Structural Anatomy

A 60-minute live training maps to this segment layout:

| Segment | Time | Purpose |
|---|---|---|
| Opening + authority frame | 0 to 8 min | Hook, introduce creator, establish authority |
| Problem frame | 8 to 15 min | State the problem in ICP voice; name the three failure modes |
| Mechanism reveal | 15 to 25 min | Name the mechanism and its 3 to 5 sub-steps |
| Sub-step teaching | 25 to 45 min | Teach 2 to 3 sub-steps with examples |
| Case study or demo | 45 to 52 min | Isomorphic case study using the full mechanism |
| Bridge to offer | 52 to 58 min | Transition into offer pitch, name the offer, state the next step |
| Q&A or close | 58 to 60 min | Brief Q&A if live; end screen with CTA if pre-recorded |

Longer 90-minute trainings expand the sub-step teaching or add a second case study. Shorter 30-minute trainings compress the problem frame and teach a single sub-step at depth.

## Segment Writing Rules

### Opening + Authority Frame

- Hook in the first 30 seconds. A contrarian belief or specific-outcome claim.
- Introduce creator in 60 to 90 seconds. Results plus relevance, not a resume.
- State what the training covers, what it does not cover, and why it matters.
- Name one outcome the attendee will be able to do by the end.

### Problem Frame

- Describe the problem using Compartment 2 voice-of-customer language.
- Name three failure modes most audience members are currently stuck in.
- Build emotional stakes without performing. Specific > dramatic.
- End with "The mechanism that resolves this is what we cover next."

### Mechanism Reveal

- Name the mechanism explicitly.
- State 3 to 5 sub-steps at the conceptual level.
- Explain the ordering logic (why sub-step one precedes two).
- Preview which sub-steps the training will teach in depth.

### Sub-step Teaching

- Pick 2 to 3 sub-steps to teach at depth (not all of them; the offer covers the rest).
- Each sub-step: definition, why it matters, how to apply it, one example.
- Use screen-share for demos, diagrams, or data where applicable.
- Keep teaching tight. Filler kills attention mid-training.

### Case Study or Demo

- One isomorphic case study that walks through the mechanism's full sub-step sequence.
- Specific numbers, specific timelines, specific starting and ending states.
- Permission-cleared.
- End with "That is what the mechanism does when applied end-to-end."

### Bridge to Offer

- Transition sentence: "For the people who want to implement this end-to-end with support, here is what I do."
- Name the offer.
- Name who it is for (reinforce ICP).
- Name the components at a high level.
- Name the guarantee.
- State the price and the specific next step (cart, application, or calendar).
- Keep this under 7 minutes. Longer feels like a webinar close; shorter feels like an afterthought.

### Q&A or Close

- Live: 2 to 10 minutes of Q&A. Scripted answers for the top 5 objections from the ICP library.
- Pre-recorded: end screen with the offer CTA, the calendar link, or the application link.

## Title Patterns — 10 Options

1. "How to [Specific Outcome] in [Timeframe] Using [Mechanism Name]"
2. "The [N]-Step [Mechanism] Training for [ICP Role]"
3. "[Specific Outcome]: A Free Training for [ICP Role]"
4. "[Contrarian Belief]: What [Conventional Approach] Gets Wrong"
5. "The [Industry] [Topic] Training: Live on [Date]"
6. "How [Case Subject] Went from [State A] to [State B] in [Timeframe]"
7. "[Specific Transformation] in One Session"
8. "The [Mechanism] Deep-Dive for [ICP Role]"
9. "Live Training: [Specific Outcome]"
10. "[N] Moves That [Specific Outcome]"

## Opt-in Page Copy Structure

- Hook headline: training title with specific outcome and ICP role.
- Subhead: "[Duration] live training on [date and time]. Replay available."
- Three to five bullets naming what will be covered.
- Social proof if available: count of past training attendees or a testimonial.
- Registration form: first name, last name, email (more fields for live trainings than static lead magnets because the commitment is higher).
- CTA button: "Save my spot."
- Fine print: live attendance recommended, replay available for a limited window.

Opt-in page runs 400 to 700 words. Live trainings earn a longer opt-in page because the time commitment is the barrier.

## Registration + Show-Up Flow

After registration:

- Immediate confirmation email with the date, time, time zone, and calendar add link.
- Pre-training email sequence: T-7d invite (if scheduled far out), T-3d value preview, T-1d reminder, T-1h join link, T-10min final nudge.
- Use /email-sequence webinar-promotion-sequence for the full drip pattern.

Live trainings have lower show-up rates than paid webinars because the commitment is free. Target 35 to 50 percent show-up rate for a well-nurtured list.

## Delivery Automation

- Opt-in fires on registration submit.
- ESP tags: `lm-training-[slug]`, `training-registered-[date-slug]`, `welcome-active`.
- Confirmation email under 120 seconds with calendar invite.
- Reminder emails drip on pre-training schedule.
- Replay email fires within 2 hours of training end with the replay link and a replay-window deadline (48 to 72 hours typical).
- Post-training sequence begins the next day; aligns with the webinar-promotion-sequence's post-webinar emails.

## Design Specs

Live platform:
- Webinar platform tested for capacity, bandwidth, chat moderation.
- Slide deck with clean typography and minimal text per slide.
- Screen-share setup for demos, if applicable.
- Creator on-camera or voice-over; pick one and commit.

Replay page:
- Hosted video embed.
- Companion CTA below the video pointing to the offer or next step.
- Replay-window countdown visible.

## Benchmarks and What They Tell You

| Metric | Healthy Range | If Below | If Above |
|---|---|---|---|
| Opt-in rate on warm traffic | 25 to 40 percent | Title vague or time commitment too steep | Fine |
| Opt-in rate on cold traffic | 12 to 22 percent | Topic mismatch or trust gap | Fine |
| Show-up rate (live) | 35 to 50 percent | Reminder cadence weak | Fine |
| Replay consumption (missers) | 40 to 60 percent | Replay deadline not salient | Fine |
| Post-training offer click rate | 8 to 18 percent | Offer mismatch or bridge weak | Strong |
| Live attendee to buyer conversion | 3 to 10 percent | Offer or bridge weak | Strong |
| Replay viewer to buyer conversion | 2 to 6 percent | Bridge weak in replay | Fine |

## Common Failure Modes

1. Title is generic. Opt-in rate below 15 percent. Fix: specificity score 8 or higher with ICP role and outcome named.
2. Authority frame is a resume recital. Audience tunes out in first 5 minutes. Fix: lead with results and relevance, not credentials.
3. Teaching is too broad. Training covers 5 sub-steps superficially. Audience walks away without a single tool. Fix: 2 to 3 sub-steps at depth.
4. Case study is not isomorphic. Audience sees "that's impressive but not me" and checks out. Fix: case subject matches ICP stage.
5. Bridge is 15 or more minutes. Feels like a webinar in disguise. Trust erodes. Fix: bridge under 7 minutes.
6. Replay deadline is open-ended. Replay consumption drops below 30 percent. Fix: 48-to-72-hour replay window, deadline stated clearly.
7. No post-training sequence. Replay viewers watch and never hear from creator. Fix: post-training sequence aligns with webinar-promotion-sequence.

## Voice-Match and Compliance

- 3 or more `phrases_to_use` across the training script.
- Banned-vocabulary sweep clean on opt-in page, reminder emails, replay page, and follow-up.
- No income guarantees in the offer pitch.
- All case studies permission-cleared.
- FTC disclosure if testimonials appear on the slide deck.
- Refund and guarantee language legal-reviewed for the offer pitched.

## Next Step Routing

After the training completes:

- Attendees who clicked offer CTA → application or cart → post-purchase-sequence on purchase
- Attendees who did not click → nurture sequence with mechanism focus
- Missers who watched replay → webinar-promotion-sequence post-webinar flow
- Missers who did not watch → re-engagement sequence if no opens within 14 days

## Verification Checklist

- [ ] Title specificity score 8 or higher
- [ ] 30, 60, or 90-minute runtime locked
- [ ] Mechanism named, 3 to 5 sub-steps defined
- [ ] 2 to 3 sub-steps taught in depth; rest tease
- [ ] One isomorphic case study with permission
- [ ] Bridge under 7 minutes with offer named, guarantee stated, CTA specified
- [ ] Opt-in page with 3 to 5 bullets, social proof if available, single CTA
- [ ] Pre-training email sequence live (from /email-sequence webinar-promotion-sequence)
- [ ] Show-up rate benchmark tracked
- [ ] Replay window 48 to 72 hours with deadline stated
- [ ] Post-training sequence aligned with webinar-promotion-sequence
- [ ] 3 or more `phrases_to_use`
- [ ] Banned-vocabulary sweep clean
- [ ] Compliance disclosures present
- [ ] Offer CTA wired to next-step asset (application, cart, or calendar)

---
*v1.0 — live-training variant of /lead-magnet. Pairs with /webinar-script (upstream framework), /email-sequence webinar-promotion-sequence (downstream drip), and /landing-page plus /ad-creative (upstream traffic).*
