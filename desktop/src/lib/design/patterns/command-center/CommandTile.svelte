<script lang="ts">
/**
 * CommandTile — live tile for one session in the Command Center grid.
 * CSS prefix: ct-
 * WS: per-tile Phoenix v2 raw-WS, cleaned up on unmount.
 * Terminal: real xterm.js, lazy-mounted via IntersectionObserver so 50 tiles
 * don't spin up 50 xterm instances at once. xterm parses ANSI natively, so
 * Claude Code's full output (welcome panel, colours, cursor moves) renders
 * correctly — same engine as /sessions/[id], just smaller.
 */

import { onMount } from 'svelte';
import { goto } from '$app/navigation';
import { useQueryClient } from '@tanstack/svelte-query';
import { Bot, Terminal as TerminalIcon, Cpu, Box } from 'lucide-svelte';
import { formatDistanceToNow } from 'date-fns';
import type { Session, SessionStatus } from '$lib/domain/sessions/types.js';
import { pauseSession, resumeSession } from '$lib/api/queries/sessions.js';
import { fetchScrollback } from '$lib/api/queries/scrollback.js';
import { toasts } from '$lib/stores/toasts.svelte.js';
import { Terminal } from '@xterm/xterm';
import { FitAddon } from '@xterm/addon-fit';
import '@xterm/xterm/css/xterm.css';

interface Props {
  session: Session;
  onPause?: (id: string) => void;
}

let { session, onPause }: Props = $props();

let wsState       = $state<'connecting' | 'connected' | 'error' | 'paused'>('connecting');
let isPaused      = $state(session.status === 'paused');
let actionPending = $state(false);
let containerEl   = $state<HTMLDivElement | undefined>();

const queryClient = useQueryClient();

// xterm + fit addon — null until the IntersectionObserver mounts.
// Until then, raw output is buffered in `pendingWrites` and replayed
// once the terminal exists. This is what makes the lazy mount cheap:
// off-screen tiles never instantiate xterm, but they still receive
// the WS stream so they're warm if the user scrolls them in.
let term: Terminal | null = null;
let fitAddon: FitAddon | null = null;
let pendingWrites: string[] = [];

function writeToTerm(data: string): void {
  if (isPaused) return;
  if (term) term.write(data);
  else {
    // Cap the pre-mount buffer so a chatty session doesn't OOM the tab.
    pendingWrites.push(data);
    if (pendingWrites.length > 64) pendingWrites = pendingWrites.slice(-64);
  }
}

function mountTerm(): void {
  if (term || !containerEl) return;
  const style = getComputedStyle(document.documentElement);
  const css = (v: string) => style.getPropertyValue(v).trim();

  term = new Terminal({
    allowTransparency: true,
    fontFamily: css('--font-mono') || '"JetBrains Mono", "Fira Code", monospace',
    fontSize: 10,
    lineHeight: 1.3,
    cursorStyle: 'bar',
    cursorBlink: false,
    disableStdin: true,
    convertEol: true,
    scrollback: 200,
    rows: 12,
    cols: 80,
    theme: {
      background: 'transparent',
      foreground: css('--term-fg') || '#e6e6e6',
      cursor: css('--term-cursor') || '#78d97c',
      black: css('--term-black') || '#1c1c1e',
      red: css('--term-red') || '#e55',
      green: css('--term-green') || '#78d97c',
      yellow: css('--term-yellow') || '#fbbf24',
      blue: css('--term-blue') || '#60a5fa',
      magenta: css('--term-magenta') || '#a78bfa',
      cyan: css('--term-cyan') || '#34d399',
      white: css('--term-white') || '#aaa',
      brightBlack: css('--term-bright-black') || '#444',
      brightGreen: css('--term-bright-green') || '#86efac',
      brightRed: css('--term-bright-red') || '#f87171',
      brightYellow: css('--term-bright-yellow') || '#fde68a',
      brightBlue: css('--term-bright-blue') || '#93c5fd',
      brightMagenta: css('--term-bright-magenta') || '#c4b5fd',
      brightCyan: css('--term-bright-cyan') || '#6ee7b7',
      brightWhite: css('--term-bright-white') || '#f5f5f7',
    },
  });

  fitAddon = new FitAddon();
  term.loadAddon(fitAddon);
  term.open(containerEl);
  try { fitAddon.fit(); } catch { /* container may be 0×0 in rare cases */ }

  // Replay anything we buffered before mount so the tile catches up.
  if (pendingWrites.length > 0) {
    for (const chunk of pendingWrites) term.write(chunk);
    pendingWrites = [];
  }
}

function unmountTerm(): void {
  if (!term) return;
  try { term.dispose(); } catch { /* ignore */ }
  term = null;
  fitAddon = null;
}

const STATUS_LABEL: Record<SessionStatus, string> = {
  running: 'running', pending: 'queued', paused: 'paused',
  completed: 'done', cancelled: 'stopped', error: 'error',
};
const STATUS_CLASS: Record<SessionStatus, string> = {
  running: 'ct-pill--running', pending: 'ct-pill--queued', paused: 'ct-pill--paused',
  completed: 'ct-pill--done', cancelled: 'ct-pill--done', error: 'ct-pill--error',
};

type IconCmp = typeof Bot;
const RUNTIME_ICONS: Record<string, IconCmp> = { claude: Bot, openai: Bot, docker: Box, cpu: Cpu };
function runtimeIcon(rt: string): IconCmp {
  const k = rt.toLowerCase();
  for (const [key, cmp] of Object.entries(RUNTIME_ICONS)) if (k.includes(key)) return cmp;
  return TerminalIcon;
}

const TileIcon = $derived(runtimeIcon(session.runtimeType));
const timeAgo  = $derived(formatDistanceToNow(new Date(session.startedAt ?? session.insertedAt), { addSuffix: true }));
const isActive = $derived(session.status === 'running' || session.status === 'pending');

const WS_URL = 'ws://localhost:9190/socket/websocket?vsn=2.0.0';

onMount(() => {
  if (typeof window === 'undefined') return;
  const TOPIC = `terminal:session:${session.id}`;
  let destroyed = false;
  let ws: WebSocket | null = null;
  let ref = 0;
  let joinRef: string | null = null;
  const next = () => String(++ref);

  // Show persisted scrollback tail so the tile isn't blank when the pty is
  // idle (or already exited). Live WS output replaces this as it arrives.
  // We grab the FULL scrollback (not just stripped lines) because xterm
  // parses ANSI natively and the colour/cursor info is what makes the
  // preview readable.
  void (async () => {
    try {
      const sb = await fetchScrollback(session.id, { lastN: 200 });
      if (destroyed) return;
      // Scrollback comes back as Uint8Array (raw pty bytes including ANSI).
      // Decode as UTF-8 and feed straight to xterm — it parses everything.
      const raw = sb?.data;
      if (raw && raw.byteLength > 0) {
        const text = new TextDecoder('utf-8', { fatal: false }).decode(raw);
        writeToTerm(text);
      }
    } catch {
      /* non-fatal */
    }
  })();

  // Lazy-mount xterm only when the tile scrolls into view. 50 tiles ×
  // a hot xterm instance each blows out memory and main-thread time;
  // this keeps off-screen tiles cheap.
  let observer: IntersectionObserver | null = null;
  if (containerEl && typeof IntersectionObserver !== 'undefined') {
    observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) mountTerm();
          // We deliberately DO NOT unmount when the tile leaves the
          // viewport — once mounted, keep it warm so scrolling back is
          // instant. dispose() only runs on component unmount.
        }
      },
      { rootMargin: '120px' },
    );
    observer.observe(containerEl);
  } else {
    // Fallback for environments without IntersectionObserver (tests/JSDOM):
    // mount immediately.
    mountTerm();
  }

  function send(event: string, payload: unknown, r?: string): void {
    if (ws?.readyState !== WebSocket.OPEN) return;
    ws.send(JSON.stringify([joinRef, r ?? next(), TOPIC, event, payload]));
  }

  ws = new WebSocket(WS_URL);
  ws.onopen = () => {
    if (destroyed || !ws) return;
    ws.send(JSON.stringify([null, next(), 'phoenix', 'heartbeat', {}]));
    joinRef = next();
    ws.send(JSON.stringify([joinRef, next(), TOPIC, 'phx_join', {}]));
  };
  ws.onmessage = (ev: MessageEvent<string>) => {
    if (destroyed) return;
    let frame: [string | null, string | null, string, string, unknown];
    try { frame = JSON.parse(ev.data) as typeof frame; } catch { return; }
    const [, , topic, event, payload] = frame;
    if (topic !== TOPIC) return;
    switch (event) {
      case 'phx_reply': wsState = (payload as { status?: string }).status === 'ok' ? 'connected' : 'error'; break;
      case 'output':    { const d = (payload as { data?: string }).data; if (d) writeToTerm(d); break; }
      case 'exit': case 'phx_error': case 'phx_close': wsState = 'error'; break;
    }
  };
  ws.onerror = () => { if (!destroyed) wsState = 'error'; };
  ws.onclose = () => { if (!destroyed && wsState === 'connecting') wsState = 'error'; };

  return () => {
    destroyed = true;
    if (observer) {
      try { observer.disconnect(); } catch { /* ignore */ }
    }
    unmountTerm();
    if (ws?.readyState === WebSocket.OPEN) {
      try { send('phx_leave', {}); } catch { /* ignore */ }
      ws.close();
    }
  };
});

async function handlePause(e: MouseEvent): Promise<void> {
  e.stopPropagation();
  if (actionPending) return;
  actionPending = true;
  const nextPaused = !isPaused;
  // Optimistic local state
  isPaused = nextPaused;
  wsState = nextPaused ? 'paused' : 'connected';
  try {
    if (nextPaused) {
      await pauseSession(session.id);
      toasts.success('Paused — terminal stays alive');
    } else {
      await resumeSession(session.id);
      toasts.success('Resumed');
    }
    queryClient.invalidateQueries({ queryKey: ['sessions'] });
    onPause?.(session.id);
  } catch (err) {
    // Revert optimistic update
    isPaused = !nextPaused;
    wsState = !nextPaused ? 'paused' : 'connected';
    const message = err instanceof Error ? err.message : 'Action failed';
    toasts.error(message);
  } finally {
    actionPending = false;
  }
}
function handleOpen(e: MouseEvent): void {
  e.stopPropagation();
  void goto(`/sessions/${session.id}`);
}
function handleTileClick(): void { void goto(`/sessions/${session.id}`); }
</script>

<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
<div
  class="ct-tile"
  class:ct-tile--active={isActive}
  class:ct-tile--error={session.status === 'error'}
  onclick={handleTileClick}
  role="button"
  tabindex="0"
  onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') handleTileClick(); }}
  aria-label="Session {session.id.slice(0, 8)} — {session.status}"
>
  <header class="ct-header">
    <div class="ct-identity">
      <span class="ct-icon" aria-hidden="true">
        {#if TileIcon}
          <TileIcon size={13} />
        {/if}
      </span>
      <div class="ct-meta">
        <span class="ct-agent">{session.agentSlug ?? session.runtimeType}</span>
        {#if session.workspaceSlug}<span class="ct-workspace">{session.workspaceSlug}</span>{/if}
      </div>
    </div>
    <span class="ct-pill {STATUS_CLASS[session.status]}">
      {#if isActive && !isPaused}<span class="ct-pulse" aria-hidden="true"></span>{/if}
      {STATUS_LABEL[session.status]}
    </span>
  </header>

  <div class="ct-terminal-wrap" aria-label="Terminal preview">
    {#if wsState === 'error'}
      <div class="ct-fallback" role="status">Terminal paused — click Open</div>
    {:else if wsState === 'connecting'}
      <div class="ct-fallback" role="status">
        <span class="ct-blink" aria-hidden="true"></span>connecting…
      </div>
    {:else}
      <div class="ct-xterm" bind:this={containerEl} aria-live="polite"></div>
    {/if}
  </div>

  <footer class="ct-footer">
    <time class="ct-time" datetime={session.startedAt ?? session.insertedAt}>{timeAgo}</time>
    <div class="ct-actions" role="group" aria-label="Session actions">
      <button class="ct-btn" onclick={handleOpen} aria-label="Open full terminal">Open</button>
      <button class="ct-btn ct-btn--ghost" onclick={handlePause}
        disabled={actionPending}
        aria-busy={actionPending}
        aria-label={isPaused ? 'Resume session' : 'Pause session'}>
        {#if actionPending}
          …
        {:else}
          {isPaused ? 'Resume' : 'Pause'}
        {/if}
      </button>
    </div>
  </footer>
</div>

<style>
  .ct-tile {
    display: flex; flex-direction: column;
    background: var(--surface, var(--bg-elevated, var(--bg))); border: 1px solid var(--border);
    border-radius: var(--radius-lg); overflow: hidden; cursor: pointer; height: 220px;
    user-select: none; outline: none;
    transition: border-color var(--dur-fast) var(--ease-out), box-shadow var(--dur-fast) var(--ease-out);
  }
  .ct-tile:focus-visible { outline: 2px solid var(--cnp-accent); outline-offset: 2px; }
  .ct-tile:hover { border-color: var(--cnp-accent); box-shadow: 0 0 0 1px color-mix(in oklch, var(--cnp-accent) 20%, transparent); }
  .ct-tile--active { border-color: color-mix(in oklch, var(--cnp-accent) 30%, var(--border)); }
  .ct-tile--error  { border-color: color-mix(in oklch, var(--signal-error, oklch(0.65 0.2 25)) 30%, var(--border)); }

  .ct-header { display: flex; align-items: center; justify-content: space-between; gap: var(--space-2); padding: var(--space-2) var(--space-3); border-bottom: 1px solid var(--border); flex-shrink: 0; }
  .ct-identity { display: flex; align-items: center; gap: var(--space-2); min-width: 0; }
  .ct-icon { display: flex; align-items: center; color: var(--fg-subtle); flex-shrink: 0; }
  .ct-meta { display: flex; flex-direction: column; min-width: 0; }
  .ct-agent { font-size: 11px; font-weight: 600; color: var(--fg); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .ct-workspace { font-size: 10px; color: var(--fg-subtle); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

  .ct-pill {
    display: inline-flex; align-items: center; gap: 4px; padding: 2px 6px; flex-shrink: 0;
    font-size: 10px; font-weight: 600; letter-spacing: 0.05em; text-transform: uppercase;
    border-radius: var(--radius-sm); border: 1px solid transparent; font-family: var(--font-mono);
  }
  .ct-pill--running  { color: var(--cnp-accent); background: color-mix(in oklch, var(--cnp-accent) 10%, transparent); border-color: color-mix(in oklch, var(--cnp-accent) 25%, transparent); }
  .ct-pill--queued   { color: var(--fg-subtle); background: var(--bg-inset); border-color: var(--border); }
  .ct-pill--paused   { color: var(--fg-muted); background: var(--bg-inset); border-color: var(--border); }
  .ct-pill--done     { color: var(--fg-subtle); background: transparent; border-color: var(--border); }
  .ct-pill--error    { color: var(--signal-error, oklch(0.65 0.2 25)); background: color-mix(in oklch, var(--signal-error, oklch(0.65 0.2 25)) 8%, transparent); border-color: color-mix(in oklch, var(--signal-error, oklch(0.65 0.2 25)) 25%, transparent); }

  .ct-pulse { width: 5px; height: 5px; border-radius: 50%; background: currentColor; animation: ct-pulse 1.4s ease-in-out infinite; flex-shrink: 0; }
  @keyframes ct-pulse { 0%, 100% { opacity: 0.3; transform: scale(0.85); } 50% { opacity: 1; transform: scale(1.1); } }

  .ct-terminal-wrap { flex: 1; min-height: 0; overflow: hidden; background: var(--term-bg, oklch(0.1 0.005 240)); display: flex; flex-direction: column; }
  .ct-xterm { flex: 1; min-height: 0; overflow: hidden; padding: var(--space-2) var(--space-3); display: flex; flex-direction: column; }
  .ct-xterm :global(.xterm) { flex: 1; min-height: 0; height: 100%; }
  .ct-xterm :global(.xterm-viewport) { background: transparent !important; scrollbar-width: none; }
  .ct-xterm :global(.xterm-viewport::-webkit-scrollbar) { display: none; }
  .ct-xterm :global(.xterm-screen) { width: 100% !important; }
  .ct-fallback { display: flex; align-items: center; justify-content: center; gap: var(--space-2); flex: 1; font-family: var(--font-mono); font-size: 10px; color: var(--fg-subtle); padding: var(--space-3); }
  .ct-blink { width: 5px; height: 5px; border-radius: 50%; background: var(--fg-subtle); animation: ct-blink 1s ease-in-out infinite; }
  @keyframes ct-blink { 0%, 100% { opacity: 0.2; } 50% { opacity: 1; } }

  .ct-footer { display: flex; align-items: center; justify-content: space-between; padding: var(--space-2) var(--space-3); border-top: 1px solid var(--border); flex-shrink: 0; min-height: 34px; }
  .ct-time { font-family: var(--font-mono); font-size: 10px; color: var(--fg-subtle); white-space: nowrap; }
  .ct-actions { display: flex; gap: var(--space-1); opacity: 0; transition: opacity var(--dur-fast) var(--ease-out); }
  .ct-tile:hover .ct-actions, .ct-tile:focus-within .ct-actions { opacity: 1; }
  .ct-btn { display: inline-flex; align-items: center; padding: 2px 8px; font-size: 10px; font-weight: 600; font-family: var(--font-sans); letter-spacing: 0.02em; border-radius: var(--radius-sm); border: 1px solid var(--border); background: var(--bg); color: var(--fg); cursor: pointer; transition: border-color var(--dur-fast) var(--ease-out); }
  .ct-btn:hover { border-color: var(--cnp-accent); }
  .ct-btn:focus-visible { outline: 2px solid var(--cnp-accent); outline-offset: 2px; }
  .ct-btn--ghost { background: transparent; color: var(--fg-subtle); }
  .ct-btn--ghost:hover { color: var(--fg); }

  @media (prefers-reduced-motion: reduce) {
    .ct-tile, .ct-btn, .ct-actions { transition: none; }
    .ct-pulse, .ct-blink { animation: none; }
  }
</style>
