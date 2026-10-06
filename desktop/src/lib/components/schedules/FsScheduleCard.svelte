<!-- src/lib/components/schedules/FsScheduleCard.svelte -->
<!-- Displays a single filesystem-backed CanopyScheduleDef (read-only) -->
<script lang="ts">
  import type { CanopyScheduleDef } from '$lib/types/canopy';
  import { nextRunFromCron, formatNextRun, cronLabel } from '$lib/stores/schedules-fs.svelte';

  interface Props {
    schedule: CanopyScheduleDef;
  }

  let { schedule }: Props = $props();

  let expanded = $state(false);

  const nextDate = $derived(nextRunFromCron(schedule.cron));
  const nextRunLabel = $derived(nextDate ? formatNextRun(nextDate) : '—');
  const humanCron = $derived(cronLabel(schedule.cron));

  // Workflow badge from the raw YAML — schedules have a `workflow` field
  const workflowId = $derived(
    (schedule as unknown as Record<string, unknown>).workflow as string | undefined
  );
</script>

<article
  class="fsc-card"
  class:fsc-card--disabled={!schedule.enabled}
  aria-label="Filesystem schedule: {schedule.id}"
>
  <!-- Status indicator + name -->
  <div class="fsc-header">
    <div class="fsc-title-row">
      <span
        class="fsc-dot"
        class:fsc-dot--on={schedule.enabled}
        aria-hidden="true"
      ></span>
      <span class="fsc-name">{schedule.id.replace(/-/g, ' ')}</span>
      <span class="fsc-source-badge">yaml</span>
    </div>
    <button
      class="fsc-expand-btn"
      onclick={() => (expanded = !expanded)}
      aria-expanded={expanded}
      aria-label={expanded ? 'Collapse details' : 'Expand details'}
      type="button"
    >
      <svg
        class="fsc-chevron"
        class:fsc-chevron--open={expanded}
        width="14"
        height="14"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        aria-hidden="true"
      >
        <path d="M6 9l6 6 6-6" />
      </svg>
    </button>
  </div>

  <!-- Human cron description -->
  <p class="fsc-cron">{humanCron}</p>

  <!-- Meta row: agent + next run -->
  <div class="fsc-meta-row">
    <div class="fsc-meta">
      <span class="fsc-meta-label">Agent</span>
      <span class="fsc-meta-value">{schedule.agent_id}</span>
    </div>
    <div class="fsc-meta">
      <span class="fsc-meta-label">Next run</span>
      <span class="fsc-meta-value fsc-meta-value--accent">{nextRunLabel}</span>
    </div>
  </div>

  <!-- Expanded: description + cron raw + workflow -->
  {#if expanded}
    <div class="fsc-expanded" aria-label="Schedule details">
      {#if schedule.description}
        <p class="fsc-description">{schedule.description}</p>
      {/if}

      <div class="fsc-detail-row">
        <span class="fsc-detail-label">Cron</span>
        <code class="fsc-cron-raw">{schedule.cron}</code>
      </div>

      {#if workflowId}
        <div class="fsc-detail-row">
          <span class="fsc-detail-label">Workflow</span>
          <span class="fsc-meta-value">{workflowId}</span>
        </div>
      {/if}

      {#if schedule.context}
        <div class="fsc-detail-row">
          <span class="fsc-detail-label">Context</span>
          <span class="fsc-meta-value">{schedule.context}</span>
        </div>
      {/if}

      <div class="fsc-detail-row">
        <span class="fsc-detail-label">Source</span>
        <code class="fsc-path">{schedule.file_path.split('/').slice(-2).join('/')}</code>
      </div>
    </div>
  {/if}
</article>

<style>
  /* ── Card ── */
  .fsc-card {
    background: var(--glass-bg);
    backdrop-filter: var(--glass-blur);
    border: 1px solid var(--glass-border);
    border-radius: var(--radius-md);
    padding: 14px 16px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    transition: border-color var(--transition-fast) ease;
  }

  .fsc-card:hover {
    border-color: var(--border-hover);
  }

  .fsc-card--disabled {
    opacity: 0.6;
  }

  /* ── Header ── */
  .fsc-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
  }

  .fsc-title-row {
    display: flex;
    align-items: center;
    gap: 7px;
    flex: 1;
    min-width: 0;
  }

  /* Status dot */
  .fsc-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: var(--text-muted);
    flex-shrink: 0;
    transition: background var(--transition-fast) ease;
  }

  .fsc-dot--on {
    background: #34d399; /* emerald — distinct from API schedule blue */
    box-shadow: 0 0 0 3px rgba(52, 211, 153, 0.2);
  }

  .fsc-name {
    font-family: var(--font-sans);
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
    text-transform: capitalize;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .fsc-source-badge {
    font-family: var(--font-mono);
    font-size: 9px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: #34d399;
    background: rgba(52, 211, 153, 0.1);
    border: 1px solid rgba(52, 211, 153, 0.25);
    border-radius: 3px;
    padding: 1px 5px;
    flex-shrink: 0;
  }

  .fsc-expand-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    border-radius: var(--radius-xs);
    border: none;
    background: transparent;
    color: var(--text-tertiary);
    cursor: pointer;
    flex-shrink: 0;
    transition: color var(--transition-fast) ease, background var(--transition-fast) ease;
    padding: 0;
  }

  .fsc-expand-btn:hover {
    color: var(--text-secondary);
    background: var(--bg-elevated);
  }

  .fsc-expand-btn:focus-visible {
    outline: 2px solid var(--accent-primary);
    outline-offset: 2px;
  }

  .fsc-chevron {
    transition: transform var(--transition-normal) ease;
  }

  .fsc-chevron--open {
    transform: rotate(180deg);
  }

  /* ── Cron description ── */
  .fsc-cron {
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--text-secondary);
    margin: 0;
  }

  /* ── Meta row ── */
  .fsc-meta-row {
    display: flex;
    gap: 16px;
    flex-wrap: wrap;
  }

  .fsc-meta {
    display: flex;
    align-items: center;
    gap: 5px;
  }

  .fsc-meta-label {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--text-tertiary);
  }

  .fsc-meta-value {
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--text-secondary);
  }

  .fsc-meta-value--accent {
    color: #34d399;
  }

  /* ── Expanded ── */
  .fsc-expanded {
    border-top: 1px solid var(--border-default);
    padding-top: 10px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .fsc-description {
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--text-secondary);
    margin: 0;
    line-height: 1.5;
  }

  .fsc-detail-row {
    display: flex;
    align-items: baseline;
    gap: 8px;
  }

  .fsc-detail-label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--text-tertiary);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    flex-shrink: 0;
    width: 56px;
  }

  .fsc-cron-raw {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--text-secondary);
    background: var(--bg-elevated);
    border-radius: 3px;
    padding: 1px 5px;
  }

  .fsc-path {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--text-muted);
  }
</style>
