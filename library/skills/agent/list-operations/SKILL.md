# /list-operations

> List all defined operations with their status, agents, and deliverables.

## Usage
```
/list-operations [--category <category>] [--verbose]
```

## What It Does
Shows a table of all defined operations in the workspace, including their goal, required agents, current status, and last execution time. Useful for understanding what automated workflows are available.

## Implementation
1. Scan `operations/` directory for all OPERATION.md files.
2. Parse metadata from each: name, goal, agents, status, last-run.
3. Display as table sorted by category.
4. With `--verbose`: show full phase breakdown and deliverables for each.

## Examples
```bash
# List all operations
/list-operations

# List by category
/list-operations --category development

# Verbose with full details
/list-operations --verbose
```
