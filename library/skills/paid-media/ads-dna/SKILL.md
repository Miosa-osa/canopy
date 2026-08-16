---
name: ads dna
description: >
  Brand DNA extractor for paid advertising. Scans a website URL to extract
  visual identity, tone of voice, color palette, typography, and imagery style.
  Outputs brand-profile.json. Run before /ads create or /ads generate for
  brand-consistent creative.
  Triggers on: "brand DNA", "brand profile", "extract brand", "brand identity",
  "brand colors", "analyze brand", "brand style guide", "brand voice"
---

# /ads dna — Brand DNA Extractor

> Extracts brand identity from a website and saves it as `brand-profile.json`
> for use by `/ads create`, `/ads generate`, and `/ads photoshoot`.

## Usage

```bash
/ads dna <url>
/ads dna https://acme.com
/ads dna https://acme.com --quick
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `<url>` | string | required | Website URL to analyze |
| `--quick` | flag | false | Homepage only (skip secondary pages) |

## Process

### Step 1: Collect URL

If the user hasn't provided a URL, ask:
> "What website URL should I analyze for brand DNA?"

### Step 2: Fetch Pages

Fetch in this order:
1. **Homepage** (`<url>`)
2. **About page** — try `<url>/about`, then `<url>/about-us`, then `<url>/our-story`
3. **Product/Services page** — try `<url>/product`, then `<url>/products`, then `<url>/services`

If `--quick` flag was provided: fetch the homepage only.

### Step 3: Extract Brand Elements

From the fetched HTML, extract:

**Colors:**
- `og:image` meta tag — analyze dominant colors
- CSS `background-color` on `body`, `header`, `.hero`, `.btn-primary`
- CSS `color` on `h1`, `h2`, `.btn`
- Identify: primary (most prominent), secondary, background, text

**Typography:**
- Google Fonts `@import` URLs — extract font names
- CSS `font-family` on `h1`, `h2`, `body`

**Voice:**
Analyze hero headline, subheadline, About page intro, and CTA button text.
Score each axis 1-10:

| Signal | Score direction |
|--------|----------------|
| Uses "you/your" frequently | formal_casual -> casual (+2) |
| Uses technical jargon | expert_accessible -> expert (-2) |
| Short punchy sentences (<=8 words) | bold_subtle -> bold (+2) |
| Data/stats in hero | rational_emotional -> rational (-2) |
| "Transform", "revolutionize" | traditional_innovative -> innovative (+2) |
| Customer testimonials lead | rational_emotional -> emotional (+2) |

**Imagery style** (from og:image and hero images):
- Photography vs. illustration vs. flat design
- Subject matter (people, product, abstract, data)
- Composition style (clean/minimal vs. busy/editorial)

**Forbidden elements** (infer from brand positioning):
- Enterprise/B2B -> "cheesy stock photos", "consumer lifestyle imagery"
- Healthcare -> "unqualified medical claims", "before/after imagery"
- Finance -> "get rich quick imagery", "unrealistic wealth displays"

### Step 4: Build brand-profile.json

```json
{
  "schema_version": "1.0",
  "brand_name": "string",
  "website_url": "string",
  "extracted_at": "ISO-8601",
  "voice": {
    "formal_casual": 1-10,
    "rational_emotional": 1-10,
    "playful_serious": 1-10,
    "bold_subtle": 1-10,
    "traditional_innovative": 1-10,
    "expert_accessible": 1-10,
    "descriptors": ["adjective1", "adjective2", "adjective3"]
  },
  "colors": {
    "primary": "#hexcode or null",
    "secondary": ["#hex1", "#hex2"],
    "forbidden": ["#hex or color name"],
    "background": "#hexcode",
    "text": "#hexcode"
  },
  "typography": {
    "heading_font": "Font Name or null",
    "body_font": "Font Name or system-ui",
    "pairing_descriptor": "brief description"
  },
  "imagery": {
    "style": "professional photography | illustration | flat design | mixed",
    "subjects": ["subject1", "subject2"],
    "composition": "brief description",
    "forbidden": ["element1", "element2"]
  },
  "aesthetic": {
    "mood_keywords": ["keyword1", "keyword2", "keyword3"],
    "texture": "minimal | textured | mixed",
    "negative_space": "generous | moderate | dense"
  },
  "brand_values": ["value1", "value2", "value3"],
  "target_audience": {
    "age_range": "e.g. 25-45",
    "profession": "brief description",
    "pain_points": ["pain1", "pain2"],
    "aspirations": ["aspiration1", "aspiration2"]
  }
}
```

### Step 5: Write brand-profile.json

Write to `./brand-profile.json` in the current working directory.

### Step 6: Confirm and Summarize

```
Brand DNA Summary:
  Brand: [brand_name]
  Voice: [descriptor 1], [descriptor 2], [descriptor 3]
  Primary Color: [hex]
  Typography: [heading_font] / [body_font]
  Target: [age_range] [profession]

Run `/ads create` to generate campaign concepts from this profile.
```

## Limitations

- **Sparse content**: Sites with <200 words produce lower-confidence profiles
- **Dynamic sites**: JavaScript-rendered content may not be captured
- **Multi-brand enterprises**: Creates one profile per URL. Run separately for each brand
- **Dark mode sites**: If body background is #333 or darker, swap background/text values
- **CSS-in-JS**: Modern React sites may not have extractable CSS. Use og:image colors as fallback
