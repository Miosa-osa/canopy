---
description: Extract creator Brand Voice Architecture — 10-section document with verbatim phrases_to_use + phrases_to_avoid. Enables voice-accurate output across all copy skills.
argument-hint: [optional: content sample URLs or file paths]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, WebFetch
---

# /extract-voice

Execute the Brand Voice Extractor skill.

## Instructions

Read and execute `skills/extract-voice/SKILL.md`. Follow its Process section Phases 0-11.

Requires: 5+ long-form content samples (podcasts, videos, posts, newsletters).

Write output to `output/extract-voice/{date}-brand-voice-document.md`. Update `company.yaml` Compartment 1.brand_voice_architecture.

Creator review required before downstream copy skills use this as voice source.

## Arguments

$ARGUMENTS
