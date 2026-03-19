# Content Factory — Workspace Completeness Contract

Verifies the Content Factory workspace is structurally sound: all agents exist,
all skills are discoverable, brand and editorial references are present, and
the content pipeline workflow is defined.

## Meta
```spec-meta
id: content-factory.workspace.completeness
kind: policy
status: active
summary: Structural integrity check for the Content Factory workspace
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
- id: content.system_md_exists
  statement: The workspace shall have a SYSTEM.md at root
  priority: must
  stability: stable

- id: content.agents_complete
  statement: The workspace shall contain all 5 declared agents (editor-in-chief, writer, designer, seo-specialist, social-media)
  priority: must
  stability: stable

- id: content.agents_frontmatter
  statement: Every agent file shall have YAML frontmatter with name, role, signal, and skills fields
  priority: must
  stability: stable

- id: content.skills_discoverable
  statement: All 5 skills (ideate, write, analyze, schedule, repurpose) shall have a SKILL.md
  priority: must
  stability: stable

- id: content.reference_brand_voice
  statement: The brand voice guide shall exist at reference/brand-voice.md
  priority: must
  stability: stable

- id: content.reference_platforms
  statement: Platform specifications shall exist at reference/platforms.md
  priority: must
  stability: stable

- id: content.reference_calendar
  statement: The content calendar reference shall exist at reference/calendar.md
  priority: should
  stability: evolving

- id: content.reference_seo
  statement: The SEO checklist shall exist at reference/seo-checklist.md
  priority: should
  stability: stable

- id: content.company_yaml_exists
  statement: The workspace shall have a company.yaml with org chart and budget configuration
  priority: must
  stability: stable

- id: content.handoffs_present
  statement: The workspace shall have a handoffs/ directory with editorial workflow handoffs
  priority: should
  stability: stable

- id: content.spec_workflow
  statement: WORKFLOW.md shall define FSM states for the editorial pipeline (ideate, draft, review, publish, distribute)
  priority: must
  stability: stable

- id: content.spec_procedures
  statement: PROCEDURES.md shall define content creation and publishing actions
  priority: should
  stability: evolving
```

## Verification
```spec-verification
- kind: source_file
  target: SYSTEM.md
  covers:
    - content.system_md_exists

- kind: glob_match
  target: agents/*.md
  expected_min: 5
  expected_max: 5
  expected_names: [editor-in-chief.md, writer.md, designer.md, seo-specialist.md, social-media.md]
  covers:
    - content.agents_complete

- kind: frontmatter_check
  target: agents/*.md
  required_fields: [name, role, signal, skills]
  covers:
    - content.agents_frontmatter

- kind: glob_match
  target: skills/*/SKILL.md
  expected_min: 5
  expected_names: [ideate/SKILL.md, write/SKILL.md, analyze/SKILL.md, schedule/SKILL.md, repurpose/SKILL.md]
  covers:
    - content.skills_discoverable

- kind: source_file
  target: reference/brand-voice.md
  covers:
    - content.reference_brand_voice

- kind: source_file
  target: reference/platforms.md
  covers:
    - content.reference_platforms

- kind: source_file
  target: reference/calendar.md
  covers:
    - content.reference_calendar

- kind: source_file
  target: reference/seo-checklist.md
  covers:
    - content.reference_seo

- kind: source_file
  target: company.yaml
  covers:
    - content.company_yaml_exists

- kind: glob_match
  target: handoffs/*.md
  expected_min: 1
  covers:
    - content.handoffs_present

- kind: content_match
  target: spec/WORKFLOW.md
  pattern: "states:"
  covers:
    - content.spec_workflow

- kind: source_file
  target: spec/PROCEDURES.md
  covers:
    - content.spec_procedures
```
