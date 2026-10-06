---
description: Build 13-section ICP Document with Completeness Score >= 80. Consumes Market Research Brief, produces ICP Document. Second Foundations skill.
argument-hint: [optional: specific ICP segment if creator has multi-segment]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, WebFetch, WebSearch
---

# /build-icp

Execute the ICP Builder skill.

## Instructions

Read and execute `skills/build-icp/SKILL.md`. Follow its Process section Phases 0-13.

Upstream dependency: `output/research/*.md` must exist (run `/research` first if absent).

Write output to `output/build-icp/{date}-icp-document.md`. Update `company.yaml` Compartment 2 post-ship.

## Arguments

$ARGUMENTS
