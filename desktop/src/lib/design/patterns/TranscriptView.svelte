<script lang="ts">
/**
 * TranscriptView — renders an ordered list of TranscriptEntry items.
 *
 * 9 rendering branches (assistant, thinking, tool_call, tool_result, diff,
 * stdout, stderr, system, init, result). Auto-scrolls to bottom unless user
 * has scrolled up more than 40px.
 *
 * Tool rendering features: icon mapping, MCP prefix stripping, args preview,
 * grouped sender blocks, live thinking indicator.
 *
 * CSS prefix: tv- (TranscriptView)
 */

import { Activity, Brain, FilePlus, FileText, Search, Terminal, Wrench } from 'lucide-svelte';
import { tick } from 'svelte';
import type { TranscriptEntry } from '$lib/domain/sessions/types.js';
import { groupTranscript } from '$lib/utils/transcript-grouping.js';
import type { GroupedEntry } from '$lib/utils/transcript-grouping.js';

// ── Icon mapping ─────────────────────────────────────────────────────────────
// Maps cleaned tool names to Lucide icons.
type IconComponent = typeof Wrench;

const TOOL_ICON_MAP: Record<string, IconComponent> = {
  read_file: FileText,
  read: FileText,
  Write: FilePlus,
  write_file: FilePlus,
  Edit: FileText,
  edit_file: FileText,
  Bash: Terminal,
  run_command: Terminal,
  bash: Terminal,
  Glob: Search,
  Grep: Search,
  search: Search,
  workspace_status: Activity,
  workspace_get_history: Activity,
};

/** Strip MCP namespace prefixes: mcp__ns__tool_name → tool_name */
function cleanToolName(name: string): string {
  const m = name.match(/^mcp__[^_]+__(.+)$/);
  if (m) return m[1];
  return name;
}

function toolIcon(rawName: string): IconComponent {
  const clean = cleanToolName(rawName);
  return TOOL_ICON_MAP[clean] ?? TOOL_ICON_MAP[rawName] ?? Wrench;
}

/** Extract a short summary from tool args for the collapsed preview line. */
function argsPreview(rawName: string, args: unknown): string {
  const tool = cleanToolName(rawName);
  const s = typeof args === 'string' ? args : JSON.stringify(args ?? '');

  const fileMatch = s.match(/'file_path':\s*'([^']+)'/) ?? s.match(/"file_path":\s*"([^"]+)"/);
  if (
    fileMatch &&
    ['Write', 'Edit', 'Read', 'write_file', 'read_file', 'edit_file'].includes(tool)
  ) {
    return fileMatch[1];
  }

  const commandMatch = s.match(/'command':\s*'([^']+)'/) ?? s.match(/"command":\s*"([^"]+)"/);
  if (commandMatch && ['Bash', 'bash', 'run_command'].includes(tool)) {
    return commandMatch[1].slice(0, 80);
  }

  const patternMatch = s.match(/'pattern':\s*'([^']+)'/) ?? s.match(/"pattern":\s*"([^"]+)"/);
  if (patternMatch) return patternMatch[1];

  return s.length > 60 ? `${s.slice(0, 60)}…` : s;
}

// ── Props ────────────────────────────────────────────────────────────────────

interface Props {
  /** Ordered list of transcript entries to render. */
  messages: TranscriptEntry[];
  /** When true, applies the agent-running animation + live thinking indicator. */
  isStreaming?: boolean;
}

let { messages, isStreaming = false }: Props = $props();

// ── State ────────────────────────────────────────────────────────────────────

let scrollEl: HTMLDivElement | undefined = $state();
let userScrolledUp = $state(false);
let expandedTools = $state<Set<string>>(new Set());
/** When there are > SHOW_LIMIT entries, only show the last SHOW_LIMIT + a header. */
const SHOW_LIMIT = 10;
let showAll = $state(false);

// ── Derived ──────────────────────────────────────────────────────────────────

/** Full grouped list — re-computed on every SSE append (pure function, safe). */
const groupedMessages = $derived(groupTranscript(messages));

const visibleMessages = $derived(
  groupedMessages.length > SHOW_LIMIT && !showAll
    ? groupedMessages.slice(groupedMessages.length - SHOW_LIMIT)
    : groupedMessages
);

const hiddenCount = $derived(
  groupedMessages.length > SHOW_LIMIT && !showAll ? groupedMessages.length - SHOW_LIMIT : 0
);

/** True when the last entry is a thinking entry and we are still streaming. */
const isLiveThinking = $derived(
  isStreaming && messages.length > 0 && messages[messages.length - 1].kind === 'thinking'
);

// ── Scroll ───────────────────────────────────────────────────────────────────

function handleScroll() {
  if (!scrollEl) return;
  const { scrollTop, clientHeight, scrollHeight } = scrollEl;
  userScrolledUp = scrollTop + clientHeight < scrollHeight - 40;
}

async function scrollToBottom() {
  await tick();
  if (!scrollEl || userScrolledUp) return;
  scrollEl.scrollTop = scrollEl.scrollHeight;
}

$effect(() => {
  void messages.length;
  void scrollToBottom();
});

// ── Accordion toggle ─────────────────────────────────────────────────────────

function toggleTool(id: string) {
  expandedTools = new Set(
    expandedTools.has(id) ? [...expandedTools].filter((k) => k !== id) : [...expandedTools, id]
  );
}

// ── Formatting helpers ───────────────────────────────────────────────────────

function stringify(val: unknown): string {
  if (typeof val === 'string') return val;
  try {
    return JSON.stringify(val, null, 2);
  } catch {
    return String(val);
  }
}

function entryKey(grouped: GroupedEntry): string {
  if (grouped.kind === 'single') return grouped.entry.id;
  if (grouped.kind === 'command_group') return `cg-${grouped.commands[0].call.id}`;
  return `tg-${grouped.tools[0].call.id}`;
}

/**
 * Default collapsed threshold: collapse command_groups with >5 commands,
 * collapse tool_groups with >3 tools.
 */
const CMD_COLLAPSE_THRESHOLD = 5;
const TOOL_COLLAPSE_THRESHOLD = 3;
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
    <!-- Show all / show less toggle -->
    {#if hiddenCount > 0}
      <button class="tv-show-more" onclick={() => (showAll = true)}>
        ↑ {hiddenCount} earlier {hiddenCount === 1 ? 'entry' : 'entries'}
      </button>
    {:else if showAll && messages.length > SHOW_LIMIT}
      <button class="tv-show-more" onclick={() => (showAll = false)}>
        Show less
      </button>
    {/if}

    {#each visibleMessages as grouped (entryKey(grouped))}

      <!-- ── command_group — collapsible shell run block ── -->
      {#if grouped.kind === 'command_group'}
        {@const failCount = grouped.exitCodes.filter((c) => c !== 0 && c !== -1).length}
        {@const defaultOpen = grouped.commands.length <= CMD_COLLAPSE_THRESHOLD}
        <details class="tv-group tv-group--cmd" open={defaultOpen}>
          <summary class="tv-group-summary">
            <span class="tv-group-chevron" aria-hidden="true">▸</span>
            <Terminal size={12} class="tv-icon tv-icon--cmd" aria-hidden="true" />
            <span class="tv-group-label">
              {grouped.commands.length} shell {grouped.commands.length === 1 ? 'command' : 'commands'}
            </span>
            {#if failCount > 0}
              <span class="tv-group-badge tv-group-badge--fail">{failCount} failed</span>
            {/if}
          </summary>
          <div class="tv-group-body">
            {#each grouped.commands as { call, result }, cmdIdx}
              {@const cmdPreview = argsPreview(call.toolName, call.args)}
              {@const exitCode = grouped.exitCodes[cmdIdx]}
              {@const rowId = `cmd-row-${call.id}`}
              <details class="tv-cmd-row" id={rowId}>
                <summary class="tv-cmd-row-summary">
                  <span
                    class="tv-exit-dot"
                    class:tv-exit-dot--ok={exitCode === 0}
                    class:tv-exit-dot--err={exitCode !== 0 && exitCode !== -1}
                    aria-label={exitCode === 0 ? 'success' : exitCode === -1 ? 'unknown' : 'failed'}
                  ></span>
                  <span class="tv-cmd-text">$ {cmdPreview}</span>
                </summary>
                {#if result}
                  <pre class="tv-cmd-output">{result.content}</pre>
                {/if}
              </details>
            {/each}
          </div>
        </details>

      <!-- ── tool_group — collapsible non-shell tool block ── -->
      {:else if grouped.kind === 'tool_group'}
        {@const uniqueNames = [...new Set(grouped.toolNames)]}
        {@const namesSummary = uniqueNames.slice(0, 4).join(', ') + (uniqueNames.length > 4 ? ', …' : '')}
        {@const defaultOpen = grouped.tools.length <= TOOL_COLLAPSE_THRESHOLD}
        <details class="tv-group tv-group--tools" open={defaultOpen}>
          <summary class="tv-group-summary">
            <span class="tv-group-chevron" aria-hidden="true">▸</span>
            <Wrench size={12} class="tv-icon tv-icon--tool" aria-hidden="true" />
            <span class="tv-group-label">
              {grouped.tools.length} tool {grouped.tools.length === 1 ? 'call' : 'calls'}:
            </span>
            <span class="tv-group-names">{namesSummary}</span>
          </summary>
          <div class="tv-group-body">
            {#each grouped.tools as { call, result }}
              {@const cleanName = cleanToolName(call.toolName)}
              {@const preview = argsPreview(call.toolName, call.args)}
              <details class="tv-cmd-row">
                <summary class="tv-cmd-row-summary">
                  <span class="tv-tool-name-inline">{cleanName}</span>
                  {#if preview}
                    <span class="tv-tool-sep" aria-hidden="true">›</span>
                    <span class="tv-cmd-text">{preview}</span>
                  {/if}
                </summary>
                {#if result}
                  <pre class="tv-cmd-output" class:tv-cmd-output--err={result.isError}>{result.content}</pre>
                {/if}
              </details>
            {/each}
          </div>
        </details>

      <!-- ── single entry — existing render paths unchanged ── -->
      {:else}
        {@const entry = grouped.entry}
        <div class="tv-entry tv-entry--{entry.kind} list-item">

          <!-- assistant -->
          {#if entry.kind === 'assistant'}
            <p class="tv-assistant-text">{entry.text}</p>

          <!-- thinking — enhanced with live pulse when streaming -->
          {:else if entry.kind === 'thinking'}
            <div class="tv-thinking-block" class:tv-thinking-block--live={isLiveThinking && entry === messages[messages.length - 1]}>
              <div class="tv-thinking-header">
                <Brain size={12} class="tv-icon tv-icon--thinking" aria-hidden="true" />
                <span class="tv-thinking-label" class:thinking={isLiveThinking}>thinking</span>
              </div>
              {#if entry.text && entry.text.toLowerCase() !== 'thinking' && entry.text !== 'thinking...'}
                <p class="tv-thinking-text">{entry.text}</p>
              {/if}
            </div>

          <!-- tool_call — collapsible card with icon + preview -->
          {:else if entry.kind === 'tool_call'}
            {@const toolId = entry.toolCallId}
            {@const isOpen = expandedTools.has(toolId)}
            {@const cleanName = cleanToolName(entry.toolName)}
            {@const Icon = toolIcon(entry.toolName)}
            {@const preview = argsPreview(entry.toolName, entry.args)}
            <div class="tv-tool-call" data-tool-id={toolId}>
              <button
                class="tv-tool-header"
                onclick={() => toggleTool(toolId)}
                aria-expanded={isOpen}
                aria-label="Toggle tool call: {cleanName}"
              >
                <span class="tv-tool-icon-wrap">
                  <Icon size={12} aria-hidden="true" />
                </span>
                <span class="tv-tool-name">{cleanName}</span>
                {#if preview && !isOpen}
                  <span class="tv-tool-sep" aria-hidden="true">›</span>
                  <span class="tv-tool-preview">{preview}</span>
                {/if}
                <span class="tv-tool-chevron" class:open={isOpen} aria-hidden="true">▸</span>
              </button>
              {#if isOpen}
                <pre class="tv-tool-args">{stringify(entry.args)}</pre>
              {/if}
            </div>

          <!-- tool_result — tinted to match its parent tool_call -->
          {:else if entry.kind === 'tool_result'}
            {@const resultId = `result-${entry.toolCallId}`}
            {@const isOpen = expandedTools.has(resultId)}
            <div
              class="tv-tool-result"
              class:tv-tool-result--error={entry.isError}
              data-parent-tool={entry.toolCallId}
            >
              <button
                class="tv-tool-header tv-tool-header--result"
                onclick={() => toggleTool(resultId)}
                aria-expanded={isOpen}
                aria-label="Toggle tool result"
              >
                <span class="tv-result-label">{entry.isError ? '✕ Error' : '✓ Result'}</span>
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
      {/if}

    {/each}

    <!-- Live activity indicator when streaming and not already in thinking -->
    {#if isStreaming && !isLiveThinking}
      <div class="tv-activity" aria-label="Agent is working" aria-live="polite">
        <span class="tv-activity-dot"></span>
        <span class="tv-activity-dot"></span>
        <span class="tv-activity-dot"></span>
      </div>
    {/if}
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

  /* Show more/less toggle */
  .tv-show-more {
    display: block;
    width: 100%;
    padding: var(--space-2) var(--space-3);
    background: transparent;
    border: 1px dashed var(--border);
    border-radius: var(--radius-md);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    cursor: pointer;
    text-align: center;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .tv-show-more:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
    color: var(--fg-muted);
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

  /* thinking — enhanced block */
  .tv-thinking-block {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: var(--space-2) var(--space-3);
    border-left: 2px solid color-mix(in oklch, var(--signal-thinking) 40%, transparent 60%);
    background: color-mix(in oklch, var(--signal-thinking) 5%, transparent 95%);
    border-radius: 0 var(--radius-md) var(--radius-md) 0;
  }

  .tv-thinking-block--live {
    border-left-color: var(--signal-thinking);
  }

  .tv-thinking-header {
    display: flex;
    align-items: center;
    gap: var(--space-1);
  }

  :global(.tv-icon--thinking) {
    color: var(--signal-thinking) !important;
    flex-shrink: 0;
  }

  .tv-thinking-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-style: italic;
    color: var(--signal-thinking);
    opacity: 0.8;
  }

  /* thinking keyframe re-use from design spec */
  .thinking {
    animation: thinking-shimmer 1.4s var(--ease-io, cubic-bezier(0.65, 0, 0.35, 1)) infinite;
  }

  @keyframes thinking-shimmer {
    0%, 100% { opacity: 0.5; }
    50%       { opacity: 1; }
  }

  .tv-thinking-text {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    line-height: 1.6;
    white-space: pre-wrap;
  }

  /* tool call / result shared header */
  .tv-tool-call,
  .tv-tool-result {
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    overflow: hidden;
    background: color-mix(in oklch, var(--bg-inset) 80%, transparent 20%);
  }

  /* tool_result tinted green on left to visually link to parent tool_call */
  .tv-tool-result {
    border-left: 3px solid color-mix(in oklch, var(--signal-thinking) 35%, var(--border) 65%);
  }

  .tv-tool-result--error {
    border-color: color-mix(in oklch, var(--signal-error) 40%, var(--border) 60%);
    border-left-color: var(--signal-error);
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
    transition: background var(--dur-instant) var(--ease-out);
    gap: var(--space-2);
    min-width: 0;
  }

  .tv-tool-header:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  .tv-tool-icon-wrap {
    display: flex;
    align-items: center;
    color: var(--signal-thinking);
    flex-shrink: 0;
  }

  .tv-tool-name {
    color: var(--signal-thinking);
    font-weight: 600;
    flex-shrink: 0;
  }

  .tv-tool-sep {
    color: color-mix(in oklch, var(--fg-subtle) 40%, transparent 60%);
    flex-shrink: 0;
  }

  .tv-tool-preview {
    color: var(--fg-subtle);
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
  }

  .tv-tool-header--result {
    cursor: pointer;
  }

  .tv-result-label {
    color: var(--fg-subtle);
    flex: 1;
  }

  .tv-tool-result--error .tv-result-label {
    color: var(--signal-error);
  }

  .tv-tool-chevron {
    font-size: 10px;
    transition: transform 0.15s var(--ease-out, cubic-bezier(0.16, 1, 0.3, 1));
    display: inline-block;
    flex-shrink: 0;
    color: var(--fg-subtle);
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
    max-height: 240px;
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

  .tv-diff-add { color: var(--signal-running); }
  .tv-diff-del { color: var(--signal-error); }

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

  .tv-diff-link:hover { color: var(--fg); }

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

  /* ── Group blocks (command_group + tool_group) ─────────────────────────── */

  .tv-group {
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    overflow: hidden;
    background: color-mix(in oklch, var(--bg-inset) 80%, transparent 20%);
  }

  .tv-group-summary {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    cursor: pointer;
    list-style: none;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    font-weight: 500;
    user-select: none;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .tv-group-summary::-webkit-details-marker { display: none; }

  .tv-group-summary:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  .tv-group-chevron {
    font-size: 10px;
    transition: transform 0.15s var(--ease-out, cubic-bezier(0.16, 1, 0.3, 1));
    display: inline-block;
    flex-shrink: 0;
    color: var(--fg-subtle);
  }

  details[open] > .tv-group-summary > .tv-group-chevron {
    transform: rotate(90deg);
  }

  :global(.tv-icon--cmd) {
    color: var(--signal-thinking) !important;
    flex-shrink: 0;
  }

  :global(.tv-icon--tool) {
    color: var(--fg-muted) !important;
    flex-shrink: 0;
  }

  .tv-group-label {
    color: var(--signal-thinking);
    font-weight: 600;
    flex-shrink: 0;
  }

  .tv-group--tools .tv-group-label {
    color: var(--fg-muted);
  }

  .tv-group-names {
    color: var(--fg-subtle);
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
  }

  .tv-group-badge {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    padding: 1px 6px;
    border-radius: 999px;
    flex-shrink: 0;
  }

  .tv-group-badge--fail {
    /* --signal-error if defined, else oklch fallback */
    background: color-mix(in oklch, var(--signal-error, oklch(0.55 0.22 25)) 15%, transparent 85%);
    color: var(--signal-error, oklch(0.55 0.22 25));
  }

  .tv-group-body {
    border-top: 1px solid var(--border);
    display: flex;
    flex-direction: column;
  }

  /* Individual command / tool rows within a group */
  .tv-cmd-row {
    border-bottom: 1px solid color-mix(in oklch, var(--border) 50%, transparent 50%);
  }

  .tv-cmd-row:last-child { border-bottom: none; }

  .tv-cmd-row-summary {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-1) var(--space-3);
    cursor: pointer;
    list-style: none;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    transition: background var(--dur-instant) var(--ease-out);
    min-width: 0;
  }

  .tv-cmd-row-summary::-webkit-details-marker { display: none; }

  .tv-cmd-row-summary:hover {
    background: color-mix(in oklch, var(--fg) 3%, transparent 97%);
  }

  .tv-exit-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    flex-shrink: 0;
    /* neutral / unknown — uses fg-subtle tint */
    background: color-mix(in oklch, var(--fg-subtle) 40%, transparent 60%);
  }

  .tv-exit-dot--ok {
    /* --signal-success if defined, else oklch green */
    background: var(--signal-success, oklch(0.65 0.18 145)); /* reconcile when token confirmed */
  }

  .tv-exit-dot--err {
    background: var(--signal-error, oklch(0.55 0.22 25)); /* reconcile when token confirmed */
  }

  .tv-cmd-text {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
    color: var(--fg-muted);
  }

  .tv-tool-name-inline {
    color: var(--signal-thinking);
    font-weight: 600;
    flex-shrink: 0;
  }

  .tv-cmd-output {
    margin: 0;
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    line-height: 1.6;
    color: var(--fg-muted);
    border-top: 1px solid color-mix(in oklch, var(--border) 50%, transparent 50%);
    overflow-x: auto;
    max-height: 200px;
    white-space: pre-wrap;
    word-break: break-all;
    background: color-mix(in oklch, var(--bg-inset) 60%, transparent 40%);
  }

  .tv-cmd-output--err {
    color: var(--signal-error, oklch(0.55 0.22 25));
    background: color-mix(in oklch, var(--signal-error, oklch(0.55 0.22 25)) 5%, transparent 95%);
  }

  /* Live activity dots — breathing animation when streaming but not in thinking */
  .tv-activity {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: var(--space-2) var(--space-1);
  }

  .tv-activity-dot {
    width: 5px;
    height: 5px;
    border-radius: 50%;
    background: var(--fg-subtle);
    animation: tv-dot-breathe 1.4s ease-in-out infinite;
  }

  .tv-activity-dot:nth-child(2) { animation-delay: 0.2s; }
  .tv-activity-dot:nth-child(3) { animation-delay: 0.4s; }

  @keyframes tv-dot-breathe {
    0%, 100% { opacity: 0.25; transform: scale(0.8); }
    50%       { opacity: 1;    transform: scale(1.1); }
  }
</style>
