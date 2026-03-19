# Adapters — Runtime Adapter Interface

> The pluggable bridge between the control plane and agent execution environments.
> An adapter defines HOW an agent runs. The control plane defines WHEN and WHY.
> Any runtime — Claude, Codex, Cursor, a Python script, a webhook — can be an adapter.

---

## Overview

The adapter pattern solves vendor lock-in. Without it, the control plane would be
hardcoded to one runtime. With adapters, the same heartbeat protocol drives Claude Code,
Codex, Cursor, Gemini, a generic shell process, or a remote webhook — all through
the same interface.

Each adapter type has a **three-module architecture**:
1. **Server module** — Execution logic (`invoke`, `status`, `cancel`)
2. **UI module** — Transcript parsing (convert raw output to structured display)
3. **CLI module** — Output formatting (terminal-friendly rendering of results)

---

## Standard Interface

Every adapter implements exactly three methods. This is the full contract.

```typescript
interface Adapter {
  invoke(config: AdapterConfig, context?: AdapterExecutionContext): Promise<void>;
  status(config: AdapterConfig): Promise<AgentStatus>;
  cancel(config: AdapterConfig): Promise<void>;
}
```

| Method | Purpose | Required |
|--------|---------|----------|
| `invoke` | Start the agent's execution cycle. Fire-and-forget or synchronous — adapter decides. | Yes |
| `status` | Check current state: running, finished, errored, idle. Used by dashboard and orphan detection. | Yes |
| `cancel` | Send graceful termination signal. Used by board pause and budget breach. | Yes |

### AgentStatus Return

```typescript
type AgentStatus = {
  state: "running" | "idle" | "finished" | "errored";
  exitCode?: number;
  signal?: string;
  error?: string;
  pid?: number;           // For local process adapters
  externalRunId?: string; // For gateway adapters
};
```

Everything beyond these three methods (cost reporting, task updates, session state)
flows through the REST API. Adapters do not implement those — agents call
the API directly if instrumented.

---

## AdapterExecutionContext (What Goes In)

The context object passed to `invoke`. Contains everything the adapter needs to
start the agent.

```typescript
interface AdapterExecutionContext {
  // Identity
  agentId: string;
  companyId: string;
  runId: string;

  // Task context
  taskId?: string;
  taskKey?: string;
  issueId?: string;
  wakeReason: string;
  wakeSource: string;

  // Session
  sessionParams?: Record<string, unknown>;  // Deserialized prior session
  forceFreshSession: boolean;
  handoffNote?: string;                     // From session compaction

  // Workspace
  cwd: string;                              // Resolved working directory
  workspaceId?: string;
  repoUrl?: string;
  repoRef?: string;

  // Budget
  budgetRemainingUsd?: number;
  budgetPercentUsed?: number;

  // Payload mode
  deliveryMode: "thin" | "fat";
  fatPayload?: Record<string, unknown>;     // Only if deliveryMode = "fat"

  // API access (for thin mode)
  apiUrl: string;
  apiKey: string;
}
```

### AdapterExecutionResult (What Comes Out)

The result captured after adapter execution completes:

```typescript
interface AdapterExecutionResult {
  exitCode: number;
  signal?: string;
  error?: string;
  errorCode?: string;

  // Token usage
  usage?: {
    inputTokens: number;
    cachedInputTokens: number;
    outputTokens: number;
    costUsd: number;
  };

  // Session state for persistence
  sessionState?: Record<string, unknown>;

  // Structured result (adapter-specific)
  result?: Record<string, unknown>;

  // Log capture
  stdout?: string;     // Truncated to last N bytes
  stderr?: string;
  logBytes?: number;
}
```

---

## The 9 Adapter Types

### Local Process Adapters

These spawn a child process on the same machine as the control plane.

| Adapter | ID | What It Spawns | Session Support |
|---------|-----|---------------|----------------|
| OSA Native | `osa` | OSA agent runtime with full engine access | Full |
| Claude Code | `claude_local` | `claude` CLI process | Full (session resume via `--session-id`) |
| Codex | `codex_local` | OpenAI Codex CLI | Full |
| Cursor | `cursor` | Cursor headless mode | Full |
| Gemini | `gemini_local` | Gemini CLI with sandbox and approval | Full |
| OpenCode | `opencode_local` | OpenCode CLI | Full |
| Pi | `pi_local` | Pi CLI process | Full |
| Generic Process | `process` | Any executable (`python`, `node`, etc.) | None (stateless) |

All sessioned local adapters share:
- Session serialize/deserialize via adapter session codec
- Working directory resolution
- Environment variable injection
- Stdout/stderr streaming to run log

### Gateway Adapters

These call a remote API to trigger agent execution.

| Adapter | ID | Mechanism |
|---------|-----|-----------|
| OpenClaw Gateway | `openclaw_gateway` | POST to OpenClaw API with agent config |
| HTTP Webhook | `http` | POST to any URL with configurable payload |

Gateway adapters provide limited instrumentation — the remote agent must call back
to the control plane API for cost reporting and task updates.

### Fallback Behavior

When an unknown adapter type is encountered, the system falls back to the `process`
adapter. The adapter type string is treated as the command to execute. This enables
quick prototyping without formal adapter registration.

---

## Native Context Management Classification

Adapters are classified by how well they manage their own context window:

| Classification | Description | Adapters |
|---------------|-------------|----------|
| `confirmed` | Adapter has verified, built-in context management (session resume, compaction) | `claude_local`, `cursor` |
| `likely` | Adapter probably manages context but not verified | `codex_local`, `gemini_local` |
| `unknown` | Context management capabilities not known | `opencode_local`, `pi_local` |
| `none` | No context management — stateless execution | `process`, `http` |

This classification drives session compaction policy. Adapters with `confirmed` context
management get longer compaction thresholds (they handle their own window). Adapters
with `none` get aggressive compaction or no sessions at all.

---

## Three-Module Architecture

Each adapter type consists of three modules:

### Server Module (Execution)

Implements the three-method interface. Handles process spawning, environment setup,
signal handling, and result capture.

```
claude_local/server.ts
  ├── invoke()  → spawn `claude` process with --session-id, --model, etc.
  ├── status()  → check process liveness via PID
  └── cancel()  → send SIGTERM, wait grace period, SIGKILL
```

### UI Module (Transcript Parsing)

Converts raw adapter output into structured display format for the dashboard.
Parses tool calls, reasoning blocks, code output into renderable components.

```
claude_local/ui.ts
  ├── parseTranscript(raw) → structured turns
  ├── extractToolCalls(raw) → tool invocation list
  └── formatForDisplay(raw) → React-renderable components
```

### CLI Module (Output Formatting)

Formats adapter results for terminal display. Handles color coding, truncation,
progress indicators.

```
claude_local/cli.ts
  ├── formatRunStart(context) → "Starting claude on LUN-042..."
  ├── formatRunProgress(event) → streaming output with syntax highlighting
  └── formatRunEnd(result) → "Completed in 45s, 12K tokens, $0.03"
```

---

## Registration

New adapters register in **three registries**:

| Registry | Purpose | What's Registered |
|----------|---------|------------------|
| **Adapter Registry** | Runtime resolution | Server module (invoke/status/cancel) |
| **UI Registry** | Dashboard rendering | UI module (transcript parsing) |
| **CLI Registry** | Terminal formatting | CLI module (output formatting) |

```typescript
// Full adapter registration
registerAdapter({
  type: "my_custom_adapter",

  // Server module
  invoke: async (config, context) => { /* start agent */ },
  status: async (config) => { /* check agent */ },
  cancel: async (config) => { /* stop agent */ },

  // Session codec (optional)
  sessionCodec: {
    serialize: (params) => { /* ... */ },
    deserialize: (raw) => { /* ... */ },
    getDisplayId: (params) => { /* ... */ },
  },

  // Context management classification
  contextManagement: "confirmed" | "likely" | "unknown" | "none",
});
```

The heartbeat service resolves the adapter at invocation time via
`getServerAdapter(adapterType)`.

---

## Context Delivery Modes

Configurable per agent. Controls how much context is bundled into the wake invocation.

### Fat Payload

The control plane bundles everything the agent needs:

```json
{
  "agent": { "id": "...", "name": "...", "role": "..." },
  "task": { "id": "LUN-042", "title": "...", "description": "...", "status": "todo" },
  "company": { "name": "...", "mission": "..." },
  "inbox": [ /* assigned tasks + recent comments */ ],
  "session": { /* serialized conversation state */ },
  "budget": { "remaining_usd": 42.50, "percent_used": 0.65 },
  "org": { /* reporting structure, peer agents */ },
  "wake": { "reason": "assignment", "source": "system" }
}
```

**Best for:** Simple agents, stateless agents, agents that cannot call back to the API.

### Thin Ping

The control plane sends only a wake signal with minimal context:

```json
{
  "agent_id": "agent-abc",
  "run_id": "run-xyz",
  "wake_reason": "assignment",
  "task_id": "LUN-042",
  "api_url": "https://osa.local/api",
  "api_key": "pk_..."
}
```

The agent calls the API to fetch whatever it needs. More efficient for sophisticated
agents that manage their own context window.

**Best for:** Fully instrumented agents, agents with large context needs, agents
that want to control their own loading strategy.

---

## Integration Levels

Adapters and agents can operate at three levels of integration:

```
Level 1: CALLABLE (minimum)
  │  Control plane can invoke you. That's it.
  │  No reporting, no feedback, no cost tracking.
  │
  ▼
Level 2: STATUS REPORTING
  │  Agent reports success/failure/in-progress.
  │  Control plane can show run status in dashboard.
  │
  ▼
Level 3: FULLY INSTRUMENTED
     Agent reports status, cost/token usage, task updates,
     session state, and logs. Full bidirectional integration.
```

| Capability | Level 1 | Level 2 | Level 3 |
|------------|---------|---------|---------|
| Invocable | Yes | Yes | Yes |
| Status visible | Process liveness only | Agent-reported | Agent-reported |
| Cost tracking | None | None | Per-run token + dollar |
| Task management | None | None | Create, update, complete via API |
| Session persistence | None | None | Full serialize/deserialize |
| Run logs | Stdout capture | Stdout + status | Full structured logs |

---

## Session Codec

Each adapter type can define a session codec — the serialization contract for
conversation state that enables cross-run continuity.

```typescript
interface AdapterSessionCodec {
  serialize(params: Record<string, unknown> | null): Record<string, unknown> | null;
  deserialize(raw: unknown): Record<string, unknown> | null;
  getDisplayId(params: Record<string, unknown> | null): string | null;
}
```

| Method | Purpose |
|--------|---------|
| `serialize` | Convert live session state to storable format (called at run end) |
| `deserialize` | Convert stored format back to live state (called at run start) |
| `getDisplayId` | Extract a human-readable session identifier for the UI |

### Default Codec

If an adapter does not define a codec, the default passes through JSON objects
and extracts `sessionId` as the display ID.

---

## Environment Variables

The control plane injects these into every local adapter invocation:

| Variable | Value | Purpose |
|----------|-------|---------|
| `AGENT_ID` | Agent UUID | Identify the agent |
| `COMPANY_ID` | Company UUID | Scope API calls |
| `API_URL` | Control plane URL | API endpoint |
| `API_KEY` | Agent JWT | Authenticate API calls |
| `RUN_ID` | Run UUID | Correlate with run record |
| `TASK_ID` | Task ID (if applicable) | Current task |
| `WAKE_REASON` | Wake reason string | Why the agent woke |

Additional env vars configured per-agent. Secrets resolved at invocation time
from the secrets service (never stored in adapter config).

---

## Adapter Config Examples

### claude_local

```yaml
adapter_config:
  model: "claude-sonnet-4-20250514"
  prompt_template: "SYSTEM.md"
  max_turns: 50
  allowed_tools: ["Read", "Write", "Bash", "Grep"]
  working_directory: "/path/to/workspace"
  env:
    CUSTOM_VAR: "value"
```

### process (Generic Shell)

```yaml
adapter_config:
  command: "python"
  args: ["run_agent.py", "--agent-id", "{AGENT_ID}"]
  working_directory: "/path/to/agent"
  env:
    PYTHONPATH: "/opt/agents/lib"
  timeout_seconds: 3600
```

### http (Webhook)

```yaml
adapter_config:
  url: "https://hooks.example.com/agent/{AGENT_ID}"
  method: "POST"
  headers:
    Authorization: "Bearer {API_KEY}"
    Content-Type: "application/json"
  payload_template: |
    {"agent_id": "{AGENT_ID}", "task": "{TASK_ID}"}
  timeout_seconds: 300
```

### openclaw_gateway

```yaml
adapter_config:
  gateway_url: "https://openclaw.example.com"
  gateway_key: "secret:openclaw-key"
  soul_md: "..."
  heartbeat_md: "..."
```

---

## Related Docs

- [heartbeat.md](heartbeat.md) — The execution cycle that invokes adapters
- [sessions.md](sessions.md) — Session codec and persistence details
- [workspaces.md](workspaces.md) — How working directories are resolved
- [budgets.md](budgets.md) — Cost tracking per adapter invocation

---

*Adapter System v2.0 — Runtime bridge specifications with three-module architecture*
