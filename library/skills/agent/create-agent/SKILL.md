# /create-agent

> Define a new specialist agent with role, capabilities, triggers, and routing rules.

## Usage
```
/create-agent "<name>" --role "<role>" [--tier <opus|sonnet|haiku>] [--triggers "<keywords>"]
```

## What It Does
Creates a new agent definition file with role description, capabilities, trigger keywords, file-type routing, escalation paths, and integration points. Validates against the existing agent roster to avoid duplicates. Registers the agent in the routing table.

## Implementation
1. **Check roster** -- verify no existing agent covers this role.
2. **Define agent** -- create agent definition with:
   - Name and role description
   - Tier assignment (opus for elite, sonnet for specialist, haiku for utility)
   - Trigger keywords for automatic routing
   - File-type associations
   - Capabilities and limitations
   - Escalation paths (when to hand off)
3. **Write definition** -- create `agents/<name>.md` following agent template.
4. **Register** -- add to routing table in CLAUDE.md.
5. **Validate** -- confirm no routing conflicts with existing agents.

## Examples
```bash
# Create a new specialist agent
/create-agent "data-engineer" --role "ETL pipelines and data modeling" --tier sonnet

# Create with specific triggers
/create-agent "mobile-dev" --role "React Native development" --tier sonnet --triggers "mobile, iOS, Android, React Native"

# Create a utility agent
/create-agent "formatter" --role "Code formatting and style enforcement" --tier haiku
```
