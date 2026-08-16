<script lang="ts">
/**
 * MentionInput — Tiptap-based rich input with cross-entity @mention autocomplete.
 *
 * Supports 4 mention categories:
 *   Agents    → @slug           (emoji + name, from hiredAgentsQuery)
 *   Workspaces → @workspace-slug (name only, from workspacesQuery)
 *   Tasks     → @T-12345678    (status dot + truncated title, from tasksQuery)
 *   Channels  → @channel-slug  (icon + name, from channelsQuery)
 *
 * Dropdown behavior:
 *   - Floats anchored to the @ character via @floating-ui/dom (position:fixed
 *     fallback when not available)
 *   - Up/Down navigate, Enter selects, Esc closes
 *   - Fuzzy scoring: prefix (4) > word-boundary (3) > contains (2) > subsequence (1)
 *   - Cap 10 results, 2–3 per category
 *   - 150ms debounce on query changes
 *
 * Submit plaintext output: "@slug" literal, compatible with backend regex
 *   ~r/(?:^|\s)@([a-z0-9-]+)/
 *
 * Keyboard bindings preserved from Composer:
 *   ⌘Enter → submit, Esc → close dropdown
 *
 * LOC budget: ≤ 280
 */

import { onMount, onDestroy } from 'svelte';
import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
import { hiredAgentsQuery } from '$lib/api/queries/agents.js';
import { workspacesQuery } from '$lib/api/queries/workspaces.js';
import { tasksQuery } from '$lib/api/queries/tasks.js';
import { channelsQuery } from '$lib/api/queries/channels.js';
import type { Agent } from '$lib/domain/agents/types.js';
import type { Workspace } from '$lib/domain/workspaces/types.js';
import type { Task } from '$lib/domain/tasks/types.js';
import type { Channel } from '$lib/domain/channels/types.js';
import StatusDot from './StatusDot.svelte';
import { useGhostSuggestion, trackRecentCommand } from '$lib/design/patterns/mosaic/panes/agent-conversation/useGhostSuggestion.svelte.js';

// ── Props ─────────────────────────────────────────────────────────────────────

interface Props {
  placeholder?: string;
  value?: string;
  onSubmit?: (text: string, mentions: string[]) => void;
  class?: string;
}

let {
  placeholder = 'What are we working on?',
  value = $bindable(''),
  onSubmit,
  class: className = '',
}: Props = $props();

// ── Mention item types ────────────────────────────────────────────────────────

type MentionCategory = 'agents' | 'workspaces' | 'tasks' | 'channels';

interface MentionItem {
  id: string;
  slug: string;
  label: string;
  sublabel: string;
  category: MentionCategory;
  emoji?: string;
  taskStatus?: Task['status'];
}

// ── Data queries ──────────────────────────────────────────────────────────────

const agentsQ = createQuery<Agent[]>(hiredAgentsQuery() as CreateQueryOptions<Agent[]>);
const workspacesQ = createQuery<Workspace[]>(workspacesQuery() as CreateQueryOptions<Workspace[]>);
const openTasksQ = createQuery<Task[]>(
  tasksQuery({ status: 'todo' }) as CreateQueryOptions<Task[]>
);
const inProgressQ = createQuery<Task[]>(
  tasksQuery({ status: 'in_progress' }) as CreateQueryOptions<Task[]>
);
const channelsQ = createQuery<Channel[]>(channelsQuery() as CreateQueryOptions<Channel[]>);

const allAgents = $derived(($agentsQ.data ?? []) as Agent[]);
const allWorkspaces = $derived(($workspacesQ.data ?? []) as Workspace[]);
const allTasks = $derived([
  ...($openTasksQ.data ?? []),
  ...($inProgressQ.data ?? []),
] as Task[]);
const allChannels = $derived(($channelsQ.data ?? []) as Channel[]);

// ── Fuzzy scoring (reuse CommandPalette tiers) ────────────────────────────────

function fuzzyScore(text: string, q: string): number {
  if (!q) return 1;
  const label = text.toLowerCase();
  const lower = q.toLowerCase();
  const words = label.split(/[\s_-]+/);
  if (words.some((w) => w.startsWith(lower))) return 4;
  if (words.some((w) => w.startsWith(lower.charAt(0)) && label.includes(lower))) return 3;
  if (label.includes(lower)) return 2;
  if (isSubsequence(lower, label)) return 1;
  return 0;
}

function isSubsequence(needle: string, haystack: string): boolean {
  let ni = 0;
  for (let hi = 0; hi < haystack.length && ni < needle.length; hi++) {
    if (haystack[hi] === needle[ni]) ni++;
  }
  return ni === needle.length;
}

function scoreAndFilter<T>(
  items: T[],
  getKey: (i: T) => string,
  q: string,
  limit: number
): Array<{ item: T; score: number }> {
  return items
    .map((item) => ({ item, score: fuzzyScore(getKey(item), q) }))
    .filter(({ score }) => score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, limit);
}

// ── Component state ───────────────────────────────────────────────────────────

let textareaEl = $state<HTMLTextAreaElement | null>(null);
let dropdownEl = $state<HTMLDivElement | null>(null);
let focused = $state(false);

// ── Ghost-text suggestion ─────────────────────────────────────────────────────

const ghost = useGhostSuggestion(() => value);

/** Text after the triggering @ up to cursor. Empty string = @ with nothing yet. null = no active mention. */
let mentionQuery = $state<string | null>(null);
/** Position of the triggering @ in the full text value. */
let mentionAtIndex = $state(-1);
/** Flat sorted results currently shown. */
let results = $state<MentionItem[]>([]);
/** Keyboard navigation index into results. */
let activeIdx = $state(0);
/** Dropdown position (fixed, anchored to caret rect). */
let dropX = $state(0);
let dropY = $state(0);
let debounceTimer = $state<ReturnType<typeof setTimeout> | null>(null);

const dropdownOpen = $derived(mentionQuery !== null && results.length > 0);

// ── Category aggregation ──────────────────────────────────────────────────────

function buildResults(q: string): MentionItem[] {
  const agentItems = scoreAndFilter(allAgents, (a) => `${a.name} ${a.slug}`, q, 3)
    .map(({ item: a }) => ({
      id: a.slug,
      slug: a.slug,
      label: a.name,
      sublabel: a.title,
      category: 'agents' as const,
      emoji: a.emoji,
    }));

  const wsItems = scoreAndFilter(allWorkspaces, (w) => `${w.name} ${w.slug}`, q, 2)
    .map(({ item: w }) => ({
      id: w.slug,
      slug: w.slug,
      label: w.name,
      sublabel: w.slug,
      category: 'workspaces' as const,
    }));

  const taskItems = scoreAndFilter(allTasks, (t) => `${t.shortId} ${t.title}`, q, 3)
    .map(({ item: t }) => ({
      id: t.id,
      slug: t.shortId.toLowerCase(),
      label: t.shortId,
      sublabel: t.title.length > 40 ? t.title.slice(0, 40) + '…' : t.title,
      category: 'tasks' as const,
      taskStatus: t.status,
    }));

  const channelItems = scoreAndFilter(allChannels, (c) => `${c.name} ${c.slug}`, q, 2)
    .map(({ item: c }) => ({
      id: c.id,
      slug: c.slug,
      label: c.name,
      sublabel: c.slug,
      category: 'channels' as const,
      emoji: c.icon ?? '#',
    }));

  return [...agentItems, ...wsItems, ...taskItems, ...channelItems].slice(0, 10);
}

// ── Debounced query update ────────────────────────────────────────────────────

function scheduleUpdate(q: string): void {
  if (debounceTimer !== null) clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => {
    results = buildResults(q);
    activeIdx = 0;
    positionDropdown();
  }, 150);
}

// ── Caret-anchored positioning (position:fixed fallback) ──────────────────────

function positionDropdown(): void {
  const el = textareaEl;
  if (!el) return;

  const rect = el.getBoundingClientRect();
  // Approximate caret position: proportional to cursor offset within textarea
  const lines = value.slice(0, el.selectionStart ?? 0).split('\n');
  const lineHeight = 20; // ~13px font-size * 1.6 line-height
  const estimatedLineY = Math.min(lines.length - 1, 4) * lineHeight;

  dropX = rect.left + 8;
  dropY = rect.top + estimatedLineY; // dropdown opens upward from this Y
}

// ── Input handling ────────────────────────────────────────────────────────────

function handleInput(): void {
  const el = textareaEl;
  if (!el) return;

  // Autogrow
  el.style.height = 'auto';
  el.style.height = `${el.scrollHeight}px`;

  const cursor = el.selectionStart ?? 0;
  const beforeCursor = value.slice(0, cursor);
  const atIdx = beforeCursor.lastIndexOf('@');

  if (atIdx !== -1) {
    const afterAt = beforeCursor.slice(atIdx + 1);
    if (!afterAt.includes(' ') && !afterAt.includes('\n')) {
      mentionAtIndex = atIdx;
      mentionQuery = afterAt;
      scheduleUpdate(afterAt);
      return;
    }
  }

  // No active mention
  if (debounceTimer !== null) clearTimeout(debounceTimer);
  mentionQuery = null;
  mentionAtIndex = -1;
  results = [];
}

// ── Item selection ────────────────────────────────────────────────────────────

function selectItem(item: MentionItem): void {
  const el = textareaEl;
  if (!el || mentionAtIndex === -1) return;

  const cursor = el.selectionStart ?? 0;
  const afterCursor = value.slice(cursor);
  const replacement = `@${item.slug} `;
  value = value.slice(0, mentionAtIndex) + replacement + afterCursor;
  mentionQuery = null;
  mentionAtIndex = -1;
  results = [];

  setTimeout(() => {
    el.focus();
    const newPos = mentionAtIndex + replacement.length;
    // mentionAtIndex is captured before null-set, but replacement was already inserted
    const pos = value.indexOf(replacement) + replacement.length;
    el.setSelectionRange(pos, pos);
  }, 0);
}

// ── Keyboard handling ─────────────────────────────────────────────────────────

/** Dismiss ghost text without accepting (used by Escape). */
let ghostDismissed = $state(false);
/** Reset dismiss flag whenever draft changes. */
$effect(() => { void value; ghostDismissed = false; });

const activeGhost = $derived(
  !ghostDismissed && !dropdownOpen ? ghost.suggestion : null,
);

function handleKeydown(e: KeyboardEvent): void {
  if (e.key === 'Enter' && e.metaKey) {
    e.preventDefault();
    handleSubmit();
    return;
  }

  // Ghost text — Tab accepts, Escape dismisses (checked before mention dropdown)
  if (e.key === 'Tab' && activeGhost) {
    e.preventDefault();
    value = activeGhost.text;
    ghostDismissed = false;
    // Move caret to end
    setTimeout(() => {
      if (textareaEl) {
        textareaEl.setSelectionRange(value.length, value.length);
        // Trigger autogrow
        textareaEl.style.height = 'auto';
        textareaEl.style.height = `${textareaEl.scrollHeight}px`;
      }
    }, 0);
    return;
  }

  if (e.key === 'Escape' && activeGhost) {
    e.preventDefault();
    ghostDismissed = true;
    return;
  }

  if (!dropdownOpen) return;

  if (e.key === 'ArrowDown') {
    e.preventDefault();
    activeIdx = Math.min(activeIdx + 1, results.length - 1);
  } else if (e.key === 'ArrowUp') {
    e.preventDefault();
    activeIdx = Math.max(activeIdx - 1, 0);
  } else if (e.key === 'Enter') {
    e.preventDefault();
    if (results[activeIdx]) selectItem(results[activeIdx]);
  } else if (e.key === 'Escape') {
    e.preventDefault();
    mentionQuery = null;
    results = [];
  } else if (e.key === 'Tab') {
    // Tab selects top mention result when no ghost is active
    if (results.length > 0) {
      e.preventDefault();
      selectItem(results[activeIdx]);
    }
  }
}

// ── Submit ────────────────────────────────────────────────────────────────────

function handleSubmit(): void {
  const trimmed = value.trim();
  if (!trimmed) return;
  trackRecentCommand(trimmed);
  const mentions = extractMentions(trimmed);
  onSubmit?.(trimmed, mentions);
  value = '';
  if (textareaEl) textareaEl.style.height = 'auto';
  mentionQuery = null;
  results = [];
}

function extractMentions(text: string): string[] {
  const matches = text.matchAll(/(?:^|\s)@([a-z0-9-]+)/g);
  return Array.from(matches, (m) => m[1]);
}

// ── Close on outside click ────────────────────────────────────────────────────

function handleDocClick(e: MouseEvent): void {
  const target = e.target as Element;
  if (!target.closest('.mnp-wrap') && !target.closest('.mnp-dropdown')) {
    mentionQuery = null;
    results = [];
  }
}

onMount(() => document.addEventListener('click', handleDocClick));
onDestroy(() => document.removeEventListener('click', handleDocClick));

// ── Category label map ────────────────────────────────────────────────────────

const CATEGORY_LABELS: Record<MentionCategory, string> = {
  agents: 'Agents',
  workspaces: 'Workspaces',
  tasks: 'Tasks',
  channels: 'Channels',
};

// ── Status → dot color ────────────────────────────────────────────────────────

function taskDotColor(status: Task['status']): 'green' | 'amber' | 'grey' | 'red' {
  if (status === 'in_progress') return 'green';
  if (status === 'todo') return 'grey';
  if (status === 'done') return 'grey';
  return 'red';
}

// ── Group results by category for rendering ───────────────────────────────────

const grouped = $derived.by(() => {
  const map = new Map<MentionCategory, MentionItem[]>();
  for (const item of results) {
    const bucket = map.get(item.category) ?? [];
    bucket.push(item);
    map.set(item.category, bucket);
  }
  return map;
});
</script>

<div class="mnp-wrap {className}" class:mnp-wrap--focused={focused}>
  <!--
    Ghost-text mirror: same font/padding/size as the textarea, positioned
    absolute behind it. Shows the typed text (invisible, for layout) + the
    ghost suffix (visible, faded). pointer-events:none so it never intercepts
    clicks. aria-hidden so screen readers ignore it.
  -->
  {#if activeGhost}
    <div class="mnp-ghost-mirror" aria-hidden="true">
      <span class="mnp-ghost-typed">{value}</span><span class="mnp-ghost-suffix">{activeGhost.suffix}</span>
    </div>
    <div class="mnp-smart-fill" aria-live="polite">
      <span>{activeGhost.source === 'shell' ? 'Fill' : activeGhost.source === 'recent' ? 'Recent' : 'Slash'}</span>
      <code class="mnp-smart-fill__value">{activeGhost.text}</code>
      <kbd>Tab</kbd>
    </div>
  {/if}

  <textarea
    bind:this={textareaEl}
    bind:value
    class="mnp-input"
    class:mnp-input--ghosted={!!activeGhost}
    {placeholder}
    rows="3"
    oninput={handleInput}
    onkeydown={handleKeydown}
    onfocus={() => { focused = true; }}
    onblur={() => { focused = false; }}
    aria-label="Message input with @mention support"
    aria-autocomplete="list"
    autocomplete="off"
    spellcheck="true"
  ></textarea>
</div>

{#if dropdownOpen}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    bind:this={dropdownEl}
    class="mnp-dropdown glass"
    role="listbox"
    aria-label="Mention suggestions"
    style="left: {dropX}px; bottom: calc(100vh - {dropY}px);"
  >
    {#each [...grouped.entries()] as [cat, items] (cat)}
      <div class="mnp-category">
        <span class="mnp-category__label">{CATEGORY_LABELS[cat]}</span>
        {#each items as item (item.id)}
          {@const globalIdx = results.indexOf(item)}
          <!-- svelte-ignore a11y_click_events_have_key_events -->
          <button
            class="mnp-row"
            class:mnp-row--active={globalIdx === activeIdx}
            role="option"
            aria-selected={globalIdx === activeIdx}
            onmousedown={(e) => { e.preventDefault(); selectItem(item); }}
          >
            {#if item.category === 'tasks'}
              <StatusDot color={taskDotColor(item.taskStatus ?? 'todo')} />
            {:else if item.emoji}
              <span class="mnp-emoji" aria-hidden="true">{item.emoji}</span>
            {:else}
              <span class="mnp-placeholder-icon" aria-hidden="true">#</span>
            {/if}
            <span class="mnp-row__label">{item.label}</span>
            {#if item.sublabel}
              <span class="mnp-row__sub">{item.sublabel}</span>
            {/if}
          </button>
        {/each}
      </div>
    {/each}
  </div>
{/if}

<style>
  .mnp-wrap {
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-2xl);
    transition: border-color var(--dur-instant) var(--ease-out);
    overflow: hidden;
    position: relative;
  }

  /* Ghost-text mirror — sits behind the textarea, matches its exact metrics */
  .mnp-ghost-mirror {
    position: absolute;
    inset: 0;
    pointer-events: none;
    /* Match textarea font/spacing exactly */
    font-family: var(--font-mono);
    font-size: 13px;
    line-height: 1.6;
    padding: var(--space-4);
    white-space: pre-wrap;
    word-break: break-word;
    overflow: hidden;
    /* Sit below the textarea in stacking order */
    z-index: 0;
  }

  /* The typed portion is invisible — it exists only to push the ghost to the right column */
  .mnp-ghost-typed {
    color: transparent;
    white-space: pre-wrap;
  }

  /* The ghost suffix — same line, faded */
  .mnp-ghost-suffix {
    color: color-mix(in oklch, var(--cnp-accent, var(--fg)) 72%, var(--fg) 28%);
    opacity: 0.82;
    white-space: pre;
  }

  .mnp-smart-fill {
    position: absolute;
    right: 10px;
    top: 8px;
    z-index: 2;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 3px 6px;
    border: 1px solid var(--border);
    border-radius: 6px;
    background: color-mix(in oklch, var(--bg-elevated, var(--bg)) 82%, black 12%);
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: 10px;
    pointer-events: none;
    box-shadow: 0 8px 22px color-mix(in oklch, black 18%, transparent);
    max-width: min(76%, 620px);
  }

  .mnp-smart-fill__value {
    max-width: 480px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    color: var(--fg);
    font-family: var(--font-mono);
    font-size: 10.5px;
  }

  .mnp-smart-fill kbd {
    min-width: 24px;
    padding: 1px 5px;
    border: 1px solid var(--border);
    border-radius: 4px;
    color: var(--fg-muted);
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    font-family: var(--font-mono);
    font-size: 10px;
    text-align: center;
  }

  /* When ghost is active, textarea must sit above the mirror and be transparent
     only in background — text stays fully visible, we just ensure z-index layering */
  .mnp-input--ghosted {
    position: relative;
    z-index: 1;
    background: transparent;
  }

  .mnp-wrap--focused {
    border-color: var(--border-strong);
  }

  .mnp-input {
    font-family: var(--font-mono);
    font-size: 13px;
    line-height: 1.6;
    color: var(--fg);
    background: transparent;
    border: none;
    outline: none;
    resize: none;
    padding: var(--space-4);
    min-height: 80px;
    max-height: 320px;
    width: 100%;
    box-sizing: border-box;
    caret-color: var(--cnp-accent);
  }

  .mnp-input::placeholder {
    color: var(--fg-subtle);
  }

  /* Dropdown — fixed, above the textarea */
  .mnp-dropdown {
    position: fixed;
    z-index: 150;
    width: 280px;
    max-height: 320px;
    overflow-y: auto;
    border-radius: var(--radius-lg);
    padding: var(--space-1);
    display: flex;
    flex-direction: column;
    gap: 2px;
    /* Flip upward by offsetting bottom */
    transform: translateY(-100%);
    margin-top: -4px;
  }

  .mnp-category {
    display: flex;
    flex-direction: column;
    gap: 1px;
    margin-bottom: var(--space-1);
  }

  .mnp-category:last-child {
    margin-bottom: 0;
  }

  .mnp-category__label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.07em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    padding: var(--space-1) var(--space-3);
    user-select: none;
  }

  .mnp-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    border: none;
    background: transparent;
    border-radius: var(--radius-md);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    text-align: left;
    width: 100%;
    transition: background var(--dur-instant) var(--ease-out);
    min-height: 32px;
  }

  .mnp-row:hover,
  .mnp-row--active {
    background: color-mix(in oklch, var(--cnp-accent) 12%, transparent 88%);
    color: var(--fg);
  }

  .mnp-emoji {
    font-size: 14px;
    line-height: 1;
    flex-shrink: 0;
    width: 16px;
    text-align: center;
  }

  .mnp-placeholder-icon {
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    flex-shrink: 0;
    width: 16px;
    text-align: center;
  }

  .mnp-row__label {
    font-weight: 500;
    flex-shrink: 0;
    max-width: 100px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .mnp-row__sub {
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    margin-left: auto;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 120px;
  }
</style>
