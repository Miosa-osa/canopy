<script lang="ts">
  /**
   * LogViewer — line-numbered mono text with a "Follow tail" toggle.
   * CSS prefix: lvw- (Log Viewer).
   *
   * When "Follow tail" is on, the viewport auto-scrolls to the last line
   * whenever the content prop changes. Toggle off to inspect history.
   *
   * The pane parent is responsible for refetching content (or wiring an
   * SSE/WebSocket source) — this viewer only re-renders on prop change.
   */
  import { tick } from "svelte";

  interface Props {
    /** Raw log text. */
    content: string;
    /** Initial follow state. Default: true. */
    initialFollow?: boolean;
  }

  let { content, initialFollow = true }: Props = $props();

  let follow = $state(initialFollow);
  let scrollEl = $state<HTMLDivElement | null>(null);

  const lines = $derived(content.split("\n"));

  // Auto-scroll on content change when following.
  $effect(() => {
    void content; // dependency
    if (follow && scrollEl) {
      void tick().then(() => {
        if (scrollEl) scrollEl.scrollTop = scrollEl.scrollHeight;
      });
    }
  });

  function toggleFollow(): void {
    follow = !follow;
    if (follow && scrollEl) scrollEl.scrollTop = scrollEl.scrollHeight;
  }
</script>

<div class="lvw-root">
  <div class="lvw-toolbar" role="toolbar" aria-label="Log controls">
    <button
      class="lvw-toggle"
      class:lvw-toggle-on={follow}
      type="button"
      onclick={toggleFollow}
      aria-pressed={follow}
    >
      {follow ? "● Following tail" : "○ Paused"}
    </button>
    <span class="lvw-stats">{lines.length} lines</span>
  </div>

  <div class="lvw-scroll" bind:this={scrollEl}>
    <div class="lvw-grid">
      <div class="lvw-numbers" aria-hidden="true">
        {#each lines as _, idx (idx)}
          <span class="lvw-ln">{idx + 1}</span>
        {/each}
      </div>
      <pre class="lvw-pre"><code>{lines.join("\n")}</code></pre>
    </div>
  </div>
</div>

<style>
  .lvw-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: var(--bg-inset);
  }

  .lvw-toolbar {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-1) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    background: var(--bg-elevated, var(--bg));
  }

  .lvw-toggle {
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    padding: 2px var(--space-2);
    cursor: pointer;
  }

  .lvw-toggle-on {
    color: oklch(0.72 0.18 145);
    border-color: color-mix(in oklch, oklch(0.72 0.18 145) 50%, transparent);
  }

  .lvw-stats {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    margin-left: auto;
  }

  .lvw-scroll {
    flex: 1;
    overflow: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .lvw-grid {
    display: flex;
    min-height: 100%;
  }

  .lvw-numbers {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    padding: var(--space-3) var(--space-2);
    border-right: 1px solid var(--border);
    user-select: none;
    flex-shrink: 0;
    min-width: 3rem;
  }

  .lvw-ln {
    font-family: var(--font-mono);
    font-size: 12px;
    line-height: 1.5;
    color: var(--fg-subtle);
  }

  .lvw-pre {
    margin: 0;
    padding: var(--space-3);
    font-family: var(--font-mono);
    font-size: 12px;
    line-height: 1.5;
    color: var(--fg);
    white-space: pre;
    flex: 1;
  }
</style>
