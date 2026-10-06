# Summary

One paragraph on what this PR changes and why. Link to the issue or roadmap item it addresses.

## Change type

- [ ] New skill
- [ ] Existing skill modification
- [ ] New agent
- [ ] Invariant change (requires creator sign-off)
- [ ] Schema change to `ENCODING.md` / `company.yaml`
- [ ] New framework or operator encoding
- [ ] Spec update
- [ ] Workflow / handoff / operations
- [ ] Documentation
- [ ] Repo hygiene (`.gitignore`, `.github/`, LICENSE, CHANGELOG)
- [ ] Visual asset (`docs/assets/`)

## Quality gates

Per [`.github/CONTRIBUTING.md`](../CONTRIBUTING.md):

- [ ] Banned-vocabulary sweep clean (`grep -i` against [`spec/BANNED-VOCABULARY.md`](../spec/BANNED-VOCABULARY.md))
- [ ] No hardcoded `/Users/...` or developer-specific paths
- [ ] Every new markdown link resolves to a real file
- [ ] Counts in `README.md`, `SYSTEM.md`, `skills/_INDEX.md`, `agents/_INDEX.md` agree
- [ ] Version stamp bumped or verified on changed top-level docs
- [ ] `CHANGELOG.md` entry added for user-visible changes
- [ ] `.gitignore` still protects the INV-11 split
- [ ] No `_private/` content, filled `company.yaml` values, or `.env` values leaked

## Skill-specific (if applicable)

- [ ] `SKILL.md` has all 9 body sections (Role, Decision Logic, Tacit Principles, Process, Output Format, Context Requirements, Verification Checklist, Important Rules, Cross-skill Routing)
- [ ] `SKILL.md` does not reference a specific runtime
- [ ] `adapters/claude-code.md` is ≤ 50 lines
- [ ] `adapters/manifest.yaml` declares tier, category, temperature_gate, evidence_gate
- [ ] `evidence/blind-output-test.md` classifies the tier correctly (sacred / external / internal)
- [ ] `.claude/commands/{slug}.md` exists and points to the adapter
- [ ] `skills/_INDEX.md` updated

## Cascade

If this PR touches `SYSTEM.md`, `INVARIANTS.md`, or `ENCODING.md`, list every downstream file that needs to re-verify.

## Testing

What was run to validate this change. Include skill slug, runtime, and summary output.

## Notes for reviewers

Anything non-obvious a reviewer should know.
