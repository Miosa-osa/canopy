# {{WORKSPACE_NAME}} — Enterprise Workspace Contract

<!-- TODO: Replace {{WORKSPACE_NAME}} with your workspace name -->

Verifies the enterprise workspace meets structural, governance, and compliance
requirements. Enterprise workspaces have stricter verification than standard
workspaces — governance controls, budget configuration, audit trails, and
security boundaries are all required.

## Meta
```spec-meta
id: {{workspace_id}}.workspace.enterprise
kind: policy
status: draft
summary: Enterprise structural and compliance verification for {{WORKSPACE_NAME}}
surface:
  - SYSTEM.md
  - agents/*.md
  - skills/*/SKILL.md
  - reference/*.md
  - company.yaml
  - governance/*.md
  - budgets/*.md
  - handoffs/*.md
```

## Requirements
```spec-requirements
# ─── Core Workspace Structure ───────────────────────────────────────

- id: ent.system_md_exists
  statement: The workspace shall have a SYSTEM.md at root
  priority: must
  stability: stable

- id: ent.agents_declared
  statement: Every agent listed in SYSTEM.md shall exist as agents/{id}.md
  priority: must
  stability: stable

- id: ent.agents_frontmatter
  statement: Every agent file shall have YAML frontmatter with name, role, signal, reportsTo, and budget fields
  priority: must
  stability: stable

- id: ent.skills_discoverable
  statement: Every skill referenced in SYSTEM.md shall exist as skills/{name}/SKILL.md
  priority: must
  stability: stable

- id: ent.company_yaml_exists
  statement: The workspace shall have a company.yaml at root
  priority: must
  stability: stable

# ─── Governance & Compliance ────────────────────────────────────────

- id: ent.governance_directory
  statement: The workspace shall have a governance/ directory with approval and escalation policies
  priority: must
  stability: stable

- id: ent.governance_approval_gates
  statement: governance/ shall define approval gates for high-risk actions
  priority: must
  stability: stable

- id: ent.governance_escalation
  statement: governance/ shall define an escalation policy with named human contacts
  priority: must
  stability: stable

- id: ent.governance_audit_log
  statement: The workspace shall define an audit logging policy for all agent actions
  priority: must
  stability: stable

# ─── Budget Controls ────────────────────────────────────────────────

- id: ent.budget_directory
  statement: The workspace shall have a budgets/ directory with cost allocation policies
  priority: must
  stability: stable

- id: ent.budget_total_defined
  statement: company.yaml shall define a total budget ceiling
  priority: must
  stability: stable

- id: ent.budget_per_agent
  statement: Every agent shall have a budget field in frontmatter that does not exceed the company total
  priority: must
  stability: stable

- id: ent.budget_alerts
  statement: Budget policy shall define alert thresholds (warn at 80%, block at 100%)
  priority: should
  stability: evolving

# ─── Security & Access Control ──────────────────────────────────────

- id: ent.agents_least_privilege
  statement: Each agent shall declare its required permissions explicitly in frontmatter
  priority: should
  stability: evolving

- id: ent.no_secrets_in_files
  statement: No workspace file shall contain API keys, tokens, passwords, or other secrets
  priority: must
  stability: stable

- id: ent.handoff_authorization
  statement: Agent handoffs shall require the receiving agent to be authorized for the task type
  priority: should
  stability: evolving

# ─── Spec Layer ─────────────────────────────────────────────────────

- id: ent.spec_procedures
  statement: PROCEDURES.md shall define all core action and query bindings
  priority: must
  stability: stable

- id: ent.spec_workflow
  statement: WORKFLOW.md shall define FSM states for all primary workflows
  priority: must
  stability: stable

- id: ent.spec_modules
  statement: MODULES.md shall define the complete module dependency graph
  priority: must
  stability: stable

# ─── Documentation & Traceability ──────────────────────────────────

- id: ent.decisions_directory
  statement: The workspace shall have a spec/decisions/ directory for Architecture Decision Records
  priority: should
  stability: stable

- id: ent.reference_complete
  statement: Every reference file cited in SYSTEM.md shall exist in reference/
  priority: must
  stability: stable

# ─── Custom Requirements (add your own below) ──────────────────────

# TODO: Add domain-specific compliance requirements
# - id: ent.compliance_{{framework}}
#   statement: The workspace shall comply with {{framework}} requirements
#   priority: must
#   stability: stable
```

## Verification
```spec-verification
# ─── Core Structure ─────────────────────────────────────────────────

- kind: source_file
  target: SYSTEM.md
  covers:
    - ent.system_md_exists

- kind: glob_match
  target: agents/*.md
  expected_min: 1
  # TODO: Set expected_min to your actual agent count
  covers:
    - ent.agents_declared

- kind: frontmatter_check
  target: agents/*.md
  required_fields: [name, role, signal, reportsTo, budget]
  covers:
    - ent.agents_frontmatter

- kind: glob_match
  target: skills/*/SKILL.md
  expected_min: 1
  # TODO: Set expected_min to your actual skill count
  covers:
    - ent.skills_discoverable

- kind: source_file
  target: company.yaml
  covers:
    - ent.company_yaml_exists

# ─── Governance ─────────────────────────────────────────────────────

- kind: glob_match
  target: governance/*.md
  expected_min: 1
  covers:
    - ent.governance_directory

- kind: content_match
  target: governance/*.md
  pattern: "approval|gate|requires_approval"
  covers:
    - ent.governance_approval_gates

- kind: content_match
  target: governance/*.md
  pattern: "escalat|human_contact|escalation_to"
  covers:
    - ent.governance_escalation

- kind: content_match
  target: governance/*.md
  pattern: "audit|log|audit_log"
  covers:
    - ent.governance_audit_log

# ─── Budget ─────────────────────────────────────────────────────────

- kind: glob_match
  target: budgets/*.md
  expected_min: 1
  covers:
    - ent.budget_directory

- kind: content_match
  target: company.yaml
  pattern: "budget:"
  covers:
    - ent.budget_total_defined

- kind: frontmatter_check
  target: agents/*.md
  required_fields: [budget]
  covers:
    - ent.budget_per_agent

- kind: content_match
  target: budgets/*.md
  pattern: "threshold|alert|warn"
  covers:
    - ent.budget_alerts

# ─── Security ──────────────────────────────────────────────────────

- kind: command
  target: "! grep -rEl '(sk-|AKIA|ghp_|token[=:].{20,})' . --include='*.md' --include='*.yaml'"
  covers:
    - ent.no_secrets_in_files

# ─── Spec Layer ─────────────────────────────────────────────────────

- kind: content_match
  target: spec/PROCEDURES.md
  pattern: "kind:\\s+(action|query)"
  covers:
    - ent.spec_procedures

- kind: content_match
  target: spec/WORKFLOW.md
  pattern: "states:"
  covers:
    - ent.spec_workflow

- kind: source_file
  target: spec/MODULES.md
  covers:
    - ent.spec_modules

# ─── Documentation ─────────────────────────────────────────────────

- kind: glob_match
  target: spec/decisions/*.md
  expected_min: 0
  covers:
    - ent.decisions_directory

- kind: cross_reference
  source: SYSTEM.md
  target: reference/*.md
  link_field: reference
  covers:
    - ent.reference_complete
```
