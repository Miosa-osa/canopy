# Legacy Protocol Specs — DEPRECATED

These specs describe the **canopy-legacy** org hierarchy (Company → Division →
Department → Team → Agent). Canopy v2 **dropped** this hierarchy; it is
replaced by the flatter Workspace Protocol.

## Files here (all DEPRECATED)

- `company-format.md`
- `division-format.md`
- `department-format.md`
- `team-format.md`

## Why deprecated

- The 5-layer org model added friction for the 80% use case (one person with a
  few agents) without paying for itself in the 20% enterprise case.
- The org-chart framing was explicitly rejected as a canopy-legacy anti-pattern for v2.
- The v2 data model uses `Workspace` as the single container for agents,
  sessions, skills, and files. Workspaces compose via cross-references, not
  strict containment.

## Canonical replacements

| Legacy concept | v2 equivalent |
|----------------|---------------|
| `company.yaml` | `workspace.yaml` (inside a workspace folder) |
| Division / Department | Tags or nested workspace folders (user-defined) |
| Team | Implicit via shared workspace membership |

## Can I safely delete these?

Not yet. They're preserved for reference until the first public v2 release, in
case any migration tooling needs to read the old format. After v0.1 ships, we
reevaluate.
