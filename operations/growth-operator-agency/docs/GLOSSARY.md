# Glossary

Terms used across Growth Operating Agency, in one place.

---

## Adapter

A thin binding file inside `skills/{slug}/adapters/` that translates a runtime-agnostic `SKILL.md` into something a specific runtime can execute. Typically ≤ 50 lines. If an adapter exceeds 50 lines, methodology has leaked out of `SKILL.md` — pull it back.

## Blind Output Test

The encoding-completeness protocol. Three evaluators who know the creator's work see the output and answer: *did the creator produce this, or the system?* If at least one says "creator" or "can't tell," encoding passed. If zero do, the encoding is wrong — revise. Spec at [`reference/canonical/spec/BLIND-OUTPUT-TEST.md`](../reference/canonical/spec/BLIND-OUTPUT-TEST.md).

## workspace protocol

The workspace file contract: `SYSTEM.md` + `SKILL.md` + two-layer structure + external skill references with provenance. Growth Operating Agency is manifest-compliant. the workspace manifest is the format the workspace speaks in.

## Compartment

One of eleven sections of the Creator Context Profile stored in `company.yaml`. Each compartment has a schema (defined in [`ENCODING.md`](../ENCODING.md)), a weight (per the Impact Distribution Principle), and a completeness percentage that gates which skills can execute.

## Compartment Completeness

A measured percentage (0–100%) per compartment. Skills self-gate on compartment thresholds — a skill that requires `audience_intelligence_system ≥ 70%` refuses to execute below that. Interview Mode fills the gap.

## Context Tier

Overall context quality: Skeleton (0–25%), Foundation (25–50%), Solid (50–75%), Optimized (75–90%), Elite (90–100%). Determines what quality of output is possible.

## Creator Context Profile

The 11-compartment schema in `ENCODING.md`, instantiated in `company.yaml`. The single source of truth for everything the workspace knows about the creator.

## Encoding Flywheel

The compounding cycle: every run through the workspace deepens the encoding, which raises the quality of the next run. After 5+ cycles, the encoding process is itself encoded — creators validate instead of write.

## Encoded Founder

The methodology for translating tacit creator judgment into machine-readable workspace content. The three-layer knowledge architecture and the M-formula (`M = T × S × K × A × E × I × L`) come from here.

## Growth Operating Agency

The predecessor / research workspace that Growth Operating Agency is extracted from. The 82KB agent architecture bible lives at [`reference/canonical/AGENT-ARCHITECTURE.md`](../reference/canonical/AGENT-ARCHITECTURE.md). Growth Operating Agency is Growth Operating Agency generalized and productized as a template.

## Impact Distribution Principle

40/40/20 — audience quality drives 40% of results, offer strength drives 40%, copy drives 20%. Fix upstream before downstream. Encoded as [INV-1](../INVARIANTS.md).

## Invariant

One of the 14 sacred rules in [`INVARIANTS.md`](../INVARIANTS.md). Each has a NEVER clause, an ALWAYS clause, and an enforcement mechanism. Violation = reject + revise.

## M-formula

`M = T × S × K × A × E × I × L` — the Encoded Founder measure of fit between an encoded workspace and its creator. T is truth, S is signal, K is knowledge, A is alignment, E is evidence, I is invariants, L is leverage. Any factor at zero collapses the whole product. Private; not sold externally.

## Output Format

The deliverable shape declared by a skill's `SKILL.md`. If content is too long, flag with `[GAP: section N]` — never silently truncate.

## ROM / RAM

The core thesis. Workspace = ROM (persistent, files on disk, yours forever). Agent = RAM (stateless, generic, replaceable). Any agent that reads the workspace becomes a specialist in the creator's business.

## Runtime

The LLM host that reads the workspace and executes skills. Growth Operating Agency supports slash-command runtime, workspace manifests (primary), Codex, Cursor, OpenClaw, and any future runtime that reads markdown + YAML. Runtime-specific concerns live in `adapters/`.

## Sacred-format

The strictest skill tier — 3/3 Blind Output Test pass required. Applies to the 7 highest-stakes skills: `design-offer`, `build-positioning`, `extract-voice`, `build-vsl`, `webinar-script`, `plan-launch`, `case-study`.

## Signal

An output of a skill, encoded as a 5-tuple `(Mode, Genre, Type, Format, Structure)`. Unresolved dimensions equal noise. Per the Signal Theory author's Signal Theory. See [`reference/canonical/spec/SIGNAL.md`](../reference/canonical/spec/SIGNAL.md).

## Signal Theory

Signal Theory's methodology for intent encoding. The quality substrate Growth Operating Agency rests on. Spec at [`reference/canonical/spec/SIGNAL.md`](../reference/canonical/spec/SIGNAL.md).

## S/N

Signal-to-noise ratio. Measured per output. Gate thresholds: ≥ 0.8 for external, ≥ 0.5 for internal, < 0.5 reject.

## Skill

A deterministic procedure that produces a specific asset. Lives as a folder `skills/{slug}/`. Not a prompt. Not chat. Rigid, versioned, testable. See [SKILL_AUTHORING.md](SKILL_AUTHORING.md).

## Triple-Layer Verification

The output gate: 40% formal + 35% semantic + 25% information-theoretic. All three layers must pass before ship. Spec at [`reference/canonical/spec/QUALITY.md`](../reference/canonical/spec/QUALITY.md).

## Voice of Customer (VOC)

Verbatim creator and customer language captured in Compartment 2 (Audience Intelligence). Skills prefer verbatim VOC over generic copy — this is the Blind-Output-Test's strongest signal.

## Workspace

The root folder of Growth Operating Agency. Contains `SYSTEM.md` + `INVARIANTS.md` + `ENCODING.md` + `company.yaml` + all skills, agents, spec, reference, workflows, and operations directories. The workspace is the product. The agent is the runtime. Skills are stacked.

---

*Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
