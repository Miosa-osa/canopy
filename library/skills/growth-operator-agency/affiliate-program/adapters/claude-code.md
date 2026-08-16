---
description: Design affiliate program structure — commission rates + payout logic + affiliate portal + promotion assets + recruitment outreach + compliance.
argument-hint: "[optional: --tier=info|digital|saas|done-for-you]"
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /affiliate-program — slash-command runtime Runtime Binding

Load and execute `skills/affiliate-program/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/affiliate-program/SKILL.md` (full body)
   - read `skills/affiliate-program/reference/` (all files, if present)
   - `Read` upstream dependency output: `output/design-offer/latest.md` (offer economics informs commission math)

2. **Pre-flight check:** Verify `company.yaml` thresholds — offer_architecture ≥ 60, lifecycle_optimization ≥ 20. If below, recommend running `/design-offer` first.

3. **Execute** per SKILL.md Decision Logic and Structure — Commission Structure, Payout Logic, Affiliate Portal, Promotion Assets, Recruitment Plan, Compliance, Economics Validation.

4. **Write output:**
   - `Write` to `output/affiliate-program/{YYYY-MM-DD}-affiliate-program-spec.md`
   - Structure per SKILL.md Output Format (7 sections + commission tier matrix + economics validation)
   - If any section fails cross-validation, mark `[GAP: section N]` and continue

5. **Update company.yaml:** `Edit` compartment 3 (offer_architecture) — append affiliate program reference + commission tier summary. Never overwrite existing values without confirmation.

6. **Post-ship:**
   - write `skills/affiliate-program/evidence/runs/{YYYY-MM-DD}-run.md` with phase log + confidence tags + LTV:CAC impact math
   - Output next-skill recommendation (usually `/referral-program` for customer-referral adjacent, or `/email-sequence` for affiliate recruitment)

## Arguments

If `$ARGUMENTS` includes `--tier=<info|digital|saas|done-for-you>`, calibrate commission benchmarks per that category. Otherwise infer from offer type in company.yaml.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for loading SKILL.md, company.yaml, reference/, offer doc
- **Write / Edit** for producing the spec and updating compartment 3
- **Grep** across `company.yaml` to check existing affiliate data + offer LTV:CAC

## Quality gates

Before writing the spec to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification (formal 40% + semantic 35% + information-theoretic 25%)
- Check `spec/BANNED-VOCABULARY.md` — reject if any banned phrases
- Confirm every evidence_gate condition (commission_structure_specified, payout_logic_clear, portal_assets_defined, recruitment_plan, compliance_disclosed)
- Signal Score ≥ 0.8
- **External tier gate:** Blind Output Test 2/3 before the program ships to real affiliates
- Economics preserve ≥ 3:1 LTV:CAC after affiliate payout

## Failure handling

If skill fails verification, follow `workflows/handoffs/quality-revision.md`:
- Attempt 1: auto-revise addressing the specific failure mode
- Attempt 2: surface the gap to creator with targeted question (often cookie window or commission tier structure undecided)
- If both fail: escalate to partnerships-head, log to `skills/affiliate-program/evidence/failure-modes.md`

## Cross-skill routing

After spec ships:
- Recommend `/referral-program` for customer-referral mechanics (adjacent but distinct from commercial affiliates)
- Recommend `/email-sequence` for affiliate recruitment sequence (Tier 1 direct outreach, Tier 2 existing-buyer activation)

---
*the slash-command adapter v1.0 — binds to skills/affiliate-program/SKILL.md*
