<script lang="ts">
/**
 * LiveTerminal — xterm.js wrapper for live session output.
 *
 * Renders a real terminal emulator with theme tokens derived from CSS vars.
 * The `stream` prop accepts a ReadableStream<string>; if null the terminal
 * stays visible but empty (Week 2 will wire real PTY streams).
 *
 * CSS prefix: lt- (LiveTerminal)
 */
import { onMount } from 'svelte';

interface Props {
  /** ReadableStream of string chunks piped to the terminal. Null = scaffold. */
  stream?: ReadableStream<string> | null;
  /** Whether the associated session is currently running. */
  isRunning?: boolean;
}

let { stream = null, isRunning = false }: Props = $props();

let containerEl: HTMLDivElement | undefined = $state();
let terminalMounted = $state(false);

onMount(() => {
  if (typeof window === 'undefined' || !containerEl) return;

  // Cleanup functions registered by the async setup below.
  let resizeCleanup: (() => void) | null = null;
  let readerCleanup: (() => void) | null = null;
  let termCleanup: (() => void) | null = null;
  let destroyed = false;

  // Async terminal setup — must NOT be the onMount return value.
  void (async () => {
    if (destroyed) return;

    const { Terminal } = await import('@xterm/xterm');
    const { FitAddon } = await import('@xterm/addon-fit');
    const { WebLinksAddon } = await import('@xterm/addon-web-links');

    if (destroyed || !containerEl) return;

    // Derive theme from CSS custom properties.
    const style = getComputedStyle(document.documentElement);
    const get = (v: string) => style.getPropertyValue(v).trim();

    const term = new Terminal({
      allowTransparency: true,
      fontFamily: get('--font-mono') || '"JetBrains Mono", monospace',
      fontSize: 12,
      lineHeight: 1.5,
      cursorStyle: 'bar',
      cursorBlink: true,
      theme: {
        background: 'transparent',
        foreground: get('--term-fg') || '#e6e6e6',
        cursor: get('--term-cursor') || '#78d97c',
        black: get('--term-black') || '#1c1c1e',
        red: get('--term-red') || '#e55',
        green: get('--term-green') || '#78d97c',
        yellow: get('--term-yellow') || '#fbbf24',
        blue: get('--term-blue') || '#60a5fa',
        magenta: get('--term-magenta') || '#a78bfa',
        cyan: get('--term-cyan') || '#34d399',
        white: get('--term-white') || '#aaa',
        brightBlack: get('--term-bright-black') || '#444',
        brightRed: get('--term-bright-red') || '#f87171',
        brightGreen: get('--term-bright-green') || '#86efac',
        brightYellow: get('--term-bright-yellow') || '#fde68a',
        brightBlue: get('--term-bright-blue') || '#93c5fd',
        brightMagenta: get('--term-bright-magenta') || '#c4b5fd',
        brightCyan: get('--term-bright-cyan') || '#6ee7b7',
        brightWhite: get('--term-bright-white') || '#f5f5f7',
      },
    });

    const fitAddon = new FitAddon();
    const webLinksAddon = new WebLinksAddon();

    term.loadAddon(fitAddon);
    term.loadAddon(webLinksAddon);
    term.open(containerEl);
    fitAddon.fit();
    terminalMounted = true;

    termCleanup = () => {
      term.dispose();
      terminalMounted = false;
    };

    // Pipe incoming stream if provided.
    if (stream) {
      const reader = stream.getReader();
      readerCleanup = () => {
        void reader.cancel();
      };
      const pump = async () => {
        while (!destroyed) {
          const { done, value } = await reader.read();
          if (done) break;
          term.write(value);
        }
      };
      void pump();
    }

    // Resize handler.
    const onResize = () => fitAddon.fit();
    window.addEventListener('resize', onResize);
    resizeCleanup = () => window.removeEventListener('resize', onResize);
  })();

  // Synchronous cleanup returned to Svelte — calls into async cleanup fns.
  return () => {
    destroyed = true;
    resizeCleanup?.();
    readerCleanup?.();
    termCleanup?.();
  };
});
</script>

<div
  class="lt-root"
  class:agent-running={isRunning}
  aria-label="Live terminal output"
  role="region"
>
  <!-- xterm.js mounts its canvas here -->
  <div class="lt-terminal" bind:this={containerEl}></div>

  {#if !terminalMounted}
    <div class="lt-placeholder" aria-hidden="true">
      <span class="lt-placeholder-text">Initialising terminal…</span>
    </div>
  {/if}
</div>

<style>
  .lt-root {
    position: relative;
    background: var(--term-bg, oklch(0.12 0.005 240));
    border-radius: var(--radius-lg);
    border: 1px solid var(--border);
    overflow: hidden;
    min-height: 160px;
    display: flex;
    flex-direction: column;
  }

  .lt-terminal {
    flex: 1;
    /* xterm.js inserts its viewport element here */
  }

  /* xterm.js overrides — blend with our token scheme */
  .lt-terminal :global(.xterm) {
    padding: 12px;
    height: 100%;
  }

  .lt-terminal :global(.xterm-viewport) {
    background: transparent !important;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .lt-placeholder {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    pointer-events: none;
  }

  .lt-placeholder-text {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    opacity: 0.6;
  }
</style>
