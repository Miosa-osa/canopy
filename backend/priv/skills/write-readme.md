---
name: Write README
description: Documentation skill for writing clear, structured README files. Follows a consistent genre skeleton that maximizes signal-to-noise ratio for technical receivers.
provider_format: generic
tags:
  - documentation
  - writing
  - readme
---

## README Writing Protocol

A README is a Signal. Resolve all 5 dimensions before writing: Mode (linguistic/code), Genre (readme), Type (inform), Format (markdown), Structure (skeleton below).

### Canonical README skeleton

```markdown
# Project Name
> One-line description. What it does, not what it is.

## What it does
Two sentences max. The problem it solves and for whom.

## Quick start
Minimum commands to get it running. No prose - just steps.

## Architecture
One diagram or one paragraph. Structure before detail.

## Configuration
Table of env vars with type, default, and description.

## Development
Prerequisites -> install -> run -> test. Four commands max.

## Deployment
Environment-specific instructions. Link to runbooks if complex.

## License
```

### Anti-patterns to eliminate

- **Wall-of-text intros** - cut everything before the first actionable line
- **Excessive feature lists** - show, don't tell; link to docs instead
- **Stale badges** - only include badges with live CI backing
- **Generic "Contributing" sections** - either link to CONTRIBUTING.md or omit

### Signal quality checks

Before finalizing:
- Can a new engineer clone and run in under 5 minutes using only this README?
- Is every section ordered by receiver priority (most urgent first)?
- Are all code blocks tested and copy-paste safe?
