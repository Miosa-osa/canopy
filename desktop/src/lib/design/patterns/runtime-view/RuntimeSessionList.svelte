<script lang="ts">
/**
 * RuntimeSessionList — sidebar sessions tab for the runtime terminal view.
 *
 * Lists all sessions for the current runtime type. Clicking a row switches
 * the main terminal to that session. "+ New session" opens NewSessionModal
 * with runtime pre-selected.
 *
 * CSS prefix: rsl-
 */
import type { Session } from '$lib/domain/sessions/types.js';

interface Props {
  sessions: Session[];
  activeSessionId: string;
  isLoading: boolean;
  onSelect: (sessionId: string) => void;
  onNewSession: () => void;
}

let { sessions, activeSessionId, isLoading, onSelect, onNewSession }: Props = $props();

/** Format ISO timestamp to relative time, e.g. "3m ago". */
function relativeTime(iso: string | null): string {
  if (!iso) return '—';
  const diff = Date.now() - new Date(iso).getTime();
  if (diff < 60_000) return 'just now';
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)}m ago`;
  if (diff < 86_400_000) return `${Math.floor(diff / 3_600_000)}h ago`;
  return `${Math.floor(diff / 86_400_000)}d ago`;
}

const statusColor = (s: string): 'green' | 'amber' | 'grey' | 'red' =>
  s === 'running' ? 'green' : s === 'paused' ? 'amber' : s === 'error' ? 'red' : 'grey';
</script>

<div class="rsl-root">
  <div class="rsl-toolbar">
    <button
      class="rsl-new-btn"
      onclick={onNewSession}
      aria-label="New session for this runtime"
    >
      + New session
    </button>
  </div>

  {#if isLoading}
    <div class="rsl-loading" aria-label="Loading sessions">
      {#each Array.from({ length: 3 }, (_, i) => i) as i (i)}
        <div class="rsl-skeleton" aria-hidden="true"></div>
      {/each}
    </div>
  {:else if sessions.length === 0}
    <div class="rsl-empty">No sessions yet</div>
  {:else}
    <ul class="rsl-list" role="listbox" aria-label="Sessions for this runtime">
      {#each sessions as s (s.id)}
        {@const isActive = s.id === activeSessionId}
        {@const color = statusColor(s.status)}
        <!-- svelte-ignore a11y_click_events_have_key_events -->
        <li
          class="rsl-item"
          class:rsl-item--active={isActive}
          role="option"
          aria-selected={isActive}
          onclick={() => onSelect(s.id)}
          tabindex="0"
          onkeydown={(e) => {
            if (e.key === 'Enter' || e.key === ' ') {
              e.preventDefault();
              onSelect(s.id);
            }
          }}
        >
          <span class="rsl-dot" data-color={color} aria-hidden="true"></span>
          <div class="rsl-item-body">
            <span class="rsl-workspace">
              {s.workspaceSlug ?? 'no workspace'}
            </span>
            <span class="rsl-time">{relativeTime(s.updatedAt)}</span>
          </div>
        </li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .rsl-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  .rsl-toolbar {
    display: flex;
    align-items: center;
    padding: var(--space-2) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .rsl-new-btn {
    width: 100%;
    padding: 5px var(--space-3);
    border-radius: var(--radius-md);
    border: 1px dashed var(--border);
    background: transparent;
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    cursor: pointer;
    text-align: center;
    transition: background 0.1s ease, color 0.1s ease, border-color 0.1s ease;
  }

  .rsl-new-btn:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    color: var(--fg);
    border-color: var(--border-strong);
    border-style: solid;
  }

  .rsl-new-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  .rsl-loading {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-3);
  }

  .rsl-skeleton {
    height: 40px;
    border-radius: var(--radius-md);
    background: color-mix(in oklch, var(--fg) 5%, transparent);
    animation: rsl-pulse 1.4s ease-in-out infinite;
  }

  @keyframes rsl-pulse {
    0%, 100% { opacity: 0.5; }
    50%       { opacity: 1; }
  }

  .rsl-empty {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    font-style: italic;
    padding: var(--space-6);
    text-align: center;
  }

  .rsl-list {
    list-style: none;
    margin: 0;
    padding: var(--space-2) var(--space-2);
    display: flex;
    flex-direction: column;
    gap: 2px;
    overflow-y: auto;
    flex: 1;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .rsl-item {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-2);
    border-radius: var(--radius-md);
    cursor: pointer;
    border: 1px solid transparent;
    transition: background 0.1s ease, border-color 0.1s ease;
  }

  .rsl-item:hover:not(.rsl-item--active) {
    background: color-mix(in oklch, var(--fg) 5%, transparent);
    border-color: var(--border);
  }

  .rsl-item--active {
    background: color-mix(in oklch, var(--cnp-accent) 10%, transparent);
    border-color: color-mix(in oklch, var(--cnp-accent) 30%, transparent);
  }

  .rsl-item:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  .rsl-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    flex-shrink: 0;
    background: var(--fg-subtle);
  }

  .rsl-dot[data-color='green']  { background: oklch(62% 0.15 145); }
  .rsl-dot[data-color='amber']  { background: oklch(70% 0.15 75); }
  .rsl-dot[data-color='red']    { background: oklch(60% 0.2 25); }
  .rsl-dot[data-color='grey']   { background: color-mix(in oklch, var(--fg) 25%, transparent); }

  .rsl-item-body {
    display: flex;
    flex-direction: column;
    gap: 1px;
    min-width: 0;
    flex: 1;
  }

  .rsl-workspace {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .rsl-time {
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
    white-space: nowrap;
  }
</style>
