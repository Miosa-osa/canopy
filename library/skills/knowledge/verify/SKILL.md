# /verify

> Test L0 abstract fidelity -- do compressed summaries match actual content?

## Usage
```
/verify [--sample <n>]
```

## What It Does
Samples context files, reads their L0 abstract (compressed ~100 token summary) and their full content, then evaluates whether the abstract accurately represents the content. Reports fidelity scores and flags abstracts that have drifted from their source.

## Implementation
Runs: `cd engine && mix optimal.verify [--sample <n>]`

Process:
1. Sample N context files (default: 10).
2. Load L0 abstract for each.
3. Load full content for each.
4. Compare: does the abstract capture the key facts?
5. Score fidelity (0-1) per file.
6. Flag any below threshold (< 0.7).
7. Suggest re-generation for drifted abstracts.

## Examples
```bash
# Test 10 random contexts
/verify

# Test a larger sample
/verify --sample 20
```
