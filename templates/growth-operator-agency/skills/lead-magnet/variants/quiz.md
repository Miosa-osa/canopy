---
variant: quiz
parent_skill: lead-magnet
scope: Outcome-based quiz or assessment. Reader answers 8 to 15 questions, receives a personalized result, and routes into a result-specific follow-up flow. Built for engagement, segmentation data, and self-diagnostic value that converts higher on cold traffic than text lead magnets.
length: 8 to 15 questions; 3 to 7 possible result types
consumption_time: 5 to 10 minutes
opt_in_rate_target: 50 to 70 percent on warm traffic; 30 to 45 percent on cold traffic (quizzes convert highest among lead magnet formats)
design_weight: 35 percent of perceived value; quiz flow and result page design are critical
bridge_to_offer: result page plus result-specific email sequence
delivery_channel: result shown on screen immediately after submission; detailed PDF report emailed within 2 minutes
version: 1.0
---

# Quiz Playbook

## Role In the Funnel

A quiz is the highest-converting lead magnet format for cold traffic because it offers the reader something a static asset cannot: a personalized result. The quiz trades the reader's attention for a diagnosis.

Three jobs:

1. Diagnose the reader's specific situation, giving them a result they feel seen by.
2. Capture segmentation data the creator could not get any other way (specific pain level, stage, readiness, or archetype).
3. Route the reader into a result-specific follow-up sequence that treats them as the archetype they scored into.

A quiz is not a survey and is not a sales pitch. Surveys capture data for the creator. Sales pitches close toward an offer. A quiz does both but wraps them in something the reader wants: clarity about themselves.

## Gate-in Conditions

Ship a quiz only if:

- Compartment 2 (Audience) at 70 percent; quizzes require strong archetype definitions
- Compartment 3 (Offer) at 60 percent; offer fit must align with at least one result archetype
- 3 to 7 result archetypes defined with distinct pain profiles, readiness levels, or personality types
- Scoring logic is mathematically sound (tested on sample responses)
- Quiz platform selected (ScoreApp, Typeform, Interact, or custom)
- Result-specific follow-up sequences are drafted for each archetype

## Structural Anatomy

A quiz has these components:

| Component | Spec |
|---|---|
| Hook page | Title plus subtitle plus CTA to start |
| Questions | 8 to 15 questions, one per screen |
| Email gate | Opt-in immediately before result is revealed |
| Result page | Personalized result with archetype name, description, and recommended next step |
| Follow-up emails | Result-specific drip, 3 to 5 emails per archetype |
| Report PDF (optional) | Detailed breakdown of result, emailed as reinforcement |

Scoring logic maps answers to result types. Three common scoring patterns:

1. **Weighted scoring:** each answer assigns points to one or more archetypes; highest total wins.
2. **Decision tree:** specific answer combinations route to specific archetypes.
3. **Dominant dimension:** answers score across 2 to 4 dimensions; result is the dominant dimension.

## Question Writing Rules

Each question:

- Asks about the reader's current state, not their aspirations. "What best describes your [metric] today?" works. "What would you love to achieve?" fails.
- Offers 3 to 5 answer options. Two-option questions feel clinical. Six or more options create choice fatigue.
- Uses the reader's language, pulled from Compartment 2 voice-of-customer data. "I'm drowning in admin" beats "Administrative load is excessive."
- Avoids double-barreled questions. One concept per question. "Do you have the time and the budget?" is double-barreled.
- Leads to a scoring outcome, not a value judgment. No "right" or "wrong" answers visible to the reader.

### Question Archetypes (deploy in order across the quiz)

1. **Current-state questions** (2 to 4): What is happening right now?
2. **Behavior questions** (2 to 4): What are you doing about it?
3. **Outcome questions** (1 to 2): What does success look like?
4. **Readiness questions** (1 to 2): What is your time horizon or resource level?
5. **Self-identification question** (1): Which of these phrases best describes you?

## Result Archetype Design

Each archetype needs:

- **Name:** 2 to 4 words. Specific. Not generic. "The Systematic Implementer" works. "The Winner" fails.
- **Description:** 150 to 300 words. Describes what this archetype is good at, what trips them up, and what the next step usually is.
- **Primary pain:** one sentence naming the archetype's core blocker.
- **Recommended next step:** 2 to 3 sentences pointing to a specific asset (core offer, foundational content, or a specific lead magnet if the quiz routes to a secondary lead magnet).
- **Result-specific follow-up sequence:** 3 to 5 emails tuned to this archetype.

Distinct archetypes matter. If two archetypes read similar, they merge in the reader's mind and the quiz feels fake. Test readability: a reader should recognize which archetype describes them without reading the others.

## Title Patterns — 10 Options

1. "What [Topic] Archetype Are You?"
2. "Take the [Specific-Outcome] Readiness Quiz"
3. "The [Mechanism Name] Diagnostic"
4. "[Topic] Style Quiz: What's Your Approach?"
5. "How Close Are You to [Specific Outcome]?"
6. "The [ICP Role] Stage Quiz: Where Are You in Your Journey?"
7. "[N] Questions to Figure Out Your [Specific Thing]"
8. "Your [Topic] Type in [N] Questions"
9. "The [Industry] Readiness Assessment"
10. "[Topic] Diagnostic: Get Your Personalized Report"

## Opt-in Page Copy Structure

- Hook headline: quiz title plus question count plus time commitment. "What [topic] archetype are you? 12 questions, 5 minutes."
- Subhead: what the reader will learn (archetype plus recommended next step).
- Visual: a preview of the archetype cards (no personal info, just the archetypes).
- CTA button: "Start the quiz."
- Social proof block if available: count of past takers.

Opt-in page under 400 words. The quiz itself is the sales copy.

## Email Gate Placement

Ask for the email after question 8 to 12 (or before the final question), never at the start. Reader who has already invested 5 minutes in the quiz opts in at 60 to 80 percent. Front-gated quizzes opt in at 20 to 30 percent.

Email gate copy:
- "Where should we send your personalized [archetype / report / next step]?"
- Single field: email.
- Privacy note: "No spam, unsubscribe anytime, your answers are confidential."

## Delivery Automation

- Opt-in fires when email is submitted during the quiz.
- ESP tags: `lm-quiz-[slug]`, `quiz-archetype-[result]`, `welcome-active`.
- Result page displays immediately after submission, no delay.
- Confirmation email fires within 2 minutes with the result restated plus the optional detailed PDF report.
- Result-specific follow-up sequence begins 1 day after quiz completion.

## Result Page Design

The result page is where the quiz converts. Spec:

- Archetype name at the top, large and centered.
- One-paragraph archetype description (the highlights of the full 150-to-300-word description).
- "What this means" section: 3 bullets about the archetype's strengths, challenges, and tendencies.
- "Your recommended next step" section: the single CTA, specific to the archetype.
- Social proof specific to the archetype if available.
- Secondary CTA: "Get the detailed report" (email-gated even if email was captured earlier; this confirms interest and triggers the PDF send).
- Share prompt: "Send this quiz to a friend" (quizzes spread when shareable).

## Benchmarks and What They Tell You

| Metric | Healthy Range | If Below | If Above |
|---|---|---|---|
| Quiz start rate (from opt-in page visit to quiz start) | 40 to 65 percent | Title or visual weak | Fine |
| Quiz completion rate (start to finish) | 55 to 80 percent | Quiz too long or questions confusing | Fine |
| Email gate opt-in rate | 60 to 80 percent | Gate too early or too intrusive | Excellent |
| Overall opt-in rate (visit to email capture) | 50 to 70 percent on warm; 30 to 45 percent on cold | Quiz friction or mismatched audience | Highest-converting format |
| Result page CTA click rate | 15 to 35 percent | Offer mismatch or CTA buried | Very high |
| Result-specific sequence open rate | 55 to 75 percent | Archetype description did not land | Fine |
| Share rate | 5 to 15 percent | Share CTA buried | Quiz is spreading |

## Common Failure Modes

1. Email gate at start. Opt-in rate 20 percent. Fix: move gate to after question 8 or later.
2. Quiz is 20 or more questions. Completion rate drops below 40 percent. Fix: cap at 15 questions, target 10 to 12.
3. Archetype names are generic ("The Leader," "The Thinker"). Reader does not feel seen. Fix: specific archetype names tied to the mechanism.
4. All result archetypes recommend the same next step. Reader suspects manipulation. Fix: different archetypes route to different assets, sequences, or CTAs.
5. Scoring logic is too complex. Edge-case answers produce weird results. Fix: test scoring on 50 to 100 sample response sets; simplify if edge cases break.
6. Result page does not restate the archetype name. Reader forgets what they scored. Fix: archetype name large at top of result page and restated in confirmation email.
7. No follow-up sequence per archetype. Reader gets the result and never hears from the creator again. Fix: 3 to 5 emails per archetype, tuned to the archetype's pain.

## Voice-Match and Compliance

- 2 or more `phrases_to_use` per archetype description.
- Banned-vocabulary sweep clean on questions, answers, archetype descriptions, and result page copy.
- No income guarantees.
- No health claims in result descriptions without clinical backing.
- GDPR-compliant consent for storing quiz responses if EU subscribers are in scope.
- Privacy note visible at email gate and on result page.

## Next Step Routing

After quiz completion, subscribers route by archetype:

- Archetype tagged as `hot-lead` or `ready-now` → application sequence or direct offer CTA in result-specific drip
- Archetype tagged as `warm-building` → nurture sequence with mechanism-focused emails
- Archetype tagged as `early-stage` or `not-ready` → welcome sequence with foundational content; offer mention delayed
- Archetype tagged as `wrong-fit` → routed to a different lead magnet or community, respecting that core offer is not their match

## Verification Checklist

- [ ] Title specificity score 8 or higher
- [ ] 8 to 15 questions, one per screen, 3 to 5 answers each
- [ ] 3 to 7 distinct archetypes defined
- [ ] Archetype descriptions 150 to 300 words each, differentiated
- [ ] Scoring logic tested on 50 to 100 sample response sets
- [ ] Email gate placed at question 8 or later
- [ ] Result page displays archetype plus single CTA immediately
- [ ] Confirmation email under 120 seconds with optional PDF report
- [ ] Result-specific follow-up sequences drafted, 3 to 5 emails per archetype
- [ ] Quiz platform tested end-to-end
- [ ] 2 or more `phrases_to_use` per archetype
- [ ] Banned-vocabulary sweep clean
- [ ] Privacy note visible at gate
- [ ] Share prompt active on result page
- [ ] Archetype-based routing rules wired

---
*v1.0 — quiz variant of /lead-magnet. Pairs with /email-sequence welcome-sequence, application-sequence, or nurture-sequence (downstream, routed by archetype) and /landing-page plus /ad-creative (upstream).*
