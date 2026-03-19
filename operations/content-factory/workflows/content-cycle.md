# Content Cycle Workflow

> 7-phase pipeline from content ideation through performance analysis.

## Overview

```
Ideate -> Research -> Draft -> Edit -> Design -> Publish -> Analyze
```

Each phase has an owner, evidence gate, and handoff protocol.

---

## Phases

### Phase 1: Ideate

- **Owner**: editor-in-chief
- **Goal**: Generate and approve content ideas aligned with strategy and SEO opportunity
- **Evidence gate**: Idea approved with brief, keyword target, audience segment, and calendar slot
- **Signal threshold**: 0.6
- **Agents activated**:
  - Wave 1: editor-in-chief (editorial strategy), seo-specialist (keyword opportunity)
- **Max duration**: 1 day
- **On failure**: Idea rejected -- generate alternatives
- **Handoff**: standard (editor-in-chief -> writer with content brief)

### Phase 2: Research

- **Owner**: writer + seo-specialist
- **Goal**: Gather sources, analyze competitors, refine outline, confirm keyword strategy
- **Evidence gate**: Research complete, outline refined, keywords confirmed, sources gathered
- **Signal threshold**: 0.6
- **Agents activated**:
  - Wave 1: writer (topic research, source gathering), seo-specialist (competitor analysis, keyword validation)
- **Max duration**: 1 day
- **On failure**: Insufficient sources -- editor-in-chief decides to proceed or kill
- **Handoff**: standard (research complete, writer begins drafting)

### Phase 3: Draft

- **Owner**: writer
- **Goal**: Produce complete first draft with all metadata
- **Evidence gate**: Draft complete, 5 headlines provided, keyword placement verified, readability score acceptable
- **Signal threshold**: 0.7
- **Agents activated**:
  - Wave 1: writer (draft production)
- **Max duration**: 2 days
- **On failure**: Writer requests extension or brief revision from editor-in-chief
- **Handoff**: editorial-review (writer -> editor-in-chief with full draft package)

### Phase 4: Edit

- **Owner**: editor-in-chief
- **Goal**: Verify brand voice, factual accuracy, SEO compliance, and quality standards
- **Evidence gate**: Editorial review checklist passed, content approved for design
- **Signal threshold**: 0.8
- **Max retries**: 2 (edit-revision loop)
- **Agents activated**:
  - Wave 1: editor-in-chief (editorial review)
  - Wave 2: seo-specialist (SEO optimization check)
- **Max duration**: 1 day
- **On failure**: Return to writer with specific corrections (max 2 revision cycles)
- **Handoff**: standard (editor-in-chief -> designer with approved content)

### Phase 5: Design

- **Owner**: designer
- **Goal**: Create visual assets for the content (thumbnail, social graphics, infographics)
- **Evidence gate**: Visual assets created, brand compliant, platform-formatted
- **Signal threshold**: 0.7
- **Agents activated**:
  - Wave 1: designer (visual creation per platform specs)
- **Max duration**: 1 day
- **On failure**: Designer revises per editor-in-chief feedback
- **Handoff**: standard (designer -> social-media with visual assets + content)

### Phase 6: Publish

- **Owner**: social-media
- **Goal**: Publish content and create platform-native social promotion
- **Evidence gate**: Content published, social posts scheduled, all platforms covered
- **Signal threshold**: 0.7
- **Agents activated**:
  - Wave 1: social-media (blog publish, social post scheduling)
- **Max duration**: 1 day
- **On failure**: Technical publish issue -> resolve and retry
- **Handoff**: standard (content live, monitoring period begins)

### Phase 7: Analyze

- **Owner**: seo-specialist + social-media
- **Goal**: 7-day performance review, capture learnings, inform next cycle
- **Evidence gate**: Performance data reviewed, learnings documented, recommendations made
- **Signal threshold**: 0.7
- **Agents activated**:
  - Wave 1: seo-specialist (organic traffic + ranking analysis), social-media (engagement analysis)
  - Wave 2: editor-in-chief (strategic recommendations based on data)
- **Max duration**: 1 day (at 7 days post-publish)
- **On failure**: N/A -- analysis always completes
- **Handoff**: Content cycle complete. Learnings fed into next Ideate phase.

---

## Edit-Revision Loop

```
Writer submits draft
  -> Editor reviews
     -> APPROVED: advance to Design
     -> REVISIONS NEEDED: return to Writer with specific corrections
        -> Writer revises, resubmits
           -> revision_count > 2: escalate to editor-in-chief for decision (publish as-is, kill, or reassign)
```

## Handoff Definitions

| Handoff Type | Template | When Used |
|-------------|----------|-----------|
| standard | N/A (inline phase transition) | Most phase transitions |
| editorial-review | handoffs/editorial-review.md | Writer submitting draft to editor |
