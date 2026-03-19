# /browse

> Browse the knowledge base structure -- list nodes, files, and L0 cache.

## Usage
```
/browse [path] [--l0]
```

## What It Does
Lists the contents of the knowledge base at any level. Without arguments, shows all nodes. With a path, shows contents of that node. With `--l0`, shows the always-loaded L0 context cache.

## Implementation
- List all nodes: `cd engine && mix optimal.ls "optimal://nodes/"`
- List one node: `cd engine && mix optimal.ls "optimal://nodes/<name>/"`
- Show L0 cache: `cd engine && mix optimal.l0`

## Examples
```bash
# List all nodes
/browse

# List contents of a specific node
/browse ai-masters

# Show the L0 always-loaded context
/browse --l0
```
