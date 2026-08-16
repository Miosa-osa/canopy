# /validate

> Validate agent definitions, skill files, and operation configs for correctness.

## Usage
```
/validate [--agents] [--skills] [--operations] [--all]
```

## What It Does
Checks that all agent definitions, skill files, and operation configs are structurally valid, have no broken references, and follow the required format. Reports issues with specific file locations and fix suggestions.

## Implementation
1. **Agent validation** -- check each agent has: name, role, tier, triggers, file associations.
2. **Skill validation** -- check each SKILL.md has: name, usage, description, implementation, examples.
3. **Operation validation** -- check each operation references valid agents and skills.
4. **Cross-reference check** -- verify routing table matches actual agent files.
5. **Report** -- list all issues by severity (error, warning, info).

## Examples
```bash
# Validate everything
/validate --all

# Validate only agents
/validate --agents

# Validate only skills
/validate --skills
```
