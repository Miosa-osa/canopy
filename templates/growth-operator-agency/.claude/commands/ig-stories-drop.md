---
description: Generate a 17-day Instagram Stories drop cycle (Whisper → Tease → Shout). Day-by-day 4-frame calendar, DM keyword system, freebie spec, funnel wireframe, Typeform application copy, 48-72h scarcity close, email+SMS pairing, KPI dashboard. Designed for IG-native creators with an existing warm list and proven hooks.
argument-hint: [optional: launch date YYYY-MM-DD, defaults to today+21 days]
allowed-tools: Read, Write, Edit, Grep, Glob, WebFetch, Bash
---

Load + execute `skills/ig-stories-drop/SKILL.md` via the runtime binding at `skills/ig-stories-drop/adapters/claude-code.md`.

## Runtime entry

1. Read `skills/ig-stories-drop/adapters/claude-code.md` (the full runtime contract).
2. Follow its Runtime Behavior section end-to-end.
3. Pass `$ARGUMENTS` through as Launch Day if provided.

`$ARGUMENTS`

## Inputs the skill expects

- A filled `company.yaml` with brand voice, ICP, and current offer (Compartments 1–7).
- An existing warm list (Discord, email, or DM history) — the skill assumes pre-existing audience, not cold launch.
- An existing freebie or lead magnet (PDF, training, swipe file).
- Proven hooks captured in `company.yaml.brand_voice.proven_hooks`.

Pair with `/show-rate-surgery` for the post-call SMS/email cadence, and `/ad-creative` for paid-retargeting during the Shout phase.

---
*Top-level slash-command binding for /ig-stories-drop v1.0*
