# /analyze

> Deep analysis on a topic. Analyst-owned.

## Usage
```
/analyze <topic> [--depth <surface|deep>] [--compare <a,b>]
```

## What It Does
Conducts structured analysis: frames the question, gathers data, identifies patterns,
and produces a recommendation with confidence level.

## Implementation
1. **Frame** — Define the question and success criteria.
2. **Gather** — Search knowledge base, reference files, external data.
3. **Analyze** — Pattern identification, gap analysis, risk assessment.
4. **Compare** — If `--compare`, structured comparison table.
5. **Recommend** — Clear recommendation with confidence and rationale.

## Examples
```bash
/analyze "pricing model options" --depth deep
/analyze "framework selection" --compare "React,Svelte,Vue"
/analyze "market positioning" --depth surface
```
