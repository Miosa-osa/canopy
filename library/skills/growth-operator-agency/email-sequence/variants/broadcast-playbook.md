---
variant: broadcast-playbook
parent_skill: email-sequence
scope: One-off broadcast emails. The weekly value drop or the tactical announcement that lands in the inbox with zero upstream setup. 10 ready-to-use formats, each with hook structure, body template, CTA class, and benchmark signal.
triggers:
  - Content calendar queues a weekly broadcast slot
  - A specific announcement needs to ship: new content, new partnership, event, product update, creator diary
  - A newsletter cadence is active
sequence_length: 1 email per broadcast (run on weekly or bi-weekly cadence)
window: Same-week send
cadence: Weekly or bi-weekly, consistent day of the week, consistent time of day
open_rate_target: 35 to 55 percent for broadcast-only lists; 40 to 60 percent for nurture-warmed lists
click_rate_target: 4 to 10 percent depending on format
unsubscribe_loss_budget: under 0.5 percent per send; under 3 percent annual cumulative
conversion_event: click on the single CTA of the broadcast
version: 1.0
---

# Broadcast Playbook

## Role In the System

A broadcast is a one-off email that does not fit inside a sequence. It lands, it delivers, it ends. No follow-up belongs to the broadcast itself. No belief arc compounds across broadcasts. Each broadcast stands alone.

Broadcasts exist because the creator produces public content, observations, case studies, and announcements continuously, and the list needs a channel for that stream that is not a sequence. Sequences are engineered arcs. Broadcasts are signals of life.

The 10 broadcast formats below cover the majority of what a creator will ever need to send outside a sequence. Each format has a specific job, a specific structure, and a specific measurement signal. Mix the formats across a quarter to keep the list awake without fatiguing any single pattern.

A broadcast is not a launch sequence and is not a nurture sequence. Launches compress urgency into a dated window across multiple emails. Nurture paces belief across months. A broadcast is one email with one job.

## Gate-in Conditions

Ship broadcasts only if:

- A weekly or bi-weekly cadence is defined and on the calendar
- Subscriber list is tagged so broadcasts reach the right segments (broadcast-active, engaged, not-in-active-sequence)
- No sequence is running to the same subscriber (launch, webinar, application, post-purchase, re-engagement all pause broadcast for the window)
- Compartment 5 (Copy and Messaging) is at 30 percent or higher, so broadcasts have proven hooks and angles to pull from
- Compartment 6 (Content Strategy) is at 30 percent or higher, so broadcasts tie to the content pillar structure

## Universal Broadcast Structure

Every broadcast, regardless of format, has the same top-level anatomy:

```
Subject (40 to 50 chars, specificity ≥ 8)
Preview text (35 to 90 chars, extends the subject)
---
[Hook — first 1 to 2 lines, visible in phone preview]
[Body — format-specific, 150 to 700 words]
[Bridge — one line connecting body to the CTA]
[Single CTA — one action, direct link]
[Sign-off — creator's first name]
---
[P.S. — optional, one line of highest-read content]
```

Universal rules:
- Single CTA per broadcast. Stacking CTAs kills click-through rate.
- Voice-match with 3 or more `phrases_to_use`.
- Full banned-vocabulary sweep before send.
- CAN-SPAM footer, physical address, unsubscribe link, every broadcast without exception.
- No fake-reply subjects, no fake-forward subjects, no fake-urgency.

## Format 1 — The Weekly Value Drop

**Job:** Deliver one tactical idea the reader can apply today.

**When to use:** Default weekly cadence. Most broadcasts are this format.

**Structure:**
- Subject: contrarian or specific-outcome framing
- Hook: "Short one today. One idea, one example, one action."
- Body: 250 to 400 words. State the idea in one sentence. One supporting example (can be a micro-case or a creator diary moment). State the specific action the reader can take today.
- Bridge: "If you try this, reply with how it goes."
- Single CTA: back to a pillar piece or to the content hub
- P.S.: preview next week's topic or point to an adjacent piece of content

**Benchmark:** 40 to 55 percent open rate, 5 to 10 percent click rate, under 0.3 percent unsub rate per send.

**Fails when:** The "idea" is a vague principle instead of a specific action. Readers cannot apply vague principles today.

## Format 2 — The Contrarian Take

**Job:** Challenge a widely held belief in the ICP's market.

**When to use:** When a new piece of conventional wisdom is gaining traction and the creator disagrees.

**Structure:**
- Subject: the contrarian position stated plainly. "Why [common advice] is wrong for [ICP segment]"
- Hook: "Everyone's saying X. Here's why X is backwards."
- Body: 300 to 500 words. State the widely held belief. Argue against it with two to three specific counterexamples. State the alternative belief.
- Bridge: "If you've been stuck because of [common belief], here's the shift."
- Single CTA: back to a deep-dive content piece on the alternative belief
- P.S.: "Reply if you disagree. I read the disagreements."

**Benchmark:** 45 to 60 percent open rate (contrarian subjects pull opens), 8 to 15 percent click rate, under 0.5 percent unsub rate (contrarian takes cost some subscribers; that is the point).

**Fails when:** The contrarian take is a straw-man or is not backed by the creator's actual experience. Readers detect performance and unsubscribe.

## Format 3 — The Creator Diary

**Job:** Show a specific, dated moment from the creator's week.

**When to use:** Weekly or bi-weekly, as relationship-deepening content between sequences.

**Structure:**
- Subject: specific moment framing. "What happened on Tuesday" or "Last Thursday, something broke"
- Hook: Date-anchored scene opener. "Tuesday at 2pm. [specific place or context]."
- Body: 300 to 450 words. Narrate the moment. Three beats: the setup, the thing that happened, what the creator learned. No teaching-mode voice. Diary voice.
- Bridge: "Why I'm telling you: [specific lesson for the reader's work]."
- Single CTA: back to content or soft reply prompt
- P.S.: one-line promise of next week's topic

**Benchmark:** 40 to 55 percent open rate, 4 to 8 percent click rate, under 0.3 percent unsub rate, reply rate notably higher than other formats.

**Fails when:** The diary becomes a humble-brag or ends with a pitch. The diary is relationship content, not sales content.

## Format 4 — The Case Study Drop

**Job:** Publish a specific client result as a standalone broadcast.

**When to use:** When a new isomorphic case study lands and is permission-cleared.

**Structure:**
- Subject: specific outcome plus timeframe. "$14,200 in 19 days. Here's what she did."
- Hook: Name the case subject and their starting state. "Jenna runs a bookkeeping practice. Six months ago she was at $4,500/mo."
- Body: 400 to 600 words. Four beats: starting situation, what she tried that did not work, the mechanism applied, the measurable outcome. Include one verbatim quote if possible.
- Bridge: "If you're where Jenna was six months ago, this is worth reading twice."
- Single CTA: link to a longer case-study page or to a piece of content explaining the mechanism
- P.S.: note that more case studies are tracked at the case-study page link

**Benchmark:** 45 to 60 percent open rate, 8 to 15 percent click rate, under 0.3 percent unsub rate.

**Fails when:** Case subject is not isomorphic to the core ICP. Readers think "that's not me" and click away.

## Format 5 — The Q+A Digest

**Job:** Answer three to five reader questions from the past week in one broadcast.

**When to use:** When reader replies or inbound questions have stacked up and deserve a reply at scale.

**Structure:**
- Subject: plain promise. "Three questions I got this week" or "The Q&A, edition [N]"
- Hook: "A lot of similar questions hit my inbox this week. Here are three answers that might help you too."
- Body: 500 to 700 words. Three to five Q+A pairs. Each question stated verbatim (with permission if attributed by first name). Each answer in 80 to 150 words. Pull answers from the mechanism's logic, not from invention.
- Bridge: "If you have one, reply. I read them."
- Single CTA: reply prompt or link to the Q+A archive page
- P.S.: "Thanks to [first names] for the questions this week."

**Benchmark:** 40 to 55 percent open rate, 4 to 8 percent click rate, higher-than-average reply rate, under 0.3 percent unsub rate.

**Fails when:** Q+A questions are invented rather than real. Readers detect performance. Trust leaks.

## Format 6 — The New Content Announcement

**Job:** Announce a new piece of public content (video, podcast, article, social post series).

**When to use:** Every time a major piece of content ships. Up to once per week.

**Structure:**
- Subject: plain announcement or tease. "New video: [specific title]" or "The [topic] breakdown is live"
- Hook: "Just published this. Wanted you to see it first."
- Body: 200 to 300 words. Name the content. Name the specific thing the reader will walk away with. Name the format (length, platform, how to consume).
- Bridge: "If this is useful, forward it to someone else who'd use it."
- Single CTA: link to the content
- P.S.: note the next piece in the series if applicable

**Benchmark:** 40 to 55 percent open rate, 15 to 30 percent click rate (announcements have high click rates), under 0.3 percent unsub rate.

**Fails when:** Announcements stack. More than one announcement per week trains the list to ignore them. Consolidate into a digest if multiple pieces shipped.

## Format 7 — The Tactical Announcement

**Job:** Announce a specific tactical change, event, or opportunity.

**When to use:** When a real event or change needs awareness: a free workshop, a pricing change, a partnership, a platform migration, a schedule shift.

**Structure:**
- Subject: plain announcement. "Free workshop on [date]" or "Pricing is changing on [date]"
- Hook: "A quick heads-up on [specific thing]."
- Body: 200 to 350 words. Three elements: what is happening, when, what the reader needs to do (if anything).
- Bridge: "Questions, reply and I'll answer."
- Single CTA: event registration, new-link, pricing page, or whatever the announcement points to
- P.S.: deadline or effective date restated

**Benchmark:** 45 to 60 percent open rate, 10 to 20 percent click rate depending on relevance, under 0.5 percent unsub rate.

**Fails when:** Announcement is dressed up as urgency when no real deadline exists. Readers detect the dress-up. Future announcements lose force.

## Format 8 — The Behind-the-Scenes

**Job:** Show a specific operational reality from the creator's business.

**When to use:** Quarterly or as warranted when a meaningful change happens internally.

**Structure:**
- Subject: specific-process framing. "How I run my Mondays" or "The one spreadsheet I open every morning"
- Hook: "Pulling back the curtain on [specific thing]."
- Body: 400 to 600 words. Describe the specific operational reality. Show a screenshot, template, or process diagram if possible. Explain why it works this way, not just that it works.
- Bridge: "If this is useful, here's the template." Or: "Next time I change this, I'll tell you."
- Single CTA: link to a downloadable template, a deep-dive post, or a community thread
- P.S.: invite readers to share their version

**Benchmark:** 40 to 55 percent open rate, 8 to 15 percent click rate, higher-than-average reply rate.

**Fails when:** Behind-the-scenes reads as self-congratulation. Readers want operational specifics they can apply, not a tour of the creator's life.

## Format 9 — The Seasonal Recap

**Job:** Wrap a specific period (month, quarter, year, campaign) with what happened and what is next.

**When to use:** Monthly, quarterly, end-of-year, or post-campaign.

**Structure:**
- Subject: period-framed. "October in review" or "The Q3 recap"
- Hook: "End of [period]. Here's what happened."
- Body: 400 to 700 words. Three sections: what shipped this period (content, offers, case studies), what was learned, what is next period's focus. Specific numbers where appropriate.
- Bridge: "If you've been building in parallel, reply with where you are."
- Single CTA: back to the content hub, calendar, or the plan-for-next-period page
- P.S.: preview the first broadcast of next period

**Benchmark:** 35 to 50 percent open rate, 6 to 12 percent click rate, under 0.3 percent unsub rate.

**Fails when:** Recap is all highlights and no specifics. Readers want real numbers and real losses, not a press release.

## Format 10 — The Reader Letter Reply

**Job:** Respond to a single reader letter publicly, with their permission.

**When to use:** When a reader reply raises a question or insight that deserves a full response.

**Structure:**
- Subject: references the topic of the reader's letter. "A reader asked: [specific question]"
- Hook: "[First name] sent this to me yesterday. I wrote back. Here's the exchange."
- Body: 400 to 600 words. The reader's letter quoted (with permission, first name only). The creator's response in full. Tie the response back to the mechanism or the core belief.
- Bridge: "If you have a version of this question, reply. I answer them."
- Single CTA: reply prompt or link to archive of past reader-letter responses
- P.S.: "Thanks to [first name] for letting me share this."

**Benchmark:** 45 to 60 percent open rate, 5 to 10 percent click rate, high reply rate, under 0.3 percent unsub rate.

**Fails when:** Reader letter is invented or the permission was not obtained. Trust violation. Do not do this.

## Subject Line Bank — 15 Broadcast Patterns Across Formats

1. "Short one today"
2. "Why [common advice] is wrong for [ICP segment]"
3. "What happened on Tuesday"
4. "$[specific number] in [N] days. Here's what she did."
5. "Three questions I got this week"
6. "New video: [specific title]"
7. "Free workshop on [date]"
8. "How I run my Mondays"
9. "October in review"
10. "A reader asked: [specific question]"
11. "One idea you might have missed"
12. "The [topic] breakdown is live"
13. "Pulling back the curtain on [specific thing]"
14. "Two things from this week"
15. "If you read one email from me this month"

## P.S. Bank — 10 Broadcast Patterns

1. Preview next week's topic.
2. Link to a related piece of content from the archive.
3. Reply prompt to raise engagement signal.
4. Pointer to the content hub or social handle.
5. Unsubscribe link, plainly stated, every 4 to 6 broadcasts.
6. Thank-you to a specific reader who prompted the broadcast.
7. Note about the cadence (weekly, bi-weekly) so new subscribers know what to expect.
8. Link to a micro-action they can take in 5 minutes.
9. Pointer to the creator's best piece of public content this year.
10. One-line reminder that the reader can always pause the list via the pause link.

## Segmentation + Cadence Logic

| Segment | Broadcast Cadence | Notes |
|---|---|---|
| broadcast-active, engaged-weekly | Weekly | Default list cadence |
| broadcast-active, engaged-monthly | Bi-weekly or monthly | Lower cadence for moderate-engagement subscribers |
| nurture-active | Paused | Broadcast resumes at end of nurture |
| launch-active or webinar-active or application-submitted | Paused | Broadcast resumes at end of active sequence |
| cold-nurture, cold-welcome | No broadcasts | Route to re-engagement instead |
| post-purchase-active (within 90 days) | Paused for buyer cohort | Resumes at Day 90 |
| paused-60d | No broadcasts for 60 days | Resumes automatically |

Segmentation critical: broadcast to subscribers only when they are not inside an active sequence. Overlapping cadences double the emails and break trust.

## Cadence Fatigue Check

Broadcast cadence is the steady-state of the list. Keep it healthy by:

- Picking one day of the week and one time of day, and sticking to it for at least 90 days before any change.
- Mixing formats across the quarter. Do not run five Weekly Value Drops in a row. Use Contrarian Take, Creator Diary, Case Study Drop, Q+A Digest, Behind-the-Scenes to rotate.
- Running an internal audit every 90 days: if click rate drops below 3 percent on average, refresh the format mix or audit subject-line specificity.
- Pausing broadcasts during any active sequence, without exception.

## Benchmarks and What They Tell You

| Metric | Healthy Range | If Below | If Above |
|---|---|---|---|
| Broadcast open rate | 35 to 55 percent | Audience has cooled or subject specificity is low | Healthy list |
| Broadcast click rate | 4 to 10 percent | CTA buried or mismatched to body | Healthy |
| Broadcast unsub rate per send | under 0.5 percent | Fine; some churn is healthy | Cadence too heavy or topic mismatch |
| Broadcast reply rate | 0.5 to 3 percent | Fine for most formats | Exceptional (Creator Diary, Q+A Digest, Reader Letter) |
| Broadcast spam-complaint rate | under 0.05 percent | Fine | Critical; review deliverability and subject-line framing |

## Voice-Match and Compliance Rules Specific to Broadcasts

- Every broadcast uses 3 or more `phrases_to_use` from Compartment 1.
- Banned-vocabulary sweep clean before every send.
- No fake-reply subjects, no fake-forward subjects, no fake-urgency.
- CAN-SPAM footer, physical address, unsubscribe link, every broadcast.
- Permissions cleared for any reader names, client names, case study quotes, or reader letters included.
- Testimonial numbers carry "results vary" disclosure where appropriate.
- No income guarantees.

## Common Failure Modes

1. Broadcasts go out during an active launch or webinar sequence. Subscriber sees conflicting CTAs. Click-through drops on both. Fix: pause broadcast for the full active-sequence window.
2. Same format five broadcasts in a row. Open rate collapses. Fix: rotate format every 2 to 3 broadcasts.
3. Subject lines are vague. Open rate drops below 35 percent. Fix: audit specificity score; specificity less than 7 fails.
4. Two or more CTAs stacked in one broadcast. Click-through halves. Fix: one CTA, every time.
5. Reader letter or case study used without permission. Trust violation. Fix: permission is non-negotiable; flag any unreleased material before send.
6. Broadcast cadence inconsistent (3 in a week, then none for a month). List expectations break. Fix: consistent day and time; hold the cadence or pause it publicly.
7. Announcements stack (3 "new content" broadcasts in 5 days). List trains to ignore announcements. Fix: cap at one announcement per week; digest the rest.

## Next-Step Routing

Broadcasts typically do not trigger downstream sequences because they are one-off. But:

- A broadcast that soft-pitches a sequence (rare) can tag clickers for routing into nurture or webinar promotion.
- A Case Study Drop can tag clickers as interested-case-study, feeding downstream segmentation.
- A New Content Announcement can tag clickers as content-active, useful for retargeting.
- The Reader Letter Reply may spike replies that route individually into support or sales inboxes.

## Verification Checklist (per broadcast)

- [ ] Format selected from the 10 above
- [ ] Subject specificity is 8 or higher
- [ ] Body matches the format's structure
- [ ] Single CTA, single action
- [ ] 3 or more `phrases_to_use`
- [ ] Banned-vocabulary sweep clean
- [ ] Permissions cleared for any attributed content
- [ ] CAN-SPAM footer, physical address, unsubscribe link
- [ ] Send-time respects the established weekly cadence
- [ ] Segment filter excludes subscribers inside active sequences
- [ ] Benchmarks captured and logged after send

---
*v1.0 — broadcast-playbook variant of /email-sequence. Pairs with /content-calendar (upstream for weekly slot queuing) and all other sequences (paused during active sequences, resumed after).*
