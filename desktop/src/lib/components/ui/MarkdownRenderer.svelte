<script lang="ts">
  import { marked } from 'marked';
  interface Props { content: string; }
  let { content }: Props = $props();
  let stripped = $derived.by(() => {
    if (!content.startsWith('---')) return content;
    const second = content.indexOf('---', 3);
    if (second === -1) return content;
    return content.slice(second + 3).trimStart();
  });
  let html = $derived(marked.parse(stripped) as string);
</script>
<div class="md-body">{@html html}</div>
<style>
  .md-body { font-size: 14px; line-height: 1.6; color: var(--text-primary, #e2e8f0); }
  .md-body :global(h1), .md-body :global(h2), .md-body :global(h3) { font-weight: 600; margin: 1rem 0 0.5rem; }
  .md-body :global(p) { margin: 0.5rem 0; }
  .md-body :global(code) { font-family: monospace; background: rgba(255,255,255,0.06); padding: 1px 4px; border-radius: 3px; }
  .md-body :global(pre) { background: rgba(255,255,255,0.06); padding: 1rem; border-radius: 6px; overflow-x: auto; }
  .md-body :global(table) { border-collapse: collapse; width: 100%; }
  .md-body :global(th), .md-body :global(td) { border: 1px solid rgba(255,255,255,0.08); padding: 6px 12px; text-align: left; }
</style>
