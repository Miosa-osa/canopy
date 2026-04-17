<script lang="ts">
/**
 * RuntimeCard — glass card showing a single runtime adapter summary.
 *
 * Displays runtime name, version, status dot, capability pills, and a
 * primary CTA (Launch ▸ if installed, Install ↗ if not). Clicking anywhere
 * on the card navigates to /runtimes/{runtime.type}.
 *
 * CSS prefix: rc- (RuntimeCard)
 */
import { goto } from '$app/navigation';
import type { Runtime, RuntimeCapability } from '$lib/domain/runtimes/types.js';
import StatusDot from './StatusDot.svelte';

interface Props {
  runtime: Runtime;
}

let { runtime }: Props = $props();

const isInstalled = $derived(runtime.status === 'installed');

const statusDotColor = $derived<'green' | 'amber' | 'red' | 'grey'>(
  runtime.status === 'installed'
    ? 'green'
    : runtime.status === 'misconfigured'
      ? 'amber'
      : runtime.status === 'error'
        ? 'red'
        : 'grey'
);

const statusPulse = $derived(runtime.status === 'installed');

const capabilityLabels: Record<RuntimeCapability, string> = {
  heartbeat: 'Heartbeat',
  interactive: 'Interactive',
  task_queued: 'Queue',
  mcp: 'MCP',
  diff: 'Diff',
  thinking: 'Thinking',
};

const runtimeEmoji: Record<string, string> = {
  claude: '🤖',
  openai: '⬡',
  gemini: '✦',
  ollama: '🦙',
  mistral: '◈',
  groq: '⚡',
};

const icon = $derived(runtimeEmoji[runtime.type.toLowerCase()] ?? '◻');

function navigateToDetail(e: MouseEvent | KeyboardEvent) {
  if (e instanceof KeyboardEvent && e.key !== 'Enter' && e.key !== ' ') return;
  e.preventDefault();
  void goto(`/runtimes/${runtime.type}`);
}

function handleCta(e: MouseEvent) {
  e.stopPropagation();
  void goto(`/runtimes/${runtime.type}`);
}
</script>

<div
  class="rc-card glass-card"
  role="button"
  tabindex="0"
  aria-label="Open {runtime.name} runtime detail"
  onclick={navigateToDetail}
  onkeydown={navigateToDetail}
>
  <!-- Header -->
  <div class="rc-header">
    <span class="rc-icon" aria-hidden="true">{icon}</span>
    <div class="rc-meta">
      <span class="rc-name">{runtime.name}</span>
      {#if runtime.version}
        <span class="rc-version">{runtime.version}</span>
      {/if}
    </div>
    <StatusDot
      color={statusDotColor}
      pulse={statusPulse}
      label="Status: {runtime.status}"
    />
  </div>

  <!-- Divider -->
  <div class="rc-divider" aria-hidden="true"></div>

  <!-- Capability pills -->
  <div class="rc-capabilities" aria-label="Capabilities">
    {#each runtime.capabilities as cap (cap)}
      <span class="rc-cap-pill">{capabilityLabels[cap] ?? cap}</span>
    {/each}
    {#if runtime.capabilities.length === 0}
      <span class="rc-cap-none">—</span>
    {/if}
  </div>

  <!-- Divider -->
  <div class="rc-divider" aria-hidden="true"></div>

  <!-- CTA -->
  <button
    class="btn-pill btn-pill-primary btn-pill-sm rc-cta"
    onclick={handleCta}
    aria-label={isInstalled ? `Launch ${runtime.name}` : `Install ${runtime.name}`}
  >
    {#if isInstalled}
      Launch ▸
    {:else}
      Install ↗
    {/if}
  </button>
</div>

<style>
  .rc-card {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-4);
    cursor: pointer;
    outline: none;
    transition:
      transform 0.2s var(--ease-out),
      box-shadow 0.2s var(--ease-out);
  }

  .rc-card:focus-visible {
    box-shadow:
      var(--glass-shadow),
      0 0 0 2px var(--accent);
  }

  .rc-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .rc-icon {
    font-size: 20px;
    line-height: 1;
    flex-shrink: 0;
    user-select: none;
    width: 28px;
    text-align: center;
  }

  .rc-meta {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-width: 0;
    gap: 2px;
  }

  .rc-name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: var(--tracking-sm);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .rc-version {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    white-space: nowrap;
  }

  .rc-divider {
    height: 1px;
    background: var(--border);
    opacity: 0.6;
  }

  .rc-capabilities {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-1);
    min-height: 24px;
  }

  .rc-cap-pill {
    display: inline-flex;
    align-items: center;
    height: 20px;
    padding: 0 8px;
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    border: 1px solid var(--border);
    white-space: nowrap;
  }

  .rc-cap-none {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  .rc-cta {
    align-self: flex-start;
  }
</style>
