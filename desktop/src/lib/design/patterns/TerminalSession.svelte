<script lang="ts">
/**
 * TerminalSession — xterm.js terminal wired to a Phoenix Channel via raw WebSocket.
 *
 * Transport: raw WebSocket using the Phoenix v2 wire protocol:
 *   [join_ref, ref, topic, event, payload]
 *
 * Topic format: "terminal:session:<session_id>"
 *
 * Frame protocol:
 *   Outgoing: push event "input"  payload { data: string }
 *             push event "resize" payload { cols: number, rows: number }
 *   Incoming: event "output" payload { data: string }
 *             event "exit"   payload { code: number }
 *
 * Static imports (no dynamic await import). One WebSocket per component.
 * No fallback transcript banner — error state shows retry button only.
 *
 * CSS prefix: ts-
 */

import { onMount } from 'svelte';
import { Terminal } from '@xterm/xterm';
import { FitAddon } from '@xterm/addon-fit';
import { WebLinksAddon } from '@xterm/addon-web-links';
import '@xterm/xterm/css/xterm.css';
import { fetchScrollback } from '$lib/api/queries/scrollback.js';
import { themeRegistry } from '$lib/stores/theme-registry.svelte.js';

interface Props {
  sessionId: string;
  isRunning?: boolean;
  /** Called when the channel joins successfully. */
  onConnected?: () => void;
  /** Called with the sendInput function so the harness can inject commands. */
  onReady?: (sendInput: (data: string) => void) => void;
}

let { sessionId, isRunning = false, onConnected, onReady }: Props = $props();

const FALLBACK_TERM_BG = '#0b0d10';
const FALLBACK_TERM_FG = '#e6e6e6';

// ── State ─────────────────────────────────────────────────────────────────────
let containerEl = $state<HTMLDivElement | undefined>();
let channelState = $state<'connecting' | 'connected' | 'error' | 'exited'>('connecting');
let exitCode = $state<number | null>(null);
let retryCount = $state(0);
let terminalBg = $state(FALLBACK_TERM_BG);

// Holds reference to the xterm Terminal instance after mount so the theme
// $effect below can update it live when the registry theme changes.
let termRef = $state<Terminal | null>(null);

function cssVar(name: string, fallback = ''): string {
  if (typeof document === 'undefined') return fallback;
  const value = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  return value || fallback;
}

function isTransparentBackground(value: string | undefined): boolean {
  if (!value) return true;
  const normalized = value.trim().toLowerCase();
  return normalized === 'transparent' || normalized === 'rgba(0, 0, 0, 0)' || normalized.endsWith('/ 0)');
}

function terminalTheme() {
  const palette = themeRegistry.activeTheme.terminal;
  const cssBg = cssVar('--term-bg', FALLBACK_TERM_BG);
  const background =
    !isTransparentBackground(palette.background)
      ? palette.background
      : !isTransparentBackground(cssBg)
        ? cssBg
        : FALLBACK_TERM_BG;
  terminalBg = background;

  return {
    ...palette,
    background,
    foreground: palette.foreground || cssVar('--term-fg', FALLBACK_TERM_FG),
    cursor: palette.cursor || cssVar('--term-cursor', '#78d97c'),
  };
}

// ── Live theme sync ────────────────────────────────────────────────────────────
// Re-runs whenever activeTheme changes. If the terminal hasn't mounted yet,
// termRef is null and this is a no-op — mount sets the theme directly.
$effect(() => {
  if (termRef) {
    termRef.options.theme = terminalTheme();
  }
});

// Phoenix v2 frame counter (ref must be unique per push within a connection).
let refCounter = 0;
function nextRef(): string {
  refCounter += 1;
  return String(refCounter);
}

const WS_URL = `ws://localhost:9190/socket/websocket?vsn=2.0.0`;
function makeTopic(id: string): string {
  return `terminal:session:${id}`;
}

// Exposed send function — populated on mount, called by harness.
let _sendFrame: ((event: string, payload: unknown) => void) | null = null;

/** Send input data to the pty via the channel. */
export function sendInput(data: string): void {
  _sendFrame?.('input', { data });
}

onMount(() => {
  if (typeof window === 'undefined' || !containerEl) return;

  const TOPIC = makeTopic(sessionId);
  let destroyed = false;
  let ws: WebSocket | null = null;
  let joinRef: string | null = null;

  // ── Build xterm synchronously (static imports — no await) ──────────────────
  const style = getComputedStyle(document.documentElement);
  const get = (v: string) => style.getPropertyValue(v).trim();

  const term = new Terminal({
    allowTransparency: false,
    fontFamily: get('--font-mono') || '"JetBrains Mono", "Fira Code", monospace',
    fontSize: 13,
    lineHeight: 1.45,
    cursorStyle: 'bar',
    cursorBlink: isRunning,
    theme: terminalTheme(),
  });

  // Expose to $effect so live theme changes can update an open terminal.
  termRef = term;

  const fitAddon = new FitAddon();
  const webLinksAddon = new WebLinksAddon();
  term.loadAddon(fitAddon);
  term.loadAddon(webLinksAddon);
  term.open(containerEl);
  const fitAndRefresh = () => {
    try {
      fitAddon.fit();
      term.refresh(0, Math.max(0, term.rows - 1));
    } catch {
      // The container can briefly be 0x0 while a canvas tile is resizing,
      // restoring, or reattaching after route hydration.
    }
  };

  fitAndRefresh();
  term.focus();

  requestAnimationFrame(fitAndRefresh);
  const initialRefreshTimers = [
    window.setTimeout(fitAndRefresh, 120),
    window.setTimeout(fitAndRefresh, 350),
  ];

  // ── Phoenix v2 send helper ─────────────────────────────────────────────────
  function sendFrame(event: string, payload: unknown, ref?: string): void {
    if (ws?.readyState !== WebSocket.OPEN) return;
    const frame = JSON.stringify([joinRef, ref ?? nextRef(), TOPIC, event, payload]);
    ws.send(frame);
  }

  // Expose to exported sendInput above.
  _sendFrame = sendFrame;
  onReady?.((data: string) => sendFrame('input', { data }));

  // ── Resize handling ────────────────────────────────────────────────────────
  // Both window resize and container resize (from ResizablePanel drag, Mosaic
  // split, sidebar collapse, etc.) must refit xterm AND notify the backend pty
  // so the child process sees the new SIGWINCH.
  // Debounce so a drag doesn't flood the backend with resize frames.
  let resizeDebounce: ReturnType<typeof setTimeout> | null = null;
  const handleResize = () => {
    fitAndRefresh();
    if (resizeDebounce) clearTimeout(resizeDebounce);
    resizeDebounce = setTimeout(() => {
      sendFrame('resize', { cols: term.cols, rows: term.rows });
      resizeDebounce = null;
    }, 80);
  };
  window.addEventListener('resize', handleResize);

  const resizeObserver = new ResizeObserver(handleResize);
  if (containerEl) resizeObserver.observe(containerEl);

  // ── xterm → channel ────────────────────────────────────────────────────────
  term.onData((data) => {
    sendFrame('input', { data });
  });

  // ── Open WebSocket ─────────────────────────────────────────────────────────
  function connect(): void {
    if (destroyed) return;
    channelState = 'connecting';

    ws = new WebSocket(WS_URL);

    ws.onopen = () => {
      if (destroyed || !ws) return;
      // Join the terminal channel.
      joinRef = nextRef();
      ws.send(JSON.stringify([joinRef, nextRef(), TOPIC, 'phx_join', {}]));
    };

    ws.onmessage = (ev: MessageEvent<string>) => {
      if (destroyed) return;
      let frame: [string | null, string | null, string, string, unknown];
      try {
        frame = JSON.parse(ev.data) as typeof frame;
      } catch {
        return;
      }
      const [, , topic, event, payload] = frame;
      if (topic !== TOPIC) return;

      switch (event) {
        case 'phx_reply': {
          const reply = payload as { status?: string; response?: unknown };
          if (reply.status === 'ok') {
            console.log('[TerminalSession] joined', TOPIC);
            channelState = 'connected';
            onConnected?.();
            // Send initial resize so backend knows terminal dimensions.
            fitAndRefresh();
            sendFrame('resize', { cols: term.cols, rows: term.rows });
          } else {
            console.error('[TerminalSession] join rejected', TOPIC, reply.response);
            channelState = 'error';
          }
          break;
        }
        case 'output': {
          const out = payload as { data?: string };
          if (out.data) term.write(out.data, fitAndRefresh);
          break;
        }
        case 'exit': {
          const ex = payload as { code?: number };
          exitCode = ex.code ?? null;
          channelState = 'exited';
          term.write(`\r\n\x1b[90m[process exited with code ${exitCode ?? '?'}]\x1b[0m\r\n`, fitAndRefresh);
          break;
        }
        case 'phx_error':
        case 'phx_close': {
          channelState = 'error';
          break;
        }
      }
    };

    ws.onerror = (e) => {
      console.error('[TerminalSession] WS error', e);
      if (!destroyed) channelState = 'error';
    };

    ws.onclose = (e) => {
      console.warn('[TerminalSession] WS closed', e.code, e.reason, 'state was:', channelState);
      if (!destroyed && channelState === 'connecting') channelState = 'error';
    };
  }

  // ── Connect the WebSocket immediately ──────────────────────────────────────
  // Opening the WS is the PRIMARY behavior — don't gate it on scrollback.
  // Scrollback loads additively after mount and writes to xterm if it arrives.
  connect();

  // Cold-restore scrollback in the background. If the endpoint 404s or the
  // response is malformed, we log and move on — the WS is already attached.
  void (async () => {
    try {
      const sb = await fetchScrollback(sessionId, { lastN: 1000 });
      if (sb.data.length > 0) {
        term.write(sb.data, fitAndRefresh);
      }
    } catch (err) {
      // Non-fatal.
      console.warn('[TerminalSession] scrollback fetch failed:', err);
    }
  })();

  // ── Cleanup ────────────────────────────────────────────────────────────────
  return () => {
    destroyed = true;
    _sendFrame = null;
    termRef = null;
    window.removeEventListener('resize', handleResize);
    for (const timer of initialRefreshTimers) window.clearTimeout(timer);
    resizeObserver.disconnect();

    if (ws && ws.readyState === WebSocket.OPEN) {
      try {
        ws.send(JSON.stringify([joinRef, nextRef(), TOPIC, 'phx_leave', {}]));
      } catch {
        // ignore
      }
      ws.close();
    }

    term.dispose();
  };
});

function handleRetry(): void {
  retryCount += 1;
  // Svelte will remount via {#key retryCount} on the parent — see template.
}
</script>

<div class="ts-root" class:agent-running={isRunning} style:--ts-term-bg={terminalBg}>
  <!-- xterm.js mount point — always rendered, overlay appears while connecting -->
  <div
    class="ts-terminal"
    bind:this={containerEl}
    aria-label="Live terminal"
  ></div>

  {#if channelState === 'connecting'}
    <div class="ts-overlay" aria-live="polite">
      <span class="ts-connecting-dot"></span>
      Connecting…
    </div>
  {:else if channelState === 'error'}
    <div class="ts-error-overlay" role="status">
      <span class="ts-error-text">Connection failed</span>
      <button
        class="ts-retry-btn"
        onclick={handleRetry}
        aria-label="Retry terminal connection"
      >
        Retry
      </button>
    </div>
  {/if}
</div>

<style>
  .ts-root {
    position: relative;
    flex: 1;
    min-height: 0;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    background: var(--ts-term-bg, #0b0d10);
    border-radius: var(--radius-lg);
    border: 1px solid var(--border);
  }

  .ts-terminal {
    flex: 1;
    min-height: 0;
    background: var(--ts-term-bg, #0b0d10);
  }

  /* xterm.js internal overrides */
  .ts-terminal :global(.xterm) {
    padding: 12px;
    height: 100%;
    background: var(--ts-term-bg, #0b0d10) !important;
  }

  .ts-terminal :global(.xterm-viewport) {
    background: var(--ts-term-bg, #0b0d10) !important;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .ts-terminal :global(.xterm-screen) {
    background: var(--ts-term-bg, #0b0d10) !important;
  }

  /* Overlay shown while connecting */
  .ts-overlay {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: var(--space-2);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    background: color-mix(in oklch, var(--ts-term-bg, #0b0d10) 80%, transparent);
    pointer-events: none;
  }

  .ts-connecting-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--fg-subtle);
    animation: ts-blink 1s ease-in-out infinite;
  }

  @keyframes ts-blink {
    0%, 100% { opacity: 0.3; }
    50%       { opacity: 1; }
  }

  /* Error overlay — small, non-blocking */
  .ts-error-overlay {
    position: absolute;
    bottom: var(--space-3);
    right: var(--space-3);
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    background: color-mix(in oklch, var(--signal-error, oklch(0.65 0.2 25)) 10%, var(--bg-inset));
    border: 1px solid color-mix(in oklch, var(--signal-error, oklch(0.65 0.2 25)) 30%, transparent);
    border-radius: var(--radius-md);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    pointer-events: all;
  }

  .ts-error-text {
    color: var(--signal-error, oklch(0.65 0.2 25));
  }

  .ts-retry-btn {
    padding: 2px 8px;
    border: 1px solid var(--cnp-accent);
    border-radius: var(--radius-sm);
    background: transparent;
    color: var(--cnp-accent);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    cursor: pointer;
    transition: background 0.1s ease;
  }

  .ts-retry-btn:hover {
    background: color-mix(in oklch, var(--cnp-accent) 12%, transparent);
  }

  .ts-retry-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }
</style>
