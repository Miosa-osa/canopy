# Workspace Management

> Where agents do their work. A workspace is the directory context for an agent's
> execution — it determines which files, repos, and tools are available during a run.

---

## Workspace Resolution Priority

When an agent wakes up, the heartbeat resolves its working directory in this order:

```
1. Project Workspace    ← Git checkout managed by the control plane
   (if task has a project with a configured workspace)
       │
       │ not available
       ▼
2. Task Session Workspace  ← Where the session was last active
   (if prior session recorded a workspace)
       │
       │ not available
       ▼
3. Agent Home Directory    ← Fallback: agent's personal workspace
   (always available)
```

### Resolution Output

```typescript
type ResolvedWorkspaceForRun = {
  cwd: string;                  // Resolved working directory path
  source: "project_primary"     // From project workspace config
        | "task_session"        // From prior session state
        | "agent_home";         // Fallback to agent home
  projectId: string | null;     // Associated project
  workspaceId: string | null;   // Workspace record ID
  repoUrl: string | null;       // Git remote URL
  repoRef: string | null;       // Git ref (branch, tag, SHA)
  workspaceHints: Array<{       // All available project workspaces
    workspaceId: string;
    cwd: string | null;
    repoUrl: string | null;
    repoRef: string | null;
  }>;
  warnings: string[];           // Any resolution issues
};
```

---

## Project Workspaces

Projects can have one or more configured workspaces. Each workspace is a directory
(usually a git checkout) that agents use when working on that project's tasks.

### Workspace Configuration

```
project_workspaces table
  ├── id             (uuid)
  ├── company_id     (uuid)
  ├── project_id     (uuid)
  ├── cwd            (string)     ← Absolute path to workspace root
  ├── repo_url       (string)     ← Git remote URL (optional)
  ├── repo_ref       (string)     ← Git branch/ref (optional)
  ├── created_at     (timestamp)
  └── updated_at     (timestamp)
```

### Managed vs Manual Workspaces

| Type | How Created | Lifecycle |
|------|------------|-----------|
| **Managed** | Control plane clones repo automatically | Control plane manages checkout |
| **Manual** | Human sets `cwd` to existing directory | Human manages the directory |

### Managed Workspace Clone

When a project has a `repo_url` and no local checkout exists:

```
1. Derive repo name from URL (strip .git suffix, take last path segment)
2. Resolve target path: {managed_workspace_root}/{companyId}/{projectId}/{repoName}
3. mkdir parent directories
4. git clone {repo_url} {target_path}
   - Timeout: 10 minutes (MANAGED_WORKSPACE_GIT_CLONE_TIMEOUT_MS)
   - Environment sanitized (no host shell state leakage)
5. Return { cwd: target_path, warning: null }
```

### Clone Failure Handling

| Failure | Response |
|---------|----------|
| Network timeout (>10min) | Error thrown, run uses fallback workspace |
| Auth failure | Error thrown, logged with details |
| Path already exists (non-git) | Warning: "path exists but is not a git checkout. Using as-is." |
| Path exists but empty | Remove and re-clone |

### Multiple Workspaces Per Project

A project can have multiple workspaces (e.g., main repo + docs repo). When multiple
exist, selection priority is:

1. **Issue-preferred workspace** — The workspace ID stored on the issue (if set)
2. **Context-specified workspace** — Workspace ID in the wake context snapshot
3. **First created** — Oldest workspace (creation order)

The `prioritizeProjectWorkspaceCandidatesForRun` function reorders the list to put
the preferred workspace first.

---

## Execution Workspaces

For isolation, agents can work in **execution workspaces** — temporary, per-run
directories derived from the project workspace.

### Isolation Modes

| Mode | Description | When to Use |
|------|-------------|-------------|
| **Shared** | Agent works directly in the project workspace | Default. Simple. Agents share files. |
| **Worktree** | Git worktree created per run | When agents need isolated branches |
| **Copy** | Full directory copy per run | When agents need complete isolation |

### Execution Workspace Lifecycle

```
Run starts
  │
  ├── Mode: shared → Use project workspace directly
  │
  ├── Mode: worktree
  │    → git worktree add {run-dir} {branch}
  │    → Agent works in worktree
  │    → Run ends → cleanup worktree
  │
  └── Mode: copy
       → cp -r {project-workspace} {run-dir}
       → Agent works in copy
       → Run ends → cleanup copy
```

### Execution Workspace Policy

Configured per-project and optionally per-issue:

```yaml
# Project-level policy
execution_workspace:
  mode: shared | worktree | copy
  cleanup_on_completion: true
  branch_naming: "agent/{agent-id}/{run-id}"

# Issue-level override
assignee_overrides:
  adapter_config: { ... }
  use_project_workspace: true | false
```

---

## Agent Home Directory

Every agent has a personal home directory that serves as the ultimate fallback.

```
{agent_home_root}/{agent-id}/
```

This directory is:
- Always available (created at agent creation time)
- Used when no project workspace exists
- Used when workspace resolution fails
- The agent's "desk" — personal files, notes, scratch space

---

## Runtime Services

Workspaces can have associated runtime services that start and stop with each run.

### Service Types

| Service | Purpose |
|---------|---------|
| MCP servers | Model Context Protocol servers for tool access |
| Language servers | LSP servers for code intelligence |
| Custom processes | Any workspace-specific background processes |

### Service Lifecycle

```
Run starts
  → Ensure runtime services for workspace
    → Start MCP servers (if configured)
    → Start language servers (if configured)
    → Inject service endpoints into adapter environment

Run ends
  → Release runtime services
    → Stop MCP servers
    → Stop language servers
    → Cleanup temporary files
```

### Service Configuration

Runtime services are configured per-workspace in the adapter config:

```yaml
runtime_services:
  mcp:
    - name: "filesystem"
      command: "npx @modelcontextprotocol/server-filesystem"
      args: ["{workspace_cwd}"]
    - name: "github"
      command: "npx @modelcontextprotocol/server-github"
      env:
        GITHUB_TOKEN: "secret:github-token"
  language_servers:
    - name: "typescript"
      command: "typescript-language-server"
      args: ["--stdio"]
```

---

## Workspace Artifacts Cleanup

After a run completes, temporary artifacts are cleaned up:

| Artifact | Cleanup Rule |
|----------|-------------|
| Execution worktrees | Deleted if `cleanup_on_completion: true` |
| Execution copies | Deleted if `cleanup_on_completion: true` |
| Temporary files | Deleted (agent-created temp files in run dir) |
| Runtime service state | Process stopped, ports released |
| Log files | Preserved (moved to log store) |

The project workspace itself is **never** cleaned up — only per-run execution workspaces
and temporary artifacts.

---

## Workspace + Session Interaction

Workspace and session are tightly coupled:

| Event | Effect on Session |
|-------|------------------|
| Agent assigned to task with project workspace | Session created with workspace cwd |
| Project workspace becomes available (clone completes) | Session migrated to new cwd |
| Workspace deleted | Session continues in fallback (agent home) |
| Agent reassigned to different project | New session in new workspace |

See `sessions.md` for the session migration protocol when workspaces change.

---

## Directory Structure Example

```
/osa/
├── workspaces/
│   ├── {company-id}/
│   │   ├── {project-id}/
│   │   │   └── {repo-name}/           ← Managed project workspace
│   │   │       ├── .git/
│   │   │       ├── src/
│   │   │       └── ...
│   │   └── {project-id}/
│   │       └── {repo-name}/
│   │
│   └── agents/
│       ├── {agent-id}/                 ← Agent home directory
│       │   ├── scratch/
│       │   └── notes/
│       └── {agent-id}/
│
├── execution/                          ← Temporary per-run workspaces
│   ├── {run-id}/                       ← Worktree or copy
│   └── {run-id}/
│
└── logs/
    └── runs/
        └── {run-id}.log
```

---

*Workspace Management v1.0 — Execution environment specifications for OSA Operations*
