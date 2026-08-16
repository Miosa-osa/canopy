---
name: inbox
description: >
  Point-to-point messaging between agents. Send, broadcast, receive, and peek at
  messages. File-based implementation using JSON in inbox directories with atomic
  writes. Includes event log for full message history. The communication backbone.
  Triggers on: "inbox", "message", "send to", "broadcast", "check messages"
---

# /inbox

> Point-to-point messaging between agents.

## Purpose

The communication backbone for multi-agent coordination. Every agent has an inbox directory. Messages are JSON files written atomically (write to temp, then rename — no partial reads). Supports direct messages, broadcasts, and reply chains. Full event log for debugging coordination issues.

## Usage

```bash
# Send a message to an agent
/inbox send researcher "Found the pricing data — check money-revenue/context.md"

# Broadcast to all agents
/inbox broadcast "Standup in 5 minutes — report your status"

# Check your inbox
/inbox receive

# Peek at an agent's inbox (read without consuming)
/inbox peek researcher

# Check inbox with filter
/inbox receive --type task --unread

# View message history
/inbox log --last 20

# Reply to a message
/inbox reply msg-a1b2c3 "Acknowledged, starting now"

# Clear processed messages
/inbox clear --before 2026-03-19
```

## Arguments

| Subcommand | Description |
|------------|-------------|
| `send <target> <message>` | Send a direct message to a specific agent |
| `broadcast <message>` | Send to all registered agents |
| `receive` | Read and consume messages from your inbox |
| `peek <target>` | Read an agent's inbox without consuming |
| `reply <msg-id> <message>` | Reply to a specific message (maintains thread) |
| `log` | View message event log |
| `clear` | Remove processed messages |

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--type` | enum | `all` | Filter: `task`, `status`, `result`, `error`, `info` |
| `--unread` | flag | false | Only show unread messages |
| `--last` | int | 10 | Number of log entries to show |
| `--before` | date | — | Clear messages before this date |
| `--format` | enum | `pretty` | `pretty`, `json`, `raw` |
| `--priority` | enum | `normal` | Message priority: `urgent`, `normal`, `low` |
| `--thread` | string | — | Thread ID to filter by |

## Workflow

### Sending
1. **Resolve target** — Look up agent by name or ID in the registry. Verify agent is running.
2. **Compose message** — Create JSON envelope: `{id, from, to, type, priority, thread, timestamp, body}`.
3. **Atomic write** — Write to temp file in target's inbox dir, then `rename()` to final path. This guarantees no partial reads.
4. **Log** — Append send event to the shared event log.
5. **Acknowledge** — Return message ID and delivery confirmation.

### Receiving
1. **Scan inbox** — List all `.json` files in own inbox directory, sorted by timestamp.
2. **Filter** — Apply type, unread, and priority filters.
3. **Read** — Parse and display messages. Mark as read (rename with `.read` suffix or move to `processed/`).
4. **Return** — Display messages in requested format.

## Output

### Send confirmation
```
Message sent: msg-2026-03-20-143500-a1b2
  To: researcher
  Type: info
  Priority: normal
  Thread: new
```

### Receive output
```markdown
## Inbox (3 unread)

### 1. From: orchestrator | 14:30 | urgent | task
> Analyze Q1 revenue data and produce summary by EOD.
> Context: money-revenue/context.md, money-revenue/signals/q1-*.md
> Reply to: msg-2026-03-20-143000-d4e5

### 2. From: writer | 14:32 | normal | info
> Draft pitch deck is ready for review at processed/pitch-v1.md

### 3. From: analyst | 14:35 | normal | result
> Revenue analysis complete. Key finding: 23% MoM growth.
> Full report: processed/q1-revenue-report.md
```

### Message JSON format
```json
{
  "id": "msg-2026-03-20-143500-a1b2",
  "from": "orchestrator",
  "to": "researcher",
  "type": "task",
  "priority": "urgent",
  "thread": "thread-revenue-analysis",
  "timestamp": "2026-03-20T14:35:00Z",
  "body": "Analyze Q1 revenue data and produce summary by EOD.",
  "context": ["money-revenue/context.md"],
  "reply_to": null
}
```

## Dependencies

- Agent registry (for resolving agent names to inbox paths)
- File system with atomic rename support
- Shared event log file (append-only)
