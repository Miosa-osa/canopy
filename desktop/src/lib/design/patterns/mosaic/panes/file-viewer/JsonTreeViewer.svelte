<script lang="ts">
/**
 * JsonTreeViewer — collapsible tree for JSON / YAML.
 * CSS prefix: jtv- (Json Tree Viewer).
 *
 * Pure DOM; no external library. YAML support uses a dynamic import of
 * js-yaml ONLY if it exists in the bundle — gracefully falls back to
 * showing raw text if the parse fails. (The wiring doc notes js-yaml as
 * an optional dep; without it, .yaml falls through to the code viewer.)
 *
 * Read-only by design. Click a key to collapse / expand its subtree.
 */
import { onMount } from 'svelte';

interface Props {
  /** Raw JSON or YAML source. */
  content: string;
  /** "json" or "yaml" — affects parse path only. */
  format?: 'json' | 'yaml';
}

let { content, format = 'json' }: Props = $props();

// ── Parse ───────────────────────────────────────────────────────────────────

let parsed = $state<unknown>(undefined);
let parseError = $state<string | null>(null);

$effect(() => {
  void content;
  void format;
  parsed = undefined;
  parseError = null;

  if (format === 'json') {
    try {
      parsed = JSON.parse(content);
    } catch (err) {
      parseError = err instanceof Error ? err.message : 'Invalid JSON';
    }
    return;
  }

  // YAML: parse via js-yaml.
  (async () => {
    try {
      const yaml = await import('js-yaml');
      parsed = yaml.load(content);
    } catch {
      parseError = 'Failed to parse YAML.';
    }
  })();
});

// ── Tree render helpers ─────────────────────────────────────────────────────

/** A path is a stable string used as a Set key for collapse state. */
function describe(value: unknown): {
  kind: 'object' | 'array' | 'primitive';
  size: number;
} {
  if (value === null || typeof value !== 'object') {
    return { kind: 'primitive', size: 0 };
  }
  if (Array.isArray(value)) return { kind: 'array', size: value.length };
  return { kind: 'object', size: Object.keys(value as object).length };
}

/** Set of currently-collapsed paths (objects/arrays only). */
let collapsed = $state<Set<string>>(new Set());

function toggle(path: string): void {
  const next = new Set(collapsed);
  if (next.has(path)) next.delete(path);
  else next.add(path);
  collapsed = next;
}

function primitiveClass(value: unknown): string {
  if (value === null) return 'jtv-null';
  if (typeof value === 'string') return 'jtv-string';
  if (typeof value === 'number') return 'jtv-number';
  if (typeof value === 'boolean') return 'jtv-boolean';
  return 'jtv-other';
}

function primitiveText(value: unknown): string {
  if (value === null) return 'null';
  if (typeof value === 'string') return JSON.stringify(value);
  return String(value);
}
</script>

<div class="jtv-root" role="tree" aria-label="JSON tree">
  {#if parseError}
    <div class="jtv-error" role="alert">{parseError}</div>
  {:else if parsed === undefined}
    <div class="jtv-loading">Parsing…</div>
  {:else}
    {@render node(parsed, "$", "")}
  {/if}
</div>

{#snippet node(value: unknown, path: string, label: string)}
  {@const desc = describe(value)}
  {#if desc.kind === "primitive"}
    <div class="jtv-row jtv-row-leaf" role="treeitem">
      {#if label}<span class="jtv-key">{label}:</span>{/if}
      <span class={primitiveClass(value)}>{primitiveText(value)}</span>
    </div>
  {:else}
    {@const isCollapsed = collapsed.has(path)}
    <div class="jtv-row" role="treeitem" aria-expanded={!isCollapsed}>
      <button
        type="button"
        class="jtv-toggle"
        onclick={() => toggle(path)}
        aria-label={isCollapsed ? "Expand" : "Collapse"}
      >
        <span class="jtv-chevron" class:jtv-chevron-collapsed={isCollapsed}>▾</span>
        {#if label}<span class="jtv-key">{label}:</span>{/if}
        <span class="jtv-bracket">
          {desc.kind === "array" ? `[${desc.size}]` : `{${desc.size}}`}
        </span>
      </button>
      {#if !isCollapsed}
        <div class="jtv-children" role="group">
          {#if desc.kind === "array"}
            {#each value as unknown[] as item, i (i)}
              {@render node(item, `${path}.${i}`, String(i))}
            {/each}
          {:else}
            {#each Object.entries(value as Record<string, unknown>) as [k, v] (k)}
              {@render node(v, `${path}.${k}`, k)}
            {/each}
          {/if}
        </div>
      {/if}
    </div>
  {/if}
{/snippet}

<style>
  .jtv-root {
    height: 100%;
    overflow: auto;
    padding: var(--space-3) var(--space-4);
    background: var(--bg-inset);
    font-family: var(--font-mono);
    font-size: 12px;
    line-height: 1.5;
    color: var(--fg);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .jtv-error {
    color: var(--signal-error, oklch(0.65 0.22 25));
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    padding: var(--space-3);
  }

  .jtv-loading {
    color: var(--fg-subtle);
    font-style: italic;
    padding: var(--space-3);
  }

  .jtv-row {
    display: block;
  }

  .jtv-row-leaf {
    padding-left: 16px;
  }

  .jtv-toggle {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    background: transparent;
    border: none;
    color: inherit;
    font: inherit;
    padding: 0;
    cursor: pointer;
    text-align: left;
  }

  .jtv-toggle:hover .jtv-key {
    color: var(--fg);
  }

  .jtv-chevron {
    display: inline-block;
    width: 10px;
    color: var(--fg-subtle);
    transition: transform 0.1s ease;
  }

  .jtv-chevron-collapsed {
    transform: rotate(-90deg);
  }

  .jtv-key {
    color: var(--fg-muted);
    font-weight: 500;
  }

  .jtv-bracket {
    color: var(--fg-subtle);
  }

  .jtv-children {
    margin-left: 16px;
    border-left: 1px dashed color-mix(in oklch, var(--fg) 12%, transparent);
    padding-left: 8px;
  }

  .jtv-string {
    color: oklch(0.72 0.18 145);
  }
  .jtv-number {
    color: oklch(0.72 0.16 250);
  }
  .jtv-boolean {
    color: oklch(0.72 0.18 60);
  }
  .jtv-null {
    color: var(--fg-subtle);
    font-style: italic;
  }
  .jtv-other {
    color: var(--fg);
  }
</style>
