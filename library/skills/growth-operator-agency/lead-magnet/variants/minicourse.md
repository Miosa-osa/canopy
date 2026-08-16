---
variant: minicourse
parent_skill: lead-magnet
scope: Multi-day email or video mini-course. 3 to 7 days of sequential lessons delivered to the inbox or via a dedicated course page. Trains the reader through a mental model while the creator earns repeated inbox presence and deeper belief installation.
length: 3 to 7 lessons; 300 to 700 words per lesson if email; 5 to 15 minutes per lesson if video
consumption_time: 3 to 7 days, one lesson per day
opt_in_rate_target: 30 to 45 percent on warm traffic; 15 to 22 percent on cold traffic
design_weight: 20 percent of perceived value if email-delivered; 40 percent if video or dedicated course page
bridge_to_offer: final lesson is 80 percent teach, 20 percent bridge
delivery_channel: ESP drip-sends one lesson per day, starting with Lesson 1 within 2 minutes of opt-in
version: 1.0
---

# Mini Course Playbook

## Role In the Funnel

A mini course is the highest-commitment lead magnet the reader will opt in for without paying. They are committing to receive several days of content in exchange for a more substantial teaching than a checklist or cheat sheet could deliver.

The format has four jobs:

1. Teach a mental model or transferable skill over 3 to 7 sequential lessons.
2. Build the creator into the reader's habit loop: the reader opens email from the creator every day for a week.
3. Install the mechanism through progressive depth: each lesson deepens one sub-step.
4. Bridge to the core offer with the final lesson framed around what the reader now realizes they need.

A mini course is not a PDF guide and is not a free training. Guides read in one session. Free trainings are a single live or recorded session. A mini course is distributed, serialized, and requires a week of reader attention.

## Gate-in Conditions

Ship a mini course only if:

- Compartment 2 (Audience) at 65 percent; mini courses demand strong ICP fit to sustain a week of attention
- Compartment 3 (Offer) at 50 percent; bridge-to-offer must point at a real next step
- Creator's mechanism is named with 3 to 5 sub-steps defined; lesson count maps to sub-step count
- Compartment 9 (Education and Nurture OS) at 30 percent or higher
- Drip-scheduling capability in ESP is configured and tested

## Structural Anatomy

A 5-day mini course maps to this lesson layout:

| Lesson | Day | Focus |
|---|---|---|
| Lesson 0 (welcome) | Day 0, immediate | Orient the reader; what to expect across the course |
| Lesson 1 | Day 1 | The foundational belief or premise |
| Lesson 2 | Day 2 | Sub-step 1 of the mechanism |
| Lesson 3 | Day 3 | Sub-step 2 of the mechanism |
| Lesson 4 | Day 4 | Sub-step 3 of the mechanism |
| Lesson 5 (capstone) | Day 5 | Integration, case study, bridge-to-offer |

Shorter 3-day courses compress sub-steps; longer 7-day courses add deeper examples or a recap lesson.

## Lesson Writing Rules

### Lesson 0 — Welcome

| Component | Spec |
|---|---|
| Subject | "Welcome. Here is what we are doing this week." |
| Preview text | Names the course theme and duration |
| Hook line | "Over the next [N] days, here is what you will be able to do." |
| Body | 200 to 300 words. Name the outcome. Name the structure (one lesson per day). Name what to expect today vs tomorrow. Name how to reply with questions. |
| CTA | Start Lesson 1 link (or "Tomorrow, Lesson 1 arrives"). |
| P.S. | Reply-with-one-word prompt to raise ESP engagement signal. |

### Lessons 1 through N-1 — Teaching Lessons

Each lesson (email or video + email announcement):

| Component | Spec |
|---|---|
| Subject | "Lesson [N] of [total]: [specific topic]" |
| Preview text | Names what will be taught |
| Hook line | Connect to yesterday's lesson. "Yesterday we covered X. Today, the next piece." |
| Body | 400 to 700 words for email-only; 200 to 400 words as companion text if video. Three beats per lesson: the concept, the example, the reader's action item. |
| Single CTA | The action item from the lesson (a reflection exercise, a calculation, a small applied task) |
| P.S. | Preview tomorrow's lesson. |

Every teaching lesson has:
- A named concept (one per lesson).
- An isomorphic example applying the concept.
- A concrete action item the reader can do in 5 to 15 minutes.
- A bridge to the next lesson's concept.

### Final Lesson — Capstone

| Component | Spec |
|---|---|
| Subject | "Lesson [final]: putting it all together" |
| Preview text | Names the integration plus the bridge |
| Hook line | "Five days in. Here is the integrated picture." |
| Body | 500 to 800 words. Three sections: (1) Integration — how all sub-steps work together, with a mini case study running through the full mechanism. (2) What this mini course did not cover — the deeper problem that requires implementation at scale. (3) The next step — name the core offer or next-step asset, explain what it adds beyond the course. |
| Single CTA | Link to the core offer, VSL, application, or calendar. |
| P.S. | "Thanks for a week of your attention. Whatever you decide from here, this foundation stays with you." |

Writing rules for the capstone:
- 80 percent teach, 20 percent bridge. Never flip this ratio.
- The bridge-to-offer is the first time in the course the core offer gets named explicitly. Earlier lessons have not mentioned price.
- Make the offer's purpose clear relative to what the course already taught. "The course taught what; the offer runs the how at scale."

## Video vs Email Format

Email-only mini courses:
- Faster to produce. Lower design weight. Text-native.
- Better for teaching concepts, frameworks, mental models.
- Lower consumption friction: reader opens email, reads, done.

Video mini courses (each lesson is a video plus announcement email):
- Higher production cost. Design weight rises.
- Better for teaching skills, walkthroughs, demonstrations.
- Higher perceived value, higher commitment signal.

Choose based on content. Mental models ship as email. Skills ship as video.

## Title Patterns — 10 Options

1. "The [N]-Day [Outcome] Mini Course"
2. "[N] Days to [Specific Transformation]"
3. "The [Mechanism Name] Mini Course"
4. "[Topic] in [N] Days: A Mini Course for [ICP Role]"
5. "From [Starting State] to [End State]: The [N]-Day Mini Course"
6. "The [ICP Role]'s [Topic] Mini Course"
7. "[N] Lessons to [Specific Outcome]"
8. "The [Industry] Foundations Mini Course"
9. "[N] Days of [Specific Tactical Skill]"
10. "The [Mechanism] Deep-Dive Mini Course"

## Opt-in Page Copy Structure

- Hook headline: mini course title with day count.
- Subhead: "One lesson per day for [N] days. [Specific outcome] at the end."
- Three to five bullets naming each lesson topic.
- Single CTA button: "Send me the course."
- Social proof block if available: number of past enrollees plus one testimonial.
- Fine print: daily email commitment, unsubscribe promise.

Opt-in page runs 300 to 500 words. Mini courses earn a longer opt-in page because the commitment is higher.

## Delivery Automation

- Opt-in fires on submit.
- ESP tags: `lm-course-[slug]`, `welcome-active`, `course-active`.
- Lesson 0 fires within 2 minutes.
- Lessons 1 through final fire on consecutive days at a consistent time (morning in ICP primary time zone).
- On course completion, subscriber routes to the standard welcome sequence or nurture sequence depending on whether the core offer CTA was clicked.

## Design Specs

Email-only courses:
- Consistent email template across lessons.
- Lesson number visible in subject and body ("Lesson 2 of 5").
- Short headline font plus body type; no heavy design.

Video mini courses:
- Each video hosted on a dedicated page (one page per lesson).
- Page includes video embed, companion text, downloadable asset, navigation to next lesson.
- Video length 5 to 15 minutes per lesson; shorter is better for completion rate.

## Benchmarks and What They Tell You

| Metric | Healthy Range | If Below | If Above |
|---|---|---|---|
| Opt-in rate on warm traffic | 30 to 45 percent | Commitment barrier; simplify the promise | Fine |
| Opt-in rate on cold traffic | 15 to 22 percent | ICP mismatch or course topic too broad | Fine |
| Lesson 1 open rate | 65 to 80 percent | Welcome email did not set expectation | Fine |
| Completion rate (Lesson final open) | 35 to 55 percent | Lessons too long or cadence friction | Excellent |
| Capstone bridge CTA click rate | 8 to 18 percent | Offer mismatch or bridge too soft | Strong conversion signal |
| Unsubscribe rate across the week | 2 to 5 percent | Fine; course cadence generates some churn | Cadence too heavy or content mismatch |

## Common Failure Modes

1. All lessons are the same length and tone. Reader fatigues. Fix: vary lesson length; mix a short lesson with a longer one.
2. Final lesson is 50 percent bridge-to-offer. Reader feels the course was bait. Fix: 80 percent teach, 20 percent bridge, no exceptions.
3. Lessons arrive at inconsistent times. Reader loses the habit. Fix: consistent morning delivery in ICP primary time zone.
4. No action items in teaching lessons. Reader reads but does not apply. Course loses compounding effect. Fix: one 5-to-15-minute action per lesson.
5. Mechanism name changes across lessons. Breaks the plant. Fix: name the mechanism identically in every lesson.
6. Capstone does not name the core offer. Reader finishes course without knowing what to buy. Fix: offer named explicitly in the capstone, with price range and CTA.
7. Drip scheduling fails (two lessons on one day, or skip a day). Reader distrust rises. Fix: test the full drip before shipping.

## Voice-Match and Compliance

- 3 or more `phrases_to_use` per lesson.
- Banned-vocabulary sweep clean.
- No income guarantees.
- All case studies and quotes permission-cleared.
- CAN-SPAM footer, physical address, unsubscribe link in every lesson email.
- Mechanism name in every lesson.

## Next Step Routing

After the capstone ships:

- Capstone CTA clicker → interested-offer tag → route to application sequence, VSL, or cart
- Course completer without capstone click → warm-mechanism tag → route to nurture sequence
- Course drop-off (no opens after Lesson 2) → cold-course tag → route to re-engagement sequence in 30 days

## Verification Checklist

- [ ] Title specificity score 8 or higher, day count included
- [ ] 3 to 7 lessons, each with concept plus example plus action item
- [ ] Lesson count matches mechanism sub-step count plus welcome plus capstone
- [ ] Capstone is 80 percent teach, 20 percent bridge
- [ ] Drip schedule tested end-to-end
- [ ] Consistent delivery time across lessons
- [ ] Mechanism named identically in every lesson
- [ ] Opt-in page 300 to 500 words with lesson-by-lesson bullets
- [ ] Delivery automation under 120 seconds for Lesson 0
- [ ] 3 or more `phrases_to_use` per lesson
- [ ] Banned-vocabulary sweep clean
- [ ] Core offer CTA in capstone lesson active
- [ ] Completion rate benchmark active in ESP
- [ ] Post-course routing rules wired for converters, completers, and drop-offs

---
*v1.0 — minicourse variant of /lead-magnet. Pairs with /email-sequence welcome-sequence or nurture-sequence (downstream after course) and /landing-page plus /ad-creative (upstream).*
