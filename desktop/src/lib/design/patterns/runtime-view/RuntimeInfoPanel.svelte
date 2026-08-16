<script lang="ts">
/**
 * RuntimeInfoPanel — sidebar info tab showing runtime capabilities, env, and config.
 *
 * CSS prefix: rip-
 */
import type { RuntimeDetail } from '$lib/domain/runtimes/types.js';

interface Props {
  runtime: RuntimeDetail;
}

let { runtime }: Props = $props();

const capabilityLabels: Record<string, string> = {
  heartbeat: 'Heartbeat',
  interactive: 'Interactive',
  task_queued: 'Task Queue',
  mcp: 'MCP',
  diff: 'Diff',
  thinking: 'Thinking',
};
</script>

<div class="rip-root">
  <section class="rip-section">
    <span class="rip-label">Capabilities</span>
    <div class="rip-pills">
      {#each runtime.capabilities as cap (cap)}
        <span class="rip-pill">{capabilityLabels[cap] ?? cap}</span>
      {/each}
      {#if runtime.capabilities.length === 0}
        <span class="rip-none">—</span>
      {/if}
    </div>
  </section>

  <section class="rip-section">
    <span class="rip-label">Runtime info</span>
    <dl class="rip-dl">
      <div class="rip-row">
        <dt class="rip-dt">Type</dt>
        <dd class="rip-dd rip-mono">{runtime.type}</dd>
      </div>
      <div class="rip-row">
        <dt class="rip-dt">Version</dt>
        <dd class="rip-dd rip-mono">{runtime.version ?? '—'}</dd>
      </div>
      {#if runtime.binaryPath}
        <div class="rip-row">
          <dt class="rip-dt">Binary</dt>
          <dd class="rip-dd rip-mono rip-truncate">{runtime.binaryPath}</dd>
        </div>
      {/if}
    </dl>
  </section>

  {#if Object.keys(runtime.config).length > 0}
    <section class="rip-section">
      <span class="rip-label">Config</span>
      <dl class="rip-dl">
        {#each Object.entries(runtime.config) as [k, v] (k)}
          <div class="rip-row">
            <dt class="rip-dt rip-mono">{k}</dt>
            <dd class="rip-dd rip-mono rip-truncate">{String(v)}</dd>
          </div>
        {/each}
      </dl>
    </section>
  {/if}
</div>

<style>
  .rip-root {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-3);
    overflow-y: auto;
    flex: 1;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .rip-section {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .rip-label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--fg-subtle);
  }

  .rip-pills {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-1);
  }

  .rip-pill {
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

  .rip-none {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    font-style: italic;
  }

  .rip-dl {
    display: flex;
    flex-direction: column;
    gap: 0;
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow: hidden;
  }

  .rip-row {
    display: flex;
    align-items: baseline;
    gap: var(--space-2);
    padding: 5px var(--space-3);
    border-bottom: 1px solid var(--border);
  }

  .rip-row:last-child {
    border-bottom: none;
  }

  .rip-dt {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-subtle);
    flex-shrink: 0;
    width: 60px;
  }

  .rip-dd {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg);
    flex: 1;
    min-width: 0;
  }

  .rip-mono {
    font-family: var(--font-mono) !important;
    font-size: 11px !important;
  }

  .rip-truncate {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>
