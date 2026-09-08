<script lang="ts">
/**
 * CompactionIndicator — context-window usage bar.
 *
 * Derives usage from session token fields (inputTokens + outputTokens vs a
 * fixed 200 K-token context window). Shows a thin colored bar at the top of
 * the conversation pane and, at ≥80 %, a "Compact now" button that sends
 * the /compact slash command to the session.
 *
 * Thresholds:
 *   <60 %  → hidden
 *   60–79 % → gray bar (informational)
 *   80–94 % → yellow bar + "Compact now" CTA
 *   ≥95 %  → red bar + "Compact now" CTA
 *
 * CSS prefix: ci-
 */

import { createMutation } from '@tanstack/svelte-query';
import { sendSessionMessage } from '$lib/api/queries/sessions.js';
import type { Session } from '$lib/domain/sessions/types.js';

interface Props {
  session: Session;
}

let { session }: Props = $props();

/** Hard-coded context window — override when the backend surfaces it. */
const CONTEXT_WINDOW = 200_000;

const usedTokens = $derived(
  (session.inputTokens ?? 0) + (session.outputTokens ?? 0) + (session.cacheReadTokens ?? 0)
);

const pct = $derived(Math.min(100, (usedTokens / CONTEXT_WINDOW) * 100));

type Level = 'hidden' | 'info' | 'warn' | 'critical';

const level = $derived<Level>(
  pct >= 95 ? 'critical' : pct >= 80 ? 'warn' : pct >= 60 ? 'info' : 'hidden'
);

const label = $derived(
  level === 'warn'
    ? 'Context 80% full — older messages will be summarized'
    : level === 'critical'
      ? 'Context nearly full — compaction needed'
      : `Context ${Math.round(pct)}% full`
);

const compact = createMutation({
  mutationFn: () => sendSessionMessage(session.id, '/compact'),
});

function handleCompact() {
  $compact.mutate();
}
</script>

{#if level !== 'hidden'}
  <div
    class="ci-root ci-root--{level}"
    role="status"
    aria-label={label}
  >
    <div class="ci-bar" style="width: {pct}%"></div>

    <div class="ci-row">
      <span class="ci-label">{label}</span>

      {#if level === 'warn' || level === 'critical'}
        <button
          class="ci-btn"
          onclick={handleCompact}
          disabled={$compact.isPending}
          aria-label="Compact context now"
        >
          {$compact.isPending ? 'Compacting…' : 'Compact now'}
        </button>
      {/if}
    </div>
  </div>
{/if}

<style>
  .ci-root {
    position: relative;
    flex-shrink: 0;
    overflow: hidden;
    border-bottom: 1px solid var(--dbd, oklch(0.28 0.01 240));
  }

  .ci-bar {
    position: absolute;
    top: 0;
    left: 0;
    height: 2px;
    transition: width 0.4s ease;
  }

  .ci-root--info .ci-bar {
    background: color-mix(in oklch, var(--dt3, oklch(0.6 0.01 240)) 50%, transparent);
  }

  .ci-root--warn .ci-bar {
    background: oklch(0.75 0.16 80);
  }

  .ci-root--critical .ci-bar {
    background: oklch(0.55 0.22 25);
  }

  .ci-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    padding: 4px 14px 4px;
  }

  .ci-label {
    font-family: var(--font-sans, system-ui);
    font-size: 11px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ci-root--info .ci-label   { color: var(--dt3, oklch(0.6 0.01 240)); }
  .ci-root--warn .ci-label   { color: oklch(0.75 0.16 80); }
  .ci-root--critical .ci-label { color: oklch(0.55 0.22 25); }

  .ci-btn {
    flex-shrink: 0;
    padding: 2px 8px;
    border-radius: var(--radius-sm, 4px);
    border: 1px solid currentColor;
    background: transparent;
    font-family: var(--font-sans, system-ui);
    font-size: 11px;
    cursor: pointer;
    transition: opacity 0.15s ease;
    color: inherit;
  }

  .ci-btn:disabled { opacity: 0.5; cursor: not-allowed; }
  .ci-btn:hover:not(:disabled) { opacity: 0.75; }
</style>
