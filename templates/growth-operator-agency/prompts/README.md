# `prompts/` — Domain-indexed prompt library

The prompt library for Growth Operating Agency. Battle-tested prompt patterns indexed by domain — research, sales, content, content-repurposing, email, ad creative, brand voice, VSL, offer, analytics — that you can paste into Claude, GPT, or any capable assistant to get on-brand outputs without burning hours.

Every prompt here is designed to work alongside the skills in this workspace. Skills run the structured process; these prompts are the cheap, fast way to generate variants, explore ideas, or unstick a specific step.

## How to use

1. **Pick the prompt** that matches your task.
2. **Copy the parameterized block** into your assistant.
3. **Fill in the `{{BRACKETED_FIELDS}}`** with your context (ICP summary, offer description, brand voice, specific input).
4. **Run it once.** Evaluate. If the output is on target, use it. If off, tighten your inputs (not the prompt).
5. **Iterate on inputs, not prompts.** 90% of prompt-output quality comes from specificity in the input fields.

## Directory

| File | Covers |
|---|---|
| `research-prompts.md` | ICP research, competitor research, objection mining, voice-of-customer extraction, market sizing |
| `offer-prompts.md` | Offer variations, price anchoring copy, guarantee language, bonus brainstorm |
| `vsl-prompts.md` | Hook variants, mechanism naming, stack slide copy, close variants |
| `ad-creative-prompts.md` | Hook variants, angle tests, headline grid, CTA variants |
| `email-prompts.md` | Subject lines, cold-email, re-engagement, launch sequences |
| `content-prompts.md` | LinkedIn post, X thread, reel script, YouTube title, carousel |
| `sales-prompts.md` | Objection reframe, call prep, proposal drafting |
| `analytics-prompts.md` | Interpret metrics, diagnose bottleneck, forecast |
| `content-repurposing-prompts.md` | YouTube → short, podcast → X thread, blog → email |
| `brand-voice-prompts.md` | Tone calibration, phrase mining, rewrite in voice |

## Ground rules

Across every prompt in this library:

- **Always feed the context profile.** Before any prompt runs, the assistant should see the relevant company.yaml compartments. Every prompt here assumes the assistant has access to creator_identity_matrix, audience_intelligence_system, and offer_architecture at minimum. Paste those in or reference them.
- **Ask for N variants, not 1.** Variance is where quality comes from. A prompt that generates 10 options and asks you to pick one outperforms a prompt that generates 1 option.
- **Name the frameworks.** Prompts that say "use the high-value offer canon" beat prompts that say "write a good offer." The named framework triggers the assistant to activate the right pre-trained patterns.
- **Request verbatim phrases from voice-of-customer.** When a prompt is producing copy, have it echo phrases from the creator's actual customer language. "Use the language in `phrases_to_use` verbatim wherever possible."
- **Demand the output format.** Tables over paragraphs. Lists over prose. If the output isn't in the shape you can use, tighten the format spec.
- **Explicit refusals.** Every prompt should include: "If required context is missing, do not fabricate. Ask for it."
- **Ban generic phrases.** Every prompt should pass through the `spec/BANNED-VOCABULARY.md` list so the output doesn't return with "unlock," "empower," "cutting-edge," etc.

## Prompt structure

Every prompt in this library follows the same structure so they compose cleanly:

```
# Role
# Context required (what must be loaded before running)
# Task (one sentence)
# Inputs (the bracketed fields to fill)
# Constraints (banned vocab, no fabrication, voice match)
# Output format (exact structure, counts, sections)
# Example (one worked example showing the expected shape)
```

## When to NOT use these prompts

- When you have time to run the actual skill. Prompts are the fast lane; skills are the right lane. For anything mission-critical that ships to prospects (VSL, offer document, sales page, launch sequence), run the skill and let it gate on compartment thresholds.
- When the input is thin. A great prompt with thin inputs produces generic output. The right move is to fill the compartment first.
- When you're asking the assistant to replace creator judgment. Prompts produce drafts. The creator ships.

---
*Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
