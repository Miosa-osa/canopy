# Signal Theory Quickstart

> The quality framework behind OSA Operations, explained in 5 minutes.

---

## The Core Idea

Every output an agent produces is a **Signal**. A Signal can be high-quality
(clear, actionable, correctly formatted) or low-quality (vague, noisy, wrong genre).

Signal Theory gives you a framework to measure and enforce output quality.
It answers one question: **Did the receiver get what they needed, in the form
they can decode, with minimum noise?**

---

## S=(M, G, T, F, W) -- The 5 Dimensions

Every Signal encodes 5 dimensions. All 5 must be resolved before producing output.
An unresolved dimension creates noise.

```
S = (Mode, Genre, Type, Format, Structure)
```

| Dim | Name | Question It Answers | Common Values |
|-----|------|-------------------|---------------|
| **M** | Mode | How is it perceived? | linguistic, visual, code, data, mixed |
| **G** | Genre | What form does it take? | spec, brief, report, proposal, plan, note, pitch, email |
| **T** | Type | What does it DO? | direct (compel action), inform, commit, decide, express |
| **F** | Format | What container? | markdown, code, JSON, yaml, HTML |
| **W** | Structure | What internal skeleton? | adr-template, review-checklist, meddpicc-scorecard |

### Real Examples

**A code review** for a developer:
```
S = (linguistic, report, inform, markdown, review-checklist)
     ^            ^       ^       ^         ^
     Perceived    Form    Purpose Container  Skeleton
     as text      is a    is to   is         follows a
                  report  inform  markdown   checklist
```

**A sales email** to a prospect:
```
S = (linguistic, email, direct, markdown, cold-email-anatomy)
     Text         Email   Compel  Markdown   Signal-based opening
                          action             + value prop + CTA
```

**An architecture decision** for the team:
```
S = (linguistic, spec, commit, markdown, adr-template)
     Text         Spec   Commit  Markdown   ADR format:
                         to a               Context, Decision,
                         decision           Consequences
```

**A pipeline dashboard** for the VP Sales:
```
S = (data, report, inform, markdown, pipeline-metrics)
     Numbers  Report  Surface  Markdown  Stage counts,
                      data               velocity, forecast
```

---

## The Genre System

Genres are conventionalized forms with predictable structures. When you say "spec,"
everyone knows what to expect: requirements, constraints, acceptance criteria.
When you say "brief," everyone knows: objective, key messages, call to action.

### When to Use Each Genre

| Genre | Use When | Receiver Expects |
|-------|---------|-----------------|
| **spec** | Defining what to build | Requirements, constraints, acceptance criteria |
| **brief** | Compelling action from non-technical people | Objective, key messages, CTA |
| **report** | Surfacing information for review | Data, analysis, recommendations |
| **proposal** | Requesting approval or buy-in | Problem, solution, cost, timeline |
| **plan** | Structuring future work | Objectives, time blocks, dependencies |
| **note** | Quick capture for later processing | Context, content, routing suggestion |
| **transcript** | Processing a meeting or call | Participants, decisions, action items |
| **pitch** | Selling an idea or product | Hook, value prop, proof, ask |
| **email** | Direct communication to a person | Subject, body, CTA |
| **adr** | Recording a technical decision | Context, decision, consequences |
| **battlecard** | Competitive positioning | Strengths, weaknesses, talk tracks |

### Genre Mismatch Is a Failure Mode

Sending a **spec** to a salesperson is a failure. They need a **brief**.
Sending a **brief** to a developer is a failure. They need a **spec**.

The genre must match what the receiver can decode. This is the principle of
**genre-receiver alignment**.

---

## Receiver-Aware Encoding

The same information should be encoded differently depending on who receives it.
This is not about dumbing things down -- it is about matching the receiver's
decoding capacity.

### Same Information, Different Output

**Information**: "We're switching from REST to GraphQL for the API layer."

**For the developer** (genre: spec):
```markdown
# ADR-012: GraphQL Migration

## Context
REST endpoints have N+1 query problems across 3 critical paths.
Client teams request 4+ roundtrips for dashboard views.

## Decision
Migrate to GraphQL with Apollo Server. REST endpoints maintained
for external API consumers during 6-month transition.

## Consequences
- Dashboard load reduced from 4 requests to 1
- Schema-first development required (new process)
- Learning curve for frontend team (estimated 2 weeks)
```

**For the VP Sales** (genre: brief):
```markdown
## API Performance Upgrade

**Objective**: Dashboard loads 4x faster for customers.

**Key Messages**:
- Customer-facing dashboards will load in under 1 second
- No customer action required -- backend change only
- Rollout over 6 months, zero downtime

**Impact**: Reduces "slow dashboard" complaints to zero.
```

**For the board** (genre: report):
```markdown
## Technical Decision: API Layer

**Decision**: Migrate internal API from REST to GraphQL.
**Cost**: ~$4,000 in engineering time (2 sprint allocation).
**Risk**: Low. External APIs unchanged. Internal only.
**Expected outcome**: 4x performance improvement on customer dashboards.
**Approval needed**: No (within CTO authority).
```

Same facts. Three different Signals. Each optimized for its receiver.

---

## Quality Gates and S/N Scoring

Signal quality is scored as a ratio of signal (useful content) to noise
(filler, ambiguity, wrong genre, missing structure).

### S/N Score Scale

| Score | Verdict | What It Means |
|-------|---------|--------------|
| 0.0-0.3 | REJECT | Noise exceeds signal. Rewrite required. |
| 0.3-0.5 | WARN | Significant noise. Revision recommended. |
| 0.5-0.7 | PASS | Acceptable signal. Minor noise tolerated. |
| 0.7-0.9 | GOOD | Strong signal. Minimal noise. |
| 0.9-1.0 | OPTIMAL | Maximum meaning per unit of output. |

### What Creates Noise

- Filler phrases: "Let me think about this...", "That's a great question..."
- Unnecessary hedging: "Perhaps we could consider..."
- Repetition: Same idea restated in different words
- Wrong genre: A paragraph explaining what a table should show
- Missing structure: No headers, no sections, no template
- Bandwidth overload: 500 lines when 20 suffice

### What Creates Signal

- Direct, actionable content
- Properly structured output (headers, tables, code blocks as needed)
- Correct genre for the receiver
- Evidence and verification (show, do not tell)
- Appropriate density -- not too much, not too little

### Phase-Level Thresholds

Workflows apply S/N thresholds at phase transitions. Output below the threshold
is rejected and returned to the producing agent:

```
Research phase:    0.7  (information must be reliable)
Build phase:       0.6  (iterating fast, lower bar)
Test phase:        0.8  (quality verification needs precision)
Deploy phase:      0.9  (production changes need confidence)
```

---

## The 4 Constraints -- Simplified

Signal Theory has 4 governing constraints. Violate any one and the output fails.

### 1. Shannon -- Do Not Overflow the Receiver

Every channel has limited bandwidth. Do not exceed what the receiver can process
in one pass.

**The test**: Can the receiver extract the key action in under 60 seconds?
If the answer is no, you are overloading the channel. Compress.

**Violation example**: A 200-line status report when 10 bullet points suffice.

### 2. Ashby -- Have the Right Form for Every Situation

You need enough genre variety to handle every situation. If the situation calls
for a table but you write a paragraph, that is an Ashby violation.

**The test**: Is this the right genre for what I need to communicate?
If you are explaining tabular data in prose, switch to a table.

**Violation example**: Describing a comparison in paragraphs instead of a
side-by-side table.

### 3. Beer -- Maintain Coherent Structure

Every output needs a clear structure at every level -- the whole document,
each section, each paragraph. No orphaned logic. No structure gaps.

**The test**: Does every section have a clear purpose? Can the reader navigate
by scanning headers alone?

**Violation example**: A report that jumps from recommendations to raw data
back to conclusions with no connecting structure.

### 4. Wiener -- Close the Loop

Never broadcast without confirmation. Verify the receiver decoded correctly.
A handoff without confirmation is a failed Signal.

**The test**: Did the receiver confirm they understood? Did the action happen?

**Violation example**: Sending a deployment plan to devops and assuming they
will execute it without confirming they received and understood it.

---

## Applying Signal Theory to Your Operation

### In Agent Definitions

Every agent carries a default signal encoding:

```yaml
signal: S=(linguistic, spec, commit, markdown, adr-template)
```

This tells the agent its default output pattern. The agent can override for
specific deliverables, but the default prevents unresolved dimensions.

### In Workflow Quality Gates

Phase transitions use S/N scoring to reject low-quality output:

```markdown
- **Signal threshold**: 0.8
```

Output below 0.8 is returned with a rejection notice specifying what failed.

### In Skill Output

Every skill specifies its output genre:

```markdown
## Output
Genre: research-brief + outreach-plan
Format: Markdown
```

This ensures the skill's output matches what downstream agents expect.

### In Handoffs

Handoff templates enforce structure on agent-to-agent transitions.
A freeform handoff is a Wiener violation -- no structure, no confirmation.

---

## Quick Reference Card

```
BEFORE producing output, resolve:

  M = Mode        What mode? (text, code, data, visual, mixed)
  G = Genre       What genre? (spec, brief, report, plan, ...)
  T = Type        What action? (direct, inform, commit, decide, express)
  F = Format      What container? (markdown, code, JSON, ...)
  W = Structure   What skeleton? (adr-template, review-checklist, ...)

CHECK against 4 constraints:

  Shannon   Am I exceeding the receiver's bandwidth?
  Ashby     Am I using the right genre for this situation?
  Beer      Is my structure coherent at every level?
  Wiener    Will the receiver confirm they decoded this correctly?

NOISE checklist:

  [ ] Every sentence carries actionable intent or necessary context
  [ ] No filler language
  [ ] No unnecessary hedging
  [ ] No repetition
  [ ] Structure is scannable (headers, sections, templates)
  [ ] Output density matches receiver's bandwidth
```

---

## Further Reading

- Full Signal Theory reference: `protocol/signal-theory.md`
- How agents use signals: [Agent Design Guide](agent-design.md)
- How workflows enforce quality: [Workflow Design Guide](workflow-design.md)
- The original paper: "Signal Theory: The Architecture of Optimal Intent Encoding"
