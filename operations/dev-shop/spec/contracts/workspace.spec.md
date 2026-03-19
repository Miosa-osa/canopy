# Dev Shop — Workspace Completeness Contract

Verifies the Dev Shop workspace is structurally sound: all agents exist,
all skills are discoverable, reference materials cover the tech stack,
and the spec layer defines the development workflow.

## Meta
```spec-meta
id: dev-shop.workspace.completeness
kind: policy
status: active
summary: Structural integrity check for the Dev Shop workspace
surface:
  - SYSTEM.md
  - agents/*.md
  - skills/*/SKILL.md
  - reference/*.md
  - company.yaml
  - handoffs/*.md
```

## Requirements
```spec-requirements
- id: devshop.system_md_exists
  statement: The workspace shall have a SYSTEM.md at root
  priority: must
  stability: stable

- id: devshop.agents_complete
  statement: The workspace shall contain all 6 declared agents (tech-lead, architect, frontend-dev, backend-dev, qa-engineer, devops)
  priority: must
  stability: stable

- id: devshop.agents_frontmatter
  statement: Every agent file shall have YAML frontmatter with name, role, signal, and skills fields
  priority: must
  stability: stable

- id: devshop.skills_discoverable
  statement: All 6 skills (spec, build, test, review, debug, deploy) shall have a SKILL.md
  priority: must
  stability: stable

- id: devshop.reference_stack
  statement: The tech stack reference shall exist at reference/stack.md
  priority: must
  stability: stable

- id: devshop.reference_standards
  statement: Coding standards shall exist at reference/standards.md
  priority: must
  stability: stable

- id: devshop.reference_patterns
  statement: Architecture patterns shall exist at reference/patterns.md
  priority: should
  stability: stable

- id: devshop.reference_cicd
  statement: CI/CD configuration reference shall exist at reference/ci-cd.md
  priority: should
  stability: evolving

- id: devshop.company_yaml_exists
  statement: The workspace shall have a company.yaml with org chart and budget configuration
  priority: must
  stability: stable

- id: devshop.handoffs_present
  statement: The workspace shall have a handoffs/ directory with inter-agent handoff definitions
  priority: should
  stability: stable

- id: devshop.spec_procedures
  statement: PROCEDURES.md shall define at least the core dev lifecycle actions (build, test, deploy)
  priority: must
  stability: stable

- id: devshop.spec_workflow
  statement: WORKFLOW.md shall define FSM states for the development pipeline (spec, build, review, test, deploy)
  priority: must
  stability: stable

- id: devshop.spec_modules
  statement: MODULES.md shall define the module dependency graph
  priority: should
  stability: evolving
```

## Verification
```spec-verification
- kind: source_file
  target: SYSTEM.md
  covers:
    - devshop.system_md_exists

- kind: glob_match
  target: agents/*.md
  expected_min: 6
  expected_max: 6
  expected_names: [tech-lead.md, architect.md, frontend-dev.md, backend-dev.md, qa-engineer.md, devops.md]
  covers:
    - devshop.agents_complete

- kind: frontmatter_check
  target: agents/*.md
  required_fields: [name, role, signal, skills]
  covers:
    - devshop.agents_frontmatter

- kind: glob_match
  target: skills/*/SKILL.md
  expected_min: 6
  expected_names: [spec/SKILL.md, build/SKILL.md, test/SKILL.md, review/SKILL.md, debug/SKILL.md, deploy/SKILL.md]
  covers:
    - devshop.skills_discoverable

- kind: source_file
  target: reference/stack.md
  covers:
    - devshop.reference_stack

- kind: source_file
  target: reference/standards.md
  covers:
    - devshop.reference_standards

- kind: source_file
  target: reference/patterns.md
  covers:
    - devshop.reference_patterns

- kind: source_file
  target: reference/ci-cd.md
  covers:
    - devshop.reference_cicd

- kind: source_file
  target: company.yaml
  covers:
    - devshop.company_yaml_exists

- kind: glob_match
  target: handoffs/*.md
  expected_min: 1
  covers:
    - devshop.handoffs_present

- kind: content_match
  target: spec/PROCEDURES.md
  pattern: "kind:\\s+action"
  covers:
    - devshop.spec_procedures

- kind: content_match
  target: spec/WORKFLOW.md
  pattern: "states:"
  covers:
    - devshop.spec_workflow

- kind: source_file
  target: spec/MODULES.md
  covers:
    - devshop.spec_modules
```
