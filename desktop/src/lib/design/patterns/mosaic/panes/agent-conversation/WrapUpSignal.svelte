<script lang="ts">
  /**
   * WrapUpSignal — slide-up card when the agent reaches a natural stop.
   *
   * Detection: the last block in the stream is `agent_message` with status
   * `completed`, and its outputText contains a completion keyword phrase.
   * Auto-dismisses after 30 s if the user takes no action.
   *
   * Action callbacks bubble up to AgentConversationPane:
   *   onNewTask   → clear state, focus composer
   *   onReview    → caller opens the diff pane
   *   onDismiss   → hide the card
   *
   * CSS prefix: wus-
   */

  import { fade, fly } from 'svelte/transition';
  import type { Block } from '$lib/domain/blocks/types.js';

  interface Props {
    blocks: Block[];
    onNewTask?: () => void;
    onReview?: () => void;
    onDismiss?: () => void;
  }

  let { blocks, onNewTask, onReview, onDismiss }: Props = $props();

  const COMPLETION_SIGNALS = [
    "i've completed",
    "i have completed",
    "done.",
    "all changes applied",
    "ready for review",
    "task finished",
    "task complete",
    "finished.",
    "completed.",
    "all done",
  ];

  function detectCompletion(blks: Block[]): string | null {
    if (!blks.length) return null;
    const last = blks[blks.length - 1];
    if (last.kind !== 'agent_message' || last.status !== 'completed') return null;
    const text = (last.outputText ?? '').toLowerCase();
    const hit = COMPLETION_SIGNALS.some((s) => text.includes(s));
    if (!hit) return null;
    return (last.outputText ?? '').slice(0, 100);
  }

  const summary = $derived(detectCompletion(blocks));

  let dismissed = $state(false);
  let timer: ReturnType<typeof setTimeout> | null = null;

  $effect(() => {
    if (summary && !dismissed) {
      timer = setTimeout(() => { dismissed = true; }, 30_000);
    }
    return () => { if (timer) clearTimeout(timer); };
  });

  const visible = $derived(!!summary && !dismissed);

  function handleNewTask() {
    dismissed = true;
    onNewTask?.();
  }

  function handleReview() {
    dismissed = true;
    onReview?.();
  }

  function handleDismiss() {
    dismissed = true;
    onDismiss?.();
  }
</script>

{#if visible}
  <div
    class="wus-root"
    role="status"
    aria-live="polite"
    aria-label="Agent finished"
    in:fly={{ y: 12, duration: 220 }}
    out:fade={{ duration: 150 }}
  >
    <p class="wus-heading">Agent has finished</p>
    {#if summary}
      <p class="wus-summary">{summary}{(summary.length >= 100) ? '…' : ''}</p>
    {/if}
    <div class="wus-actions">
      <button class="wus-btn wus-btn--primary" onclick={handleNewTask}>
        Start new task
      </button>
      <button class="wus-btn wus-btn--secondary" onclick={handleReview}>
        Review changes
      </button>
      <button class="wus-btn wus-btn--ghost" onclick={handleDismiss}>
        Dismiss
      </button>
    </div>
  </div>
{/if}

<style>
  .wus-root {
    flex-shrink: 0;
    margin: 0 12px 8px;
    padding: 10px 14px;
    border-radius: var(--radius-lg, 8px);
    border: 1px solid color-mix(in oklch, oklch(0.65 0.18 145) 30%, var(--dbd, oklch(0.28 0.01 240)));
    background: color-mix(in oklch, oklch(0.65 0.18 145) 6%, var(--dbg2, oklch(0.18 0.01 240)));
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .wus-heading {
    margin: 0;
    font-family: var(--font-sans, system-ui);
    font-size: 12px;
    font-weight: 600;
    color: oklch(0.65 0.18 145);
  }

  .wus-summary {
    margin: 0;
    font-family: var(--font-sans, system-ui);
    font-size: 11px;
    color: var(--dt2, oklch(0.7 0.05 240));
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .wus-actions {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
    margin-top: 2px;
  }

  .wus-btn {
    padding: 3px 10px;
    border-radius: var(--radius-sm, 4px);
    font-family: var(--font-sans, system-ui);
    font-size: 11px;
    font-weight: 500;
    cursor: pointer;
    transition: opacity 0.15s ease;
    border: 1px solid transparent;
  }

  .wus-btn:hover { opacity: 0.8; }

  .wus-btn--primary {
    background: oklch(0.65 0.18 145);
    color: oklch(0.12 0.01 240);
    border-color: oklch(0.65 0.18 145);
  }

  .wus-btn--secondary {
    background: transparent;
    color: var(--dt2, oklch(0.7 0.05 240));
    border-color: var(--dbd, oklch(0.28 0.01 240));
  }

  .wus-btn--ghost {
    background: transparent;
    color: var(--dt3, oklch(0.6 0.01 240));
    border-color: transparent;
  }
</style>
