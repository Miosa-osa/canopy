<!-- src/lib/components/chat/MessageBubble.svelte -->
<!-- Full message bubble: markdown body, thinking block, tool calls, streaming cursor -->
<script lang="ts">
  import { marked } from 'marked';
  import DOMPurify from 'dompurify';
  import type { Message } from '$lib/api/types';
  import StreamingCursor from './StreamingCursor.svelte';
  import ThinkingBlock from './ThinkingBlock.svelte';
  import ToolCall from './ToolCall.svelte';
  import CodeBlock from './CodeBlock.svelte';

  interface Props {
    message: Message;
    isStreaming?: boolean;
    thinkingText?: string;
    /** Live text buffer while streaming (takes priority over message.content) */
    liveText?: string;
  }

  let { message, isStreaming = false, thinkingText, liveText }: Props = $props();

  const isUser = $derived(message.role === 'user');
  const isAssistant = $derived(message.role === 'assistant');

  // Body text — prefer live buffer during streaming
  const bodyText = $derived(liveText !== undefined ? liveText : message.content);

  // Parse markdown into HTML for assistant messages
  // Extract code blocks before rendering so we can swap in CodeBlock components
  interface ParsedSegment {
    type: 'text' | 'code';
    content: string;
    lang?: string;
  }

  const segments = $derived.by((): ParsedSegment[] => {
    if (!isAssistant || !bodyText) return [{ type: 'text', content: bodyText ?? '' }];

    const result: ParsedSegment[] = [];
    const codeBlockRe = /```(\w*)\n?([\s\S]*?)```/g;
    let lastIndex = 0;
    let match: RegExpExecArray | null;

    while ((match = codeBlockRe.exec(bodyText)) !== null) {
      if (match.index > lastIndex) {
        result.push({ type: 'text', content: bodyText.slice(lastIndex, match.index) });
      }
      result.push({ type: 'code', lang: match[1] || undefined, content: match[2] });
      lastIndex = match.index + match[0].length;
    }

    if (lastIndex < bodyText.length) {
      result.push({ type: 'text', content: bodyText.slice(lastIndex) });
    }

    return result.length ? result : [{ type: 'text', content: bodyText }];
  });

  function renderMarkdown(text: string): string {
    if (!text) return '';
    try {
      const raw = marked.parse(text, { async: false }) as string;
      return DOMPurify.sanitize(raw);
    } catch {
      return DOMPurify.sanitize(text);
    }
  }

  // Timestamp — short relative format
  function formatTime(iso: string): string {
    const d = new Date(iso);
    return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }
</script>

<div
  class="mb-wrap"
  class:mb-wrap--user={isUser}
  class:mb-wrap--assistant={isAssistant}
  role="article"
  aria-label="{isUser ? 'Your' : 'Canopy'} message"
>
  {#if isAssistant}
    <!-- Avatar -->
    <div class="mb-avatar" aria-hidden="true">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 14.5v-9l6 4.5-6 4.5z"/>
      </svg>
    </div>
  {/if}

  <div class="mb-content">
    {#if isAssistant}
      <p class="mb-author">Canopy</p>
    {/if}

    <!-- Thinking block (live during streaming, or from message) -->
    {#if thinkingText || message.thinking?.thinking}
      <ThinkingBlock
        thinking={thinkingText ?? message.thinking?.thinking ?? ''}
        isStreaming={isStreaming && !!thinkingText}
      />
    {/if}

    <!-- Message body -->
    {#if isUser}
      <div class="mb-user-text">{bodyText}</div>
    {:else if isAssistant}
      <div class="mb-assistant-body">
        {#each segments as seg (seg.content.slice(0, 32) + seg.type)}
          {#if seg.type === 'code'}
            <CodeBlock code={seg.content} lang={seg.lang ?? ''} />
          {:else}
            <!-- eslint-disable-next-line svelte/no-at-html-tags -->
            <div class="mb-md">{@html renderMarkdown(seg.content)}</div>
          {/if}
        {/each}
        {#if isStreaming}
          <StreamingCursor />
        {/if}
      </div>
    {/if}

    <!-- Tool calls -->
    {#if message.tool_calls && message.tool_calls.length > 0}
      <div class="mb-tools" role="list" aria-label="Tool calls">
        {#each message.tool_calls as tc (tc.id)}
          <div role="listitem">
            <ToolCall tool={tc} />
          </div>
        {/each}
      </div>
    {/if}

    <time class="mb-time" datetime={message.timestamp}>
      {formatTime(message.timestamp)}
    </time>
  </div>
</div>

<style>
  .mb-wrap {
    display: flex;
    gap: 10px;
    align-items: flex-start;
    max-width: 100%;
  }

  .mb-wrap--user {
    flex-direction: row-reverse;
  }

  /* Avatar */
  .mb-avatar {
    flex-shrink: 0;
    width: 28px;
    height: 28px;
    border-radius: 50%;
    background: var(--accent-glow, rgba(59, 130, 246, 0.15));
    border: 1px solid rgba(59, 130, 246, 0.25);
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--accent-primary, #3b82f6);
    margin-top: 2px;
  }

  /* Content column */
  .mb-content {
    display: flex;
    flex-direction: column;
    gap: 4px;
    min-width: 0;
    max-width: calc(100% - 38px);
  }

  .mb-author {
    margin: 0;
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    color: var(--text-tertiary);
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }

  /* User bubble */
  .mb-user-text {
    padding: 9px 13px;
    border-radius: var(--radius-md) var(--radius-xs) var(--radius-md) var(--radius-md);
    background: rgba(59, 130, 246, 0.18);
    border: 1px solid rgba(59, 130, 246, 0.28);
    font-family: var(--font-sans);
    font-size: 13.5px;
    line-height: 1.55;
    color: var(--text-primary);
    white-space: pre-wrap;
    word-break: break-word;
  }

  /* Assistant body — transparent, no bubble */
  .mb-assistant-body {
    font-family: var(--font-sans);
    font-size: 13.5px;
    line-height: 1.6;
    color: var(--text-primary);
    min-width: 0;
  }

  /* Markdown output */
  :global(.mb-md p) {
    margin: 0 0 0.6em;
  }
  :global(.mb-md p:last-child) {
    margin-bottom: 0;
  }
  :global(.mb-md ul, .mb-md ol) {
    margin: 0.4em 0 0.6em 1.2em;
    padding: 0;
  }
  :global(.mb-md li) {
    margin-bottom: 0.2em;
  }
  :global(.mb-md h1, .mb-md h2, .mb-md h3) {
    margin: 0.8em 0 0.3em;
    font-weight: 600;
    color: var(--text-primary);
  }
  :global(.mb-md code) {
    font-family: var(--font-mono, ui-monospace, monospace);
    font-size: 0.88em;
    background: rgba(255, 255, 255, 0.08);
    border-radius: 3px;
    padding: 1px 5px;
    color: #93c5fd;
  }
  :global(.mb-md a) {
    color: var(--accent-primary, #3b82f6);
    text-decoration: none;
  }
  :global(.mb-md a:hover) {
    text-decoration: underline;
  }
  :global(.mb-md blockquote) {
    border-left: 3px solid rgba(255, 255, 255, 0.15);
    margin: 0.5em 0;
    padding: 2px 12px;
    color: var(--text-secondary);
  }
  :global(.mb-md hr) {
    border: none;
    border-top: 1px solid var(--border-default);
    margin: 0.8em 0;
  }
  :global(.mb-md table) {
    border-collapse: collapse;
    width: 100%;
    font-size: 12.5px;
  }
  :global(.mb-md th, .mb-md td) {
    border: 1px solid var(--border-default);
    padding: 5px 10px;
    text-align: left;
  }
  :global(.mb-md th) {
    background: rgba(255, 255, 255, 0.05);
    font-weight: 600;
  }

  .mb-tools {
    display: flex;
    flex-direction: column;
    gap: 3px;
    margin-top: 4px;
  }

  .mb-time {
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--text-muted, #404040);
    align-self: flex-end;
    margin-top: 2px;
  }
</style>
