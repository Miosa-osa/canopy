<script lang="ts">
/**
 * WorkflowPane — Mosaic pane that renders a Drive workflow entry as an
 * executable form. Fetches the Drive entry (kind="workflow"), resolves its
 * linked Routine, auto-detects {{param}} placeholders, lets the user fill
 * them in, previews the interpolated steps, and runs the workflow by opening
 * an agent_conversation pane.
 *
 * CSS prefix: wfp-
 */

import { createQuery } from '@tanstack/svelte-query';
import { driveEntryQuery } from '$lib/api/queries/drive.js';
import { routineQuery } from '$lib/api/queries/routines.js';
import type { WorkflowBody } from '$lib/domain/drive/types.js';
import { mosaicLayout } from '$lib/stores/mosaic-layout.svelte.js';

// ── Props ──────────────────────────────────────────────────────────────────

interface Props {
  workflowRef: string; // pane.ref — Drive entry id or slug
  workspaceSlug?: string;
}

let { workflowRef, workspaceSlug = 'default' }: Props = $props();

// ── Drive entry query ──────────────────────────────────────────────────────

const entryQuery = createQuery(driveEntryQuery(workflowRef));

// ── Resolve routine_id from drive entry body ───────────────────────────────

const routineId = $derived(
  ($entryQuery.data?.kind === 'workflow'
    ? ($entryQuery.data.body as unknown as WorkflowBody).routine_id
    : null) ?? ''
);

const rQuery = createQuery({
  ...routineQuery(routineId),
  enabled: Boolean(routineId),
});

// ── Parse steps from promptTemplate ───────────────────────────────────────
// A step = one non-empty line (or code block) from the template.

const PARAM_RE = /\{\{(\w+)\}\}/g;

const steps = $derived.by(() => {
  const tmpl = $rQuery.data?.promptTemplate ?? '';
  if (!tmpl) return [] as string[];
  // Split on double-newlines or numbered list markers; fall back to lines.
  const raw = tmpl
    .split(/\n{2,}|\r\n{2,}/)
    .map((s) => s.trim())
    .filter(Boolean);
  return raw.length > 1
    ? raw
    : tmpl
        .split('\n')
        .map((s) => s.trim())
        .filter(Boolean);
});

// Unique param names across all steps, in order of appearance.
const paramNames = $derived.by(() => {
  const tmpl = $rQuery.data?.promptTemplate ?? '';
  const seen = new Set<string>();
  const out: string[] = [];
  const re = new RegExp(PARAM_RE.source, 'g');
  for (const m of tmpl.matchAll(re)) {
    if (!seen.has(m[1])) {
      seen.add(m[1]);
      out.push(m[1]);
    }
  }
  return out;
});

// ── Param values (mutable form state) ─────────────────────────────────────

let paramValues = $state<Record<string, string>>({});

$effect(() => {
  // Initialise new param keys to empty string; preserve existing values.
  const next: Record<string, string> = {};
  for (const name of paramNames) {
    next[name] = paramValues[name] ?? '';
  }
  paramValues = next;
});

// ── Interpolation ──────────────────────────────────────────────────────────

function interpolate(template: string): string {
  return template.replace(/\{\{(\w+)\}\}/g, (_, key: string) => paramValues[key] ?? `{{${key}}}`);
}

const interpolatedSteps = $derived(steps.map(interpolate));
const allFilled = $derived(paramNames.every((n) => paramValues[n]?.trim()));

// ── Highlight {{param}} spans in a step for the preview ───────────────────

function highlightParams(raw: string, filled: string): string {
  // Show the filled version but mark positions that were params
  // by diffing: replace filled value with a <mark> in the output.
  // Simpler: highlight remaining {{...}} placeholders in the filled string.
  return filled.replace(/\{\{(\w+)\}\}/g, '<mark class="wfp-ph">{{$1}}</mark>');
}

// ── Run action ─────────────────────────────────────────────────────────────

function runWorkflow(): void {
  const prompt = interpolatedSteps.join('\n\n');
  const title = $entryQuery.data?.name ?? 'Workflow';
  mosaicLayout.openPane({
    id: crypto.randomUUID(),
    kind: 'agent_conversation',
    ref: 'new',
    title,
    config: { cwd: '~', initialPrompt: prompt },
  });
}

// ── Loading / error helpers ────────────────────────────────────────────────

const isLoading = $derived($entryQuery.isLoading || ($entryQuery.data && $rQuery.isLoading));
const notFound = $derived(!$entryQuery.isLoading && !$entryQuery.data);
const entry = $derived($entryQuery.data);
const routine = $derived($rQuery.data);
</script>

<div class="wfp-root">

  {#if isLoading}
    <div class="wfp-center">
      <span class="wfp-loading">Loading workflow…</span>
    </div>

  {:else if notFound}
    <div class="wfp-center">
      <p class="wfp-empty-title">Workflow not found</p>
      <p class="wfp-empty-hint">Ref <code>{workflowRef}</code> did not match any Drive entry.</p>
    </div>

  {:else if entry}
    <!-- Header -->
    <header class="wfp-header">
      <h2 class="wfp-title">{entry.name}</h2>
      {#if routine?.description}
        <p class="wfp-desc">{routine.description}</p>
      {/if}
    </header>

    <div class="wfp-body">

      <!-- Parameters form -->
      {#if paramNames.length > 0}
        <section class="wfp-section">
          <h3 class="wfp-section-label">Parameters</h3>
          <div class="wfp-params">
            {#each paramNames as name (name)}
              <label class="wfp-param">
                <span class="wfp-param-name">{name}</span>
                <input
                  class="wfp-param-input"
                  type="text"
                  placeholder={`Enter ${name}…`}
                  bind:value={paramValues[name]}
                />
              </label>
            {/each}
          </div>
        </section>
      {/if}

      <!-- Steps preview -->
      {#if steps.length > 0}
        <section class="wfp-section">
          <h3 class="wfp-section-label">Steps</h3>
          <ol class="wfp-steps">
            {#each interpolatedSteps as step, i (i)}
              <li class="wfp-step">
                <span class="wfp-step-num">{i + 1}</span>
                <!-- eslint-disable-next-line svelte/no-at-html-tags -->
                <span class="wfp-step-text">{@html highlightParams(steps[i], step)}</span>
              </li>
            {/each}
          </ol>
        </section>
      {:else if routine && !$rQuery.isLoading}
        <p class="wfp-empty-hint">This routine has no template steps defined.</p>
      {/if}

    </div>

    <!-- Run button -->
    <footer class="wfp-footer">
      <button
        class="wfp-run"
        onclick={runWorkflow}
        disabled={paramNames.length > 0 && !allFilled}
        title={paramNames.length > 0 && !allFilled ? 'Fill all parameters to run' : 'Run workflow'}
      >
        Run workflow
      </button>
    </footer>

  {/if}
</div>

<style>
  .wfp-root {
    display: flex;
    flex-direction: column;
    flex: 1;
    height: 100%;
    min-height: 0;
    font-family: var(--font-sans);
    background: var(--bg);
  }

  /* ── Center helper (loading / empty) ───────────────────────────────────── */
  .wfp-center {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 8px;
    padding: 24px;
    text-align: center;
  }

  .wfp-loading {
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    font-style: italic;
  }

  .wfp-empty-title {
    font-size: var(--text-base);
    font-weight: 600;
    color: var(--fg-muted);
    margin: 0;
  }

  .wfp-empty-hint {
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    margin: 0;
  }

  /* ── Header ────────────────────────────────────────────────────────────── */
  .wfp-header {
    padding: 16px 20px 12px;
    border-bottom: 1px solid var(--border-subtle, color-mix(in oklch, var(--fg) 10%, transparent));
  }

  .wfp-title {
    margin: 0 0 4px;
    font-size: var(--text-base);
    font-weight: 600;
    color: var(--fg);
    line-height: 1.3;
  }

  .wfp-desc {
    margin: 0;
    font-size: var(--text-sm);
    color: var(--fg-muted);
    line-height: 1.5;
  }

  /* ── Body ───────────────────────────────────────────────────────────────── */
  .wfp-body {
    flex: 1;
    overflow-y: auto;
    padding: 16px 20px;
    display: flex;
    flex-direction: column;
    gap: 20px;
    min-height: 0;
  }

  /* ── Sections ───────────────────────────────────────────────────────────── */
  .wfp-section {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .wfp-section-label {
    margin: 0;
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-subtle);
  }

  /* ── Params ─────────────────────────────────────────────────────────────── */
  .wfp-params {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .wfp-param {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .wfp-param-name {
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg-muted);
    font-family: var(--font-mono);
  }

  .wfp-param-input {
    width: 100%;
    padding: 7px 10px;
    border-radius: var(--radius-md, 6px);
    border: 1px solid color-mix(in oklch, var(--fg) 15%, transparent);
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    color: var(--fg);
    font-size: var(--text-sm);
    font-family: var(--font-sans);
    outline: none;
    box-sizing: border-box;
    transition: border-color 120ms;
  }

  .wfp-param-input:focus {
    border-color: var(--accent, oklch(0.6 0.18 250));
  }

  /* ── Steps ──────────────────────────────────────────────────────────────── */
  .wfp-steps {
    margin: 0;
    padding: 0;
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .wfp-step {
    display: flex;
    gap: 10px;
    align-items: flex-start;
    padding: 10px 12px;
    border-radius: var(--radius-md, 6px);
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  .wfp-step-num {
    flex-shrink: 0;
    width: 20px;
    height: 20px;
    border-radius: 50%;
    background: color-mix(in oklch, var(--fg) 12%, transparent);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 11px;
    font-weight: 600;
    color: var(--fg-muted);
    line-height: 1;
  }

  .wfp-step-text {
    flex: 1;
    font-size: var(--text-sm);
    color: var(--fg);
    font-family: var(--font-mono);
    line-height: 1.5;
    word-break: break-word;
    white-space: pre-wrap;
  }

  /* Unfilled placeholder highlight */
  :global(.wfp-ph) {
    background: color-mix(in oklch, var(--accent, oklch(0.6 0.18 250)) 20%, transparent);
    color: var(--accent, oklch(0.6 0.18 250));
    border-radius: 3px;
    padding: 0 2px;
    font-style: normal;
  }

  /* ── Footer ─────────────────────────────────────────────────────────────── */
  .wfp-footer {
    padding: 12px 20px 16px;
    border-top: 1px solid color-mix(in oklch, var(--fg) 10%, transparent);
  }

  .wfp-run {
    width: 100%;
    padding: 9px 16px;
    border-radius: var(--radius-md, 6px);
    border: none;
    cursor: pointer;
    font-size: var(--text-sm);
    font-weight: 600;
    font-family: var(--font-sans);
    background: var(--accent, oklch(0.6 0.18 250));
    color: #fff;
    transition: opacity 120ms, background 120ms;
  }

  .wfp-run:hover:not(:disabled) {
    opacity: 0.88;
  }

  .wfp-run:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }
</style>
