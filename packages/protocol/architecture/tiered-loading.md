# Tiered Loading

> L0/L1/L2 context management. The system that prevents context window overflow
> by loading knowledge at the right depth for the current task. Never load full
> content when an abstract suffices. Never guess when search can tell you.
>
> Tiered retrieval with token budgets and cache-aware loading for OSA Operations
> with Signal Theory gates.

---

## The Problem

LLM context windows are finite. A workspace with 200 documents at ~2K tokens each
is 400K tokens — half the context window consumed by reference material before the
agent even starts working. Most of that content is irrelevant to the current task.

Tiered loading solves this: load abstracts first, expand only what matters.

---

## Three Tiers

```
┌─────────────────────────────────────────────────────┐
│  L0 — Always Loaded                                 │
│  ~100 tokens per item, ETS cache                    │
│  System identity + compressed abstracts             │
│  Budget: 5K-15K tokens total                        │
├─────────────────────────────────────────────────────┤
│  L1 — On-Demand Summaries                           │
│  ~2K tokens per item, loaded when topic relevant    │
│  Structured overviews with key facts                │
│  Budget: 20K-50K tokens per task                    │
├─────────────────────────────────────────────────────┤
│  L2 — Full Content                                  │
│  Full document, loaded only for deep work           │
│  Complete text with all detail                      │
│  Budget: 100K tokens max per session                │
└─────────────────────────────────────────────────────┘
```

### Tier Definitions

| Tier | Size | When Loaded | Cache | Lifespan |
|------|------|-------------|-------|----------|
| L0 | ~100 tokens | Always (session boot) | ETS hot cache | Entire session |
| L1 | ~2K tokens | Task relevance detected | LRU cache, 10 min TTL | Current task |
| L2 | Full content | Explicit request or deep dive | No cache (too large) | Single use |

---

## L0: Always-Loaded Essentials

L0 is the compressed knowledge base that every agent carries at all times. It
answers the question: "What exists and what is it about?"

### What Goes in L0

```yaml
l0_contents:
  system:
    - SYSTEM.md identity section       # Who am I, what do I do
    - Agent's own definition           # My role, rules, signal encoding
    - Active task description          # What I'm working on right now

  knowledge_abstracts:
    - title: "AI Masters Pricing"
      abstract: "Partner wants $2K/seat. Owner countered $1.5K. Decision pending."
      node: "04-ai-masters"
      updated: "2026-03-18"
      relevance_score: 0.82

    - title: "Enterprise Deal Status"
      abstract: "Sales team closed. $48K ARR. Onboarding starts March 25."
      node: "06-agency"
      updated: "2026-03-17"
      relevance_score: 0.71

  people_index:
    - name: "Ed Honour"
      role: "Course Partner"
      send_genre: "brief, proposal"
      active_threads: 2
```

### L0 Generation

L0 abstracts are pre-computed, not generated on-the-fly:

```elixir
defmodule TieredLoader.L0 do
  @l0_budget 15_000  # tokens
  @abstract_target 100  # tokens per item

  def generate_abstract(resource) do
    # Extract the core claim, current status, and next action
    %{
      title: resource.title,
      abstract: compress(resource.content, target: @abstract_target),
      node: resource.node,
      updated: resource.updated_at,
      relevance_score: score_relevance(resource)
    }
  end

  def load_l0(agent_id) do
    abstracts =
      Store.list_resources()
      |> Enum.map(&generate_abstract/1)
      |> Enum.sort_by(& &1.relevance_score, :desc)
      |> take_within_budget(@l0_budget)

    Cache.put(:l0, agent_id, abstracts, ttl: :session)
    abstracts
  end

  defp take_within_budget(items, budget) do
    Enum.reduce_while(items, {[], 0}, fn item, {acc, tokens} ->
      item_tokens = estimate_tokens(item)
      if tokens + item_tokens <= budget do
        {:cont, {[item | acc], tokens + item_tokens}}
      else
        {:halt, {acc, tokens}}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end
end
```

### L0 Cache Strategy

```
ETS Table: :l0_cache
  Key: {agent_id}
  Value: %{abstracts: [...], loaded_at: timestamp, token_count: int}
  TTL: Session lifetime (cleared on session end)
  Invalidation: On resource update, regenerate affected abstract
```

L0 is cached in ETS for sub-millisecond access. When a resource is updated,
only its abstract is regenerated — not the entire L0 set.

---

## L1: On-Demand Summaries

L1 provides structured overviews when the agent needs more than an abstract but
less than the full document. Loaded when topic relevance is detected.

### What L1 Contains

```yaml
l1_example:
  resource_id: "res_01HQ..."
  title: "AI Masters Pricing Strategy"
  token_count: 1847
  summary: |
    ## Current State
    The course partner proposed $2K/seat for the advanced course. The owner countered
    at $1.5K citing the Wyatt/Carson simplicity principle — price should not
    create a decision barrier for the target audience.

    ## Key Facts
    - Beginner course: $497 (confirmed)
    - Advanced course: $1.5K-$2K (under negotiation)
    - Revenue target: $500K in first 6 months
    - Robert Potter handling sales, needs briefs not specs
    - 3-cohort model: Jan, Apr, Jul

    ## Decisions Made
    - 2026-03-12: Beginner pricing locked at $497
    - 2026-03-15: Advanced pricing narrowed to $1.5K-$2K range

    ## Open Questions
    - Final advanced pricing (partner vs owner position)
    - Bundle discount for beginner+advanced
    - Enterprise licensing for teams >10
```

### L1 Loading Triggers

L1 loads automatically when any of these conditions are met:

| Trigger | Detection Method | Example |
|---------|-----------------|---------|
| Query match | Search returns resource in top 5 | User asks about "pricing" |
| Entity mention | Named entity in user input matches resource | User mentions "Ed Honour" |
| Task context | Task metadata references the resource | Task assigned to ai-masters node |
| Agent request | Agent explicitly requests L1 via tool call | `load_context("res_01HQ...", :l1)` |
| Cross-reference | Currently loaded L1 references another resource | Pricing doc links to revenue model |

### L1 Budget Management

```elixir
defmodule TieredLoader.L1 do
  @l1_budget 50_000  # tokens per task
  @l1_ttl :timer.minutes(10)

  def load_l1(resource_id, task_context) do
    current_usage = Cache.get_usage(:l1, task_context.task_id)

    if current_usage + resource.token_count > @l1_budget do
      # Evict least-recently-used L1 to make room
      evict_lru(:l1, task_context.task_id)
    end

    l1_content = generate_l1(resource_id)
    Cache.put(:l1, {task_context.task_id, resource_id}, l1_content, ttl: @l1_ttl)
    l1_content
  end

  defp generate_l1(resource_id) do
    resource = Store.get(resource_id)
    %{
      resource_id: resource_id,
      title: resource.title,
      summary: Summarizer.structured_summary(resource.content, target: 2000),
      key_facts: Extractor.facts(resource.content),
      decisions: Extractor.decisions(resource.content),
      open_questions: Extractor.questions(resource.content),
      token_count: estimate_tokens(resource.content)
    }
  end
end
```

### L1 Cache Strategy

```
ETS Table: :l1_cache
  Key: {task_id, resource_id}
  Value: %{content: ..., loaded_at: timestamp, token_count: int}
  TTL: 10 minutes (task-scoped)
  Eviction: LRU when budget exceeded
  Invalidation: On resource update OR task switch
```

---

## L2: Full Content

L2 is the complete, uncompressed content. Loaded only when the agent needs to
work directly with the full text — editing, deep analysis, or content generation.

### When to Load L2

```
LOAD L2 WHEN:
  ✓ Agent needs to edit the document
  ✓ Agent needs exact quotes or specific details
  ✓ L1 summary is insufficient for the task
  ✓ Agent explicitly requests full content
  ✓ Document is the PRIMARY input for current task

DO NOT LOAD L2 WHEN:
  ✗ L0 abstract answers the question
  ✗ L1 summary provides enough context
  ✗ Document is background reference only
  ✗ Token budget would be exceeded
```

### L2 Budget Enforcement

```elixir
defmodule TieredLoader.L2 do
  @l2_budget 100_000  # tokens per session
  @l2_warning 80_000  # warn at 80%

  def load_l2(resource_id, session) do
    resource = Store.get(resource_id)
    current_usage = Session.l2_usage(session.id)

    cond do
      current_usage + resource.token_count > @l2_budget ->
        {:error, :budget_exceeded,
         "L2 budget would be exceeded (#{current_usage}/#{@l2_budget}). " <>
         "Consider using L1 summary instead."}

      current_usage + resource.token_count > @l2_warning ->
        {:warn, resource.content,
         "L2 usage at #{current_usage + resource.token_count}/#{@l2_budget}. " <>
         "#{@l2_budget - current_usage - resource.token_count} tokens remaining."}

      true ->
        Session.record_l2_load(session.id, resource_id, resource.token_count)
        {:ok, resource.content}
    end
  end
end
```

### L2 Is Not Cached

Full content is too large to cache in ETS. L2 loads come directly from storage
(SQLite, filesystem, or PostgreSQL). This is acceptable because L2 loads are
infrequent — typically 2-5 per task.

---

## Token Budget Summary

| Tier | Per-Item | Per-Task/Session | Cache | Eviction |
|------|----------|-----------------|-------|----------|
| L0 | ~100 tokens | 5K-15K total | ETS, session TTL | None (always loaded) |
| L1 | ~2K tokens | 20K-50K per task | ETS, 10 min TTL | LRU on budget exceed |
| L2 | Full size | 100K per session | None | N/A (not cached) |

### Budget Allocation by Agent Type

Different agents need different budget distributions:

```yaml
budget_profiles:
  researcher:
    l0: 15000
    l1: 50000
    l2: 150000    # Researchers need deep access

  operator:
    l0: 10000
    l1: 30000
    l2: 50000     # Operators rarely need full docs

  writer:
    l0: 10000
    l1: 40000
    l2: 100000    # Writers need source material

  executor:
    l0: 5000
    l1: 20000
    l2: 30000     # Executors work from instructions
```

---

## Loading Protocol

The full loading sequence during a heartbeat cycle:

```
Agent wakes up (heartbeat step 4: session restore)
  │
  ▼
1. Load L0 from ETS cache (or generate if cold start)
   ├── System identity
   ├── Agent definition
   ├── Knowledge abstracts (sorted by relevance)
   └── People index
  │
  ▼
2. Receive task assignment
   ├── Parse task description for entities and topics
   └── Identify relevant resources from L0 abstracts
  │
  ▼
3. Auto-load L1 for relevant resources
   ├── Top 3-5 resources by relevance score
   ├── Resources referenced in task metadata
   └── Cross-referenced resources (1 hop)
  │
  ▼
4. Agent begins execution
   ├── May request additional L1 loads via tool calls
   ├── May request L2 for deep-dive resources
   └── Budget enforced at each load request
  │
  ▼
5. Task complete → L1 cache entries decay (10 min TTL)
   └── L0 persists for next task
```

---

## Relevance Scoring

Resources compete for L0/L1 slots. The relevance scorer determines priority:

```elixir
defmodule TieredLoader.Relevance do
  def score(resource, context) do
    recency = recency_score(resource.updated_at)        # 0-1, exponential decay
    frequency = frequency_score(resource.access_count)    # 0-1, logarithmic
    task_match = task_relevance(resource, context.task)   # 0-1, keyword + entity overlap
    entity_match = entity_overlap(resource, context.input) # 0-1, named entity match

    # Weighted combination
    recency * 0.2 + frequency * 0.2 + task_match * 0.4 + entity_match * 0.2
  end

  defp recency_score(updated_at) do
    days = DateTime.diff(DateTime.utc_now(), updated_at, :day)
    :math.exp(-0.05 * days)  # Half-life ~14 days
  end

  defp frequency_score(count) do
    :math.log(count + 1) / :math.log(100)  # Normalized to 100 accesses
    |> min(1.0)
  end
end
```

---

## Relationship to Other Architecture Files

| File | How It Uses Tiered Loading |
|------|--------------------------|
| `basement.md` | Provides the resource envelope with `tier` field |
| `heartbeat.md` | Step 4 (session restore) triggers L0 load |
| `memory-architecture.md` | Memory layers map to tiers (working=L0, semantic=L1, episodic=L2) |
| `proactive-agents.md` | Proactive agents use L0 to detect staleness and quality drops |
| `signal-integration.md` | S/N scoring uses tier-appropriate content depth |
| `sessions.md` | Session state tracks which L1/L2 resources are loaded |

---

*Tiered Loading v1.0 — Context management for OSA Operations*
