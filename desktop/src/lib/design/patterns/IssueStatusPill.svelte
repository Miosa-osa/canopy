<script lang="ts">
  /**
   * IssueStatusPill — compact status badge for issue rows.
   * CSS prefix: isp- (IssueStatusPill)
   * 5 statuses: backlog | open | in_progress | in_review | closed
   */
  import type { IssueStatus } from '$lib/domain/issues/types.js';

  interface Props {
    status: IssueStatus;
  }

  let { status }: Props = $props();

  type PillMeta = { label: string; mod: string };

  const META: Record<IssueStatus, PillMeta> = {
    backlog:     { label: 'Backlog',     mod: 'isp--backlog' },
    open:        { label: 'Open',        mod: 'isp--open' },
    in_progress: { label: 'In Progress', mod: 'isp--in-progress' },
    in_review:   { label: 'In Review',   mod: 'isp--in-review' },
    closed:      { label: 'Closed',      mod: 'isp--closed' },
  };

  const meta = $derived(META[status] ?? { label: status, mod: '' });
</script>

<span class="isp {meta.mod}" aria-label="Status: {meta.label}">
  {meta.label}
</span>

<style>
  .isp {
    display: inline-flex;
    align-items: center;
    padding: 1px 7px;
    border-radius: 9999px;
    border: 1px solid var(--border);
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.03em;
    white-space: nowrap;
    color: var(--fg-muted);
    background: var(--bg-inset);
  }

  /* Backlog — subtle grey */
  .isp--backlog {
    color: var(--fg-subtle);
    border-color: color-mix(in oklch, var(--fg) 15%, transparent);
  }

  /* Open — slight accent tint */
  .isp--open {
    color: var(--cnp-accent, oklch(0.78 0.18 145));
    border-color: color-mix(in oklch, var(--cnp-accent, oklch(0.78 0.18 145)) 40%, transparent);
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.78 0.18 145)) 8%, transparent);
  }

  /* In Progress — accent + elevated */
  .isp--in-progress {
    color: var(--cnp-accent, oklch(0.78 0.18 145));
    border-color: color-mix(in oklch, var(--cnp-accent, oklch(0.78 0.18 145)) 50%, transparent);
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.78 0.18 145)) 12%, transparent);
  }

  /* In Review — amber */
  .isp--in-review {
    color: oklch(0.72 0.13 75);
    border-color: oklch(0.72 0.13 75 / 0.4);
    background: oklch(0.72 0.13 75 / 0.1);
  }

  /* Closed — muted strike-through feel */
  .isp--closed {
    color: var(--fg-subtle);
    border-color: var(--border);
    opacity: 0.7;
  }
</style>
