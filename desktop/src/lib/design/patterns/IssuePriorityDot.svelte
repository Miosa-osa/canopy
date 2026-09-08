<script lang="ts">
/**
 * IssuePriorityDot — small coloured priority indicator for issue rows.
 * CSS prefix: ipd- (IssuePriorityDot)
 * Priority 0=none 1=low 2=medium 3=high
 */
import type { IssuePriority } from '$lib/domain/issues/types.js';

interface Props {
  priority: IssuePriority;
}

let { priority }: Props = $props();

type DotMeta = { label: string; mod: string };

const META: Record<IssuePriority, DotMeta> = {
  0: { label: 'No priority', mod: 'ipd--none' },
  1: { label: 'Low', mod: 'ipd--low' },
  2: { label: 'Medium', mod: 'ipd--medium' },
  3: { label: 'High', mod: 'ipd--high' },
};

const meta = $derived(META[priority] ?? META[0]);
</script>

<span class="ipd {meta.mod}" aria-label="{meta.label} priority" title="{meta.label}"></span>

<style>
  .ipd {
    display: inline-block;
    width: 8px;
    height: 8px;
    border-radius: 9999px;
    border: 1.5px solid currentColor;
    flex-shrink: 0;
  }

  .ipd--none    { color: var(--fg-subtle); background: transparent; }
  .ipd--low     { color: var(--fg-muted);  background: color-mix(in oklch, var(--fg-muted) 30%, transparent); }
  .ipd--medium  {
    color: oklch(0.72 0.13 75);
    background: oklch(0.72 0.13 75 / 0.25);
  }
  .ipd--high    {
    color: oklch(0.65 0.18 28);
    background: oklch(0.65 0.18 28 / 0.25);
  }
</style>
