<script lang="ts">
/**
 * Block — single-block renderer for the agentic terminal.
 *
 * Discriminates on `kind` and delegates the body to the matching
 * kind-specific component. Header carries the kind icon, status pill,
 * duration + cost, and a collapse toggle. Footer carries action buttons
 * (copy, re-run, share, pin, delete) emitted via callback props.
 *
 * Thin component — owns no state beyond local UI (collapsed). Renders
 * existing foundation primitives (Button) and emits actions via props.
 *
 * CSS prefix: blk-
 */

import {
  AlertTriangle,
  Bot,
  ChevronDown,
  ChevronRight,
  Copy,
  FileDiff,
  Info,
  Pin,
  Play,
  Share2,
  ShieldAlert,
  Terminal,
  Trash2,
  Wrench,
} from 'lucide-svelte';

import type { BlockKind, BlockStatus, Block as BlockType } from '$lib/domain/blocks/types.js';

import AgentMessageBlock from './AgentMessageBlock.svelte';
import ApprovalBlock from './ApprovalBlock.svelte';
import CommandBlock from './CommandBlock.svelte';
import SystemEventBlock from './SystemEventBlock.svelte';
import ToolCallBlock from './ToolCallBlock.svelte';

type IconComponent = typeof Info;

const KIND_ICONS: Record<BlockKind, IconComponent> = {
  command: Terminal,
  agent_message: Bot,
  tool_call: Wrench,
  tool_result: Wrench,
  approval: ShieldAlert,
  diff: FileDiff,
  system_event: Info,
  error: AlertTriangle,
};

const KIND_LABEL: Record<BlockKind, string> = {
  command: 'command',
  agent_message: 'agent',
  tool_call: 'tool',
  tool_result: 'tool result',
  approval: 'approval',
  diff: 'diff',
  system_event: 'system',
  error: 'error',
};

// ── Props ────────────────────────────────────────────────────────────────

interface Props {
  block: BlockType;
  /** Optional inline-controls — emitted up to the parent stream. */
  onCopy?: (block: BlockType) => void;
  onRerun?: (block: BlockType) => void;
  onShare?: (block: BlockType) => void;
  onPin?: (block: BlockType) => void;
  onDelete?: (block: BlockType) => void;
  /** When true, collapse the body by default. */
  defaultCollapsed?: boolean;
  /** When true, renders with a keyboard-focus highlight ring. */
  isFocused?: boolean;
}

let {
  block,
  onCopy,
  onRerun,
  onShare,
  onPin,
  onDelete,
  defaultCollapsed = false,
  isFocused = false,
}: Props = $props();

let collapsed = $state(defaultCollapsed);

// ── Derived ──────────────────────────────────────────────────────────────

const KindIcon = $derived(KIND_ICONS[block.kind] ?? Info);
const kindLabel = $derived(KIND_LABEL[block.kind] ?? block.kind);

const durationLabel = $derived(formatDuration(block.durationMs));
const costLabel = $derived(formatCost(block.costCents));
const isPinned = $derived(block.tags.includes('pinned'));

function formatDuration(ms: number | null): string | null {
  if (ms == null) return null;
  if (ms < 1000) return `${ms}ms`;
  if (ms < 60_000) return `${(ms / 1000).toFixed(1)}s`;
  const minutes = Math.floor(ms / 60_000);
  const seconds = Math.round((ms % 60_000) / 1000);
  return `${minutes}m ${seconds}s`;
}

function formatCost(cents: number | null): string | null {
  if (cents == null || cents === 0) return null;
  return `$${(cents / 100).toFixed(2)}`;
}

function statusVariant(status: BlockStatus): string {
  return `blk-pill--${status}`;
}

function toggle() {
  collapsed = !collapsed;
}
</script>

<article class="blk-root" class:blk-focused={isFocused} data-kind={block.kind} data-status={block.status} aria-label="{kindLabel} block">
  <header class="blk-header">
    <button
      class="blk-toggle"
      onclick={toggle}
      aria-label={collapsed ? 'Expand block' : 'Collapse block'}
      aria-expanded={!collapsed}
    >
      {#if collapsed}
        <ChevronRight size={12} aria-hidden="true" />
      {:else}
        <ChevronDown size={12} aria-hidden="true" />
      {/if}
    </button>

    <span class="blk-kind-icon" aria-hidden="true">
      <KindIcon size={12} />
    </span>

    <span class="blk-kind-label">{kindLabel}</span>

    <span class="blk-pill {statusVariant(block.status)}" aria-label="status: {block.status}">
      {block.status.replace('_', ' ')}
    </span>

    <div class="blk-meta">
      {#if durationLabel}
        <span class="blk-meta-item" title="duration">{durationLabel}</span>
      {/if}
      {#if costLabel}
        <span class="blk-meta-item" title="cost">{costLabel}</span>
      {/if}
      {#if block.exitCode != null && block.exitCode !== 0}
        <span class="blk-meta-item blk-meta-item--err" title="exit code">
          exit {block.exitCode}
        </span>
      {/if}
    </div>
  </header>

  {#if !collapsed}
    <div class="blk-body">
      {#if block.kind === 'command'}
        <CommandBlock {block} />
      {:else if block.kind === 'agent_message'}
        <AgentMessageBlock {block} />
      {:else if block.kind === 'tool_call' || block.kind === 'tool_result'}
        <ToolCallBlock {block} />
      {:else if block.kind === 'approval'}
        <ApprovalBlock {block} />
      {:else if block.kind === 'system_event' || block.kind === 'error' || block.kind === 'diff'}
        <SystemEventBlock {block} />
      {/if}
    </div>

    <footer class="blk-footer">
      {#if onCopy}
        <button class="blk-action" onclick={() => onCopy?.(block)} aria-label="Copy block">
          <Copy size={12} aria-hidden="true" />
          <span>Copy</span>
        </button>
      {/if}
      {#if onRerun && block.kind === 'command'}
        <button class="blk-action" onclick={() => onRerun?.(block)} aria-label="Re-run command">
          <Play size={12} aria-hidden="true" />
          <span>Re-run</span>
        </button>
      {/if}
      {#if onShare}
        <button class="blk-action" onclick={() => onShare?.(block)} aria-label="Share block">
          <Share2 size={12} aria-hidden="true" />
          <span>Share</span>
        </button>
      {/if}
      {#if onPin}
        <button
          class="blk-action"
          class:blk-action--active={isPinned}
          onclick={() => onPin?.(block)}
          aria-label={isPinned ? 'Unpin block' : 'Pin block'}
        >
          <Pin size={12} aria-hidden="true" />
          <span>{isPinned ? 'Unpin' : 'Pin'}</span>
        </button>
      {/if}
      {#if onDelete}
        <button
          class="blk-action blk-action--danger"
          onclick={() => onDelete?.(block)}
          aria-label="Delete block"
        >
          <Trash2 size={12} aria-hidden="true" />
          <span>Delete</span>
        </button>
      {/if}
    </footer>
  {/if}
</article>

<style>
  .blk-root {
    display: flex;
    flex-direction: column;
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    background: var(--bg-elevated, var(--bg));
    overflow: hidden;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .blk-focused {
    border-color: var(--signal-thinking, oklch(0.7 0.15 230));
    box-shadow: 0 0 0 2px color-mix(in oklch, var(--signal-thinking, oklch(0.7 0.15 230)) 25%, transparent 75%);
  }

  .blk-root[data-status='failed'] {
    border-color: color-mix(in oklch, var(--signal-error) 35%, var(--border) 65%);
  }

  .blk-root[data-status='pending_approval'] {
    border-color: color-mix(in oklch, var(--signal-warning, oklch(0.75 0.16 80)) 45%, var(--border) 55%);
  }

  .blk-root[data-kind='error'] {
    border-color: color-mix(in oklch, var(--signal-error) 30%, var(--border) 70%);
  }

  .blk-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    border-bottom: 1px solid color-mix(in oklch, var(--border) 60%, transparent 40%);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    min-width: 0;
  }

  .blk-toggle {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 18px;
    height: 18px;
    padding: 0;
    background: transparent;
    border: none;
    border-radius: var(--radius-sm);
    color: var(--fg-subtle);
    cursor: pointer;
    flex-shrink: 0;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .blk-toggle:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
  }

  .blk-kind-icon {
    display: flex;
    align-items: center;
    color: var(--signal-thinking, var(--fg-muted));
    flex-shrink: 0;
  }

  .blk-kind-label {
    color: var(--fg);
    font-weight: 600;
    flex-shrink: 0;
  }

  .blk-pill {
    display: inline-flex;
    align-items: center;
    padding: 1px 6px;
    border-radius: 999px;
    font-size: 10px;
    font-weight: 600;
    font-family: var(--font-sans);
    text-transform: uppercase;
    letter-spacing: 0.04em;
    flex-shrink: 0;
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg-muted);
  }

  .blk-pill--running {
    background: color-mix(in oklch, var(--signal-thinking, oklch(0.7 0.15 230)) 14%, transparent 86%);
    color: var(--signal-thinking, oklch(0.7 0.15 230));
  }

  .blk-pill--completed {
    background: color-mix(in oklch, var(--signal-success, oklch(0.65 0.18 145)) 14%, transparent 86%);
    color: var(--signal-success, oklch(0.65 0.18 145));
  }

  .blk-pill--failed {
    background: color-mix(in oklch, var(--signal-error, oklch(0.55 0.22 25)) 18%, transparent 82%);
    color: var(--signal-error, oklch(0.55 0.22 25));
  }

  .blk-pill--cancelled {
    color: var(--fg-subtle);
  }

  .blk-pill--pending_approval {
    background: color-mix(in oklch, var(--signal-warning, oklch(0.75 0.16 80)) 18%, transparent 82%);
    color: var(--signal-warning, oklch(0.75 0.16 80));
  }

  .blk-meta {
    display: flex;
    gap: var(--space-2);
    margin-left: auto;
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  .blk-meta-item--err {
    color: var(--signal-error, oklch(0.55 0.22 25));
  }

  .blk-body {
    padding: var(--space-3);
    overflow-x: auto;
  }

  .blk-footer {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-1);
    padding: var(--space-1) var(--space-2);
    border-top: 1px solid color-mix(in oklch, var(--border) 60%, transparent 40%);
    background: color-mix(in oklch, var(--bg-inset, var(--bg)) 60%, transparent 40%);
  }

  .blk-action {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 3px 8px;
    background: transparent;
    border: none;
    border-radius: var(--radius-sm);
    color: var(--fg-subtle);
    font-family: var(--font-sans);
    font-size: 11px;
    cursor: pointer;
    transition: background var(--dur-instant) var(--ease-out), color var(--dur-instant) var(--ease-out);
  }

  .blk-action:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .blk-action--active {
    color: var(--signal-thinking, var(--fg));
  }

  .blk-action--danger:hover {
    color: var(--signal-error, oklch(0.55 0.22 25));
    background: color-mix(in oklch, var(--signal-error, oklch(0.55 0.22 25)) 8%, transparent 92%);
  }
</style>
