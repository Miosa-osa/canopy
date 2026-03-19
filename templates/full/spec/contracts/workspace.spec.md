# {{WORKSPACE_NAME}} — Workspace Completeness Contract

<!-- TODO: Replace {{WORKSPACE_NAME}} with your workspace name -->
<!-- TODO: Update the description to match your workspace's purpose -->

Verifies the workspace is structurally sound: all declared agents exist,
all skills are discoverable, reference materials are present, and the
workspace follows the Workspace Protocol.

## Meta
```spec-meta
id: {{workspace_id}}.workspace.completeness
kind: policy
status: draft
summary: Structural integrity check for {{WORKSPACE_NAME}}
surface:
  - SYSTEM.md
  - agents/*.md
  - skills/*/SKILL.md
  - reference/*.md
  - company.yaml
```

## Requirements
```spec-requirements
# --- Core workspace structure (keep these) ---

- id: ws.system_md_exists
  statement: The workspace shall have a SYSTEM.md at root
  priority: must
  stability: stable

- id: ws.agents_declared
  statement: Every agent listed in SYSTEM.md shall exist as agents/{id}.md
  priority: must
  stability: stable

- id: ws.agents_frontmatter
  statement: Every agent file shall have YAML frontmatter with name, role, and signal fields
  priority: must
  stability: stable

- id: ws.skills_discoverable
  statement: Every skill referenced in SYSTEM.md shall exist as skills/{name}/SKILL.md
  priority: must
  stability: stable

- id: ws.company_yaml_exists
  statement: The workspace shall have a company.yaml at root
  priority: should
  stability: stable

# --- Reference materials (customize these) ---

# TODO: Add requirements for your specific reference files
# - id: ws.reference_{{name}}
#   statement: {{Description}} shall exist at reference/{{name}}.md
#   priority: must
#   stability: stable

# --- Spec layer (add if using PROCEDURES.md / WORKFLOW.md / MODULES.md) ---

# TODO: Uncomment and customize if your workspace uses the spec layer
# - id: ws.spec_procedures
#   statement: PROCEDURES.md shall define the core action bindings
#   priority: should
#   stability: evolving

# - id: ws.spec_workflow
#   statement: WORKFLOW.md shall define FSM states for the primary workflow
#   priority: should
#   stability: evolving

# --- Custom requirements (add your own below) ---
```

## Verification
```spec-verification
- kind: source_file
  target: SYSTEM.md
  covers:
    - ws.system_md_exists

- kind: glob_match
  target: agents/*.md
  expected_min: 1
  # TODO: Set expected_min to your actual agent count
  # TODO: Add expected_names list for your specific agents
  covers:
    - ws.agents_declared

- kind: frontmatter_check
  target: agents/*.md
  required_fields: [name, role, signal]
  covers:
    - ws.agents_frontmatter

- kind: glob_match
  target: skills/*/SKILL.md
  expected_min: 1
  # TODO: Set expected_min to your actual skill count
  # TODO: Add expected_names list for your specific skills
  covers:
    - ws.skills_discoverable

- kind: source_file
  target: company.yaml
  covers:
    - ws.company_yaml_exists

# TODO: Add verification entries for your reference files and spec layer
# - kind: source_file
#   target: reference/{{name}}.md
#   covers:
#     - ws.reference_{{name}}
```
