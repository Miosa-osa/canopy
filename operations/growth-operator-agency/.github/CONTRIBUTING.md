# Contributing — Growth Operating Agency

Contribution guide for this workspace template. The main line is authored by the maintainers; external contributions are accepted when they preserve the invariants below.

The `.github/` directory holds the GitHub-native config for this repository: this contribution guide, the security policy, code-owners, the pull-request template, and issue templates.

## Before you change anything

1. **Read `SYSTEM.md`, `INVARIANTS.md`, and `ENCODING.md` end to end.** These three files are load-bearing. An edit that contradicts them cascades through every skill output.
2. **Check `spec/BANNED-VOCABULARY.md`.** Anti-slop constraints are enforced at skill-execution time. New content has to pass the banned-vocab check before it ships.
3. **Check `docs/PROVENANCE.md`.** Understand what layers the workspace rests on before touching the foundation layer.
4. **Run the existing chain once.** If you have never executed `/research → /build-icp → /build-positioning → /design-offer → /extract-voice` against a test creator, do that first. The chain is the reality check for any architectural change.

## Where changes go

| Change type | File(s) to edit |
|---|---|
| A new skill | `skills/{new-slug}/SKILL.md` + `adapters/` + `evidence/` + `.claude/commands/{new-slug}.md` + `skills/_INDEX.md` entry |
| A new agent | `agents/{new-slug}.md` with frontmatter + reporting chain + `agents/_INDEX.md` entry |
| An invariant change | `INVARIANTS.md` — requires creator sign-off, because the change cascades through every skill |
| A new runtime | A new adapter pattern in `spec/RUNTIMES.md` + `skills/{slug}/adapters/{runtime}.{ext}` per skill |
| A new framework doc | `reference/frameworks/{name}/` with a `README.md` + source attribution |
| A new operator playbook | `reference/operators/{slug}.md` with provenance header + cross-references |
| A schema change to `company.yaml` | `ENCODING.md` first, then `company.yaml`, then every skill that reads that compartment |
| A workflow or automation | `workflows/{category}/{name}.md` |

## Commit etiquette

- Co-authorship on commits is not used in this repository. The commit author stands on their own.
- Commits should be narrow — a single skill, a single framework, a single spec update. Avoid mixing structural and content changes in one commit.
- The Heuresis commit voice is declarative, not apologetic. Write *what changed* in the imperative mood. Do not explain what you did not do.
- When a commit touches `SYSTEM.md`, `INVARIANTS.md`, or `ENCODING.md`, note it clearly in the message so reviewers can check for cascade.

## Quality gates before a PR

Run this before you ask for review:

1. **Banned vocabulary sweep.** `grep -i` the list in `spec/BANNED-VOCABULARY.md` against your changed files. Zero hits in active content.
2. **Hardcoded path sweep.** No absolute paths starting with `/Users/` or any other developer-specific root. Template paths are always workspace-relative.
3. **Link integrity.** Every new markdown link resolves to a real file in this workspace.
4. **Version stamp.** If you touched a top-level doc, bump or verify the footer version.
5. **Cross-reference check.** If you touched `SYSTEM.md`'s file catalog, confirm every referenced file exists.
6. **Private-data check.** No `company.yaml` values, no `_private/` content, no `.env` values, no creator names anywhere outside the designated encoded-operator files.

## Style

- Markdown only. No HTML unless absolutely required.
- Fenced code blocks with a language hint.
- Tables for structured lists when rows repeat a schema.
- Use declarative prose. Heuresis voice is calm, specific, and does not over-explain.
- Do not write "we do not X" / "this is not Y" — declare positively instead.
- Do not cite competitors. Compare Growth Operating Agency to itself at different versions, not to other vendors.

## Review checklist

Reviewers confirm:

- Counts in `README.md`, `SYSTEM.md`, `skills/_INDEX.md`, and `agents/_INDEX.md` agree.
- `.gitignore` still protects the INV-11 split.
- No forbidden content (banned vocabulary, competitor mentions, leaked paths, creator IP) entered the repo.
- Every skill change has a corresponding `evidence/blind-output-test.md` update if the output contract changed.

## Roadmap changes

The canonical roadmap lives at the bottom of `skills/_INDEX.md` ("Roadmap") and in `CHANGELOG.md` under "Known next steps." Do not start a roadmap skill without updating the INDEX entry to **🟡 v1.1 target** or **⏳ v2.0 roadmap** first.

---

*Growth Operating Agency — a Heuresis workspace template.*
