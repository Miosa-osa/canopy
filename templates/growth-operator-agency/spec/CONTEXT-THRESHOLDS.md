# CONTEXT-THRESHOLDS.md — Agent/Skill Unlock Gates

> **Foundations-first enforcement.** Each skill declares its required compartment completeness. If not met, the skill refuses to execute and interview-mode activates to fill the gap.

## Department Unlock Thresholds

Before any skill in a department can execute, its parent department must hit baseline:

| Department | Parent Lead | Unlock threshold (overall context %) |
|---|---|---|
| Foundations | `foundations-head` | 15% (can start from near-zero — this IS the foundation-builder) |
| Marketing | `marketing-head` | 50% |
| Nurture | `nurture-head` | 55% |
| Sales | `sales-head` | 60% |
| Launch | `launch-head` | 60% |
| Scale | `scale-head` | 70% |
| Partnerships | `partnerships-head` | 60% |

## Asset-Specific Context Thresholds

Before producing a specific asset, these compartments must hit minimum %:

| Asset type | Audience | Offer | Copy | Funnels | Content | Nurture | Sales | Ops |
|---|---|---|---|---|---|---|---|---|
| **Market Research Brief** | — | — | — | — | — | — | — | — |
| **ICP Document** | 30 | — | — | — | — | — | — | — |
| **Positioning Document** | 60 | 40 | — | — | — | — | — | — |
| **Offer Document** | 70 | 30 | — | — | — | — | — | — |
| **Offer Repositioning** | 70 | 60 | — | — | — | — | — | — |
| **Brand Voice Doc** | 50 | — | — | — | — | — | — | — |
| **Content Calendar** | 70 | 70 | 50 | — | 30 | — | — | — |
| **LinkedIn Offer Post** | 70 | 70 | 40 | — | 30 | — | — | — |
| **YouTube Script** | 70 | 70 | 50 | — | 40 | — | — | — |
| **Short-Form Script** | 70 | 60 | 40 | — | 30 | — | — | — |
| **Ad Creative Brief** | 70 | 50 | 40 | 30 | — | — | — | — |
| **VSL (production)** | 60 | **70** | 50 | — | — | — | — | — |
| **Webinar Script** | 70 | 70 | 50 | — | — | 50 | — | — |
| **Email Sequence** | 60 | 50 | 40 | — | — | 50 | — | — |
| **Lead Magnet** | 60 | 60 | 40 | — | — | — | — | — |
| **SMS Sequence** | 50 | 50 | — | — | — | 40 | — | — |
| **Sales Script** | 60 | 70 | — | — | — | — | 50 | — |
| **DM Sequence** | 60 | 60 | — | — | — | — | 50 | — |
| **Landing Page** | 70 | 70 | 50 | 40 | — | — | 40 | — |
| **Application Form** | 60 | 50 | — | — | — | — | 50 | — |
| **Pitch Deck** | 60 | 70 | 40 | — | — | — | 50 | — |
| **Guarantee Copy** | 50 | 70 | — | — | — | — | — | — |
| **Launch Plan** | 60 | 70 | 40 | 60 | 40 | 40 | 40 | 30 |
| **Launch Report** | — | — | — | — | — | — | — | 40 |
| **SOP** | — | — | — | — | — | — | — | 50 |
| **Hiring Brief** | — | — | — | — | — | — | — | 50 |
| **Financial Model** | — | 70 | — | — | — | — | 50 | 30 |
| **Retention Check** | — | — | — | — | — | — | — | — (requires Lifecycle 50) |
| **Case Study** | — | — | — | — | — | — | — | — (requires Lifecycle 40 + Social Proof Assets) |

*Dashes (—) mean no hard minimum. Specific numbers mean: compartment must score at least that % before skill executes.*

## How Thresholds Enforce

1. Skill declares required thresholds in frontmatter:
   ```yaml
   required_compartments:
     audience_intelligence_system: 70
     offer_architecture: 70
     copy_messaging: 50
   ```
2. At invocation, skill reads `company.yaml` + computes current % for each listed compartment
3. If any compartment below threshold: skill REFUSES to execute and enters **interview-mode** to fill the gap
4. Interview-mode reads the missing compartment's schema (ENCODING.md) and asks targeted questions
5. Updates `company.yaml` with captured answers
6. Re-checks threshold; if met, proceeds with original skill

## Why these specific numbers

- **Audience 70%** for any external-facing copy — Impact Distribution 40%. Below 70%, copy will be generic.
- **Offer 70%** for VSL / launches / sales assets — Impact Distribution 40%. Below 70%, offer isn't proven enough to pitch.
- **Foundations sequential chain:** Market Research (0% needed) → ICP (needs Audience 30%) → Positioning (needs Audience 60%) → Offer (needs Audience 70%) → Offer Repositioning (needs Audience 70% + Offer 60%)
- **Economics gate (INV-4):** No offer document passes the gate without `economics_validation.ltv_cac_ratio >= 3.0`

## Exceptions

- `/research` and `/build-icp` are the **bootstrap skills** — they start from empty compartments and interview the creator to fill them. They have NO threshold requirement (they're the only skills that don't).
- Creator can force-bypass a threshold with explicit override: `/skill-name --force-bypass-thresholds` — but this flags the output as `[THRESHOLD-BYPASSED]` and strips the S/N gate to 0.5 max.

## Source

- Growth Operating Agency Master Prompt Layer 2 Section 5 (Context Quality → Output Quality Engine)
- Eli 8 Required Beliefs (Offer must hit 70% before pitch)
- the offer architect 40/40/20 Impact Distribution

---
*v1.0 — 2026-04-19*
