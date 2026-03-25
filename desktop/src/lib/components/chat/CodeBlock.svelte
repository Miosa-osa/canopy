<!-- src/lib/components/chat/CodeBlock.svelte -->
<!-- Syntax-highlighted code block with language label and copy button -->
<script lang="ts">
  import hljs from 'highlight.js';
  import DOMPurify from 'dompurify';

  interface Props {
    code: string;
    lang?: string;
  }

  let { code, lang = '' }: Props = $props();

  let copied = $state(false);
  let copyTimer: ReturnType<typeof setTimeout> | null = null;

  const highlighted = $derived.by(() => {
    let raw: string;
    if (lang) {
      try {
        raw = hljs.highlight(code, { language: lang, ignoreIllegals: true }).value;
      } catch {
        // Unknown language — fall through to auto-detect
        raw = hljs.highlightAuto(code).value;
      }
    } else {
      raw = hljs.highlightAuto(code).value;
    }
    return DOMPurify.sanitize(raw, { ALLOWED_TAGS: ['span', 'br'], ALLOWED_ATTR: ['class'] });
  });

  const displayLang = $derived(lang || 'text');

  async function copy(): Promise<void> {
    try {
      await navigator.clipboard.writeText(code);
      copied = true;
      if (copyTimer) clearTimeout(copyTimer);
      copyTimer = setTimeout(() => { copied = false; }, 2000);
    } catch {
      // Clipboard unavailable — ignore
    }
  }
</script>

<div class="cb-wrap" role="figure" aria-label="{displayLang} code block">
  <div class="cb-header">
    <span class="cb-lang">{displayLang}</span>
    <button class="cb-copy" onclick={copy} aria-label="Copy code">
      {#if copied}
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
          <polyline points="20 6 9 17 4 12"></polyline>
        </svg>
        <span>Copied</span>
      {:else}
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
          <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
          <path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"></path>
        </svg>
        <span>Copy</span>
      {/if}
    </button>
  </div>
  <pre class="cb-pre"><code class="cb-code hljs">{@html highlighted}</code></pre>
</div>

<style>
  .cb-wrap {
    border-radius: var(--radius-md);
    overflow: hidden;
    border: 1px solid var(--border-default);
    background: rgba(0, 0, 0, 0.35);
    margin: 8px 0;
  }

  .cb-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 6px 14px;
    background: rgba(255, 255, 255, 0.04);
    border-bottom: 1px solid var(--border-default);
  }

  .cb-lang {
    font-family: var(--font-mono, ui-monospace, monospace);
    font-size: 11px;
    color: var(--text-tertiary);
    text-transform: lowercase;
    letter-spacing: 0.04em;
  }

  .cb-copy {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--text-tertiary);
    background: transparent;
    border: none;
    cursor: pointer;
    padding: 2px 6px;
    border-radius: var(--radius-xs);
    transition: color 0.15s ease, background 0.15s ease;
  }

  .cb-copy:hover {
    color: var(--text-primary);
    background: rgba(255, 255, 255, 0.07);
  }

  .cb-pre {
    margin: 0;
    padding: 14px 16px;
    overflow-x: auto;
    font-size: 13px;
    line-height: 1.6;
  }

  .cb-code {
    font-family: var(--font-mono, ui-monospace, monospace);
    background: transparent !important;
  }
</style>
