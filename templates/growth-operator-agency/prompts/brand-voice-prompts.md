# brand-voice-prompts

Drop-in prompts for voice calibration, phrase mining, in-voice rewrites, voice audits. Pair with `/extract-voice` and the Brand Voice Document.

---

## Prompt 1 — Voice calibration from 3 samples

```
# Role
A voice-calibration specialist. You read 3 samples of the creator's writing and extract: communication style, tone framework (primary + secondary), personality traits, sentence-length pattern, signature phrases, phrases-to-avoid.

# Task
Calibrate my brand voice from the 3 samples below.

# Inputs
Sample 1 (LinkedIn post / blog / email): {{SAMPLE_1}}
Sample 2: {{SAMPLE_2}}
Sample 3: {{SAMPLE_3}}
Industry / niche: {{NICHE}}
Who the creator is speaking to: {{AUDIENCE}}

# Constraints
- Evidence-based — cite specific sentences from the samples.
- Don't invent traits that aren't in the samples.
- Identify 5–10 signature phrases appearing across samples.

# Output format
- Communication style (direct / consultative / storytelling / analytical / contrarian)
- Primary tone + secondary tone (e.g., blunt / warm-under-blunt)
- Personality traits (3–5)
- Signature sentence patterns (3–5, with example from samples)
- Phrases-to-use (verbatim, 10–15)
- Phrases-to-avoid (banned-feeling-for-this-voice, 10–15)
- Sentence-length pattern (short / varied / long)
- Authority positioning (category-king / challenger / insider / outsider-with-edge)

End with: the 3-line voice summary that could be used as the front-matter of any prompt asking for "write in my voice".
```

---

## Prompt 2 — In-voice rewrite

```
# Role
A voice-rewriter. You take generic copy and rewrite it in the creator's voice using the Brand Voice Document.

# Task
Rewrite the copy below in my voice.

# Inputs
Copy to rewrite: {{COPY}}
Brand voice summary: {{BRAND_VOICE_SUMMARY}}
Phrases to use: {{PHRASES_TO_USE}}
Phrases to avoid: {{PHRASES_TO_AVOID}}
Signature patterns: {{SIGNATURE_PATTERNS}}

# Constraints
- Preserve logical content.
- Use verbatim phrases from phrases-to-use where natural.
- Do not use any phrase from phrases-to-avoid.
- Mirror sentence-length pattern.
- No banned vocabulary.

# Output format
- Rewritten copy
- Change log (what changed + why)
- 3 lines I added that most strongly signal the voice

End with: the score (0–10) on how close this rewrite is to passing a Blind Output Test against the creator's actual writing.
```

---

## Prompt 3 — Phrase mining from creator corpus

```
# Role
A phrase-miner. You read 10+ pieces of creator content and extract: signature phrases (repeat ≥ 3×), unique word choices, idiom patterns, metaphor preferences.

# Task
Mine phrases from the corpus below.

# Inputs
Corpus (10+ pieces, 5,000–20,000 words): {{CORPUS}}
Note any obvious phrases the creator self-identifies with: {{SELF_IDENTIFIED_PHRASES}}

# Constraints
- Verbatim only.
- Cluster by: signature-phrase (repeats), unique-word (used in a non-standard way), metaphor preference (what the creator reaches for when explaining).

# Output format
| Phrase / word / metaphor | Cluster | Occurrences | Example usage |
|---|---|---|---|

End with: the top-5 phrases I should hard-code into every future piece of copy + the top-5 I should ensure never appear.
```

---

## Prompt 4 — Voice-mismatch audit

```
# Role
A voice-audit specialist. You compare copy produced by the team (ads, emails, sales pages) against the creator's actual voice and flag mismatches.

# Task
Audit the copy below against the Brand Voice Document. Flag every mismatch.

# Inputs
Copy to audit (multiple pieces): {{COPY_PIECES}}
Brand Voice Document: {{BRAND_VOICE_DOC}}

# Constraints
- Flag, don't rewrite.
- Be specific: "used 'supercharge' which is on phrases-to-avoid" is useful; "feels off" is not.

# Output format
| Piece | Mismatch type | Evidence | Severity (1-3) |
|---|---|---|---|

End with: the 1 piece that needs the biggest rewrite + the root cause of the drift (freelancer onboarding / template / platform override).
```

---

## Prompt 5 — Voice-match for AI assistant persona

```
# Role
A prompt-architect who configures an AI assistant to respond in the creator's voice consistently.

# Task
Write the system-prompt that makes my AI assistant (Claude / GPT / equivalent) default to my brand voice on every output.

# Inputs
Brand voice summary: {{BRAND_VOICE_SUMMARY}}
Top 15 phrases-to-use: {{PHRASES_TO_USE}}
Top 15 phrases-to-avoid: {{PHRASES_TO_AVOID}}
Typical output types (email / ad / post / reel / sales copy): {{OUTPUT_TYPES}}

# Constraints
- System prompt ≤ 400 words.
- Include concrete voice rules.
- Include banned-vocabulary enforcement.
- Include one worked example of the creator's voice at its best.

# Output format
- System prompt (≤ 400 words)
- One example of voice-correct output
- One example of voice-incorrect output (with the fix)

End with: the 1 assistant setting / configuration tweak I should make on top of the prompt (temperature, model choice, role framing).
```

---
*v1.0 — drop-in prompts for brand-voice work. Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
