<script lang="ts">
/**
 * CodeViewer — Shiki-based read-only syntax highlight.
 * CSS prefix: cvw- (Code Viewer Wrapper).
 *
 * REUSES the Shiki dynamic-import pattern from DiffViewer.svelte (the only
 * other Shiki consumer). When a third consumer arrives, factor a shared
 * highlighter module out of both. For now: two callers, two local instances.
 *
 * If Shiki fails to load, gracefully falls back to a plain <pre> with line
 * numbers — never breaks the build, never crashes the pane.
 *
 * Read-only by design. Editing lives in CodeEditorPane / FileViewer.
 */
import { onMount } from 'svelte';

interface Props {
  /** Raw source code. */
  content: string;
  /** Shiki language id ("typescript", "json", "elixir"…). */
  language?: string;
}

let { content, language = 'text' }: Props = $props();

// ── Render state ────────────────────────────────────────────────────────────

/** HTML emitted by Shiki (or null while loading / on failure). */
let highlighted = $state<string | null>(null);
/** Whether Shiki failed to load — toggles the plain <pre> fallback. */
let shikiFailed = $state(false);

// Plain-text line array for fallback rendering.
const lines = $derived(content.split('\n'));

onMount(async () => {
  try {
    const { createHighlighter } = await import('shiki');
    const hl = await createHighlighter({
      themes: ['github-dark-dimmed'],
      langs: [language],
    });
    highlighted = hl.codeToHtml(content, {
      lang: language,
      theme: 'github-dark-dimmed',
    });
  } catch {
    shikiFailed = true;
  }
});

function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
</script>

<div class="cvw-root" role="region" aria-label="Code preview">
  {#if highlighted && !shikiFailed}
    <!-- Shiki output already includes <pre><code>; render verbatim. -->
    <!-- eslint-disable-next-line svelte/no-at-html-tags -->
    <div class="cvw-shiki">{@html highlighted}</div>
  {:else}
    <!-- Fallback: line-numbered <pre>. Same look as FileViewer.fv-code-view. -->
    <div class="cvw-fallback">
      <div class="cvw-line-numbers" aria-hidden="true">
        {#each lines as _, idx (idx)}
          <span class="cvw-ln">{idx + 1}</span>
        {/each}
      </div>
      <pre class="cvw-pre"><code>{@html escapeHtml(content)}</code></pre>
    </div>
  {/if}
</div>

<style>
  .cvw-root {
    height: 100%;
    overflow: auto;
    background: var(--bg-inset);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  /* ── Shiki output: override its inline background to match our surface. ── */
  .cvw-shiki {
    padding: var(--space-4);
    font-family: var(--font-mono);
    font-size: 13px;
    line-height: 1.6;
  }

  .cvw-shiki :global(pre) {
    margin: 0;
    background: transparent !important;
    padding: 0;
  }

  /* ── Fallback layout (line numbers + pre) ───────────────────────────────── */
  .cvw-fallback {
    display: flex;
    min-height: 100%;
  }

  .cvw-line-numbers {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    padding: var(--space-4) var(--space-2) var(--space-4) var(--space-3);
    border-right: 1px solid var(--border);
    user-select: none;
    flex-shrink: 0;
    min-width: 2.75rem;
  }

  .cvw-ln {
    font-family: var(--font-mono);
    font-size: 12px;
    line-height: 1.6;
    color: var(--fg-subtle);
    display: block;
  }

  .cvw-pre {
    margin: 0;
    padding: var(--space-4);
    font-family: var(--font-mono);
    font-size: 13px;
    line-height: 1.6;
    color: var(--fg);
    white-space: pre;
    flex: 1;
    overflow: visible;
  }
</style>
