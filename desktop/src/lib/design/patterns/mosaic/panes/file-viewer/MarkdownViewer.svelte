<script lang="ts">
  /**
   * MarkdownViewer — read-only markdown render.
   * CSS prefix: mvw- (Markdown Viewer Wrapper).
   *
   * REUSES the existing inline markdown renderer at $lib/utils/markdown.ts,
   * which is already used by FilePreview.svelte and FileViewer.svelte.
   * No new markdown library is added.
   *
   * The .fv-* class names emitted by renderMarkdown() are styled globally
   * (see FileViewer.svelte's :global blocks) — those styles apply here too.
   *
   * Editing belongs in TiptapEditor / FileViewer; this is a viewer only.
   */
  import { renderMarkdown } from "$lib/utils/markdown.js";

  interface Props {
    /** Raw markdown source. */
    content: string;
  }

  let { content }: Props = $props();

  const html = $derived(renderMarkdown(content));
</script>

<article class="mvw-root" aria-label="Markdown preview">
  <!-- eslint-disable-next-line svelte/no-at-html-tags -->
  {@html html}
</article>

<style>
  .mvw-root {
    padding: var(--space-5);
    overflow-y: auto;
    height: 100%;
    box-sizing: border-box;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    line-height: 1.7;
    color: var(--fg);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }
</style>
