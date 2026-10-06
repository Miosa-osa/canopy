# Client Portal / Dashboard

> **Why this matters:** The client portal is where delivery lives, but it's also where advocacy is born. Customers who can see their own progress, connect with peers, and capture their wins in one place churn less and refer more. Without a portal, delivery fragments across Slack, Zoom, and Loom links — and the operator loses both retention and proof.

## Source / Lineage

the paid media director — IG profile funnel architect. The portal closes the loop between acquisition (IG) and advocacy (which feeds the next wave of acquisition). the paid media director treats the portal as the fifth playbook of the IG system: it's what turns customers into the content engine the operator couldn't otherwise afford.

## Scope Guard (INV-8)

**The portal described here is for customers of the operator's OWN offer** — a coaching program, mastermind, or cohort the operator delivers directly. It is not:
- A white-label portal sold as a service to other brands.
- A content membership with no human delivery layer.
- A SaaS product built for external customers.

## Purpose Stack (in priority order)

1. **Deliver the program.** Course modules, coaching calendar, resources.
2. **Track progress.** Customer sees their own wins over time.
3. **Connect customers.** Community layer — peer support is retention glue.
4. **Capture social proof.** Wins logged in the portal become testimonials + case studies.
5. **Surface advocacy moments.** Prompt referrals at the right time in the customer's journey.

Any portal feature that doesn't serve one of these five purposes is bloat.

## Component Map

### 1. Home / Dashboard

The first screen a customer sees on login. Role: orient them and surface the next action.

**Standard elements:**
- Welcome header with customer name + current program phase.
- "Your next step" card (one action, not five).
- Upcoming calls / events (next 7 days).
- Recent community activity (3–5 most relevant posts).
- Progress bar (program completion %).
- Recent wins (theirs + peers').

### 2. Program / Course

The structured curriculum or module library.

**Standard elements:**
- Module tree with completion states.
- Per-module: video, transcript, worksheet, action-items, comments.
- "Mark complete" and reflection prompt.
- Adjacent modules (next / previous).

Keep modules short (10–25 min videos, <1 hr total per module). Long modules don't get finished.

### 3. Coaching Calendar

Where scheduled coaching calls live.

**Standard elements:**
- Upcoming group calls (with registration link or Zoom link).
- Past call replays (indexed by topic and timestamp).
- 1:1 coaching booking (if applicable to the tier).
- Q&A submission for upcoming calls.

### 4. Community

The peer layer. Often the single biggest retention driver.

**Tool choices:** Circle, Skool, Mighty Networks, or a native Slack/Discord if lighter-weight is preferred. Avoid Facebook Groups — Meta dependence + poor customer experience.

**Standard elements:**
- Welcome channel (customer intros).
- Wins channel (results, prompts for capture).
- Questions / help channel.
- Accountability channel (weekly check-ins).
- Optional: topic-specific channels (e.g., "ads," "content," "sales").

**Moderation cadence:** operator appears 3–5×/week. Community lead (if there is one) daily. Silence from the operator for 7+ days drops engagement 30–50%.

### 5. Results Tracker

Customer-visible progress on their own outcome.

**Standard elements:**
- Key metric chart (revenue, followers, conversions — whatever the offer promises).
- Milestone markers (first $10k month, first 10k followers, first hire, etc.).
- Before / current snapshot.
- Reflection log (weekly, monthly check-ins).

**Why this matters for advocacy:** a customer who can see a chart of their own growth has a visible, share-ready asset. The chart becomes the testimonial.

### 6. Resources

Templates, SOPs, swipe files — the assets the operator ships alongside the core program.

**Organisation:** by stage of the customer journey, not alphabetically. A new customer should see starter resources first; advanced customers see advanced.

### 7. Advocacy Mechanics

The explicit referral and social-proof layer.

**Standard elements:**
- "Share a win" prompt (triggered by milestone or at fixed cadence).
- Testimonial capture form (short video or written quote).
- Referral link / code (unique per customer).
- Referral leaderboard (optional, if culture fits).
- Case study opt-in form.

**The win-capture flow:**
1. Customer logs a milestone in the results tracker.
2. Portal triggers a prompt: "Congrats on hitting [milestone]. Want to share this?"
3. Three options: (a) post it privately in wins channel, (b) record a short video quote, (c) opt into a full case study.
4. Each option routes to the right place — operator gets notified of option (b) and (c) for follow-up.

## Retention Loop

The portal's retention function works through this weekly loop:

```
Customer logs in (pulled by email / push about the weekly call)
        │
        ▼
Sees progress on dashboard
        │
        ▼
Engages in community (wins, questions)
        │
        ▼
Hits a milestone → triggers advocacy prompt
        │
        ▼
Shares a win → peer sees it → raises their own bar
        │
        ▼
Compounds into the next week
```

Customers who log in once a week at minimum churn at roughly half the rate of customers who don't. The portal's job is to earn that weekly login through genuine value — not by gamification gimmicks.

## Feedback Loop to Acquisition

This is the under-used half of the portal: it feeds content and proof back to the IG acquisition engine.

| Portal event | Feeds into |
|--------------|------------|
| Win captured in results tracker | Proof highlight on IG, reel script, email story. |
| Testimonial video recorded | Video testimonial ad, landing-page asset. |
| Case study opt-in | Long-form case study (YouTube, blog, sales page). |
| Referral sent | New top-of-funnel lead through trusted source. |
| Community quote / DM | Social-proof post, objection-handling content. |

The operator (or a VA) reviews portal events weekly and routes them into content + acquisition. Without this review, 80% of the proof captured never leaves the portal.

## Platform Choices

| Platform | When to use it | Notes |
|----------|----------------|-------|
| Circle | Most common for coaching in 2024–2026. | Clean UX, community-first, good for 50–1000 members. |
| Skool | Alternative to Circle. | Gamification built in; some coaches love it, others find it gimmicky. |
| Kajabi / Teachable | If the course content is the primary delivery. | Weaker community; often paired with a separate community tool. |
| Custom (Webflow / Framer + Memberstack / Outseta) | Brand-control-heavy operators. | Highest build cost; worth it at $2M+ ARR or if the portal is a differentiator. |
| Notion (as interim) | Pre-$300k operators or pilots. | Fine to start; outgrown by 20+ customers. |

Pick one platform. Consolidation matters more than feature-parity with competitors.

## Metrics to Track

| Metric | Target band | Signals |
|--------|-------------|---------|
| Weekly active customers | 60–80% | Below 50% = delivery problem, not portal problem. |
| Modules completed per customer (90 days) | 60%+ of available | Below 40% = modules too long or unclear. |
| Community posts per customer (30 days) | 2+ per active customer | Below 1 = community not lively enough. |
| Wins logged per customer (90 days) | 2+ | Primary proof-capture metric. |
| Testimonials captured per cohort | 30–50% of customers | Key for downstream acquisition. |
| Referrals per customer (lifetime) | 0.3–1.0 | At 1.0+, referrals become a top-3 acquisition channel. |

## Common Failure Modes

- **Ghost portal.** Built once, never updated. Customers log in, see 6-month-old content, never return.
- **Feature bloat.** 12 tabs, nobody uses 8 of them. Kill features aggressively.
- **Silent operator.** Operator hasn't posted in community for 2 weeks. Retention starts dropping immediately.
- **No win-capture ritual.** Wins happen off-portal (in Slack, in DMs) and never get logged as social proof.
- **Ignored results tracker.** The chart exists but customers don't update it because it's decoupled from their actual workflow. Fix: prompt updates at cadence that matches the customer's existing rhythm (weekly call, monthly review).

## Build Order for a New Program

1. Week 1: ship the dashboard + first 2 modules. Nothing else.
2. Week 2: ship community + coaching calendar.
3. Week 4: ship results tracker + first win-capture prompt.
4. Week 6: ship advocacy mechanics (referral link, testimonial form).
5. Week 8+: iterate based on actual customer usage. Do not pre-build features no customer has asked for.

## How this applies in Growth Operating Agency

- **Skills that consume this:** `portal-audit`, `onboarding-builder`, `win-capture-workflow`, `retention-scorecard`.
- **Agents that use it:** client-success-bot, community-manager, advocacy-operator.
- **Companion frameworks:** pairs with `instagram-profile-funnel/automated-ecosystem.md` (advocacy feeds the top of funnel), `growth-operating-process/8-stage-customer-journey-audit.md` (stages 6–8 run through the portal), and `offer-architecture/` (the portal mirrors the offer structure).

## Non-applicable scenarios

- Low-ticket digital products without human delivery (no community layer makes sense).
- 1:1 consulting with <5 clients (Notion or Google Drive is sufficient).
- Offers with <30 day delivery cycles where retention isn't the issue.

## Cross-references

- `reference/frameworks/instagram-profile-funnel/automated-ecosystem.md`
- `reference/frameworks/instagram-profile-funnel/dm-setter-playbook.md`
- `reference/frameworks/growth-operating-process/8-stage-customer-journey-audit.md`
- `reference/frameworks/offer-architecture/`

---
*v1.0 — 2026-04-19.*
