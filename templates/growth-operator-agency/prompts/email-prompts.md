# email-prompts

Drop-in prompts for subject lines, cold-email openers, re-engagement sequences, launch-email arcs. Pair with `/email-sequence` for variant exploration.

---

## Prompt 1 — Subject line generator (20 per sequence type)

```
# Role
A subject-line specialist. Subject lines are the gate to every email; every 1% open-rate point is worth the entire downstream optimization.

# Task
Generate 20 subject lines for a {{SEQUENCE_TYPE}} email. Split evenly: 5 curiosity, 5 specific-benefit, 5 contrarian, 5 identity / personal.

# Inputs
Sequence type (welcome / nurture / launch / webinar-promo / re-engagement / application / post-purchase / broadcast): {{SEQUENCE_TYPE}}
Email body summary (1–2 sentences): {{EMAIL_BODY_SUMMARY}}
Brand voice: {{BRAND_VOICE}}
ICP: {{ICP_ONE_LINER}}
Forbidden spam triggers (make money fast, guaranteed, free-free-free, all caps, excessive punctuation): auto-enforced

# Constraints
- ≤ 50 characters each (mobile clip).
- Zero banned vocabulary.
- No emoji unless brand voice explicitly uses them.
- Preview text complement (one line under subject, 80–120 chars) for each.

# Output format
| # | Category | Subject (≤50 chars) | Preview text (80–120 chars) | Spam risk |
|---|---|---|---|---|

End with: my top-5 to A/B test + why each is tuned to this audience.
```

---

## Prompt 2 — Cold-email opener rewriter

```
# Role
A cold-email specialist for partnership / JV / sales outreach. You know that the opener is 90% of reply rate, and that the opener must demonstrate: (1) I researched the prospect specifically, (2) I have a concrete reason to reach out, (3) there's a specific ask they can say yes to in one reply.

# Task
Rewrite my cold-email opener to improve reply rate. Propose 3 variants.

# Inputs
Prospect (name, role, company, public-facing work): {{PROSPECT_PROFILE}}
My current opener: {{CURRENT_OPENER}}
My offer / ask: {{ASK}}
What specifically I can reference about their work (something recent, specific, public): {{SPECIFIC_REFERENCE}}

# Constraints
- 3 short paragraphs maximum.
- No generic openers ("Hope this finds you well").
- No flattery without specificity.
- One clear ask at the end. Binary yes/no or easy meeting request.
- No banned vocabulary.

# Output format
For each of 3 variants:
- Subject line (one)
- Email body (3 paragraphs)
- What changed vs original + why it likely lifts reply rate

End with: my top pick + the A/B variable I'd test in version 2.
```

---

## Prompt 3 — Welcome-sequence architect (5 emails)

```
# Role
A welcome-sequence architect. You design sequences that install the right beliefs, set expectations, deliver quick wins, and filter serious-prospects-from-tire-kickers before the first sales pitch.

# Task
Architect a 5-email welcome sequence for new opt-ins from my {{LEAD_MAGNET}}. Each email has a specific job in the belief-installation arc.

# Inputs
Lead magnet delivered: {{LEAD_MAGNET}}
Next-step offer being prepared: {{NEXT_OFFER}}
Brand voice: {{BRAND_VOICE}}
Creator's core belief / big idea: {{CORE_BELIEF}}
Cadence preference (daily / every-other-day / weekly): {{CADENCE}}

# Constraints
- Each email has ONE job — not 3.
- No banned vocabulary.
- No hard pitch in emails 1–3.
- Email 4 or 5 introduces the offer naturally.
- Each email ≤ 300 words.

# Output format
For each email:
- Job (one sentence — what this email must do)
- Subject line + preview text
- Body (≤ 300 words)
- CTA (what action is invited)
- Belief installed

End with: the segmentation signals to capture (who opens, who clicks, who replies) + how they drive routing into the next sequence.
```

---

## Prompt 4 — Launch-sequence architect (10-email arc)

```
# Role
A launch-sequence architect. You design 10-email cart-open-to-cart-close arcs that install beliefs, overcome objections, build urgency genuinely, and close without feeling like a carnival.

# Task
Architect a 10-email launch sequence running {{CART_DURATION_DAYS}} days.

# Inputs
Offer: {{OFFER}}
Price: {{PRICE}}
Cart open date: {{CART_OPEN}}
Cart close date: {{CART_CLOSE}}
Scarcity mechanism (real — cohort cap / price increase / bonus expiring): {{SCARCITY}}
Top 10 objections: {{OBJECTIONS}}
Social proof / case studies available: {{SOCIAL_PROOF}}

# Constraints
- Scarcity must be real, not manufactured.
- Each email addresses a specific objection OR installs a specific belief OR shares a specific proof point.
- No banned vocabulary.
- Day-of-close email sends ≥ 2 emails (morning + final hours).

# Output format
| Day | Email # | Job | Subject | Core beat | Objection / belief / proof |
|---|---|---|---|---|---|

End with: the specific email I'd A/B test first + the variable + the sample size needed.
```

---

## Prompt 5 — Re-engagement sequence (for dormant subscribers)

```
# Role
A list-hygiene specialist. You know that re-engagement isn't about re-selling — it's about filtering. Re-engage who's still there; clean the rest.

# Task
Design a 4-email re-engagement sequence for subscribers inactive for {{INACTIVITY_DAYS}} days.

# Inputs
Subscribers inactive for: {{INACTIVITY_DAYS}} days
Last content they engaged with: {{LAST_ENGAGEMENT_TOPIC}}
Deliverability status (IP reputation trend): {{DELIVERABILITY_STATUS}}
What's new / what's changed since they last engaged: {{WHATS_NEW}}

# Constraints
- Email 4 is the "we're going to remove you unless…" email. It should set clear criteria.
- No banned vocabulary.
- Be direct, not pleading.

# Output format
For each of 4 emails:
- Job
- Subject line
- Body (≤ 250 words)
- CTA (the explicit click / reply / action needed)
- Unsubscribe outcome (if no action)

End with: the cleanup criteria after email 4 + what % list loss is expected + the post-cleanup re-engagement rate I should see from remaining subscribers.
```

---

## Prompt 6 — Post-purchase onboarding (first 14 days)

```
# Role
A first-win specialist. You know that the first 14 days determine retention, testimonials, and referrals. The job of the onboarding sequence is to get the buyer to ONE concrete win within the first 14 days.

# Task
Design the 7-email onboarding sequence for new buyers of {{OFFER}}. The sequence must engineer a specific first-win milestone by day 14.

# Inputs
Offer: {{OFFER}}
First concrete outcome a buyer can achieve in 14 days: {{FIRST_WIN}}
Required prerequisites (what they need to set up / do / submit): {{PREREQS}}
Common failure points in the first 14 days: {{FAILURE_POINTS}}

# Constraints
- First email sent within 15 minutes of purchase.
- Each email has one explicit action.
- Day-14 email celebrates the first-win + unlocks the next milestone.
- No banned vocabulary.

# Output format
| Day | Email # | Job | Subject | Action required | Unlock if completed |
|---|---|---|---|---|---|

End with: the 3 friction points most likely to cause buyers to stall + the email-embed video / asset that removes each.
```

---

## Prompt 7 — Broadcast-email playbook (one-off)

```
# Role
A broadcast-email specialist. You know when to send, when to stay quiet, how to warm up before a pitch, and what formats consistently outperform.

# Task
Write a broadcast email on {{TOPIC}} that I'm sending to my full list. The email should deliver standalone value, not require prior context, and set up the next email / offer naturally.

# Inputs
Topic: {{TOPIC}}
Intended next step (reply / click / wait for next email): {{NEXT_STEP}}
Brand voice: {{BRAND_VOICE}}
List relationship stage (cold / warm / hot): {{LIST_STAGE}}
Last broadcast topic (to avoid cannibalizing): {{LAST_BROADCAST}}

# Constraints
- ≤ 400 words.
- No banned vocabulary.
- Stands alone.
- Ends with one clear next step.

# Output format
- Subject line + preview text
- Full email body
- Postscript (PS) with one additional value / signal
- Segmentation tags to apply based on reader behavior

End with: the expected open / click / reply benchmark for this type of broadcast.
```

---

## Prompt 8 — Deliverability audit (what's killing open rate)

```
# Role
A deliverability auditor. You diagnose why an email list's open rates have dropped: spam filter triggers, list hygiene, IP reputation, authentication, content, cadence.

# Task
Audit my recent deliverability. Identify the top-3 likely causes of the open-rate drop. Prescribe the specific fix for each.

# Inputs
Open rate 90 days ago: {{OLD_OPEN_RATE}}
Open rate today: {{CURRENT_OPEN_RATE}}
List size: {{LIST_SIZE}}
Send cadence: {{CADENCE}}
ESP (email service provider): {{ESP}}
SPF / DKIM / DMARC status: {{AUTH_STATUS}}
Bounce rate: {{BOUNCE_RATE}}
Spam complaint rate: {{SPAM_RATE}}
Recent content changes: {{RECENT_CHANGES}}

# Constraints
- Diagnose from evidence, not vibes.
- Rank by likelihood.
- Propose the specific, actionable fix for each.

# Output format
| Likely cause | Evidence | Impact (est) | Specific fix | Effort |
|---|---|---|---|---|

End with: the one fix I'd do this week + the metric I'd track to verify recovery.
```

---

## Prompt 9 — Segmentation rules generator

```
# Role
A list-segmentation specialist. You design segmentation rules that split a general list into actionable sub-segments without creating hundreds of tiny lists that never get used.

# Task
Propose a segmentation model with 5–7 segments. Each segment has: the rule that captures it, the offer or sequence it receives, the action that moves them to the next segment.

# Inputs
Current list size: {{LIST_SIZE}}
Available signals (open / click / purchase / survey answer / engagement frequency): {{AVAILABLE_SIGNALS}}
Current segmentation (if any): {{CURRENT_SEGMENTATION}}
Primary offers and stages in my funnel: {{FUNNEL_STAGES}}

# Constraints
- 5–7 segments, not more (complexity tax).
- Each segment must receive a distinct sequence or broadcast treatment.
- No stale "will never open again" segments without a plan to clean or re-engage.

# Output format
| # | Segment | Capture rule | Sequence / treatment | Promotion signal (to next segment) | Demotion signal (to lower segment) |
|---|---|---|---|---|---|

End with: which segment I should build first + the rule + the sequence.
```

---

## Prompt 10 — Link-click behavior → offer routing

```
# Role
A link-behavior routing specialist. You take a list of emails where different subscribers clicked different links (signaling different interests / levels of readiness) and propose routing logic to serve each the right next offer.

# Task
Given the click signals below, propose routing logic that serves each subscriber the right next email or offer.

# Inputs
Email recently sent with 3–5 distinct CTAs: {{EMAIL_WITH_CTAS}}
Click rates per CTA: {{CLICK_RATES}}
Available sequences / offers to route into: {{AVAILABLE_SEQUENCES}}

# Constraints
- No subscriber gets routed to more than one sequence at once.
- Non-clickers get a different treatment (maybe re-engagement, maybe wait).
- No banned vocabulary.

# Output format
| Click signal | Interpreted intent | Route to | Why |
|---|---|---|---|

End with: the default routing for non-clickers + the measurement window before re-assessing.
```

---
*v1.0 — drop-in prompts for email sequences and deliverability. Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
