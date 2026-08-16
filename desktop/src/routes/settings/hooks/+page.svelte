<script lang="ts">
/**
 * Settings › Hooks — agent lifecycle hook observability.
 *
 * Shows per-runtime install status (claude, cursor, gemini, codex, opencode),
 * reinstall/uninstall controls, and a live feed of the last 20 hook events
 * received by the Canopy backend from agents running anywhere on this machine.
 */

import {
  getHooksStatus,
  installHooks,
  uninstallHooks,
  type HookEvent,
  type RuntimeStatus,
} from "$lib/api/queries/hooks.js";
import { onMount } from "svelte";

// ── State ─────────────────────────────────────────────────────────────────────

let runtimes = $state<Record<string, RuntimeStatus>>({});
let recentEvents = $state<HookEvent[]>([]);
let loading = $state(true);
let actionPending = $state(false);
let actionError = $state<string | null>(null);

const RUNTIMES = ["claude", "cursor", "gemini", "codex", "opencode"] as const;

// ── Lifecycle ─────────────────────────────────────────────────────────────────

onMount(() => {
  void refresh();
});

async function refresh(): Promise<void> {
  loading = true;
  actionError = null;
  try {
    const data = await getHooksStatus();
    runtimes = data.runtimes;
    recentEvents = data.recent_events;
  } catch (e) {
    actionError = e instanceof Error ? e.message : "Failed to load hook status";
  } finally {
    loading = false;
  }
}

async function handleInstall(): Promise<void> {
  actionPending = true;
  actionError = null;
  try {
    await installHooks();
    await refresh();
  } catch (e) {
    actionError = e instanceof Error ? e.message : "Install failed";
  } finally {
    actionPending = false;
  }
}

async function handleUninstall(): Promise<void> {
  actionPending = true;
  actionError = null;
  try {
    await uninstallHooks();
    await refresh();
  } catch (e) {
    actionError = e instanceof Error ? e.message : "Uninstall failed";
  } finally {
    actionPending = false;
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function statusOf(name: string): RuntimeStatus {
  return runtimes[name] ?? { status: "not_installed" };
}

function isInstalled(s: RuntimeStatus): boolean {
  return s.status === "installed" || s.status === "ok";
}

function formatTime(iso: string): string {
  try {
    return new Date(iso).toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    });
  } catch {
    return iso;
  }
}

function eventLabel(event: string): string {
  return (
    {
      PostToolUse: "tool use",
      Stop: "stop",
      UserPromptSubmit: "prompt",
      PermissionRequest: "permission",
      PostToolUseFailure: "tool fail",
    }[event] ?? event
  );
}
</script>

<div class="hk-page">
  <!-- ── Runtime status grid ─────────────────────────────────────────────── -->
  <div class="hk-section">
    <div class="hk-section-head">
      <span class="hk-section-label">Runtimes</span>
      <span class="hk-section-desc">
        Hooks installed in global agent configs receive events from every session
        on this machine — including those started outside Canopy.
      </span>
    </div>

    {#if loading}
      <div class="hk-loading">Loading...</div>
    {:else}
      <div class="hk-runtime-grid">
        {#each RUNTIMES as name}
          {@const s = statusOf(name)}
          <div class="hk-runtime-row">
            <span class="hk-runtime-dot" class:hk-dot--ok={isInstalled(s)} class:hk-dot--warn={!isInstalled(s) && s.status !== 'error'} class:hk-dot--error={s.status === 'error'} aria-hidden="true"></span>
            <span class="hk-runtime-name">{name}</span>
            <span class="hk-runtime-status">{s.status}</span>
            {#if s.reason}
              <span class="hk-runtime-reason" title={s.reason}>{s.reason}</span>
            {/if}
          </div>
        {/each}
      </div>
    {/if}
  </div>

  <!-- ── Controls ───────────────────────────────────────────────────────── -->
  <div class="hk-controls">
    <button
      class="hk-btn hk-btn--primary"
      onclick={handleInstall}
      disabled={actionPending}
      aria-label="Reinstall hooks in all agent configs"
    >
      {actionPending ? "Working..." : "Reinstall hooks"}
    </button>
    <button
      class="hk-btn"
      onclick={handleUninstall}
      disabled={actionPending}
      aria-label="Remove hooks from all agent configs"
    >
      Uninstall hooks
    </button>
    <button
      class="hk-btn"
      onclick={refresh}
      disabled={loading || actionPending}
      aria-label="Refresh status"
    >
      Refresh
    </button>
  </div>

  {#if actionError}
    <p class="hk-error" role="alert">{actionError}</p>
  {/if}

  <!-- ── Recent events feed ─────────────────────────────────────────────── -->
  <div class="hk-section">
    <div class="hk-section-head">
      <span class="hk-section-label">Recent events</span>
      <span class="hk-section-desc">
        Last 20 hook events received from agents on this machine.
        Run <code class="hk-code">claude</code> in any terminal to see events appear here.
      </span>
    </div>

    {#if recentEvents.length === 0 && !loading}
      <p class="hk-empty">No events yet. Start a claude session in any terminal.</p>
    {:else}
      <ul class="hk-event-list" role="list" aria-label="Recent hook events">
        {#each recentEvents as ev (ev.id)}
          <li class="hk-event-row">
            <span class="hk-event-time">{formatTime(ev.inserted_at)}</span>
            <span class="hk-event-agent">{ev.agent}</span>
            <span class="hk-event-tag hk-tag--{ev.event.toLowerCase()}">{eventLabel(ev.event)}</span>
            {#if ev.session_id}
              <span class="hk-event-session" title={ev.session_id}>
                {ev.session_id.slice(0, 8)}
              </span>
            {/if}
          </li>
        {/each}
      </ul>
    {/if}
  </div>
</div>

<style>
  .hk-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-6);
    max-width: 720px;
  }

  /* ── Section ─────────────────────────────────────────────────────────────── */

  .hk-section {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .hk-section-head {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .hk-section-label {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
  }

  .hk-section-desc {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    line-height: 1.5;
  }

  .hk-code {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    padding: 1px 4px;
    border-radius: var(--radius-sm);
  }

  .hk-loading,
  .hk-empty {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
  }

  /* ── Runtime grid ────────────────────────────────────────────────────────── */

  .hk-runtime-grid {
    display: flex;
    flex-direction: column;
    gap: 2px;
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow: hidden;
  }

  .hk-runtime-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    background: transparent;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .hk-runtime-row:hover {
    background: color-mix(in oklch, var(--fg) 3%, transparent 97%);
  }

  .hk-runtime-row + .hk-runtime-row {
    border-top: 1px solid var(--border);
  }

  .hk-runtime-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
    background: var(--fg-subtle);
  }

  .hk-dot--ok {
    background: oklch(65% 0.18 145);
  }

  .hk-dot--warn {
    background: oklch(70% 0.16 75);
  }

  .hk-dot--error {
    background: oklch(60% 0.20 25);
  }

  .hk-runtime-name {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg);
    width: 80px;
    flex-shrink: 0;
  }

  .hk-runtime-status {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    flex: 1;
  }

  .hk-runtime-reason {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 200px;
  }

  /* ── Controls ────────────────────────────────────────────────────────────── */

  .hk-controls {
    display: flex;
    gap: var(--space-2);
    flex-wrap: wrap;
  }

  .hk-btn {
    display: inline-flex;
    align-items: center;
    padding: var(--space-1-5) var(--space-3);
    border-radius: 9999px;
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    cursor: pointer;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out),
      border-color var(--dur-instant) var(--ease-out);
    white-space: nowrap;
  }

  .hk-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .hk-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .hk-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .hk-btn--primary {
    background: color-mix(in oklch, var(--cnp-accent) 12%, transparent 88%);
    border-color: color-mix(in oklch, var(--cnp-accent) 40%, transparent 60%);
    color: var(--cnp-accent);
  }

  .hk-btn--primary:hover:not(:disabled) {
    background: color-mix(in oklch, var(--cnp-accent) 20%, transparent 80%);
    border-color: var(--cnp-accent);
  }

  /* ── Error ───────────────────────────────────────────────────────────────── */

  .hk-error {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: oklch(60% 0.20 25);
    margin: 0;
  }

  /* ── Event list ──────────────────────────────────────────────────────────── */

  .hk-event-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow: hidden;
  }

  .hk-event-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-1-5) var(--space-3);
    transition: background var(--dur-instant) var(--ease-out);
  }

  .hk-event-row + .hk-event-row {
    border-top: 1px solid var(--border);
  }

  .hk-event-row:hover {
    background: color-mix(in oklch, var(--fg) 3%, transparent 97%);
  }

  .hk-event-time {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    width: 72px;
    flex-shrink: 0;
  }

  .hk-event-agent {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    width: 64px;
    flex-shrink: 0;
  }

  .hk-event-tag {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    padding: 1px var(--space-1);
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg-muted);
    flex-shrink: 0;
  }

  .hk-tag--posttooluse,
  .hk-tag--posttoolusefailure {
    background: color-mix(in oklch, oklch(65% 0.18 260) 12%, transparent 88%);
    color: oklch(55% 0.18 260);
  }

  .hk-tag--stop {
    background: color-mix(in oklch, oklch(65% 0.18 145) 12%, transparent 88%);
    color: oklch(50% 0.16 145);
  }

  .hk-tag--userpromptsubmit {
    background: color-mix(in oklch, oklch(70% 0.18 75) 12%, transparent 88%);
    color: oklch(52% 0.16 75);
  }

  .hk-tag--permissionrequest {
    background: color-mix(in oklch, oklch(60% 0.20 25) 12%, transparent 88%);
    color: oklch(50% 0.18 25);
  }

  .hk-event-session {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
</style>
