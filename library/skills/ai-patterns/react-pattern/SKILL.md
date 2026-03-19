---
name: react-pattern
description: "Thought-Action-Observation loop for transparent reasoning"
trigger: "always"
priority: 3
dynamic: false
created: "2026-01-26"
---

# ReAct Pattern

Thought → Action → Observation loop for transparent reasoning and reduced hallucination.

## Activation

Activates on:
- Multi-step tasks
- Research tasks
- Debugging sessions
- Complex problem solving

## Process

### Loop Structure

```
THOUGHT: What do I need to do next?
ACTION: [tool_name] with [parameters]
OBSERVATION: [result of action]
... repeat until task complete ...
THOUGHT: Task complete because [reasoning]
```

### Guidelines

1. **Thought**: Explicit reasoning about next step
   - What information do I need?
   - What's the best tool for this?
   - What could go wrong?

2. **Action**: Execute one tool call
   - Use the most specific tool
   - Provide complete parameters
   - Prefer specialized tools over Bash

3. **Observation**: Analyze the result
   - Did I get what I expected?
   - Is there an error to handle?
   - What did I learn?

### Benefits

- **Transparency**: Reasoning is visible
- **Debuggability**: Each step is traceable
- **Reduced Hallucination**: Actions ground in reality
- **Learning**: Patterns can be extracted

## Integration

Works with:
- All agent workflows
- Memory system (captures thoughts)
- Learning engine (extracts patterns)
- Verification (traces reasoning)

## Anti-Patterns

Avoid:
- Skipping thoughts before actions
- Multiple actions without observations
- Ignoring error observations
- Concluding without final verification

---

*Based on ReAct: Synergizing Reasoning and Acting in Language Models*
