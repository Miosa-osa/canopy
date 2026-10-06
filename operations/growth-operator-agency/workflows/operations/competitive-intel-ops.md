# Competitive Intelligence — Operating Practice

## Purpose
The operating-level playbook for competitive intelligence — the weekly scanning, monitoring, and response practice. Distinct from the `/competitor-intel` skill (which is strategic deep-dives); this doc is the continuous ops rhythm. Goal: the team finds and acts on competitive moves within 7 days, not discovered 3 months later.

## Scope — What's Tracked

Three lists, maintained in Notion `/competitive-intel/`:

| List | Count | Review |
|---|---|---|
| Direct competitors (same offer, same ICP) | 5-8 | Weekly |
| Adjacent (different offer, same ICP) | 5-8 | Monthly |
| Aspirational (larger/later-stage in the category) | 3-5 | Quarterly |

Every tracked entity has: company name, founder(s), URL, primary offer, pricing (public), social handles, owned content URLs, last-scanned date, change log.

## Weekly Scan Cadence

**Owner:** Marketing Mgr (or dedicated intern at $3M+). Scan completed every Tuesday by noon PT. Report in #competitive channel by 2pm PT same day.

### Weekly Scan Checklist (Direct Competitors, Every One)

- [ ] Website homepage diff (was there a change since last week?)
- [ ] Pricing page (any change? stored version archived)
- [ ] New blog / YouTube / podcast content in last 7 days
- [ ] New social posts on primary platforms (LinkedIn, IG, TikTok, YouTube Community)
- [ ] New ads running (Meta Ad Library, TikTok Ad Library)
- [ ] New hires on LinkedIn (roles signal expansion direction)
- [ ] Press releases or news mentions
- [ ] Reddit / community mentions (search query: company name + "experience," "review," "scam," "vs")

Time budget: ~45 minutes for 5-8 direct competitors.

### Monthly Scan Checklist (Adjacent + Aspirational)

- [ ] Major product/offer changes
- [ ] Major content bets (new YouTube series, new podcast)
- [ ] Headcount trajectory (LinkedIn employee count)
- [ ] Funding events / acquisitions
- [ ] Pricing model shifts (freemium, one-time, subscription)

Time budget: ~2 hours monthly.

## Monitoring Tools

| Tool | Use For | Cost | Setup Time |
|---|---|---|---|
| Meta Ad Library | Competitor ads running (free, public) | $0 | 5 min |
| TikTok Creative Center / Ad Library | TikTok ads | $0 | 5 min |
| Google Alerts | Company name mentions | $0 | 5 min / competitor |
| Mentionlytics | Social + web mention monitoring | $79-$299/mo | 1 hour |
| Brand24 | Alternative to Mentionlytics | $79-$249/mo | 1 hour |
| F5Bot | Reddit keyword alerts (free) | $0 | 15 min |
| Visualping | Page-diff monitoring (URLs that matter) | $10-$50/mo | 10 min |
| Wayback Machine | Historical page versions | $0 | — |
| Semrush / Ahrefs | Organic + paid keyword gains/losses | $100-$400/mo | 2 hours |
| LinkedIn Sales Navigator | Hiring / org chart changes | $100/mo | 30 min |
| BuiltWith / Wappalyzer | Tech stack changes on competitor sites | $0-$295/mo | 10 min |

**Recommended starter stack ($0-$500k stage):** Meta Ad Library + Google Alerts + F5Bot + Visualping + Wayback — total cost ~$20/mo.

**At $1M+:** add Mentionlytics/Brand24 + Semrush.

**At $3M+:** add LinkedIn Sales Navigator + Ahrefs + a dedicated intern/VA.

## Weekly Scan Report Template

Posted in #competitive channel every Tuesday 2pm PT:

```
COMPETITIVE SCAN — Week of [date]

New signals (changes spotted this week):
  [Competitor A]: [specific change] → [our likely read]
  [Competitor B]: [specific change] → [our likely read]

Ads running (new / notable):
  [Competitor A]: [ad creative + angle + estimated spend]
  [Competitor B]: [ad creative + angle + estimated spend]

Content highlights (their hits):
  - [URL] — [why it's working, e.g., 50k views in 3 days, engagement rate]

Hiring signals:
  - [Competitor]: hired [role] — implies [direction]

Whitespace spotted:
  - [topic / audience / channel] that no one is attacking

Recommended actions for us:
  1. [specific + owner + timeline]
  2. [specific + owner + timeline]
```

## Response Protocols

| Signal | Response | Who Decides |
|---|---|---|
| Competitor drops price >20% | Board-level review of pricing strategy | Operator + CFO (monthly) |
| Competitor launches offer similar to ours | Counter-positioning brief within 14 days | Marketing Mgr |
| Competitor hits viral moment (>1M reach) | Study the pattern; do not copy directly | Content Mgr |
| Competitor hires a role signaling new direction | Note, discuss at monthly strategic priorities | Operator |
| Competitor acquires company | Discuss at quarterly positioning refresh | Operator |
| Competitor goes public-negative on us | Do not engage; monitor; escalate to Operator only if material | Operator |
| Ex-competitor employee available | Interview if role matches hiring plan | Hiring mgr |

**Default stance:** we learn, we don't react. Most competitive moves don't require counter-moves. Over-reaction is the more common failure.

## Counter-Positioning Protocol

When a direct competitor launches an offer that overlaps ours:

1. **Week 1:** Document the overlap and the differences. Write 1 page: "How we're different."
2. **Week 2:** Update sales objection handling. "What about [competitor]?" → scripted response.
3. **Week 2:** Update top-of-funnel content (one piece specifically addressing the choice).
4. **Week 3-4:** Run A/B test on positioning language, measure.
5. **Monthly:** Track win/loss against that competitor for 90 days.

Counter-positioning doc template lives in `frameworks/counter-positioning/`.

## Whitespace Capture Protocol

Whitespace = audience / topic / channel none of the tracked entities are attacking.

When identified during scan:

1. **Log in whitespace list** (Notion `/competitive-intel/whitespace/`)
2. **Score:** audience size (1-5), strategic fit (1-5), team capability (1-5)
3. **Decide monthly:** is any whitespace >12 total worth a 30-day test?
4. **Test cheap first:** 1 piece of content, 1 ad variant, 1 landing page
5. **Measure → double down or kill**

## Integration With Other Ops

- **Sales weekly (Monday):** win/loss reasons reference competitive signals (GHL tag: "Lost to [competitor]").
- **Content weekly (Thursday):** first 10 min includes "what did competitors publish this week?"
- **Marketing weekly (Tuesday):** scan report is pre-read, first 15 min is discussion.
- **Monthly strategic priorities (day 25):** competitive signals are pre-read input.
- **Quarterly positioning refresh:** competitive lens is an agenda item.

## Metrics / Success Criteria
- Weekly scan delivered 50/52 weeks
- Response cycle time <14 days for priced moves
- Win/loss against top 3 competitors tracked continuously
- ≥1 whitespace test per quarter
- Positioning doc refreshed at least 2x per year

## Failure Modes
- **Obsession.** Team reads competitors daily; ignores their own work. Fix: time-box scan to 45 min/week.
- **Imitation.** Copying competitor moves without distinct angle. Fix: counter-positioning must include "how we're different."
- **Under-scanning.** Scans "when we have time." Fix: Tuesday noon PT, non-negotiable, named owner.
- **Tool sprawl.** 7 monitoring tools, zero synthesis. Fix: Mentionlytics or Brand24 consolidates; kill redundancy.
- **Bad signal triggers bad response.** One angry Reddit post drives a pivot. Fix: response protocols tier signals; noise is ignored.

## Cross-references
- Skills: `skills/competitor-intel/` (deep-dive skill; this doc is the weekly ops layer)
- Frameworks: `frameworks/counter-positioning/`, `frameworks/whitespace-scoring/`
- Other operations docs: `cadences-monthly.md`, `cadences-quarterly.md`, `cadences-weekly.md`

---
*v1.0 — 2026-04-19.*
