# Use Case Presets

## Preset 1: CEO Operating Mode (Default)
**When**: The operator's daily use — brain dumps, signal processing, decision-making
**Active Systems**:
- Full engine (all 39 modules)
- All 12 nodes active
- Rhythm system (boot/shutdown)
- Genre encoding for all receivers
- Weekly review cycle

**Key Commands**:
```bash
mix optimal.l0                    # Morning boot context
mix optimal.assemble "topic"      # Pre-work context loading
mix optimal.ingest "signal"       # Signal capture
mix optimal.search "query"        # Knowledge retrieval
mix optimal.health                # Weekly health check
```

**Cognitive Modes**: BUILD, OPERATE, LEARN, SYNTHESIZE, EXTRACT

## Preset 2: Technical Development Mode
**When**: Building the engine itself, platform work, coding sessions
**Active Systems**:
- Engine modules (for testing/development)
- Nodes 02 (Platform), 05 (Research) primary
- Spec genre dominant
- Deep work blocks (BUILD mode only)

**Key Commands**:
```bash
mix optimal.search "query" --node platform
mix compile --force
mix test
mix optimal.graph triangles       # Check knowledge coherence
```

## Preset 3: Sales & Partnerships Mode
**When**: Calls with Ed, Robert Potter, Len, Bennett, prospects
**Active Systems**:
- Search focused on relevant node
- Genre system in brief/pitch mode
- Pre-call prep via context assembly
- Post-call EXTRACT mode

**Key Commands**:
```bash
mix optimal.assemble "Ed Honour AI Masters"   # Pre-call context
mix optimal.ingest --genre transcript          # Post-call capture
mix optimal.search "pricing" --node ai-masters # Quick lookup
```

**Genre Lock**: brief and pitch only. No specs to non-technical receivers.

## Preset 4: Review & Synthesis Mode
**When**: Friday reviews, monthly reviews, strategic planning
**Active Systems**:
- Health diagnostics
- Reweaver (find stale contexts)
- GraphAnalyzer (synthesis opportunities)
- RememberLoop (check escalations)
- RethinkEngine (evidence synthesis)

**Key Commands**:
```bash
mix optimal.health                # System health
mix optimal.reweave "topic"       # Find stale content
mix optimal.graph triangles       # Synthesis opportunities
mix optimal.remember --escalations # Check friction patterns
mix optimal.rethink "topic"       # Evidence synthesis
```

## Preset Selection Algorithm
1. Check current cognitive mode (from rhythm/today.md)
2. If BUILD + code context → Preset 2
3. If OPERATE + people context → Preset 3
4. If SYNTHESIZE or Friday → Preset 4
5. Default → Preset 1
