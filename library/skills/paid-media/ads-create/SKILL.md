---
name: ads create
description: >
  Campaign concept and copy brief generator for paid advertising. Reads
  brand-profile.json and optional audit results to produce structured campaign
  concepts, messaging pillars, and copy briefs. Outputs campaign-brief.md.
  Run after /ads dna and before /ads generate.
  Triggers on: "create campaign", "campaign brief", "ad concepts", "write ad copy",
  "campaign strategy", "ad messaging", "creative brief", "generate concepts"
---

# /ads create — Campaign Concept & Copy Brief Generator

> Generates structured campaign concepts and platform-specific copy from your brand
> profile and optional audit data. Outputs `campaign-brief.md` for use by `/ads generate`.

## Usage

```bash
/ads create
/ads create --platforms meta google
/ads create --objective leads
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--platforms` | string[] | all | Platforms to target |
| `--objective` | string | — | Campaign objective (sales, leads, awareness) |

## Process

### Step 1: Check for Brand Profile

Look for `brand-profile.json` in the current directory.

- **Found**: Load and proceed.
- **Not found**: Ask the user to run `/ads dna <url>` first or describe brand manually.

### Step 2: Check for Audit Results

Look for `ADS-AUDIT-REPORT.md` or any `*-audit-results.md` in the current directory.

- **Found**: Note top 3 weaknesses to address in concepts.
- **Not found**: Continue without. Note: "No audit data — run `/ads audit` for weakness-targeted concepts."

### Step 3: Collect Campaign Parameters

Ask (combine into one message — omit any already provided via flags):
1. **Platforms**: Which ad platforms? (Meta, Google, LinkedIn, TikTok, YouTube, Microsoft, All)
2. **Objective**: Sales/Revenue, Leads/Demos, App Installs, Brand Awareness, Retargeting
3. **Offer or brief**: Any specific offer, promotion, or message to highlight? (optional)
4. **Number of concepts**: How many campaign concepts? (default: 3)

### Step 4: Spawn Creative Agents in Sequence

Agents must run **sequentially** — `copy-writer` reads the file that `creative-strategist`
writes, so running them in parallel creates a race condition on `campaign-brief.md`.

**Step 4a — Spawn `creative-strategist`**:
Creates `campaign-brief.md` and writes the strategic sections:
`## Brand DNA Summary`, `## Campaign Concepts`, `## Image Generation Briefs`, `## Next Steps`.

**Step 4b — Spawn `copy-writer`**:
After `creative-strategist` completes, spawn `copy-writer`. It reads the existing
`campaign-brief.md` and appends the `## Copy Deck` section with platform-specific
headlines, primary text, and CTAs.

### Step 5: Review and Present

Confirm `campaign-brief.md` exists and is complete. Present summary to user.

## campaign-brief.md Format Specification

The following section headings are a **parsing contract** — agents downstream depend on these exact heading names.

```markdown
# Campaign Brief — [brand_name]
**Generated:** [date]
**Website:** [website_url]
**Platforms:** [comma-separated list]
**Objective:** [objective]
**Concepts:** [N]

## Brand DNA Summary
[3-sentence synthesis of brand-profile.json: voice, visual identity, target audience]

## Audit Context
[If audit data found: top 3 weaknesses being addressed]
[If no audit data: "No audit data — run /ads audit for weakness-targeted concepts"]

## Campaign Concepts

### Concept 1: [Name]
**Hypothesis:** [why this will work — 1 sentence]
**Primary Message:** [core message — 1 sentence]
**Tone:** [voice reading from brand-profile.json]
**Visual Direction:** [2-3 sentences describing imagery]
**Target Platforms:** [platforms and rationale]
**CTA:** [call to action text]
**Addresses:** [audit finding or "general brand awareness"]

### Concept 2: [Name]
[same structure]

## Copy Deck
[appended by copy-writer agent — headlines, primary text, CTAs per concept per platform]

## Image Generation Briefs

### Brief 1: [Concept Name] — [Platform]
**Prompt:** [exact generation prompt]
**Dimensions:** [WxH]
**Safe zone notes:** [constraint or "None"]

## Next Steps
1. Review all concepts and select which to move forward with
2. Run `/ads generate` to produce images from the briefs above
3. Adjust CTAs and offers in the copy deck for your specific promotion
4. Upload final assets to your ad platform managers
```

## Quality Gates

- **Minimum 3 concepts** (unless user requests fewer)
- **Distinct angles**: no two concepts share the same primary message angle
- **Platform fit**: concepts targeting TikTok must acknowledge vertical-only format and sound-on context
- **Offer anchoring**: if the user provided a specific offer, at least 1 concept must lead with it
- **Image briefs**: every concept must have at least one image brief per requested platform
