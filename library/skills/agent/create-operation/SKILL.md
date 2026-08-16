# /create-operation

> Define a new operation (a packaged workflow with agents, skills, and deliverables).

## Usage
```
/create-operation "<name>" --goal "<goal>" [--agents "<agent-list>"]
```

## What It Does
Creates an operation definition -- a reusable workflow that combines multiple agents and skills to achieve a specific outcome. Operations are the packaged units of work in the Workspace Protocol.

## Implementation
1. **Define goal** -- what the operation achieves when complete.
2. **Select agents** -- which agents participate and in what order.
3. **Map skills** -- which skills each agent uses.
4. **Define phases** -- sequential steps with inputs/outputs.
5. **Set deliverables** -- concrete artifacts the operation produces.
6. **Write definition** -- create `operations/<name>/OPERATION.md`.
7. **Validate** -- check all referenced agents and skills exist.

## Examples
```bash
# Create a feature delivery operation
/create-operation "feature-delivery" --goal "Ship a feature from spec to production" --agents "architect, backend-go, frontend-react, test-automator, devops-engineer"

# Create a knowledge maintenance operation
/create-operation "weekly-review" --goal "Friday review cycle" --agents "orchestrator"

# Create a client onboarding operation
/create-operation "client-onboard" --goal "Onboard new client from signup to first value"
```
