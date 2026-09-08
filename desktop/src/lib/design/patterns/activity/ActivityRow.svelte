<script lang="ts">
/**
 * ActivityRow — single event in the activity feed.
 * Left: event-type icon. Body: title + actor chip + preview. Right: timestamp.
 * CSS prefix: ar- (ActivityRow)
 * LOC target: ≤ 140.
 */

import {
  Activity,
  AlertTriangle,
  CheckSquare,
  CircleDot,
  FolderOpen,
  Pause,
  Play,
  RotateCcw,
  Terminal,
  Users,
  XCircle,
  Zap,
} from 'lucide-svelte';
import type { ActivityEvent, ActivityEventType } from '$lib/domain/activity/types.js';

interface Props {
  event: ActivityEvent;
}

const { event }: Props = $props();

// ── Icon resolution ───────────────────────────────────────────────────────────

type IconComponent = typeof Terminal;

const ICON_MAP: Record<ActivityEventType, IconComponent> = {
  session_started: Terminal,
  session_ended: XCircle,
  session_paused: Pause,
  session_resumed: Play,
  session_cancelled: XCircle,
  session_error: AlertTriangle,
  task_dispatched: Zap,
  task_completed: CheckSquare,
  task_failed: AlertTriangle,
  issue_opened: CircleDot,
  issue_closed: CheckSquare,
  issue_updated: RotateCcw,
  agent_registered: Users,
  runtime_created: FolderOpen,
  runtime_deleted: FolderOpen,
  workspace_created: FolderOpen,
  workspace_updated: FolderOpen,
};

const EventIcon = $derived(ICON_MAP[event.type] ?? Activity);

// ── Link resolution ───────────────────────────────────────────────────────────

const entityHref = $derived((): string | null => {
  if (event.session_id) return `/sessions/${event.session_id}`;
  if (event.task_id) return `/tasks/${event.task_id}`;
  if (event.issue_id) return `/issues/${event.issue_id}`;
  return null;
});

// ── Timestamp formatting ──────────────────────────────────────────────────────

function relativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const s = Math.floor(diff / 1000);
  if (s < 60) return `${s}s ago`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const d = Math.floor(h / 24);
  return `${d}d ago`;
}

function absoluteTime(iso: string): string {
  return new Date(iso).toLocaleString();
}

const relTs = $derived(relativeTime(event.at));
const absTs = $derived(absoluteTime(event.at));

// ── Preview mono detection ────────────────────────────────────────────────────

const isToolOutput = $derived(
  event.type === 'session_started' ||
    event.type === 'task_dispatched' ||
    event.type === 'session_ended'
);

const href = $derived(entityHref());

// ── Wake-reason pill ──────────────────────────────────────────────────────────

const wakeReason = $derived(event.type === 'session_started' ? (event.wake_reason ?? null) : null);

const WAKE_PILL_CLASS: Record<string, string> = {
  user_prompt: 'ar-wake--user',
  approval: 'ar-wake--approval',
  schedule: 'ar-wake--schedule',
  resume: 'ar-wake--resume',
};
</script>

<div class="ar-row" role="listitem">
  <!-- Icon -->
  <div class="ar-icon" aria-hidden="true">
    <EventIcon size={14} />
  </div>

  <!-- Body -->
  <div class="ar-body">
    {#if href}
      <a class="ar-title" href={href} aria-label={event.title}>{event.title}</a>
    {:else}
      <span class="ar-title ar-title--plain">{event.title}</span>
    {/if}

    <div class="ar-meta">
      <span class="ar-actor" title="Actor: {event.actor_id}">{event.actor_type}</span>
      <span class="ar-sep" aria-hidden="true">·</span>
      <span class="ar-actor-id">{event.actor_id}</span>
    </div>

    {#if event.preview}
      <p class="ar-preview" class:ar-preview--mono={isToolOutput}>{event.preview}</p>
    {/if}
    {#if wakeReason}
      <span class="ar-wake {WAKE_PILL_CLASS[wakeReason] ?? 'ar-wake--user'}" aria-label="Wake reason: {wakeReason}">
        {wakeReason.replace('_', ' ')}
      </span>
    {/if}
  </div>

  <!-- Timestamp -->
  <div class="ar-ts" title={absTs} aria-label={absTs}>
    <time datetime={event.at}>{relTs}</time>
  </div>
</div>

<style>
  .ar-row {
    display: flex;
    align-items: flex-start;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-4);
    border-bottom: 1px solid var(--border);
    transition: background var(--dur-instant) var(--ease-out);
    cursor: default;
  }

  .ar-row:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  .ar-row:last-child {
    border-bottom: none;
  }

  /* Icon */
  .ar-icon {
    flex-shrink: 0;
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    border-radius: var(--radius-sm);
    color: var(--fg-subtle);
    margin-top: 2px;
  }

  /* Body */
  .ar-body {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .ar-title {
    font-size: 13px;
    font-weight: 500;
    color: var(--fg);
    text-decoration: none;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ar-title:not(.ar-title--plain):hover {
    color: var(--cnp-accent);
    text-decoration: underline;
  }

  .ar-title--plain {
    color: var(--fg);
  }

  .ar-meta {
    display: flex;
    align-items: center;
    gap: var(--space-1);
  }

  .ar-actor {
    font-size: 11px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    border-radius: var(--radius-sm);
    padding: 1px 5px;
  }

  .ar-sep {
    font-size: 11px;
    color: var(--fg-subtle);
    opacity: 0.5;
  }

  .ar-actor-id {
    font-size: 11px;
    color: var(--fg-subtle);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 200px;
  }

  .ar-preview {
    font-size: 12px;
    color: var(--fg-subtle);
    margin: 0;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
    line-height: 1.5;
  }

  .ar-preview--mono {
    font-family: var(--font-mono);
    font-size: 11px;
  }

  /* Wake-reason pill */
  .ar-wake {
    display: inline-block;
    padding: 1px 6px;
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    margin-top: 2px;
  }

  .ar-wake--user     { background: color-mix(in oklch, oklch(0.85 0.18 55) 20%, transparent);  color: oklch(0.60 0.18 55); }
  .ar-wake--approval { background: color-mix(in oklch, oklch(0.75 0.18 145) 20%, transparent); color: oklch(0.50 0.18 145); }
  .ar-wake--schedule { background: color-mix(in oklch, oklch(0.75 0.18 240) 20%, transparent); color: oklch(0.50 0.18 240); }
  .ar-wake--resume   { background: color-mix(in oklch, oklch(0.70 0.18 300) 20%, transparent); color: oklch(0.50 0.18 300); }

  /* Timestamp */
  .ar-ts {
    flex-shrink: 0;
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-subtle);
    white-space: nowrap;
    margin-top: 3px;
  }
</style>
