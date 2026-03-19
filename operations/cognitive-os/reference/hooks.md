# Hooks — Agent System Integration

## Overview
Hooks connect OptimalOS to the agent system (Claude Code / OSA). They fire at
specific lifecycle events to inject context, enforce quality, and persist state.

AC has 3 hooks: SessionStart, WriteValidate, SessionCapture.
We have those plus 2 more: SearchEnhance and ModeTransition.

## Hook 1: SessionStart — Context Injection

**Fires**: When a new conversation begins
**Purpose**: Inject dynamic operating state so the AI starts oriented

### What It Loads
1. **L0 Cache** — Always-loaded abstracts from all context.md files (~2K tokens)
2. **Today Context** — `rhythm/today.md` current plan + mode (~500 tokens)
3. **Week Plan** — `week-plan.md` priorities (~300 tokens)
4. **Recent Signals** — Last 5 ingested signals (~500 tokens)
5. **Health Alerts** — Any critical diagnostics (~200 tokens)
6. **Active Escalations** — Friction patterns ready for rethink (~200 tokens)

### Implementation
```bash
# Engine-backed: run at session start
cd engine && mix optimal.l0              # L0 cache
cat rhythm/today.md                       # Today context
cat week-plan.md                          # Week plan
cd engine && mix optimal.health --quick   # Critical alerts only
```

### Token Budget
Total injection: ~3.5K tokens (well within context budget)

## Hook 2: WriteValidate — Schema Enforcement

**Fires**: Before any markdown file is written to the numbered folders
**Purpose**: Ensure every file meets quality standards

### Validation Rules
1. **Frontmatter required**: Every signal file must have YAML frontmatter with:
   - `title`, `date`, `genre`, `type`, `node`
2. **Genre compliance**: Genre must be from the known catalogue (27 genres in CLAUDE.md, 191 in docs/taxonomy/)
3. **Routing compliance**: Node must match one of the 12 numbered folders
4. **S/N threshold**: Content must have substance (not empty, not just headers)
5. **Cross-reference check**: Financial signals must also route to 11-money-revenue

### On Failure
- Block the write
- Report which validation rule failed
- Suggest fix

## Hook 3: SessionCapture — State Persistence

**Fires**: When a conversation ends (Stop event)
**Purpose**: Persist session state for continuity

### What It Captures
1. **Session summary** — Key topics discussed, decisions made
2. **Pending actions** — Unfinished tasks from the session
3. **Observations** — Any friction patterns noticed
4. **State updates** — Changes to today.md, signal.md, context.md
5. **Energy level** — If user reported energy/focus level

### Storage
- Session metadata → Engine `sessions` table
- Observations → Engine `observations` table
- State changes → Already written to files during session

## Hook 4: SearchEnhance — Query Augmentation

**Fires**: Before any search query
**Purpose**: Enhance queries with context awareness

### What It Does
1. Checks current cognitive mode → adjusts search scope
2. If in BUILD mode on topic X → auto-filter to relevant nodes
3. If recent session has entity context → add as node hints
4. If same query was searched recently → suggest refinement

## Hook 5: ModeTransition — SAVE → CLEAR → LOAD

**Fires**: When cognitive mode changes (BUILD → OPERATE, etc.)
**Purpose**: Ensure clean context transitions

### What It Does
1. **SAVE** — Capture any pending signals, update today.md
2. **CLEAR** — Note the mode transition for session history
3. **LOAD** — Assemble context for the new mode's focus area

### Mode-Specific Loading
| From → To | Load Action |
|-----------|-------------|
| Any → BUILD | `mix optimal.assemble "{build topic}"` |
| Any → OPERATE | Load today.md queue + recent signals |
| Any → LEARN | Load relevant reference/ files |
| Any → SYNTHESIZE | Load graph analysis + escalations |
| Any → EXTRACT | Load transcript template + routing table |

## Hook Execution Order
```
SessionStart → [SearchEnhance before queries] → [WriteValidate before writes]
    → [ModeTransition on mode changes] → SessionCapture on Stop
```

## Integration with Agent Systems

### Claude Code
Hooks map to Claude Code's hook system:
- SessionStart → `SessionStart` event in `.claude/hooks/`
- WriteValidate → `PreToolUse` hook filtering Write tool calls
- SessionCapture → `Stop` event in `.claude/hooks/`
- SearchEnhance → Integrated into SearchEngine GenServer
- ModeTransition → Triggered by user command or detected context shift

### OSA (Optimal System Agent)
OSA implements hooks natively in its ReAct loop:
- SessionStart → Boot phase of agent initialization
- WriteValidate → Tool execution middleware
- SessionCapture → Agent shutdown handler
- SearchEnhance → Pre-search middleware in tool pipeline
- ModeTransition → State machine transition handler
