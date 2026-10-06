# Quickstart

Get Growth Operating Agency running against a real creator in under 30 minutes. This guide assumes slash-command runtime. For other runtimes, see [RUNTIMES](../spec/RUNTIMES.md).

---

## Prerequisites

- A working install of [slash-command runtime](https://docs.claude.com/en/docs/claude-code) or the [workspace-manifest runtime](https://manifest.dev).
- Git.
- A creator whose business you are about to encode (yourself, a client, or a research subject).

That is the full list. Growth Operating Agency is markdown and YAML. There is no build step, no package to install, no database to provision.

---

## Step 1 — Get the workspace

```bash
git clone <your-private-remote>/growth-os.git your-creator-workspace
cd your-creator-workspace
```

Replace `<your-private-remote>` with the git URL of your own private mirror.

**Verify the shape:**

```bash
ls
# .env.template  CHANGELOG.md  CONTRIBUTING.md  ENCODING.md
# INVARIANTS.md  LICENSE       PROVENANCE.md    README.md
# SECURITY.md    SYSTEM.md     _excluded/       _private/
# agents/        company.yaml  handoffs/        operations/
# output/        reference/    skills/          spec/
# workflows/
```

You should see 29 skill folders under `skills/`, 41 agent files under `agents/`, and 29 slash-command runtime command bindings under `.claude/commands/`.

---

## Step 2 — Boot the workspace

### If you are using slash-command runtime

Open the workspace directory in a slash-command runtime. The harness reads `.claude/commands/*.md` automatically and exposes the slash commands to the palette. The first agent to enter the workspace reads `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, and `company.yaml` before it does anything else — this is the boot sequence.

### If you are using the workspace manifest

```bash
manifest boot ./
```

the workspace manifest discovers skills by scanning `skills/*/SKILL.md` and agents by scanning `agents/*.md`. The adapters in `skills/{slug}/adapters/manifest.yaml` handle runtime bindings automatically.

### If you are using a generic LLM

1. Paste the contents of `SYSTEM.md` into a new conversation as the system prompt.
2. Paste the relevant `company.yaml` compartments as context.
3. Invoke a skill by pasting its `SKILL.md` body and following the Process section.

This is the **portability guarantee** — any capable LLM that reads markdown and YAML can run a skill. See [INV-10 in INVARIANTS.md](../INVARIANTS.md).

---

## Step 3 — Run the Foundations chain

The Foundations chain is the sequential dependency chain you run first, always. It fills the 11-compartment Creator Context Profile enough to unlock every downstream department.

```
/research → /build-icp → /build-positioning → /design-offer → /extract-voice
```

### Run `/research`

```
/research
```

The `researcher` agent takes over. It interviews the creator across the 11 compartments, captures raw context into `_private/interview-notes.md`, and produces a **Market Research Brief** at `output/research/{date}-market-research-brief.md`. This is your bootstrap artifact.

Time: 30–90 minutes of creator attention, split across one or more sessions.

### Run `/build-icp`

Only once `audience_intelligence_system` completeness is at least 30%:

```
/build-icp
```

Produces an **ICP Document** with 13 sections and a Completeness Score. The score must be ≥ 80 before this artifact is considered shipped.

### Continue the chain

- `/build-positioning` — after audience ≥ 60%
- `/design-offer` — after audience ≥ 70% and offer ≥ 30%, with 3:1 LTV:CAC economics gate
- `/extract-voice` — after the creator has enough historical content to sample

Every skill self-gates on context thresholds per [spec/CONTEXT-THRESHOLDS.md](../spec/CONTEXT-THRESHOLDS.md). A skill refuses to execute below threshold rather than produce noise — if that happens, the workspace will ask you to run the upstream skill first.

---

## Step 4 — Ship the first external asset

Once the Foundations stack is validated (all five compartments green), run cycle 2:

```
/build-vsl
/build-funnel
/ad-creative
/write-linkedin-post
```

Each of these is context-gated. The workspace checks `company.yaml` before generating, refuses below threshold, and flags gaps inside the output rather than hiding them.

---

## Step 5 — Read what happened

Every run writes:

- The artifact — at `output/{skill}/{date}-{name}.md`
- The run log — at `skills/{skill}/evidence/runs/{date}-run.md`
- Compartment updates — merged back into `company.yaml` if the skill writes to a compartment

Before shipping any asset externally, run the Blind Output Test spec — see [reference/canonical/spec/BLIND-OUTPUT-TEST.md](../reference/canonical/spec/BLIND-OUTPUT-TEST.md). If three evaluators who know the creator's work can tell the system produced it, the encoding is wrong. Revise.

---

## What to do next

- Read [ARCHITECTURE.md](ARCHITECTURE.md) to understand the three-layer knowledge model.
- Read [SKILL_AUTHORING.md](SKILL_AUTHORING.md) if you plan to add or modify skills.
- Read [GLOSSARY.md](GLOSSARY.md) for the vocabulary — compartment, signal, S/N, sacred-format, encoding flywheel.
- Read [FAQ.md](FAQ.md) for common questions on privacy, instantiation, and runtimes.

---

*Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
