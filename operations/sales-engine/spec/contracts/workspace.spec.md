# Sales Engine — Workspace Completeness Contract

Verifies the Sales Engine workspace is structurally sound: all agents exist,
all skills are discoverable, reference materials are present, and the company
configuration is valid.

## Meta
```spec-meta
id: sales-engine.workspace.completeness
kind: policy
status: active
summary: Structural integrity check for the Sales Engine workspace
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
- id: sales.system_md_exists
  statement: The workspace shall have a SYSTEM.md at root
  priority: must
  stability: stable

- id: sales.agents_complete
  statement: The workspace shall contain all 5 declared agents (director, prospector, researcher, closer, copywriter)
  priority: must
  stability: stable

- id: sales.agents_frontmatter
  statement: Every agent file shall have YAML frontmatter with name, role, signal, and skills fields
  priority: must
  stability: stable

- id: sales.skills_discoverable
  statement: All 5 skills (prospect, qualify, pipeline, close-plan, battlecard) shall have a SKILL.md
  priority: must
  stability: stable

- id: sales.reference_icp
  statement: The ICP framework shall exist at reference/icp.md
  priority: must
  stability: stable

- id: sales.reference_meddpicc
  statement: The MEDDPICC methodology shall exist at reference/meddpicc.md
  priority: must
  stability: stable

- id: sales.reference_objections
  statement: The objection playbook shall exist at reference/objections.md
  priority: should
  stability: stable

- id: sales.reference_sequences
  statement: Outreach sequences shall exist at reference/sequences.md
  priority: should
  stability: evolving

- id: sales.company_yaml_exists
  statement: The workspace shall have a company.yaml with org chart and budget configuration
  priority: must
  stability: stable

- id: sales.company_yaml_budget
  statement: company.yaml shall define a budget section with a total and per-agent allocations
  priority: should
  stability: evolving

- id: sales.handoffs_present
  statement: The workspace shall have a handoffs/ directory with inter-agent handoff definitions
  priority: should
  stability: stable

- id: sales.spec_files_present
  statement: The spec/ directory shall contain PROCEDURES.md, WORKFLOW.md, and MODULES.md
  priority: should
  stability: stable
```

## Verification
```spec-verification
- kind: source_file
  target: SYSTEM.md
  covers:
    - sales.system_md_exists

- kind: glob_match
  target: agents/*.md
  expected_min: 5
  expected_max: 5
  expected_names: [director.md, prospector.md, researcher.md, closer.md, copywriter.md]
  covers:
    - sales.agents_complete

- kind: frontmatter_check
  target: agents/*.md
  required_fields: [name, role, signal, skills]
  covers:
    - sales.agents_frontmatter

- kind: glob_match
  target: skills/*/SKILL.md
  expected_min: 5
  expected_names: [prospect/SKILL.md, qualify/SKILL.md, pipeline/SKILL.md, close-plan/SKILL.md, battlecard/SKILL.md]
  covers:
    - sales.skills_discoverable

- kind: source_file
  target: reference/icp.md
  covers:
    - sales.reference_icp

- kind: source_file
  target: reference/meddpicc.md
  covers:
    - sales.reference_meddpicc

- kind: source_file
  target: reference/objections.md
  covers:
    - sales.reference_objections

- kind: source_file
  target: reference/sequences.md
  covers:
    - sales.reference_sequences

- kind: source_file
  target: company.yaml
  covers:
    - sales.company_yaml_exists

- kind: content_match
  target: company.yaml
  pattern: "budget:"
  covers:
    - sales.company_yaml_budget

- kind: glob_match
  target: handoffs/*.md
  expected_min: 1
  covers:
    - sales.handoffs_present

- kind: source_file
  target: spec/PROCEDURES.md
  covers:
    - sales.spec_files_present

- kind: source_file
  target: spec/WORKFLOW.md
  covers:
    - sales.spec_files_present

- kind: source_file
  target: spec/MODULES.md
  covers:
    - sales.spec_files_present
```
