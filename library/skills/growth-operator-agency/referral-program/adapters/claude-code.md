---
description: Design customer referral mechanics — reward structure, triggers, tracking, viral loop (k-factor). Customer-focused (distinct from affiliate).
argument-hint: "[optional: --reward=cash|credit-both|perks|hybrid]"
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /referral-program — slash-command runtime Runtime Binding

Load and execute `skills/referral-program/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/referral-program/SKILL.md` (full body)
   - read `skills/referral-program/reference/` (all files, if present)
   - `Read` upstream dependency output: `output/retention-check/latest.md` (Thriving clients = referral pool)
   - read `output/design-offer/latest.md` for offer tier + price-point context

2. **Pre-flight check:** Verify `company.yaml` thresholds — offer_architecture ≥ 50, lifecycle_optimization ≥ 40. If below, recommend running `/retention-check` first.

3. **Execute Phase 0 → Phase 5** per SKILL.md Process section — Load, Reward Structure, Trigger Mapping, Tracking Wire-up, Communication, Success Metrics.

4. **Write output:**
   - `Write` to `output/referral-program/{YYYY-MM-DD}-referral-program-spec.md`
   - Structure per SKILL.md Output Format (6 sections: Reward Structure, Triggers, Tracking, Communication Cadence with assets, Success Metrics)
   - If any section fails cross-validation, mark `[GAP: section N]` and continue

5. **Update company.yaml:** `Edit` compartment 10 (lifecycle_optimization) — append referral program reference + k-factor target + trigger points. Never overwrite existing values without confirmation.

6. **Post-ship:**
   - write `skills/referral-program/evidence/runs/{YYYY-MM-DD}-run.md` with phase log + confidence tags + reward pattern + k-factor target
   - Output next-skill recommendation (usually `/email-sequence` for referral-ask emails, or `/case-study` to pair with Thriving clients)

## Arguments

If `$ARGUMENTS` includes `--reward=<pattern>`, anchor the reward structure design. Otherwise select pattern per offer tier (high-ticket → perks > cash).

`$ARGUMENTS`

## Tool usage patterns

- **Read** for loading SKILL.md, company.yaml, reference/, retention-check output, offer doc
- **Write / Edit** for producing the spec and updating compartment 10
- **Grep** across `company.yaml` to check Thriving client count + existing referral data

## Quality gates

Before writing the spec to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification (formal 40% + semantic 35% + information-theoretic 25%)
- Check `spec/BANNED-VOCABULARY.md` — reject if any banned phrases
- Confirm every evidence_gate condition (reward_structure_specified, triggers_mapped, tracking_wired, viral_loop_designed)
- Signal Score ≥ 0.8
- **External tier gate:** Blind Output Test 2/3 before the program ships to real customers
- k-factor target stated with realistic basis (most programs 0.1-0.5)

## Failure handling

If skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode
- Attempt 2: surface the gap to creator with targeted question (often trigger cadence undecided)
- If both fail: escalate to partnerships-head, log to `skills/referral-program/evidence/failure-modes.md`

## Cross-skill routing

After spec ships:
- Recommend `/email-sequence` for referral-ask emails (post-first-win + NPS-9 moments)
- Recommend `/case-study` to pair with Thriving clients (referral ask + testimonial capture in same touchpoint)

---
*the slash-command adapter v1.0 — binds to skills/referral-program/SKILL.md*
