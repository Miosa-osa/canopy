// src/lib/api/mock/library/local-skills.ts
// Bundled skill registry generated from library/skills/**/SKILL.md.

import type { Skill } from "../../types";

export const LOCAL_SKILLS: Skill[] = [
  {
    "id": "agent--create-agent",
    "name": "create-agent",
    "description": "Bundled Agent skill from library/skills/agent/create-agent/SKILL.md.",
    "category": "agent",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/create-agent",
      "create-agent"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "agent--create-operation",
    "name": "create-operation",
    "description": "Bundled Agent skill from library/skills/agent/create-operation/SKILL.md.",
    "category": "agent",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/create-operation",
      "create-operation"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "agent--list-operations",
    "name": "list-operations",
    "description": "Bundled Agent skill from library/skills/agent/list-operations/SKILL.md.",
    "category": "agent",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/list-operations",
      "list-operations"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "agent--validate",
    "name": "validate",
    "description": "Bundled Agent skill from library/skills/agent/validate/SKILL.md.",
    "category": "agent",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/validate",
      "validate"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "ai-patterns--eval-rag",
    "name": "eval-rag",
    "description": "> Evaluate retrieval and generation quality in RAG pipelines. Separate scoring for retrieval (recall, precision, MRR) and generation (faithfulness, relevance, completeness). End-to-end pipeline assessment with bottleneck identification. Triggers on: \"eval rag\", \"rag evaluation\", \"retrieval evaluation\", \"rag quality\", \"rag metrics\"",
    "category": "ai-patterns",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/eval-rag",
      "eval-rag"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "ai-patterns--judge-prompt",
    "name": "judge-prompt",
    "description": "> Design binary pass/fail LLM-as-Judge evaluators. Structured prompt engineering for evaluation: criteria definition, rubric construction, few-shot calibration, and bias mitigation. Produces a ready-to-deploy judge prompt with scoring instructions. Triggers on: \"judge prompt\", \"llm judge\", \"evaluator prompt\", \"scoring prompt\", \"grading rubric\"",
    "category": "ai-patterns",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/judge-prompt",
      "judge-prompt"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "ai-patterns--lats",
    "name": "lats",
    "description": "Language Agent Tree Search - Monte Carlo planning - 92.7% on HumanEval",
    "category": "ai-patterns",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/lats",
      "lats",
      "complex planning, code generation, decision-making under uncertainty"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "ai-patterns--learning-engine",
    "name": "learning-engine",
    "description": "Self-learning system based on SICA, VIGIL, and Mem0 patterns. Auto-triggers after task completion. Captures patterns, consolidates memory, generates skills, recovers from errors.",
    "category": "ai-patterns",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/learning-engine",
      "learning-engine"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "ai-patterns--meta-prompting",
    "name": "meta-prompting",
    "description": "Self-improving prompts through meta-level optimization",
    "category": "ai-patterns",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/meta-prompting",
      "meta-prompting",
      "keyword"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "ai-patterns--prompt-cache-optimizer",
    "name": "prompt-cache-optimizer",
    "description": "Optimize token usage through prompt caching and compression",
    "category": "ai-patterns",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/prompt-cache-optimizer",
      "prompt-cache-optimizer",
      "auto"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "ai-patterns--react-pattern",
    "name": "react-pattern",
    "description": "Thought-Action-Observation loop for transparent reasoning",
    "category": "ai-patterns",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/react-pattern",
      "react-pattern"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "ai-patterns--reflection",
    "name": "reflection-loop",
    "description": "Self-correction via critique loop - 18.5 percentage point improvement",
    "category": "ai-patterns",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/reflection-loop",
      "reflection-loop"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "ai-patterns--self-consistency",
    "name": "self-consistency",
    "description": "Sample multiple paths, select most consistent - +17.9% on GSM8K",
    "category": "ai-patterns",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/self-consistency",
      "self-consistency",
      "math, logic puzzles, fact-based reasoning, high-stakes decisions"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "ai-patterns--skeleton-of-thought",
    "name": "skeleton-of-thought",
    "description": "Parallel generation through skeleton-first approach for 2x speedup",
    "category": "ai-patterns",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/skeleton-of-thought",
      "skeleton-of-thought",
      "keyword"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "ai-patterns--synthetic-data",
    "name": "synthetic-data",
    "description": "> Generate diverse synthetic test inputs via dimension-based tuple generation. Defines variation dimensions, enumerates combinations, filters for relevance, and produces labeled test cases. For LLM eval pipelines, training data augmentation, and stress testing. Triggers on: \"synthetic data\", \"generate test data\", \"test inputs\", \"data generation\", \"augment data\"",
    "category": "ai-patterns",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/synthetic-data",
      "synthetic-data"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "ai-patterns--tree-of-thoughts",
    "name": "tree-of-thoughts",
    "description": "Multi-path reasoning with evaluation and backtracking - 74% success on complex tasks",
    "category": "ai-patterns",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/tree-of-thoughts",
      "tree-of-thoughts",
      "complex reasoning, planning, multi-step problems"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "ai-patterns--validate-evaluator",
    "name": "validate-evaluator",
    "description": "> Calibrate LLM-as-Judge evaluators against human labels. Computes TPR, TNR, precision, recall, F1, and Cohen's kappa. Detects systematic biases and recommends prompt corrections. Produces a calibration report with confidence intervals. Triggers on: \"validate evaluator\", \"calibrate judge\", \"judge accuracy\", \"evaluator validation\", \"judge metrics\"",
    "category": "ai-patterns",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/validate-evaluator",
      "validate-evaluator"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "analysis--audit",
    "name": "audit",
    "description": "> Multi-domain audit with weighted scoring. Spawns parallel subagents per audit domain. Each check has severity weight and category weight. Produces a quantified health score (0-100) with prioritized findings. Supports security, code quality, performance, compliance, and custom domains. Triggers on: \"audit\", \"assess\", \"evaluate quality\", \"score\"",
    "category": "analysis",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/audit",
      "audit"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "analysis--error-analysis",
    "name": "error-analysis",
    "description": "> Guided analysis of LLM traces to categorize and pattern-match failures. Reads execution traces, classifies failure modes, detects recurring patterns, and produces actionable taxonomy of errors. For diagnosing why an LLM system fails and where to focus improvement effort. Triggers on: \"error analysis\", \"analyze failures\", \"failure patterns\", \"trace analysis\", \"debug eval\"",
    "category": "analysis",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/error-analysis",
      "error-analysis"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "analysis--eval-audit",
    "name": "eval-audit",
    "description": "> Audit an LLM evaluation pipeline for correctness, coverage, and reliability. 6 diagnostic areas with structured Check/Finding output. Produces prioritized findings by severity and recommends next skills to run. Catches common eval pitfalls before they corrupt your metrics. Triggers on: \"eval audit\", \"audit evals\", \"evaluation audit\", \"check eval pipeline\", \"eval health\"",
    "category": "analysis",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/eval-audit",
      "eval-audit"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "analysis--graph",
    "name": "graph",
    "description": "> 9 graph analysis operations for knowledge networks: triangles (synthesis opportunities), bridges (critical connectors), clusters (isolated subgraphs), hubs (high-degree nodes), siblings (unconnected items sharing topics), forward/backward traversal, orphans, and staleness scan. The analytical lens on your knowledge structure. Triggers on: \"graph\", \"connections\", \"network analysis\", \"knowledge map\"",
    "category": "analysis",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/graph",
      "graph"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "analysis--health",
    "name": "health",
    "description": "> Workspace health diagnostics. Runs targeted checks against the knowledge base: orphaned content, stale signals, missing cross-references, index drift, duplicate detection, broken references, embedding coverage, and quality distribution. Color-coded severity output. Triggers on: \"health\", \"diagnose\", \"check health\", \"knowledge base status\"",
    "category": "analysis",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/health",
      "health"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "analysis--stats",
    "name": "stats",
    "description": "> Workspace metrics dashboard. Tracks growth rate, connection density, pipeline throughput, health score trends, budget consumption, and agent utilization over time. Includes trend detection for spotting degradation or acceleration. Triggers on: \"stats\", \"metrics\", \"dashboard\", \"workspace numbers\"",
    "category": "analysis",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/stats",
      "stats"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "content--edit",
    "name": "edit",
    "description": "Bundled Content skill from library/skills/content/edit/SKILL.md.",
    "category": "content",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/edit",
      "edit"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "content--slides",
    "name": "slides",
    "description": "> Create animation-rich HTML presentations from scratch or convert PowerPoint. Progressive disclosure pipeline: content discovery, style discovery, generation. Zero-dependency single HTML file output. Anti-AI-slop guardrails for natural, professional presentations. Triggers on: \"slides\", \"presentation\", \"slide deck\", \"create slides\", \"convert pptx\", \"html presentation\"",
    "category": "content",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/slides",
      "slides"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "content--summarize",
    "name": "summarize",
    "description": "Bundled Content skill from library/skills/content/summarize/SKILL.md.",
    "category": "content",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/summarize",
      "summarize"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "content--translate",
    "name": "translate",
    "description": "Bundled Content skill from library/skills/content/translate/SKILL.md.",
    "category": "content",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/translate",
      "translate"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "content--write",
    "name": "write",
    "description": "Bundled Content skill from library/skills/content/write/SKILL.md.",
    "category": "content",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/write",
      "write"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "coordination--board",
    "name": "board",
    "description": "> Visual task management dashboard. Terminal-based kanban board, tiled agent status view, and progress tracking. Shows all agents, their current tasks, budget consumption, and overall workspace health at a glance. Triggers on: \"board\", \"dashboard\", \"kanban\", \"status board\", \"show agents\"",
    "category": "coordination",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/board",
      "board"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "coordination--checkout",
    "name": "checkout",
    "description": "> Atomic task locking. Ensures only one agent works on a task at a time. Returns 409 Conflict if already locked. Auto-releases on agent death or timeout. Prevents double-work and wasted compute in multi-agent systems. Triggers on: \"checkout\", \"lock task\", \"claim task\", \"reserve\"",
    "category": "coordination",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/checkout",
      "checkout"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "coordination--delegate",
    "name": "delegate",
    "description": "> Assign work to a specific workspace agent or external runtime. Picks the right adapter (Claude for reasoning, Codex for bulk changes, Gemini for multimodal). Creates tasks with parent chain tracking for full delegation lineage. Triggers on: \"delegate\", \"assign\", \"hand off\", \"send to agent\"",
    "category": "coordination",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/delegate",
      "delegate"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "coordination--heartbeat",
    "name": "heartbeat",
    "description": "> Agent wake-up and health monitoring protocol. 9-step startup cycle that grounds the agent in identity, fetches tasks, selects work, and begins execution. Also serves as a periodic health check - detect stalled or dead agents. Scheduled or event-triggered. Triggers on: \"heartbeat\", \"wake up\", \"agent health\", \"check agents\"",
    "category": "coordination",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/heartbeat",
      "heartbeat"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "coordination--inbox",
    "name": "inbox",
    "description": "> Point-to-point messaging between agents. Send, broadcast, receive, and peek at messages. File-based implementation using JSON in inbox directories with atomic writes. Includes event log for full message history. The communication backbone. Triggers on: \"inbox\", \"message\", \"send to\", \"broadcast\", \"check messages\"",
    "category": "coordination",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/inbox",
      "inbox"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "coordination--pay",
    "name": "pay",
    "description": "Authorize agent payments via Machine Payments Protocol (MPP). Handles microtransactions, API purchases, service subscriptions within budget governance. Triggered by pay, purchase, buy, transaction, payment, MPP, commerce.",
    "category": "coordination",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/pay",
      "pay"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "coordination--spawn",
    "name": "spawn",
    "description": "> Launch a specialized agent for a subtask. Assigns identity, workspace scope, available commands, and communication protocol. Supports tmux-based (visual) or subprocess (headless) execution backends. The primary way to parallelize work. Triggers on: \"spawn\", \"launch agent\", \"start worker\", \"parallelize\"",
    "category": "coordination",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/spawn",
      "spawn"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "development--autoresearch",
    "name": "autoresearch",
    "description": "> Autonomous iterative improvement loop. Agent modifies code, verifies against metrics, keeps improvements or reverts failures, and repeats. Uses git as memory - each change is committed, measured, and kept or discarded. Runs until a target metric is hit or max iterations reached. Triggers on: \"autoresearch\", \"auto improve\", \"iterative improvement\", \"autonomous loop\", \"hill climb\"",
    "category": "development",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/autoresearch",
      "autoresearch"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "development--cli-anything",
    "name": "cli-anything",
    "description": "> Transform any GUI application into an agent-controllable CLI. 7-phase pipeline: analyze the GUI, design CLI commands, implement adapters, plan tests, write tests, document, and publish. Produces a standalone CLI tool that wraps GUI functionality for automation. Triggers on: \"cli anything\", \"gui to cli\", \"make cli\", \"wrap gui\", \"automate application\"",
    "category": "development",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/cli-anything",
      "cli-anything"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "development--code-review",
    "name": "code-review",
    "description": "> Branch code review with structured scoring against project guidelines. Produces categorized findings with severity levels and LLM-generated fix prompts. Quality gate: only posts review to PR if score meets threshold. Triggers on: \"code review\", \"review branch\", \"review PR\", \"review changes\", \"score code\"",
    "category": "development",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/code-review",
      "code-review"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "development--commit",
    "name": "commit",
    "description": "Bundled Development skill from library/skills/development/commit/SKILL.md.",
    "category": "development",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/commit",
      "commit"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "development--create-pr",
    "name": "create-pr",
    "description": "Bundled Development skill from library/skills/development/create-pr/SKILL.md.",
    "category": "development",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/create-pr",
      "create-pr"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "development--create-spec",
    "name": "create-spec",
    "description": "> Guided spec creation through 9 phases from discovery to testing strategy. Supports spec types: library, feature, change. Produces a complete specification document with requirements, architecture, constraints, and YAML test data. Interactive or autonomous modes. Triggers on: \"create spec\", \"write spec\", \"spec out\", \"specification\", \"design document\"",
    "category": "development",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/create-spec",
      "create-spec"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "development--debug",
    "name": "debug",
    "description": "Bundled Development skill from library/skills/development/debug/SKILL.md.",
    "category": "development",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/debug",
      "debug"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "development--deploy",
    "name": "deploy",
    "description": "Bundled Development skill from library/skills/development/deploy/SKILL.md.",
    "category": "development",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/deploy",
      "deploy"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "development--lint",
    "name": "lint",
    "description": "Bundled Development skill from library/skills/development/lint/SKILL.md.",
    "category": "development",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/lint",
      "lint"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "development--refactor",
    "name": "refactor",
    "description": "Bundled Development skill from library/skills/development/refactor/SKILL.md.",
    "category": "development",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/refactor",
      "refactor"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "development--review",
    "name": "review",
    "description": "Bundled Development skill from library/skills/development/review/SKILL.md.",
    "category": "development",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/review",
      "review"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "development--tdd",
    "name": "tdd-enforcer",
    "description": "Enforces Test-Driven Development discipline with RED-GREEN-REFACTOR cycle",
    "category": "development",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/tdd-enforcer",
      "tdd-enforcer"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "development--test",
    "name": "test",
    "description": "Bundled Development skill from library/skills/development/test/SKILL.md.",
    "category": "development",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/test",
      "test"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "governance--approve",
    "name": "approve",
    "description": "> Human-in-the-loop approval gates. Creates approval requests for high-stakes actions like hiring agents, strategy proposals, or budget overrides. Tracks states from pending through approved/rejected/revision_requested. Blocks execution until resolved. Triggers on: \"approve\", \"approval\", \"review request\", \"sign off\"",
    "category": "governance",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/approve",
      "approve"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "governance--budget",
    "name": "budget",
    "description": "> 3-tier budget enforcement for AI agent workspaces. Visibility dashboards (always on), soft alerts at 80% threshold, hard ceilings at 100% that auto-pause agents. Tracks per-agent, per-task, and per-project costs in both tokens and dollars. Triggers on: \"budget\", \"cost\", \"spending\", \"token usage\", \"billing\"",
    "category": "governance",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/budget",
      "budget"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "governance--hire",
    "name": "hire",
    "description": "> Add an agent to a workspace from the agent library. Proposes agent configuration including name, role, capabilities, adapter, and budget. Requires board approval via /approve before onboarding. Completes with identity setup and coordination prompt. Triggers on: \"hire\", \"add agent\", \"onboard agent\", \"recruit\"",
    "category": "governance",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/hire",
      "hire"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--ad-creative",
    "name": "ad-creative",
    "description": "Produce paid ad creative briefs + copy variants across 8 ad types (Profile Funnel / Retargeting / Video Hook / Video Story / Testimonial / Image / Carousel / UGC). the paid media director depth. Voice-matched. Compliance-checked. Ships ready for Meta Ads Library ready or direct API upload.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/ad-creative",
      "ad-creative"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--affiliate-program",
    "name": "affiliate-program",
    "description": "Design affiliate program structure - commission rates + payout logic + affiliate portal + promotion assets + recruitment outreach + compliance. Built for Stripe / ThriveCart / FirstPromoter / Everflow integrations.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/affiliate-program",
      "affiliate-program"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--application-form",
    "name": "application-form",
    "description": "Produce a high-ticket qualifying application form - 8-12 questions calibrated for show-rate + close-rate + refund-prevention. Offers 3 archetypes (high-barrier for founder calls / medium for setter screen / low for flywheel) with disqualification logic. Filters out tire-kickers before they consume closer time AND captures the prospect-specific signal that feeds /call-prep. Consumes ICP Section 10 + Offer Doc + Funnel Archetype decision (application funnel #3 or book-a-call funnel #4). External-tier format. Ships as structured question schema + form-builder copy.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/application-form",
      "application-form"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--build-funnel",
    "name": "build-funnel",
    "description": "Design a complete funnel architecture using one of 7 archetypes (VSL Funnel / Webinar / Application / Book-a-Call / Tripwire / Challenge / Community Lead Magnet). Consumes Offer Document + VSL Script + ICP. Produces funnel blueprint with stage-by-stage conversion metrics, tracking, and dependencies. Second Cycle 2 skill.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/build-funnel",
      "build-funnel"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--build-icp",
    "name": "build-icp",
    "description": "Build a complete Ideal Customer Profile Document (13 sections) with Completeness Score >= 80. Populates Compartment 2 (Audience Intelligence System) to at least 70%. Second skill in the Foundations chain - consumes Market Research Brief, produces ICP Document. Every downstream marketing, sales, and copy asset inherits from this output.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/build-icp",
      "build-icp"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--build-positioning",
    "name": "build-positioning",
    "description": "Build a Positioning Document - Vehicle Switch, Unique Mechanism, Core Belief Statement, Narrative Architecture, Market Sophistication match. Sits between /build-icp and /design-offer. Consumes ICP + Market Research Brief. Output becomes the messaging spine for every downstream copy asset.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/build-positioning",
      "build-positioning"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--build-sop",
    "name": "build-sop",
    "description": "Produce a Standard Operating Procedure for a role or process (14 variants - 8 roles: Setter/Closer/SDR/Content-Mgr/Video-Editor/CS/VA/Marketing-Mgr + 6 processes: Sales/Content/Onboarding/Lead-Mgmt/QA/Reporting). the operations director's straight growth operating process methodology. Produces SOP + KPIs + quality gates + escalation rules + training plan.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/build-sop",
      "build-sop"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--build-vsl",
    "name": "build-vsl",
    "description": "Produce a Video Sales Letter script using one of 5 framework variants (15-step / pull-push-persuade 11-step pull-push-persuade / 13-step VSL slides / three-phase VSL formula / hidden-pitch long-form video). Consumes Offer Document + Positioning + ICP + Brand Voice. Cycle 2 Sales hero skill. Gate-blocked below Offer 70% + Audience 60%. Sacred format - requires 3/3 Blind Output Test pass before paid traffic.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/build-vsl",
      "build-vsl"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--call-prep",
    "name": "call-prep",
    "description": "Produce a 1-page pre-call brief for every high-ticket discovery call - prospect-specific hooks, pain anchors, identity match, decision-style flag, objection pre-empts, and tension-setting cues. Runs a 15-minute pre-call routine that converts application form data + ICP archetype match + offer context into a scannable single-page brief the closer reads 5 min before dialing. Consumes application-form output + ICP + Offer Doc + Objection Library + (optionally) prior CRM notes. External-tier format - closer briefs ship same-day, no Blind Output Test (internal operational asset).",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/call-prep",
      "call-prep"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--case-study",
    "name": "case-study",
    "description": "Convert a client win into a publishable case study per the Growth Operating Agency 6-Level Social Proof Hierarchy + the offer architect Isomorphic Story principle. Produces one full written case study (800-1500 words), one VSL insert (60-90s), one ad variant (30s), one LinkedIn post, one X thread, one email broadcast, plus FTC disclosure and client-approval record. Target output: Level 5 or Level 6 proof only. Lower-level testimonials are routed to aggregate-proof channels, not hero case studies.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/case-study",
      "case-study"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--competitor-intel",
    "name": "competitor-intel",
    "description": "Produce a competitor teardown and positioning-whitespace analysis for a creator's high-ticket offer. Covers a 3-tier matrix (direct / adjacent / alternative), a 10-dimension per-competitor teardown, a cross-competitor pattern synthesis, and a prioritized whitespace map that feeds /build-positioning. This is the diagnostic skill that turns a blank-market brief into a specific, differentiated angle.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/competitor-intel",
      "competitor-intel"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--content-calendar",
    "name": "content-calendar",
    "description": "Build a 30-day content calendar across platforms using 40/30/20/10 pillar ratio + Core Four channel mix + platform-specific cadence. Plans the organic attention layer that complements paid (/ad-creative). Consumes ICP + Positioning + Offer + Brand Voice. Output is a dated calendar + per-post briefs routed to /write-reel, /write-youtube, /write-linkedin-post, /write-x-thread, /story-sequence.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/content-calendar",
      "content-calendar"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--design-offer",
    "name": "design-offer",
    "description": "Design a high-ticket offer using the 7-step Offer Architecture (7-phase offer methodology) + Value Equation (acquisition-economics methodology) + 4-Layer Belief Stack + 3:1 LTV:CAC economics validation. Produces a 12-section Offer Document. Third skill in Foundations chain - consumes ICP + Positioning. Gate-blocked below Audience 70%. The hero Cycle 1 demo.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/design-offer",
      "design-offer"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--diagnose-conversion-gap",
    "name": "diagnose-conversion-gap",
    "description": "Funnel teardown from past-launch data. Ingests stage-by-stage metrics (ads -> opt-ins -> apps -> booked -> showed -> closed -> cash), surfaces the biggest $ leaks, triangulates root cause via 40/40/20 Audience/Offer/Copy framework, outputs ranked fix list with $-impact estimates and recommended next-skill. Runnable on any creator with funnel history. Used as the first-pass diagnostic on every new client before any asset work begins.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/diagnose-conversion-gap",
      "diagnose-conversion-gap"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--email-sequence",
    "name": "email-sequence",
    "description": "Produce email sequences in 8 types (Welcome / Nurture / Launch / Webinar / Re-engagement / Application / Post-Purchase / Single Broadcast). Voice-matched. Conversion-staged. Consumes ICP + Offer + Brand Voice. Built for ConvertKit / ActiveCampaign / Beehiiv / GoHighLevel.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/email-sequence",
      "email-sequence"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--extract-voice",
    "name": "extract-voice",
    "description": "Extract the creator's Brand Voice Architecture from their existing content + interviews. Produces Brand Voice Document with 10 components (communication style, tone framework, personality traits, language patterns, phrases_to_use, phrases_to_avoid, persuasion style, authority positioning, contrarian beliefs, voice examples). Populates Compartment 1.brand_voice_architecture. Runs in parallel with /build-positioning.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/extract-voice",
      "extract-voice"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--hiring-brief",
    "name": "hiring-brief",
    "description": "Produce hiring brief for one of 8 roles (Setter / Closer / SDR / Content Manager / Video Editor / Customer Success / VA / Marketing Manager). Scorecard + ideal profile + outreach script + interview questions + 30/60/90-day plan. Revenue-threshold-aware (per the VSL director team model).",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/hiring-brief",
      "hiring-brief"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--ig-stories-drop",
    "name": "ig-stories-drop",
    "description": "17-day Instagram Stories launch cycle (Whisper -> Tease -> Shout). Produces daily story calendar (4 frames/day), poll prompts, DM keyword auto-replies, freebie lead-capture spec, Typeform application copy, pixelled funnel-page wireframe, 48-72h scarcity close cadence, email+SMS pairing, KPI benchmarks. For Instagram-native creators whose content is curiosity/opinion-driven (not community-pitch). Based on the documented IG Stories Launch System.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/ig-stories-drop",
      "ig-stories-drop"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--jv-webinar-proposal",
    "name": "jv-webinar-proposal",
    "description": "Produce a JV partner outreach package + webinar proposal. Identifies aligned partners from the creator's adjacent tier, drafts personalized outreach, structures revenue split + logistics + co-created content, and models expected economics per partner. Treats the outreach as a full-stack sales call on paper - same 8-stage discipline, same belief-install logic, same decision-lock at close. Output feeds directly into `/webinar-script` for the event itself and `/email-sequence` for post-event follow-up.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/jv-webinar-proposal",
      "jv-webinar-proposal"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--landing-page",
    "name": "landing-page",
    "description": "Produce the 4-page landing-page stack for any funnel archetype - opt-in page, offer page, thank-you page, checkout page - with 4 copy variants per page (hooks + CTA + proof stack). Mobile-first structure. Follows research-mechanism-brief-copy methodology (7-section outline - Lead / Background Story / Problem Mechanism / Solution Mechanism / Product Reveal / Close / FAQ). Consumes Offer Doc + Positioning + ICP + Brand Voice + Funnel Archetype + (if exists) VSL + Tripwire Design. Sacred format - 3/3 Blind Output Test required before paid traffic.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/landing-page",
      "landing-page"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--launch-report",
    "name": "launch-report",
    "description": "Post-launch debrief and optimization recommendations. Consumes the /plan-launch runbook plus actual performance data (analytics, CRM, payments, call recordings). Computes plan-vs-actual variance per KPI, diagnoses which of the 5 launch phases leaked using the the operations director 8-stage customer-journey audit, attributes revenue against the 60/30/10 channel mix, separates offer-vs-copy-vs-audience causality, and produces a next-launch playbook plus a fix-path task list with owners and deadlines. The Cycle 6 Deploy closing skill - every launch ends with this document or it is not closed. Gate-blocked until all 5 phases of /plan-launch have shipped and cart has closed.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/launch-report",
      "launch-report"
    ],
    "version": "2.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--lead-magnet",
    "name": "lead-magnet",
    "description": "Design a lead magnet in one of 9 types (PDF Guide / Checklist / Cheat Sheet / Swipe File / Mini Course / Quiz-Assessment / Calculator-Tool / Free Training / Custom). the acquisition economist a lead-generation canon methodology. Produces asset brief + opt-in copy + delivery flow. Opt-in rate target 30%+ on warm traffic.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/lead-magnet",
      "lead-magnet"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--objection-library",
    "name": "objection-library",
    "description": "Produce a complete encoded objection-handling library for a high-ticket offer - 20+ objections across 6 categories (money / timing / trust / spouse-partner / format / past-failure) with 3-layer reframes (cognitive / emotional / behavioral), proof stack per objection, and role-play escalation scripts. Consumes ICP Section 10 + Offer Doc + Brand Voice + Case Study database. Feeds /sales-script inline objection block, /call-prep objection pre-empts, and /proposal FAQ. Sacred format for closer discipline - library must pass 20/20 closer role-play coverage before ship.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/objection-library",
      "objection-library"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--plan-launch",
    "name": "plan-launch",
    "description": "Plan a high-ticket launch in one of 5 variants (Live / Evergreen / Rolling / Flash / Beta) using the Growth Operating Agency 5-Phase Launch SOP layered over the operations director 7-Step rollout with the growth strategist Whisper/Tease/Shout cadence. Orchestrates every upstream asset (Offer Doc, VSL, Funnel, Email Sequence, Ad Creative, Post-Booking Nurture) into a dated launch runbook with hour-level tasks, owner assignments, KPI targets, asset dependency gates, and a mandatory tech checklist. Gate-blocked below Offer 70% + Audience 60% + Funnel 60%. The Cycle 6 Deploy hero skill. Sacred runbook - cart-close deadline is immutable per launch-pipeline FSM.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/plan-launch",
      "plan-launch"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--post-booking-nurture",
    "name": "post-booking-nurture",
    "description": "Produce the the paid media director Show-Rate Stack - confirmation page + email cadence + SMS cadence + optional phone triage from call-booking to call-show. Targets 70%+ show-rate. Critical for Book-a-Call and Application Funnel archetypes (build-funnel types 3 + 4).",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/post-booking-nurture",
      "post-booking-nurture"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--proposal",
    "name": "proposal",
    "description": "Produce a 1-page after-call proposal / agreement summary for a high-ticket program ($3K-$50K). Covers scope, timeline, deliverables, payment terms, risk reversal, and next step. Not a formal contract - legal-templates skill handles signed agreements. This is the scannable \"yes-document\" the prospect reads, signs intent on, and returns to for reassurance during the commitment window. Consumes Offer Doc + Call Brief + Call Notes + Objection Library. External-tier format. Converts a verbal close into a documented commitment within 2 hours of the call.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/proposal",
      "proposal"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--referral-program",
    "name": "referral-program",
    "description": "Design customer-referral mechanics - reward structure, referral triggers, tracking, viral loop design. Distinct from affiliate program (customer-focused, not commercial partner).",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/referral-program",
      "referral-program"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--research",
    "name": "research",
    "description": "Conduct deep market + audience research for a creator's high-ticket offer. Produces a 9-section Market Research Brief and populates the first layers of Compartments 1 + 2 + 3 of the Creator Context Profile. This is the upstream-most skill - every downstream asset inherits from its output.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/research",
      "research"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--retention-check",
    "name": "retention-check",
    "description": "Score client health, detect churn risk, prescribe intervention actions. Produces per-client Health Score + portfolio dashboard + intervention playbook + save-vs-let-churn economics. Feeds /case-study when clients hit wins and /email-sequence when re-engagement sequences are required. Consumes Customer Success SOP + CRM data + NPS/CSAT signals + community engagement data. The Cycle 5 Scale retention-governance skill - retention is where the L in LTV is earned, not the P in CAC. Gate-blocked below Compartment 10 (Lifecycle) 40%.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/retention-check",
      "retention-check"
    ],
    "version": "2.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--revenue-report",
    "name": "revenue-report",
    "description": "Produce revenue analysis, forecasting, and unit-economics reports using the the backend economist 4-metric scorecard (RPL, cohort LTV, LTV:CAC by source, contribution margin per call) and the the operations director 60/30/10 revenue mix discipline. Produces weekly, monthly, and quarterly reports with cohort analysis, forecast, and variance-driven fix paths. This is the financial-truth skill - decisions made off this report get funded; everything else stays hypothesis.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/revenue-report",
      "revenue-report"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--sales-script",
    "name": "sales-script",
    "description": "Produce a complete high-ticket discovery-pitch-close script for application and book-a-call funnels (funnel archetypes 3 and 4). Covers 8-stage Full-Stack Sales Call, 12+ objection reframes inline, and 3 closing archetypes (assumptive / crossroads / takeaway). Works for setter+closer team architecture AND founder-led sales. Consumes Offer Doc + ICP + Brand Voice + (if exists) Objection Library. Sacred format for sales operations - requires 3/3 role-play pass before live calls.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/sales-script",
      "sales-script"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--show-rate-surgery",
    "name": "show-rate-surgery",
    "description": "Fix booked-to-show conversion on high-ticket sales funnels. Ingests current booking metrics (book-rate, show-rate, no-show %), diagnoses cause, outputs SMS/email reminder cadence + book-to-call window tightening + application-quality filter + optional deposit-at-booking mechanics. Target lift show rate to 70%+. Directly addresses the #1 conversion leak documented on most application-funnel creators.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/show-rate-surgery",
      "show-rate-surgery"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--story-sequence",
    "name": "story-sequence",
    "description": "Produce 7-day Instagram Story sequence using the stories director's 4-layer story anatomy + 7-day content calendar (Proof / Clarity / Objection Break / Education-Differentiation / Connection / Proof+Skepticism Removal / Mission). 2-4 stories per day. Text + image + proof-screenshots + visuals.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/story-sequence",
      "story-sequence"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--tripwire-design",
    "name": "tripwire-design",
    "description": "Design a $7-$97 entry offer (tripwire) for cold-traffic liquidation + list-builder + buying-habit-installer. 7 tripwire archetypes (free+shipping, low-ticket info, checklist+call, trial, consultation, live workshop, physical sample). Economics model covers payback-per-lead, breakeven CAC, mid-ticket + high-ticket ladder progression. Consumes ICP + Offer Doc + Funnel Archetype decision + ad economics. Sacred format for ascension funnels - 3/3 Blind Output Test on economics model before paid launch.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/tripwire-design",
      "tripwire-design"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--webinar-script",
    "name": "webinar-script",
    "description": "Produce a webinar script using the 7-Figure Webinar Script structure (Intro 15-30 min / Content 45-60 min / Transition / Pitch / Q&A 30+ min). Voice-matched. Objection-handled. Bonus-stacked. Crossroads close. 6 delivery variants (Live / Evergreen / 3-Day Challenge / 5-Day / 7-Day / Workshop).",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/webinar-script",
      "webinar-script"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--write-linkedin-post",
    "name": "write-linkedin-post",
    "description": "Produce a LinkedIn post promoting the creator's offer or mechanism. Scoped to Growth Operating Agency (operator posting about their own offer) - NOT full LinkedIn agency content (that's a separate workspace). Uses PIER / Hook-Loop-CTA / 30-50-20 pillar split. 3-4 posts/week cadence (not daily - Dec 2025 algo change).",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/write-linkedin-post",
      "write-linkedin-post"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--write-reel",
    "name": "write-reel",
    "description": "Produce short-form video script for IG Reel / TikTok / YouTube Shorts using one of 10 short-form frameworks (Speed Build / Money Reveal / Comparison / Weird Workflow / Transformation / Discovery / Teaching / Challenge / Story Time / Lifestyle). 60-second structure, second-by-second timing, voice-matched.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/write-reel",
      "write-reel"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--write-x-thread",
    "name": "write-x-thread",
    "description": "Produce X/Twitter thread in one of 7 thread types (Thread / Story Thread / Hot Take / How-To Thread / Listicle Thread / Case Study Thread / Daily Tweets batch). Specificity-first, open-curiosity-loop structure, final-tweet CTA. 2-3 threads per week.",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/write-x-thread",
      "write-x-thread"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "growth-operator-agency--write-youtube",
    "name": "write-youtube",
    "description": "Produce YouTube long-form video script in one of 7 video types (Educational Deep-Dive / VSSL / Lifestyle-Vlog / Tutorial / Case Study / Listicle / Reaction / Interview). Full MODULE 4 Script Architecture - content brief + script + title/thumbnail + binge loop. the content OS director platform-hierarchy default (YouTube-first for high-ticket).",
    "category": "growth-operator-agency",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/write-youtube",
      "write-youtube"
    ],
    "version": "1.0",
    "author": "Heuresis",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "knowledge--graph",
    "name": "graph",
    "description": "Bundled Knowledge skill from library/skills/knowledge/graph/SKILL.md.",
    "category": "knowledge",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/graph",
      "graph"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "knowledge--index",
    "name": "index",
    "description": "Bundled Knowledge skill from library/skills/knowledge/index/SKILL.md.",
    "category": "knowledge",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/index",
      "index"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "knowledge--ingest",
    "name": "ingest",
    "description": "Bundled Knowledge skill from library/skills/knowledge/ingest/SKILL.md.",
    "category": "knowledge",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/ingest",
      "ingest"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "knowledge--reflect",
    "name": "reflect",
    "description": "Bundled Knowledge skill from library/skills/knowledge/reflect/SKILL.md.",
    "category": "knowledge",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/reflect",
      "reflect"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "knowledge--remember",
    "name": "remember",
    "description": "Bundled Knowledge skill from library/skills/knowledge/remember/SKILL.md.",
    "category": "knowledge",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/remember",
      "remember"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "knowledge--rethink",
    "name": "rethink",
    "description": "Bundled Knowledge skill from library/skills/knowledge/rethink/SKILL.md.",
    "category": "knowledge",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/rethink",
      "rethink"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "knowledge--reweave",
    "name": "reweave",
    "description": "Bundled Knowledge skill from library/skills/knowledge/reweave/SKILL.md.",
    "category": "knowledge",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/reweave",
      "reweave"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "knowledge--verify",
    "name": "verify",
    "description": "Bundled Knowledge skill from library/skills/knowledge/verify/SKILL.md.",
    "category": "knowledge",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/verify",
      "verify"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "learning--learn",
    "name": "learn",
    "description": "> Research topics via web search, fetch content, and file to inbox with provenance metadata. The first step for acquiring external knowledge. Chains into /seed and /pipeline for full processing. Supports multiple search engines and content types. Triggers on: \"learn\", \"research\", \"look up\", \"find out about\"",
    "category": "learning",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/learn",
      "learn"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "learning--learning-engine",
    "name": "learning-engine",
    "description": "Self-learning system based on SICA, VIGIL, and Mem0 patterns. Auto-triggers after task completion. Captures patterns, consolidates memory, generates skills, recovers from errors.",
    "category": "learning",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/learning-engine",
      "learning-engine"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "learning--meta-prompting",
    "name": "meta-prompting",
    "description": "Bundled Learning skill from library/skills/learning/meta-prompting/SKILL.md.",
    "category": "learning",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/meta-prompting",
      "meta-prompting"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "learning--pattern-capture",
    "name": "pattern-capture",
    "description": "Bundled Learning skill from library/skills/learning/pattern-capture/SKILL.md.",
    "category": "learning",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/pattern-capture",
      "pattern-capture"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "learning--remember",
    "name": "remember",
    "description": "> Capture behavioral friction as structured observations. Three modes: explicit (user states a lesson), contextual (scan conversation for corrections and patterns), and session mining (bulk extract from transcripts). Stores observations for later synthesis via /rethink. Triggers on: \"remember\", \"lesson learned\", \"note pattern\", \"capture friction\"",
    "category": "learning",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/remember",
      "remember"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "learning--rethink",
    "name": "rethink",
    "description": "> Synthesize accumulated observations into system evolution proposals. Fires when observation count reaches threshold. 5-phase process: triage, methodology updates, pattern detection, proposal generation, and human approval. Never auto-implements - always proposes changes for review. Triggers on: \"rethink\", \"synthesize learnings\", \"evolve system\", \"improve process\"",
    "category": "learning",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/rethink",
      "rethink"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--caveman",
    "name": "caveman",
    "description": "> Ultra-compressed communication mode. Cuts token usage ~75% by dropping filler, articles, and pleasantries while keeping full technical accuracy. Use when user says \"caveman mode\", \"talk like caveman\", \"use caveman\", \"less tokens\", \"be brief\", or invokes /caveman.",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/caveman",
      "caveman"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--design-an-interface",
    "name": "design-an-interface",
    "description": "Generate multiple radically different interface designs for a module using parallel sub-agents. Use when user wants to design an API, explore interface options, compare module shapes, or mentions \"design it twice\".",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/design-an-interface",
      "design-an-interface"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--diagnose",
    "name": "diagnose",
    "description": "Disciplined diagnosis loop for hard bugs and performance regressions. Reproduce -> minimise -> hypothesise -> instrument -> fix -> regression-test. Use when user says \"diagnose this\" / \"debug this\", reports a bug, says something is broken/throwing/failing, or describes a performance regression.",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/diagnose",
      "diagnose"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--edit-article",
    "name": "edit-article",
    "description": "Edit and improve articles by restructuring sections, improving clarity, and tightening prose. Use when user wants to edit, revise, or improve an article draft.",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/edit-article",
      "edit-article"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--git-guardrails-claude-code",
    "name": "git-guardrails-claude-code",
    "description": "Set up Claude Code hooks to block dangerous git commands (push, reset --hard, clean, branch -D, etc.) before they execute. Use when user wants to prevent destructive git operations, add git safety hooks, or block git push/reset in Claude Code.",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/git-guardrails-claude-code",
      "git-guardrails-claude-code"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--grill-me",
    "name": "grill-me",
    "description": "Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions \"grill me\".",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/grill-me",
      "grill-me"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--grill-with-docs",
    "name": "grill-with-docs",
    "description": "Grilling session that challenges your plan against the existing domain model, sharpens terminology, and updates documentation (CONTEXT.md, ADRs) inline as decisions crystallise. Use when user wants to stress-test a plan against their project's language and documented decisions.",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/grill-with-docs",
      "grill-with-docs"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--improve-codebase-architecture",
    "name": "improve-codebase-architecture",
    "description": "Find deepening opportunities in a codebase, informed by the domain language in CONTEXT.md and the decisions in docs/adr/. Use when the user wants to improve architecture, find refactoring opportunities, consolidate tightly-coupled modules, or make a codebase more testable and AI-navigable.",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/improve-codebase-architecture",
      "improve-codebase-architecture"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--migrate-to-shoehorn",
    "name": "migrate-to-shoehorn",
    "description": "Migrate test files from `as` type assertions to @total-typescript/shoehorn. Use when user mentions shoehorn, wants to replace `as` in tests, or needs partial test data.",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/migrate-to-shoehorn",
      "migrate-to-shoehorn"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--obsidian-vault",
    "name": "obsidian-vault",
    "description": "Search, create, and manage notes in the Obsidian vault with wikilinks and index notes. Use when user wants to find, create, or organize notes in Obsidian.",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/obsidian-vault",
      "obsidian-vault"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--qa",
    "name": "qa",
    "description": "Interactive QA session where user reports bugs or issues conversationally, and the agent files GitHub issues. Explores the codebase in the background for context and domain language. Use when user wants to report bugs, do QA, file issues conversationally, or mentions \"QA session\".",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/qa",
      "qa"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--request-refactor-plan",
    "name": "request-refactor-plan",
    "description": "Create a detailed refactor plan with tiny commits via user interview, then file it as a GitHub issue. Use when user wants to plan a refactor, create a refactoring RFC, or break a refactor into safe incremental steps.",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/request-refactor-plan",
      "request-refactor-plan"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--scaffold-exercises",
    "name": "scaffold-exercises",
    "description": "Create exercise directory structures with sections, problems, solutions, and explainers that pass linting. Use when user wants to scaffold exercises, create exercise stubs, or set up a new course section.",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/scaffold-exercises",
      "scaffold-exercises"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--setup-matt-pocock-skills",
    "name": "setup-matt-pocock-skills",
    "description": "Sets up an `## Agent skills` block in AGENTS.md/CLAUDE.md and `docs/agents/` so the engineering skills know this repo's issue tracker (GitHub or local markdown), triage label vocabulary, and domain doc layout. Run before first use of `to-issues`, `to-prd`, `triage`, `diagnose`, `tdd`, `improve-codebase-architecture`, or `zoom-out` - or if those skills appear to be missing context about the issue tracker, triage labels, or domain docs.",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/setup-matt-pocock-skills",
      "setup-matt-pocock-skills"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--setup-pre-commit",
    "name": "setup-pre-commit",
    "description": "Set up Husky pre-commit hooks with lint-staged (Prettier), type checking, and tests in the current repo. Use when user wants to add pre-commit hooks, set up Husky, configure lint-staged, or add commit-time formatting/typechecking/testing.",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/setup-pre-commit",
      "setup-pre-commit"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--tdd",
    "name": "tdd",
    "description": "Test-driven development with red-green-refactor loop. Use when user wants to build features or fix bugs using TDD, mentions \"red-green-refactor\", wants integration tests, or asks for test-first development.",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/tdd",
      "tdd"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--to-issues",
    "name": "to-issues",
    "description": "Break a plan, spec, or PRD into independently-grabbable issues on the project issue tracker using tracer-bullet vertical slices. Use when user wants to convert a plan into issues, create implementation tickets, or break down work into issues.",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/to-issues",
      "to-issues"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--to-prd",
    "name": "to-prd",
    "description": "Turn the current conversation context into a PRD and publish it to the project issue tracker. Use when user wants to create a PRD from the current context.",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/to-prd",
      "to-prd"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--triage",
    "name": "triage",
    "description": "Triage issues through a state machine driven by triage roles. Use when user wants to create an issue, triage issues, review incoming bugs or feature requests, prepare issues for an AFK agent, or manage issue workflow.",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/triage",
      "triage"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--ubiquitous-language",
    "name": "ubiquitous-language",
    "description": "Extract a DDD-style ubiquitous language glossary from the current conversation, flagging ambiguities and proposing canonical terms. Saves to UBIQUITOUS_LANGUAGE.md. Use when user wants to define domain terms, build a glossary, harden terminology, create a ubiquitous language, or mentions \"domain model\" or \"DDD\".",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/ubiquitous-language",
      "ubiquitous-language"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--write-a-skill",
    "name": "write-a-skill",
    "description": "Create new agent skills with proper structure, progressive disclosure, and bundled resources. Use when user wants to create, write, or build a new skill.",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/write-a-skill",
      "write-a-skill"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "matt-pocock--zoom-out",
    "name": "zoom-out",
    "description": "Tell the agent to zoom out and give broader context or a higher-level perspective. Use when you're unfamiliar with a section of code or need to understand how it fits into the bigger picture.",
    "category": "matt-pocock",
    "source": "marketplace",
    "enabled": false,
    "triggers": [
      "/zoom-out",
      "zoom-out"
    ],
    "version": "1.0",
    "author": "Matt Pocock",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "operations--boot",
    "name": "boot",
    "description": "Bundled Operations skill from library/skills/operations/boot/SKILL.md.",
    "category": "operations",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/boot",
      "boot"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "operations--doctor",
    "name": "doctor",
    "description": "Bundled Operations skill from library/skills/operations/doctor/SKILL.md.",
    "category": "operations",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/doctor",
      "doctor"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "operations--health",
    "name": "health",
    "description": "Bundled Operations skill from library/skills/operations/health/SKILL.md.",
    "category": "operations",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/health",
      "health"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "operations--shutdown",
    "name": "shutdown",
    "description": "Bundled Operations skill from library/skills/operations/shutdown/SKILL.md.",
    "category": "operations",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/shutdown",
      "shutdown"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "operations--status",
    "name": "status",
    "description": "Bundled Operations skill from library/skills/operations/status/SKILL.md.",
    "category": "operations",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/status",
      "status"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "paid-media--ads-apple",
    "name": "ads apple",
    "description": "> Apple Search Ads (ASA) deep analysis for mobile app advertisers. Evaluates campaign structure, bid health, Creative Sets, MMP attribution, budget pacing, TAP coverage (Today/Search/Product Pages), and goal CPA benchmarks by country. Triggers on: \"Apple Search Ads\", \"ASA\", \"App Store ads\", \"Apple ads\", \"Search Ads\", \"iOS app ads\"",
    "category": "paid-media",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/ads-apple",
      "ads-apple"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "paid-media--ads-audit",
    "name": "ads audit",
    "description": "> Full multi-platform paid advertising audit with parallel subagent delegation. Analyzes Google Ads, Meta Ads, LinkedIn Ads, TikTok Ads, and Microsoft Ads accounts. Generates health score per platform and aggregate score. Triggers on: \"audit\", \"full ad check\", \"analyze my ads\", \"account health check\", \"PPC audit\", \"ad account audit\"",
    "category": "paid-media",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/ads-audit",
      "ads-audit"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "paid-media--ads-budget",
    "name": "ads budget",
    "description": "> Budget allocation and bidding strategy review across all ad platforms. Evaluates spend distribution, bidding strategy appropriateness, scaling readiness, and identifies campaigns to kill or scale. Uses 70/20/10 rule, 3x Kill Rule, and 20% scaling rule. Triggers on: \"budget allocation\", \"bidding strategy\", \"ad spend\", \"ROAS target\", \"media budget\", \"scaling\", \"kill list\"",
    "category": "paid-media",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/ads-budget",
      "ads-budget"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "paid-media--ads-competitor",
    "name": "ads competitor",
    "description": "> Competitor ad intelligence analysis across Google, Meta, LinkedIn, TikTok, and Microsoft. Analyzes competitor ad copy, creative strategy, keyword targeting, estimated spend, and identifies competitive gaps and opportunities. Triggers on: \"competitor ads\", \"ad spy\", \"competitive analysis\", \"competitor PPC\", \"ad intelligence\", \"competitor research\"",
    "category": "paid-media",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/ads-competitor",
      "ads-competitor"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "paid-media--ads-create",
    "name": "ads create",
    "description": "> Campaign concept and copy brief generator for paid advertising. Reads brand-profile.json and optional audit results to produce structured campaign concepts, messaging pillars, and copy briefs. Outputs campaign-brief.md. Run after /ads dna and before /ads generate. Triggers on: \"create campaign\", \"campaign brief\", \"ad concepts\", \"write ad copy\", \"campaign strategy\", \"ad messaging\", \"creative brief\", \"generate concepts\"",
    "category": "paid-media",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/ads-create",
      "ads-create"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "paid-media--ads-creative",
    "name": "ads creative",
    "description": "> Cross-platform creative quality audit covering ad copy, video, image, and format diversity across all platforms. Detects creative fatigue, evaluates platform-native compliance, and provides production priorities. Triggers on: \"creative audit\", \"ad creative\", \"creative fatigue\", \"ad copy review\", \"ad design\", \"creative review\", \"creative health\"",
    "category": "paid-media",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/ads-creative",
      "ads-creative"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "paid-media--ads-dna",
    "name": "ads dna",
    "description": "> Brand DNA extractor for paid advertising. Scans a website URL to extract visual identity, tone of voice, color palette, typography, and imagery style. Outputs brand-profile.json. Run before /ads create or /ads generate for brand-consistent creative. Triggers on: \"brand DNA\", \"brand profile\", \"extract brand\", \"brand identity\", \"brand colors\", \"analyze brand\", \"brand style guide\", \"brand voice\"",
    "category": "paid-media",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/ads-dna",
      "ads-dna"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "paid-media--ads-generate",
    "name": "ads generate",
    "description": "> AI image generation for paid ad creatives. Reads campaign-brief.md and brand-profile.json to produce platform-sized ad images using Gemini (default) or a configured provider. Requires GOOGLE_API_KEY or ADS_IMAGE_PROVIDER + matching key. Triggers on: \"generate ads\", \"create images\", \"make ad creatives\", \"generate visuals\", \"create ad images\", \"generate campaign images\", \"make the images\", \"generate from brief\"",
    "category": "paid-media",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/ads-generate",
      "ads-generate"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "paid-media--ads-google",
    "name": "ads google",
    "description": "> Google Ads deep analysis covering Search, Performance Max, Display, YouTube, and Demand Gen campaigns. Evaluates 74 checks across conversion tracking, wasted spend, account structure, keywords, ads, and settings. Triggers on: \"Google Ads\", \"Google PPC\", \"search ads\", \"PMax\", \"Performance Max\", \"Google campaign\", \"Google audit\"",
    "category": "paid-media",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/ads-google",
      "ads-google"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "paid-media--ads-landing",
    "name": "ads landing",
    "description": "> Landing page quality assessment for paid advertising campaigns. Evaluates message match, page speed, mobile experience, trust signals, form optimization, and conversion rate potential. Triggers on: \"landing page\", \"post-click experience\", \"landing page audit\", \"conversion rate\", \"landing page optimization\", \"LP audit\"",
    "category": "paid-media",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/ads-landing",
      "ads-landing"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "paid-media--ads-linkedin",
    "name": "ads linkedin",
    "description": "> LinkedIn Ads deep analysis for B2B advertising. Evaluates 25 checks across technical setup, audience targeting, creative quality, lead gen forms, and bidding strategy. Includes Thought Leader Ads, ABM, and predictive audiences. Triggers on: \"LinkedIn Ads\", \"B2B ads\", \"sponsored content\", \"lead gen forms\", \"InMail\", \"LinkedIn campaign\", \"LinkedIn audit\"",
    "category": "paid-media",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/ads-linkedin",
      "ads-linkedin"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "paid-media--ads-meta",
    "name": "ads meta",
    "description": "> Meta Ads deep analysis covering Facebook and Instagram advertising. Evaluates 46 checks across Pixel/CAPI health, creative diversity and fatigue, account structure, and audience targeting. Includes Advantage+ assessment. Triggers on: \"Meta Ads\", \"Facebook Ads\", \"Instagram Ads\", \"Advantage+\", \"Meta campaign\", \"Meta audit\", \"FB ads\"",
    "category": "paid-media",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/ads-meta",
      "ads-meta"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "paid-media--ads-microsoft",
    "name": "ads microsoft",
    "description": "> Microsoft/Bing Ads deep analysis covering search, Performance Max, Audience Network, and Copilot integration. Evaluates 20 checks with focus on Google import validation, unique Microsoft features, and cost advantage assessment. Triggers on: \"Microsoft Ads\", \"Bing Ads\", \"Bing PPC\", \"Copilot ads\", \"Microsoft campaign\", \"Bing audit\"",
    "category": "paid-media",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/ads-microsoft",
      "ads-microsoft"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "paid-media--ads-photoshoot",
    "name": "ads photoshoot",
    "description": "> Product photography enhancement for ad creatives using AI image generation. Takes a product image and generates 5 professional photography styles for ad use: Studio, Floating, Ingredient, In Use, and Lifestyle. Requires GOOGLE_API_KEY or configured ADS_IMAGE_PROVIDER. Triggers on: \"product photo\", \"product photography\", \"photoshoot\", \"enhance product image\", \"product shoot\", \"product photos for ads\", \"studio shot\", \"lifestyle photo\"",
    "category": "paid-media",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/ads-photoshoot",
      "ads-photoshoot"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "paid-media--ads-plan",
    "name": "ads plan",
    "description": "> Strategic paid advertising planning with industry-specific templates. Covers platform selection, campaign architecture, budget planning, creative strategy, and phased implementation roadmap. Triggers on: \"ad plan\", \"ad strategy\", \"campaign planning\", \"media plan\", \"PPC strategy\", \"advertising plan\", \"media strategy\"",
    "category": "paid-media",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/ads-plan",
      "ads-plan"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "paid-media--ads-tiktok",
    "name": "ads tiktok",
    "description": "> TikTok Ads deep analysis covering creative quality, tracking, bidding, campaign structure, and TikTok Shop. Evaluates 25 checks with emphasis on creative-first strategy, safe zone compliance, and Smart+ campaigns. Triggers on: \"TikTok Ads\", \"TikTok marketing\", \"TikTok Shop\", \"Spark Ads\", \"Smart+\", \"TikTok campaign\", \"TikTok audit\"",
    "category": "paid-media",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/ads-tiktok",
      "ads-tiktok"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "paid-media--ads-youtube",
    "name": "ads youtube",
    "description": "> YouTube Ads specific analysis covering campaign types, creative quality, audience targeting, and measurement. Evaluates video ad performance across skippable, non-skippable, bumper, Shorts, and Demand Gen formats. Triggers on: \"YouTube Ads\", \"video ads\", \"pre-roll\", \"bumper ads\", \"YouTube campaign\", \"Shorts ads\", \"YouTube audit\"",
    "category": "paid-media",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/ads-youtube",
      "ads-youtube"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "processing--pipeline",
    "name": "pipeline",
    "description": "> End-to-end processing pipeline that chains the full 6R sequence: seed, reduce, reflect, reweave, verify. Runs per-item or in batch mode. Three depth levels control thoroughness vs. speed. The orchestrator for all processing skills. Triggers on: \"pipeline\", \"process\", \"full pipeline\", \"6R\"",
    "category": "processing",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/pipeline",
      "pipeline"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "processing--reduce",
    "name": "reduce",
    "description": "> Extract atomic insights from raw source material. Takes articles, transcripts, meeting notes, or any unstructured input and produces structured claims with provenance metadata. The foundational extraction step of the 6R processing pipeline. Triggers on: \"extract\", \"reduce\", \"distill\", \"summarize source\"",
    "category": "processing",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/reduce",
      "reduce"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "processing--reflect",
    "name": "reflect",
    "description": "> Discover connections between existing knowledge items. Scans the knowledge base for related concepts, updates topic maps, and surfaces synthesis opportunities using graph traversal. The connective tissue step of the 6R pipeline. Triggers on: \"reflect\", \"connect\", \"find related\", \"topic map\"",
    "category": "processing",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/reflect",
      "reflect"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "processing--reweave",
    "name": "reweave",
    "description": "> Backward pass over existing knowledge when new information arrives. Finds older content that should be updated, corrected, or enriched in light of new data. Detects staleness, generates update suggestions, and optionally applies them. Triggers on: \"reweave\", \"update stale\", \"backward pass\", \"refresh context\"",
    "category": "processing",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/reweave",
      "reweave"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "processing--seed",
    "name": "seed",
    "description": "> Initialize sources into the processing pipeline. Takes URLs, files, or raw text and creates inbox items with full provenance metadata. The entry point for all external knowledge - nothing enters the system without being seeded first. Triggers on: \"seed\", \"add source\", \"ingest url\", \"new input\"",
    "category": "processing",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/seed",
      "seed"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "processing--verify",
    "name": "verify",
    "description": "> Quality gate for knowledge base content. Validates structural compliance (YAML frontmatter, required fields, link integrity), checks that L0 abstracts accurately represent full content, and runs schema conformance. Non-blocking - reports warnings. Triggers on: \"verify\", \"validate\", \"check quality\", \"lint knowledge\"",
    "category": "processing",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/verify",
      "verify"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "search--assemble",
    "name": "assemble",
    "description": "Bundled Search skill from library/skills/search/assemble/SKILL.md.",
    "category": "search",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/assemble",
      "assemble"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "search--browse",
    "name": "browse",
    "description": "Bundled Search skill from library/skills/search/browse/SKILL.md.",
    "category": "search",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/browse",
      "browse"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "search--search",
    "name": "search",
    "description": "Bundled Search skill from library/skills/search/search/SKILL.md.",
    "category": "search",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/search",
      "search"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "security--auditor",
    "name": "security-auditor",
    "description": "Comprehensive security analysis and vulnerability detection",
    "category": "security",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/security-auditor",
      "security-auditor",
      "security|vulnerability|CVE|OWASP|audit|pentest|harden|compliance|secret|exploit"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "security--harden",
    "name": "harden",
    "description": "Bundled Security skill from library/skills/security/harden/SKILL.md.",
    "category": "security",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/harden",
      "harden"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "security--secret-scan",
    "name": "secret-scan",
    "description": "Bundled Security skill from library/skills/security/secret-scan/SKILL.md.",
    "category": "security",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/secret-scan",
      "secret-scan"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "security--security-scan",
    "name": "security-scan",
    "description": "Bundled Security skill from library/skills/security/security-scan/SKILL.md.",
    "category": "security",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/security-scan",
      "security-scan"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "strategy--brainstorm",
    "name": "brainstorm",
    "description": "Bundled Strategy skill from library/skills/strategy/brainstorm/SKILL.md.",
    "category": "strategy",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/brainstorm",
      "brainstorm"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "strategy--impact",
    "name": "impact",
    "description": "Bundled Strategy skill from library/skills/strategy/impact/SKILL.md.",
    "category": "strategy",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/impact",
      "impact"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "strategy--plan",
    "name": "plan",
    "description": "Bundled Strategy skill from library/skills/strategy/plan/SKILL.md.",
    "category": "strategy",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/plan",
      "plan"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "strategy--simulate",
    "name": "simulate",
    "description": "Bundled Strategy skill from library/skills/strategy/simulate/SKILL.md.",
    "category": "strategy",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/simulate",
      "simulate"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "workflow--batch",
    "name": "batch",
    "description": "Bundled Workflow skill from library/skills/workflow/batch/SKILL.md.",
    "category": "workflow",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/batch",
      "batch"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "workflow--handoff",
    "name": "handoff",
    "description": "Bundled Workflow skill from library/skills/workflow/handoff/SKILL.md.",
    "category": "workflow",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/handoff",
      "handoff"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "workflow--loop",
    "name": "loop",
    "description": "Bundled Workflow skill from library/skills/workflow/loop/SKILL.md.",
    "category": "workflow",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/loop",
      "loop"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "workflow--pipeline",
    "name": "pipeline",
    "description": "Bundled Workflow skill from library/skills/workflow/pipeline/SKILL.md.",
    "category": "workflow",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/pipeline",
      "pipeline"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "workspace--compose",
    "name": "compose",
    "description": "Generate structured documents from composition templates. Combines reference templates with live data to produce reviewable output artifacts. Triggered by compose, document, generate report, create brief, write proposal.",
    "category": "workspace",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/compose",
      "compose"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "workspace--export",
    "name": "export",
    "description": "> Export a workspace as a portable template. Captures SYSTEM.md, agent definitions, skills, reference files, configuration, seed tasks, and budget defaults. Handles secret stripping and collision metadata for clean import elsewhere. Triggers on: \"export\", \"save template\", \"package workspace\", \"share workspace\"",
    "category": "workspace",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/export",
      "export"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "workspace--import",
    "name": "import",
    "description": "> Import a workspace template. Supports preview (dry-run), collision handling (rename/skip/replace), and secret requirements tracking. Accepts templates from local files, URLs, or GitHub repositories. The counterpart to /export. Triggers on: \"import\", \"load template\", \"install workspace\"",
    "category": "workspace",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/import",
      "import"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "workspace--launch",
    "name": "launch",
    "description": "> One-command workspace activation from a template. Reads a TOML/YAML workspace template, spawns agents, assigns initial tasks, sets budgets, and bootstraps the full operating environment. Variable substitution for customization. Triggers on: \"launch\", \"start workspace\", \"activate\", \"boot workspace\"",
    "category": "workspace",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/launch",
      "launch"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  },
  {
    "id": "workspace--review-interface",
    "name": "review-interface",
    "description": "> Build custom annotation UIs for human review of agent traces, LLM outputs, and labeled data. Generates a self-contained HTML interface for reviewing, labeling, comparing, and exporting judgments. For calibrating evals, auditing agent behavior, and building gold-standard datasets. Triggers on: \"review interface\", \"annotation ui\", \"labeling interface\", \"review ui\", \"human review\"",
    "category": "workspace",
    "source": "builtin",
    "enabled": false,
    "triggers": [
      "/review-interface",
      "review-interface"
    ],
    "version": "1.0",
    "author": "Canopy",
    "downloads": 0,
    "rating": 0
  }
];
