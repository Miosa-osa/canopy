# Signal Theory Failure Modes

A diagnostic reference for the 11 failure modes in the OptimalOS signal network. Use this when communication breaks down, outputs miss their target, or the knowledge base degrades.

---

## Quick Reference

| # | Mode | Constraint | One-Line |
|---|------|-----------|----------|
| 1 | Routing Failure | Shannon | Signal sent to wrong recipient |
| 2 | Bandwidth Overload | Shannon | Too much output for channel capacity |
| 3 | Fidelity Failure | Shannon | Meaning lost in encoding |
| 4 | Genre Mismatch | Ashby | Wrong conventionalized form used |
| 5 | Variety Failure | Ashby | No genre exists for this situation |
| 6 | Structure Failure | Ashby | No internal skeleton imposed |
| 7 | Bridge Failure | Beer | No shared context between sender/receiver |
| 8 | Herniation Failure | Beer | Incoherence across system layers |
| 9 | Decay Failure | Beer | Signal is outdated/stale |
| 10 | Feedback Failure | Wiener | No confirmation loop exists |
| 11 | Adversarial Noise | Cross-cutting | Deliberate signal degradation |

---

## Shannon Failures

### 1. Routing Failure

**Symptoms**
- Receiver is confused by content that isn't meant for them
- Wrong person acts on a decision (or nobody acts)
- Signal lands in the wrong folder/node

**Root Cause**
Sender did not resolve the receiver dimension before encoding. The routing table was not consulted, or the signal touched multiple nodes and was only written to one.

**Fix**
1. Identify the correct receiver using the routing table in `CLAUDE.md`
2. Re-route the signal to the correct node folder
3. If the signal touches multiple nodes, write to all of them
4. For cross-domain signals (e.g., financial + personal), always write to 11-money-revenue as the secondary route

**Engine Check**
- `mix optimal.health` — detects orphaned signals not linked to any node
- `mix optimal.reflect` — surfaces co-occurring entities that should be linked

**Prevention**
Always resolve: "Who receives this?" before encoding. For financial signals, the answer is always "primary node + 11-money-revenue."

---

### 2. Bandwidth Overload

**Symptoms**
- Receiver stops reading mid-document
- Action rate drops (people see a wall of text and do nothing)
- The operator gets 500 lines when 20 would suffice
- A salesperson receives a spec instead of a brief

**Root Cause**
Output density exceeds the receiver's decoding capacity. The sender over-encoded — added context the receiver didn't need, repeated themselves, or used the wrong tier of detail.

**Fix**
1. Cut to the bandwidth the receiver can process
2. Apply the genre skeleton — each skeleton has a maximum footprint
3. For salespeople (Robert, Len, Liam): brief only, 5 bullets max
4. Use tiered loading: send L0 summary, offer L1 on request

**Engine Check**
- No engine check for output bandwidth — this is a human judgment call
- Before sending: ask "Would Robert Potter act on this in 60 seconds?"

**Prevention**
Check receiver's genre preference in the People table (`CLAUDE.md`) before encoding. Match output density to that receiver's documented capacity.

---

### 3. Fidelity Failure

**Symptoms**
- Receiver decoded the opposite of what was intended
- Action taken is wrong despite the receiver reading the signal
- "I thought you meant X" — meaning loss in translation

**Root Cause**
The encoding was ambiguous. Meaning was lost because the structure was too loose, the language was hedged, or the type (speech act) was unclear — the receiver couldn't tell if it was a direct command, an FYI, or a decision.

**Fix**
1. Re-encode with explicit type: is this a direct (compel action), inform, commit, decide, or express?
2. Remove hedging language ("maybe", "perhaps", "you might want to")
3. Make the call to action unambiguous — one ask, one deadline
4. Use the genre skeleton's CTA section explicitly

**Engine Check**
- `mix optimal.verify --sample 10` — tests whether L0 abstracts faithfully represent full content
- Low fidelity score = the abstract is lying about what the signal contains

**Prevention**
Before sending: state the type dimension explicitly. "This is a decision. The decision is X." or "This is a direct. Do Y by Z date."

---

## Ashby Failures

### 4. Genre Mismatch

**Symptoms**
- Developer receives a brief when they needed a spec
- Salesperson receives a spec when they needed a brief
- Technical partner receives a wall of prose when they needed a numbered list
- Receiver has the information but can't act because the form is wrong

**Root Cause**
The sender selected a genre based on habit or convenience rather than the receiver's decoding competence. The content may be correct, but the container is wrong.

**Fix**
1. Identify receiver's genre preference from the People table
2. Re-encode in the correct genre using the skeleton from `CLAUDE.md`
3. The 5 most common genres: brief, spec, plan, transcript, note
4. Full catalogue: `docs/taxonomy/genres.md`

**Engine Check**
- `mix optimal.search "query" --type signal` — inspect what genres are being used for a node
- If a node has mostly prose notes where specs should exist, genre mismatch is systemic

**Prevention**
Before encoding: "What genre does this receiver decode most naturally?" Consult the People table. Never default to prose.

---

### 5. Variety Failure

**Symptoms**
- Situation exists but no genre template matches it
- You're writing a "note" but it's really a hybrid of 3 things
- The signal doesn't fit anywhere cleanly

**Root Cause**
The genre repertoire doesn't have enough variety to cover this situation. This is a system-level gap — the Ashby variety requirement is not met.

**Fix**
1. Route to `09-new-stuff` — don't force a misfit genre
2. Document the new situation type: "We need a genre for X"
3. Create the genre skeleton in `docs/taxonomy/genres.md`
4. Add it to the routing table if it recurs

**Engine Check**
- `mix optimal.health` — surfaces signals routed to 09-new-stuff at high rate (indicates variety gap)
- High volume in 09-new-stuff = Ashby variety failure at system level

**Prevention**
Review `docs/taxonomy/genres.md` quarterly. When the same situation recurs 3+ times without a genre, create one.

---

### 6. Structure Failure

**Symptoms**
- Output is a wall of prose with no skeleton
- Reader cannot extract action items without parsing the whole document
- Headers are missing; sections are not distinct
- Signal is technically complete but operationally useless

**Root Cause**
The sender encoded raw information without imposing structure. The genre skeleton was ignored or no genre was selected. Information ≠ signal. Unstructured output is noise.

**Fix**
1. Select a genre and apply its skeleton immediately
2. Minimum structure: Purpose → Content → Action
3. For any signal over 100 words: impose headers
4. Run the Noise Elimination Checklist before delivery

**Engine Check**
- `mix optimal.verify` — checks if L0 abstracts have structure (title + summary + key points)
- Unstructured L0 = structure failure was captured at ingest time

**Prevention**
Never write without a genre. If unsure: note genre is the minimum viable structure. "Context / Content / Route" is always sufficient scaffolding.

---

## Beer Failures

### 7. Bridge Failure

**Symptoms**
- Receiver has no shared context to decode the signal
- "Who is Ed?" — receiver doesn't know the entities referenced
- New team member can't use existing signals
- Signal makes sense to the operator but nobody else

**Root Cause**
The sender assumed shared context that doesn't exist. The signal references entities, decisions, or history that the receiver has no access to. No bridge was built between sender's knowledge and receiver's knowledge.

**Fix**
1. Add preamble: define entities, reference the decision history
2. For external receivers: include enough context to decode without access to internal files
3. For briefs sent to salespeople: assume zero internal knowledge
4. Cross-reference key signals: "See context.md node 04 for Ed Honour background"

**Engine Check**
- `mix optimal.assemble "topic"` — surfaces the bridge context needed before a conversation
- `mix optimal.reflect` — finds entities that are referenced but not linked to their source context

**Prevention**
Before sending to anyone outside the core system (the operator + the technical partner): ask "Can they decode this cold?" If no, add the bridge.

---

### 8. Herniation Failure

**Symptoms**
- L0 abstract says one thing; full content says another
- Weekly signal.md contradicts the context.md ground truth
- Architecture docs describe a system that doesn't match the code
- Incoherence detected when reading across layers

**Root Cause**
A signal was updated at one layer but not propagated to adjacent layers. The system lost coherence across its own levels. Named for the structural failure where one layer "herniates" into another — the boundary breaks.

**Fix**
1. `mix optimal.verify --sample 20` — find L0/full content mismatches
2. Update the stale layer to match the authoritative source
3. Rule: context.md is the source of truth for persistent facts. Signal.md is the source of truth for weekly state. Never reverse this.
4. After any major decision: update context.md "Key Decisions" section

**Engine Check**
- `mix optimal.verify` — primary tool for detecting herniation
- `mix optimal.health` — checks for structural inconsistencies across the knowledge base

**Prevention**
Maintain the context.md vs signal.md separation strictly. Persistent facts → context.md. Temporal state → signal.md. Never mix them.

---

### 9. Decay Failure

**Symptoms**
- Acting on information that is weeks or months old
- Pricing, team membership, or project status in context.md hasn't been updated
- Search surfaces stale signals as top results
- the operator makes a decision based on a fact that changed

**Root Cause**
Signals were written but never updated as the world changed. The knowledge base is temporally incoherent — it represents a past state as if it were current. All signals have a half-life; failure to acknowledge this is Decay Failure.

**Fix**
1. `mix optimal.reweave "topic"` — finds stale contexts about a topic and suggests updates
2. `mix optimal.health` — runs 10 diagnostic checks including decay scoring
3. Update context.md whenever ground truth changes (don't wait for the weekly review)
4. Friday review: explicitly check signal.md files for staleness

**Engine Check**
- `mix optimal.reweave "topic" --days 60` — custom staleness threshold
- Temporal decay formula: `e^(-λ * hours_old)` — engine auto-deprioritizes stale signals
- Genre-specific half-lives in `topology.yaml`: transcripts decay in 7 days; specs persist 180 days

**Prevention**
After every call or decision: immediately update the affected context.md. Don't let ground truth drift. The engine handles signal decay automatically; context.md decay is a human responsibility.

---

## Wiener Failures

### 10. Feedback Failure

**Symptoms**
- Signal was sent but no confirmation it was received/decoded
- Delegation made but no check-in scheduled
- Decision communicated but no acknowledgment from receiver
- "Did you get my message?" — classic Wiener violation

**Root Cause**
The sender broadcast without closing the loop. Communication was treated as one-way transmission rather than a round-trip. The feedback channel was never opened.

**Fix**
1. After every delegation: add a fidelity tracking entry to the relevant signal.md
2. After every decision communicated: confirm receipt explicitly
3. Friday review: check fidelity tracking table — did delegated signals come back as intended?
4. For high-stakes signals: require explicit acknowledgment before acting

**Engine Check**
- Friday review workflow: `signal.md` fidelity tracking table
- `mix optimal.remember --contextual` — surfaces unconfirmed patterns from recent signals

**Prevention**
Every delegation needs: Person + Task + Deadline + Check-in date. No check-in = Wiener violation by design.

---

## Cross-Cutting

### 11. Adversarial Noise

**Symptoms**
- Signal is technically well-formed but systematically misleading
- Information is accurate in isolation but creates false impressions in aggregate
- Someone is selectively sharing information to steer decisions
- Patterns in incoming signals don't match reality

**Root Cause**
Deliberate degradation of signal quality by a participant in the network. Unlike the other 10 failure modes (which are accidents or system gaps), adversarial noise is intentional. It exploits the trust assumptions built into the signal system.

**Fix**
1. Make the noise pattern visible — surface it explicitly rather than acting on the degraded signal
2. Cross-reference with independent sources (other people, other nodes, documented history)
3. Escalate: adversarial noise is a people problem, not a system problem
4. Document the pattern in `01-operator/context.md` under "Key Decisions"

**Engine Check**
- No automated engine check for adversarial noise — requires human pattern recognition
- `mix optimal.graph hubs` — overly connected entities may be signal amplifiers (watch for distortion)
- `mix optimal.reflect` — unusual co-occurrence patterns may indicate manufactured associations

**Prevention**
Build independent verification into high-stakes decisions. Never rely on a single source for decisions with major financial or strategic consequences.

---

## Domain Vulnerability Matrix

Which failure modes are most common per domain. Use this to prioritize diagnostic attention.

| Failure Mode | Business | Technical | Personal | Operational |
|---|---|---|---|---|
| 1. Routing Failure | HIGH | MEDIUM | LOW | HIGH |
| 2. Bandwidth Overload | HIGH | LOW | MEDIUM | MEDIUM |
| 3. Fidelity Failure | HIGH | MEDIUM | HIGH | MEDIUM |
| 4. Genre Mismatch | HIGH | LOW | LOW | MEDIUM |
| 5. Variety Failure | MEDIUM | LOW | LOW | LOW |
| 6. Structure Failure | MEDIUM | LOW | MEDIUM | HIGH |
| 7. Bridge Failure | HIGH | LOW | LOW | MEDIUM |
| 8. Herniation Failure | LOW | HIGH | LOW | HIGH |
| 9. Decay Failure | MEDIUM | HIGH | MEDIUM | HIGH |
| 10. Feedback Failure | HIGH | MEDIUM | LOW | HIGH |
| 11. Adversarial Noise | HIGH | LOW | MEDIUM | LOW |

**Business domain** (sales, partnerships, revenue): Routing, Bandwidth, Fidelity, Genre Mismatch, Bridge, Feedback are the dominant risks. The receiver is almost never technical. Genre always matters.

**Technical domain** (engine, platform, specs): Herniation and Decay are the dominant risks. Code and docs drift apart. Specs go stale. The system coherence breaks silently.

**Personal domain** (the operator's goals, energy, health): Fidelity and Adversarial Noise are the risks. the operator's intentions don't survive encoding into delegated tasks. External noise shapes decisions.

**Operational domain** (rhythm, runbooks, daily execution): Routing, Structure, Decay, and Feedback are dominant. Procedures without structure fail. Delegations without feedback loops drift. Stale runbooks cause incidents.

---

## See Also

- `reference/search-architecture.md` — Engine checks for decay and herniation
- `reference/session-lifecycle.md` — Feedback loops in daily rhythm
- `CLAUDE.md` — Routing table and genre skeletons
- `docs/taxonomy/genres.md` — Full genre catalogue
