---
name: create-spec
description: >
  Guided spec creation through 9 phases from discovery to testing strategy.
  Supports spec types: library, feature, change. Produces a complete
  specification document with requirements, architecture, constraints, and
  YAML test data. Interactive or autonomous modes.
  Triggers on: "create spec", "write spec", "spec out", "specification", "design document"
---

# /create-spec

> Guided specification creation through 9 structured phases.

## Purpose

Create a complete, implementation-ready specification document by walking through 9 phases: discovery, context gathering, requirements, constraints, architecture, interfaces, error handling, testing strategy, and final assembly. Supports three spec types (library, feature, change) with type-specific templates. Produces YAML test data alongside the spec for immediate TDD usage.

## Usage

```bash
# Interactive guided mode (asks questions at each phase)
/create-spec --type feature

# Autonomous mode with initial description
/create-spec --type library --description "HTTP client with retry and circuit breaking"

# Create a change spec for an existing system
/create-spec --type change --scope lib/auth/ --description "Add OAuth2 PKCE flow"

# Resume an in-progress spec
/create-spec --resume

# Generate only the test data from an existing spec
/create-spec --tests-only --from specs/auth-spec.md
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--type` | enum | `feature` | Spec type: `library`, `feature`, `change` |
| `--description` | string | — | Initial description (skips discovery questions) |
| `--scope` | string | `.` | Files or directories the spec covers |
| `--interactive` | flag | true | Ask clarifying questions at each phase |
| `--resume` | flag | false | Resume an in-progress spec session |
| `--output` | string | `specs/<name>-spec.md` | Output path for the spec document |
| `--tests-only` | flag | false | Generate YAML test data from an existing spec |
| `--from` | string | — | Path to existing spec (for `--tests-only`) |
| `--format` | enum | `markdown` | Output format: `markdown`, `json` |

## Workflow

### Phase 1: Discovery
Understand what is being built. Clarify the problem statement, who it serves, and what success looks like. Output: problem statement + success criteria.

### Phase 2: Context Gathering
Read existing codebase, related specs, and documentation. Identify prior art, patterns in use, and conventions to follow. Output: context summary + relevant file list.

### Phase 3: Requirements
Extract functional and non-functional requirements. Number each requirement. Mark as MUST, SHOULD, or MAY (RFC 2119). Output: numbered requirements list.

### Phase 4: Constraints
Define what is explicitly out of scope, what cannot change, performance budgets, and compatibility requirements. Output: constraints list.

### Phase 5: Architecture
Design the high-level structure. Module boundaries, data flow, state management, external dependencies. Diagrams where helpful. Output: architecture section with module list.

### Phase 6: Interfaces
Define public APIs, function signatures, message formats, and protocols. Include types and example payloads. Output: interface definitions.

### Phase 7: Error Handling
Enumerate failure modes, error types, recovery strategies, and degradation behavior. Output: error catalogue with handling strategy for each.

### Phase 8: Testing Strategy
Define test categories (unit, integration, e2e), coverage targets, and generate YAML test data with inputs, expected outputs, and edge cases. Output: test plan + YAML test data file.

### Phase 9: Assembly
Compile all phases into a single spec document. Add table of contents, cross-references, and review checklist. Output: final spec file.

## Examples

### Creating a feature spec
```
/create-spec --type feature --description "Real-time notification system with WebSocket delivery"

## Spec — Real-time Notification System

### Phase 1: Discovery
- Problem: Users miss time-sensitive updates because they rely on polling
- Success: Notifications delivered within 500ms of event, 99.9% delivery rate

### Phase 3: Requirements
1. [MUST] Deliver notifications via WebSocket to connected clients
2. [MUST] Queue notifications for offline users, deliver on reconnect
3. [SHOULD] Support notification preferences (mute, channels)
4. [MAY] Support push notifications as fallback channel
...

### Phase 8: Test Data (tests/notification_spec_data.yaml)
```yaml
scenarios:
  - name: "online user receives notification"
    setup: { user: "u1", connected: true }
    input: { event: "message.new", payload: { from: "u2", text: "hello" } }
    expected: { delivered: true, latency_ms: "<500", channel: "websocket" }
  - name: "offline user receives on reconnect"
    setup: { user: "u1", connected: false, queue: [] }
    input: { event: "message.new", payload: { from: "u2", text: "hello" } }
    then: { action: "reconnect", user: "u1" }
    expected: { delivered: true, queue_size: 0 }
```

## Output

```markdown
## Specification: <Name>

### Meta
- Type: feature | library | change
- Author: <agent>
- Date: <date>
- Status: draft

### Table of Contents
1. Discovery
2. Context
3. Requirements
4. Constraints
5. Architecture
6. Interfaces
7. Error Handling
8. Testing Strategy

### [Each phase section...]

### Review Checklist
- [ ] All MUST requirements have acceptance criteria
- [ ] Architecture diagram reviewed
- [ ] Error handling covers all failure modes
- [ ] Test data covers happy path + edge cases
- [ ] Constraints are realistic and measurable
```

## Dependencies

- File system access to read existing code and write spec output
- `/test` — Optional integration for running generated test data
- `/tdd` — Companion skill for implementing against the spec
- Project guidelines for convention detection (Phase 2)
