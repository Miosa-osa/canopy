<!-- src/lib/components/documents/DocumentViewer.svelte -->
<!-- Markdown viewer with glass surface and edit toggle -->
<script lang="ts">
  import type { Document } from '$api/types';
  import DOMPurify from 'dompurify';
  import TimeAgo from '$lib/components/shared/TimeAgo.svelte';

  interface Props {
    document: Document;
  }

  let { document }: Props = $props();

  let editMode = $state(false);
  let editContent = $state(document.content);

  // Reset edit content when document changes
  $effect(() => {
    editContent = document.content;
    editMode = false;
  });

  // Lightweight markdown → HTML renderer, sanitized via DOMPurify.
  function renderMarkdown(md: string): string {
    if (!md) return '<p class="dv-empty-doc">This document is empty.</p>';
    const html = md
      // Headings
      .replace(/^######\s(.+)$/gm, '<h6>$1</h6>')
      .replace(/^#####\s(.+)$/gm, '<h5>$1</h5>')
      .replace(/^####\s(.+)$/gm, '<h4>$1</h4>')
      .replace(/^###\s(.+)$/gm, '<h3>$1</h3>')
      .replace(/^##\s(.+)$/gm, '<h2>$1</h2>')
      .replace(/^#\s(.+)$/gm, '<h1>$1</h1>')
      // Bold + Italic
      .replace(/\*\*\*(.+?)\*\*\*/g, '<strong><em>$1</em></strong>')
      .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
      .replace(/\*(.+?)\*/g, '<em>$1</em>')
      // Inline code
      .replace(/`([^`]+)`/g, '<code>$1</code>')
      // Blockquotes
      .replace(/^>\s(.+)$/gm, '<blockquote>$1</blockquote>')
      // Unordered list items
      .replace(/^[-*]\s(.+)$/gm, '<li>$1</li>')
      // Horizontal rule
      .replace(/^---$/gm, '<hr />')
      // Paragraphs (double newlines)
      .split(/\n\n+/)
      .map(block => {
        if (block.startsWith('<h') || block.startsWith('<hr') || block.startsWith('<li') || block.startsWith('<blockquote')) return block;
        const wrapped = block.replace(/\n/g, '<br/>');
        return `<p>${wrapped}</p>`;
      })
      .join('\n');
    return DOMPurify.sanitize(html);
  }

  let rendered = $derived(renderMarkdown(document.content));

  const FORMAT_LABELS: Record<string, string> = {
    markdown: 'Markdown',
    yaml:     'YAML',
    json:     'JSON',
    text:     'Text',
  };
</script>

<div class="dv-viewer" aria-label="Document viewer: {document.title}">
  <!-- Title bar -->
  <header class="dv-header">
    <div class="dv-title-group">
      <h2 class="dv-title">{document.title}</h2>
      <span class="dv-format">{FORMAT_LABELS[document.format] ?? document.format}</span>
    </div>

    <div class="dv-header-meta">
      {#if document.last_edited_by}
        <span class="dv-meta" aria-label="Last edited by {document.last_edited_by}">
          {document.last_edited_by}
        </span>
      {/if}
      {#if document.updated_at}
        <TimeAgo date={document.updated_at} />
      {/if}
      <button
        class="dv-edit-btn"
        class:dv-edit-btn--active={editMode}
        onclick={() => editMode = !editMode}
        aria-label={editMode ? 'Switch to preview mode' : 'Switch to edit mode'}
        aria-pressed={editMode}
        type="button"
      >
        {#if editMode}
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>
          </svg>
          Preview
        {:else}
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4z"/>
          </svg>
          Edit
        {/if}
      </button>
    </div>
  </header>

  <!-- Content area -->
  <div class="dv-body">
    {#if editMode}
      <textarea
        class="dv-editor"
        bind:value={editContent}
        aria-label="Edit document content"
        spellcheck="true"
      ></textarea>
    {:else if document.format === 'markdown'}
      <!-- eslint-disable-next-line svelte/no-at-html-tags -->
      <div class="dv-markdown" aria-label="Document content">{@html rendered}</div>
    {:else}
      <pre class="dv-code" aria-label="Document content"><code>{document.content}</code></pre>
    {/if}
  </div>
</div>

<style>
  .dv-viewer {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: var(--glass-bg);
    backdrop-filter: var(--glass-blur);
    border: 1px solid var(--glass-border);
    border-radius: var(--radius-md);
    overflow: hidden;
  }

  .dv-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 12px 16px;
    border-bottom: 1px solid var(--border-default);
    flex-shrink: 0;
    background: rgba(0,0,0,0.1);
  }

  .dv-title-group {
    display: flex;
    align-items: center;
    gap: 8px;
    min-width: 0;
  }

  .dv-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .dv-format {
    font-size: 10px;
    font-weight: 500;
    padding: 2px 6px;
    background: rgba(255,255,255,0.07);
    border: 1px solid var(--border-default);
    border-radius: 4px;
    color: var(--text-tertiary);
    white-space: nowrap;
    flex-shrink: 0;
  }

  .dv-header-meta {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-shrink: 0;
  }

  .dv-meta {
    font-size: 11px;
    color: var(--text-muted);
  }

  .dv-edit-btn {
    display: flex;
    align-items: center;
    gap: 5px;
    height: 26px;
    padding: 0 10px;
    border: 1px solid var(--border-default);
    border-radius: var(--radius-xs);
    background: transparent;
    color: var(--text-secondary);
    font-size: 11px;
    font-weight: 500;
    font-family: inherit;
    cursor: pointer;
    transition: background 100ms, color 100ms, border-color 100ms;
  }
  .dv-edit-btn:hover { background: rgba(255,255,255,0.06); }
  .dv-edit-btn--active { background: rgba(59,130,246,0.1); border-color: rgba(59,130,246,0.3); color: #93c5fd; }
  .dv-edit-btn:focus-visible { outline: 2px solid var(--accent-primary); }

  .dv-body {
    flex: 1;
    overflow-y: auto;
    padding: 20px 24px;
  }

  .dv-body::-webkit-scrollbar { width: 6px; }
  .dv-body::-webkit-scrollbar-track { background: transparent; }
  .dv-body::-webkit-scrollbar-thumb { background: var(--border-default); border-radius: 3px; }

  .dv-editor {
    width: 100%;
    height: 100%;
    min-height: 400px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    color: var(--text-primary);
    font-family: var(--font-mono, 'JetBrains Mono', monospace);
    font-size: 13px;
    line-height: 1.6;
    padding: 12px;
    resize: none;
    outline: none;
    transition: border-color 150ms ease;
  }
  .dv-editor:focus { border-color: var(--accent-primary); }

  /* Markdown prose styles */
  .dv-markdown {
    color: var(--text-secondary);
    font-size: 14px;
    line-height: 1.7;
    max-width: 760px;
  }

  :global(.dv-markdown h1) { font-size: 22px; font-weight: 700; color: var(--text-primary); margin: 0 0 16px; }
  :global(.dv-markdown h2) { font-size: 18px; font-weight: 600; color: var(--text-primary); margin: 24px 0 12px; }
  :global(.dv-markdown h3) { font-size: 15px; font-weight: 600; color: var(--text-primary); margin: 20px 0 10px; }
  :global(.dv-markdown h4, .dv-markdown h5, .dv-markdown h6) { font-size: 13px; font-weight: 600; color: var(--text-secondary); margin: 16px 0 8px; }
  :global(.dv-markdown p) { margin: 0 0 12px; }
  :global(.dv-markdown strong) { color: var(--text-primary); font-weight: 600; }
  :global(.dv-markdown em) { font-style: italic; }
  :global(.dv-markdown code) { font-family: var(--font-mono, monospace); font-size: 12px; background: rgba(255,255,255,0.07); padding: 1px 5px; border-radius: 3px; color: #c4b5fd; }
  :global(.dv-markdown blockquote) { border-left: 3px solid var(--accent-primary); padding-left: 12px; color: var(--text-tertiary); margin: 12px 0; }
  :global(.dv-markdown hr) { border: none; border-top: 1px solid var(--border-default); margin: 20px 0; }
  :global(.dv-markdown li) { list-style: disc; margin-left: 20px; margin-bottom: 4px; }
  :global(.dv-empty-doc) { color: var(--text-muted); font-style: italic; }

  .dv-code {
    font-family: var(--font-mono, monospace);
    font-size: 12px;
    line-height: 1.6;
    color: var(--text-secondary);
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    padding: 16px;
    overflow-x: auto;
    white-space: pre;
  }
</style>
