---
name: ads generate
description: >
  AI image generation for paid ad creatives. Reads campaign-brief.md and
  brand-profile.json to produce platform-sized ad images using Gemini
  (default) or a configured provider. Requires GOOGLE_API_KEY or
  ADS_IMAGE_PROVIDER + matching key.
  Triggers on: "generate ads", "create images", "make ad creatives",
  "generate visuals", "create ad images", "generate campaign images",
  "make the images", "generate from brief"
---

# /ads generate — AI Ad Image Generator

> Generates platform-sized ad creative images from your campaign brief and brand
> profile. Uses Gemini by default.

## Usage

```bash
/ads generate
/ads generate --platform meta
/ads generate --prompt "text" --ratio 9:16
/ads generate --batch
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--platform` | string | all | Generate for specific platform only |
| `--prompt` | string | — | Standalone generation without brief |
| `--ratio` | string | — | Aspect ratio for standalone mode |
| `--batch` | flag | false | Use batch API (50% cost, 24h turnaround) |

## Environment Setup

```bash
# Gemini (default)
export GOOGLE_API_KEY="your-key"

# Alternative providers
export ADS_IMAGE_PROVIDER="openai"
export OPENAI_API_KEY="your-key"

export ADS_IMAGE_PROVIDER="stability"
export STABILITY_API_KEY="your-key"

export ADS_IMAGE_PROVIDER="replicate"
export REPLICATE_API_TOKEN="your-token"
```

## Process

### Step 1: Check API Key

Verify the required environment variable is set before proceeding. If not set,
display setup instructions and stop.

### Step 2: Locate Source Files

Check for:
- `campaign-brief.md` — primary source for prompts and dimensions
- `brand-profile.json` — brand color/style injection (optional but recommended)

If no campaign-brief.md: enter standalone mode (ask for prompt, platform, filename).

### Step 3: Parse Image Generation Briefs

From `## Image Generation Briefs` section of campaign-brief.md, extract each brief's
prompt, dimensions, and safe zone notes.

### Step 4: Generate Images

For each brief, call the image generation API with:
- Constructed prompt (brief prompt + brand DNA injection)
- Platform-correct dimensions
- Output path: `./ad-assets/[platform]/[concept]/[filename].png`

### Step 5: Validate Formats

Check all generated images against platform spec requirements (dimensions, file size).

### Step 6: Report Results

```
Generation complete:

  Generated assets:
    ./ad-assets/meta/concept-1/feed-1080x1350.png
    ./ad-assets/tiktok/concept-1/vertical-1080x1920.png

  Cost estimate: ~$[N] at $0.067/image (Gemini)

  Next steps:
    1. Review assets in ./ad-assets/
    2. Upload to your ad platform managers
```

## Platform Dimensions (Standalone Mode)

```
meta-feed     -> 1080x1350 (4:5)
meta-reels    -> 1080x1920 (9:16)
tiktok        -> 1080x1920 (9:16)
google-pmax   -> 1200x628 (1.91:1)
linkedin      -> 1080x1080 (1:1)
youtube       -> 1280x720 (16:9)
youtube-short -> 1080x1920 (9:16)
```

## Cost Transparency

Before generating, estimate and show the cost:
- Count image briefs x $0.067 (Gemini default)
- If >$1.00, ask for confirmation before proceeding

## Dependencies

- `brand-profile.json` — from `/ads dna`
- `campaign-brief.md` — from `/ads create`
- Image generation API key (see Environment Setup)
