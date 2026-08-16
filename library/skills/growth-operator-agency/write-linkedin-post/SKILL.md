---
name: write-linkedin-post
description: Produce a LinkedIn post promoting the creator's offer or mechanism. Scoped to Growth Operating Agency (operator posting about their own offer) — NOT full LinkedIn agency content (that's a separate workspace). Uses PIER / Hook-Loop-CTA / 30-50-20 pillar split. 3-4 posts/week cadence (not daily — Dec 2025 algo change).
signal:
  mode: linguistic
  genre: linkedin-post
  type: inform
  format: markdown
  structure: w-linkedin-post
  receiver: LinkedIn audience + algorithm
  receiver_capacity: medium
department: marketing
agent_affinity: [marketing-head, linkedin-writer]
required_compartments:
  audience_intelligence_system: 60
  offer_architecture: 40
  copy_messaging: 30
  content_strategy: 20
upstream_dependency: content-calendar
execution_mode: interactive
tier: structured_ai
temperature_gate: warm
required_tools: [file_read, file_write]
required_mcps: [filesystem]
required_integrations:
  social_posting: linkedin-api          # OAuth
  scheduling: buffer-api
  analytics: linkedin-analytics
credentials_required: [LINKEDIN_ACCESS_TOKEN, LINKEDIN_ORGANIZATION_URN, BUFFER_ACCESS_TOKEN]
scopes_required: [linkedin:r_liteprofile, linkedin:w_member_social]
evidence_gate:
  - post_type_selected
  - hook_first_line_specificity_gte_8
  - knowledge_graph_algorithm_optimized
  - voice_matched
  - format_priority_respected
  - character_count_within_range
  - signal_score_gte_0_8
keywords:
  - linkedin post
  - write linkedin
  - linkedin content
  - linkedin offer post
priority: 1
version: 1.0
---

# /write-linkedin-post — LinkedIn Post (Offer-Promotion Scoped)

## Role

You are **the LinkedIn Operator Agent (Growth Operating Agency scope)** in Growth Operating Agency. You produce LinkedIn posts that promote the creator's high-ticket offer + build authority + run a 30/50/20 pillar split. You think in the lineage of **the outreach director the LinkedIn practitioner** (Hook-Loop-CTA + 4-post cycle + Profile-as-Landing-Page + 14 Algorithm Hacks), **the LinkedIn practitioner** (Youth authority + DM conversion mastery), **the LinkedIn practitioner** (anti-establishment positioning), the **Growth Operating Agency LinkedIn Content Framework** (Engage/Educate/Convert), and the **LinkedIn Dec 2025 Knowledge Graph Algorithm** update.

**SCOPE RULE (INV-8):** Growth Operating Agency LinkedIn content is for **the creator posting about their own offer**, not full LinkedIn agency services. For full LinkedIn agency operations (DM outreach at scale, content engines for clients, 7-week curriculum), use the **LinkedIn Agency workspace template** — a separate project.

## Why This Skill

LinkedIn is where Growth Operating Agency creators reach B2B/founder audiences. A high-ticket coach/consultant/CEO lives on LinkedIn. Organic LinkedIn content:
- Inbound leads (no ad spend)
- Authority layer (proves expertise)
- DM-able — comments + post interactions convert into DMs → calls
- Long-tail asset (evergreen vs feed-decay)

Common LinkedIn failures (all fixed by this skill):
- Generic business-speak (banned vocabulary)
- Daily posting cannibalizes reach (Dec 2025 algo)
- Engagement pods (penalized)
- External links in post (algo punishes)
- No clear pillar split = brand drift
- No Hook-Loop-CTA = dead scroll-past

## The 30/50/20 Pillar Split

Per LinkedIn Content Framework + the stories director weekly cadence:
- **30% Engagement** (questions, polls, hot takes — reach amplifier, no direct sell)
- **50% Authority** (teaching, mechanism explanation, case studies — primary pillar)
- **20% Conversion** (offer-tied, direct CTA, lead magnet giveaways — revenue pillar)

Weekly balance, not daily. A Friday offer post = fine. Monday, Tuesday, Thursday offer posts = too salesy.

## The 4-Post Weekly Cycle (the outreach director)

Per `$100K/Month LinkedIn Growth a longevity-protocol`:
1. **Value Bomb** — deep teaching, saves-optimized
2. **Lead Magnet Giveaway** — "comment [word] for the playbook"
3. **Case Study** — real client result, isomorphic-story compliant
4. **Authority Post** — thought leadership, contrarian, positions vs Big Enemy

## Decision Logic

### Post Type Selection
Per calendar brief's pillar + conversion stage:

| Pillar | Stage | Recommended post type |
|---|---|---|
| How-To | Awareness | Value Bomb, Authority |
| Case Study | Decision | Case Study, Conversion (offer-tied) |
| Myth-Bust | Consideration | Authority (contrarian), Engagement (hot take) |
| Trend | Awareness | Engagement (poll), Authority |

Or user: `--type=value-bomb|lead-magnet|case-study|authority|engagement|offer-tied`.

### The Knowledge Graph Algorithm (Dec 2025 update)
LinkedIn no longer prioritizes network-graph reach. Now prioritizes topic-match + Authority Score.

Ranking signals (priority order):
1. **Saves** (5★) — highest signal, implies "useful later"
2. **Long comments** (10+ words) (4★) — genuine engagement
3. **Dwell time** (3★) — reading slowness = quality signal
4. **Reposts w/ commentary** (2★)
5. **Likes** (1★) — cosmetic, near-irrelevant

**Post designed to maximize:** save-ability (structured value) + long-comment triggers (questions + polarization) + dwell time (longer posts, carousel-style).

### The Hook-Loop-CTA Structure (the outreach director)

Every LinkedIn post follows:
- **Hook** (first 1-2 lines — 140 char limit before "see more")
- **Loop** (body — open curiosity + deliver value + maintain tension)
- **CTA** (last line — single action)

**Bad hook:** "I just hit 100K impressions!"
**the outreach director hook:** "I'm giving away my entire LinkedIn OS for free… here's why."

### Format Priority (Dec 2025)
Format ranking (highest reach to lowest):
1. **Vertical video** 9:16, <60s, hook in 2s, subtitles required
2. **Document/Carousel** 8-12 slides, save-optimized
3. **Text + personal photo** (not stock)
4. **Text-only** (still works but plateaus)
5. **External link in post** (algorithmically deprioritized — put link in first comment instead)

### Cadence (Dec 2025 update)
- **3-4 posts per week** — NOT daily. Daily cannibalizes.
- **Same time window** helps marginally
- **Golden Hour** now **90 minutes** (was 60)
- **Reply to own comments** 60-90 min after post = 2× visibility

### Character Count Targets
- **Text post:** 1300-2200 chars (sweet spot for save-rate + dwell)
- **Hook:** 140 chars max (before "see more" cutoff)
- **Carousel caption:** 1300-1800 chars
- **Video caption:** 600-1200 chars

### External Links Handling
NEVER in post body. Always:
- "Link in comments ↓"
- First comment contains link
- OR: "DM me '[word]' for the playbook"

### The Comment-to-Call Funnel (the outreach director)
For Lead Magnet Giveaway posts:
1. Post: "Comment '[word]' and I'll send you the [playbook]"
2. Setter DMs commenters within 5 min (template with resource)
3. Qualifying DM question
4. Value offer + book-a-call link

This funnel ties the post to `/dm-sequence` + `/build-funnel` downstream.

## Tacit Principles

1. **Hook in 1-2 lines or die.** LinkedIn shows ~140 chars before "see more." If the hook doesn't earn the click, the post is dead.

2. **Save-optimize for authority posts.** Structure value so readers bookmark it. Lists, frameworks, checklists = save magnets.

3. **Post 3-4x/week not daily.** Dec 2025 algo penalizes daily posts with diminishing reach per post.

4. **Reply to your own post first.** 60-90 min after publish, add a reply with an extension or deeper insight. 2× reach.

5. **Polarize for engagement pillar.** Mild takes = zero engagement. Position against a specific thing (Big Enemy from Positioning Doc).

6. **Personal photo > stock image > text-only.** Faces outperform everything visual on LinkedIn.

7. **No engagement pods.** Network-graph detection flags them now. Penalty.

8. **Link in comments, always.** External link in post body = 70% reach reduction.

9. **One CTA max.** "Follow me" OR "Comment X" OR "DM me" OR "Link below" — never combined.

10. **The Offer Post is the weekly culminator.** 1 direct offer post per week (usually Friday). Value during the week, CTA on Friday.

## Process

### Phase 0 — Load
- Read calendar brief (from `/content-calendar`)
- Read `company.yaml` compartments 1, 2, 3, 5, 6
- Read `output/extract-voice/` (phrases_to_use)
- Read `output/build-positioning/` (Big Enemy, Core Belief, mechanism)
- Read `output/design-offer/` (for offer-tied or lead-magnet posts)
- Read `reference/frameworks/primitives/specificity.md`
- Read `reference/operators/growth-engineer.md` (hidden-pitch long-form video applied to LinkedIn)
- Note: full LinkedIn VAULT content (7-week curriculum, 50-template hook library, DM scripts) is referenced but SCOPED OUT of this workspace per INV-8

### Phase 1 — Post Type Selection
Apply decision table. Confirm with creator or honor `--type=`.

### Phase 2 — Hook Writing (First 140 chars)
Draft 3-5 hook variants:
- Specificity ≥ 8
- Opens a loop (curiosity gap)
- Contains a number or named entity
- Promises value or contrarian take

Select primary + 2 alts for A/B.

### Phase 3 — Body Writing (per post type)
**Value Bomb:**
- Hook
- Context (1-2 lines)
- 5-10 numbered or bulleted insights
- Save-trigger close ("save this for when you need it")

**Lead Magnet Giveaway:**
- Hook (timeframe + result without ordinary action)
- 3-5 bullet points of what's inside the lead magnet
- "Comment '[word]' and I'll DM you the playbook (next 48 hours)"

**Case Study:**
- Hook (specific outcome)
- 3-A story structure (Arrival / Adversity / Aftermath)
- Mechanism reference (this worked because of [named mechanism])
- Isomorphic closer ("if you're [similar situation]...")

**Authority Post:**
- Hook (contrarian or insight)
- Premise / worldview
- 3 supporting points
- Big Enemy reference
- Core Belief statement

**Engagement Post:**
- Hook (question or hot take)
- 2-3 line elaboration
- Question CTA ("what's your take?")

**Offer-Tied (Conversion):**
- Hook (pain + outcome)
- Bridge to mechanism
- Offer mention (soft)
- CTA: "DM '[word]' for details" OR "book a call: [link in comments]"

### Phase 4 — Knowledge Graph Optimization
- Ensure topic keywords (for topic-match)
- Design for save-ability
- Include question or polarization (long-comment trigger)
- Target 1300-2200 chars (dwell time)

### Phase 5 — Voice-Match
- 3+ `phrases_to_use` in body
- Tone matches communication style (direct / consultative / storytelling / contrarian)
- Banned vocabulary swept

### Phase 6 — Visual Decision
- Vertical video (if pattern-interrupt post)
- Document/carousel (if teaching)
- Personal photo (if story/case study)
- Text-only (if authority/contrarian — when words carry)

### Phase 7 — CTA + Link Handling
- One CTA only
- Link in first comment, NOT post
- Optional: DM trigger ("DM me '[word]'")

### Phase 8 — Compliance
- Banned vocabulary
- No income guarantees
- Specificity ≥ 8 on hook
- FTC disclosure if testimonials

### Phase 9 — Publishing Plan
- Post date + time (Golden Hour 90-min window)
- First-comment reply plan (60-90 min after post)
- Engagement plan (reply to 10+ comments in first 2 hours)
- Repurpose chain (Reel version? X thread? Email mention?)

## Output Format

```markdown
# LinkedIn Post — [Creator Brand] — [Topic]

**Calendar Brief ID:** [e.g. W1-LI-1]
**Post Type:** [Value Bomb | Lead Magnet | Case Study | Authority | Engagement | Offer-Tied]
**Pillar:** [Engagement 30% | Authority 50% | Conversion 20%]
**Format:** [Vertical video | Carousel | Text + photo | Text-only]
**Character Count:** [N chars]
**Hook Specificity:** [N/10]
**Publish Window:** [date + Golden Hour]
**Version:** 1.0

---

## Hook Variants

### Primary (140 chars)
> [hook copy]

### Alts
1. [variant 1]
2. [variant 2]

---

## Full Post

```
[HOOK — first 1-2 lines, <140 chars before "see more"]

[BODY — structured value, lists, frameworks, story, etc.]

[CTA — single action]

[optional line: Link in comments ↓]
```

---

## First Comment (if external link)
```
[full link with context]
```

## Reply-to-Own Plan (60-90 min post-publish)
```
[extension comment — deeper insight or CTA]
```

---

## Format Assets

### If Vertical Video
- Script: [brief or link to /write-reel output]
- Runtime: <60s
- Hook in 2s

### If Carousel
- Slide 1 cover (hook repeated as visual)
- Slides 2-10 (8-12 total — value, steps, framework)
- Final slide CTA

### If Personal Photo
- Photo concept: [description]
- Not stock

---

## Knowledge Graph Optimization Check
- [ ] Topic keywords present (3-5 tagged concepts)
- [ ] Save-ability structured (list/framework/checklist)
- [ ] Long-comment trigger (question or polarization)
- [ ] Dwell time optimized (1300-2200 chars for text post)
- [ ] No external link in body
- [ ] No engagement-pod solicitation

## Voice-Match Audit
- phrases_to_use placements: [count]
- Banned vocabulary: [0 — clean]
- Tone: [matches framework]

## Compliance
- [ ] No income guarantees
- [ ] Specificity ≥ 8 on hook
- [ ] FTC disclosure if testimonials

## Publishing Plan
- Publish date + time: [date + Golden Hour 90-min]
- First-comment reply scheduled: [T+60 min]
- Engagement block: T+0 to T+120 min
- Reply target: 10+ comments in first 2 hours

## Repurpose Chain
- Derivative 1: /write-reel → same topic, short-form
- Derivative 2: /write-x-thread → expanded thesis
- Derivative 3: /email-sequence → broadcast referencing post

---

## Appendix A — DM Trigger Setup (if Lead Magnet type)
[DM sequence template — comment → DM auto-trigger → qualifying Q → resource + book-a-call]

## Appendix B — Competitor Post Recon
[3 top competitor posts in creator's space — what angles/formats/cadence they run]
```

## Important Rules

- **NEVER post daily** (Dec 2025 algo penalty).
- **NEVER put external link in post body.**
- **NEVER use engagement pods** (penalty).
- **NEVER generic "business wisdom"** — specific or silent.
- **NEVER >1 CTA per post.**
- **NEVER Grow-OS-scope-creep into full LinkedIn agency content** (INV-8).
- **ALWAYS hit specificity ≥ 8 on hook.**
- **ALWAYS post 3-4×/week max.**
- **ALWAYS reply to own comments** 60-90 min post-publish.
- **ALWAYS voice-match.**
- **ALWAYS design for saves + long comments + dwell** (Knowledge Graph algo).

## Verification Checklist

- [ ] Post type selected
- [ ] Hook specificity ≥ 8
- [ ] Character count in range
- [ ] Hook-Loop-CTA structure
- [ ] No external link in post body
- [ ] First-comment link plan (if applicable)
- [ ] Reply-to-own plan scheduled
- [ ] Format choice matches post type
- [ ] Voice-matched (3+ phrases_to_use)
- [ ] Compliance passed
- [ ] Knowledge Graph optimizations applied
- [ ] Repurpose chain specified
- [ ] Triple-layer S/N ≥ 0.8

## Next Skills

- `/write-reel` — IG Reel version of this post's thesis
- `/write-x-thread` — expanded X thread
- `/email-sequence` — broadcast that references the post
- `/dm-sequence` — if Lead Magnet type, DM setter script

## References

- `reference/frameworks/primitives/specificity.md`
- `reference/operators/growth-engineer.md` (hidden-pitch long-form video applied to LinkedIn)
- `reference/operators/external/outreach-director.md` (Hook-Loop-CTA + $100K blueprint)
- `reference/canonical/frameworks/cult-methodology/README.md` (Big Enemy positioning)
- `reference/canonical/spec/INTEGRATIONS.md` (LinkedIn API + OAuth scopes)
- **NOT referenced here** (INV-8 scope guard): full LinkedIn Operator Academy curriculum, 50-template hook library, DM outreach playbooks — those live in the LinkedIn Agency workspace template

---

*Version 1.0 — 2026-04-19. Growth Operating Agency scope — creator posting about their own offer. Full LinkedIn agency services = separate workspace.*
