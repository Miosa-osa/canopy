---
name: Git Commit Workflow
description: Disciplined git commit workflow skill. Guides agents through staged commits, conventional commit messages, and pre-commit verification before marking any task complete.
provider_format: agents_md
tags:
  - git
  - workflow
  - commits
---

## Git Commit Workflow

Never commit without verification. Never amend unless explicitly requested. Never force-push.

### Pre-commit checklist

Before staging anything:

1. `git status` — confirm which files changed and why
2. `git diff` — review every line; no debug prints, no secrets, no `.env` files
3. Run the test suite — do not commit red
4. Run the formatter — `mix format` / `biome check` / `cargo fmt`
5. Run the linter — `mix credo --strict` / `biome lint`

### Conventional commit format

```
<type>(<scope>): <imperative summary>

<body — explain WHY, not WHAT>

<footer — breaking changes, issue references>
```

**Types:** `feat` `fix` `refactor` `test` `docs` `chore` `perf` `ci`

**Rules:**
- Summary: imperative mood, ≤72 chars, no period
- Body: explain the motivation, not the mechanics
- One logical change per commit — split if needed

### Staging discipline

Stage files explicitly by name — never `git add .` or `git add -A`. Wildcards only when the entire changed set belongs to the same commit.

```bash
git add lib/canopy/skills.ex lib/canopy/skills/skill.ex
git commit -m "feat(skills): add Skills context with bundle_key computation"
```

### After commit

- `git log --oneline -5` — verify the commit landed correctly
- Never use `--no-verify` unless the user explicitly requests it
- If a pre-commit hook fails: fix the issue, re-stage, create a NEW commit — never `--amend` after a hook failure
