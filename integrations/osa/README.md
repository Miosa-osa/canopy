# OSA Integration

OSA natively supports the Workspace Protocol. Point it at any workspace
and it auto-discovers SYSTEM.md, agents, skills, and reference files.

## Connect a Workspace

```bash
# Connect OSA to a workspace
osa connect /path/to/workspace

# OSA reads SYSTEM.md, discovers:
#   - agents/ → available specialist agents
#   - skills/ → available slash commands
#   - reference/ → domain knowledge (loaded on-demand)
#   - engine/ → powers skills (invisible to agent)
```

## How OSA Layers Workspaces

OSA has its own base configuration at `~/.osa/`:

```
~/.osa/                              ← Base config (always active)
├── config.yaml                        Model, channels, preferences
├── agents/                            Global agents (debugger, reviewer, etc.)
├── skills/                            Global skills (/commit, /test, etc.)
├── memory/                            Persistent memory across sessions
│   ├── episodic/                      Event-indexed interaction logs
│   ├── semantic/                      Extracted facts, entities, relationships
│   └── procedural/                    Learned patterns, heuristics
├── channels/                          CLI, HTTP, Telegram, Discord, Slack
└── hooks/                             Pre/post tool use automation
```

When OSA enters a workspace, the workspace config layers on top:

```
Base (~/.osa/)          +  Workspace (sales-engine/)     =  Active Config
───────────────────────────────────────────────────────────────────────
Global agents              Workspace agents                 Both available
  debugger.md                closer.md                      Agent picks the
  code-reviewer.md           prospector.md                  right specialist
  architect.md               researcher.md                  for the task

Global skills              Workspace skills                 Both available
  /commit                    /prospect                      User calls any
  /test                      /pipeline                      skill by name
  /review                    /qualify

(no domain knowledge)      Workspace reference              Domain-aware
                             icp.md, meddpicc.md            Agent can now
                             objections.md                  do sales work

(no domain engine)         Workspace engine                 Skills invoke
                             CRM, email API, DB             engine underneath
```

## OSA Features That Map to Workspaces

| OSA Component | What It Does | Workspace Equivalent |
|---|---|---|
| `prompt_loader.ex` | Reads SYSTEM.md on workspace entry | L0 boot |
| `agent/context.ex` | Assembles context from workspace | L0/L1/L2 tiered loading |
| `agent/tier.ex` | Tiered context loading (L0/L1/L2) | Token budget enforcement |
| `signal/classifier.ex` | Classifies S=(M,G,T,F,W) | Signal Theory encoding |
| `agent/loop/genre_router.ex` | Routes output by genre | Receiver-aware encoding |
| `tools/builtins/list_skills.ex` | Discovers skills/*/SKILL.md | Skill discovery |
| `memory/store.ex` | Persistent memory | Cross-session knowledge |
| `memory/learning.ex` | Pattern extraction | Learning loop |
| `scheduler/heartbeat.ex` | Periodic agent wake | Proactive agents |
| `swarm/patterns.ex` | Multi-agent coordination | Parallel, pipeline, debate |

## Install Agents from the Library

```bash
# Install library agents into your OSA base config
./scripts/install.sh --tool osa

# Or copy specific categories
cp library/agents/engineering/*.md ~/.osa/agents/
cp library/agents/specialized/*.md ~/.osa/agents/
```

## Multiple Workspaces

OSA can switch between workspaces. Each workspace provides different
domain capabilities while the base config stays constant:

```bash
osa connect ~/workspaces/sales-engine    # becomes a sales agent
osa connect ~/workspaces/dev-shop        # becomes a coding agent
osa connect ~/workspaces/content-factory # becomes a content agent
```

The workspace SYSTEM.md tells OSA who it becomes. When OSA leaves a
workspace, it drops that domain context and picks up the next one.
The base config (global agents, memory, channels) persists across all.
