# BANNED-VOCABULARY.md — Anti-Slop Filter

> **Hard constraint.** If output contains any banned vocabulary, it FAILS formal verification and is rejected before shipping. Zero exceptions without creator override.

## Why

Generic AI outputs signal "AI-generated" instantly. These phrases are the AI-generation tell. Professional creator content never uses them. The T-variable (Truth) requires output that sounds like the creator, not like ChatGPT's default voice.

## Banned Words (as verbs)

- `unlock` / `unleash` / `supercharge` / `harness` / `leverage` (as verb)
- `dive into` / `dive deep` / `deep-dive` (overused)
- `explore` / `navigate` (metaphorical, not literal)
- `transform` (overused — use specific verbs)
- `elevate` / `empower` / `amplify` (corporate-speak)
- `revolutionize` / `disrupt` (hype)
- `master` (as verb, implying full domain) — use "get good at"
- `optimize` (overused — use specific verb)
- `streamline` (corporate filler)

## Banned Adjectives

- `game-changing` / `game-changer`
- `revolutionary` / `next-level` / `cutting-edge` / `state-of-the-art`
- `groundbreaking` / `paradigm-shifting` / `transformative`
- `seamless` / `frictionless`
- `robust` / `scalable` (over-used in tech-speak)
- `holistic` / `synergistic`
- `world-class` (unless specifically backed by data)
- `best-in-class` (unless claim can be proven in 30 sec)

## Banned Phrases

- "In today's fast-paced world..."
- "In the digital age..."
- "As we navigate these uncertain times..."
- "Let's dive in"
- "The bottom line is..."
- "At the end of the day"
- "Moving forward"
- "That's a great question" (agent self-inflating)
- "Let me think about this..." (agent performing deliberation)
- "I'd be happy to help" (sycophancy)
- "It's important to note" (filler)
- "Furthermore" / "Moreover" / "Additionally" (list-y filler — use specific transitions)
- "In conclusion" (just conclude)
- "There are several factors to consider"
- "The key is..."
- "It goes without saying" (if it goes without saying, don't say it)
- "At the risk of stating the obvious"
- "With that said" / "Having said that"
- "This begs the question" (misuse anyway)
- "A word to the wise"
- "Needless to say"
- "The fact of the matter is"
- "It is what it is"
- "To be fair"
- "Hope this helps!"
- "Feel free to..."

## Banned Opening Patterns

- "I'd like to..." / "I want to..."
- "Let's explore..."
- "Here's the thing..."
- "So, the answer is..."
- Any sentence that starts with an apology ("I apologize for...")
- "I understand that..."
- "I can see why..."

## Banned Structural Tics

- Numbered lists with "1. First..." / "2. Second..." / "3. Third..." (use real transitions or named items)
- Em-dashes (—) in creator-voice output (per Syed's global preference)
- Corporate bullet-point density ("• Efficient • Scalable • Robust • Innovative")
- Closing with "Let me know if you have any questions!"

## Banned Claims (Regulatory/Brand Safety)

- Income guarantees — "guaranteed earnings/revenue/results"
- Health claims without clinical backing
- "Passive income" (without specific mechanism)
- "Anyone can do this" (unless proven)
- "100% success rate" (unless backed by verifiable data)
- "No experience needed" without nuance
- Before-and-after claims without timeline + method

## Context-Dependent Bans

Some words are fine in code/technical contexts, banned in customer-facing copy:
- `leverage` — OK in "leverage ratio" (financial), banned in "leverage our tools"
- `scalable` — OK in "scalable architecture" (technical), banned in "scalable solution"
- `robust` — OK in "robust testing" (code), banned in "robust strategy"

## Creator Override

If the creator's `brand_voice_architecture.phrases_to_use` explicitly includes a "banned" word (e.g., the creator actually says "game-changing" frequently), that word is UN-banned for this creator's outputs.

## How This Enforces

Phase 1 (pre-ship): regex scan of output against this list. Match = REJECT.
Phase 2 (manual review): creator spot-checks for subtle slop the regex missed.

## Source

- Foundations agent spec — "Banned vocabulary filter (anti-slop)"
- Syed global rules: "No em dashes in rendered text"

---
*v1.0 — 2026-04-19*
