# Signal Theory Reference

> Every output is a Signal. Maximize Signal-to-Noise Ratio. Zero exceptions.
>
> Source: "Signal Theory: The Architecture of Optimal Intent Encoding"

## The Signal

Every agent output encodes 5 dimensions:

```
S = (M, G, T, F, W)
```

| Dim | Name | What It Resolves | Example Values |
|-----|------|-----------------|----------------|
| **M** | Mode | How is it perceived? | linguistic, visual, code, data, mixed |
| **G** | Genre | What conventionalized form? | spec, brief, report, proposal, pitch, plan, transcript, note, email, adr, battlecard |
| **T** | Type | What does it DO? (speech act) | direct (compel action), inform, commit, decide, express |
| **F** | Format | What container? | markdown, code, JSON, yaml, HTML, audio, video |
| **W** | Structure | Internal skeleton? | Genre-specific template (meddpicc-scorecard, adr-template, etc.) |

All 5 dimensions MUST be resolved before producing non-trivial output. Unresolved
dimensions create noise.

### Signal Encoding in Agent Definitions

Each agent carries a default signal encoding in its frontmatter:

```yaml
signal: S=(linguistic, brief, direct, markdown, persuasion)
```

This is the agent's default output mode. Agents can override per-deliverable, but the
default encodes their most common output pattern.

## 4 Governing Constraints

Violate any one of these and the output fails.

### 1. Shannon (The Ceiling)
Every channel has finite capacity. Do not exceed the receiver's bandwidth.

- A 500-line explanation when 20 lines suffice is a Shannon violation
- Match output density to what the receiver can decode in one pass
- When in doubt, compress. The receiver can always ask for more.

### 2. Ashby (The Repertoire)
Have enough Signal variety (genres, modes, structures) to handle every situation.

- If the situation needs a spec, write a spec — not a wall of prose
- If the situation needs a table, use a table — not a paragraph describing rows
- Genre mismatch = Ashby violation. The form must match the function.

### 3. Beer (The Architecture)
Maintain viable structure at every scale. A response, a file, a system — each must
be coherently structured.

- No orphaned logic (a conclusion without supporting evidence)
- No structure gaps (a list that starts at item 3)
- Every section has a clear purpose. If it doesn't, cut it.

### 4. Wiener (The Feedback Loop)
Never broadcast without confirmation. Close the loop.

- Verify the receiver decoded correctly
- Ask when ambiguous
- Check that the action happened
- A handoff without confirmation is a failed Signal

## 6 Encoding Principles

Apply on EVERY output.

| # | Principle | What It Means |
|---|-----------|--------------|
| 1 | **Mode-message alignment** | Sequential logic -> text/code. Relational logic -> diagrams/tables. |
| 2 | **Genre-receiver alignment** | Match the genre to the receiver. Devs decode specs. PMs decode briefs. |
| 3 | **Structure imposition** | Raw information is noise. ALWAYS impose structure. Headers, sections, templates. |
| 4 | **Redundancy proportional to noise** | High-stakes -> more structure, more explicit intent. Simple context -> minimal. |
| 5 | **Entropy preservation** | Maximum meaning per unit of output. No filler, no hedging, no padding. |
| 6 | **Bandwidth matching** | Match output density to receiver's decoding capacity. 3 bullets when 3 is enough. |

## 11 Failure Modes

### Shannon Violations
| Mode | Symptom | Fix |
|------|---------|-----|
| Routing Failure | Wrong recipient | Re-route to correct receiver |
| Bandwidth Overload | Too much output | Reduce, prioritize, batch |
| Fidelity Failure | Meaning lost in encoding | Re-encode with clearer structure |

### Ashby Violations
| Mode | Symptom | Fix |
|------|---------|-----|
| Genre Mismatch | Wrong form for the situation | Re-encode in correct genre |
| Variety Failure | No genre exists for this situation | Create one |
| Structure Failure | No internal skeleton | Impose genre-specific structure |

### Beer Violations
| Mode | Symptom | Fix |
|------|---------|-----|
| Bridge Failure | No shared context between sender/receiver | Add preamble/conventions |
| Herniation Failure | Incoherence across layers | Re-encode with proper traversal |
| Decay Failure | Outdated Signal | Audit, version, or sunset |

### Wiener Violations
| Mode | Symptom | Fix |
|------|---------|-----|
| Feedback Failure | No confirmation loop | Close it — verify, check, confirm |

### Cross-Cutting
| Mode | Symptom | Fix |
|------|---------|-----|
| Adversarial Noise | Deliberate degradation | Make noise visible, escalate |

## S/N Quality Gates

Quality gates are applied at phase transitions in workflows (see Operations Spec,
Section 5). A gate rejects output when:

1. Any of the 5 Signal dimensions (M, G, T, F, W) is unresolved
2. Filler phrases detected ("Let me think about this...", "That's a great question...")
3. Output genre mismatches the receiving agent's expected input genre
4. Shannon violation: output length exceeds 2x the minimum required to convey intent
5. Structure failure: no headers, no sections, no template applied

Rejected output is returned to the producing agent with a structured rejection notice
specifying which violations were detected and what corrections are required.

### S/N Scoring

```
Score Range | Verdict
0.0 - 0.3  | REJECT — noise exceeds signal, rewrite required
0.3 - 0.5  | WARN — significant noise, revision recommended
0.5 - 0.7  | PASS — acceptable signal, minor noise tolerated
0.7 - 0.9  | GOOD — strong signal, minimal noise
0.9 - 1.0  | OPTIMAL — maximum meaning per unit of output
```

Default phase transition threshold: 0.5 (configurable per workflow phase).

## Path of Least Resistance

Optimal encoding converges on **minimum decoding effort** at the receiver:

- Uses the **mode** the receiver perceives most naturally
- Takes the **genre** the receiver has competence to decode
- Performs the **type** (speech act) that matches intended outcome
- Arrives in the **format** appropriate to the channel
- Has a **structure** that makes the internal skeleton immediately decodable
- Carries enough **redundancy** to survive noise
- Minimizes **decoding effort** at the receiver
- Produces **action** with highest probability

What the receiver experiences as clarity, elegance, or "just right" — that is the path
of least resistance.

---

## Optimal System Position

This spec defines **Layer 2 (The Signal)** of the Optimal System architecture — the
encoded intent that flows through the network. But Signal Theory governs ALL 7 layers:

| Layer | How Signal Theory Applies |
|-------|--------------------------|
| L1 Network | Routing rules determine which signals reach which nodes |
| L2 Signal | This spec — S=(M,G,T,F,W) encoding, quality gates, failure modes |
| L3 Composition | Micro-structure within each signal (compositional hierarchy) |
| L4 Interface | Progressive disclosure = Shannon constraint on the interface layer |
| L5 Data | Storage substrate must preserve signal fidelity across the DIKW hierarchy |
| L6 Feedback | Quality gates and rejection notices ARE the feedback loop |
| L7 Governance | System 5 (Policy) defines the encoding standards all agents follow |

See `architecture/optimal-system-mapping.md` for the canonical mapping.
