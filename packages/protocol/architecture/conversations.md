# Conversations — Structured Multi-Agent Dialogue Protocol

> Structured multi-agent conversations that produce collective intelligence.
> Four conversation types, three turn strategies, a structured debate mechanism
> with convergence tracking, Weaver auto-summarization, and a persona system
> that augments agent behavior without altering identity.

---

## Overview

Not all agent work is solitary. Some problems require multiple perspectives
synthesized into a single position — design reviews that expose blind spots,
red team sessions that stress-test plans, brainstorms that generate option
breadth, user panels that simulate diverse stakeholder responses.

The Conversations protocol defines how structured multi-agent dialogue is
initiated, moderated, tracked, and synthesized. A conversation is not a task
comment thread — it is a time-bounded, facilitated exchange with a defined
structure, a convergence target, and a Weaver that summarizes the output into
a form the rest of the system can consume.

The design principle: **structure amplifies collective intelligence; free-form
chat degrades it**. Without a moderator, roles, and convergence criteria,
multi-agent conversations become an echo chamber or an argument. With them,
they become a reasoning accelerator.

---

## Conversation Types

| Type | Purpose | Default Turn Strategy | Typical Duration |
|------|---------|----------------------|-----------------|
| `brainstorm` | Generate diverse options for a problem | `round_robin` | 3–5 turns per agent |
| `design_review` | Expose weaknesses in a proposed design | `facilitator` | 2–4 rounds |
| `red_team` | Adversarial stress-testing of a plan or system | `weighted` (Jaccard) | 2–3 rounds |
| `user_panel` | Simulate stakeholder responses to a proposal | `round_robin` | 1–2 rounds per persona |

### Type: `brainstorm`

The brainstorm produces a set of candidate options. Each participant generates
independently. The Weaver de-duplicates, groups by theme, and produces a ranked
option list.

```
Facilitator presents the problem statement
  │
  ▼
Round 1: all agents generate options independently (no cross-talk)
  │
  ▼
Round 2: agents react to each other's options (build or challenge)
  │
  ▼
Round 3 (optional): agents vote on top-K options (see Structured Debate: vote)
  │
  ▼
Weaver synthesizes: groups by theme, removes duplicates, ranks by vote
```

### Type: `design_review`

The design_review requires one agent to present a design and others to critique.
The facilitator ensures critique is specific, not generic.

```
Presenter shares design document (artifact or markdown)
  │
  ▼
Round 1: reviewers independently identify concerns (no discussion yet)
  │
  ▼
Round 2: facilitator presents consolidated concerns → presenter responds to each
  │
  ▼
Round 3: reviewers score: accept / conditionally_accept / reject
  │
  ▼
Weaver produces: review summary with APPROVED | NEEDS_CHANGES | REJECTED verdict
```

### Type: `red_team`

The red_team assigns one or more agents as "attackers" and one as "defender."
Attackers identify failure modes; defender responds with mitigations.

```
System/plan presented to all agents
  │
  ▼
Role assignment: {attackers: [A, B], defender: C}
  │
  ▼
Round 1: attackers generate threat scenarios independently
  │
  ▼
Round 2: defender proposes mitigations for each threat
  │
  ▼
Round 3: attackers rate mitigations (effective / partial / ineffective)
  │
  ▼
Weaver produces: threat matrix with {threat, mitigation, effectiveness, residual_risk}
```

### Type: `user_panel`

The user_panel uses the persona system (see below). Each participant is assigned
a persona (or uses their own identity). The goal is simulating diverse user
reactions to a proposal.

```
Proposal presented to panel
  │
  ▼
Each persona responds from their perspective:
  - What do they value?
  - What do they find confusing or concerning?
  - Would they adopt/accept/reject?
  │
  ▼
Weaver produces: segmented response map {persona → reaction} + synthesized insight
```

---

## Turn Strategies

The turn strategy governs which agent speaks when.

### Strategy: `facilitator`

An LLM-driven facilitator (a dedicated agent role, not a human) decides who speaks
next based on conversation state. The facilitator tracks what has been said, what
has not been addressed, and which agents have been silent.

```elixir
defmodule Conversations.Turn.Facilitator do
  def next_speaker(state) do
    # Build facilitator prompt with full conversation history
    # Ask: "Who should speak next and what should they address?"
    # Parse response: {agent_id, prompt_for_agent}
    FacilitatorLLM.decide(state.history, state.participants, state.topic)
  end
end
```

**When to use**: Asymmetric conversations where some participants have more
to contribute. Design reviews. Red teams. Any conversation with a moderator role.

**Cost**: ~500 tokens per facilitator decision.

### Strategy: `round_robin`

Simple sequential rotation. Each agent speaks once per round. Order is fixed
at conversation start (by role priority or random shuffle).

```
Round 1: Agent A → Agent B → Agent C
Round 2: Agent A → Agent B → Agent C
...until convergence or max_rounds
```

**When to use**: Brainstorms. User panels. Any symmetric conversation where all
participants should have equal airtime.

**Cost**: No overhead beyond agent turns.

### Strategy: `weighted` (Jaccard Similarity)

Agents whose last contribution was most different from the previous speaker are
prioritized. This maximizes semantic variety — the next speaker is the one most
likely to introduce new perspective rather than echo what was just said.

```
After each agent turn:
  Compute embedding of agent's contribution
  Compute Jaccard similarity between this embedding and all other agents' last contributions
  Next speaker = agent with lowest similarity to the just-spoken agent
```

```elixir
defmodule Conversations.Turn.Weighted do
  def next_speaker(state) do
    last_contribution = List.last(state.history)
    last_embedding = Embeddings.encode(last_contribution.content)

    state.participants
    |> Enum.reject(& &1.id == last_contribution.agent_id)
    |> Enum.min_by(fn agent ->
      Embeddings.jaccard_similarity(last_embedding, agent.last_contribution_embedding)
    end)
  end
end
```

**When to use**: Red teams where echo chamber risk is high. Any conversation
where variety of perspective is more valuable than coherence.

**Cost**: Embedding computation per turn (~200ms latency).

---

## Structured Debate

The structured debate mechanism imposes formal structure on controversial decisions.
It has four stages: propose → critique → revise → vote.

### Stage Flow

```
┌──────────────┐
│   PROPOSE    │  One agent proposes a position
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   CRITIQUE   │  Other agents critique the proposal (structured critique format)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   REVISE     │  Proposer revises based on critiques
└──────┬───────┘
       │
       ├──── convergence_score > threshold → VOTE
       │
       └──── convergence_score ≤ threshold → back to CRITIQUE (max 3 cycles)
       │
       ▼
┌──────────────┐
│    VOTE      │  All agents vote: accept / accept_with_reservations / reject
└──────────────┘
```

### Critique Format

Each critique must be structured to prevent generic objections:

```markdown
## Critique by {agent_name}

**Position**: [support | neutral | oppose]

**Specific concerns** (each must cite the specific claim being challenged):
1. {claim from proposal} — Concern: {specific issue} — Impact: {high|medium|low}
2. {claim from proposal} — Concern: {specific issue} — Impact: {high|medium|low}

**Suggested revision**: {specific change that would address the concern}

**Blocker?**: [yes — would reject if unaddressed | no — would accept with reservation]
```

### Convergence Tracking

Convergence is measured after each revision cycle:

```
convergence_score = 1 - (divergent_agents / total_agents)

divergent_agent = any agent whose critique contains a blocker that has not been
                  addressed in the latest revision

Example:
  5 agents. After revision 2:
    - Agent A: no remaining blockers
    - Agent B: no remaining blockers
    - Agent C: 1 remaining blocker
    - Agent D: no remaining blockers
    - Agent E: no remaining blockers

  divergent_agents = 1 (Agent C)
  convergence_score = 1 - (1/5) = 0.80
```

Default convergence threshold: `0.80` (80% of agents have no remaining blockers).
Configurable per conversation:

```yaml
debate:
  convergence_threshold: 0.80
  max_critique_cycles: 3
  force_vote_after_max_cycles: true
```

### Vote Tallying

```elixir
defmodule Conversations.Debate.Tally do
  def tally(votes) do
    %{
      accept:                  Enum.count(votes, & &1 == :accept),
      accept_with_reservations: Enum.count(votes, & &1 == :accept_with_reservations),
      reject:                  Enum.count(votes, & &1 == :reject),
      outcome: cond do
        reject_count(votes) > 0 -> :rejected
        accept_count(votes) >= majority(votes) -> :accepted
        true -> :accepted_with_reservations
      end
    }
  end
end
```

---

## Weaver Auto-Summarization

The Weaver is a dedicated summarization step that runs at conversation end. It
is not a participant — it is a post-processor that produces structured output
the rest of the system can consume.

### Weaver Inputs

```
- conversation_type: brainstorm | design_review | red_team | user_panel
- full turn history: [{agent_id, content, turn_number, timestamp}]
- debate_result: nil | %{outcome, votes, final_revision}
- convergence_metrics: {rounds, convergence_score_history}
```

### Weaver Outputs by Type

| Type | Weaver Output |
|------|--------------|
| `brainstorm` | Ranked option list with themes, vote counts, key supporting arguments |
| `design_review` | APPROVED / NEEDS_CHANGES / REJECTED verdict + issue list + suggested revisions |
| `red_team` | Threat matrix (threat → mitigation → effectiveness → residual_risk) |
| `user_panel` | Segmented response map + synthesized insight + adoption likelihood |

### Weaver System Prompt Excerpt

```
You are the Weaver for a {conversation_type} conversation on topic: {topic}.

Your job is NOT to add your own opinion. Your job is to:
1. Accurately represent what was said by each participant.
2. Identify where participants agreed and where they diverged.
3. Surface the highest-signal insights (not just the loudest voices).
4. Produce the structured output format for this conversation type.

Signal Theory constraint: maximize S/N. Do not pad. Do not repeat.
Every sentence in your output must carry information not expressible more concisely.
```

---

## Persona System

Personas allow agents to adopt a defined perspective without altering their
core identity. A persona is an overlay — it changes what the agent cares about
and how it responds, but not who the agent fundamentally is.

### Predefined Personas

| Persona ID | Archetype | Key Characteristics |
|-----------|-----------|-------------------|
| `skeptic` | Critical evaluator | Questions assumptions, asks "what could go wrong?", high burden of proof |
| `champion` | Enthusiastic adopter | Amplifies benefits, surfaces opportunities, advocates for forward motion |
| `pragmatist` | Resource-conscious | Focuses on cost, timeline, implementation complexity |
| `end_user` | Non-technical stakeholder | Values simplicity, clarity, and direct value; confused by jargon |
| `security_auditor` | Risk-focused | Identifies attack surfaces, questions data flows, asks about failure modes |
| `newcomer` | First-time evaluator | Asks basic questions, surfaces assumptions that experts overlook |

### Custom Persona Overlays

Teams can define custom personas for domain-specific panels:

```yaml
personas:
  - id: "enterprise_cto"
    archetype: "Enterprise Technology Decision Maker"
    values: ["scalability", "vendor_support", "compliance", "total_cost_of_ownership"]
    concerns: ["vendor_lock_in", "data_sovereignty", "integration_complexity"]
    typical_questions:
      - "How does this integrate with our existing IAM?"
      - "What's the 3-year TCO?"
      - "Who is accountable when this fails at 2am?"

  - id: "solo_developer"
    archetype: "Independent Developer / Indie Hacker"
    values: ["developer_experience", "time_to_first_value", "pricing_transparency"]
    concerns: ["complexity", "cost_at_scale", "lock_in"]
    typical_questions:
      - "Can I get started in 5 minutes?"
      - "What does this cost when I have 1,000 users?"
```

### Persona Injection

Personas are injected as a prefix to the agent's context at conversation start:

```
[PERSONA OVERLAY — ACTIVE FOR THIS CONVERSATION]
For this conversation, you are responding as: {persona.archetype}

Your values for this conversation: {persona.values}
Your concerns for this conversation: {persona.concerns}

Respond from this perspective throughout. When the conversation ends,
your persona overlay is removed. This is a conversation-scoped overlay only.
[END PERSONA OVERLAY]
```

The overlay is prepended to the agent's system prompt for the duration of the
conversation. It is not persisted to session state.

---

## Conversation Lifecycle

```
Conversation created (type, participants, topic, turn_strategy)
  │
  ▼
┌─────────────────────────────────────┐
│  PRE-CONVERSATION SETUP              │
│  - Assign personas (if user_panel)   │
│  - Inject coordination context       │
│  - Set facilitator role (if needed)  │
│  - Initialize turn order             │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  ACTIVE TURNS                        │
│  - Turn strategy drives sequence     │
│  - Each turn produces a contribution │
│  - Facilitator probes as needed      │
│  - Convergence checked after rounds  │
└──────────────┬──────────────────────┘
               │
               ├── max_rounds reached OR convergence threshold met
               │
               ▼
┌─────────────────────────────────────┐
│  STRUCTURED DEBATE (if configured)   │
│  propose → critique → revise → vote  │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  WEAVER SYNTHESIS                    │
│  - Produce type-specific output      │
│  - Post summary to team context      │
│  - Create decision nodes if needed   │
└──────────────┬──────────────────────┘
               │
               ▼
          CONVERSATION COMPLETE
          output stored in: context-mesh, task comment, decision graph
```

### Configuration Schema

```yaml
conversation:
  type: brainstorm           # brainstorm | design_review | red_team | user_panel
  topic: "API versioning strategy"
  participants:
    - agent_id: "architect"
      persona: null
    - agent_id: "backend-lead"
      persona: null
    - agent_id: "devops-lead"
      persona: "skeptic"
  turn_strategy: round_robin # facilitator | round_robin | weighted
  max_rounds: 4
  debate:
    enabled: true
    convergence_threshold: 0.80
    max_critique_cycles: 3
  weaver:
    post_to_context_mesh: true
    create_decision_nodes: true
```

---

## Signal Theory Position

Conversations implement **Layer 3 (The Composition)** of the Optimal System.

```
OS Layer 3 — The Composition
  ↕
Conversations — multi-agent signal composition into collective intelligence

COMPOSITION: A conversation is not multiple separate signals — it is a
  structured process that composes multiple agent signals into one collective
  signal with higher information density than any individual agent could
  produce. The Weaver output is the composed signal.

MICRO-STRUCTURE: Turn strategies, critique formats, and the debate lifecycle
  define the micro-structure of how individual contributions combine. Without
  this structure, the conversation is noise (multiple agents broadcasting
  simultaneously). With it, the conversation is signal (each turn builds on
  or challenges the last, converging toward a shared position).
```

### Governing Principle: Ashby — Requisite Variety

Debate variety must match problem variety. A brainstorm with five agents who
all share the same background will converge quickly but produce low-variety
output — an Ashby failure. The persona system and Jaccard-weighted turn strategy
exist to inject variety artificially when participant diversity is insufficient.

A red_team that only has "champion" personas cannot catch real weaknesses — it
lacks the variety (attacker perspective) needed to match the variety of real-world
adversaries. The persona system provides requisite variety when agent diversity
cannot.

### Governing Principle: Shannon — Channel Capacity

Each turn is a channel transmission. Long, unfocused contributions degrade
signal-to-noise for every participant who must read them. The structured
critique format (specific claim → specific concern → specific revision) enforces
Shannon efficiency: every sentence carries information not expressible more
concisely. Facilitator probing maintains channel discipline by redirecting agents
who are broadcasting noise.

---

## See Also

- [context-mesh.md](context-mesh.md) — Weaver posts conversation summaries to the team's keeper
- [decision-graph.md](decision-graph.md) — Conversations create decision nodes when debates reach a verdict
- [peer-protocol.md](peer-protocol.md) — Structured handoffs reference conversation outputs in `decisions_made`
- [team-coordination.md](team-coordination.md) — Conversations extend the leader-worker model for collective work
- [memory-architecture.md](memory-architecture.md) — Episodic memory stores conversation records; semantic memory extracts facts
- [optimal-system-mapping.md](optimal-system-mapping.md) — Full 7-layer OS mapping

---

*Conversations v1.0 — Structured multi-agent dialogue with turn strategies, debate mechanics, Weaver synthesis, and persona overlays*
