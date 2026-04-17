<script lang="ts">
/**
 * TranscriptView — renders an ordered list of TranscriptEntry items.
 *
 * 9 rendering branches (assistant, thinking, tool_call, tool_result, diff,
 * stdout, stderr, system, init, result). Auto-scrolls to bottom unless user
 * has scrolled up more than 40px.
 *
 * CSS prefix: tv- (TranscriptView)
 */
import { tick } from 'svelte';
import type { TranscriptEntry } from '$lib/domain/sessions/types.js';

interface Props {
  /** Ordered list of transcript entries to render. */
  messages: TranscriptEntry[];
  /** When true, applies the agent-running animation to the container. */
  isStreaming?: boolean;
}

let { messages, isStreaming = false }: Props = $props();

let scrollEl: HTMLDivElement | undefined = $state();
let userScrolledUp = $state(false);
let expandedTools = $state<Set<string>>(new Set());

/** Track user scroll position to suppress auto-scroll when reading up. */
function handleScroll() {
  if (!scrollEl) return;
  const { scrollTop, clientHeight, scrollHeight } = scrollEl;
  userScrolledUp = scrollTop + clientHeight < scrollHeight - 40;
}

/** Toggle a tool_call/tool_result accordion. */
function toggleTool(id: string) {
  expandedTools = new Set(
    expandedTools.has(id) ? [...expandedTools].filter((k) => k !== id) : [...expandedTools, id]
  );
}

/** Scroll to bottom unless user is reading above. */
async function scrollToBottom() {
  await tick();
  if (!scrollEl || userScrolledUp) return;
  scrollEl.scrollTop = scrollEl.scrollHeight;
}

$effect(() => {
  // Re-run whenever messages array length changes.
  void messages.length;
  void scrollToBottom();
});

/** Format cost display for a result entry. */
function formatCost(val: unknown): string {
  const n = Number(val);
  return Number.isFinite(n) ? `$${n.toFixed(4)}` : '—';
}

function formatTokens(val: unknown): string {
  const n = Number(val);
  return Number.isFinite(n) ? n.toLocaleString() : '—';
}

function stringify(val: unknown): string {
  if (typeof val === 'string') return val;
  try {
    return JSON.stringify(val, null, 2);
  } catch {
    return String(val);
  }
}

function entryKey(entry: TranscriptEntry): string {
  return entry.id;
}
</script>

<div
  class="tv-root"
  class:agent-running={isStreaming}
  bind:this={scrollEl}
  onscroll={handleScroll}
  role="log"
  aria-live="polite"
  aria-label="Session transcript"
>
  {#if messages.length === 0}
    <div class="tv-empty">
      <span class="tv-empty-text">No output yet.</span>
    </div>
  {:else}
    {#each messages as entry (entryKey(entry))}
      <div class="tv-entry tv-entry--{entry.kind} list-item">

        <!-- assistant -->
        {#if entry.kind === 'assistant'}
          <p class="tv-assistant-text">{entry.text}</p>

        <!-- thinking -->
        {:else if entry.kind === 'thinking'}
          <p class="tv-thinking thinking">{entry.text}</p>

        <!-- tool_call -->
        {:else if entry.kind === 'tool_call'}
          {@const toolId = entry.toolCallId}
          {@const isOpen = expandedTools.has(toolId)}
          <div class="tv-tool-call">
            <button
              class="tv-tool-header"
              onclick={() => toggleTool(toolId)}
              aria-expanded={isOpen}
              aria-label="Toggle tool call: {entry.toolName}"
            >
              <span class="tv-tool-name">{entry.toolName}</span>
              <span class="tv-tool-chevron" class:open={isOpen} aria-hidden="true">▸</span>
            </button>
            {#if isOpen}
              <pre class="tv-tool-args">{stringify(entry.args)}</pre>
            {/if}
          </div>

        <!-- tool_result -->
        {:else if entry.kind === 'tool_result'}
          {@const resultId = `result-${entry.toolCallId}`}
          {@const isOpen = expandedTools.has(resultId)}
          <div class="tv-tool-result" class:tv-tool-result--error={entry.isError}>
            <button
              class="tv-tool-header"
              onclick={() => toggleTool(resultId)}
              aria-expanded={isOpen}
              aria-label="Toggle tool result"
            >
              <span class="tv-result-label">{entry.isError ? 'Error' : 'Result'}</span>
              <span class="tv-tool-chevron" class:open={isOpen} aria-hidden="true">▸</span>
            </button>
            {#if isOpen}
              <pre class="tv-tool-args">{entry.content}</pre>
            {/if}
          </div>

        <!-- diff -->
        {:else if entry.kind === 'diff'}
          <div class="tv-diff">
            <div class="tv-diff-header">
              <span class="tv-diff-path">{entry.filePath}</span>
              <span class="tv-diff-stats">
                <span class="tv-diff-add">+{entry.additions}</span>
                <span class="tv-diff-del">-{entry.deletions}</span>
              </span>
              <!-- placeholder — full diff viewer in Week 2 -->
              <button class="tv-diff-link" onclick={() => {}}>Review Changes →</button>
            </div>
            <pre class="tv-diff-patch">{entry.patch.slice(0, 600)}{entry.patch.length > 600 ? '\n…' : ''}</pre>
          </div>

        <!-- stdout -->
        {:else if entry.kind === 'stdout'}
          <pre class="tv-stdout">{entry.text}</pre>

        <!-- stderr -->
        {:else if entry.kind === 'stderr'}
          <pre class="tv-stderr">{entry.text}</pre>

        <!-- system -->
        {:else if entry.kind === 'system'}
          <p class="tv-system">{entry.text}</p>

        {/if}
      </div>
    {/each}
  {/if}
</div>

<style>
  .tv-root {
    flex: 1;
    overflow-y: auto;
    overscroll-behavior: contain;
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-4);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .tv-empty {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .tv-empty-text {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    font-style: italic;
  }

  /* Entry base */
  .tv-entry {
    display: flex;
    flex-direction: column;
  }

  /* assistant */
  .tv-assistant-text {
    margin: 0;
    font-family: var(--font-sans);
    font-size: 15px;
    line-height: 1.65;
    color: var(--fg);
  }

  /* thinking */
  .tv-thinking {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-style: italic;
    color: var(--fg-muted);
    line-height: 1.6;
  }

  /* tool call / result shared header */
  .tv-tool-call,
  .tv-tool-result {
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    overflow: hidden;
    background: color-mix(in oklch, var(--bg-inset) 80%, transparent 20%);
  }

  .tv-tool-result--error {
    border-color: color-mix(in oklch, var(--signal-error) 40%, var(--border) 60%);
  }

  .tv-tool-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-2) var(--space-3);
    background: transparent;
    border: none;
    cursor: pointer;
    width: 100%;
    text-align: left;
    color: var(--fg-muted);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    font-weight: 500;
    transition: background 0.15s;
  }

  .tv-tool-header:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  .tv-tool-name {
    color: var(--signal-thinking);
  }

  .tv-result-label {
    color: var(--fg-subtle);
  }

  .tv-tool-result--error .tv-result-label {
    color: var(--signal-error);
  }

  .tv-tool-chevron {
    font-size: 10px;
    transition: transform 0.15s var(--ease-out);
    display: inline-block;
  }

  .tv-tool-chevron.open {
    transform: rotate(90deg);
  }

  .tv-tool-args {
    margin: 0;
    padding: var(--space-3);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    line-height: 1.6;
    color: var(--fg-muted);
    border-top: 1px solid var(--border);
    overflow-x: auto;
    white-space: pre-wrap;
    word-break: break-all;
  }

  /* diff */
  .tv-diff {
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    overflow: hidden;
    background: color-mix(in oklch, var(--bg-inset) 80%, transparent 20%);
  }

  .tv-diff-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-wrap: wrap;
  }

  .tv-diff-path {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .tv-diff-stats {
    display: flex;
    gap: var(--space-1);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    flex-shrink: 0;
  }

  .tv-diff-add {
    color: var(--signal-running);
  }

  .tv-diff-del {
    color: var(--signal-error);
  }

  .tv-diff-link {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    background: transparent;
    border: none;
    cursor: pointer;
    text-decoration: underline;
    text-underline-offset: 2px;
    padding: 0;
    white-space: nowrap;
    flex-shrink: 0;
  }

  .tv-diff-link:hover {
    color: var(--fg);
  }

  .tv-diff-patch {
    margin: 0;
    padding: var(--space-3);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    line-height: 1.6;
    color: var(--fg-muted);
    overflow-x: auto;
    white-space: pre;
  }

  /* stdout */
  .tv-stdout {
    margin: 0;
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    line-height: 1.6;
    color: var(--fg-muted);
    background: transparent;
    white-space: pre-wrap;
    word-break: break-all;
  }

  /* stderr */
  .tv-stderr {
    margin: 0;
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    line-height: 1.6;
    color: var(--signal-error);
    background: color-mix(in oklch, var(--signal-error) 5%, transparent 95%);
    border-radius: var(--radius-md);
    white-space: pre-wrap;
    word-break: break-all;
  }

  /* system */
  .tv-system {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-style: italic;
    color: var(--fg-subtle);
  }
</style>
