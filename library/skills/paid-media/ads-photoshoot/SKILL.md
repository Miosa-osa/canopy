---
name: ads photoshoot
description: >
  Product photography enhancement for ad creatives using AI image generation.
  Takes a product image and generates 5 professional photography styles for
  ad use: Studio, Floating, Ingredient, In Use, and Lifestyle. Requires
  GOOGLE_API_KEY or configured ADS_IMAGE_PROVIDER.
  Triggers on: "product photo", "product photography", "photoshoot",
  "enhance product image", "product shoot", "product photos for ads",
  "studio shot", "lifestyle photo"
---

# /ads photoshoot — AI Product Photography

> Transforms a product image or description into professional ad-ready photography
> in 5 distinct visual styles, each at platform-appropriate sizes.

## Usage

```bash
/ads photoshoot
/ads photoshoot --styles studio floating
/ads photoshoot --product shoe.jpg
/ads photoshoot --all-platforms
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--styles` | string[] | all 5 | Which styles to generate |
| `--product` | string | — | Product image file path |
| `--all-platforms` | flag | false | Generate all 5 sizes per style |

## Environment Setup

```bash
export GOOGLE_API_KEY="your-key"
# See /ads generate for alternative providers
```

## Process

### Step 1: Collect Product Information

1. **Product image**: Path to file, URL, or text description
2. **Product description**: What is it? Key features?
3. **Styles to generate**: Studio, Floating, Ingredient, In Use, Lifestyle (default: all 5)
4. **Target platforms**: Determines output sizes (default: Meta + TikTok = 1:1 + 9:16)

### Step 2: Load Brand Profile (Optional)

Check for `brand-profile.json` — if found, inject:
- `colors.primary` into backgrounds and accents
- `aesthetic.mood_keywords` as atmosphere descriptors
- `target_audience` for Lifestyle and In Use context
- `imagery.forbidden` exclusions into all prompts

### Step 3: Generate per Style

#### Style 1: Studio
Clean, e-commerce product shot. White seamless background, even studio lighting.
- Output: 1080x1080, 1080x1920

#### Style 2: Floating
Dramatic levitation effect with gradient background.
- Output: 1080x1080, 1080x1920

#### Style 3: Ingredient
Flat lay with components/materials artfully arranged. Top-down view.
- Output: 1080x1080 (optimal for this style)

#### Style 4: In Use
Authentic usage context. Hands using product, shallow depth of field.
Hands only — no full face (avoids model release complications).
- Output: 1080x1080, 1080x1920

#### Style 5: Lifestyle
Aspirational full-context shot. Environmental context with product as hero.
- Output: 1080x1080, 1080x1920

### Step 4: Organize Output

```
./product-photos/
  studio/
    product-studio-1080x1080.png
    product-studio-1080x1920.png
  floating/
    product-floating-1080x1080.png
    product-floating-1080x1920.png
  ingredient/
    product-ingredient-1080x1080.png
  in-use/
    product-in-use-1080x1080.png
    product-in-use-1080x1920.png
  lifestyle/
    product-lifestyle-1080x1080.png
    product-lifestyle-1080x1920.png
```

## Platform Recommendations

| Style | Best Platforms | Rationale |
|-------|---------------|-----------|
| Studio | Meta Feed, LinkedIn, Google PMax | Universal, clean, platform-safe |
| Floating | Meta Reels, TikTok, Stories | High visual impact on vertical |
| Ingredient | Meta Feed, Pinterest | Best as square; tells product story |
| In Use | TikTok, Meta Reels, Stories | Authentic, native-feeling content |
| Lifestyle | All platforms | Aspirational, broad audience appeal |

## Cost Estimate

- Number of styles x 2 sizes = total images
- $0.067/image (Gemini default)
- If >$0.50, ask for confirmation

## Dependencies

- `brand-profile.json` — from `/ads dna` (optional)
- Image generation API key (see Environment Setup)
