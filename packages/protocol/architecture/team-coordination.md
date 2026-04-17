# Team Coordination — Multi-Agent Orchestration

> Agents coordinate through **files, not APIs**. All state lives in JSON on the filesystem.
> Agents message each other through file-based inboxes. Tasks chain through dependency
> graphs with automatic unblocking. Git worktrees isolate parallel work. The result is
> a coordination layer with zero external dependencies — just the filesystem and git.

---

## Overview

Multi-agent coordination is a distributed systems problem. Most solutions reach for
databases, message brokers, or RPC frameworks. This architecture reaches for the
filesystem. Files are the database. Directories are message queues. Git branches
are isolation boundaries.

This works because agent coordination is low-throughput, high-latency by nature.
Agents think in seconds, not microseconds. The filesystem handles that fine. What
agents need is reliability, visibility, and debuggability — all things files excel at.

---

## Leader-Worker Hierarchy

Every team has exactly one leader and one or more workers. The leader decomposes
goals into tasks, assigns them, monitors progress, and synthesizes results. Workers
execute tasks and report back.

```
┌─────────────────────────────────────────┐
│              HUMAN                       │
│         (sets the goal)                  │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│          LEADER AGENT                    │
│                                          │
│  - Decomposes goal into tasks            │
│  - Assigns tasks to workers              │
│  - Monitors progress via task files      │
│  - Resolves blockers                     │
│  - Synthesizes results                   │
│  - Reports to human                      │
└────────┬──────────┬──────────┬──────────┘
         │          │          │
         ▼          ▼          ▼
    ┌─────────┐ ┌─────────┐ ┌─────────┐
    │ Worker  │ │ Worker  │ │ Worker  │
    │ Agent A │ │ Agent B │ │ Agent C │
    │         │ │         │ │         │
    │ Backend │ │Frontend │ │ Testing │
    └─────────┘ └─────────┘ └─────────┘
```

### Hierarchy Rules

| Rule | Rationale |
|------|-----------|
| **One leader per team** | Multiple leaders create conflicting task assignments. Single point of coordination. |
| **Workers report to leader only** | Workers don't coordinate with each other directly. All cross-worker communication goes through the leader or the task graph. |
| **Leader doesn't do worker tasks** | The leader decomposes and synthesizes. If the leader starts implementing, it loses oversight. Exception: teams of 1. |
| **Humans set goals, not tasks** | Humans describe outcomes. The leader decides the task decomposition. Micromanagement defeats the purpose. |

### "Agents Are Users" Inversion

The hierarchy is recursive. An agent can spawn and manage other agents the same way
a human manages agents. The spawning agent becomes the leader. The spawned agents
become workers. Humans just set the top-level goal.

```
Human → "Build the authentication system"
  │
  Leader → decomposes into:
    ├── Task 1: "Design auth API schema" → Worker A (API designer)
    ├── Task 2: "Implement JWT middleware" → Worker B (backend dev)
    ├── Task 3: "Write auth integration tests" → Worker C (test engineer)
    │
    Worker B → needs a subtask:
      └── Task 2.1: "Research JWT library options" → Sub-Worker (researcher)
```

---

## Filesystem as Database

All coordination state lives in JSON files. No SQLite, no Redis, no external services.

```
.team/
├── team.toml                    # Team definition (agents, roles, config)
├── agents/
│   ├── leader/
│   │   ├── agent.json           # Agent config (identity, adapter, capabilities)
│   │   ├── inbox/               # Messages TO this agent
│   │   │   ├── msg-001.json
│   │   │   └── msg-002.json
│   │   └── outbox/              # Messages FROM this agent (receipts)
│   │       └── msg-003.json
│   ├── worker-a/
│   │   ├── agent.json
│   │   ├── inbox/
│   │   └── outbox/
│   └── worker-b/
│       ├── agent.json
│       ├── inbox/
│       └── outbox/
├── tasks/
│   ├── task-001.json            # Task definitions with status, deps, assignee
│   ├── task-002.json
│   └── task-003.json
├── registry.json                # Spawn registry (PID/tmux tracking, liveness)
└── results/
    └── synthesis.md             # Leader's synthesized output
```

### Why Files?

| Property | Filesystem | Database |
|----------|-----------|----------|
| **Dependencies** | None (OS-provided) | Requires install, config, migration |
| **Debuggability** | `cat task-001.json` | Need client, query language |
| **Version control** | `git diff` | External changelog |
| **Portability** | Copy the directory | Export/import, schema compat |
| **Concurrency** | Atomic rename (see below) | Built-in but hidden |
| **Recovery** | Files are the backup | Need dump/restore |

---

## File-Based Inbox Messaging

Agents communicate through inbox directories. A message is a JSON file written to
the recipient's inbox. The sender writes to a temp file, then atomically renames it
into the inbox — preventing partial reads.

### Message Schema

```json
{
  "id": "msg-2026-03-20-001",
  "from": "leader",
  "to": "worker-a",
  "type": "task_assignment",
  "subject": "Implement JWT middleware",
  "body": {
    "taskId": "task-002",
    "priority": 1,
    "context": "Use RS256 algorithm. See task-001 output for schema."
  },
  "replyTo": null,
  "createdAt": "2026-03-20T16:00:00Z"
}
```

### Atomic Write Protocol

```
1. Writer creates temp file:     .team/agents/worker-a/inbox/.tmp-msg-001.json
2. Writer writes full content to temp file
3. Writer calls rename():        .tmp-msg-001.json → msg-001.json
4. Rename is atomic on all major filesystems
5. Reader only ever sees complete messages (no partial writes)
```

### Message Types

| Type | Direction | Purpose |
|------|-----------|---------|
| `task_assignment` | Leader → Worker | Assign a new task |
| `task_update` | Worker → Leader | Report progress, completion, or blocker |
| `question` | Worker → Leader | Ask for clarification |
| `answer` | Leader → Worker | Respond to question |
| `ping` | Any → Any | Wake check or attention request |
| `result` | Worker → Leader | Final deliverable for a task |
| `directive` | Leader → Worker | Priority change, scope adjustment, cancellation |

---

## Task Dependency Chains

Tasks can depend on other tasks. A task with unmet dependencies stays in `blocked`
status. When a dependency completes, the dependent task automatically moves to `ready`.

### Task Schema

```json
{
  "id": "task-002",
  "title": "Implement JWT middleware",
  "status": "blocked",
  "assignee": "worker-b",
  "priority": 1,
  "dependencies": ["task-001"],
  "dependents": ["task-003"],
  "description": "Implement RS256 JWT middleware for Express",
  "result": null,
  "createdAt": "2026-03-20T16:00:00Z",
  "startedAt": null,
  "completedAt": null
}
```

### Status Transitions

```
┌──────────┐     ┌─────────┐     ┌────────────┐     ┌───────────┐
│ CREATED  │────►│ BLOCKED │────►│   READY    │────►│IN_PROGRESS│
└──────────┘     └─────────┘     └────────────┘     └─────┬─────┘
                   ▲                                       │
                   │ (new dep added)              ┌────────┼────────┐
                   │                              ▼        ▼        ▼
                                            ┌──────┐ ┌────────┐ ┌────────┐
                                            │ DONE │ │ FAILED │ │BLOCKED │
                                            └──────┘ └────────┘ └────────┘
```

### Auto-Unblocking

When a task completes, the system scans all tasks that list it as a dependency.
If all dependencies are now `done`, the dependent task transitions to `ready` and
a `task_assignment` message is sent to the assignee's inbox.

```
task-001 completes
  → scan: task-002.dependencies includes "task-001"
  → check: all of task-002.dependencies are "done"?
  → yes: task-002.status = "ready"
  → send task_assignment to worker-b inbox
```

### File-Level Locking

For task status updates, agents use the atomic write protocol (tmp + rename).
Only the assignee or the leader can modify a task file. The leader arbitrates
all conflicts.

---

## Git Worktree Isolation

When agents modify code, they need isolation. Two agents editing the same branch
create merge conflicts. Git worktrees give each agent its own working directory
on its own branch, with zero conflicts during parallel work.

```
project/                          # Main working directory (leader)
├── .git/
├── src/
└── ...

project-worktrees/
├── worker-a/                     # git worktree on branch agent/worker-a
│   ├── src/                      # Full checkout, isolated branch
│   └── ...
├── worker-b/                     # git worktree on branch agent/worker-b
│   ├── src/
│   └── ...
└── worker-c/                     # git worktree on branch agent/worker-c
    ├── src/
    └── ...
```

### Workspace Isolation Modes

| Mode | Mechanism | When to Use |
|------|-----------|-------------|
| **Shared** | All agents work in the same directory | Non-code tasks (research, analysis, documentation) |
| **Worktree** | Each agent gets a git worktree on a dedicated branch | Code modification tasks (implementation, refactoring) |
| **Copy** | Each agent gets a full directory copy | Non-git projects or when worktrees aren't available |

### Worktree Lifecycle

```
1. Leader creates worktree:    git worktree add ../worker-a agent/worker-a
2. Worker operates in worktree: cd ../worker-a && <do work>
3. Worker commits to branch:    git add . && git commit
4. Leader merges when ready:    git merge agent/worker-a
5. Leader cleans up:            git worktree remove ../worker-a
```

---

## Team Templates

Teams are defined in TOML files. Templates encode repeatable team configurations
for common scenarios.

### Template Schema

```toml
[team]
name = "code-review"
description = "Code review team with lead reviewer and specialists"

[leader]
name = "lead-reviewer"
role = "Lead Code Reviewer"
adapter = "claude-code"
model = "opus"
system_prompt = "You are a senior code reviewer. Decompose review into focused areas."

[[worker]]
name = "security-reviewer"
role = "Security Specialist"
adapter = "claude-code"
model = "sonnet"
system_prompt = "Review for OWASP Top 10 vulnerabilities, auth issues, injection risks."

[[worker]]
name = "performance-reviewer"
role = "Performance Specialist"
adapter = "claude-code"
model = "sonnet"
system_prompt = "Review for N+1 queries, memory leaks, algorithmic complexity."

[[worker]]
name = "style-reviewer"
role = "Style & Convention Reviewer"
adapter = "claude-code"
model = "haiku"
system_prompt = "Review for naming conventions, code organization, documentation."
```

### Built-In Templates

| Template | Leader | Workers | Purpose |
|----------|--------|---------|---------|
| `software-dev` | Architect | Backend, Frontend, Testing | Feature implementation |
| `code-review` | Lead Reviewer | Security, Performance, Style | Multi-angle code review |
| `research` | Research Lead | Domain Expert, Data Analyst, Writer | Research and synthesis |
| `hedge-fund` | Portfolio Manager | Analyst, Risk, Quantitative | Financial analysis |
| `debug` | Lead Debugger | Reproducer, Isolator, Fixer | Systematic bug resolution |

---

## Auto-Injected Coordination Prompts

When the leader spawns a worker, it auto-injects coordination context into the
worker's system prompt. The worker doesn't need to be told how to communicate —
the protocol is baked in at spawn time.

### Injected Context

```
You are {agent.name}, a {agent.role} on team "{team.name}".

Your leader is {leader.name}. Report all progress to your leader.

Your workspace is: {workspace_path}
Your inbox is: {inbox_path}

Available commands:
  - Read inbox: check {inbox_path}/ for new messages
  - Send message: write JSON to {leader.inbox_path}/
  - Update task: modify {tasks_path}/{task_id}.json

Current task: {task.title}
Task description: {task.description}
Dependencies: {task.dependencies}

When you complete your task:
1. Write results to {results_path}/{task_id}.md
2. Update task status to "done" in {tasks_path}/{task_id}.json
3. Send a task_update message to leader's inbox
```

---

## Liveness Detection

The leader needs to know if workers are alive. The spawn registry tracks process
state for all spawned agents.

### Registry Schema

```json
{
  "agents": {
    "worker-a": {
      "pid": 42381,
      "tmuxTarget": "team:worker-a",
      "spawnedAt": "2026-03-20T16:00:00Z",
      "lastHeartbeat": "2026-03-20T16:05:00Z",
      "status": "alive"
    },
    "worker-b": {
      "pid": 42395,
      "tmuxTarget": "team:worker-b",
      "spawnedAt": "2026-03-20T16:00:30Z",
      "lastHeartbeat": "2026-03-20T16:04:45Z",
      "status": "alive"
    }
  }
}
```

### Liveness Check

```
For each agent in registry:
  1. Check PID exists:     kill -0 {pid}
  2. Check tmux target:    tmux has-session -t {tmuxTarget}
  3. Check heartbeat age:  now - lastHeartbeat < threshold (default: 5 min)

  All pass → status: "alive"
  PID gone → status: "dead" (process crashed)
  Heartbeat stale → status: "unresponsive" (may be stuck)
```

### Recovery Actions

| Status | Leader Action |
|--------|-------------|
| `alive` | No action needed |
| `dead` | Reassign task, respawn agent if retries remain |
| `unresponsive` | Send ping message, wait one cycle, then treat as dead |

---

## Transport Layer

The default transport is filesystem-based. For scenarios requiring lower latency
or cross-machine coordination, ZeroMQ provides a P2P alternative with file fallback.

| Transport | Latency | Reliability | Dependencies |
|-----------|---------|-------------|-------------|
| **File (default)** | ~100ms (filesystem poll) | High (atomic rename) | None |
| **ZeroMQ P2P** | ~1ms | Medium (network dependent) | libzmq |
| **ZeroMQ + file fallback** | ~1ms normal, ~100ms degraded | High (fallback on failure) | libzmq (optional) |

### Transport Selection

```
If agents are on same machine → File transport (no dependencies)
If agents are on different machines → ZeroMQ with file fallback
If libzmq not available → File transport (always works)
```

File transport polls inbox directories on the heartbeat cycle. ZeroMQ pushes
messages directly to a socket, with a file write as fallback if the socket
is unreachable.

---

## Invariant Rules

| Rule | Rationale |
|------|-----------|
| **All state in files** | No in-memory-only coordination state. If the leader crashes and restarts, it can reconstruct the full team state from the filesystem. |
| **Atomic writes only** | All file mutations use tmp + rename. Partial writes corrupt state. |
| **Leader arbitrates conflicts** | Two workers cannot both modify the same task file. The leader resolves all contention. |
| **Messages are immutable** | Once written to an inbox, a message is never modified. Send a new message to correct or supersede. |
| **Worktrees are disposable** | A worktree can be deleted and recreated at any time. All durable state is in the task files and results directory, not the worktree. |
| **Templates are starting points** | Teams can be modified after creation. Templates encode defaults, not constraints. |

---

## Related Docs

- [heartbeat.md](heartbeat.md) — Execution cycle each agent follows within the team
- [tasks.md](tasks.md) — Task schema that team task files extend
- [governance.md](governance.md) — Cross-team delegation and escalation rules
- [workspaces.md](workspaces.md) — Workspace resolution for agent working directories
- [sessions.md](sessions.md) — Session persistence across agent restarts
- [peer-protocol.md](peer-protocol.md) — Horizontal coordination layer: handoffs, review gates, negotiation, and file locking that extend the leader-worker model laterally
- [context-mesh.md](context-mesh.md) — Per-team context keeper: the persistent nervous system that stores shared in-flight context across all agents on a team
- [decision-graph.md](decision-graph.md) — DAG-structured decision tracking: leaders create decision nodes when decomposing goals; the graph holds the team's decision memory
- [conversations.md](conversations.md) — Structured multi-agent dialogue for brainstorms, design reviews, red teams, and user panels within the team
- [self-healing.md](self-healing.md) — Autonomous error recovery: when agents in the team fail, healing episodes restore viability without routing through the leader

---

*Team Coordination v1.0 — Filesystem-native multi-agent orchestration with zero external dependencies*
